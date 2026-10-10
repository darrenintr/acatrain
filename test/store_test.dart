import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:acatrain/store.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final seed = File('assets/seed.json').readAsStringSync();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });
  test(
    'valid release swaps only after download and persists across restart',
    () async {
      final payload = seed.replaceFirst(
        'Market structure essentials',
        'Updated economics',
      );
      final client = MockClient(
        (r) async => http.Response.bytes(
          utf8.encode(r.url.path.endsWith('manifest')
              ? jsonEncode({
                'releaseId': 'r1',
                'schemaVersion': 1,
                'minAppBuild': 1,
                'sha256': sha256.convert(utf8.encode(payload)).toString(),
              })
              : payload),
          200,
        ),
      );
      final prefs = await SharedPreferences.getInstance();
      final store = AppStore(
        prefs,
        client: client,
        apiUrl: 'https://study.example',
      );
      await store.load(seed: seed);
      final runningSession = store.bundle.sets.first;
      await store.syncContent();
      expect(store.releaseId, 'r1');
      expect(store.bundle.sets.first.title, 'Updated economics');
      expect(runningSession.title, 'Market structure essentials');
      final reopened = AppStore(prefs);
      await reopened.load(seed: seed);
      expect(reopened.releaseId, 'r1');
      store.dispose();
      reopened.dispose();
    },
  );
  test('checksum failure leaves current release and cache intact', () async {
    final store = AppStore(
      await SharedPreferences.getInstance(),
      apiUrl: 'https://study.example',
      client: MockClient(
        (r) async => http.Response.bytes(
          utf8.encode(r.url.path.endsWith('manifest')
              ? jsonEncode({
                'releaseId': 'r1',
                'schemaVersion': 1,
                'minAppBuild': 1,
                'sha256': 'invalid',
              })
              : seed),
          200,
        ),
      ),
    );
    await store.load(seed: seed);
    await store.syncContent();
    expect(store.releaseId, 'bundled-demo');
    expect(store.prefs.getString('content:v1'), isNull);
    expect(store.status, contains('integrity'));
    store.dispose();
  });
  test(
    'progress persists offline and no authentication token is stored',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final store = AppStore(prefs);
      await store.load(seed: seed);
      final set = store.bundle.sets.first;
      await store.record(set, set.items.first, false);
      final reopened = AppStore(prefs);
      await reopened.load(seed: seed);
      expect(reopened.isWrong(set, set.items.first), true);
      expect(
        prefs.getKeys().every((key) => !key.toLowerCase().contains('token')),
        true,
      );
      store.dispose();
      reopened.dispose();
    },
  );
  test('session survives restart and expired token refreshes', () async {
    final prefs = await SharedPreferences.getInstance();
    var refreshes = 0;
    final client = MockClient((request) async {
      if (request.url.host == 'securetoken.googleapis.com') {
        refreshes++;
        return http.Response(jsonEncode({
          'user_id': 'alice',
          'id_token': 'refreshed-id',
          'refresh_token': 'rotated-refresh',
          'expires_in': '3600',
        }), 200);
      }
      return http.Response(jsonEncode({
        'localId': 'alice',
        'email': 'a@example.com',
        'idToken': 'short-id',
        'refreshToken': 'initial-refresh',
        'expiresIn': '1',
      }), 200);
    });
    final first = AppStore(prefs, firebaseKey: 'test', client: client);
    await first.load(seed: seed);
    expect(await first.signIn('a@example.com', 'password'), true);
    final set = first.bundle.sets.first;
    await first.record(set, set.items.first, true);
    expect(first.completion(set), greaterThan(0));
    first.dispose();

    final reopened = AppStore(prefs, firebaseKey: 'test', client: client);
    await reopened.load(seed: seed);
    expect(reopened.uid, 'alice');
    expect(reopened.email, 'a@example.com');
    expect(reopened.completion(set), greaterThan(0));
    expect(refreshes, 1);
    expect(prefs.getKeys().every((key) => !key.contains('token')), true);
    await reopened.signOut();
    final guest = AppStore(prefs, firebaseKey: 'test', client: client);
    await guest.load(seed: seed);
    expect(guest.uid, isNull);
    guest.dispose();
    reopened.dispose();
  });
  test('corrupt cached release falls back to bundled content', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('content:v1', 'broken');
    final store = AppStore(prefs);
    await store.load(seed: seed);
    expect(store.bundle.sets.length, 5);
    expect(store.releaseId, 'bundled-demo');
    store.dispose();
  });
  test('production content API is configured by default', () async {
    final store = AppStore(await SharedPreferences.getInstance());
    expect(store.cloudConfigured, true);
    expect(store.apiUrl, AppStore.productionApiUrl);
    store.dispose();
  });
  test('older cached content gains bundled English sets without losing its release', () async {
    final prefs = await SharedPreferences.getInstance();
    final original = jsonDecode(seed) as Map<String, dynamic>;
    final oldContent = jsonEncode({
      ...original,
      'sets': (original['sets'] as List).sublist(0, 3),
    });
    await prefs.setString('content:v1', jsonEncode({
      'releaseId': 'older-release',
      'payload': oldContent,
      'sha256': sha256.convert(utf8.encode(oldContent)).toString(),
    }));
    final store = AppStore(prefs);
    await store.load(seed: seed);
    expect(store.releaseId, 'older-release');
    expect(store.bundle.sets.length, 5);
    expect(store.bundle.sets.last.id, 'english-paper-3b-phrases');
    store.dispose();
  });
  test(
    'guest and signed-in progress stay isolated, cloud conflicts retry',
    () async {
      var uploads = 0;
      final client = MockClient((r) async {
        if (r.url.host == 'identitytoolkit.googleapis.com') {
          return http.Response(
            jsonEncode({
              'localId': 'alice',
              'email': 'a@example.com',
              'idToken': 'token',
              'refreshToken': 'refresh',
              'expiresIn': '3600',
            }),
            200,
          );
        }
        if (r.method == 'GET') {
          return http.Response('{"items":{},"version":null}', 200);
        }
        uploads++;
        return http.Response('{}', uploads == 1 ? 409 : 200);
      });
      final store = AppStore(
        await SharedPreferences.getInstance(),
        client: client,
        apiUrl: 'https://study.example',
        firebaseKey: 'test',
      );
      await store.load(seed: seed);
      final set = store.bundle.sets.first;
      await store.record(set, set.items.first, false);
      expect(await store.signIn('a@example.com', 'password'), true);
      expect(store.progress, isEmpty);
      await store.record(set, set.items[1], true);
      await store.syncProgress();
      expect(uploads, 2);
      expect(store.status, contains('synced'));
      await store.signOut();
      expect(store.isWrong(set, set.items.first), true);
      expect(store.progress.containsKey(set.items[1].key(set.id)), false);
      store.dispose();
    },
  );
  test(
    'Google email collision links to the password account and keeps progress',
    () async {
      final googleToken =
          'header.${base64Url.encode(utf8.encode(jsonEncode({'email': 'a@example.com'})))}.signature';
      var linked = false;
      final client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        if (request.url.path.endsWith('signInWithIdp')) {
          if (body['idToken'] == null) {
            return http.Response('{"error":{"message":"EMAIL_EXISTS"}}', 400);
          }
          linked = true;
          return http.Response(
            jsonEncode({
              'localId': 'password-uid',
              'email': 'a@example.com',
              'idToken': 'linked-token',
              'refreshToken': 'linked-refresh',
              'expiresIn': '3600',
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'localId': 'password-uid',
            'email': 'a@example.com',
            'idToken': 'password-token',
            'refreshToken': 'password-refresh',
            'expiresIn': '3600',
          }),
          200,
        );
      });
      final store = AppStore(
        await SharedPreferences.getInstance(),
        client: client,
        firebaseKey: 'test',
        googleTokenProvider: () async => googleToken,
      );
      await store.load(seed: seed);
      expect(await store.signInWithGoogle(), false);
      expect(store.uid, isNull);
      expect(await store.signIn('a@example.com', 'password'), true);
      expect(linked, true);
      expect(store.uid, 'password-uid');
      final set = store.bundle.sets.first;
      await store.record(set, set.items.first, false);
      await store.signOut();
      expect(await store.signIn('a@example.com', 'password'), true);
      expect(store.isWrong(set, set.items.first), true);
      store.dispose();
    },
  );

  test('account profile, verification and rotated credentials persist securely', () async {
    final prefs = await SharedPreferences.getInstance();
    var updates = 0;
    final client = MockClient((request) async {
      if (request.url.path.endsWith('lookup')) {
        return http.Response(jsonEncode({
          'users': [{
            'localId': 'alice',
            'email': 'alice@example.com',
            'displayName': 'Alice',
            'emailVerified': true,
            'providerUserInfo': [{'providerId': 'google.com'}],
          }],
        }), 200);
      }
      if (request.url.path.endsWith('update')) {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        if (updates > 0) expect(body['idToken'], 'rotated-1');
        updates++;
        return http.Response(jsonEncode({
          'localId': 'alice',
          'email': 'alice@example.com',
          'idToken': 'rotated-$updates',
          'refreshToken': 'refresh-$updates',
          'expiresIn': '3600',
        }), 200);
      }
      return http.Response(jsonEncode({
        'localId': 'alice',
        'email': 'alice@example.com',
        'idToken': 'signed-id',
        'refreshToken': 'signed-refresh',
        'expiresIn': '3600',
      }), 200);
    });
    final store = AppStore(prefs, client: client, firebaseKey: 'test');
    await store.load(seed: seed);
    expect(await store.signIn('alice@example.com', 'old-password'), true);
    expect(await store.refreshAccount(), true);
    expect(store.emailVerified, true);
    expect(store.googleConnected, true);
    expect(store.displayName, 'Alice');
    expect(await store.updateDisplayName('  Alice Updated  '), true);
    expect(store.displayName, 'Alice Updated');
    expect(await store.changePassword('safe-new-password'), true);
    expect(updates, 2);
    store.dispose();

    final reopened = AppStore(prefs, client: client, firebaseKey: 'test');
    await reopened.load(seed: seed);
    expect(reopened.uid, 'alice');
    expect(reopened.displayName, 'Alice Updated');
    expect(reopened.emailVerified, true);
    expect(reopened.googleConnected, true);
    expect(prefs.getKeys().every((key) => !key.contains('token')), true);
    reopened.dispose();
  });

  test('registration requests verification and password validation prevents API calls', () async {
    var verificationRequests = 0;
    var updateRequests = 0;
    final client = MockClient((request) async {
      if (request.url.path.endsWith('sendOobCode')) {
        verificationRequests++;
        expect((jsonDecode(request.body) as Map)['requestType'], 'VERIFY_EMAIL');
        return http.Response('{}', 200);
      }
      if (request.url.path.endsWith('update')) updateRequests++;
      return http.Response(jsonEncode({
        'localId': 'new-user',
        'email': 'new@example.com',
        'idToken': 'new-id',
        'refreshToken': 'new-refresh',
        'expiresIn': '3600',
      }), 200);
    });
    final store = AppStore(await SharedPreferences.getInstance(),
      client: client, firebaseKey: 'test');
    await store.load(seed: seed);
    expect(await store.signIn('new@example.com', 'strong-password', register: true), true);
    expect(verificationRequests, 1);
    expect(store.emailVerified, false);
    expect(store.status, contains('verify'));
    expect(await store.changePassword('short'), false);
    expect(updateRequests, 0);
    store.dispose();
  });

  test('real profile response without rotated tokens keeps the existing session', () async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('update')) {
        return http.Response('{"localId":"alice","displayName":"Updated name","emailVerified":false}', 200);
      }
      if (request.url.host == 'study.example') {
        expect(request.headers['authorization'], 'Bearer signed-id');
        return http.Response(request.method == 'GET' ? '{"items":{},"version":null}' : '{}', 200);
      }
      return http.Response(jsonEncode({
        'localId': 'alice', 'email': 'alice@example.com',
        'idToken': 'signed-id', 'refreshToken': 'signed-refresh',
        'expiresIn': '3600',
      }), 200);
    });
    final store = AppStore(await SharedPreferences.getInstance(),
      client: client, apiUrl: 'https://study.example', firebaseKey: 'test');
    await store.load(seed: seed);
    await store.signIn('alice@example.com', 'password');
    expect(await store.updateDisplayName('Updated name'), true);
    expect(store.displayName, 'Updated name');
    expect(await store.syncProgress(), true);
    // A missing token pair must still fail for security-sensitive updates.
    expect(await store.changePassword('new-strong-password'), false);
    store.dispose();
  });

  test('deleting an account erases only its cloud and local progress', () async {
    final requests = <String>[];
    final client = MockClient((request) async {
      if (request.url.host == 'study.example') {
        requests.add('cloud:' + request.method);
        expect(request.url.path, '/v1/progress');
        expect(request.headers['authorization'], 'Bearer signed-id');
        return http.Response('{}', 200);
      }
      if (request.url.path.endsWith('delete')) {
        requests.add('auth:delete');
        return http.Response('{}', 200);
      }
      return http.Response(jsonEncode({
        'localId': 'alice',
        'email': 'alice@example.com',
        'idToken': 'signed-id',
        'refreshToken': 'signed-refresh',
        'expiresIn': '3600',
      }), 200);
    });
    final prefs = await SharedPreferences.getInstance();
    final store = AppStore(prefs,
      client: client, apiUrl: 'https://study.example', firebaseKey: 'test');
    await store.load(seed: seed);
    final set = store.bundle.sets.first;
    await store.record(set, set.items.first, false);
    expect(await store.signIn('alice@example.com', 'password'), true);
    await store.record(set, set.items[1], true);
    expect(prefs.getString('progress:guest'), isNotNull);
    expect(prefs.getString('progress:alice'), isNotNull);
    expect(await store.deleteAccount(), true);
    expect(requests, ['cloud:DELETE', 'auth:delete']);
    expect(store.uid, isNull);
    expect(prefs.getString('progress:alice'), isNull);
    expect(prefs.getString('progress:guest'), isNotNull);
    expect(store.isWrong(set, set.items.first), true);
    store.dispose();
  });

  test('cloud deletion failure leaves Firebase account and local progress intact', () async {
    var authDeletes = 0;
    final client = MockClient((request) async {
      if (request.url.host == 'study.example') {
        return http.Response('{}', 503);
      }
      if (request.url.path.endsWith('delete')) authDeletes++;
      return http.Response(jsonEncode({
        'localId': 'alice',
        'email': 'alice@example.com',
        'idToken': 'signed-id',
        'refreshToken': 'signed-refresh',
        'expiresIn': '3600',
      }), 200);
    });
    final prefs = await SharedPreferences.getInstance();
    final store = AppStore(prefs,
      client: client, apiUrl: 'https://study.example', firebaseKey: 'test');
    await store.load(seed: seed);
    expect(await store.signIn('alice@example.com', 'password'), true);
    final set = store.bundle.sets.first;
    await store.record(set, set.items.first, true);
    expect(await store.deleteAccount(), false);
    expect(authDeletes, 0);
    expect(store.uid, 'alice');
    expect(prefs.getString('progress:alice'), isNotNull);
    store.dispose();
  });

  for (final networkFailure in [false, true]) {
    test('Auth deletion ${networkFailure ? 'timeout' : 'rejection'} preserves local progress and can be retried', () async {
      var authDeletes = 0;
      var cloudDeletes = 0;
      final client = MockClient((request) async {
        if (request.url.host == 'study.example') {
          cloudDeletes++;
          expect(request.method, 'DELETE');
          return http.Response('{"ok":true}', 200);
        }
        if (request.url.path.endsWith('delete')) {
          authDeletes++;
          if (authDeletes == 1) {
            if (networkFailure) throw TimeoutException('Lost Auth response');
            return http.Response('{"error":{"message":"CREDENTIAL_TOO_OLD_LOGIN_AGAIN"}}', 400);
          }
          return http.Response('{}', 200);
        }
        return http.Response(jsonEncode({
          'localId': 'alice', 'email': 'alice@example.com',
          'idToken': 'signed-id', 'refreshToken': 'signed-refresh',
          'expiresIn': '3600',
        }), 200);
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('progress:bob', '{}');
      final store = AppStore(prefs, client: client,
        apiUrl: 'https://study.example', firebaseKey: 'test');
      await store.load(seed: seed);
      final set = store.bundle.sets.first;
      await store.record(set, set.items.first, false);
      await store.signIn('alice@example.com', 'password');
      await store.record(set, set.items[1], true);
      final local = prefs.getString('progress:alice');
      expect(await store.deleteAccount(), false);
      expect(store.status, contains('Cloud progress was erased'));
      expect(store.uid, 'alice');
      expect(prefs.getString('progress:alice'), local);
      expect(store.progress, isNotEmpty);
      await store.signOut();
      await store.signIn('alice@example.com', 'password');
      expect(await store.deleteAccount(), true);
      expect(cloudDeletes, 2);
      expect(authDeletes, 2);
      expect(prefs.getString('progress:alice'), isNull);
      expect(prefs.getString('progress:bob'), '{}');
      expect(prefs.getString('progress:guest'), isNotNull);
      expect(store.uid, isNull);
      store.dispose();
    });
  }

  test('Google linking cannot switch the REST identity or its local progress', () async {
    final client = MockClient((request) async => http.Response(jsonEncode({
      'localId': request.url.path.endsWith('signInWithIdp') ? 'bob' : 'alice',
      'email': 'alice@example.com', 'idToken': 'signed-id',
      'refreshToken': 'signed-refresh', 'expiresIn': '3600',
    }), 200));
    final store = AppStore(await SharedPreferences.getInstance(),
      client: client, firebaseKey: 'test', googleTokenProvider: () async => 'google-token');
    await store.load(seed: seed);
    await store.signIn('alice@example.com', 'password');
    final set = store.bundle.sets.first;
    await store.record(set, set.items.first, false);
    expect(await store.signInWithGoogle(), false);
    expect(store.uid, 'alice');
    expect(store.googleConnected, false);
    expect(store.isWrong(set, set.items.first), true);
    store.dispose();
  });
}

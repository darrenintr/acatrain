import 'dart:convert';
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
      store.signOut();
      expect(await store.signIn('a@example.com', 'password'), true);
      expect(store.isWrong(set, set.items.first), true);
      store.dispose();
    },
  );
}

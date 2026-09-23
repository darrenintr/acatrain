import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

class AppStore extends ChangeNotifier {
  AppStore(
    this.prefs, {
    http.Client? client,
    this.apiUrl = const String.fromEnvironment('ACATRAIN_API_URL'),
    this.firebaseKey = const String.fromEnvironment('FIREBASE_WEB_API_KEY'),
    this.authContinueUrl =
        const String.fromEnvironment('ACATRAIN_AUTH_CONTINUE_URL'),
  }) : client = client ?? http.Client();

  final SharedPreferences prefs;
  final http.Client client;
  final String apiUrl, firebaseKey, authContinueUrl;

  ContentBundle bundle = const ContentBundle([]);
  String releaseId = 'bundled-demo';
  String status = 'Offline ready. Your progress stays on this device.';
  bool busy = false;
  String? uid, email, _idToken, _refreshToken;
  DateTime? _expiresAt;
  DateTime? lastContentSync;
  Map<String, ReviewState> progress = {};

  bool get cloudConfigured => apiUrl.isNotEmpty;
  String get _progressKey => 'progress:${uid ?? 'guest'}';

  Uri _uri(String path) {
    final uri = Uri.parse('${apiUrl.replaceAll(RegExp(r'/+$'), '')}$path');
    if (uri.scheme != 'https' &&
        !(uri.scheme == 'http' &&
            ['localhost', '127.0.0.1'].contains(uri.host))) {
      throw const FormatException(
        'The API must use HTTPS (except localhost)',
      );
    }
    return uri;
  }

  Uri _authContinueUri() {
    if (authContinueUrl.isEmpty) {
      throw const FormatException(
        'Set ACATRAIN_AUTH_CONTINUE_URL to an authorized HTTPS page before using email-link sign in.',
      );
    }
    final uri = Uri.parse(authContinueUrl);
    if (uri.scheme != 'https' &&
        !(uri.scheme == 'http' &&
            ['localhost', '127.0.0.1'].contains(uri.host))) {
      throw const FormatException(
        'The authentication continue URL must use HTTPS (except localhost).',
      );
    }
    return uri;
  }

  Uri _firebaseUri(String action) => Uri.https(
        'identitytoolkit.googleapis.com',
        '/v1/accounts:$action',
        {'key': firebaseKey},
      );

  Future<http.Response> _firebasePost(
    String action,
    Map<String, dynamic> body,
  ) {
    if (firebaseKey.isEmpty) {
      throw const FormatException(
        'Set FIREBASE_WEB_API_KEY to enable account sign in.',
      );
    }
    return client
        .post(
          _firebaseUri(action),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 20));
  }

  FormatException _firebaseFailure(
    http.Response response,
    String fallback,
  ) {
    String code = '';
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      code = ((body['error'] as Map?)?['message'] ?? '').toString();
      code = code.split(' : ').first.split(':').first;
    } catch (_) {
      return FormatException(fallback);
    }
    final message = switch (code) {
      'INVALID_EMAIL' => 'Enter a valid email address.',
      'EMAIL_EXISTS' => 'That email address already has an account.',
      'EMAIL_NOT_FOUND' ||
      'INVALID_PASSWORD' ||
      'INVALID_LOGIN_CREDENTIALS' =>
        'The email or password is incorrect.',
      'WEAK_PASSWORD' => 'Choose a stronger password with at least 6 characters.',
      'OPERATION_NOT_ALLOWED' =>
        'This sign-in method is not enabled in Firebase Authentication.',
      'TOO_MANY_ATTEMPTS_TRY_LATER' =>
        'Too many attempts. Try again later.',
      'EXPIRED_OOB_CODE' => 'That email link has expired. Request a new one.',
      'INVALID_OOB_CODE' => 'That email link or code is invalid.',
      _ => fallback,
    };
    return FormatException(message);
  }

  void _applySession(
    Map<String, dynamic> data, {
    String? fallbackEmail,
  }) {
    final nextUid = data['localId']?.toString();
    final nextIdToken = data['idToken']?.toString();
    final nextRefreshToken = data['refreshToken']?.toString();
    if (nextUid == null || nextIdToken == null || nextRefreshToken == null) {
      throw const FormatException('The authentication response was incomplete.');
    }
    uid = nextUid;
    email = data['email']?.toString() ?? fallbackEmail;
    _idToken = nextIdToken;
    _refreshToken = nextRefreshToken;
    final seconds = int.tryParse(data['expiresIn']?.toString() ?? '') ?? 3600;
    _expiresAt = DateTime.now().add(Duration(seconds: seconds));
    _loadProgress();
  }

  Future<void> load({String? seed}) async {
    bundle = ContentBundle.parse(
      seed ?? await rootBundle.loadString('assets/seed.json'),
    );
    final cached = prefs.getString('content:v1');
    if (cached != null) {
      try {
        final data = jsonDecode(cached) as Map<String, dynamic>;
        final payload = data['payload'] as String;
        if (sha256.convert(utf8.encode(payload)).toString() != data['sha256']) {
          throw const FormatException('Cache checksum mismatch');
        }
        final restored = ContentBundle.parse(payload);
        final restoredId = data['releaseId'] as String;
        bundle = restored;
        releaseId = restoredId;
        status = 'Using downloaded content. Available offline.';
      } catch (_) {
        status = 'Downloaded cache was invalid; using bundled content.';
      }
    }
    _loadProgress();
    notifyListeners();
  }

  void _loadProgress() {
    try {
      progress = decodeProgress(
        jsonDecode(prefs.getString(_progressKey) ?? '{}'),
      );
    } catch (_) {
      progress = {};
      status = 'Could not read local progress.';
    }
  }

  Future<void> _saveProgress() async {
    final ok = await prefs.setString(
      _progressKey,
      jsonEncode(progress.map((k, v) => MapEntry(k, v.toJson()))),
    );
    if (!ok) throw StateError('Local progress could not be saved');
  }

  List<StudyItem> dueItems(StudySet set) => set.items.where((item) {
        final state = progress[item.key(set.id)];
        return state == null || !state.dueAt.isAfter(DateTime.now());
      }).toList(growable: false);

  int dueCount(StudySet set) => dueItems(set).length;

  int get totalDue =>
      bundle.sets.fold(0, (n, set) => n + dueCount(set));

  int get mastered => bundle.sets.fold(
        0,
        (n, set) =>
            n +
            set.items
                .where(
                  (item) => (progress[item.key(set.id)]?.box ?? 0) >= 3,
                )
                .length,
      );

  bool isWrong(StudySet set, StudyItem item) =>
      progress[item.key(set.id)]?.wrong ?? false;

  Future<void> record(StudySet set, StudyItem item, bool correct) async {
    final key = item.key(set.id);
    progress[key] = nextReview(progress[key], correct, DateTime.now());
    try {
      await _saveProgress();
    } catch (_) {
      status = 'Progress is in memory, but local storage failed.';
    }
    notifyListeners();
  }

  Future<bool> _run(Future<void> Function() action) async {
    if (busy) return false;
    busy = true;
    notifyListeners();
    try {
      await action();
      return true;
    } catch (error) {
      status = error is FormatException
          ? error.message
          : 'Could not complete sync. Check your connection and configuration.';
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> syncContent() async {
    if (!cloudConfigured) {
      status =
          'Demo mode. Configure ACATRAIN_API_URL to receive published content.';
      notifyListeners();
      return;
    }
    await _run(() async {
      final response = await client
          .get(_uri('/v1/manifest'))
          .timeout(const Duration(seconds: 20));
      if (response.statusCode == 404) {
        throw const FormatException(
          'No content has been published yet. Offline content is unchanged.',
        );
      }
      if (response.statusCode != 200) {
        throw const FormatException(
          'Content server is unavailable. Offline content is unchanged.',
        );
      }
      final manifest = jsonDecode(response.body) as Map<String, dynamic>;
      if (manifest['schemaVersion'] != 1 ||
          manifest['minAppBuild'] != appBuild) {
        throw const FormatException(
          'New content requires an app update. Current content is unchanged.',
        );
      }
      final nextId = manifest['releaseId'] as String;
      if (!RegExp(r'^[a-z0-9][a-z0-9_-]{0,63}$').hasMatch(nextId)) {
        throw const FormatException('Invalid release ID');
      }
      if (nextId == releaseId) {
        status = 'Content is up to date.';
        lastContentSync = DateTime.now();
        return;
      }
      final downloaded = await client
          .get(_uri('/v1/releases/$nextId'))
          .timeout(const Duration(seconds: 30));
      if (downloaded.statusCode != 200 ||
          downloaded.bodyBytes.length > maxContentBytes) {
        throw const FormatException(
          'Content download failed. Current content is unchanged.',
        );
      }
      final hash = sha256.convert(downloaded.bodyBytes).toString();
      if (hash != manifest['sha256']) {
        throw const FormatException(
          'Content integrity check failed. Current content is unchanged.',
        );
      }
      final payload = utf8.decode(downloaded.bodyBytes);
      final next = ContentBundle.parse(payload);
      final saved = await prefs.setString(
        'content:v1',
        jsonEncode({
          'releaseId': nextId,
          'payload': payload,
          'sha256': hash,
        }),
      );
      if (!saved) {
        throw const FormatException(
          'Could not save content for offline use.',
        );
      }
      bundle = next;
      releaseId = nextId;
      lastContentSync = DateTime.now();
      status =
          'New content is ready. Existing study sessions stay unchanged.';
    });
  }

  Future<bool> signIn(
    String address,
    String password, {
    bool register = false,
  }) =>
      _run(() async {
        final action = register ? 'signUp' : 'signInWithPassword';
        final response = await _firebasePost(action, {
          'email': address.trim(),
          'password': password,
          'returnSecureToken': true,
        });
        if (response.statusCode != 200) {
          throw _firebaseFailure(
            response,
            register
                ? 'Could not create the account.'
                : 'Could not sign in with email and password.',
          );
        }
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        _applySession(data, fallbackEmail: address.trim());
        status =
            'Signed in. Use Sync progress to merge this account across devices.';
      });

  Future<bool> signInWithGoogle() => _run(() async {
        if (kIsWeb ||
            (defaultTargetPlatform != TargetPlatform.android &&
                defaultTargetPlatform != TargetPlatform.iOS)) {
          throw const FormatException(
            'Google sign-in is currently available in the Android and iOS apps.',
          );
        }

        GoogleSignInAccount account;
        try {
          account = await GoogleSignIn.instance.authenticate();
        } on GoogleSignInException catch (error) {
          if (error.code == GoogleSignInExceptionCode.canceled) {
            throw const FormatException('Google sign-in was canceled.');
          }
          throw const FormatException(
            'Google sign-in could not be completed. Check the app OAuth configuration.',
          );
        }

        final googleIdToken = account.authentication.idToken;
        if (googleIdToken == null || googleIdToken.isEmpty) {
          throw const FormatException(
            'Google did not return an ID token for this app.',
          );
        }
        if (firebaseKey.isEmpty) {
          throw const FormatException(
            'Set FIREBASE_WEB_API_KEY to enable account sign in.',
          );
        }

        final response = await client
            .post(
              _firebaseUri('signInWithIdp'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'requestUri': 'http://localhost',
                'postBody': Uri(
                  queryParameters: {
                    'id_token': googleIdToken,
                    'providerId': 'google.com',
                  },
                ).query,
                'returnIdpCredential': true,
                'returnSecureToken': true,
              }),
            )
            .timeout(const Duration(seconds: 20));

        if (response.statusCode != 200) {
          throw _firebaseFailure(
            response,
            'Could not sign in with Google.',
          );
        }

        final data = jsonDecode(response.body) as Map<String, dynamic>;
        _applySession(data, fallbackEmail: account.email);
        status =
            'Signed in with Google. Use Sync progress to merge progress across devices.';
      });

  Future<bool> sendPasswordReset(String address) => _run(() async {
        final response = await _firebasePost('sendOobCode', {
          'requestType': 'PASSWORD_RESET',
          'email': address.trim(),
        });
        if (response.statusCode != 200) {
          throw _firebaseFailure(
            response,
            'Could not send the password reset email.',
          );
        }
        status = 'Password reset email sent. Check your inbox.';
      });

  Future<bool> sendEmailSignInLink(String address) => _run(() async {
        final continueUri = _authContinueUri();
        final response = await _firebasePost('sendOobCode', {
          'requestType': 'EMAIL_SIGNIN',
          'email': address.trim(),
          'continueUrl': continueUri.toString(),
          'canHandleCodeInApp': true,
        });
        if (response.statusCode != 200) {
          throw _firebaseFailure(
            response,
            'Could not send the passwordless sign-in link.',
          );
        }
        status =
            'Sign-in link sent. Open it on Web, or paste the full link/code into Acatrain on another platform.';
      });

  String _extractEmailLinkCode(String input) {
    final raw = input.trim();
    if (raw.isEmpty) {
      throw const FormatException('Paste the email sign-in link or code.');
    }
    final uri = Uri.tryParse(raw);
    if (uri != null) {
      final direct = uri.queryParameters['oobCode'];
      if (direct != null && direct.isNotEmpty) return direct;
      final nested = uri.queryParameters['link'];
      if (nested != null && nested != raw) {
        return _extractEmailLinkCode(nested);
      }
    }
    return raw;
  }

  Future<bool> signInWithEmailLink(String address, String linkOrCode) =>
      _run(() async {
        final response = await _firebasePost('signInWithEmailLink', {
          'email': address.trim(),
          'oobCode': _extractEmailLinkCode(linkOrCode),
        });
        if (response.statusCode != 200) {
          throw _firebaseFailure(
            response,
            'Could not complete passwordless sign in.',
          );
        }
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        _applySession(data, fallbackEmail: address.trim());
        status =
            'Signed in with an email link. Use Sync progress to merge progress across devices.';
      });

  void signOut() {
    if (busy) return;
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      try {
        GoogleSignIn.instance.signOut().ignore();
      } catch (_) {
        // Unit tests and unsupported embedders may not register the native
        // Google Sign-In implementation. The local Firebase session must
        // still be cleared.
      }
    }
    uid = null;
    email = null;
    _idToken = null;
    _refreshToken = null;
    _expiresAt = null;
    _loadProgress();
    status = 'Signed out. Guest progress restored.';
    notifyListeners();
  }

  Future<String> _token() async {
    if (_idToken == null) {
      throw const FormatException('Sign in before syncing progress.');
    }
    if (_expiresAt != null &&
        DateTime.now().isBefore(
          _expiresAt!.subtract(const Duration(minutes: 1)),
        )) {
      return _idToken!;
    }
    final response = await client
        .post(
          Uri.https(
            'securetoken.googleapis.com',
            '/v1/token',
            {'key': firebaseKey},
          ),
          body: {
            'grant_type': 'refresh_token',
            'refresh_token': _refreshToken!,
          },
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw const FormatException(
        'Your session expired. Sign out and sign in again.',
      );
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['user_id'] != uid) {
      throw const FormatException(
        'Session identity mismatch. Sign in again.',
      );
    }
    _idToken = data['id_token'];
    _refreshToken = data['refresh_token'];
    _expiresAt = DateTime.now().add(
      Duration(seconds: int.parse(data['expires_in'])),
    );
    return _idToken!;
  }

  Future<void> syncProgress() async {
    await _run(() async {
      if (!cloudConfigured) {
        throw const FormatException(
          'Configure ACATRAIN_API_URL before syncing progress.',
        );
      }
      final headers = {
        'Authorization': 'Bearer ${await _token()}',
        'Content-Type': 'application/json',
      };
      for (var attempt = 0; attempt < 3; attempt++) {
        final response = await client
            .get(_uri('/v1/progress'), headers: headers)
            .timeout(const Duration(seconds: 20));
        if (response.statusCode != 200) {
          throw const FormatException(
            'Could not read cloud progress. Check your session and Firestore rules.',
          );
        }
        final remote = jsonDecode(response.body) as Map<String, dynamic>;
        final merged = mergeProgress(
          progress,
          decodeProgress(remote['items']),
        );
        final upload = await client
            .post(
              _uri('/v1/progress'),
              headers: headers,
              body: jsonEncode({
                'items': merged.map((k, v) => MapEntry(k, v.toJson())),
                'version': remote['version'],
              }),
            )
            .timeout(const Duration(seconds: 20));
        if (upload.statusCode == 409) continue;
        if (upload.statusCode != 200) {
          throw const FormatException(
            'Could not save cloud progress. Local progress is unchanged.',
          );
        }
        progress = mergeProgress(progress, merged);
        await _saveProgress();
        status = 'Progress synced. Most recent review wins per item.';
        return;
      }
      throw const FormatException(
        'Another device is syncing. Please retry; local progress is safe.',
      );
    });
  }

  @override
  void dispose() {
    client.close();
    super.dispose();
  }
}

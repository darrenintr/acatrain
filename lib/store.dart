import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'haptics.dart';
import 'models.dart';
import 'google_identity.dart';
import 'plan_icon.dart';

enum ItemStatus { missed, due, practised, new_ }

class AppStore extends ChangeNotifier {
  AppStore(
    this.prefs, {
    http.Client? client,
    FlutterSecureStorage? sessionStorage,
    this.googleTokenProvider,
    this.apiUrl = const String.fromEnvironment('ACATRAIN_API_URL'),
    this.firebaseKey = const String.fromEnvironment('FIREBASE_WEB_API_KEY'),
    this.authContinueUrl = const String.fromEnvironment(
      'ACATRAIN_AUTH_CONTINUE_URL',
    ),
  }) : client = client ?? http.Client(),
       sessionStorage = sessionStorage ?? const FlutterSecureStorage() {
    Haptics.level = hapticLevel;
  }

  final SharedPreferences prefs;
  final http.Client client;
  final FlutterSecureStorage sessionStorage;
  static const _sessionKey = 'acatrain.session.v1';
  final Future<String> Function()? googleTokenProvider;
  final String apiUrl, firebaseKey, authContinueUrl;

  ContentBundle bundle = const ContentBundle([]);
  String releaseId = 'bundled-demo';
  String status = 'Offline ready. Your progress stays on this device.';
  bool busy = false;

  /// True after a sync failed to reach the network; cleared by the next
  /// successful request. Studying carries on from saved content.
  bool offline = false;

  /// Counts content releases applied by [syncContent], so the UI can tell
  /// the learner that new study content is ready.
  final contentReleases = ValueNotifier<int>(0);
  String? uid, email, displayName, _idToken, _refreshToken;
  String? _pendingGoogleToken, _pendingGoogleEmail;
  DateTime? _expiresAt;
  DateTime? lastContentSync;
  Map<String, ReviewState> progress = {};
  List<StudySet> _bundledEnglishSets = const [];

  ContentBundle _withBundledEnglish(ContentBundle content) {
    final ids = content.sets.map((set) => set.id).toSet();
    return ContentBundle(List.unmodifiable([
      ...content.sets,
      for (final set in _bundledEnglishSets)
        if (!ids.contains(set.id)) set,
    ]));
  }

  bool get cloudConfigured => apiUrl.isNotEmpty;
  String? get pendingGoogleEmail => _pendingGoogleEmail;
  String get languageCode => prefs.getString('display-language') ?? 'en';
  String get appearance => prefs.getString('appearance') ?? 'system';

  Future<void> setLanguageCode(String value) async {
    await prefs.setString('display-language', value);
    notifyListeners();
  }

  Future<void> setAppearance(String value) async {
    await prefs.setString('appearance', value);
    notifyListeners();
  }

  /// Haptic strength on this device: 0 off, 1 subtle, 2 standard. Not synced.
  int get hapticLevel => (prefs.getInt('haptic-strength') ?? 2).clamp(0, 2);

  Future<void> setHapticLevel(int value) async {
    Haptics.level = value.clamp(0, 2);
    await prefs.setInt('haptic-strength', Haptics.level);
    notifyListeners();
  }

  /// 'system' follows the device's reduce-motion setting; 'reduced' always
  /// takes the reduce-motion path.
  String get motion => prefs.getString('motion') ?? 'system';

  Future<void> setMotion(String value) async {
    await prefs.setString('motion', value);
    notifyListeners();
  }

  /// The demo subscription tier: 'free', 'starter', 'pro' or 'max'. Nothing
  /// is ever charged; the tier only unlocks a themed look on this device.
  String get plan => prefs.getString('demo-plan') ?? 'free';

  Future<void> setPlan(String value) async {
    await prefs.setString('demo-plan', value);
    await PlanIcon.apply(value);
    notifyListeners();
  }

  /// The pretend billing record behind [plan] (renewal date, payment
  /// method, receipts), or null when nothing was ever "bought". Stored as
  /// JSON and interpreted by `DemoSubscription` in subscription.dart.
  Map<String, dynamic>? get demoSubscription {
    final raw = prefs.getString('demo-subscription');
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> setDemoSubscription(
    Map<String, dynamic>? value, {
    String? plan,
  }) async {
    if (value == null) {
      await prefs.remove('demo-subscription');
    } else {
      await prefs.setString('demo-subscription', jsonEncode(value));
    }
    if (plan != null) {
      await prefs.setString('demo-plan', plan);
      await PlanIcon.apply(plan);
    }
    notifyListeners();
  }

  String get _progressKey => 'progress:${uid ?? 'guest'}';

  Uri _uri(String path) {
    final uri = Uri.parse('${apiUrl.replaceAll(RegExp(r'/+$'), '')}$path');
    if (uri.scheme != 'https' &&
        !(uri.scheme == 'http' &&
            ['localhost', '127.0.0.1'].contains(uri.host))) {
      throw const FormatException('The API must use HTTPS (except localhost)');
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

  FormatException _firebaseFailure(http.Response response, String fallback) {
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
      'FEDERATED_USER_ID_ALREADY_LINKED' =>
        'This Google account is already linked to another account.',
      'EMAIL_EXISTS_WITH_DIFFERENT_CREDENTIAL' ||
      'ACCOUNT_EXISTS_WITH_DIFFERENT_CREDENTIAL' =>
        'This email already has an account. Sign in with your password to connect Google.',
      'EMAIL_NOT_FOUND' ||
      'INVALID_PASSWORD' ||
      'INVALID_LOGIN_CREDENTIALS' => 'The email or password is incorrect.',
      'WEAK_PASSWORD' =>
        'Choose a stronger password with at least 6 characters.',
      'OPERATION_NOT_ALLOWED' =>
        'This sign-in method is not enabled in Firebase Authentication.',
      'TOO_MANY_ATTEMPTS_TRY_LATER' => 'Too many attempts. Try again later.',
      'EXPIRED_OOB_CODE' => 'That email link has expired. Request a new one.',
      'INVALID_OOB_CODE' => 'That email link or code is invalid.',
      _ => fallback,
    };
    return FormatException(message);
  }

  Future<void> _applySession(Map<String, dynamic> data, {String? fallbackEmail}) async {
    final nextUid = data['localId']?.toString();
    final nextIdToken = data['idToken']?.toString();
    final nextRefreshToken = data['refreshToken']?.toString();
    if (nextUid == null || nextIdToken == null || nextRefreshToken == null) {
      throw const FormatException(
        'The authentication response was incomplete.',
      );
    }
    uid = nextUid;
    email = data['email']?.toString() ?? fallbackEmail;
    displayName = data['displayName']?.toString();
    _idToken = nextIdToken;
    _refreshToken = nextRefreshToken;
    final seconds = int.tryParse(data['expiresIn']?.toString() ?? '') ?? 3600;
    _expiresAt = DateTime.now().add(Duration(seconds: seconds));
    _loadProgress();
    await _saveSession();
  }

  Future<void> _saveSession() async {
    await sessionStorage.write(key: _sessionKey, value: jsonEncode({
      'uid': uid, 'email': email, 'displayName': displayName,
      'idToken': _idToken, 'refreshToken': _refreshToken,
      'expiresAt': _expiresAt?.toUtc().toIso8601String(),
    }));
  }

  Future<void> _restoreSession() async {
    try {
      final raw = await sessionStorage.read(key: _sessionKey);
      if (raw == null) return;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final restoredUid = data['uid'] as String?;
      final refresh = data['refreshToken'] as String?;
      if (restoredUid == null || restoredUid.isEmpty || refresh == null || refresh.isEmpty) {
        await sessionStorage.delete(key: _sessionKey);
        return;
      }
      uid = restoredUid;
      email = data['email'] as String?;
      displayName = data['displayName'] as String?;
      _idToken = data['idToken'] as String?;
      _refreshToken = refresh;
      _expiresAt = DateTime.tryParse(data['expiresAt']?.toString() ?? '');
      _loadProgress();
      if (firebaseKey.isNotEmpty && (_expiresAt == null ||
          !DateTime.now().isBefore(_expiresAt!.subtract(const Duration(minutes: 1))))) {
        try {
          await _token();
        } on FormatException {
          await _clearSession();
          status = 'Your session expired. Please sign in again.';
        } catch (_) {
          // Preserve offline progress and retry the refresh when online.
          status = 'Account restored offline. Connect to sync progress.';
        }
      }
    } catch (_) {
      // A damaged or unavailable secure store must not prevent offline use.
      status = 'Could not restore the saved account.';
    }
  }

  Future<void> _clearSession() async {
    uid = null;
    email = null;
    displayName = null;
    _idToken = null;
    _refreshToken = null;
    _expiresAt = null;
    _loadProgress();
    await sessionStorage.delete(key: _sessionKey);
  }

  Future<void> load({String? seed}) async {
    final bundled = ContentBundle.parse(
      seed ?? await rootBundle.loadString('assets/seed.json'),
    );
    _bundledEnglishSets = bundled.sets.where((set) =>
        set.id == 'english-conversational-vocab' ||
        set.id == 'english-paper-3b-phrases').toList(growable: false);
    bundle = bundled;
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
        bundle = _withBundledEnglish(restored);
        releaseId = restoredId;
        status = 'Using downloaded content. Available offline.';
      } catch (_) {
        status = 'Downloaded cache was invalid; using bundled content.';
      }
    }
    await _restoreSession();
    if (uid == null) _loadProgress();
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

  List<StudyItem> dueItems(StudySet set) => set.items
      .where((item) {
        final state = progress[item.key(set.id)];
        return state == null || !state.dueAt.isAfter(DateTime.now());
      })
      .toList(growable: false);

  int dueCount(StudySet set) => dueItems(set).length;

  int get totalDue => bundle.sets.fold(0, (n, set) => n + dueCount(set));

  int get mastered => bundle.sets.fold(
    0,
    (n, set) =>
        n +
        set.items
            .where((item) => (progress[item.key(set.id)]?.box ?? 0) >= 3)
            .length,
  );

  bool isWrong(StudySet set, StudyItem item) =>
      progress[item.key(set.id)]?.wrong ?? false;

  int missedCount(StudySet set) =>
      set.items.where((item) => isWrong(set, item)).length;

  int get totalMissed => bundle.sets.fold(0, (n, set) => n + missedCount(set));

  /// Items reviewed since local midnight.
  int get doneToday {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);
    return bundle.sets.fold(
      0,
      (n, set) =>
          n +
          set.items
              .where(
                (item) =>
                    progress[item.key(set.id)]?.updatedAt.isAfter(midnight) ??
                    false,
              )
              .length,
    );
  }

  /// Missed items, most recent first, with when they were missed.
  List<(StudySet, StudyItem, DateTime)> get recentMisses {
    final misses = [
      for (final set in bundle.sets)
        for (final item in set.items)
          if (isWrong(set, item))
            (set, item, progress[item.key(set.id)]!.updatedAt.toLocal()),
    ];
    misses.sort((a, b) => b.$3.compareTo(a.$3));
    return misses;
  }

  int practisedCount(StudySet set) =>
      set.items.where((item) => progress.containsKey(item.key(set.id))).length;

  /// Credit the first successful review immediately and grow toward mastery.
  double completion(StudySet set) {
    if (set.items.isEmpty) return 0;
    final credit = set.items.fold<double>(0, (total, item) {
      final state = progress[item.key(set.id)];
      if (state == null) return total;
      return total + (state.box == 0 ? 0.15 : (state.box / 3).clamp(0.0, 1.0));
    });
    return credit / set.items.length;
  }

  int get totalItems => bundle.sets.fold(0, (n, set) => n + set.items.length);

  ItemStatus statusOf(StudySet set, StudyItem item) {
    if (isWrong(set, item)) return ItemStatus.missed;
    final state = progress[item.key(set.id)];
    final due = state == null || !state.dueAt.isAfter(DateTime.now());
    if (due) return ItemStatus.due;
    return ItemStatus.practised;
  }

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
      offline = false;
      return true;
    } catch (error) {
      offline = error is! FormatException;
      status =
          error is FormatException
              ? error.message
              : 'Could not complete sync. Check your connection and configuration.';
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// Checks for published content. Returns whether the check succeeded.
  Future<bool> syncContent() async {
    if (!cloudConfigured) {
      status =
          'Demo mode. Configure ACATRAIN_API_URL to receive published content.';
      lastContentSync = DateTime.now();
      notifyListeners();
      return true;
    }
    return _run(() async {
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
        jsonEncode({'releaseId': nextId, 'payload': payload, 'sha256': hash}),
      );
      if (!saved) {
        throw const FormatException('Could not save content for offline use.');
      }
      bundle = _withBundledEnglish(next);
      releaseId = nextId;
      lastContentSync = DateTime.now();
      status = 'New content is ready. Existing study sessions stay unchanged.';
      contentReleases.value++;
    });
  }

  Future<bool> signIn(
    String address,
    String password, {
    bool register = false,
  }) => _run(() async {
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
    var data = jsonDecode(response.body) as Map<String, dynamic>;
    if (_pendingGoogleToken != null &&
        !register &&
        address.trim().toLowerCase() == _pendingGoogleEmail?.toLowerCase()) {
      data = await _exchangeGoogle(
        _pendingGoogleToken!,
        idToken: data['idToken'] as String,
      );
      _pendingGoogleToken = null;
      _pendingGoogleEmail = null;
    } else if (_pendingGoogleToken != null) {
      _pendingGoogleToken = null;
      _pendingGoogleEmail = null;
    }
    await _applySession(data, fallbackEmail: address.trim());
    if (!register) {
      try {
        await prepareGoogleIdentityPassword(address.trim(), password);
      } catch (_) {
        // REST sign-in succeeded. Web SDK setup is only needed later if
        // the user chooses to connect Google.
      }
    }
    status =
        'Signed in. Use Sync progress to merge this account across devices.';
  });

  Future<Map<String, dynamic>> _exchangeGoogle(
    String googleToken, {
    String? idToken,
  }) async {
    final response = await _firebasePost('signInWithIdp', {
      'requestUri': 'http://localhost',
      'postBody':
          Uri(
            queryParameters: {
              'id_token': googleToken,
              'providerId': 'google.com',
            },
          ).query,
      if (idToken != null) 'idToken': idToken,
      'returnIdpCredential': true,
      'returnSecureToken': true,
    });
    if (response.statusCode != 200) {
      final failure = _firebaseFailure(
        response,
        'Could not connect this Google account.',
      );
      if (failure.message == 'That email address already has an account.') {
        throw const FormatException(
          'This email already has an account. Sign in with its password to connect Google.',
        );
      }
      throw failure;
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<bool> signInWithGoogle() => _run(() async {
    final googleToken =
        await (googleTokenProvider?.call() ??
            googleIdentityToken(linkExisting: uid != null));
    String? googleEmail;
    try {
      final payload = googleToken.split('.')[1];
      googleEmail =
          (jsonDecode(
                    utf8.decode(base64Url.decode(base64Url.normalize(payload))),
                  )
                  as Map)['email']
              ?.toString();
    } catch (_) {
      // Firebase verifies the token; this untrusted claim is only used to
      // match the email entered in the password confirmation flow.
    }
    if (uid != null) {
      final previousUid = uid;
      // On Web, linkWithPopup has already linked the provider in Firebase.
      // A regular IdP sign-in now returns that same user's REST session.
      final data = await _exchangeGoogle(
        googleToken,
        idToken: kIsWeb ? null : await _token(),
      );
      if (data['localId'] != previousUid) {
        throw const FormatException(
          'Google could not be linked to the current account.',
        );
      }
      await _applySession(data, fallbackEmail: email);
      status =
          'Google is connected to your account. Your progress stays with this account.';
      return;
    }
    try {
      final data = await _exchangeGoogle(googleToken);
      if (data['needConfirmation'] == true || data['idToken'] == null) {
        _pendingGoogleToken = googleToken;
        _pendingGoogleEmail = data['email']?.toString();
        throw const FormatException(
          'This email already has an account. Sign in with its password to connect Google.',
        );
      }
      await _applySession(data);
      status =
          'Signed in with Google. Use Sync progress to merge progress across devices.';
    } on FormatException catch (error) {
      if (error.message.contains('already has an account') &&
          googleEmail != null) {
        _pendingGoogleToken = googleToken;
        _pendingGoogleEmail = googleEmail;
      }
      rethrow;
    }
  });

  Future<bool> updateDisplayName(String name) => _run(() async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.length > 80) {
      throw const FormatException('Choose a name between 1 and 80 characters.');
    }
    final response = await _firebasePost('update', {
      'idToken': await _token(),
      'displayName': trimmed,
      'returnSecureToken': true,
    });
    if (response.statusCode != 200) {
      throw _firebaseFailure(response, 'Could not save your name.');
    }
    displayName = trimmed;
    status = 'Personal info saved.';
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

  Future<bool> signInWithEmailLink(
    String address,
    String linkOrCode,
  ) => _run(() async {
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
    await _applySession(data, fallbackEmail: address.trim());
    status =
        'Signed in with an email link. Use Sync progress to merge progress across devices.';
  });

  Future<void> signOut() async {
    if (busy) return;
    signOutGoogleIdentity().ignore();
    _pendingGoogleToken = null;
    _pendingGoogleEmail = null;
    await _clearSession();
    status = 'Signed out. Guest progress restored.';
    notifyListeners();
  }

  Future<String> _token() async {
    if (_refreshToken == null) {
      throw const FormatException('Sign in before syncing progress.');
    }
    if (_idToken != null && _expiresAt != null &&
        DateTime.now().isBefore(
          _expiresAt!.subtract(const Duration(minutes: 1)),
        )) {
      return _idToken!;
    }
    final response = await client
        .post(
          Uri.https('securetoken.googleapis.com', '/v1/token', {
            'key': firebaseKey,
          }),
          body: {
            'grant_type': 'refresh_token',
            'refresh_token': _refreshToken!,
          },
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      if (response.statusCode == 400 || response.statusCode == 401) {
        await _clearSession();
        notifyListeners();
        throw const FormatException('Your session expired. Please sign in again.');
      }
      throw Exception('Could not refresh the session. Check your connection.');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['user_id'] != uid) {
      throw const FormatException('Session identity mismatch. Sign in again.');
    }
    _idToken = data['id_token'];
    _refreshToken = data['refresh_token'];
    _expiresAt = DateTime.now().add(
      Duration(seconds: int.parse(data['expires_in'])),
    );
    await _saveSession();
    return _idToken!;
  }

  Future<bool> syncProgress() async {
    return _run(() async {
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
        final merged = mergeProgress(progress, decodeProgress(remote['items']));
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
    contentReleases.dispose();
    client.close();
    super.dispose();
  }
}

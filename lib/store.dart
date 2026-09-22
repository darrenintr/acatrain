import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

class AppStore extends ChangeNotifier {
  AppStore(this.prefs, {http.Client? client,
    this.apiUrl = const String.fromEnvironment('ACATRAIN_API_URL'),
    this.firebaseKey = const String.fromEnvironment('FIREBASE_WEB_API_KEY')})
    : client = client ?? http.Client();
  final SharedPreferences prefs;
  final http.Client client;
  final String apiUrl, firebaseKey;
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
        !(uri.scheme == 'http' && ['localhost', '127.0.0.1'].contains(uri.host))) {
      throw const FormatException('The API must use HTTPS (except localhost)');
    }
    return uri;
  }
  Future<void> load({String? seed}) async {
    bundle = ContentBundle.parse(seed ?? await rootBundle.loadString('assets/seed.json'));
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
        bundle = restored; releaseId = restoredId;
        status = 'Using downloaded content. Available offline.';
      } catch (_) { status = 'Downloaded cache was invalid; using bundled content.'; }
    }
    _loadProgress(); notifyListeners();
  }
  void _loadProgress() {
    try { progress = decodeProgress(jsonDecode(prefs.getString(_progressKey) ?? '{}')); }
    catch (_) { progress = {}; status = 'Could not read local progress.'; }
  }
  Future<void> _saveProgress() async {
    final ok = await prefs.setString(_progressKey,
        jsonEncode(progress.map((k, v) => MapEntry(k, v.toJson()))));
    if (!ok) throw StateError('Local progress could not be saved');
  }
  int dueCount(StudySet set) => set.items.where((item) {
    final state = progress[item.key(set.id)];
    return state == null || !state.dueAt.isAfter(DateTime.now());
  }).length;
  int get totalDue => bundle.sets.fold(0, (n, set) => n + dueCount(set));
  int get mastered => bundle.sets.fold(0, (n, set) => n + set.items
      .where((item) => (progress[item.key(set.id)]?.box ?? 0) >= 3).length);
  bool isWrong(StudySet set, StudyItem item) => progress[item.key(set.id)]?.wrong ?? false;
  Future<void> record(StudySet set, StudyItem item, bool correct) async {
    final key = item.key(set.id);
    progress[key] = nextReview(progress[key], correct, DateTime.now());
    try { await _saveProgress(); }
    catch (_) { status = 'Progress is in memory, but local storage failed.'; }
    notifyListeners();
  }
  Future<bool> _run(Future<void> Function() action) async {
    if (busy) return false;
    busy = true; notifyListeners();
    try { await action(); return true; }
    catch (error) {
      status = error is FormatException ? error.message :
          'Could not complete sync. Check your connection and configuration.';
      return false;
    } finally { busy = false; notifyListeners(); }
  }
  Future<void> syncContent() async {
    if (!cloudConfigured) { status = 'Demo mode. Configure ACATRAIN_API_URL to receive published content.'; notifyListeners(); return; }
    await _run(() async {
      final response = await client.get(_uri('/v1/manifest')).timeout(const Duration(seconds: 20));
      if (response.statusCode == 404) throw const FormatException('No content has been published yet. Offline content is unchanged.');
      if (response.statusCode != 200) throw const FormatException('Content server is unavailable. Offline content is unchanged.');
      final manifest = jsonDecode(response.body) as Map<String, dynamic>;
      if (manifest['schemaVersion'] != 1 || manifest['minAppBuild'] != appBuild) {
        throw const FormatException('New content requires an app update. Current content is unchanged.');
      }
      final nextId = manifest['releaseId'] as String;
      if (!RegExp(r'^[a-z0-9][a-z0-9_-]{0,63}$').hasMatch(nextId)) {
        throw const FormatException('Invalid release ID');
      }
      if (nextId == releaseId) { status = 'Content is up to date.'; lastContentSync = DateTime.now(); return; }
      final downloaded = await client.get(_uri('/v1/releases/$nextId')).timeout(const Duration(seconds: 30));
      if (downloaded.statusCode != 200 || downloaded.bodyBytes.length > maxContentBytes) {
        throw const FormatException('Content download failed. Current content is unchanged.');
      }
      final hash = sha256.convert(downloaded.bodyBytes).toString();
      if (hash != manifest['sha256']) throw const FormatException('Content integrity check failed. Current content is unchanged.');
      final payload = utf8.decode(downloaded.bodyBytes);
      final next = ContentBundle.parse(payload);
      final saved = await prefs.setString('content:v1', jsonEncode({
        'releaseId': nextId, 'payload': payload, 'sha256': hash}));
      if (!saved) throw const FormatException('Could not save content for offline use.');
      // Swap only after the complete release is validated and saved.
      bundle = next; releaseId = nextId; lastContentSync = DateTime.now();
      status = 'New content is ready. Existing study sessions stay unchanged.';
    });
  }
  Future<bool> signIn(String address, String password, {bool register = false}) => _run(() async {
    if (firebaseKey.isEmpty) throw const FormatException('Set FIREBASE_WEB_API_KEY to enable sign in.');
    final action = register ? 'signUp' : 'signInWithPassword';
    final response = await client.post(
      Uri.https('identitytoolkit.googleapis.com', '/v1/accounts:$action', {'key': firebaseKey}),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': address.trim(), 'password': password, 'returnSecureToken': true})
    ).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) throw const FormatException('Sign in failed. Check the email/password and Firebase Email/Password provider.');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    uid = data['localId']; email = data['email']; _idToken = data['idToken'];
    _refreshToken = data['refreshToken'];
    _expiresAt = DateTime.now().add(Duration(seconds: int.parse(data['expiresIn'])));
    _loadProgress();
    status = 'Signed in. Use Sync progress to merge this account across devices.';
  });
  void signOut() {
    if (busy) return;
    uid = null; email = null; _idToken = null; _refreshToken = null; _expiresAt = null;
    _loadProgress(); status = 'Signed out. Guest progress restored.'; notifyListeners();
  }
  Future<String> _token() async {
    if (_idToken == null) throw const FormatException('Sign in before syncing progress.');
    if (_expiresAt != null && DateTime.now().isBefore(_expiresAt!.subtract(const Duration(minutes: 1)))) return _idToken!;
    final response = await client.post(Uri.https('securetoken.googleapis.com', '/v1/token', {'key': firebaseKey}),
      body: {'grant_type': 'refresh_token', 'refresh_token': _refreshToken!}
    ).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) throw const FormatException('Your session expired. Sign out and sign in again.');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['user_id'] != uid) throw const FormatException('Session identity mismatch. Sign in again.');
    _idToken = data['id_token']; _refreshToken = data['refresh_token'];
    _expiresAt = DateTime.now().add(Duration(seconds: int.parse(data['expires_in'])));
    return _idToken!;
  }
  Future<void> syncProgress() async {
    await _run(() async {
      if (!cloudConfigured) throw const FormatException('Configure ACATRAIN_API_URL before syncing progress.');
      final headers = {'Authorization': 'Bearer ${await _token()}', 'Content-Type': 'application/json'};
      for (var attempt = 0; attempt < 3; attempt++) {
        final response = await client.get(_uri('/v1/progress'), headers: headers).timeout(const Duration(seconds: 20));
        if (response.statusCode != 200) throw const FormatException('Could not read cloud progress. Check your session and Firestore rules.');
        final remote = jsonDecode(response.body) as Map<String, dynamic>;
        final merged = mergeProgress(progress, decodeProgress(remote['items']));
        final upload = await client.post(_uri('/v1/progress'), headers: headers,
          body: jsonEncode({'items': merged.map((k, v) => MapEntry(k, v.toJson())), 'version': remote['version']})
        ).timeout(const Duration(seconds: 20));
        if (upload.statusCode == 409) continue;
        if (upload.statusCode != 200) throw const FormatException('Could not save cloud progress. Local progress is unchanged.');
        progress = mergeProgress(progress, merged);
        await _saveProgress(); status = 'Progress synced. Most recent review wins per item.'; return;
      }
      throw const FormatException('Another device is syncing. Please retry; local progress is safe.');
    });
  }
  @override
  void dispose() { client.close(); super.dispose(); }
}

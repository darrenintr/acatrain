import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

Future<void> initializeGoogleIdentity() async {
  const apiKey = String.fromEnvironment('FIREBASE_WEB_API_KEY');
  const appId = String.fromEnvironment('FIREBASE_WEB_APP_ID');
  const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  const senderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  const configuredAuthDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');
  if (apiKey.isEmpty ||
      appId.isEmpty ||
      projectId.isEmpty ||
      senderId.isEmpty) {
    return;
  }
  await Firebase.initializeApp(
    options: FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      projectId: projectId,
      messagingSenderId: senderId,
      authDomain:
          configuredAuthDomain.isEmpty
              ? '$projectId.firebaseapp.com'
              : configuredAuthDomain,
    ),
  );
}

Future<void> prepareGoogleIdentityPassword(
  String email,
  String password,
) async {
  if (Firebase.apps.isEmpty) return;
  await FirebaseAuth.instance.signInWithEmailAndPassword(
    email: email,
    password: password,
  );
}

Future<String> googleIdentityToken({bool linkExisting = false}) async {
  if (Firebase.apps.isEmpty) {
    throw const FormatException(
      'Set Firebase web app ID, project ID and sender ID to enable Google sign-in on Web.',
    );
  }
  try {
    final auth = FirebaseAuth.instance;
    final alreadyLinked =
        auth.currentUser?.providerData.any(
          (provider) => provider.providerId == 'google.com',
        ) ??
        false;
    final result =
        linkExisting && auth.currentUser != null && !alreadyLinked
            ? await auth.currentUser!.linkWithPopup(GoogleAuthProvider())
            : await auth.signInWithPopup(GoogleAuthProvider());
    final token = (result.credential as OAuthCredential?)?.idToken;
    if (token == null || token.isEmpty) {
      throw const FormatException('Google did not return an ID token.');
    }
    return token;
  } on FirebaseAuthException catch (error) {
    if (error.code == 'account-exists-with-different-credential') {
      throw const FormatException(
        'This email already has a password account. Sign in with your password, then connect Google in Personal info.',
      );
    }
    throw FormatException(
      error.message ?? 'Google sign-in could not be completed.',
    );
  }
}

Future<void> signOutGoogleIdentity() async {
  if (Firebase.apps.isNotEmpty) await FirebaseAuth.instance.signOut();
}

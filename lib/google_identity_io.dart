import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

Future<void> initializeGoogleIdentity() async {
  if (defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS) {
    await GoogleSignIn.instance.initialize();
  }
}

Future<void> prepareGoogleIdentityPassword(
  String email,
  String password,
) async {}

Future<String> googleIdentityToken({bool linkExisting = false}) async {
  if (defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS) {
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
    final token = account.authentication.idToken;
    if (token == null || token.isEmpty) {
      throw const FormatException('Google did not return an ID token.');
    }
    return token;
  }

  // Installed desktop apps use a system browser and a one-time loopback
  // callback. A desktop OAuth client must be configured in Google Cloud.
  const clientId = String.fromEnvironment('GOOGLE_DESKTOP_CLIENT_ID');
  if (clientId.isEmpty) {
    throw const FormatException(
      'Set GOOGLE_DESKTOP_CLIENT_ID to enable Google sign-in on desktop.',
    );
  }
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final random = Random.secure();
  String randomUrlSafe(int length) => base64Url
      .encode(List<int>.generate(length, (_) => random.nextInt(256)))
      .replaceAll('=', '');
  final state = randomUrlSafe(32);
  final verifier = randomUrlSafe(48);
  final challenge = base64Url
      .encode(sha256.convert(ascii.encode(verifier)).bytes)
      .replaceAll('=', '');
  final redirect = 'http://127.0.0.1:${server.port}/callback';
  final authorization = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
    'client_id': clientId,
    'redirect_uri': redirect,
    'response_type': 'code',
    'scope': 'openid email profile',
    'state': state,
    'code_challenge': challenge,
    'code_challenge_method': 'S256',
  });
  try {
    if (!await launchUrl(authorization, mode: LaunchMode.externalApplication)) {
      throw const FormatException(
        'Could not open the browser for Google sign-in.',
      );
    }
    final request = await server.first.timeout(const Duration(minutes: 3));
    final parameters = request.uri.queryParameters;
    request.response.headers.contentType = ContentType.html;
    request.response.write(
      '<!doctype html><title>Acatrain</title><p>Return to Acatrain to finish signing in.</p>',
    );
    await request.response.close();
    if (parameters['state'] != state || parameters['code'] == null) {
      throw const FormatException(
        'Google sign-in was canceled or could not be verified.',
      );
    }
    final response = await http
        .post(
          Uri.https('oauth2.googleapis.com', '/token'),
          body: {
            'client_id': clientId,
            'code': parameters['code']!,
            'code_verifier': verifier,
            'redirect_uri': redirect,
            'grant_type': 'authorization_code',
          },
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw const FormatException('Google could not complete desktop sign-in.');
    }
    final token =
        (jsonDecode(response.body) as Map<String, dynamic>)['id_token']
            as String?;
    if (token == null || token.isEmpty) {
      throw const FormatException('Google did not return an ID token.');
    }
    return token;
  } on TimeoutException {
    throw const FormatException('Google sign-in timed out. Please try again.');
  } finally {
    await server.close(force: true);
  }
}

Future<void> signOutGoogleIdentity() async {
  if (defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS) {
    await GoogleSignIn.instance.signOut();
  }
}

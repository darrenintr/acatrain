import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:acatrain/app/acatrain_app.dart';
import 'package:acatrain/google_identity.dart';
import 'package:acatrain/plan_icon.dart';
import 'package:acatrain/store.dart';
import 'package:acatrain/subscription.dart';

/// One production bootstrap path; all platform initialization stays here.
Future<void> launchAcatrain() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = AppStore(await SharedPreferences.getInstance());
  runApp(AcatrainApp(store: store, ready: initializeAcatrain(store)));
}

/// Start-up work that runs behind the launch animation.
Future<void> initializeAcatrain(AppStore store) async {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    try {
      await FlutterDisplayMode.setHighRefreshRate();
    } catch (_) {
      // The system remains in automatic display mode when no override is
      // available. Flutter animations continue to follow the platform vsync.
    }
  }
  await initializeGoogleIdentity();
  await store.load();
  // Bill renewals or end cancelled plans that fell due while closed.
  await settleDemoSubscription(store);
  await PlanIcon.apply(store.plan);
  if (store.cloudConfigured) unawaited(store.syncContent());
}

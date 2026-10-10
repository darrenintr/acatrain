import 'dart:io';

import 'package:acatrain/app/acatrain_app.dart';
import 'package:acatrain/core/design_system/acatrain_theme.dart';
import 'package:acatrain/features/shell/presentation/home_shell.dart';
import 'package:acatrain/main.dart' as legacy;
import 'package:acatrain/store.dart';
import 'package:acatrain/subscription.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the shared design system preserves the current free-plan palette', () {
    final theme = buildAcatrainTheme(Brightness.light, AcatrainPlan.free);
    expect(theme.colorScheme.primary, const Color(0xFF36684F));
    expect(theme.textTheme.bodyMedium?.fontFamily, acatrainFontFamily);
  });

  testWidgets('legacy main.dart entry point delegates to the feature shell', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    final store = AppStore(await SharedPreferences.getInstance());
    await store.load(seed: File('assets/seed.json').readAsStringSync());
    await tester.pumpWidget(legacy.AcatrainApp(store: store));
    await tester.pumpAndSettle();
    expect(find.byType(AcatrainApp), findsOneWidget);
    expect(find.byType(HomeShell), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    store.dispose();
  });
}

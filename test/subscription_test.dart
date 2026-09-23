import 'dart:io';

import 'package:acatrain/main.dart';
import 'package:acatrain/store.dart';
import 'package:acatrain/subscription.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Future<AppStore> store() async {
    SharedPreferences.setMockInitialValues({});
    final state = AppStore(await SharedPreferences.getInstance());
    await state.load(seed: File('assets/seed.json').readAsStringSync());
    return state;
  }

  // The plan art shimmers forever, so step time instead of pumpAndSettle.
  Future<void> wait(WidgetTester tester, int ms) async {
    for (var elapsed = 0; elapsed < ms; elapsed += 100) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  test('plan persists and unknown ids fall back to Free', () async {
    final state = await store();
    expect(AcatrainPlan.fromId(state.plan), AcatrainPlan.free);
    await state.setPlan('max');
    expect(AppStore(state.prefs).plan, 'max');
    expect(AcatrainPlan.fromId('bogus'), AcatrainPlan.free);
    for (final plan in AcatrainPlan.values.skip(1)) {
      expect(planColorScheme(plan, Brightness.light), isNotNull);
      expect(planColorScheme(plan, Brightness.dark), isNotNull);
    }
    state.dispose();
  });

  for (final size in [const Size(360, 740), const Size(1440, 1400)]) {
    for (final (method, confirm, plan, price) in [
      ('Google Play', 'Subscribe', AcatrainPlan.starter, r'$5.00'),
      ('App Store (iOS)', 'Double-Click to Pay', AcatrainPlan.pro, r'$10.00'),
      ('Stripe (Web)', r'Subscribe · $20.00', AcatrainPlan.max, r'$20.00'),
    ]) {
      testWidgets(
        '$method demo checkout unlocks ${plan.label} at ${size.width}',
        (tester) async {
          final state = await store();
          await tester.binding.setSurfaceSize(size);
          await tester.pumpWidget(
            MaterialApp(home: SubscriptionPage(store: state)),
          );
          await wait(tester, 400);
          await tester.ensureVisible(find.text('Subscribe · $price'));
          await wait(tester, 400);
          await tester.tap(find.text('Subscribe · $price'));
          await wait(tester, 600);
          await tester.tap(find.text(method));
          await tester.tap(find.text('Continue'));
          await wait(tester, 800);
          expect(find.text('Simulated payment · not charged'), findsOneWidget);
          await tester.tap(find.text(confirm).last);
          await wait(tester, 4000);
          expect(state.plan, plan.id);
          expect(find.text('Welcome to ${plan.label}'), findsOneWidget);
          await wait(tester, 4200);
          expect(find.text('Welcome to ${plan.label}'), findsNothing);
          expect(
            find.text('Current plan', skipOffstage: false),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          await tester.binding.setSurfaceSize(null);
          await tester.pumpWidget(const SizedBox());
          state.dispose();
        },
      );
    }
  }

  testWidgets('paid plan themes the whole app', (tester) async {
    final state = await store();
    await state.setPlan('max');
    await tester.pumpWidget(AcatrainApp(store: state));
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(Scaffold).first);
    expect(Theme.of(context).colorScheme.primary, const Color(0xFF1B1812));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    state.dispose();
  });
}

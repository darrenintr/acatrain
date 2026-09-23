import 'dart:io';

import 'package:acatrain/demo_checkout.dart';
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

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await wait(tester, 300);
    await tester.tap(finder);
  }

  Future<void> openCheckout(
    WidgetTester tester,
    AppStore state,
    String action,
    String method,
  ) async {
    await tester.pumpWidget(MaterialApp(home: SubscriptionPage(store: state)));
    await wait(tester, 400);
    await tapVisible(tester, find.text(action));
    await wait(tester, 600);
    await tester.tap(find.text(method));
    await tester.tap(find.text('Continue'));
    await wait(tester, 800);
    expect(find.text('Simulated payment · not charged'), findsOneWidget);
  }

  Future<void> fillStripe(WidgetTester tester, String card) async {
    Finder field(String hint) => find.widgetWithText(TextField, hint);
    await tester.enterText(field('you@example.com'), 'learner@example.com');
    await tester.enterText(field('1234 1234 1234 1234'), card);
    await tester.enterText(field('MM / YY'), '1240');
    await tester.enterText(field('CVC'), '123');
    await tester.enterText(field('Full name on card'), 'Ada Learner');
    await tester.enterText(field('ZIP'), '94107');
    await tester.pump();
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

  test('pricing, proration and money formatting', () {
    expect(AcatrainPlan.pro.priceCents(BillingCycle.monthly), 1000);
    expect(AcatrainPlan.pro.priceCents(BillingCycle.yearly), 10000);
    expect(formatMoney(123456), r'$1,234.56');
    expect(
      BillingCycle.monthly.advance(DateTime(2026, 1, 31)),
      DateTime(2026, 2, 28),
    );

    final start = DateTime(2026, 9, 1);
    final starter = DemoSubscription(
      plan: AcatrainPlan.starter,
      cycle: BillingCycle.monthly,
      method: DemoPaymentMethod.stripeWeb,
      instrument: 'Visa ·· 4242',
      memberSince: start,
      memberNumber: '1234',
      periodStart: start,
      renewsAt: DateTime(2026, 10, 1),
    );
    // Halfway through a $5 month, $2.50 of Starter carries over.
    final quote = DemoQuote.change(
      AcatrainPlan.max,
      BillingCycle.monthly,
      starter,
      DateTime(2026, 9, 16),
    );
    expect(quote.creditCents, 250);
    expect(quote.dueTodayCents, 1750);
    expect(quote.replacing, AcatrainPlan.starter);
  });

  test('renewals bill while away and cancelled plans end', () async {
    final state = await store();
    final start = DateTime(2026, 1, 15);
    final subscription = DemoSubscription(
      plan: AcatrainPlan.pro,
      cycle: BillingCycle.monthly,
      method: DemoPaymentMethod.googlePlay,
      instrument: 'Visa ·· 4242',
      memberSince: start,
      memberNumber: '4821',
      periodStart: start,
      renewsAt: DateTime(2026, 2, 15),
    );
    await state.setDemoSubscription(subscription.toJson(), plan: 'pro');
    await settleDemoSubscription(state, now: DateTime(2026, 4, 20));
    var saved = DemoSubscription.fromStore(state)!;
    expect(saved.invoices, hasLength(3));
    expect(saved.renewsAt, DateTime(2026, 5, 15));
    expect(saved.periodStart, DateTime(2026, 4, 15));
    expect(state.plan, 'pro');

    await state.setDemoSubscription(saved.copyWith(cancelled: true).toJson());
    await settleDemoSubscription(state, now: DateTime(2026, 5, 1));
    expect(state.plan, 'pro');
    await settleDemoSubscription(state, now: DateTime(2026, 5, 16));
    saved = DemoSubscription.fromStore(state)!;
    expect(saved.ended, isTrue);
    expect(saved.invoices, hasLength(3));
    expect(state.plan, 'free');
    state.dispose();
  });

  test('Stripe test cards behave like test mode', () {
    expect(cardBrandOf('4242'), CardBrand.visa);
    expect(cardBrandOf('5555'), CardBrand.mastercard);
    expect(cardBrandOf('3782'), CardBrand.amex);
    expect(luhnValid('4242424242424242'), isTrue);
    expect(luhnValid('4242424242424241'), isFalse);
    expect(stripeTestOutcome('4242424242424242'), isNull);
    expect(stripeTestOutcome('4000000000000002'), 'Your card was declined.');
    expect(stripeTestOutcome('4000002760003184'), '3ds');
    expect(stripeTestOutcome('4111111111111111'), contains('non test card'));
  });

  for (final size in [const Size(360, 740), const Size(1440, 1400)]) {
    testWidgets('Google Play checkout verifies and unlocks Starter at '
        '${size.width}', (tester) async {
      final state = await store();
      await tester.binding.setSurfaceSize(size);
      await openCheckout(tester, state, r'Subscribe · $5.00', 'Google Play');
      // Switch the payment method, then subscribe.
      await tester.tap(find.text('Visa-4242'));
      await wait(tester, 400);
      await tester.tap(find.text('PayPal: demo@example.com'));
      await wait(tester, 400);
      await tester.tap(find.text('Subscribe').last);
      await wait(tester, 400);
      expect(find.text("Verify it's you"), findsOneWidget);
      await tester.tap(find.text('Use password'));
      await wait(tester, 3000);
      expect(state.plan, 'starter');
      expect(find.text('Welcome to Starter'), findsOneWidget);
      await wait(tester, 5600);
      expect(find.text('Welcome to Starter'), findsNothing);
      expect(find.text('Your Starter membership'), findsOneWidget);
      expect(find.text('Current plan', skipOffstage: false), findsOneWidget);
      final saved = DemoSubscription.fromStore(state)!;
      expect(saved.instrument, 'PayPal');
      expect(saved.invoices.single.cents, 500);
      expect(tester.takeException(), isNull);
      await tester.binding.setSurfaceSize(null);
      await tester.pumpWidget(const SizedBox());
      state.dispose();
    });

    testWidgets('App Store checkout needs a double click at ${size.width}', (
      tester,
    ) async {
      final state = await store();
      await tester.binding.setSurfaceSize(size);
      await openCheckout(
        tester,
        state,
        r'Subscribe · $10.00',
        'App Store (iOS)',
      );
      final confirm = find.text('Confirm with Side Button');
      await tester.tap(confirm);
      await wait(tester, 600);
      expect(state.plan, 'free');
      await tester.tap(confirm);
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tap(confirm);
      await wait(tester, 3200);
      expect(find.text("You're all set."), findsOneWidget);
      await tester.tap(find.text('OK'));
      await wait(tester, 800);
      expect(state.plan, 'pro');
      expect(find.text('Welcome to Pro'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.binding.setSurfaceSize(null);
      await tester.pumpWidget(const SizedBox());
      state.dispose();
    });

    testWidgets('Stripe checkout validates and accepts a test card at '
        '${size.width}', (tester) async {
      final state = await store();
      await tester.binding.setSurfaceSize(size);
      await openCheckout(tester, state, r'Subscribe · $20.00', 'Stripe (Web)');
      final pay = find.text(r'Subscribe · $20.00').last;
      await tapVisible(tester, pay);
      await wait(tester, 300);
      expect(
        find.text('Your card number is incomplete.', skipOffstage: false),
        findsOneWidget,
      );
      await tapVisible(tester, find.text('Autofill test card'));
      await wait(tester, 200);
      await tapVisible(tester, pay);
      await wait(tester, 3200);
      expect(state.plan, 'max');
      expect(DemoSubscription.fromStore(state)!.instrument, 'Visa ·· 4242');
      expect(find.text('Welcome to Max 20x'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.binding.setSurfaceSize(null);
      await tester.pumpWidget(const SizedBox());
      state.dispose();
    });
  }

  testWidgets('Stripe declines, then passes 3-D Secure', (tester) async {
    final state = await store();
    await tester.binding.setSurfaceSize(const Size(1280, 1400));
    await openCheckout(tester, state, r'Subscribe · $10.00', 'Stripe (Web)');
    final pay = find.text(r'Subscribe · $10.00').last;

    await fillStripe(tester, '4000000000000002');
    await tapVisible(tester, pay);
    await wait(tester, 2000);
    expect(find.text('Your card was declined.'), findsOneWidget);
    expect(state.plan, 'free');

    await fillStripe(tester, '4111111111111111');
    await tapVisible(tester, pay);
    await wait(tester, 2000);
    expect(find.textContaining('non test card'), findsOneWidget);

    await fillStripe(tester, '4000002760003184');
    await tapVisible(tester, pay);
    await wait(tester, 2000);
    expect(find.text('3D Secure 2 Test Page'), findsOneWidget);
    await tester.tap(find.text('Complete authentication'));
    await wait(tester, 3000);
    expect(state.plan, 'pro');
    expect(DemoSubscription.fromStore(state)!.instrument, 'Visa ·· 3184');
    expect(tester.takeException(), isNull);
    await tester.binding.setSurfaceSize(null);
    await tester.pumpWidget(const SizedBox());
    state.dispose();
  });

  testWidgets('members can cancel, resume, read receipts and upgrade', (
    tester,
  ) async {
    final state = await store();
    await tester.binding.setSurfaceSize(const Size(1280, 1600));
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 10));
    await state.setDemoSubscription(
      DemoSubscription(
        plan: AcatrainPlan.starter,
        cycle: BillingCycle.monthly,
        method: DemoPaymentMethod.stripeWeb,
        instrument: 'Visa ·· 4242',
        memberSince: start,
        memberNumber: '4821',
        periodStart: start,
        renewsAt: BillingCycle.monthly.advance(start),
        invoices: [
          DemoInvoice(
            number: 'ACA-1234-5678',
            date: start,
            description: 'Acatrain Starter · monthly',
            cents: 500,
            instrument: 'Visa ·· 4242',
          ),
        ],
      ).toJson(),
      plan: 'starter',
    );
    await tester.pumpWidget(MaterialApp(home: SubscriptionPage(store: state)));
    await wait(tester, 400);
    expect(find.text('Your Starter membership'), findsOneWidget);
    expect(find.text('••••  ••••  ••••  4821'), findsOneWidget);

    await tester.tap(find.text('Acatrain Starter · monthly'));
    await wait(tester, 600);
    expect(find.text('Receipt from Acatrain'), findsOneWidget);
    expect(find.text('ACA-1234-5678'), findsOneWidget);
    await tester.tap(find.byTooltip('Close'));
    await wait(tester, 600);

    await tester.tap(find.text('Cancel subscription'));
    await wait(tester, 400);
    await tester.tap(find.text('Cancel subscription').last);
    await wait(tester, 400);
    expect(DemoSubscription.fromStore(state)!.cancelled, isTrue);
    expect(find.text('Cancelled'), findsOneWidget);
    expect(state.plan, 'starter');

    await tester.tap(find.text('Resume subscription'));
    await wait(tester, 400);
    expect(DemoSubscription.fromStore(state)!.cancelled, isFalse);

    // Upgrading credits the unused Starter time.
    await tapVisible(tester, find.text(r'Upgrade · $20.00'));
    await wait(tester, 600);
    await tester.tap(find.text('Stripe (Web)'));
    await tester.tap(find.text('Continue'));
    await wait(tester, 800);
    expect(find.text('Credit for unused Starter'), findsOneWidget);
    await tester.tap(find.byTooltip('Close'));
    await wait(tester, 600);
    expect(state.plan, 'starter');
    expect(tester.takeException(), isNull);
    await tester.binding.setSurfaceSize(null);
    await tester.pumpWidget(const SizedBox());
    state.dispose();
  });

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

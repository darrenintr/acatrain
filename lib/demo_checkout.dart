import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_ui.dart';
import 'language.dart';
import 'subscription.dart';

// Three look-alike checkouts (Google Play, App Store, Stripe). They behave
// like the real sheets, including verification steps and Stripe's test-card
// outcomes, but nothing leaves the device: no store, wallet, bank or card
// network is contacted, card numbers are never stored (only brand and last
// four digits), and nothing is ever charged.

/// What a finished demo checkout "paid with".
class DemoCharge {
  const DemoCharge(this.method, this.instrument);
  final DemoPaymentMethod method;

  /// e.g. "Visa ·· 4242". Never a full card number.
  final String instrument;
}

/// Who is "paying", for the account rows and prefilled fields.
class DemoPayer {
  const DemoPayer({this.name, this.email});
  final String? name;
  final String? email;
}

extension DemoPaymentMethodLabels on DemoPaymentMethod {
  String get label => switch (this) {
    DemoPaymentMethod.googlePlay => 'Google Play',
    DemoPaymentMethod.appleIos => 'App Store (iOS)',
    DemoPaymentMethod.stripeWeb => 'Stripe (Web)',
  };

  IconData get icon => switch (this) {
    DemoPaymentMethod.googlePlay => Icons.shop_rounded,
    DemoPaymentMethod.appleIos => Icons.phone_iphone_rounded,
    DemoPaymentMethod.stripeWeb => Icons.credit_card_rounded,
  };
}

DemoPaymentMethod _defaultMethod() {
  if (kIsWeb) return DemoPaymentMethod.stripeWeb;
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => DemoPaymentMethod.googlePlay,
    TargetPlatform.iOS || TargetPlatform.macOS => DemoPaymentMethod.appleIos,
    _ => DemoPaymentMethod.stripeWeb,
  };
}

Duration demoMotion(BuildContext context, int ms) =>
    MediaQuery.of(context).disableAnimations
        ? Duration(milliseconds: math.min(ms, 120))
        : Duration(milliseconds: ms);

/// Walks through a simulated checkout for [quote]. Returns what was "paid
/// with" when the pretend payment succeeds, or null when it is abandoned.
Future<DemoCharge?> showDemoCheckout(
  BuildContext context,
  DemoQuote quote, {
  DemoPayer payer = const DemoPayer(),
}) async {
  final method = await showModalBottomSheet<DemoPaymentMethod>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 560),
    isScrollControlled: true,
    builder: (_) => SingleChildScrollView(child: _MethodPicker(quote: quote)),
  );
  if (method == null || !context.mounted) return null;
  final checkout = switch (method) {
    DemoPaymentMethod.googlePlay => showModalBottomSheet<DemoCharge>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      constraints: const BoxConstraints(maxWidth: 560),
      builder:
          (_) => SingleChildScrollView(
            child: _GooglePlaySheet(quote: quote, payer: payer),
          ),
    ),
    DemoPaymentMethod.appleIos => showModalBottomSheet<DemoCharge>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      constraints: const BoxConstraints(maxWidth: 520),
      builder:
          (_) => SingleChildScrollView(
            child: _AppleSheet(quote: quote, payer: payer),
          ),
    ),
    DemoPaymentMethod.stripeWeb => showGeneralDialog<DemoCharge>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: const Color(0x99000000),
      transitionDuration: demoMotion(context, 320),
      pageBuilder: (_, _, _) => _StripeCheckout(quote: quote, payer: payer),
      transitionBuilder: (context, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween(begin: 0.94, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    ),
  };
  return checkout;
}

class _MethodPicker extends StatefulWidget {
  const _MethodPicker({required this.quote});
  final DemoQuote quote;

  @override
  State<_MethodPicker> createState() => _MethodPickerState();
}

class _MethodPickerState extends State<_MethodPicker> {
  DemoPaymentMethod _method = _defaultMethod();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final quote = widget.quote;
    final methods = DemoPaymentMethod.values;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${quote.plan.label} · ${formatMoney(quote.priceCents)} '
            '${tr(context, quote.cycle.perLabel)}',
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 6),
          Text(
            tr(context, 'Pick a checkout to try. Every one is simulated.'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          for (var i = 0; i < methods.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Material(
                color:
                    _method == methods[i]
                        ? theme.colorScheme.secondaryContainer
                        : theme.colorScheme.surfaceContainerHigh,
                shape: RoundedRectangleBorder(
                  borderRadius: segmentRadius(i, methods.length),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _method = methods[i]);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        Icon(methods[i].icon),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            methods[i].label,
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                        if (methods[i] == _defaultMethod())
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Text(
                              tr(context, 'This device'),
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        Icon(
                          _method == methods[i]
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_off_rounded,
                          color: theme.colorScheme.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(context, _method),
              child: Text(tr(context, 'Continue')),
            ),
          ),
        ],
      ),
    );
  }
}

enum _PayStage { review, verify, processing, done }

/// Shared state machine for the fake checkouts: review → (verify) →
/// processing → done, then closes itself with the [charge].
mixin _FakePayment<T extends StatefulWidget> on State<T> {
  _PayStage stage = _PayStage.review;

  /// The last decline message, shown until the next attempt.
  String? error;

  DemoCharge charge();

  /// Runs after the success animation, before the sheet closes.
  Future<void> afterSuccess() async {}

  /// [outcome] returns a decline message, or null to succeed.
  Future<void> pay({
    int processingMs = 1600,
    FutureOr<String?> Function()? outcome,
  }) async {
    if (stage == _PayStage.processing || stage == _PayStage.done) return;
    setState(() {
      stage = _PayStage.processing;
      error = null;
    });
    await Future<void>.delayed(demoMotion(context, processingMs));
    if (!mounted) return;
    final failure = await outcome?.call();
    if (!mounted) return;
    if (failure != null) {
      unawaited(HapticFeedback.heavyImpact());
      setState(() {
        stage = _PayStage.review;
        error = failure;
      });
      return;
    }
    unawaited(HapticFeedback.mediumImpact());
    setState(() => stage = _PayStage.done);
    await Future<void>.delayed(demoMotion(context, 1300));
    if (!mounted) return;
    await afterSuccess();
    if (mounted) Navigator.pop(context, charge());
  }
}

/// Draws a ring, then a check mark, as it animates in.
class AnimatedCheck extends StatelessWidget {
  const AnimatedCheck({
    super.key,
    required this.color,
    this.size = 72,
    this.filled = false,
    this.duration = const Duration(milliseconds: 700),
  });

  final Color color;
  final double size;
  final bool filled;
  final Duration duration;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: demoMotion(context, duration.inMilliseconds),
    curve: Curves.easeOutCubic,
    builder:
        (context, t, _) => Transform.scale(
          scale: 0.7 + 0.3 * Curves.easeOutBack.transform(t),
          child: CustomPaint(
            size: Size.square(size),
            painter: _CheckPainter(t, color, filled),
          ),
        ),
  );
}

class _CheckPainter extends CustomPainter {
  _CheckPainter(this.t, this.color, this.filled);
  final double t;
  final Color color;
  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.075;
    final rect = Offset.zero & size;
    final ring = (t / 0.55).clamp(0.0, 1.0);
    final tick = ((t - 0.45) / 0.55).clamp(0.0, 1.0);
    if (filled) {
      canvas.drawCircle(
        rect.center,
        size.width / 2 * ring,
        Paint()..color = color,
      );
    } else {
      canvas.drawArc(
        rect.deflate(stroke / 2),
        -math.pi / 2,
        math.pi * 2 * ring,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round,
      );
    }
    if (tick == 0) return;
    final path =
        Path()
          ..moveTo(size.width * 0.28, size.height * 0.52)
          ..lineTo(size.width * 0.44, size.height * 0.67)
          ..lineTo(size.width * 0.73, size.height * 0.37);
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * tick),
      Paint()
        ..color = filled ? Colors.white : color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter old) =>
      old.t != t || old.color != color || old.filled != filled;
}

class _DemoTag extends StatelessWidget {
  const _DemoTag({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => Text(
    tr(context, 'Simulated payment · not charged'),
    textAlign: TextAlign.center,
    style: TextStyle(fontSize: 11, color: color, letterSpacing: 0.3),
  );
}

/// The app's "store listing" icon, in the plan's colours.
class PlanThumb extends StatelessWidget {
  const PlanThumb({
    super.key,
    required this.plan,
    this.radius = 10,
    this.size = 52,
  });
  final AcatrainPlan plan;
  final double radius;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      gradient: plan.gradient,
      borderRadius: BorderRadius.circular(radius),
    ),
    child: Icon(
      Icons.school_rounded,
      color: const Color(0xFFFFF8E7),
      size: size * 0.5,
    ),
  );
}

/// Label/value rows describing what is due, shared by every sheet.
List<(String, String)> _quoteRows(DemoQuote quote) => [
  ('Subscription', '${formatMoney(quote.priceCents)}/${quote.cycle.unit}'),
  if (quote.creditCents > 0) ...[
    (
      'Credit for unused ${quote.replacing?.label ?? 'plan'}',
      '−${formatMoney(quote.creditCents)}',
    ),
    ('Due today', formatMoney(quote.dueTodayCents)),
  ],
  ('Renews', formatDemoDate(quote.renewsAt)),
];

// ---------------------------------------------------------------------------
// Google Play style
// ---------------------------------------------------------------------------

class _GooglePlaySheet extends StatefulWidget {
  const _GooglePlaySheet({required this.quote, required this.payer});
  final DemoQuote quote;
  final DemoPayer payer;

  @override
  State<_GooglePlaySheet> createState() => _GooglePlaySheetState();
}

class _GooglePlaySheetState extends State<_GooglePlaySheet>
    with _FakePayment, SingleTickerProviderStateMixin {
  static const _green = Color(0xFF01875F);
  static const _ink = Color(0xFF1F1F1F);
  static const _muted = Color(0xFF5F6368);
  static const _line = Color(0xFFE8EAED);
  static const _instruments = [
    (Icons.credit_card_rounded, 'Visa-4242', 'Visa ·· 4242'),
    (Icons.credit_card_rounded, 'Mastercard-5454', 'Mastercard ·· 5454'),
    (
      Icons.account_balance_wallet_outlined,
      'PayPal: demo@example.com',
      'PayPal',
    ),
    (Icons.redeem_rounded, r'Google Play balance ($127.50)', 'Play balance'),
  ];

  int _instrument = 0;
  bool _choosing = false;

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  DemoCharge charge() =>
      DemoCharge(DemoPaymentMethod.googlePlay, _instruments[_instrument].$3);

  @override
  Widget build(BuildContext context) {
    final quote = widget.quote;
    final plan = quote.plan;
    return PopScope(
      canPop: stage == _PayStage.review || stage == _PayStage.verify,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: DefaultTextStyle.merge(
          style: const TextStyle(fontSize: 14, color: _ink),
          child: AnimatedSize(
            duration: demoMotion(context, 320),
            curve: Curves.easeOutCubic,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDADCE0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.shop_rounded, color: _green, size: 22),
                    const SizedBox(width: 8),
                    const Text(
                      'Google Play',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: _muted,
                      ),
                    ),
                    const Spacer(),
                    if (stage == _PayStage.review)
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded, color: _muted),
                      ),
                  ],
                ),
                const Divider(height: 24, color: _line),
                AnimatedSwitcher(
                  duration: demoMotion(context, 260),
                  child: switch (stage) {
                    _PayStage.done => Padding(
                      key: const ValueKey('done'),
                      padding: const EdgeInsets.symmetric(vertical: 28),
                      child: Column(
                        children: [
                          const AnimatedCheck(color: _green, filled: true),
                          const SizedBox(height: 16),
                          const Text(
                            'Payment successful',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Acatrain ${plan.label} is now active',
                            style: const TextStyle(color: _muted),
                          ),
                        ],
                      ),
                    ),
                    _PayStage.verify => _verify(),
                    _ => _review(quote),
                  },
                ),
                const SizedBox(height: 12),
                const _DemoTag(color: _muted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _review(DemoQuote quote) {
    final plan = quote.plan;
    final (icon, label, _) = _instruments[_instrument];
    return Column(
      key: const ValueKey('review'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            PlanThumb(plan: plan, radius: 12),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Acatrain ${plan.label}'
                    '${quote.cycle == BillingCycle.yearly ? ' (Yearly)' : ''}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Text('Acatrain', style: TextStyle(color: _muted)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        for (final (label, value) in _quoteRows(quote))
          _playRow(label, value, bold: label == 'Subscription'),
        const SizedBox(height: 10),
        Material(
          color: Colors.transparent,
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: _line),
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              InkWell(
                onTap:
                    stage == _PayStage.review
                        ? () => setState(() => _choosing = !_choosing)
                        : null,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(icon, color: _muted),
                      const SizedBox(width: 12),
                      Expanded(child: Text(label)),
                      AnimatedRotation(
                        turns: _choosing ? 0.25 : 0,
                        duration: demoMotion(context, 200),
                        child: const Icon(
                          Icons.chevron_right_rounded,
                          color: _muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_choosing)
                for (var i = 0; i < _instruments.length; i++)
                  InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _instrument = i;
                        _choosing = false;
                      });
                    },
                    child: Container(
                      decoration: const BoxDecoration(
                        border: Border(top: BorderSide(color: _line)),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Icon(_instruments[i].$1, color: _muted, size: 20),
                          const SizedBox(width: 12),
                          Expanded(child: Text(_instruments[i].$2)),
                          if (i == _instrument)
                            const Icon(
                              Icons.check_rounded,
                              color: _green,
                              size: 20,
                            ),
                        ],
                      ),
                    ),
                  ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'By tapping "Subscribe", you agree to the Google Payments Terms of '
          'Service. Your subscription renews every ${quote.cycle.unit} until '
          'you cancel in Settings. Demo: no money moves and Google Play is '
          'not contacted.',
          style: const TextStyle(fontSize: 12, color: _muted),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _green,
              disabledBackgroundColor: _green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              minimumSize: const Size(0, 48),
            ),
            onPressed:
                stage == _PayStage.review
                    ? () => setState(() {
                      _choosing = false;
                      stage = _PayStage.verify;
                    })
                    : null,
            child:
                stage == _PayStage.processing
                    ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                    : const Text(
                      'Subscribe',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
          ),
        ),
      ],
    );
  }

  /// The biometric prompt Play shows when purchase authentication is on.
  Widget _verify() => Padding(
    key: const ValueKey('verify'),
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Column(
      children: [
        const Text(
          "Verify it's you",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        Text(
          'Confirm ${formatMoney(widget.quote.dueTodayCents)} for '
          'Acatrain ${widget.quote.plan.label}',
          style: const TextStyle(color: _muted),
        ),
        const SizedBox(height: 22),
        Semantics(
          button: true,
          label: 'Touch the fingerprint sensor',
          child: GestureDetector(
            onTap: () => pay(processingMs: 1100),
            child: AnimatedBuilder(
              animation: _pulse,
              builder:
                  (context, child) => Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _green.withValues(
                        alpha: 0.08 + 0.08 * _pulse.value,
                      ),
                      border: Border.all(
                        color: _green.withValues(
                          alpha: 0.3 + 0.4 * _pulse.value,
                        ),
                        width: 2,
                      ),
                    ),
                    child: child,
                  ),
              child: const Icon(
                Icons.fingerprint_rounded,
                size: 44,
                color: _green,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Touch the fingerprint sensor',
          style: TextStyle(color: _muted),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: () => setState(() => stage = _PayStage.review),
              style: TextButton.styleFrom(foregroundColor: _green),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => pay(processingMs: 1100),
              style: TextButton.styleFrom(foregroundColor: _green),
              child: const Text('Use password'),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _playRow(String label, String value, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(color: _muted))),
        Text(
          value,
          style: TextStyle(
            fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// iOS App Store style
// ---------------------------------------------------------------------------

class _AppleSheet extends StatefulWidget {
  const _AppleSheet({required this.quote, required this.payer});
  final DemoQuote quote;
  final DemoPayer payer;

  @override
  State<_AppleSheet> createState() => _AppleSheetState();
}

class _AppleSheetState extends State<_AppleSheet>
    with _FakePayment, TickerProviderStateMixin {
  static const _blue = Color(0xFF0A84FF);

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  DemoCharge charge() =>
      const DemoCharge(DemoPaymentMethod.appleIos, 'Apple Pay · Visa ·· 4242');

  /// The App Store's closing "You're all set." alert. Drawn by hand, not
  /// with CupertinoAlertDialog, so it keeps the app's font on every platform.
  @override
  Future<void> afterSuccess() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? Colors.white : Colors.black;
    return showGeneralDialog<void>(
      context: context,
      barrierColor: const Color(0x66000000),
      transitionDuration: demoMotion(context, 220),
      pageBuilder:
          (context, _, _) => Center(
            child: Material(
              color: dark ? const Color(0xF22C2C2E) : const Color(0xF2F2F2F7),
              borderRadius: BorderRadius.circular(14),
              clipBehavior: Clip.antiAlias,
              child: SizedBox(
                width: 270,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 18),
                      child: Column(
                        children: [
                          Text(
                            "You're all set.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: ink,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Your purchase was successful.\n[Demo]',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: ink),
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: ink.withValues(alpha: 0.18)),
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      child: const SizedBox(
                        height: 44,
                        width: double.infinity,
                        child: Center(
                          child: Text(
                            'OK',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: _blue,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      transitionBuilder:
          (context, animation, _, child) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween(begin: 1.12, end: 1.0).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
              child: child,
            ),
          ),
    );
  }

  void _confirm() {
    HapticFeedback.heavyImpact();
    pay(processingMs: 1500);
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7);
    final card = dark ? const Color(0xFF2C2C2E) : Colors.white;
    final ink = dark ? Colors.white : Colors.black;
    const muted = Color(0xFF8E8E93);
    final quote = widget.quote;
    final plan = quote.plan;
    return PopScope(
      canPop: stage == _PayStage.review,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              color: bg,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
            child: DefaultTextStyle.merge(
              style: TextStyle(fontSize: 15, color: ink),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        'App Store',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: ink,
                        ),
                      ),
                      const Spacer(),
                      if (stage == _PayStage.review)
                        Semantics(
                          button: true,
                          label: 'Close',
                          child: GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: muted.withValues(alpha: 0.24),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: muted,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: card,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            PlanThumb(plan: plan, radius: 12, size: 56),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Acatrain ${plan.label}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const Text(
                                    'Acatrain',
                                    style: TextStyle(color: muted),
                                  ),
                                  Text(
                                    'Subscription · '
                                    '${quote.cycle == BillingCycle.yearly ? '1 year' : '1 month'}',
                                    style: const TextStyle(
                                      color: muted,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        Divider(
                          height: 24,
                          color: muted.withValues(alpha: 0.3),
                        ),
                        _appleRow(
                          'Price',
                          '${formatMoney(quote.priceCents)} per '
                              '${quote.cycle.unit}',
                          muted,
                        ),
                        if (quote.creditCents > 0)
                          _appleRow(
                            'Credit',
                            '−${formatMoney(quote.creditCents)} unused '
                                '${quote.replacing?.label ?? ''}',
                            muted,
                          ),
                        _appleRow(
                          'Account',
                          widget.payer.email ?? 'demo@icloud.com',
                          muted,
                        ),
                        _appleRow(
                          'Pay with',
                          'Apple Pay · Visa ···· 4242',
                          muted,
                        ),
                        _appleRow(
                          'Renews',
                          '${formatDemoDate(quote.renewsAt)} until cancelled',
                          muted,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 26),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 132),
                    child: AnimatedSwitcher(
                      duration: demoMotion(context, 260),
                      child: switch (stage) {
                        _PayStage.review || _PayStage.verify => Semantics(
                          key: const ValueKey('confirm'),
                          button: true,
                          label: 'Double-click the side button to pay',
                          child: GestureDetector(
                            onDoubleTap: _confirm,
                            behavior: HitTestBehavior.opaque,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.phone_iphone_rounded,
                                  size: 44,
                                  color: ink,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Confirm with Side Button',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    color: ink,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Double-tap here to stand in for it',
                                  style: TextStyle(color: muted, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ),
                        _PayStage.processing => Column(
                          key: const ValueKey('faceid'),
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const _FaceScan(color: _blue),
                            const SizedBox(height: 12),
                            Text('Face ID', style: TextStyle(color: ink)),
                          ],
                        ),
                        _PayStage.done => Column(
                          key: const ValueKey('done'),
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const AnimatedCheck(color: _blue, size: 64),
                            const SizedBox(height: 12),
                            Text(
                              'Done',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: ink,
                              ),
                            ),
                          ],
                        ),
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  const _DemoTag(color: muted),
                ],
              ),
            ),
          ),
          // The glowing side-button cue and its "Double Click to Pay" label
          // on the sheet's right edge, where the real button sits.
          if (stage == _PayStage.review)
            Positioned(
              right: 0,
              top: 66,
              child: GestureDetector(
                onDoubleTap: _confirm,
                behavior: HitTestBehavior.opaque,
                child: AnimatedBuilder(
                  animation: _pulse,
                  builder:
                      (context, _) => Row(
                        children: [
                          Text(
                            'Double Click\nto Pay',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.2,
                              fontWeight: FontWeight.w600,
                              color: ink.withValues(
                                alpha: 0.55 + 0.45 * _pulse.value,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 6,
                            height: 64,
                            decoration: BoxDecoration(
                              color: _blue.withValues(
                                alpha: 0.35 + 0.65 * _pulse.value,
                              ),
                              borderRadius: const BorderRadius.horizontal(
                                left: Radius.circular(3),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: _blue.withValues(
                                    alpha: 0.6 * _pulse.value,
                                  ),
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _appleRow(String label, String value, Color muted) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 84,
          child: Text(label, style: TextStyle(color: muted, fontSize: 13)),
        ),
        Expanded(child: Text(value)),
      ],
    ),
  );
}

/// A pulsing face glyph with a scanning line, in the spirit of Face ID.
class _FaceScan extends StatefulWidget {
  const _FaceScan({required this.color});
  final Color color;

  @override
  State<_FaceScan> createState() => _FaceScanState();
}

class _FaceScanState extends State<_FaceScan>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder:
        (context, _) => CustomPaint(
          size: const Size.square(64),
          painter: _FacePainter(_controller.value, widget.color),
        ),
  );
}

class _FacePainter extends CustomPainter {
  _FacePainter(this.t, this.color);
  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.2
          ..strokeCap = StrokeCap.round;
    // Corner brackets.
    const c = 14.0;
    for (final (x, y, dx, dy) in [
      (0.0, 0.0, 1.0, 1.0),
      (w, 0.0, -1.0, 1.0),
      (0.0, w, 1.0, -1.0),
      (w, w, -1.0, -1.0),
    ]) {
      canvas.drawPath(
        Path()
          ..moveTo(x, y + dy * c)
          ..lineTo(x, y)
          ..lineTo(x + dx * c, y),
        paint,
      );
    }
    // Eyes, nose and smile.
    canvas.drawLine(Offset(w * .36, w * .36), Offset(w * .36, w * .44), paint);
    canvas.drawLine(Offset(w * .64, w * .36), Offset(w * .64, w * .44), paint);
    canvas.drawPath(
      Path()
        ..moveTo(w * .52, w * .36)
        ..lineTo(w * .52, w * .56)
        ..lineTo(w * .47, w * .56),
      paint,
    );
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(w * .5, w * .6),
        width: w * .36,
        height: w * .2,
      ),
      0.25,
      math.pi - 0.5,
      false,
      paint,
    );
    // Scan line.
    final y = w * (0.12 + 0.76 * (0.5 - 0.5 * math.cos(t * math.pi * 2)));
    canvas.drawLine(
      Offset(w * .1, y),
      Offset(w * .9, y),
      Paint()
        ..color = color.withValues(alpha: 0.55)
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_FacePainter old) => old.t != t || old.color != color;
}

// ---------------------------------------------------------------------------
// Stripe web checkout style
// ---------------------------------------------------------------------------

enum CardBrand { visa, mastercard, amex, discover, jcb, unionpay, unknown }

extension CardBrandLabel on CardBrand {
  String get label => switch (this) {
    CardBrand.visa => 'Visa',
    CardBrand.mastercard => 'Mastercard',
    CardBrand.amex => 'Amex',
    CardBrand.discover => 'Discover',
    CardBrand.jcb => 'JCB',
    CardBrand.unionpay => 'UnionPay',
    CardBrand.unknown => 'Card',
  };

  int get length => this == CardBrand.amex ? 15 : 16;
  int get cvcLength => this == CardBrand.amex ? 4 : 3;
}

CardBrand cardBrandOf(String digits) {
  if (digits.startsWith('4')) return CardBrand.visa;
  if (RegExp(r'^3[47]').hasMatch(digits)) return CardBrand.amex;
  if (RegExp(
    r'^(5[1-5]|222[1-9]|22[3-9]|2[3-6]|27[01]|2720)',
  ).hasMatch(digits)) {
    return CardBrand.mastercard;
  }
  if (RegExp(r'^(6011|65|64[4-9])').hasMatch(digits)) return CardBrand.discover;
  if (digits.startsWith('35')) return CardBrand.jcb;
  if (digits.startsWith('62')) return CardBrand.unionpay;
  return CardBrand.unknown;
}

bool luhnValid(String digits) {
  var sum = 0;
  for (var i = 0; i < digits.length; i++) {
    var d = digits.codeUnitAt(digits.length - 1 - i) - 48;
    if (i.isOdd) {
      d *= 2;
      if (d > 9) d -= 9;
    }
    sum += d;
  }
  return digits.isNotEmpty && sum % 10 == 0;
}

/// How Stripe's test mode answers a card number: null to succeed, '3ds' to
/// ask for authentication, otherwise the decline message it shows.
String? stripeTestOutcome(String digits) {
  const succeeds = {
    '4242424242424242',
    '4000056655665556',
    '5555555555554444',
    '2223003122003222',
    '5200828282828210',
    '5105105105105100',
    '378282246310005',
    '371449635398431',
    '6011111111111117',
    '3566002020360505',
    '6200000000000005',
  };
  if (succeeds.contains(digits)) return null;
  return switch (digits) {
    '4000002760003184' || '4000002500003155' || '4000000000003220' => '3ds',
    '4000000000000002' => 'Your card was declined.',
    '4000000000009995' => 'Your card has insufficient funds.',
    '4000000000000069' => 'Your card has expired.',
    '4000000000000127' => "Your card's security code is incorrect.",
    '4000000000000119' =>
      'An error occurred while processing your card. Try again in a little bit.',
    _ =>
      'Your card was declined. Your request was in test mode, but used a '
          'non test card. For a list of valid test cards, visit: '
          'https://stripe.com/docs/testing.',
  };
}

class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final brand = cardBrandOf(digits);
    digits = digits.substring(0, math.min(digits.length, brand.length));
    final groups = brand == CardBrand.amex ? [4, 6, 5] : [4, 4, 4, 4];
    final out = StringBuffer();
    var index = 0;
    for (final size in groups) {
      if (index >= digits.length) break;
      if (out.isNotEmpty) out.write(' ');
      out.write(digits.substring(index, math.min(digits.length, index + size)));
      index += size;
    }
    final text = out.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    // "4" means April: pad it like Stripe does.
    if (digits.length == 1 && int.parse(digits) > 1) digits = '0$digits';
    digits = digits.substring(0, math.min(4, digits.length));
    final deleting = newValue.text.length < oldValue.text.length;
    final text =
        digits.length > 2 || (digits.length == 2 && !deleting)
            ? '${digits.substring(0, 2)} / ${digits.substring(2)}'
            : digits;
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class _StripeCheckout extends StatefulWidget {
  const _StripeCheckout({required this.quote, required this.payer});
  final DemoQuote quote;
  final DemoPayer payer;

  @override
  State<_StripeCheckout> createState() => _StripeCheckoutState();
}

class _StripeCheckoutState extends State<_StripeCheckout> with _FakePayment {
  static const _blurple = Color(0xFF635BFF);
  static const _ink = Color(0xFF30313D);
  static const _muted = Color(0xFF6D6E78);
  static const _line = Color(0xFFE6E6EB);
  static const _red = Color(0xFFDF1B41);

  late final _email = TextEditingController(text: widget.payer.email ?? '');
  final _number = TextEditingController();
  final _expiry = TextEditingController();
  final _cvc = TextEditingController();
  late final _name = TextEditingController(text: widget.payer.name ?? '');
  final _zip = TextEditingController();
  String _country = 'United States';

  /// Per-field validation messages, shown after the first submit.
  Map<String, String> _invalid = {};
  bool _saveWithLink = false;

  static const _countries = [
    'United States',
    'Hong Kong SAR China',
    'United Kingdom',
    'Canada',
    'Australia',
    'Japan',
    'Singapore',
  ];

  String get _digits => _number.text.replaceAll(' ', '');
  CardBrand get _brand => cardBrandOf(_digits);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (isCantonese(context) && _zip.text.isEmpty) {
      _country = 'Hong Kong SAR China';
    }
  }

  @override
  void dispose() {
    for (final c in [_email, _number, _expiry, _cvc, _name, _zip]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  DemoCharge charge() {
    final last4 = _digits.substring(_digits.length - 4);
    return DemoCharge(DemoPaymentMethod.stripeWeb, '${_brand.label} ·· $last4');
  }

  void _autofill() {
    final year = (DateTime.now().year + 3) % 100;
    setState(() {
      if (_email.text.isEmpty) _email.text = 'demo@example.com';
      _number.text = '4242 4242 4242 4242';
      _expiry.text = '12 / ${year.toString().padLeft(2, '0')}';
      _cvc.text = '123';
      if (_name.text.isEmpty) _name.text = 'Demo Learner';
      if (_country == 'United States') _zip.text = '94107';
      _invalid = {};
      error = null;
    });
  }

  Map<String, String> _validate() {
    final problems = <String, String>{};
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_email.text.trim())) {
      problems['email'] =
          _email.text.trim().isEmpty
              ? 'Required'
              : 'Your email address is invalid.';
    }
    final digits = _digits;
    if (digits.length < _brand.length) {
      problems['card'] = 'Your card number is incomplete.';
    } else if (!luhnValid(digits)) {
      problems['card'] = 'Your card number is invalid.';
    } else {
      final expiry = _expiry.text.replaceAll(RegExp(r'\D'), '');
      final now = DateTime.now();
      if (expiry.length < 4) {
        problems['card'] = "Your card's expiration date is incomplete.";
      } else {
        final month = int.parse(expiry.substring(0, 2));
        final year = 2000 + int.parse(expiry.substring(2));
        if (month < 1 || month > 12) {
          problems['card'] = "Your card's expiration date is invalid.";
        } else if (year < now.year) {
          problems['card'] = "Your card's expiration year is in the past.";
        } else if (year == now.year && month < now.month) {
          problems['card'] = "Your card's expiration date is in the past.";
        } else if (_cvc.text.length < _brand.cvcLength) {
          problems['card'] = "Your card's security code is incomplete.";
        }
      }
    }
    if (_name.text.trim().isEmpty) problems['name'] = 'Required';
    if (_country == 'United States' && _zip.text.trim().length < 5) {
      problems['zip'] = 'Your ZIP is incomplete.';
    }
    return problems;
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    final problems = _validate();
    setState(() {
      _invalid = problems;
      error = null;
    });
    if (problems.isNotEmpty) {
      HapticFeedback.heavyImpact();
      return;
    }
    pay(
      processingMs: 1400,
      outcome: () async {
        final result = stripeTestOutcome(_digits);
        if (result != '3ds') return result;
        final passed = await _authenticate();
        return passed
            ? null
            : 'We are unable to authenticate your payment method. Please '
                'choose a different payment method and try again.';
      },
    );
  }

  /// Stripe's test-mode 3-D Secure page.
  Future<bool> _authenticate() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => Dialog(
            backgroundColor: Colors.white,
            insetPadding: const EdgeInsets.all(20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: DefaultTextStyle.merge(
                  style: const TextStyle(fontSize: 14, color: _ink),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.shield_outlined, color: _blurple),
                          SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              '3D Secure 2 Test Page',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Your bank wants to confirm this '
                        '${formatMoney(widget.quote.dueTodayCents)} payment '
                        'to Acatrain. This is a test authentication page: '
                        'choose how the bank should respond.',
                        style: const TextStyle(color: _muted, height: 1.4),
                      ),
                      const SizedBox(height: 22),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF1EA672),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          minimumSize: const Size(0, 44),
                        ),
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Complete authentication'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _red,
                          side: const BorderSide(color: _red),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          minimumSize: const Size(0, 44),
                        ),
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Fail authentication'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final quote = widget.quote;
    final editable = stage == _PayStage.review;
    final cardProblem = _invalid['card'];
    final appText = Theme.of(context).textTheme.bodyMedium;
    // A light, Stripe-coloured theme that keeps the app's bundled font.
    return Theme(
      data: ThemeData(
        useMaterial3: true,
        fontFamily: appText?.fontFamily,
        fontFamilyFallback: appText?.fontFamilyFallback,
        colorScheme: ColorScheme.fromSeed(seedColor: _blurple),
        textSelectionTheme: const TextSelectionThemeData(cursorColor: _blurple),
      ),
      child: PopScope(
        canPop: editable,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                clipBehavior: Clip.antiAlias,
                elevation: 24,
                child: SingleChildScrollView(
                  child: DefaultTextStyle.merge(
                    style: const TextStyle(fontSize: 14, color: _ink),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _header(quote),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: editable ? _autofill : null,
                                  style: TextButton.styleFrom(
                                    foregroundColor: _blurple,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  icon: const Icon(
                                    Icons.bolt_rounded,
                                    size: 18,
                                  ),
                                  label: const Text('Autofill test card'),
                                ),
                              ),
                              _label('Email'),
                              _input(
                                _email,
                                hint: 'you@example.com',
                                problem: _invalid['email'],
                                keyboard: TextInputType.emailAddress,
                                autofill: const [AutofillHints.email],
                                enabled: editable,
                              ),
                              _problem(_invalid['email']),
                              const SizedBox(height: 14),
                              _label('Card information'),
                              _cardBlock(editable, cardProblem != null),
                              _problem(cardProblem),
                              const SizedBox(height: 14),
                              _label('Cardholder name'),
                              _input(
                                _name,
                                hint: 'Full name on card',
                                problem: _invalid['name'],
                                autofill: const [AutofillHints.creditCardName],
                                enabled: editable,
                              ),
                              _problem(_invalid['name']),
                              const SizedBox(height: 14),
                              _label('Country or region'),
                              _countryBlock(editable),
                              _problem(_invalid['zip']),
                              const SizedBox(height: 14),
                              _linkBox(editable),
                              AnimatedSize(
                                duration: demoMotion(context, 220),
                                child:
                                    error == null
                                        ? const SizedBox(width: double.infinity)
                                        : Container(
                                          margin: const EdgeInsets.only(
                                            top: 14,
                                          ),
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFFF0F2),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Icon(
                                                Icons.error_outline_rounded,
                                                size: 18,
                                                color: _red,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  error!,
                                                  style: const TextStyle(
                                                    color: _red,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                              ),
                              const SizedBox(height: 18),
                              _payButton(quote),
                              const SizedBox(height: 12),
                              Text(
                                "By confirming your subscription, you allow "
                                "Acatrain to charge you for future payments "
                                "in accordance with their terms. You can "
                                "always cancel your subscription.",
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: _muted,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 14),
                              const Wrap(
                                alignment: WrapAlignment.center,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    'Powered by ',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _muted,
                                    ),
                                  ),
                                  Text(
                                    'stripe',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: _muted,
                                    ),
                                  ),
                                  Text(
                                    '  ·  Terms  ·  Privacy',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _muted,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              const _DemoTag(color: _muted),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(DemoQuote quote) => Container(
    color: const Color(0xFFF6F9FC),
    padding: const EdgeInsets.fromLTRB(24, 18, 12, 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            PlanThumb(plan: quote.plan, radius: 6, size: 28),
            const SizedBox(width: 10),
            const Flexible(
              child: Text(
                'Acatrain',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFFDE92),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'TEST MODE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF983705),
                ),
              ),
            ),
            const Spacer(),
            Visibility.maintain(
              visible: stage == _PayStage.review,
              child: IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: _muted),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          'Subscribe to Acatrain ${quote.plan.label}',
          style: const TextStyle(color: _muted),
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              formatMoney(quote.priceCents),
              style: const TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w600,
                color: _ink,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 6, left: 6),
              child: Text(
                'per\n${quote.cycle.unit}',
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.15,
                  color: _muted,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final (label, value) in _quoteRows(quote))
          Padding(
            padding: const EdgeInsets.only(top: 4, right: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label == 'Subscription'
                        ? 'Acatrain ${quote.plan.label}'
                        : label,
                    style: const TextStyle(color: _muted, fontSize: 13),
                  ),
                ),
                Text(value, style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 8, right: 12),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Total due today',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                formatMoney(quote.dueTodayCents),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  InputDecoration _decoration({
    String? hint,
    bool invalid = false,
    bool boxed = true,
    Widget? suffix,
  }) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: color, width: width),
        );
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFFA3A3AD)),
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      suffixIcon: suffix,
      suffixIconConstraints: const BoxConstraints(minHeight: 20),
      border: boxed ? border(_line) : InputBorder.none,
      enabledBorder: boxed ? border(invalid ? _red : _line) : InputBorder.none,
      disabledBorder: boxed ? border(_line) : InputBorder.none,
      focusedBorder:
          boxed ? border(invalid ? _red : _blurple, 2) : InputBorder.none,
    );
  }

  Widget _input(
    TextEditingController controller, {
    String? hint,
    String? problem,
    TextInputType? keyboard,
    Iterable<String>? autofill,
    List<TextInputFormatter>? formatters,
    bool boxed = true,
    bool enabled = true,
    Widget? suffix,
    ValueChanged<String>? onChanged,
  }) => TextField(
    controller: controller,
    enabled: enabled,
    keyboardType: keyboard,
    autofillHints: autofill,
    inputFormatters: formatters,
    onChanged: onChanged,
    style: const TextStyle(fontSize: 15, color: _ink),
    decoration: _decoration(
      hint: hint,
      invalid: problem != null,
      boxed: boxed,
      suffix: suffix,
    ),
  );

  Widget _cardBlock(bool editable, bool invalid) => Container(
    decoration: BoxDecoration(
      border: Border.all(color: invalid ? _red : _line),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Column(
      children: [
        _input(
          _number,
          hint: '1234 1234 1234 1234',
          keyboard: TextInputType.number,
          autofill: const [AutofillHints.creditCardNumber],
          formatters: [_CardNumberFormatter()],
          boxed: false,
          enabled: editable,
          onChanged: (_) => setState(() {}),
          suffix: Padding(
            padding: const EdgeInsets.only(right: 10),
            child: AnimatedSwitcher(
              duration: demoMotion(context, 180),
              child: _BrandMark(key: ValueKey(_brand), brand: _brand),
            ),
          ),
        ),
        const Divider(height: 1, color: _line),
        IntrinsicHeight(
          child: Row(
            children: [
              Expanded(
                child: _input(
                  _expiry,
                  hint: 'MM / YY',
                  keyboard: TextInputType.number,
                  autofill: const [AutofillHints.creditCardExpirationDate],
                  formatters: [_ExpiryFormatter()],
                  boxed: false,
                  enabled: editable,
                ),
              ),
              const VerticalDivider(width: 1, color: _line),
              Expanded(
                child: _input(
                  _cvc,
                  hint: 'CVC',
                  keyboard: TextInputType.number,
                  autofill: const [AutofillHints.creditCardSecurityCode],
                  formatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(_brand.cvcLength),
                  ],
                  boxed: false,
                  enabled: editable,
                  suffix: const Padding(
                    padding: EdgeInsets.only(right: 10),
                    child: Icon(
                      Icons.credit_score_outlined,
                      size: 18,
                      color: _muted,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _countryBlock(bool editable) => Container(
    decoration: BoxDecoration(
      border: Border.all(color: _invalid['zip'] != null ? _red : _line),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Column(
      children: [
        DropdownButtonHideUnderline(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: DropdownButton<String>(
              value: _country,
              isExpanded: true,
              dropdownColor: Colors.white,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(fontSize: 15, color: _ink),
              onChanged:
                  editable
                      ? (value) => setState(() => _country = value ?? _country)
                      : null,
              items: [
                for (final country in _countries)
                  DropdownMenuItem(value: country, child: Text(country)),
              ],
            ),
          ),
        ),
        if (_country == 'United States') ...[
          const Divider(height: 1, color: _line),
          _input(
            _zip,
            hint: 'ZIP',
            keyboard: TextInputType.number,
            autofill: const [AutofillHints.postalCode],
            formatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(5),
            ],
            boxed: false,
            enabled: editable,
          ),
        ],
      ],
    ),
  );

  Widget _linkBox(bool editable) => Container(
    decoration: BoxDecoration(
      border: Border.all(color: _line),
      borderRadius: BorderRadius.circular(6),
    ),
    child: CheckboxListTile(
      value: _saveWithLink,
      onChanged: editable ? (v) => setState(() => _saveWithLink = v!) : null,
      controlAffinity: ListTileControlAffinity.leading,
      activeColor: _blurple,
      dense: true,
      title: const Text(
        'Securely save my information for 1-click checkout',
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      ),
      subtitle: const Text(
        'Pay faster on Acatrain and everywhere Link is accepted.',
        style: TextStyle(fontSize: 12, color: _muted),
      ),
    ),
  );

  Widget _payButton(DemoQuote quote) => AnimatedContainer(
    duration: demoMotion(context, 280),
    curve: Curves.easeOutCubic,
    height: 46,
    decoration: BoxDecoration(
      color: stage == _PayStage.done ? const Color(0xFF1EA672) : _blurple,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: stage == _PayStage.review ? _submit : null,
        child: Center(
          child: AnimatedSwitcher(
            duration: demoMotion(context, 220),
            child: switch (stage) {
              _PayStage.review || _PayStage.verify => Text(
                'Subscribe · ${formatMoney(quote.dueTodayCents)}',
                key: const ValueKey('label'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              _PayStage.processing => const Row(
                key: ValueKey('spin'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Processing…',
                    style: TextStyle(color: Colors.white, fontSize: 15),
                  ),
                ],
              ),
              _PayStage.done => const AnimatedCheck(
                key: ValueKey('check'),
                color: Colors.white,
                size: 28,
              ),
            },
          ),
        ),
      ),
    ),
  );

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        color: _muted,
        fontWeight: FontWeight.w500,
      ),
    ),
  );

  Widget _problem(String? message) => AnimatedSize(
    duration: demoMotion(context, 160),
    child:
        message == null
            ? const SizedBox(width: double.infinity)
            : Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                message,
                style: const TextStyle(color: _red, fontSize: 13),
              ),
            ),
  );
}

/// A small brand plate like the ones in Stripe's card field.
class _BrandMark extends StatelessWidget {
  const _BrandMark({super.key, required this.brand});
  final CardBrand brand;

  @override
  Widget build(BuildContext context) {
    if (brand == CardBrand.unknown) {
      return const Icon(
        Icons.credit_card_rounded,
        size: 20,
        color: Color(0xFFA3A3AD),
      );
    }
    final (bg, fg) = switch (brand) {
      CardBrand.visa => (const Color(0xFF1A1F71), Colors.white),
      CardBrand.mastercard => (
        const Color(0xFF252525),
        const Color(0xFFF79E1B),
      ),
      CardBrand.amex => (const Color(0xFF2E77BC), Colors.white),
      CardBrand.discover => (const Color(0xFFF3F3F3), const Color(0xFFE55C20)),
      CardBrand.jcb => (const Color(0xFF0B4EA2), Colors.white),
      _ => (const Color(0xFFD7141A), Colors.white),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        brand.label.toUpperCase(),
        style: TextStyle(
          color: fg,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          fontStyle: FontStyle.italic,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app_ui.dart';
import 'expressive.dart';
import 'language.dart';
import 'store.dart';

/// A demo subscription tier. Checkout is simulated end to end: no store,
/// wallet or card network is ever contacted and nothing is charged. A tier
/// only swaps the app to a richer theme on this device.
enum AcatrainPlan {
  free('free', 'Free', 0, 'Evergreen', Color(0xFF36684F), Color(0xFF9DD4B4)),
  starter(
    'starter',
    'Starter',
    5,
    'Sapphire',
    Color(0xFF1D3F8F),
    Color(0xFFB9C8E8),
  ),
  pro(
    'pro',
    'Pro',
    10,
    'Amethyst & Gold',
    Color(0xFF4A1F73),
    Color(0xFFD9B45A),
  ),
  max(
    'max',
    'Max 20x',
    20,
    'Noir & Gold',
    Color(0xFF121110),
    Color(0xFFE3C274),
  );

  const AcatrainPlan(
    this.id,
    this.label,
    this.price,
    this.themeName,
    this.deep,
    this.shine,
  );

  final String id;
  final String label;
  final int price;
  final String themeName;

  /// The tier's darkest brand colour and its metallic highlight, used for
  /// plan cards and checkout art.
  final Color deep;
  final Color shine;

  String get priceLabel => '\$$price.00';

  static AcatrainPlan fromId(String id) => AcatrainPlan.values.firstWhere(
    (plan) => plan.id == id,
    orElse: () => AcatrainPlan.free,
  );

  LinearGradient get gradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [deep, Color.lerp(deep, shine, 0.45)!, shine],
    stops: const [0, 0.62, 1],
  );

  List<String> get perks => switch (this) {
    AcatrainPlan.free => const [
      'Evergreen theme',
      'Every study set',
      'Offline progress',
    ],
    AcatrainPlan.starter => const [
      'Sapphire theme',
      'Everything in Free',
      'Supporter badge',
    ],
    AcatrainPlan.pro => const [
      'Amethyst & Gold theme',
      'Everything in Starter',
      'Gilded hero card',
    ],
    AcatrainPlan.max => const [
      'Noir & Gold theme',
      'Everything in Pro',
      '20x the flair',
    ],
  };
}

/// The colour scheme for a paid tier, or null for Free (which keeps the
/// hand-tuned Evergreen scheme).
ColorScheme? planColorScheme(AcatrainPlan plan, Brightness brightness) {
  final light = brightness == Brightness.light;
  switch (plan) {
    case AcatrainPlan.free:
      return null;
    case AcatrainPlan.starter:
      final base = ColorScheme.fromSeed(
        seedColor: const Color(0xFF1D4FB8),
        brightness: brightness,
        dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
      );
      return light
          ? base.copyWith(
            primary: const Color(0xFF1D3F8F),
            surface: const Color(0xFFF7F9FE),
            surfaceContainerLow: const Color(0xFFEFF3FB),
            tertiary: const Color(0xFF5C6A86),
            tertiaryContainer: const Color(0xFFDCE3F2),
            onTertiaryContainer: const Color(0xFF16213A),
          )
          : base.copyWith(
            surface: const Color(0xFF0C1220),
            surfaceContainerLow: const Color(0xFF131B2C),
            surfaceContainer: const Color(0xFF172033),
          );
    case AcatrainPlan.pro:
      final base = ColorScheme.fromSeed(
        seedColor: const Color(0xFF5B2A86),
        brightness: brightness,
        dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
      );
      return light
          ? base.copyWith(
            primary: const Color(0xFF4A1F73),
            surface: const Color(0xFFFBF8FD),
            surfaceContainerLow: const Color(0xFFF4EEF8),
            tertiary: const Color(0xFF8A6A12),
            tertiaryContainer: const Color(0xFFF6E3B0),
            onTertiaryContainer: const Color(0xFF3A2A00),
          )
          : base.copyWith(
            surface: const Color(0xFF120C18),
            surfaceContainerLow: const Color(0xFF1B1323),
            surfaceContainer: const Color(0xFF21182A),
            tertiary: const Color(0xFFE3C274),
            tertiaryContainer: const Color(0xFF594410),
            onTertiaryContainer: const Color(0xFFFBE7B5),
          );
    case AcatrainPlan.max:
      // Gold on near-black in both modes; light mode swaps the black
      // surfaces for warm ivory but keeps the black-and-gold accents.
      final base = ColorScheme.fromSeed(
        seedColor: const Color(0xFFB08A3E),
        brightness: brightness,
        dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
      );
      return light
          ? base.copyWith(
            primary: const Color(0xFF1B1812),
            onPrimary: const Color(0xFFF3D98E),
            primaryContainer: const Color(0xFF2A241A),
            onPrimaryContainer: const Color(0xFFF1D995),
            secondary: const Color(0xFF7A5E1F),
            secondaryContainer: const Color(0xFFF1E3BF),
            onSecondaryContainer: const Color(0xFF2B1F00),
            tertiary: const Color(0xFF8C6B1C),
            tertiaryContainer: const Color(0xFFF5E2AE),
            onTertiaryContainer: const Color(0xFF362700),
            surface: const Color(0xFFFBF8F1),
            surfaceContainerLowest: const Color(0xFFFFFFFF),
            surfaceContainerLow: const Color(0xFFF4EFE3),
            surfaceContainer: const Color(0xFFEEE8DA),
            surfaceContainerHigh: const Color(0xFFE8E1D1),
            surfaceContainerHighest: const Color(0xFFE2DAC8),
          )
          : base.copyWith(
            primary: const Color(0xFFE3C274),
            onPrimary: const Color(0xFF1B1405),
            primaryContainer: const Color(0xFF2A2417),
            onPrimaryContainer: const Color(0xFFF3DC9C),
            secondaryContainer: const Color(0xFF3A301B),
            onSecondaryContainer: const Color(0xFFF1DFB3),
            tertiary: const Color(0xFFF0D593),
            tertiaryContainer: const Color(0xFF4A3A12),
            onTertiaryContainer: const Color(0xFFFBE8BA),
            surface: const Color(0xFF0B0A08),
            surfaceContainerLowest: const Color(0xFF060504),
            surfaceContainerLow: const Color(0xFF15130F),
            surfaceContainer: const Color(0xFF1B1813),
            surfaceContainerHigh: const Color(0xFF231F18),
            surfaceContainerHighest: const Color(0xFF2C271E),
            outlineVariant: const Color(0xFF4A4232),
          );
  }
}

/// Hero tones that pair with [planColorScheme].
AcatrainTones planTones(AcatrainPlan plan, ColorScheme colors) => AcatrainTones(
  heroAccent: switch (plan) {
    AcatrainPlan.free => colors.primary,
    AcatrainPlan.max =>
      colors.brightness == Brightness.light
          ? const Color(0xFFE3C274)
          : colors.primary,
    _ =>
      colors.brightness == Brightness.light
          ? colors.inversePrimary
          : colors.primary,
  },
  heroBody: colors.onPrimaryContainer,
);

enum DemoPaymentMethod { googlePlay, appleIos, stripeWeb }

extension on DemoPaymentMethod {
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

Duration _motion(BuildContext context, int ms) =>
    MediaQuery.of(context).disableAnimations
        ? Duration(milliseconds: math.min(ms, 120))
        : Duration(milliseconds: ms);

class SubscriptionPage extends StatelessWidget {
  const SubscriptionPage({super.key, required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) {
      final theme = Theme.of(context);
      final current = AcatrainPlan.fromId(store.plan);
      return Scaffold(
        appBar: AppBar(title: Text(tr(context, 'Plans'))),
        body: ListView(
          padding: AcatrainLayout.pagePadding(context),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: AcatrainLayout.maxContentWidth(context),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr(context, 'Make it yours.'),
                      style: theme.textTheme.displaySmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      tr(
                        context,
                        'Each plan dresses Acatrain in a more luxurious theme.',
                      ),
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const _DemoNotice(),
                    const SizedBox(height: 22),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final columns =
                            constraints.maxWidth >= 1040
                                ? 4
                                : constraints.maxWidth >= 600
                                ? 2
                                : 1;
                        final width =
                            (constraints.maxWidth - 14 * (columns - 1)) /
                            columns;
                        return Wrap(
                          spacing: 14,
                          runSpacing: 14,
                          children: [
                            for (final plan in AcatrainPlan.values)
                              SizedBox(
                                width: width,
                                child: _PlanCard(
                                  plan: plan,
                                  current: plan == current,
                                  onChoose: () => _choose(context, plan),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    },
  );

  Future<void> _choose(BuildContext context, AcatrainPlan plan) async {
    if (plan == AcatrainPlan.free) {
      await store.setPlan(plan.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr(context, 'Back to the Evergreen theme.'))),
        );
      }
      return;
    }
    final paid = await showDemoCheckout(context, plan);
    if (!paid || !context.mounted) return;
    await store.setPlan(plan.id);
    if (!context.mounted) return;
    await _celebrate(context, plan);
  }
}

class _DemoNotice extends StatelessWidget {
  const _DemoNotice();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(AcatrainRadii.l),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: theme.colorScheme.onTertiaryContainer,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              tr(context, 'Demo checkout. You will never be charged.'),
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onTertiaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.current,
    required this.onChoose,
  });

  final AcatrainPlan plan;
  final bool current;
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground =
        plan == AcatrainPlan.free ? Colors.white : const Color(0xFFFFF8E7);
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AcatrainRadii.xl),
        side:
            current
                ? BorderSide(color: theme.colorScheme.primary, width: 2)
                : BorderSide.none,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 132,
            decoration: BoxDecoration(gradient: plan.gradient),
            child: Stack(
              children: [
                if (plan != AcatrainPlan.free)
                  Positioned.fill(child: _Sheen(color: plan.shine)),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            switch (plan) {
                              AcatrainPlan.free => Icons.eco_rounded,
                              AcatrainPlan.starter => Icons.diamond_outlined,
                              AcatrainPlan.pro => Icons.auto_awesome_rounded,
                              AcatrainPlan.max =>
                                Icons.workspace_premium_rounded,
                            },
                            color: foreground,
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            plan.label,
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: foreground,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        tr(context, plan.themeName),
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: foreground.withValues(alpha: 0.86),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      plan.price == 0 ? '\$0' : '\$${plan.price}',
                      style: theme.textTheme.headlineLarge,
                    ),
                    const SizedBox(width: 4),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Text(
                        tr(context, '/ month'),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                for (final perk in plan.perks)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_rounded,
                          size: 18,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            tr(context, perk),
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child:
                      current
                          ? OutlinedButton(
                            onPressed: null,
                            child: Text(tr(context, 'Current plan')),
                          )
                          : FilledButton(
                            onPressed: onChoose,
                            child: Text(
                              plan == AcatrainPlan.free
                                  ? tr(context, 'Switch to Free')
                                  : '${tr(context, 'Subscribe')} · ${plan.priceLabel}',
                            ),
                          ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A slow diagonal highlight that sweeps across the plan art.
class _Sheen extends StatefulWidget {
  const _Sheen({required this.color});
  final Color color;

  @override
  State<_Sheen> createState() => _SheenState();
}

class _SheenState extends State<_Sheen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value * 3 - 1;
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-1 + t * 2, -1),
              end: Alignment(t * 2, 1),
              colors: [
                widget.color.withValues(alpha: 0),
                widget.color.withValues(alpha: 0.35),
                widget.color.withValues(alpha: 0),
              ],
            ),
          ),
        );
      },
    ),
  );
}

/// Walks through a simulated checkout for [plan]. Returns true when the
/// pretend payment "succeeds". Never contacts any payment provider.
Future<bool> showDemoCheckout(BuildContext context, AcatrainPlan plan) async {
  final method = await showModalBottomSheet<DemoPaymentMethod>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 560),
    isScrollControlled: true,
    builder: (_) => SingleChildScrollView(child: _MethodPicker(plan: plan)),
  );
  if (method == null || !context.mounted) return false;
  final checkout = switch (method) {
    DemoPaymentMethod.googlePlay => showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      constraints: const BoxConstraints(maxWidth: 560),
      builder:
          (_) => SingleChildScrollView(child: _GooglePlaySheet(plan: plan)),
    ),
    DemoPaymentMethod.appleIos => showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      constraints: const BoxConstraints(maxWidth: 520),
      builder: (_) => SingleChildScrollView(child: _AppleSheet(plan: plan)),
    ),
    DemoPaymentMethod.stripeWeb => showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: const Color(0x99000000),
      transitionDuration: _motion(context, 320),
      pageBuilder: (_, _, _) => _StripeCheckout(plan: plan),
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
  return await checkout ?? false;
}

class _MethodPicker extends StatefulWidget {
  const _MethodPicker({required this.plan});
  final AcatrainPlan plan;

  @override
  State<_MethodPicker> createState() => _MethodPickerState();
}

class _MethodPickerState extends State<_MethodPicker> {
  DemoPaymentMethod _method = _defaultMethod();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final methods = DemoPaymentMethod.values;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.plan.label} · ${widget.plan.priceLabel}${tr(context, '/ month')}',
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
                  onTap: () => setState(() => _method = methods[i]),
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

enum _PayStage { review, processing, done }

/// Shared state machine for the three fake checkouts: review → processing →
/// done, then closes itself with `true`.
mixin _FakePayment<T extends StatefulWidget> on State<T> {
  _PayStage stage = _PayStage.review;

  Future<void> pay({int processingMs = 1600}) async {
    if (stage != _PayStage.review) return;
    setState(() => stage = _PayStage.processing);
    await Future<void>.delayed(_motion(context, processingMs));
    if (!mounted) return;
    setState(() => stage = _PayStage.done);
    await Future<void>.delayed(_motion(context, 1300));
    if (mounted) Navigator.pop(context, true);
  }
}

/// Draws a ring, then a check mark, as [progress] runs 0 → 1.
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
    duration: _motion(context, duration.inMilliseconds),
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

// ---------------------------------------------------------------------------
// Google Play style
// ---------------------------------------------------------------------------

class _GooglePlaySheet extends StatefulWidget {
  const _GooglePlaySheet({required this.plan});
  final AcatrainPlan plan;

  @override
  State<_GooglePlaySheet> createState() => _GooglePlaySheetState();
}

class _GooglePlaySheetState extends State<_GooglePlaySheet> with _FakePayment {
  static const _green = Color(0xFF01875F);
  static const _ink = Color(0xFF1F1F1F);
  static const _muted = Color(0xFF5F6368);

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    return PopScope(
      canPop: stage == _PayStage.review,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: DefaultTextStyle(
          style: const TextStyle(fontSize: 14, color: _ink),
          child: AnimatedSize(
            duration: _motion(context, 320),
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
                        onPressed: () => Navigator.pop(context, false),
                        icon: const Icon(Icons.close_rounded, color: _muted),
                      ),
                  ],
                ),
                const Divider(height: 24, color: Color(0xFFE8EAED)),
                AnimatedSwitcher(
                  duration: _motion(context, 260),
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
                    _ => Column(
                      key: const ValueKey('review'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _PlanThumb(plan: plan, radius: 12),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Acatrain ${plan.label}',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const Text(
                                    'Acatrain',
                                    style: TextStyle(color: _muted),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        _playRow(
                          'Subscription',
                          '${plan.priceLabel}/month',
                          bold: true,
                        ),
                        _playRow('Billing starts', 'Today'),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFE8EAED)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.credit_card_rounded, color: _muted),
                              SizedBox(width: 12),
                              Expanded(child: Text('Demo Visa ·· 4242')),
                              Icon(Icons.chevron_right_rounded, color: _muted),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Cancel anytime in Settings. This is a demo: no '
                          'money moves and Google Play is not contacted.',
                          style: TextStyle(fontSize: 12, color: _muted),
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
                                stage == _PayStage.review ? () => pay() : null,
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
                    ),
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

class _PlanThumb extends StatelessWidget {
  const _PlanThumb({required this.plan, this.radius = 10, this.size = 52});
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

// ---------------------------------------------------------------------------
// iOS App Store style
// ---------------------------------------------------------------------------

class _AppleSheet extends StatefulWidget {
  const _AppleSheet({required this.plan});
  final AcatrainPlan plan;

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
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7);
    final card = dark ? const Color(0xFF2C2C2E) : Colors.white;
    final ink = dark ? Colors.white : Colors.black;
    const muted = Color(0xFF8E8E93);
    final plan = widget.plan;
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
            child: DefaultTextStyle(
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
                        GestureDetector(
                          onTap: () => Navigator.pop(context, false),
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: muted.withValues(alpha: 0.24),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: muted,
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
                            _PlanThumb(plan: plan, radius: 12, size: 56),
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
                                  const Text(
                                    'Subscription',
                                    style: TextStyle(
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
                          '${plan.priceLabel} per month',
                          muted,
                        ),
                        _appleRow('Account', 'demo@example.com', muted),
                        _appleRow('Pay with', 'Demo Card ···· 4242', muted),
                      ],
                    ),
                  ),
                  const SizedBox(height: 26),
                  SizedBox(
                    height: 132,
                    child: AnimatedSwitcher(
                      duration: _motion(context, 260),
                      child: switch (stage) {
                        _PayStage.review => GestureDetector(
                          key: const ValueKey('confirm'),
                          onTap: () => pay(processingMs: 1500),
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
                                'Double-Click to Pay',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  color: ink,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Tap here to confirm with Side Button',
                                style: TextStyle(color: muted, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        _PayStage.processing => Column(
                          key: const ValueKey('faceid'),
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _FaceScan(color: _blue),
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
          // The glowing side-button cue on the sheet's right edge.
          if (stage == _PayStage.review)
            Positioned(
              right: 0,
              top: 18,
              child: AnimatedBuilder(
                animation: _pulse,
                builder:
                    (context, _) => Container(
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
                            color: _blue.withValues(alpha: 0.6 * _pulse.value),
                            blurRadius: 12,
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

class _StripeCheckout extends StatefulWidget {
  const _StripeCheckout({required this.plan});
  final AcatrainPlan plan;

  @override
  State<_StripeCheckout> createState() => _StripeCheckoutState();
}

class _StripeCheckoutState extends State<_StripeCheckout> with _FakePayment {
  static const _blurple = Color(0xFF635BFF);
  static const _ink = Color(0xFF30313D);
  static const _muted = Color(0xFF6D6E78);
  static const _line = Color(0xFFE6E6EB);

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    return PopScope(
      canPop: stage == _PayStage.review,
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
                child: DefaultTextStyle(
                  style: const TextStyle(fontSize: 14, color: _ink),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        color: const Color(0xFFF6F9FC),
                        padding: const EdgeInsets.fromLTRB(24, 18, 12, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                _PlanThumb(plan: plan, radius: 6, size: 28),
                                const SizedBox(width: 10),
                                const Flexible(
                                  child: Text(
                                    'Acatrain',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
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
                                if (stage == _PayStage.review)
                                  IconButton(
                                    onPressed:
                                        () => Navigator.pop(context, false),
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      color: _muted,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Subscribe to Acatrain ${plan.label}',
                              style: const TextStyle(color: _muted),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  plan.priceLabel,
                                  style: const TextStyle(
                                    fontSize: 34,
                                    fontWeight: FontWeight.w600,
                                    color: _ink,
                                  ),
                                ),
                                const Padding(
                                  padding: EdgeInsets.only(bottom: 6, left: 6),
                                  child: Text(
                                    'per\nmonth',
                                    style: TextStyle(
                                      fontSize: 12,
                                      height: 1.15,
                                      color: _muted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _label('Email'),
                            _field('demo@example.com'),
                            const SizedBox(height: 14),
                            _label('Card information'),
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: _line),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Column(
                                children: [
                                  const _StripeCell(
                                    '4242 4242 4242 4242',
                                    trailing: Icon(
                                      Icons.credit_card_rounded,
                                      size: 18,
                                      color: _blurple,
                                    ),
                                  ),
                                  const Divider(height: 1, color: _line),
                                  IntrinsicHeight(
                                    child: Row(
                                      children: const [
                                        Expanded(child: _StripeCell('12 / 34')),
                                        VerticalDivider(width: 1, color: _line),
                                        Expanded(child: _StripeCell('123')),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            _label('Name on card'),
                            _field('Demo Learner'),
                            const SizedBox(height: 22),
                            AnimatedContainer(
                              duration: _motion(context, 280),
                              curve: Curves.easeOutCubic,
                              height: 46,
                              decoration: BoxDecoration(
                                color:
                                    stage == _PayStage.done
                                        ? const Color(0xFF1EA672)
                                        : _blurple,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Material(
                                type: MaterialType.transparency,
                                child: InkWell(
                                  onTap:
                                      stage == _PayStage.review
                                          ? () => pay(processingMs: 1800)
                                          : null,
                                  child: Center(
                                    child: AnimatedSwitcher(
                                      duration: _motion(context, 220),
                                      child: switch (stage) {
                                        _PayStage.review => Text(
                                          'Subscribe · ${plan.priceLabel}',
                                          key: const ValueKey('label'),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        _PayStage.processing =>
                                          const SizedBox.square(
                                            key: ValueKey('spin'),
                                            dimension: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.4,
                                              color: Colors.white,
                                            ),
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
                            ),
                            const SizedBox(height: 14),
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.lock_outline_rounded,
                                  size: 14,
                                  color: _muted,
                                ),
                                SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    'Stripe-style checkout · simulated',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _muted,
                                    ),
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
    );
  }

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

  Widget _field(String value) => Container(
    decoration: BoxDecoration(
      border: Border.all(color: _line),
      borderRadius: BorderRadius.circular(6),
    ),
    child: _StripeCell(value),
  );
}

class _StripeCell extends StatelessWidget {
  const _StripeCell(this.value, {this.trailing});
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
    child: Row(
      children: [Expanded(child: Text(value)), if (trailing != null) trailing!],
    ),
  );
}

// ---------------------------------------------------------------------------
// Welcome moment
// ---------------------------------------------------------------------------

Future<void> _celebrate(BuildContext context, AcatrainPlan plan) =>
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.transparent,
      transitionDuration: _motion(context, 520),
      pageBuilder: (_, _, _) => _Welcome(plan: plan),
      transitionBuilder:
          (context, animation, _, child) => FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          ),
    );

class _Welcome extends StatefulWidget {
  const _Welcome({required this.plan});
  final AcatrainPlan plan;

  @override
  State<_Welcome> createState() => _WelcomeState();
}

class _WelcomeState extends State<_Welcome>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..forward();
  Timer? _autoClose;

  @override
  void initState() {
    super.initState();
    _autoClose = Timer(const Duration(milliseconds: 3600), () {
      if (mounted) Navigator.maybePop(context);
    });
  }

  @override
  void dispose() {
    _autoClose?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => Navigator.maybePop(context),
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(gradient: plan.gradient),
          child: Stack(
            children: [
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder:
                      (context, _) => CustomPaint(
                        painter: _SparklePainter(_controller.value, plan.shine),
                      ),
                ),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: _motion(context, 900),
                        curve: Curves.elasticOut,
                        builder:
                            (context, t, child) =>
                                Transform.scale(scale: t, child: child),
                        child: ExpressiveBadge(
                          shape: ExpressiveShape.sunny,
                          size: 112,
                          color: plan.shine,
                          child: Icon(
                            Icons.workspace_premium_rounded,
                            size: 56,
                            color: plan.deep,
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        isCantonese(context)
                            ? '歡迎使用 ${plan.label}'
                            : 'Welcome to ${plan.label}',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.displaySmall?.copyWith(
                          color: const Color(0xFFFFF8E7),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        isCantonese(context)
                            ? '已套用「${tr(context, plan.themeName)}」主題'
                            : 'Your ${plan.themeName} theme is on.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: const Color(
                            0xFFFFF8E7,
                          ).withValues(alpha: 0.85),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        tr(context, 'Demo only. Nothing was charged.'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: const Color(0xFFFFF8E7).withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SparklePainter extends CustomPainter {
  _SparklePainter(this.t, this.color);
  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(7);
    final center = size.center(Offset.zero);
    final reach = size.shortestSide * 0.62;
    for (var i = 0; i < 46; i++) {
      final angle = random.nextDouble() * math.pi * 2;
      final speed = 0.45 + random.nextDouble() * 0.55;
      final delay = random.nextDouble() * 0.25;
      final p = ((t - delay) / (1 - delay)).clamp(0.0, 1.0);
      if (p == 0) continue;
      final eased = Curves.easeOutCubic.transform(p);
      final position =
          center +
          Offset(math.cos(angle), math.sin(angle)) * reach * speed * eased;
      final radius = (2 + random.nextDouble() * 3.5) * (1 - p * 0.6);
      final paint = Paint()..color = color.withValues(alpha: (1 - p) * 0.95);
      // Four-point star.
      canvas.drawPath(
        Path()
          ..moveTo(position.dx, position.dy - radius * 2.2)
          ..lineTo(position.dx + radius * 0.5, position.dy)
          ..lineTo(position.dx, position.dy + radius * 2.2)
          ..lineTo(position.dx - radius * 0.5, position.dy)
          ..close()
          ..moveTo(position.dx - radius * 2.2, position.dy)
          ..lineTo(position.dx, position.dy + radius * 0.5)
          ..lineTo(position.dx + radius * 2.2, position.dy)
          ..lineTo(position.dx, position.dy - radius * 0.5)
          ..close(),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_SparklePainter old) => old.t != t;
}

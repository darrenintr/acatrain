import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_ui.dart';
import 'demo_checkout.dart';
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

enum BillingCycle { monthly, yearly }

extension BillingCycleDetails on BillingCycle {
  /// "month" or "year", for "$10.00/month" style labels.
  String get unit => this == BillingCycle.monthly ? 'month' : 'year';

  /// The translatable "/ month" suffix used on plan cards.
  String get perLabel => this == BillingCycle.monthly ? '/ month' : '/ year';

  DateTime advance(DateTime from) =>
      _addMonths(from, this == BillingCycle.monthly ? 1 : 12);
}

DateTime _addMonths(DateTime date, int months) {
  final index = date.month - 1 + months;
  final year = date.year + index ~/ 12;
  final month = index % 12 + 1;
  final lastDay = DateTime(year, month + 1, 0).day;
  return DateTime(
    year,
    month,
    math.min(date.day, lastDay),
    date.hour,
    date.minute,
    date.second,
  );
}

extension AcatrainPlanPricing on AcatrainPlan {
  /// Yearly billing is ten months' price: two months free.
  int priceCents(BillingCycle cycle) =>
      price * 100 * (cycle == BillingCycle.yearly ? 10 : 1);
}

String formatMoney(int cents) {
  final dollars = (cents ~/ 100).toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  return '\$$dollars.${(cents % 100).toString().padLeft(2, '0')}';
}

const _shortMonths = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// "23 Oct 2026", as the English-only store sheets print dates.
String formatDemoDate(DateTime date) =>
    '${date.day} ${_shortMonths[date.month - 1]} ${date.year}';

/// A date in the app's display language.
String formatPlanDate(BuildContext context, DateTime date) =>
    isCantonese(context)
        ? '${date.year}年${date.month}月${date.day}日'
        : formatDemoDate(date);

/// One pretend payment in the billing history.
class DemoInvoice {
  const DemoInvoice({
    required this.number,
    required this.date,
    required this.description,
    required this.cents,
    required this.instrument,
    this.creditCents = 0,
  });

  final String number;
  final DateTime date;
  final String description;

  /// What was "paid" after any credit.
  final int cents;
  final int creditCents;
  final String instrument;

  factory DemoInvoice.fromJson(Map<String, dynamic> json) => DemoInvoice(
    number: json['number'] as String,
    date: DateTime.parse(json['date'] as String),
    description: json['description'] as String,
    cents: json['cents'] as int,
    creditCents: json['creditCents'] as int? ?? 0,
    instrument: json['instrument'] as String,
  );

  Map<String, dynamic> toJson() => {
    'number': number,
    'date': date.toIso8601String(),
    'description': description,
    'cents': cents,
    'creditCents': creditCents,
    'instrument': instrument,
  };
}

String _receiptNumber(math.Random random) {
  String four() => (1000 + random.nextInt(9000)).toString();
  return 'ACA-${four()}-${four()}';
}

/// The pretend billing record for a paid plan: renews, cancels and keeps
/// receipts like a real subscription, entirely on this device.
class DemoSubscription {
  const DemoSubscription({
    required this.plan,
    required this.cycle,
    required this.method,
    required this.instrument,
    required this.memberSince,
    required this.memberNumber,
    required this.periodStart,
    required this.renewsAt,
    this.cancelled = false,
    this.ended = false,
    this.invoices = const [],
  });

  final AcatrainPlan plan;
  final BillingCycle cycle;
  final DemoPaymentMethod method;
  final String instrument;
  final DateTime memberSince;
  final String memberNumber;
  final DateTime periodStart;
  final DateTime renewsAt;

  /// Cancelled plans stay active until [renewsAt], then end.
  final bool cancelled;
  final bool ended;

  /// Newest first.
  final List<DemoInvoice> invoices;

  bool get active => !ended && plan != AcatrainPlan.free;
  int get priceCents => plan.priceCents(cycle);

  static DemoSubscription? fromStore(AppStore store) {
    final json = store.demoSubscription;
    if (json == null) return null;
    try {
      return DemoSubscription.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  factory DemoSubscription.fromJson(Map<String, dynamic> json) =>
      DemoSubscription(
        plan: AcatrainPlan.fromId(json['plan'] as String),
        cycle: BillingCycle.values.byName(json['cycle'] as String),
        method: DemoPaymentMethod.values.byName(json['method'] as String),
        instrument: json['instrument'] as String,
        memberSince: DateTime.parse(json['memberSince'] as String),
        memberNumber: json['memberNumber'] as String,
        periodStart: DateTime.parse(json['periodStart'] as String),
        renewsAt: DateTime.parse(json['renewsAt'] as String),
        cancelled: json['cancelled'] as bool? ?? false,
        ended: json['ended'] as bool? ?? false,
        invoices: [
          for (final invoice in json['invoices'] as List? ?? const [])
            DemoInvoice.fromJson(invoice as Map<String, dynamic>),
        ],
      );

  Map<String, dynamic> toJson() => {
    'plan': plan.id,
    'cycle': cycle.name,
    'method': method.name,
    'instrument': instrument,
    'memberSince': memberSince.toIso8601String(),
    'memberNumber': memberNumber,
    'periodStart': periodStart.toIso8601String(),
    'renewsAt': renewsAt.toIso8601String(),
    'cancelled': cancelled,
    'ended': ended,
    'invoices': [for (final invoice in invoices) invoice.toJson()],
  };

  DemoSubscription copyWith({
    DateTime? periodStart,
    DateTime? renewsAt,
    bool? cancelled,
    bool? ended,
    List<DemoInvoice>? invoices,
  }) => DemoSubscription(
    plan: plan,
    cycle: cycle,
    method: method,
    instrument: instrument,
    memberSince: memberSince,
    memberNumber: memberNumber,
    periodStart: periodStart ?? this.periodStart,
    renewsAt: renewsAt ?? this.renewsAt,
    cancelled: cancelled ?? this.cancelled,
    ended: ended ?? this.ended,
    invoices: invoices ?? this.invoices,
  );

  /// Catches up on time spent away: bills each renewal that has passed
  /// (with a receipt), or ends a cancelled plan once its period is over.
  DemoSubscription settle(DateTime now, {math.Random? random}) {
    if (!active) return this;
    if (cancelled) return now.isBefore(renewsAt) ? this : copyWith(ended: true);
    final rng = random ?? math.Random();
    var start = periodStart;
    var renews = renewsAt;
    final added = <DemoInvoice>[];
    // Cap the catch-up so a clock jump cannot stall start-up.
    while (!now.isBefore(renews) && added.length < 36) {
      added.insert(
        0,
        DemoInvoice(
          number: _receiptNumber(rng),
          date: renews,
          description: 'Acatrain ${plan.label} · ${cycle.name} renewal',
          cents: priceCents,
          instrument: instrument,
        ),
      );
      start = renews;
      renews = cycle.advance(renews);
    }
    if (added.isEmpty) return this;
    return copyWith(
      periodStart: start,
      renewsAt: renews,
      invoices: [...added, ...invoices],
    );
  }
}

/// Applies renewals and cancellations that fell due while the app was
/// closed. Safe to call any time.
Future<void> settleDemoSubscription(AppStore store, {DateTime? now}) async {
  final current = DemoSubscription.fromStore(store);
  if (current == null || !current.active) return;
  final settled = current.settle(now ?? DateTime.now());
  if (identical(settled, current)) return;
  await store.setDemoSubscription(
    settled.toJson(),
    plan: settled.ended ? AcatrainPlan.free.id : null,
  );
}

/// What a checkout will charge for moving to [plan] on [cycle].
class DemoQuote {
  const DemoQuote({
    required this.plan,
    required this.cycle,
    required this.startsAt,
    this.replacing,
    this.creditCents = 0,
  });

  /// Prices a change from [current], crediting its unused time like the
  /// stores do when you switch plans mid-period.
  factory DemoQuote.change(
    AcatrainPlan plan,
    BillingCycle cycle,
    DemoSubscription? current,
    DateTime now,
  ) {
    var credit = 0;
    if (current != null && current.active && now.isBefore(current.renewsAt)) {
      final period = current.renewsAt.difference(current.periodStart);
      final left = current.renewsAt.difference(now);
      if (period.inSeconds > 0) {
        credit = (current.priceCents * left.inSeconds / period.inSeconds)
            .round()
            .clamp(0, plan.priceCents(cycle));
      }
    }
    return DemoQuote(
      plan: plan,
      cycle: cycle,
      startsAt: now,
      replacing: credit > 0 ? current!.plan : null,
      creditCents: credit,
    );
  }

  final AcatrainPlan plan;
  final BillingCycle cycle;
  final DateTime startsAt;
  final AcatrainPlan? replacing;
  final int creditCents;

  int get priceCents => plan.priceCents(cycle);
  int get dueTodayCents => math.max(0, priceCents - creditCents);
  DateTime get renewsAt => cycle.advance(startsAt);
}

class SubscriptionPage extends StatefulWidget {
  const SubscriptionPage({super.key, required this.store});
  final AppStore store;

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  final _plansKey = GlobalKey();
  BillingCycle? _cycle;

  AppStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    unawaited(settleDemoSubscription(store));
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) {
      final theme = Theme.of(context);
      final current = AcatrainPlan.fromId(store.plan);
      final record = DemoSubscription.fromStore(store);
      final subscription =
          record != null && record.active && record.plan == current
              ? record
              : null;
      final cycle = _cycle ?? subscription?.cycle ?? BillingCycle.monthly;
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
                    if (subscription != null) ...[
                      _MembershipPanel(
                        subscription: subscription,
                        holder: store.displayName,
                        onCancel: () => _cancel(subscription),
                        onResume: () => _resume(subscription),
                        onChangePlan: _showPlans,
                      ),
                      const SizedBox(height: 32),
                    ],
                    Text(
                      key: _plansKey,
                      tr(
                        context,
                        subscription == null
                            ? 'Make it yours.'
                            : 'Change your plan',
                      ),
                      style:
                          subscription == null
                              ? theme.textTheme.displaySmall
                              : theme.textTheme.headlineMedium,
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
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SegmentedButton<BillingCycle>(
                          showSelectedIcon: false,
                          segments: [
                            ButtonSegment(
                              value: BillingCycle.monthly,
                              label: Text(tr(context, 'Monthly')),
                            ),
                            ButtonSegment(
                              value: BillingCycle.yearly,
                              label: Text(tr(context, 'Yearly')),
                            ),
                          ],
                          selected: {cycle},
                          onSelectionChanged: (value) {
                            HapticFeedback.selectionClick();
                            setState(() => _cycle = value.first);
                          },
                        ),
                        _Pill(
                          text: tr(context, '2 months free with yearly'),
                          color: theme.colorScheme.tertiaryContainer,
                          onColor: theme.colorScheme.onTertiaryContainer,
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
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
                                  cycle: cycle,
                                  current:
                                      plan == current &&
                                      (plan == AcatrainPlan.free ||
                                          subscription == null ||
                                          subscription.cycle == cycle),
                                  action: _actionLabel(
                                    context,
                                    plan,
                                    current,
                                    subscription,
                                    cycle,
                                  ),
                                  onChoose: () => _choose(plan, cycle),
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

  String _actionLabel(
    BuildContext context,
    AcatrainPlan plan,
    AcatrainPlan current,
    DemoSubscription? subscription,
    BillingCycle cycle,
  ) {
    if (plan == AcatrainPlan.free) return tr(context, 'Switch to Free');
    final price = formatMoney(plan.priceCents(cycle));
    final verb =
        current == AcatrainPlan.free
            ? 'Subscribe'
            : plan == current
            ? (cycle == BillingCycle.yearly
                ? 'Switch to yearly'
                : 'Switch to monthly')
            : plan.index > current.index
            ? 'Upgrade'
            : 'Downgrade';
    return '${tr(context, verb)} · $price';
  }

  void _showPlans() {
    final target = _plansKey.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: demoMotion(context, 520),
      curve: Curves.easeInOutCubic,
    );
  }

  Future<void> _choose(AcatrainPlan plan, BillingCycle cycle) async {
    final record = DemoSubscription.fromStore(store);
    final subscription = record != null && record.active ? record : null;
    if (plan == AcatrainPlan.free) {
      if (subscription != null && !subscription.cancelled) {
        await _cancel(subscription);
        return;
      }
      if (subscription != null) return;
      await store.setPlan(plan.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr(context, 'Back to the Evergreen theme.'))),
        );
      }
      return;
    }
    final now = DateTime.now();
    final quote = DemoQuote.change(plan, cycle, subscription, now);
    final charge = await showDemoCheckout(
      context,
      quote,
      payer: DemoPayer(name: store.displayName, email: store.email),
    );
    if (charge == null || !mounted) return;
    final random = math.Random();
    final next = DemoSubscription(
      plan: plan,
      cycle: cycle,
      method: charge.method,
      instrument: charge.instrument,
      memberSince: subscription?.memberSince ?? now,
      memberNumber:
          record?.memberNumber ??
          List.generate(4, (_) => random.nextInt(10)).join(),
      periodStart: now,
      renewsAt: quote.renewsAt,
      invoices: [
        DemoInvoice(
          number: _receiptNumber(random),
          date: now,
          description:
              'Acatrain ${plan.label} · ${cycle.name}'
              '${quote.replacing == null ? '' : ' (from ${quote.replacing!.label})'}',
          cents: quote.dueTodayCents,
          creditCents: quote.creditCents,
          instrument: charge.instrument,
        ),
        ...?record?.invoices,
      ],
    );
    await store.setDemoSubscription(next.toJson(), plan: plan.id);
    if (!mounted) return;
    await _celebrate(context, next, store.displayName);
  }

  Future<void> _cancel(DemoSubscription subscription) async {
    final theme = Theme.of(context);
    final until = formatPlanDate(context, subscription.renewsAt);
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            icon: Icon(
              Icons.heart_broken_outlined,
              color: theme.colorScheme.error,
            ),
            title: Text(
              isCantonese(context)
                  ? '取消 ${subscription.plan.label}？'
                  : 'Cancel ${subscription.plan.label}?',
            ),
            content: Text(
              isCantonese(context)
                  ? '你可以用「${tr(context, subscription.plan.themeName)}」主題直到 $until。之後 Acatrain 會轉返常青主題。到期前隨時可以恢復。'
                  : 'You keep the ${subscription.plan.themeName} theme until '
                      '$until. After that Acatrain goes back to Evergreen. '
                      'You can resume any time before then.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(tr(context, 'Keep plan')),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: Text(tr(context, 'Cancel subscription')),
              ),
            ],
          ),
    );
    if (confirmed != true) return;
    await store.setDemoSubscription(
      subscription.copyWith(cancelled: true).toJson(),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isCantonese(context)
              ? '已取消訂閱，可以用到 $until。'
              : 'Subscription cancelled. Yours until $until.',
        ),
      ),
    );
  }

  Future<void> _resume(DemoSubscription subscription) async {
    HapticFeedback.mediumImpact();
    await store.setDemoSubscription(
      subscription.copyWith(cancelled: false).toJson(),
    );
    if (!mounted) return;
    final date = formatPlanDate(context, subscription.renewsAt);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isCantonese(context)
              ? '歡迎返嚟！方案會喺 $date 續訂。'
              : 'Welcome back. Your plan renews on $date.',
        ),
      ),
    );
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

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.color, required this.onColor});
  final String text;
  final Color color;
  final Color onColor;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(AcatrainRadii.full),
    ),
    child: Text(
      text,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(color: onColor),
    ),
  );
}

IconData _planIcon(AcatrainPlan plan) => switch (plan) {
  AcatrainPlan.free => Icons.eco_rounded,
  AcatrainPlan.starter => Icons.diamond_outlined,
  AcatrainPlan.pro => Icons.auto_awesome_rounded,
  AcatrainPlan.max => Icons.workspace_premium_rounded,
};

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.cycle,
    required this.current,
    required this.action,
    required this.onChoose,
  });

  final AcatrainPlan plan;
  final BillingCycle cycle;
  final bool current;
  final String action;
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground =
        plan == AcatrainPlan.free ? Colors.white : const Color(0xFFFFF8E7);
    final cents = plan.priceCents(cycle);
    final badge = switch (plan) {
      AcatrainPlan.pro => 'Most popular',
      AcatrainPlan.max => 'High-roller pick',
      _ => null,
    };
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
                          Icon(_planIcon(plan), color: foreground, size: 22),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              plan.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: foreground,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              tr(context, plan.themeName),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: foreground.withValues(alpha: 0.86),
                              ),
                            ),
                          ),
                          if (badge != null)
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 150),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: plan.shine,
                                  borderRadius: BorderRadius.circular(
                                    AcatrainRadii.full,
                                  ),
                                ),
                                child: Text(
                                  tr(context, badge),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: plan.deep,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                            ),
                        ],
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
                    AnimatedSwitcher(
                      duration: demoMotion(context, 240),
                      transitionBuilder:
                          (child, animation) => FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween(
                                begin: const Offset(0, 0.3),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          ),
                      child: Text(
                        plan.price == 0 ? '\$0' : '\$${cents ~/ 100}',
                        key: ValueKey(cents),
                        style: theme.textTheme.headlineLarge,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Text(
                        tr(context, cycle.perLabel),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(
                  height: 20,
                  child:
                      cycle == BillingCycle.yearly && plan.price > 0
                          ? Text(
                            isCantonese(context)
                                ? '即係每月 ${formatMoney((cents / 12).round())}'
                                : 'That is ${formatMoney((cents / 12).round())} a month',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.tertiary,
                            ),
                          )
                          : null,
                ),
                const SizedBox(height: 4),
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
                            child: Text(action),
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

// ---------------------------------------------------------------------------
// Membership: card, status, billing history and receipts
// ---------------------------------------------------------------------------

class _MembershipPanel extends StatelessWidget {
  const _MembershipPanel({
    required this.subscription,
    required this.holder,
    required this.onCancel,
    required this.onResume,
    required this.onChangePlan,
  });

  final DemoSubscription subscription;
  final String? holder;
  final VoidCallback onCancel;
  final VoidCallback onResume;
  final VoidCallback onChangePlan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final s = subscription;
    final card = Container(
      alignment: Alignment.center,
      constraints: const BoxConstraints(maxWidth: 400),
      child: MemberCard(
        plan: s.plan,
        holder: holder,
        number: s.memberNumber,
        since: s.memberSince,
      ),
    );
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                isCantonese(context)
                    ? '你嘅 ${s.plan.label} 會籍'
                    : 'Your ${s.plan.label} membership',
                style: theme.textTheme.headlineSmall,
              ),
            ),
            const SizedBox(width: 10),
            _Pill(
              text: tr(context, s.cancelled ? 'Cancelled' : 'Active'),
              color:
                  s.cancelled ? colors.errorContainer : colors.primaryContainer,
              onColor:
                  s.cancelled
                      ? colors.onErrorContainer
                      : colors.onPrimaryContainer,
            ),
          ],
        ),
        const SizedBox(height: 14),
        _detail(
          context,
          Icons.event_repeat_rounded,
          tr(context, s.cancelled ? 'Access until' : 'Next payment'),
          s.cancelled
              ? formatPlanDate(context, s.renewsAt)
              : '${formatMoney(s.priceCents)} · ${formatPlanDate(context, s.renewsAt)}',
        ),
        _detail(
          context,
          Icons.payments_outlined,
          tr(context, 'Payment method'),
          '${s.instrument} · ${s.method.label}',
        ),
        _detail(
          context,
          Icons.calendar_month_outlined,
          tr(context, 'Billing'),
          tr(context, s.cycle == BillingCycle.yearly ? 'Yearly' : 'Monthly'),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton.tonalIcon(
              onPressed: onChangePlan,
              icon: const Icon(Icons.swap_vert_rounded),
              label: Text(tr(context, 'Change plan')),
            ),
            if (s.cancelled)
              FilledButton.icon(
                onPressed: onResume,
                icon: const Icon(Icons.replay_rounded),
                label: Text(tr(context, 'Resume subscription')),
              )
            else
              TextButton(
                style: TextButton.styleFrom(foregroundColor: colors.error),
                onPressed: onCancel,
                child: Text(tr(context, 'Cancel subscription')),
              ),
          ],
        ),
      ],
    );
    return LayoutBuilder(
      builder:
          (context, constraints) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (constraints.maxWidth >= 720)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: card),
                    const SizedBox(width: 28),
                    Expanded(child: details),
                  ],
                )
              else ...[
                Center(child: card),
                const SizedBox(height: 22),
                details,
              ],
              if (s.invoices.isNotEmpty) ...[
                const SizedBox(height: 26),
                Text(
                  tr(context, 'Billing history'),
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                _BillingHistory(invoices: s.invoices, plan: s.plan),
              ],
            ],
          ),
    );
  }

  Widget _detail(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(value, style: theme.textTheme.titleSmall),
          ),
        ],
      ),
    );
  }
}

class _BillingHistory extends StatefulWidget {
  const _BillingHistory({required this.invoices, required this.plan});
  final List<DemoInvoice> invoices;
  final AcatrainPlan plan;

  @override
  State<_BillingHistory> createState() => _BillingHistoryState();
}

class _BillingHistoryState extends State<_BillingHistory> {
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final invoices = widget.invoices;
    final shown = _all ? invoices : invoices.take(4).toList();
    return Column(
      children: [
        for (var i = 0; i < shown.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Material(
              color: theme.colorScheme.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: segmentRadius(i, shown.length),
              ),
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                onTap: () => showDemoReceipt(context, shown[i], widget.plan),
                leading: Icon(
                  Icons.receipt_long_outlined,
                  color: theme.colorScheme.primary,
                ),
                title: Text(shown[i].description),
                subtitle: Text(
                  '${formatPlanDate(context, shown[i].date)} · ${shown[i].instrument}',
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatMoney(shown[i].cents),
                      style: theme.textTheme.titleSmall,
                    ),
                    Text(
                      tr(context, 'Paid'),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (invoices.length > 4 && !_all)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => setState(() => _all = true),
              child: Text(
                isCantonese(context)
                    ? '顯示全部 ${invoices.length} 張收據'
                    : 'Show all ${invoices.length} receipts',
              ),
            ),
          ),
      ],
    );
  }
}

/// A paper-style receipt for one pretend payment.
Future<void> showDemoReceipt(
  BuildContext context,
  DemoInvoice invoice,
  AcatrainPlan plan,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: Colors.transparent,
  constraints: const BoxConstraints(maxWidth: 480),
  builder: (_) => SingleChildScrollView(child: _Receipt(invoice, plan)),
);

class _Receipt extends StatelessWidget {
  const _Receipt(this.invoice, this.plan);
  final DemoInvoice invoice;
  final AcatrainPlan plan;

  static const _ink = Color(0xFF1A1A1A);
  static const _muted = Color(0xFF6B6B6B);

  @override
  Widget build(BuildContext context) {
    Widget row(String label, String value, {bool bold = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: bold ? _ink : _muted,
                fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: ClipPath(
        clipper: const _ZigzagClipper(),
        child: Container(
          color: const Color(0xFFFFFEFA),
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 34),
          child: DefaultTextStyle.merge(
            style: const TextStyle(fontSize: 14, color: _ink),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    PlanThumb(plan: plan, radius: 10, size: 40),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Receipt from Acatrain',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, color: _muted),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  formatMoney(invoice.cents),
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Paid ${formatDemoDate(invoice.date)}',
                  style: const TextStyle(color: _muted),
                ),
                const SizedBox(height: 18),
                row('Receipt number', invoice.number),
                row('Payment method', invoice.instrument),
                row(
                  'Date paid',
                  '${formatDemoDate(invoice.date)}, '
                      '${invoice.date.hour.toString().padLeft(2, '0')}:'
                      '${invoice.date.minute.toString().padLeft(2, '0')}',
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: _DashedLine(),
                ),
                const Text(
                  'SUMMARY',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.2,
                    color: _muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                row(
                  invoice.description,
                  formatMoney(invoice.cents + invoice.creditCents),
                ),
                if (invoice.creditCents > 0)
                  row(
                    'Credit for unused time',
                    '−${formatMoney(invoice.creditCents)}',
                  ),
                row('Tax', formatMoney(0)),
                const Divider(height: 18),
                row('Amount paid', formatMoney(invoice.cents), bold: true),
                const SizedBox(height: 20),
                Text(
                  tr(context, 'Demo receipt. No money moved.'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: _muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedLine extends StatelessWidget {
  const _DashedLine();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder:
        (context, constraints) => Row(
          children: List.generate(
            (constraints.maxWidth / 8).floor(),
            (_) => Container(
              width: 4,
              height: 1,
              margin: const EdgeInsets.only(right: 4),
              color: const Color(0xFFBDBDBD),
            ),
          ),
        ),
  );
}

/// Rounded top, torn-paper zigzag bottom.
class _ZigzagClipper extends CustomClipper<Path> {
  const _ZigzagClipper();

  @override
  Path getClip(Size size) {
    const tooth = 10.0;
    const radius = 16.0;
    final path =
        Path()
          ..moveTo(0, radius)
          ..quadraticBezierTo(0, 0, radius, 0)
          ..lineTo(size.width - radius, 0)
          ..quadraticBezierTo(size.width, 0, size.width, radius)
          ..lineTo(size.width, size.height - tooth);
    final teeth = (size.width / (tooth * 2)).ceil();
    final step = size.width / teeth;
    for (var i = teeth; i > 0; i--) {
      final x = i * step;
      path
        ..lineTo(x - step / 2, size.height)
        ..lineTo(x - step, size.height - tooth);
    }
    return path..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// A metal membership card that tilts toward the pointer or finger, with a
/// glare that follows it.
class MemberCard extends StatefulWidget {
  const MemberCard({
    super.key,
    required this.plan,
    required this.number,
    required this.since,
    this.holder,
  });

  final AcatrainPlan plan;
  final String number;
  final DateTime since;
  final String? holder;

  @override
  State<MemberCard> createState() => _MemberCardState();
}

class _MemberCardState extends State<MemberCard> {
  Offset _tilt = Offset.zero;

  void _aim(Offset local, Size size) {
    if (MediaQuery.of(context).disableAnimations) return;
    setState(() {
      _tilt = Offset(
        (local.dx / size.width * 2 - 1).clamp(-1.0, 1.0),
        (local.dy / size.height * 2 - 1).clamp(-1.0, 1.0),
      );
    });
  }

  void _rest() => setState(() => _tilt = Offset.zero);

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    const ink = Color(0xFFFFF8E7);
    final holder =
        (widget.holder?.trim().isNotEmpty ?? false)
            ? widget.holder!.trim().toUpperCase()
            : 'ACATRAIN MEMBER';
    final since =
        '${widget.since.month.toString().padLeft(2, '0')}/'
        '${(widget.since.year % 100).toString().padLeft(2, '0')}';
    return AspectRatio(
      aspectRatio: 1.586,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          final scale = size.width / 360;
          return MouseRegion(
            onHover: (event) => _aim(event.localPosition, size),
            onExit: (_) => _rest(),
            child: GestureDetector(
              onPanUpdate: (details) => _aim(details.localPosition, size),
              onPanEnd: (_) => _rest(),
              onPanCancel: _rest,
              child: TweenAnimationBuilder<Offset>(
                tween: Tween(end: _tilt),
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                builder:
                    (context, tilt, child) => Transform(
                      alignment: Alignment.center,
                      transform:
                          Matrix4.identity()
                            ..setEntry(3, 2, 0.0012)
                            ..rotateX(-tilt.dy * 0.22)
                            ..rotateY(tilt.dx * 0.22),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: plan.gradient,
                          borderRadius: BorderRadius.circular(18 * scale),
                          boxShadow: [
                            BoxShadow(
                              color: plan.deep.withValues(alpha: 0.45),
                              blurRadius: 28,
                              offset: Offset(-tilt.dx * 10, 14 - tilt.dy * 6),
                            ),
                          ],
                        ),
                        foregroundDecoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18 * scale),
                          gradient: RadialGradient(
                            center: Alignment(tilt.dx, tilt.dy),
                            radius: 0.9,
                            colors: [
                              Colors.white.withValues(alpha: 0.28),
                              Colors.white.withValues(alpha: 0),
                            ],
                          ),
                        ),
                        child: child,
                      ),
                    ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18 * scale),
                  child: Stack(
                    children: [
                      Positioned.fill(child: _Sheen(color: plan.shine)),
                      Padding(
                        padding: EdgeInsets.all(20 * scale),
                        child: DefaultTextStyle.merge(
                          style: TextStyle(color: ink, fontSize: 13 * scale),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'ACATRAIN',
                                    style: TextStyle(
                                      fontSize: 15 * scale,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 3 * scale,
                                    ),
                                  ),
                                  const Spacer(),
                                  Icon(
                                    _planIcon(plan),
                                    color: plan.shine,
                                    size: 18 * scale,
                                  ),
                                  SizedBox(width: 6 * scale),
                                  Text(
                                    plan.label.toUpperCase(),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.2 * scale,
                                      color: plan.shine,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 22 * scale),
                              _Chip(scale: scale, color: plan.shine),
                              const Spacer(),
                              Text(
                                '••••  ••••  ••••  ${widget.number}',
                                style: TextStyle(
                                  fontSize: 18 * scale,
                                  letterSpacing: 1.5 * scale,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                              SizedBox(height: 12 * scale),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Expanded(
                                    child: Text(
                                      holder,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 1.2 * scale,
                                      ),
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        'MEMBER SINCE',
                                        style: TextStyle(
                                          fontSize: 8 * scale,
                                          letterSpacing: 1 * scale,
                                          color: ink.withValues(alpha: 0.7),
                                        ),
                                      ),
                                      Text(
                                        since,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The card's contact chip.
class _Chip extends StatelessWidget {
  const _Chip({required this.scale, required this.color});
  final double scale;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 42 * scale,
    height: 32 * scale,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(6 * scale),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.lerp(color, Colors.white, 0.35)!,
          color,
          Color.lerp(color, Colors.black, 0.25)!,
        ],
      ),
    ),
    child: CustomPaint(
      painter: _ChipLines(Colors.black.withValues(alpha: 0.25)),
    ),
  );
}

class _ChipLines extends CustomPainter {
  _ChipLines(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..strokeWidth = 1
          ..style = PaintingStyle.stroke;
    final w = size.width;
    final h = size.height;
    canvas
      ..drawLine(Offset(0, h / 3), Offset(w * 0.35, h / 3), paint)
      ..drawLine(Offset(0, h * 2 / 3), Offset(w * 0.35, h * 2 / 3), paint)
      ..drawLine(Offset(w * 0.65, h / 3), Offset(w, h / 3), paint)
      ..drawLine(Offset(w * 0.65, h * 2 / 3), Offset(w, h * 2 / 3), paint)
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(w * 0.35, h * 0.2, w * 0.65, h * 0.8),
          const Radius.circular(3),
        ),
        paint,
      );
  }

  @override
  bool shouldRepaint(_ChipLines old) => old.color != color;
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

// ---------------------------------------------------------------------------
// Welcome moment
// ---------------------------------------------------------------------------

Future<void> _celebrate(
  BuildContext context,
  DemoSubscription subscription,
  String? holder,
) => showGeneralDialog<void>(
  context: context,
  barrierDismissible: true,
  barrierLabel: 'Close',
  barrierColor: Colors.transparent,
  transitionDuration: demoMotion(context, 520),
  pageBuilder:
      (_, _, _) => _Welcome(subscription: subscription, holder: holder),
  transitionBuilder:
      (context, animation, _, child) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      ),
);

class _Welcome extends StatefulWidget {
  const _Welcome({required this.subscription, this.holder});
  final DemoSubscription subscription;
  final String? holder;

  @override
  State<_Welcome> createState() => _WelcomeState();
}

class _WelcomeState extends State<_Welcome>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  )..forward();
  Timer? _autoClose;

  @override
  void initState() {
    super.initState();
    HapticFeedback.heavyImpact();
    _autoClose = Timer(const Duration(milliseconds: 5200), () {
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
    final subscription = widget.subscription;
    final plan = subscription.plan;
    final theme = Theme.of(context);
    const ink = Color(0xFFFFF8E7);
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
                        foregroundPainter: _ConfettiPainter(_controller.value, [
                          plan.shine,
                          ink,
                          Color.lerp(plan.deep, plan.shine, 0.5)!,
                        ]),
                      ),
                ),
              ),
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // The new card flips in, like it just arrived.
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: demoMotion(context, 1100),
                        curve: Curves.easeOutBack,
                        builder:
                            (context, t, child) => Transform(
                              alignment: Alignment.center,
                              transform:
                                  Matrix4.identity()
                                    ..setEntry(3, 2, 0.0015)
                                    ..rotateY((1 - t) * math.pi / 2)
                                    ..scaleByDouble(
                                      0.8 + 0.2 * t,
                                      0.8 + 0.2 * t,
                                      1,
                                      1,
                                    ),
                              child: Opacity(
                                opacity: t.clamp(0.0, 1.0),
                                child: child,
                              ),
                            ),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 340),
                          child: MemberCard(
                            plan: plan,
                            holder: widget.holder,
                            number: subscription.memberNumber,
                            since: subscription.memberSince,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        isCantonese(context)
                            ? '歡迎使用 ${plan.label}'
                            : 'Welcome to ${plan.label}',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.displaySmall?.copyWith(
                          color: ink,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        isCantonese(context)
                            ? '已套用「${tr(context, plan.themeName)}」主題'
                            : 'Your ${plan.themeName} theme is on.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: ink.withValues(alpha: 0.85),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isCantonese(context)
                            ? '下次續訂：${formatPlanDate(context, subscription.renewsAt)}'
                            : 'Renews ${formatPlanDate(context, subscription.renewsAt)}',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: ink.withValues(alpha: 0.75),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        tr(context, 'Demo only. Nothing was charged.'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: ink.withValues(alpha: 0.7),
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

/// Ribbons of confetti drifting down from above the screen.
class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.t, this.colors);
  final double t;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(11);
    for (var i = 0; i < 70; i++) {
      final x = random.nextDouble() * size.width;
      final delay = random.nextDouble() * 0.35;
      final fall = 0.55 + random.nextDouble() * 0.6;
      final p = ((t - delay) / (1 - delay)).clamp(0.0, 1.0);
      if (p == 0) continue;
      final y = -20 + (size.height + 40) * p * fall;
      final sway = math.sin((p * 6 + i) * math.pi) * 14;
      final spin = p * math.pi * (4 + random.nextDouble() * 6);
      final w = 5 + random.nextDouble() * 5;
      final h = 9 + random.nextDouble() * 7;
      final fade = p > 0.8 ? (1 - p) / 0.2 : 1.0;
      canvas
        ..save()
        ..translate(x + sway, y)
        ..rotate(spin)
        ..scale(1, math.cos(spin * 1.3).abs() * 0.8 + 0.2);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: w, height: h),
          const Radius.circular(1.5),
        ),
        Paint()
          ..color = colors[i % colors.length].withValues(alpha: 0.9 * fade),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
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

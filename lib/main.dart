import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_ui.dart';
import 'expressive.dart';
import 'models.dart';
import 'store.dart';
import 'study_page.dart';
import 'subscription.dart';
import 'google_identity.dart';
import 'haptics.dart';
import 'language.dart';
import 'loading_indicator.dart';
import 'launch_screen.dart';
import 'plan_icon.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Preferences hold the plan, language and appearance, so the launch
  // animation already wears the right theme.
  final store = AppStore(await SharedPreferences.getInstance());
  runApp(AcatrainApp(store: store, ready: _boot(store)));
}

/// Start-up work that runs behind the launch animation.
Future<void> _boot(AppStore store) async {
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

const _fontFamily = 'Google Sans Flex';
const _fontFallback = ['Figtree'];

FontWeight _nearestWeight(double weight) {
  final steps = [100, 200, 300, 400, 500, 600, 700, 800, 900];
  final nearest = steps.reduce(
    (a, b) => (weight - a).abs() < (weight - b).abs() ? a : b,
  );
  return FontWeight.values[(nearest ~/ 100) - 1];
}

TextStyle _type({
  required double size,
  required double height,
  required double weight,
  double letterSpacing = 0,
}) => TextStyle(
  fontFamily: _fontFamily,
  fontFamilyFallback: _fontFallback,
  fontSize: size,
  height: height / size,
  fontWeight: _nearestWeight(weight),
  fontVariations: [FontVariation('wght', weight)],
  letterSpacing: letterSpacing,
);

class AcatrainApp extends StatelessWidget {
  const AcatrainApp({super.key, required this.store, this.ready});
  final AppStore store;

  /// Start-up work to play the launch animation over. Without it the home
  /// screen shows straight away (the store must already be loaded).
  final Future<void>? ready;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder:
        (context, _) => MaterialApp(
          title: 'Acatrain',
          debugShowCheckedModeBanner: false,
          locale:
              store.languageCode == 'zh_HK'
                  ? const Locale('zh', 'HK')
                  : const Locale('en'),
          supportedLocales: const [Locale('en'), Locale('zh', 'HK')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          themeMode: switch (store.appearance) {
            'light' => ThemeMode.light,
            'dark' => ThemeMode.dark,
            _ => ThemeMode.system,
          },
          // A slower morph so switching plans feels like an unveiling.
          themeAnimationDuration: const Duration(milliseconds: 900),
          themeAnimationCurve: Curves.easeInOutCubic,
          // Settings → Motion → Reduced forces the reduce-motion path
          // everywhere, whatever the device setting says.
          builder:
              (context, child) =>
                  store.motion == 'reduced'
                      ? MediaQuery(
                        data: MediaQuery.of(
                          context,
                        ).copyWith(disableAnimations: true),
                        child: child!,
                      )
                      : child!,
          theme: _theme(Brightness.light, AcatrainPlan.fromId(store.plan)),
          darkTheme: _theme(Brightness.dark, AcatrainPlan.fromId(store.plan)),
          home:
              ready == null
                  ? HomeShell(store: store)
                  : AcatrainLaunchScreen(
                    ready: ready,
                    child: HomeShell(store: store),
                  ),
        ),
  );

  ThemeData _theme(Brightness brightness, AcatrainPlan plan) {
    final colors =
        planColorScheme(plan, brightness) ??
        (brightness == Brightness.light
            ? const ColorScheme(
              brightness: Brightness.light,
              primary: Color(0xFF36684F),
              onPrimary: Color(0xFFFFFFFF),
              primaryContainer: Color(0xFFB8F0CF),
              onPrimaryContainer: Color(0xFF0E3A26),
              secondary: Color(0xFF4E6356),
              onSecondary: Color(0xFFFFFFFF),
              secondaryContainer: Color(0xFFD0E8D7),
              onSecondaryContainer: Color(0xFF0B2616),
              tertiary: Color(0xFF3B6470),
              onTertiary: Color(0xFFFFFFFF),
              tertiaryContainer: Color(0xFFBFE9F8),
              onTertiaryContainer: Color(0xFF0A3642),
              error: Color(0xFFBA1A1A),
              onError: Color(0xFFFFFFFF),
              errorContainer: Color(0xFFFFDAD6),
              onErrorContainer: Color(0xFF410002),
              surface: Color(0xFFF6FBF4),
              onSurface: Color(0xFF171D19),
              surfaceContainerLowest: Color(0xFFFFFFFF),
              surfaceContainerLow: Color(0xFFF0F5EE),
              surfaceContainer: Color(0xFFEAEFE9),
              surfaceContainerHigh: Color(0xFFE4EAE3),
              surfaceContainerHighest: Color(0xFFDFE4DD),
              onSurfaceVariant: Color(0xFF404943),
              outline: Color(0xFF707973),
              outlineVariant: Color(0xFFC0C9C1),
              inverseSurface: Color(0xFF2C322E),
              onInverseSurface: Color(0xFFEDF2EB),
              inversePrimary: Color(0xFF9DD4B4),
            )
            : ColorScheme.fromSeed(
              seedColor: const Color(0xFF426B58),
              brightness: Brightness.dark,
            ));
    final tones =
        plan != AcatrainPlan.free
            ? planTones(plan, colors)
            : brightness == Brightness.light
            ? AcatrainTones.light
            : AcatrainTones.dark(colors);

    final textTheme = TextTheme(
      displaySmall: _type(
        size: 36,
        height: 42,
        weight: 750,
        letterSpacing: -1.2,
      ),
      headlineLarge: _type(
        size: 32,
        height: 38,
        weight: 750,
        letterSpacing: -1.0,
      ),
      headlineMedium: _type(
        size: 28,
        height: 34,
        weight: 700,
        letterSpacing: -0.5,
      ),
      headlineSmall: _type(
        size: 24,
        height: 30,
        weight: 700,
        letterSpacing: -0.4,
      ),
      titleLarge: _type(size: 20, height: 26, weight: 700, letterSpacing: -0.3),
      titleMedium: _type(
        size: 16,
        height: 22,
        weight: 650,
        letterSpacing: -0.1,
      ),
      titleSmall: _type(size: 14, height: 20, weight: 650),
      bodyLarge: _type(size: 16, height: 24, weight: 400),
      bodyMedium: _type(size: 14, height: 20, weight: 400),
      bodySmall: _type(size: 12, height: 16, weight: 400),
      labelLarge: _type(size: 14, height: 20, weight: 650),
      labelMedium: _type(size: 12, height: 16, weight: 600),
      labelSmall: _type(size: 12, height: 16, weight: 700, letterSpacing: 0.8),
    ).apply(bodyColor: colors.onSurface, displayColor: colors.onSurface);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colors,
      scaffoldBackgroundColor: colors.surface,
      visualDensity: VisualDensity.standard,
      fontFamily: _fontFamily,
      textTheme: textTheme,
      extensions: [tones],
      appBarTheme: AppBarTheme(
        toolbarHeight: 64,
        scrolledUnderElevation: 0,
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: colors.onSurface,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceContainerHigh,
        hintStyle: TextStyle(color: colors.onSurfaceVariant),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AcatrainRadii.full),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AcatrainRadii.full),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AcatrainRadii.full),
          borderSide: BorderSide(color: colors.primary, width: 2),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: colors.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AcatrainRadii.xl),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 80,
        elevation: 0,
        backgroundColor: colors.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        indicatorColor: colors.secondaryContainer,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AcatrainRadii.l),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return _type(
            size: 12,
            height: 16,
            weight: selected ? 700 : 550,
          ).copyWith(
            color: selected ? colors.onSurface : colors.onSurfaceVariant,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color:
                selected
                    ? colors.onSecondaryContainer
                    : colors.onSurfaceVariant,
          );
        }),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: const StadiumBorder(),
          minimumSize: const Size(0, 56),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          textStyle: _type(size: 16, height: 20, weight: 650),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: const StadiumBorder(),
          minimumSize: const Size(0, 56),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          textStyle: _type(size: 16, height: 20, weight: 650),
          side: BorderSide(color: colors.outlineVariant),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: const StadiumBorder(),
          textStyle: _type(size: 14, height: 20, weight: 650),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: ZoomPageTransitionsBuilder(),
          TargetPlatform.windows: ZoomPageTransitionsBuilder(),
        },
      ),
    );
  }
}

const _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];
const _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

String _formatEyebrowDate(DateTime date) =>
    '${_weekdays[date.weekday - 1]}, ${date.day} ${_months[date.month - 1]}';

/// Page-switch fade: the effects spring, stretched over the spatial
/// spring's settle time that drives the accompanying slide.
final _pageFadeCurve = AcatrainSpringCurve(
  AcatrainSprings.effectsDefault,
  span: AcatrainSprings.settle(AcatrainSprings.spatialDefault),
);

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.store});
  final AppStore store;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _page = 0;
  String _query = '';
  String _subject = 'All';
  bool _sortMostDue = false;

  AppStore get store => widget.store;

  static const _labels = ['Today', 'Library', 'Review', 'Settings'];
  static const _icons = [
    Icons.space_dashboard_outlined,
    Icons.collections_bookmark_outlined,
    Icons.history_edu_outlined,
    Icons.tune,
  ];
  static const _selectedIcons = [
    Icons.space_dashboard_rounded,
    Icons.collections_bookmark_rounded,
    Icons.history_edu_rounded,
    Icons.tune_rounded,
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    store.contentReleases.addListener(_contentReady);
  }

  /// New content has been applied; sessions already open keep their items.
  void _contentReady() {
    if (!mounted) return;
    final theme = Theme.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: theme.colorScheme.inverseSurface,
          content: Text(
            tr(
              context,
              'New study content is ready. It applies to your next session.',
            ),
          ),
          action: SnackBarAction(
            label: tr(context, 'Refresh'),
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
              setState(() => _page = 0);
            },
          ),
        ),
      );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    store.contentReleases.removeListener(_contentReady);
    _hapticPreview?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        store.cloudConfigured &&
        !store.busy &&
        (store.lastContentSync == null ||
            DateTime.now().difference(store.lastContentSync!).inMinutes >= 5)) {
      unawaited(store.syncContent());
    }
  }

  void _open(StudySet set) {
    unawaited(Haptics.play(AcHaptic.tap));
    Navigator.push(
      context,
      AcatrainPageRoute<void>(builder: (_) => SetPage(set: set, store: store)),
    );
  }

  void _startSession(StudySet set, List<StudyItem> items, bool quiz) {
    unawaited(Haptics.play(AcHaptic.tap));
    Navigator.push(
      context,
      AcatrainPageRoute<void>(
        builder:
            (_) => StudyPage(set: set, items: items, quiz: quiz, store: store),
      ),
    );
  }

  void _selectPage(int index) {
    if (index == _page) return;
    unawaited(Haptics.play(AcHaptic.tick));
    setState(() => _page = index);
  }

  Timer? _hapticPreview;

  /// Plays a tick, then previews `confirm` at the new strength.
  void _setHapticLevel(int level) {
    unawaited(store.setHapticLevel(level));
    unawaited(Haptics.play(AcHaptic.tick));
    _hapticPreview?.cancel();
    if (level > 0) {
      _hapticPreview = Timer(
        const Duration(milliseconds: 260),
        () => Haptics.play(AcHaptic.confirm),
      );
    }
  }

  /// A content check the learner started: unlike background syncs, it
  /// reports its outcome with a haptic.
  Future<void> _syncContentByUser() async {
    unawaited(Haptics.play(AcHaptic.tap));
    final ok = await store.syncContent();
    unawaited(Haptics.play(ok ? AcHaptic.done : AcHaptic.error));
  }

  Future<void> _syncProgressByUser() async {
    unawaited(Haptics.play(AcHaptic.tap));
    final ok = await store.syncProgress();
    unawaited(Haptics.play(ok ? AcHaptic.done : AcHaptic.error));
  }

  void _searchLibrary(String query) {
    setState(() {
      _query = query;
      _page = 1;
    });
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) {
      final windowClass = AcatrainLayout.classOf(context);
      final useRail = windowClass != AcatrainWindowClass.compact;
      final expanded = windowClass == AcatrainWindowClass.expanded;
      final theme = Theme.of(context);
      return Scaffold(
        appBar: expanded ? null : _appBar(theme),
        body: SafeArea(
          // Expanded layouts draw their own header instead of using an
          // AppBar, so Scaffold does not reserve the system status bar.
          top: expanded,
          bottom: false,
          child: Column(
            children: [
              AnimatedSwitcher(
                duration: AcatrainSprings.durationOf(
                  context,
                  AcatrainSprings.effectsDefault,
                ),
                switchInCurve: AcatrainSprings.effectsDefaultCurve,
                switchOutCurve: AcatrainSprings.effectsDefaultCurve,
                child:
                    store.busy
                        ? const LinearProgressIndicator(
                          key: ValueKey('busy'),
                          minHeight: 2,
                        )
                        : const SizedBox(key: ValueKey('idle'), height: 2),
              ),
              if (store.offline) const _OfflineBanner(),
              Expanded(
                child: Row(
                  children: [
                    if (useRail)
                      _ExpressiveRail(
                        selectedIndex: _page,
                        onSelected: _selectPage,
                        labels:
                            _labels.map((label) => tr(context, label)).toList(),
                        icons: _icons,
                        selectedIcons: _selectedIcons,
                      ),
                    Expanded(
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: AcatrainLayout.maxContentWidth(context),
                          ),
                          child: AnimatedSwitcher(
                            duration: AcatrainSprings.durationOf(
                              context,
                              AcatrainSprings.spatialDefault,
                            ),
                            // The full-screen pages have transparent areas.
                            // Keeping the outgoing page in the switcher's
                            // default stack makes both screens readable at
                            // once during a cross-fade.
                            layoutBuilder:
                                (currentChild, previousChildren) =>
                                    currentChild ?? const SizedBox.shrink(),
                            transitionBuilder: (child, animation) {
                              final slide = Tween<Offset>(
                                begin: const Offset(0.025, 0),
                                end: Offset.zero,
                              ).animate(
                                CurvedAnimation(
                                  parent: animation,
                                  curve: AcatrainSprings.spatialDefaultCurve,
                                ),
                              );
                              return FadeTransition(
                                opacity: CurvedAnimation(
                                  parent: animation,
                                  curve: _pageFadeCurve,
                                ),
                                child: SlideTransition(
                                  position: slide,
                                  child: child,
                                ),
                              );
                            },
                            child: KeyedSubtree(
                              key: ValueKey(_page),
                              child: switch (_page) {
                                0 =>
                                  expanded
                                      ? _todayExpanded(theme)
                                      : _today(theme),
                                1 => _library(theme, expanded: expanded),
                                2 => _review(theme, expanded: expanded),
                                _ => _settings(theme, expanded: expanded),
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar:
            useRail
                ? null
                : NavigationBar(
                  selectedIndex: _page,
                  onDestinationSelected: _selectPage,
                  destinations: List.generate(
                    _labels.length,
                    (i) => NavigationDestination(
                      icon: Icon(_icons[i]),
                      selectedIcon: Icon(_selectedIcons[i]),
                      label: tr(context, _labels[i]),
                    ),
                  ),
                ),
      );
    },
  );

  PreferredSizeWidget _appBar(ThemeData theme) => AppBar(
    titleSpacing: 20,
    title:
        _page == 0
            ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ExpressiveBadge(
                  shape: ExpressiveShape.cookie9,
                  size: 34,
                  color: theme.colorScheme.primary,
                  child: Icon(
                    Icons.school_rounded,
                    size: 17,
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'acatrain',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                  ),
                ),
              ],
            )
            : null,
    actions: _appBarActions(theme),
  );

  List<Widget> _appBarActions(ThemeData theme) => [
    IconButton(
      tooltip: tr(context, 'Sync content'),
      onPressed: store.busy ? null : _syncContentByUser,
      icon: const Icon(Icons.sync_rounded),
    ),
    Padding(
      padding: const EdgeInsets.only(left: 4, right: 12),
      child: PopupMenuButton<String>(
        tooltip: store.email ?? tr(context, 'Guest'),
        onSelected: (value) {
          switch (value) {
            case 'info':
              _personalInfo();
              break;
            case 'settings':
              _selectPage(3);
              break;
            case 'theme':
              store.setAppearance(switch (store.appearance) {
                'system' => 'light',
                'light' => 'dark',
                _ => 'system',
              });
              break;
            case 'auth':
              if (store.uid == null) {
                _login();
              } else {
                unawaited(store.signOut());
              }
              break;
          }
        },
        itemBuilder:
            (context) => [
              PopupMenuItem<String>(
                enabled: false,
                child: Text(
                  store.displayName ?? store.email ?? tr(context, 'Guest'),
                ),
              ),
              PopupMenuItem(
                value: 'info',
                child: ListTile(
                  leading: const Icon(Icons.person_outline_rounded),
                  title: Text(tr(context, 'Personal info')),
                ),
              ),
              PopupMenuItem(
                value: 'settings',
                child: ListTile(
                  leading: const Icon(Icons.tune_rounded),
                  title: Text(tr(context, 'Settings')),
                ),
              ),
              PopupMenuItem(
                value: 'theme',
                child: ListTile(
                  leading: const Icon(Icons.brightness_6_outlined),
                  title: Text(
                    '${tr(context, 'Appearance')}: ${tr(context, switch (store.appearance) {
                      'light' => 'Light',
                      'dark' => 'Dark',
                      _ => 'System',
                    })}',
                  ),
                ),
              ),
              PopupMenuItem(
                value: 'auth',
                child: ListTile(
                  leading: Icon(
                    store.uid == null
                        ? Icons.login_rounded
                        : Icons.logout_rounded,
                  ),
                  title: Text(
                    tr(context, store.uid == null ? 'Sign in' : 'Sign out'),
                  ),
                ),
              ),
            ],
        child: CircleAvatar(
          radius: 18,
          backgroundColor: theme.colorScheme.tertiaryContainer,
          child: Text(
            (store.displayName?.isNotEmpty ?? false)
                ? store.displayName![0].toUpperCase()
                : (store.email?.isNotEmpty ?? false)
                ? store.email![0].toUpperCase()
                : 'A',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onTertiaryContainer,
            ),
          ),
        ),
      ),
    ),
  ];

  Widget _pageHeader(ThemeData theme, String title, {String? eyebrow}) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 0, 8),
        child: SizedBox(
          height: 88,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (eyebrow != null)
                      Text(
                        eyebrow,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    Text(title, style: theme.textTheme.headlineLarge),
                  ],
                ),
              ),
              ..._appBarActions(theme),
            ],
          ),
        ),
      );

  Widget _today(ThemeData theme) {
    final padding = AcatrainLayout.pagePadding(context);
    return FadingListView(
      padding: padding,
      children: [
        const SizedBox(height: 4),
        Text(
          isCantonese(context)
              ? '${DateTime.now().month} 月 ${DateTime.now().day} 日'
              : _formatEyebrowDate(DateTime.now()),
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          tr(context, 'Make room\nfor learning.'),
          style: theme.textTheme.displaySmall,
        ),
        const SizedBox(height: 20),
        _TodayHero(
          store: store,
          compact: true,
          onOpen: _open,
          onStart: (set, items) => _startSession(set, items, false),
          onPracticeTest: (set, items) => _startSession(set, items, true),
        ),
        const SizedBox(height: 8),
        _MetricStrip(store: store),
        const SizedBox(height: 28),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  tr(context, 'Your study sets'),
                  style: theme.textTheme.titleLarge,
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _page = 1),
                child: Text(tr(context, 'See all')),
              ),
            ],
          ),
        ),
        _TodaySetList(sets: store.bundle.sets, store: store, onOpen: _open),
        const SizedBox(height: 24),
        Text(
          store.status,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _todayExpanded(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 32, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 88,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isCantonese(context)
                            ? '${DateTime.now().month} 月 ${DateTime.now().day} 日'
                            : _formatEyebrowDate(DateTime.now()),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        tr(context, 'Make room for learning.'),
                        style: theme.textTheme.headlineLarge,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 320,
                  height: 56,
                  child: TextField(
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search_rounded),
                      hintText: tr(context, 'Search study sets'),
                    ),
                    onSubmitted: _searchLibrary,
                  ),
                ),
                const SizedBox(width: 8),
                ..._appBarActions(theme),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: FadingSingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _TodayHero(
                          store: store,
                          compact: false,
                          onOpen: _open,
                          onStart:
                              (set, items) => _startSession(set, items, false),
                          onPracticeTest:
                              (set, items) => _startSession(set, items, true),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 28, 4, 14),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  tr(context, 'Your study sets'),
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontSize: 22,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () => setState(() => _page = 1),
                                child: Text(tr(context, 'Open library')),
                              ),
                            ],
                          ),
                        ),
                        _DesktopSetGrid(
                          sets: store.bundle.sets,
                          store: store,
                          onOpen: _open,
                          columns: 3,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                SizedBox(
                  width: 340,
                  child: _ReviewQueuePanel(
                    store: store,
                    onOpenSet: _open,
                    onStart: _startSession,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _library(ThemeData theme, {required bool expanded}) {
    final subjects = [
      'All',
      ...store.bundle.sets.map((s) => s.subject).toSet(),
    ];
    final filter = subjects.contains(_subject) ? _subject : 'All';
    var sets =
        store.bundle.sets
            .where(
              (s) =>
                  (filter == 'All' || s.subject == filter) &&
                  '${s.title} ${s.subject} ${s.description}'
                      .toLowerCase()
                      .contains(_query.toLowerCase()),
            )
            .toList();
    if (_sortMostDue) {
      sets = [...sets]
        ..sort((a, b) => store.dueCount(b).compareTo(store.dueCount(a)));
    }
    final totalItems = sets.fold<int>(0, (n, s) => n + s.items.length);
    return FadingListView(
      padding: AcatrainLayout.pagePadding(context),
      children: [
        if (expanded) _pageHeader(theme, tr(context, 'Library')),
        if (!expanded) ...[
          const SizedBox(height: 4),
          Text(tr(context, 'Library'), style: theme.textTheme.displaySmall),
          const SizedBox(height: 6),
          Text(
            tr(context, 'Everything you can study, organised in one place.'),
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
        ],
        TextField(
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search_rounded),
            hintText: tr(
              context,
              expanded ? 'Search study sets' : 'Search your study sets',
            ),
          ),
          onChanged: (value) => setState(() => _query = value),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: subjects.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final subject = subjects[i];
              return _FilterChip(
                label: tr(context, subject),
                selected: filter == subject,
                onSelected: () => setState(() => _subject = subject),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  isCantonese(context)
                      ? '${sets.length} 個題組 · $totalItems 題'
                      : '${sets.length} sets · $totalItems items',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: acatrainWeight(550),
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => setState(() => _sortMostDue = !_sortMostDue),
                icon: Icon(
                  Icons.swap_vert_rounded,
                  size: 20,
                  color:
                      _sortMostDue
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                ),
                label: Text(
                  tr(context, 'Most due'),
                  style: TextStyle(
                    color:
                        _sortMostDue
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (sets.isEmpty)
          _EmptyState(
            icon: Icons.search_off_rounded,
            title: tr(context, 'No matching study sets'),
            message: tr(context, 'Try another keyword or subject filter.'),
          )
        else
          _LibraryList(sets: sets, store: store, onOpen: _open),
      ],
    );
  }

  Widget _review(ThemeData theme, {required bool expanded}) {
    final colors = theme.colorScheme;
    final totalDue = store.totalDue;
    final totalMissed = store.totalMissed;
    final caughtUp = totalDue == 0 && totalMissed == 0;
    // The practise button covers one set (progress is kept per set), so the
    // missed cards come from the set with the most recent miss.
    final misses = store.recentMisses;
    final missedSet = misses.isEmpty ? null : misses.first.$1;
    final setMisses =
        missedSet == null
            ? const <(StudySet, StudyItem, DateTime)>[]
            : misses.where((m) => m.$1.id == missedSet.id).toList();
    final shownMisses = setMisses.take(3).toList();
    final reviewSets =
        store.bundle.sets
            .where((s) => store.dueCount(s) > 0 || store.missedCount(s) > 0)
            .toList();

    Widget sectionTitle(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 4, 12),
      child: Text(text, style: theme.textTheme.titleLarge),
    );

    return FadingListView(
      padding: AcatrainLayout.pagePadding(context),
      children: [
        if (expanded) _pageHeader(theme, tr(context, 'Review')),
        if (!expanded) ...[
          const SizedBox(height: 4),
          Text(tr(context, 'Review'), style: theme.textTheme.displaySmall),
          const SizedBox(height: 6),
        ],
        Text(
          tr(
            context,
            'Due items rise to the top. Missed answers stay easy to revisit.',
          ),
          style: theme.textTheme.bodyLarge?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        _ReviewSummary(
          due: totalDue,
          missed: totalMissed,
          doneToday: store.doneToday,
        ),
        if (caughtUp) ...[
          const SizedBox(height: 16),
          _EmptyState(
            icon: Icons.done_all_rounded,
            title: tr(context, 'You are caught up'),
            message: tr(context, 'There are no review items due right now.'),
            actionLabel: tr(context, 'Browse'),
            onAction: () {
              unawaited(Haptics.play(AcHaptic.tap));
              setState(() => _page = 1);
            },
          ),
        ],
        if (shownMisses.isNotEmpty) ...[
          sectionTitle(tr(context, 'Missed recently')),
          for (var i = 0; i < shownMisses.length; i++)
            Padding(
              padding: EdgeInsets.only(
                bottom: i == shownMisses.length - 1 ? 0 : 3,
              ),
              child: _MissedCard(
                set: shownMisses[i].$1,
                item: shownMisses[i].$2,
                missedAt: shownMisses[i].$3,
                radius: segmentRadius(
                  i,
                  shownMisses.length,
                  outer: AcatrainRadii.xl,
                  inner: 6,
                ),
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed:
                  () => _startSession(
                    missedSet!,
                    [for (final m in setMisses) m.$2],
                    false,
                  ),
              icon: const Icon(Icons.replay_rounded),
              label: Text(
                isCantonese(context)
                    ? '練習 ${setMisses.length} 題錯題'
                    : 'Practise ${setMisses.length} mistake${setMisses.length == 1 ? '' : 's'}',
              ),
            ),
          ),
        ],
        if (reviewSets.isNotEmpty) ...[
          sectionTitle(tr(context, 'Due by set')),
          for (var i = 0; i < reviewSets.length; i++)
            Padding(
              padding: EdgeInsets.only(
                bottom: i == reviewSets.length - 1 ? 0 : 3,
              ),
              child: _DueSetRow(
                set: reviewSets[i],
                due: store.dueCount(reviewSets[i]),
                missed: store.missedCount(reviewSets[i]),
                radius: segmentRadius(
                  i,
                  reviewSets.length,
                  outer: AcatrainRadii.xl,
                  inner: 6,
                ),
                onReview: () {
                  final set = reviewSets[i];
                  final due = store.dueItems(set);
                  if (due.isEmpty) {
                    _startSession(
                      set,
                      set.items.where((it) => store.isWrong(set, it)).toList(),
                      false,
                    );
                  } else {
                    _startSession(set, due, false);
                  }
                },
              ),
            ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _settings(ThemeData theme, {required bool expanded}) => FadingListView(
    padding: AcatrainLayout.pagePadding(context),
    children: [
      if (expanded) _pageHeader(theme, tr(context, 'Your learning space')),
      if (!expanded) ...[
        const SizedBox(height: 4),
        Text(
          tr(context, 'Your learning space'),
          style: theme.textTheme.displaySmall,
        ),
        const SizedBox(height: 22),
      ],
      LayoutBuilder(
        builder: (context, constraints) {
          final twoColumns = constraints.maxWidth >= 760;
          final cardWidth =
              twoColumns
                  ? (constraints.maxWidth - 14) / 2
                  : constraints.maxWidth;
          return Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              SizedBox(
                width: cardWidth,
                child: _SettingsCard(
                  icon:
                      store.uid == null
                          ? Icons.person_outline_rounded
                          : Icons.verified_user_outlined,
                  title: tr(context, 'Account & progress'),
                  body:
                      store.email ??
                      tr(context, 'Guest mode. No account needed to study.'),
                  footer: tr(
                    context,
                    'Guest and account progress stay separate. Acatrain never uploads guest progress automatically.',
                  ),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.icon(
                        onPressed:
                            store.busy
                                ? null
                                : store.uid == null
                                ? _login
                                : _syncProgressByUser,
                        icon: Icon(
                          store.uid == null
                              ? Icons.login_rounded
                              : Icons.cloud_sync_outlined,
                        ),
                        label: Text(
                          tr(
                            context,
                            store.uid == null
                                ? 'Sign in or create account'
                                : 'Sync progress',
                          ),
                        ),
                      ),
                      if (store.uid != null)
                        OutlinedButton(
                          onPressed: store.busy ? null : _personalInfo,
                          child: Text(tr(context, 'Personal info')),
                        ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: cardWidth,
                child: _SettingsCard(
                  icon: Icons.palette_outlined,
                  title: tr(context, 'Appearance'),
                  body: tr(
                    context,
                    'Choose how Acatrain looks on this device.',
                  ),
                  footer: tr(context, 'System follows your device setting.'),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final (value, label) in [
                        ('system', 'System'),
                        ('light', 'Light'),
                        ('dark', 'Dark'),
                      ])
                        ChoiceChip(
                          label: Text(tr(context, label)),
                          selected: store.appearance == value,
                          onSelected: (_) => store.setAppearance(value),
                        ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: cardWidth,
                child: _SettingsCard(
                  icon: Icons.vibration_rounded,
                  title: tr(context, 'Haptics'),
                  body: tr(context, 'Short, tuned vibrations for each action.'),
                  footer: tr(
                    context,
                    'Acatrain stays silent when system haptics are off.',
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AcatrainSegmentedButton<int>(
                        label: tr(context, 'Haptic strength'),
                        segments: [
                          (0, tr(context, 'Off')),
                          (1, tr(context, 'Subtle')),
                          (2, tr(context, 'Standard')),
                        ],
                        selected: store.hapticLevel,
                        onChanged: _setHapticLevel,
                      ),
                      const SizedBox(height: 12),
                      FilledButton.tonalIcon(
                        onPressed:
                            store.hapticLevel == 0
                                ? null
                                : () => Haptics.play(AcHaptic.confirm),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 48),
                        ),
                        icon: const Icon(Icons.touch_app_outlined),
                        label: Text(tr(context, 'Try it')),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: cardWidth,
                child: _SettingsCard(
                  icon: Icons.animation_rounded,
                  title: tr(context, 'Motion'),
                  body: tr(
                    context,
                    'Reduced motion removes springs and loops.',
                  ),
                  footer: tr(
                    context,
                    'Match system follows your device setting.',
                  ),
                  child: AcatrainSegmentedButton<String>(
                    label: tr(context, 'Motion'),
                    segments: [
                      ('system', tr(context, 'Match system')),
                      ('reduced', tr(context, 'Reduced')),
                    ],
                    selected: store.motion,
                    onChanged: (value) {
                      unawaited(
                        Haptics.play(
                          value == 'reduced'
                              ? AcHaptic.toggleOn
                              : AcHaptic.toggleOff,
                        ),
                      );
                      unawaited(store.setMotion(value));
                    },
                  ),
                ),
              ),
              SizedBox(
                width: cardWidth,
                child: _SettingsCard(
                  icon: Icons.workspace_premium_outlined,
                  title: tr(context, 'Subscription'),
                  body:
                      isCantonese(context)
                          ? '目前方案：${AcatrainPlan.fromId(store.plan).label}（${tr(context, AcatrainPlan.fromId(store.plan).themeName)}）'
                          : 'Current plan: ${AcatrainPlan.fromId(store.plan).label} (${AcatrainPlan.fromId(store.plan).themeName})',
                  footer: tr(
                    context,
                    'Demo checkout. You will never be charged.',
                  ),
                  child: FilledButton.tonalIcon(
                    onPressed:
                        () => Navigator.of(context).push(
                          AcatrainPageRoute<void>(
                            builder: (_) => SubscriptionPage(store: store),
                          ),
                        ),
                    icon: const Icon(Icons.auto_awesome_rounded),
                    label: Text(tr(context, 'View plans')),
                  ),
                ),
              ),
              SizedBox(
                width: cardWidth,
                child: _SettingsCard(
                  icon: Icons.language_rounded,
                  title: tr(context, 'Language'),
                  body: tr(context, 'Choose the display language.'),
                  footer: tr(
                    context,
                    'Study content keeps its original language.',
                  ),
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: store.languageCode,
                    items: [
                      DropdownMenuItem(
                        value: 'en',
                        child: Text(tr(context, 'English')),
                      ),
                      DropdownMenuItem(
                        value: 'zh_HK',
                        child: Text(tr(context, 'Cantonese (繁體中文)')),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) store.setLanguageCode(value);
                    },
                  ),
                ),
              ),
              SizedBox(
                width: cardWidth,
                child: _StudyContentCard(store: store),
              ),
            ],
          );
        },
      ),
      const SizedBox(height: 20),
      Text(
        tr(context, store.status),
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 18),
      Text('Acatrain 0.1.0 · Build 1', style: theme.textTheme.bodySmall),
    ],
  );

  Future<void> _personalInfo() async {
    if (store.uid == null) {
      await _login();
      return;
    }
    final controller = TextEditingController(text: store.displayName ?? '');
    await showDialog<void>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(tr(dialogContext, 'Personal info')),
            content: SizedBox(
              width: 380,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: controller,
                    maxLength: 80,
                    decoration: InputDecoration(
                      labelText: tr(dialogContext, 'Name'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('${tr(dialogContext, 'Email')}: ${store.email ?? ''}'),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed:
                        store.busy
                            ? null
                            : () async {
                              final ok = await store.signInWithGoogle();
                              if (dialogContext.mounted) {
                                ScaffoldMessenger.of(
                                  dialogContext,
                                ).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      tr(dialogContext, store.status),
                                    ),
                                  ),
                                );
                                if (ok) Navigator.pop(dialogContext);
                              }
                            },
                    icon: const Icon(Icons.account_circle_outlined),
                    label: Text(tr(dialogContext, 'Connect Google')),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(
                  MaterialLocalizations.of(dialogContext).cancelButtonLabel,
                ),
              ),
              FilledButton(
                onPressed: () async {
                  final ok = await store.updateDisplayName(controller.text);
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(content: Text(tr(dialogContext, store.status))),
                    );
                    if (ok) Navigator.pop(dialogContext);
                  }
                },
                child: Text(tr(dialogContext, 'Save')),
              ),
            ],
          ),
    );
    controller.dispose();
  }

  Future<void> _login() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (_) => _AuthSheet(store: store),
    );
  }
}

/// The compact expressive nav rail (96 wide): cookie9 logo, then destinations
/// with the same pill indicator as the bottom nav bar.
class _ExpressiveRail extends StatelessWidget {
  const _ExpressiveRail({
    required this.selectedIndex,
    required this.onSelected,
    required this.labels,
    required this.icons,
    required this.selectedIcons,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<String> labels;
  final List<IconData> icons;
  final List<IconData> selectedIcons;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 96,
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          ExpressiveBadge(
            shape: ExpressiveShape.cookie9,
            size: 44,
            color: theme.colorScheme.primary,
            child: Icon(
              Icons.school_rounded,
              size: 22,
              color: theme.colorScheme.onPrimary,
            ),
          ),
          const SizedBox(height: 28),
          for (var i = 0; i < labels.length; i++)
            _RailDestination(
              selected: selectedIndex == i,
              icon: selectedIndex == i ? selectedIcons[i] : icons[i],
              label: labels[i],
              onTap: () => onSelected(i),
            ),
        ],
      ),
    );
  }
}

class _RailDestination extends StatelessWidget {
  const _RailDestination({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AcatrainRadii.l),
          child: SizedBox(
            width: 80,
            child: Column(
              children: [
                AnimatedContainer(
                  duration: AcatrainSprings.durationOf(
                    context,
                    AcatrainSprings.effectsDefault,
                  ),
                  curve: AcatrainSprings.effectsDefaultCurve,
                  width: 56,
                  height: 32,
                  decoration: BoxDecoration(
                    color:
                        selected
                            ? theme.colorScheme.secondaryContainer
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(AcatrainRadii.l),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    icon,
                    color:
                        selected
                            ? theme.colorScheme.onSecondaryContainer
                            : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight:
                        selected ? FontWeight.w700 : acatrainWeight(550),
                    color:
                        selected
                            ? theme.colorScheme.onSurface
                            : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TodayHero extends StatelessWidget {
  const _TodayHero({
    required this.store,
    required this.compact,
    required this.onOpen,
    required this.onStart,
    required this.onPracticeTest,
  });

  final AppStore store;
  final bool compact;
  final ValueChanged<StudySet> onOpen;
  final void Function(StudySet set, List<StudyItem> items) onStart;
  final void Function(StudySet set, List<StudyItem> items) onPracticeTest;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tones = theme.extension<AcatrainTones>() ?? AcatrainTones.light;
    final totalDue = store.totalDue;
    final set =
        store.bundle.sets.isEmpty
            ? null
            : store.bundle.sets.firstWhere(
              (s) => store.dueCount(s) > 0,
              orElse: () => store.bundle.sets.first,
            );
    final quizzes =
        set == null
            ? const <StudyItem>[]
            : set.items.where((i) => i.isQuiz).toList();
    final caughtUp = totalDue == 0;

    final headline =
        isCantonese(context)
            ? (caughtUp ? '全部都溫習好喇' : '$totalDue 題等你溫習')
            : (caughtUp
                ? "You're caught up"
                : '$totalDue items ready to review');
    final counterText = caughtUp ? '0' : '$totalDue';

    void handleStart() {
      if (set == null) return;
      if (caughtUp) {
        onOpen(set);
        return;
      }
      final due = store.dueItems(set);
      onStart(set, due.isNotEmpty ? due : set.items);
    }

    final badgeSize = compact ? 104.0 : 184.0;
    final counter = ExpressiveBadge(
      shape: ExpressiveShape.cookie9,
      size: badgeSize,
      color: theme.colorScheme.primary,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            counterText,
            style: TextStyle(
              fontFamily: _fontFamily,
              fontFamilyFallback: _fontFallback,
              fontSize: compact ? 40 : 64,
              height: 1,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.5,
              color: theme.colorScheme.onPrimary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (!compact) ...[
            const SizedBox(height: 4),
            Text(
              tr(context, 'due today'),
              style: theme.textTheme.labelLarge?.copyWith(
                color: tones.heroAccent,
                fontWeight: acatrainWeight(650),
              ),
            ),
          ],
        ],
      ),
    );

    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "TODAY'S REVIEW",
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          headline,
          style: (compact
                  ? theme.textTheme.headlineMedium
                  : theme.textTheme.headlineLarge)
              ?.copyWith(
                fontSize: compact ? null : 40,
                height: compact ? null : 46 / 40,
                letterSpacing: compact ? null : -1.2,
                color: theme.colorScheme.onPrimaryContainer,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          tr(context, 'Start with recall, then check what really stuck.'),
          style: (compact
                  ? theme.textTheme.bodyMedium
                  : theme.textTheme.bodyLarge)
              ?.copyWith(
                fontSize: compact ? 15 : 17,
                height: compact ? 22 / 15 : 26 / 17,
                color: tones.heroBody,
              ),
        ),
      ],
    );

    final startButton = FilledButton.icon(
      onPressed: set == null ? null : handleStart,
      style: FilledButton.styleFrom(
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
      ),
      icon: const Icon(Icons.play_arrow_rounded),
      label: Text(tr(context, 'Start learning')),
    );

    final buttons =
        compact
            ? Row(
              children: [
                Expanded(child: startButton),
                if (quizzes.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Tooltip(
                    message: tr(context, 'Start a practice test'),
                    child: SizedBox(
                      width: 56,
                      height: 56,
                      child: FilledButton(
                        onPressed: () => onPracticeTest(set!, quizzes),
                        style: FilledButton.styleFrom(
                          backgroundColor: tones.heroAccent,
                          foregroundColor: theme.colorScheme.onPrimaryContainer,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AcatrainRadii.l,
                            ),
                          ),
                          padding: EdgeInsets.zero,
                        ),
                        child: const Icon(Icons.quiz_rounded),
                      ),
                    ),
                  ),
                ],
              ],
            )
            : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                startButton,
                if (quizzes.isNotEmpty)
                  FilledButton.icon(
                    onPressed: () => onPracticeTest(set!, quizzes),
                    style: FilledButton.styleFrom(
                      backgroundColor: tones.heroAccent,
                      foregroundColor: theme.colorScheme.onPrimaryContainer,
                    ),
                    icon: const Icon(Icons.quiz_rounded),
                    label: Text(tr(context, 'Practice test')),
                  ),
              ],
            );

    final radius = compact ? AcatrainRadii.xlPlus : 36.0;
    if (compact) {
      return Semantics(
        container: true,
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(radius),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: copy),
                  const SizedBox(width: 16),
                  counter,
                ],
              ),
              const SizedBox(height: 18),
              buttons,
            ],
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 32),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [copy, const SizedBox(height: 14), buttons],
            ),
          ),
          const SizedBox(width: 32),
          counter,
        ],
      ),
    );
  }
}

class _MetricStrip extends StatelessWidget {
  const _MetricStrip({required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tiles = [
      (
        ExpressiveShape.sunny,
        theme.colorScheme.secondaryContainer,
        theme.colorScheme.onSecondaryContainer,
        Icons.collections_bookmark_rounded,
        '${store.bundle.sets.length}',
        tr(context, 'study sets'),
      ),
      (
        ExpressiveShape.clover4,
        theme.colorScheme.tertiaryContainer,
        theme.colorScheme.onTertiaryContainer,
        Icons.workspace_premium_rounded,
        '${store.mastered}',
        tr(context, 'well-practised'),
      ),
      (
        ExpressiveShape.flower6,
        theme.colorScheme.primaryContainer,
        theme.colorScheme.onPrimaryContainer,
        Icons.offline_pin_rounded,
        tr(context, 'Ready'),
        tr(context, 'for offline'),
      ),
    ];
    return Row(
      children: [
        for (var i = 0; i < tiles.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: _MetricTile(
              shape: tiles[i].$1,
              container: tiles[i].$2,
              onContainer: tiles[i].$3,
              icon: tiles[i].$4,
              value: tiles[i].$5,
              label: tiles[i].$6,
            ),
          ),
        ],
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.shape,
    required this.container,
    required this.onContainer,
    required this.icon,
    required this.value,
    required this.label,
  });

  final ExpressiveShape shape;
  final Color container;
  final Color onContainer;
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AcatrainRadii.lPlus),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExpressiveBadge(
            shape: shape,
            size: 32,
            color: container,
            child: Icon(icon, size: 18, color: onContainer),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontSize: 22,
              height: 26 / 22,
              fontWeight: acatrainWeight(750),
              letterSpacing: -0.4,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _TodaySetList extends StatelessWidget {
  const _TodaySetList({
    required this.sets,
    required this.store,
    required this.onOpen,
  });
  final List<StudySet> sets;
  final AppStore store;
  final ValueChanged<StudySet> onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < sets.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == sets.length - 1 ? 0 : 3),
            child: _TodaySetRow(
              set: sets[i],
              store: store,
              radius: segmentRadius(
                i,
                sets.length,
                outer: AcatrainRadii.xl,
                inner: 6,
              ),
              onTap: () => onOpen(sets[i]),
            ),
          ),
      ],
    );
  }
}

class _TodaySetRow extends StatelessWidget {
  const _TodaySetRow({
    required this.set,
    required this.store,
    required this.radius,
    required this.onTap,
  });

  final StudySet set;
  final AppStore store;
  final BorderRadius radius;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = SubjectStyle.of(context, set.subject);
    final due = store.dueCount(set);
    final progress = store.completion(set);
    return AcatrainPressScale(
      child: StudySetHero(
        setId: set.id,
        child: Material(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
              child: Row(
                children: [
                  ExpressiveBadge(
                    shape: style.shape,
                    size: 52,
                    color: style.container,
                    child: Icon(style.icon, color: style.onContainer, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          set.subject,
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: acatrainWeight(650),
                            letterSpacing: 0.3,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          set.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            AcatrainFlatBar(value: progress, color: style.fill),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text.rich(
                                TextSpan(
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  children: [
                                    TextSpan(
                                      text:
                                          isCantonese(context)
                                              ? '${set.items.length} 題 · '
                                              : '${set.items.length} items · ',
                                    ),
                                    TextSpan(
                                      text:
                                          isCantonese(context)
                                              ? '$due 題待溫習'
                                              : '$due due',
                                      style: TextStyle(
                                        fontWeight: acatrainWeight(650),
                                        color: theme.colorScheme.onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DesktopSetGrid extends StatelessWidget {
  const _DesktopSetGrid({
    required this.sets,
    required this.store,
    required this.onOpen,
    required this.columns,
  });

  final List<StudySet> sets;
  final AppStore store;
  final ValueChanged<StudySet> onOpen;
  final int columns;

  @override
  Widget build(BuildContext context) => GridView.builder(
    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: columns,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      mainAxisExtent: 212,
    ),
    itemCount: sets.length,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    itemBuilder: (context, index) {
      final set = sets[index];
      final theme = Theme.of(context);
      final style = SubjectStyle.of(context, set.subject);
      final due = store.dueCount(set);
      final progress = store.completion(set);
      return AcatrainPressScale(
        child: StudySetHero(
          setId: set.id,
          child: Material(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AcatrainRadii.xl),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => onOpen(set),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ExpressiveBadge(
                          shape: style.shape,
                          size: 48,
                          color: style.fill,
                          child: Icon(
                            style.icon,
                            color: style.onFill,
                            size: 24,
                          ),
                        ),
                        const Spacer(),
                        _DuePill(
                          count: due,
                          container: style.container,
                          onContainer: style.onContainer,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            set.subject,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: acatrainWeight(650),
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            set.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleLarge,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    WavyProgress(value: progress, color: style.fill, height: 8),
                    const SizedBox(height: 6),
                    Text(
                      isCantonese(context)
                          ? '${store.practisedCount(set)} / ${set.items.length} 題已熟習'
                          : '${store.practisedCount(set)} of ${set.items.length} well-practised',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _DuePill extends StatelessWidget {
  const _DuePill({
    required this.count,
    required this.container,
    required this.onContainer,
  });
  final int count;
  final Color container;
  final Color onContainer;

  @override
  Widget build(BuildContext context) => Container(
    height: 28,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
      color: container,
      borderRadius: BorderRadius.circular(AcatrainRadii.l),
    ),
    alignment: Alignment.center,
    child: Text(
      isCantonese(context) ? '$count 題待溫習' : '$count due',
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: onContainer,
      ),
    ),
  );
}

class _ReviewQueuePanel extends StatelessWidget {
  const _ReviewQueuePanel({
    required this.store,
    required this.onOpenSet,
    required this.onStart,
  });
  final AppStore store;
  final ValueChanged<StudySet> onOpenSet;
  final void Function(StudySet, List<StudyItem>, bool) onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = <(StudySet, StudyItem, bool)>[];
    for (final set in store.bundle.sets) {
      for (final item in store.dueItems(set)) {
        entries.add((set, item, store.isWrong(set, item)));
      }
    }
    entries.sort((a, b) => (a.$3 == b.$3) ? 0 : (a.$3 ? -1 : 1));
    final shown = entries.take(4).toList();

    StudySet? worstSet;
    var worstMisses = 0;
    for (final set in store.bundle.sets) {
      final misses = set.items.where((i) => store.isWrong(set, i)).length;
      if (misses > worstMisses) {
        worstMisses = misses;
        worstSet = set;
      }
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AcatrainRadii.xlPlus),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    tr(context, 'Review queue'),
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                Text(
                  isCantonese(context)
                      ? '${store.totalDue} 題待溫習'
                      : '${store.totalDue} due',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (shown.isEmpty)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                tr(context, 'Nothing due right now.'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            Column(
              children: [
                for (var i = 0; i < shown.length; i++)
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: i == shown.length - 1 ? 0 : 2,
                    ),
                    child: _ReviewQueueRow(
                      set: shown[i].$1,
                      item: shown[i].$2,
                      missed: shown[i].$3,
                      radius: segmentRadius(
                        i,
                        shown.length,
                        outer: AcatrainRadii.lPlus,
                        inner: AcatrainRadii.xs,
                      ),
                      onTap: () => onOpenSet(shown[i].$1),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 16),
          FilledButton.tonal(
            onPressed:
                worstSet == null
                    ? null
                    : () {
                      final set = worstSet!;
                      onStart(
                        set,
                        set.items.where((i) => store.isWrong(set, i)).toList(),
                        false,
                      );
                    },
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.secondaryContainer,
              foregroundColor: theme.colorScheme.onSecondaryContainer,
              minimumSize: const Size(0, 48),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.replay_rounded, size: 20),
                const SizedBox(width: 8),
                Text(tr(context, 'Practise mistakes')),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ReviewStat(
                  value: '${store.mastered}',
                  label: tr(context, 'well-practised'),
                  leading: true,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _ReviewStat(
                  value: '${store.totalItems}',
                  label: tr(context, 'items offline'),
                  leading: false,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReviewQueueRow extends StatelessWidget {
  const _ReviewQueueRow({
    required this.set,
    required this.item,
    required this.missed,
    required this.radius,
    required this.onTap,
  });

  final StudySet set;
  final StudyItem item;
  final bool missed;
  final BorderRadius radius;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = SubjectStyle.of(context, set.subject);
    return Material(
      color: theme.colorScheme.surfaceContainerLowest,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              ExpressiveBadge(
                shape: style.shape,
                size: 36,
                color: style.container,
                child: Icon(style.icon, size: 18, color: style.onContainer),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.prompt,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    Text(
                      tr(context, missed ? 'Missed' : 'Due now'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: acatrainWeight(550),
                        color:
                            missed
                                ? theme.colorScheme.error
                                : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewStat extends StatelessWidget {
  const _ReviewStat({
    required this.value,
    required this.label,
    required this.leading,
  });
  final String value;
  final String label;
  final bool leading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AcatrainRadii.lPlus),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontSize: 26,
              fontWeight: acatrainWeight(750),
            ),
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) => AcatrainPressScale(
    pressedScale: 0.95,
    child: AnimatedSize(
      duration: AcatrainSprings.durationOf(
        context,
        AcatrainSprings.spatialFast,
      ),
      curve: AcatrainSprings.spatialFastCurve,
      child: _chip(context),
    ),
  );

  Widget _chip(BuildContext context) {
    final theme = Theme.of(context);
    if (selected) {
      return Material(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(AcatrainRadii.full),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onSelected,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 16, 0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_rounded,
                  size: 18,
                  color: theme.colorScheme.onSecondaryContainer,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AcatrainRadii.m),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onSelected,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AcatrainRadii.m),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _LibraryList extends StatelessWidget {
  const _LibraryList({
    required this.sets,
    required this.store,
    required this.onOpen,
  });
  final List<StudySet> sets;
  final AppStore store;
  final ValueChanged<StudySet> onOpen;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns =
          constraints.maxWidth >= 1000
              ? 3
              : constraints.maxWidth >= 660
              ? 2
              : 1;
      if (columns == 1) {
        return Column(
          children: [
            for (var i = 0; i < sets.length; i++)
              Padding(
                padding: EdgeInsets.only(bottom: i == sets.length - 1 ? 0 : 10),
                child: _LibraryCard(
                  set: sets[i],
                  store: store,
                  onTap: () => onOpen(sets[i]),
                ),
              ),
          ],
        );
      }
      return GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          mainAxisExtent: 252,
        ),
        itemCount: sets.length,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemBuilder:
            (context, i) => _LibraryCard(
              set: sets[i],
              store: store,
              grid: true,
              onTap: () => onOpen(sets[i]),
            ),
      );
    },
  );
}

class _LibraryCard extends StatelessWidget {
  const _LibraryCard({
    required this.set,
    required this.store,
    required this.onTap,
    this.grid = false,
  });
  final StudySet set;
  final AppStore store;
  final VoidCallback onTap;
  final bool grid;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = SubjectStyle.of(context, set.subject);
    final due = store.dueCount(set);
    final practised = store.practisedCount(set);
    final progress = set.items.isEmpty ? 0.0 : practised / set.items.length;
    return AcatrainPressScale(
      child: StudySetHero(
        setId: set.id,
        child: Material(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AcatrainRadii.xl),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ExpressiveBadge(
                        shape: style.shape,
                        size: 44,
                        color: style.fill,
                        child: Icon(style.icon, color: style.onFill, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          set.subject,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: acatrainWeight(650),
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      _DuePill(
                        count: due,
                        container: style.container,
                        onContainer: style.onContainer,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    set.title,
                    maxLines: grid ? 2 : null,
                    overflow: grid ? TextOverflow.ellipsis : null,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontSize: 22,
                      height: 28 / 22,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    set.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: WavyProgress(
                          value: progress,
                          color: style.fill,
                          height: 8,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        isCantonese(context)
                            ? '$practised/${set.items.length} 題已練習'
                            : '$practised/${set.items.length} practised',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: acatrainWeight(550),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.child,
    required this.footer,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget child;
  final String footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: EdgeInsets.all(AcatrainLayout.isCompact(context) ? 20 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExpressiveBadge(
                  shape: ExpressiveShape.sunny,
                  size: 40,
                  color: theme.colorScheme.secondaryContainer,
                  child: Icon(
                    icon,
                    color: theme.colorScheme.onSecondaryContainer,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleLarge),
                      const SizedBox(height: 4),
                      Text(
                        body,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            child,
            const SizedBox(height: 14),
            Text(
              footer,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AcatrainRadii.xl),
      ),
      child: Column(
        children: [
          ExpressiveBadge(
            shape: ExpressiveShape.sunny,
            size: 56,
            color: theme.colorScheme.secondaryContainer,
            child: Icon(
              icon,
              color: theme.colorScheme.onSecondaryContainer,
              size: 28,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: 20),
            FilledButton.tonal(
              onPressed: onAction,
              style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

/// Due now, missed and done today, as a connected three-part strip.
class _ReviewSummary extends StatelessWidget {
  const _ReviewSummary({
    required this.due,
    required this.missed,
    required this.doneToday,
  });

  final int due;
  final int missed;
  final int doneToday;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final stats = [
      ('$due', tr(context, 'due now'), colors.onSurface),
      ('$missed', tr(context, 'missed'), missed > 0 ? colors.error : colors.onSurface),
      ('$doneToday', tr(context, 'done today'), colors.onSurface),
    ];
    return Semantics(
      liveRegion: true,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, stat) in stats.indexed)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: i == 0 ? 0 : 1.5,
                    right: i == stats.length - 1 ? 0 : 1.5,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerLow,
                      borderRadius: _rowSegmentRadius(i, stats.length),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stat.$1,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontSize: 24,
                            fontWeight: acatrainWeight(750),
                            color: stat.$3,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        Text(
                          stat.$2,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// [segmentRadius] turned sideways, for a horizontal connected group.
BorderRadius _rowSegmentRadius(int index, int count) {
  const outer = Radius.circular(AcatrainRadii.lPlus);
  const inner = Radius.circular(6);
  if (count <= 1) return const BorderRadius.all(outer);
  return BorderRadius.horizontal(
    left: index == 0 ? outer : inner,
    right: index == count - 1 ? outer : inner,
  );
}

class _MissedCard extends StatelessWidget {
  const _MissedCard({
    required this.set,
    required this.item,
    required this.missedAt,
    required this.radius,
  });

  final StudySet set;
  final StudyItem item;
  final DateTime missedAt;
  final BorderRadius radius;

  String _when(BuildContext context) {
    final now = DateTime.now();
    final days =
        DateTime(now.year, now.month, now.day)
            .difference(DateTime(missedAt.year, missedAt.month, missedAt.day))
            .inDays;
    if (isCantonese(context)) {
      return days <= 0
          ? '今日答錯'
          : days == 1
          ? '尋日答錯'
          : '$days 日前答錯';
    }
    return days <= 0
        ? 'missed today'
        : days == 1
        ? 'missed yesterday'
        : 'missed $days days ago';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: radius,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colors.errorContainer,
              borderRadius: BorderRadius.circular(AcatrainRadii.m),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.undo_rounded,
              size: 22,
              color: colors.onErrorContainer,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.prompt, style: theme.textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  '${set.subject} · ${_when(context)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
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

class _DueSetRow extends StatelessWidget {
  const _DueSetRow({
    required this.set,
    required this.due,
    required this.missed,
    required this.radius,
    required this.onReview,
  });

  final StudySet set;
  final int due;
  final int missed;
  final BorderRadius radius;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final style = SubjectStyle.of(context, set.subject);
    final caption = theme.textTheme.bodySmall?.copyWith(
      color: colors.onSurfaceVariant,
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: radius,
      ),
      child: Row(
        children: [
          ExpressiveBadge(
            shape: style.shape,
            size: 44,
            color: style.container,
            child: Icon(style.icon, color: style.onContainer, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  set.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text.rich(
                  TextSpan(
                    style: caption,
                    children: [
                      TextSpan(
                        text: isCantonese(context) ? '$due 題待溫習' : '$due due',
                      ),
                      if (missed > 0) ...[
                        const TextSpan(text: ' · '),
                        TextSpan(
                          text:
                              isCantonese(context)
                                  ? '$missed 題錯題'
                                  : '$missed missed',
                          style: TextStyle(color: colors.error),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.tonal(
            onPressed: onReview,
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              // Keeps a 48dp touch target around the 40dp pill.
              tapTargetSize: MaterialTapTargetSize.padded,
              textStyle: theme.textTheme.labelLarge,
            ),
            child: Text(tr(context, 'Review')),
          ),
        ],
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        color: theme.colorScheme.surfaceContainerHighest,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                tr(context, 'Offline. Studying from saved content.'),
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _CheckPhase { idle, busy, done, failed }

/// The study content row in Settings: an icon button starts a check, the
/// expressive loading indicator shows only if it takes over 400 ms, and the
/// outcome turns into a check (with `done`) or an error card (with `error`).
class _StudyContentCard extends StatefulWidget {
  const _StudyContentCard({required this.store});
  final AppStore store;

  @override
  State<_StudyContentCard> createState() => _StudyContentCardState();
}

class _StudyContentCardState extends State<_StudyContentCard> {
  var _phase = _CheckPhase.idle;
  var _showLoader = false;
  Timer? _loaderTimer;
  Timer? _resetTimer;

  AppStore get store => widget.store;

  @override
  void dispose() {
    _loaderTimer?.cancel();
    _resetTimer?.cancel();
    super.dispose();
  }

  Future<void> _check() async {
    if (_phase == _CheckPhase.busy || store.busy) return;
    unawaited(Haptics.play(AcHaptic.tap));
    _resetTimer?.cancel();
    setState(() {
      _phase = _CheckPhase.busy;
      _showLoader = false;
    });
    _loaderTimer = Timer(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _showLoader = true);
    });
    final ok = await store.syncContent();
    _loaderTimer?.cancel();
    if (!mounted) return;
    setState(() => _phase = ok ? _CheckPhase.done : _CheckPhase.failed);
    unawaited(Haptics.play(ok ? AcHaptic.done : AcHaptic.error));
    if (ok) {
      _resetTimer = Timer(const Duration(milliseconds: 2600), () {
        if (mounted) setState(() => _phase = _CheckPhase.idle);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final label = switch (_phase) {
      _CheckPhase.busy => tr(context, 'Checking for updates…'),
      _CheckPhase.done => tr(context, 'Up to date · checked just now'),
      _ =>
        store.cloudConfigured
            ? (isCantonese(context)
                ? '版本 ${store.releaseId}'
                : 'Release ${store.releaseId}')
            : tr(context, 'Bundled demo · works offline'),
    };

    final Widget trailing = switch (_phase) {
      _CheckPhase.busy =>
        _showLoader
            ? const AcatrainLoadingIndicator(
              key: ValueKey('loading'),
              size: 40,
              semanticsLabel: 'Checking for updates',
            )
            : const SizedBox(key: ValueKey('waiting'), width: 48, height: 48),
      _CheckPhase.done => AcatrainSpringIn(
        key: const ValueKey('done'),
        disabled: reduceMotion,
        spring: AcatrainSprings.spatialFast,
        builder:
            (context, t) => Transform.rotate(
              angle: -60 * (1 - t) * 3.141592653589793 / 180,
              child: Transform.scale(
                scale: 0.3 + 0.7 * t,
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: colors.primary,
                    semanticLabel: tr(context, 'Up to date'),
                  ),
                ),
              ),
            ),
      ),
      _ => IconButton(
        key: const ValueKey('sync'),
        tooltip: tr(context, 'Check for content updates'),
        onPressed: store.busy ? null : _check,
        icon: const Icon(Icons.sync_rounded),
      ),
    };

    return _SettingsCard(
      icon: Icons.cloud_sync_outlined,
      title: tr(context, 'Study content'),
      body: tr(
        context,
        store.cloudConfigured
            ? 'Connected to your published content service.'
            : 'Bundled demo. Cloud service is not configured.',
      ),
      footer: tr(context, 'Study content keeps working offline.'),
      child: AnimatedSize(
        duration: AcatrainSprings.durationOf(
          context,
          AcatrainSprings.spatialDefault,
        ),
        curve: AcatrainSprings.spatialDefaultCurve,
        alignment: Alignment.topCenter,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    liveRegion: true,
                    child: Text(label, style: theme.textTheme.bodyLarge),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 48,
                  height: 48,
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: AcatrainSprings.durationOf(
                        context,
                        AcatrainSprings.effectsDefault,
                      ),
                      child: trailing,
                    ),
                  ),
                ),
              ],
            ),
            if (_phase == _CheckPhase.failed) ...[
              const SizedBox(height: 12),
              AcatrainSpringIn(
                disabled: reduceMotion,
                spring: AcatrainSprings.spatialDefault,
                builder:
                    (context, t) => Opacity(
                      opacity: t.clamp(0.0, 1.0),
                      child: Transform.translate(
                        offset: Offset(0, 12 * (1 - t)),
                        child: _ErrorCard(
                          message: tr(context, 'Could not check for updates.'),
                          detail: tr(context, store.status),
                          onRetry: _check,
                        ),
                      ),
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({
    required this.message,
    required this.onRetry,
    this.detail,
  });

  final String message;
  final String? detail;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        decoration: BoxDecoration(
          color: colors.errorContainer,
          borderRadius: BorderRadius.circular(AcatrainRadii.l),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline_rounded, color: colors.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: colors.onErrorContainer,
                    ),
                  ),
                  if (detail != null)
                    Text(
                      detail!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onErrorContainer,
                      ),
                    ),
                ],
              ),
            ),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: colors.onErrorContainer,
                minimumSize: const Size(0, 48),
              ),
              child: Text(tr(context, 'Try again')),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthSheet extends StatefulWidget {
  const _AuthSheet({required this.store});
  final AppStore store;

  @override
  State<_AuthSheet> createState() => _AuthSheetState();
}

class _AuthSheetState extends State<_AuthSheet> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _emailLink = TextEditingController();
  bool _creating = false;
  bool _submitting = false;
  bool _passwordless = false;
  bool _linkSent = false;
  String? _error;
  String? _notice;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _emailLink.dispose();
    super.dispose();
  }

  Future<void> _run(
    Future<bool> Function() action, {
    bool close = false,
  }) async {
    setState(() {
      _submitting = true;
      _error = null;
      _notice = null;
    });
    final ok = await action();
    if (!ok) unawaited(Haptics.play(AcHaptic.error));
    if (!mounted) return;
    if (ok && close) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _submitting = false;
      if (ok) {
        _notice = widget.store.status;
      } else {
        _error = widget.store.status;
        if (_error!.contains('password account') ||
            _error!.contains('with its password')) {
          _creating = false;
          _passwordless = false;
          if (_email.text.isEmpty && widget.store.pendingGoogleEmail != null) {
            _email.text = widget.store.pendingGoogleEmail!;
          }
        }
      }
    });
  }

  Future<void> _submitPassword() => _run(
    () => widget.store.signIn(_email.text, _password.text, register: _creating),
    close: true,
  );

  Future<void> _sendLink() => _run(() async {
    final ok = await widget.store.sendEmailSignInLink(_email.text);
    if (ok && mounted) setState(() => _linkSent = true);
    return ok;
  });

  Future<void> _finishLink() => _run(
    () => widget.store.signInWithEmailLink(_email.text, _emailLink.text),
    close: true,
  );

  Future<void> _resetPassword() =>
      _run(() => widget.store.sendPasswordReset(_email.text));

  Future<void> _signInGoogle() =>
      _run(widget.store.signInWithGoogle, close: true);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, 6, 24, 24 + bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            tr(
              context,
              _passwordless
                  ? 'Sign in without a password'
                  : _creating
                  ? 'Create your account'
                  : 'Welcome back',
            ),
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            tr(
              context,
              _passwordless
                  ? 'We can send a one-time Firebase email link. On desktop/mobile you can paste the full link back here.'
                  : 'Your cloud account only exists to sync learning progress across devices.',
            ),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 22),
          OutlinedButton.icon(
            onPressed: _submitting ? null : _signInGoogle,
            icon: const Icon(Icons.account_circle_outlined),
            label: Text(tr(context, 'Continue with Google')),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(tr(context, 'or use email')),
              ),
              const Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _email,
            enabled: !_submitting,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: InputDecoration(
              labelText: tr(context, 'Email'),
              prefixIcon: const Icon(Icons.mail_outline_rounded),
            ),
          ),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: AcatrainSprings.durationOf(
              context,
              AcatrainSprings.effectsDefault,
            ),
            switchInCurve: AcatrainSprings.effectsDefaultCurve,
            switchOutCurve: AcatrainSprings.effectsDefaultCurve,
            child:
                _passwordless
                    ? Column(
                      key: const ValueKey('link-auth'),
                      children: [
                        if (_linkSent) ...[
                          TextField(
                            controller: _emailLink,
                            enabled: !_submitting,
                            decoration: InputDecoration(
                              labelText: tr(context, 'Email link or oobCode'),
                              prefixIcon: const Icon(Icons.link_rounded),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        FilledButton.icon(
                          onPressed:
                              _submitting
                                  ? null
                                  : _linkSent
                                  ? _finishLink
                                  : _sendLink,
                          icon: Icon(
                            _linkSent
                                ? Icons.login_rounded
                                : Icons.send_outlined,
                          ),
                          label: Text(
                            tr(
                              context,
                              _linkSent
                                  ? 'Complete sign in'
                                  : 'Send sign-in link',
                            ),
                          ),
                        ),
                      ],
                    )
                    : Column(
                      key: const ValueKey('password-auth'),
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _password,
                          enabled: !_submitting,
                          obscureText: true,
                          enableSuggestions: false,
                          autocorrect: false,
                          autofillHints:
                              _creating
                                  ? const [AutofillHints.newPassword]
                                  : const [AutofillHints.password],
                          decoration: InputDecoration(
                            labelText: tr(context, 'Password'),
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _submitting ? null : _submitPassword,
                          child: Text(
                            tr(
                              context,
                              _submitting
                                  ? 'Connecting...'
                                  : _creating
                                  ? 'Create account'
                                  : 'Sign in',
                            ),
                          ),
                        ),
                        if (!_creating)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: _submitting ? null : _resetPassword,
                              child: Text(tr(context, 'Forgot password?')),
                            ),
                          ),
                      ],
                    ),
          ),
          if (_notice != null) ...[
            const SizedBox(height: 12),
            _AuthMessage(
              text: _notice!,
              icon: Icons.mark_email_read_outlined,
              color: theme.colorScheme.primaryContainer,
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            _AuthMessage(
              text: _error!,
              icon: Icons.error_outline_rounded,
              color: theme.colorScheme.errorContainer,
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(tr(context, 'or')),
              ),
              const Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed:
                _submitting
                    ? null
                    : () => setState(() {
                      _passwordless = !_passwordless;
                      _error = null;
                      _notice = null;
                    }),
            icon: Icon(
              _passwordless
                  ? Icons.password_rounded
                  : Icons.mark_email_unread_outlined,
            ),
            label: Text(
              tr(
                context,
                _passwordless
                    ? 'Use email and password'
                    : 'Use passwordless email link',
              ),
            ),
          ),
          if (!_passwordless)
            TextButton(
              onPressed:
                  _submitting
                      ? null
                      : () => setState(() => _creating = !_creating),
              child: Text(
                tr(
                  context,
                  _creating
                      ? 'Already have an account? Sign in'
                      : 'New to Acatrain? Create an account',
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AuthMessage extends StatelessWidget {
  const _AuthMessage({
    required this.text,
    required this.icon,
    required this.color,
  });
  final String text;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(AcatrainRadii.l),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(tr(context, text))),
      ],
    ),
  );
}

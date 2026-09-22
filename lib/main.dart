import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_ui.dart';
import 'models.dart';
import 'store.dart';
import 'study_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    try {
      await FlutterDisplayMode.setHighRefreshRate();
    } catch (_) {
      // The system remains in automatic display mode when no override is
      // available. Flutter animations continue to follow the platform vsync.
    }
  }
  final store = AppStore(await SharedPreferences.getInstance());
  await store.load();
  runApp(AcatrainApp(store: store));
  if (store.cloudConfigured) unawaited(store.syncContent());
}

class AcatrainApp extends StatelessWidget {
  const AcatrainApp({super.key, required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Acatrain',
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.system,
        theme: _theme(Brightness.light),
        darkTheme: _theme(Brightness.dark),
        home: HomeShell(store: store),
      );

  ThemeData _theme(Brightness brightness) {
    final colors = ColorScheme.fromSeed(
      seedColor: const Color(0xFF426B58),
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colors,
      scaffoldBackgroundColor: colors.surface,
      visualDensity: VisualDensity.standard,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: colors.primary, width: 2),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: colors.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: colors.surfaceContainer,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: colors.surface,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
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
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
    Navigator.push(
      context,
      AcatrainPageRoute<void>(
        builder: (_) => SetPage(set: set, store: store),
      ),
    );
  }

  void _selectPage(int index) => setState(() => _page = index);

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: store,
        builder: (context, _) {
          final windowClass = AcatrainLayout.classOf(context);
          final useRail = windowClass != AcatrainWindowClass.compact;
          final extendedRail =
              windowClass == AcatrainWindowClass.expanded &&
                  MediaQuery.sizeOf(context).width >= 1180;
          final theme = Theme.of(context);
          return Scaffold(
            appBar: AppBar(
              scrolledUnderElevation: 0,
              titleSpacing: useRail ? 24 : 20,
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      size: 19,
                      color: theme.colorScheme.onPrimary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'acatrain',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                    ),
                  ),
                ],
              ),
              actions: [
                if (store.uid != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Tooltip(
                      message: store.email ?? 'Signed in',
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: theme.colorScheme.secondaryContainer,
                        child: Text(
                          (store.email?.isNotEmpty ?? false)
                              ? store.email![0].toUpperCase()
                              : 'A',
                          style: theme.textTheme.labelLarge,
                        ),
                      ),
                    ),
                  ),
                IconButton(
                  tooltip: 'Sync content',
                  onPressed: store.busy ? null : store.syncContent,
                  icon: const Icon(Icons.sync_rounded),
                ),
                const SizedBox(width: 10),
              ],
            ),
            body: Column(
              children: [
                AnimatedSwitcher(
                  duration: acatrainFastMotion,
                  child: store.busy
                      ? const LinearProgressIndicator(
                          key: ValueKey('busy'),
                          minHeight: 2,
                        )
                      : const SizedBox(
                          key: ValueKey('idle'),
                          height: 2,
                        ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      if (useRail)
                        NavigationRail(
                          extended: extendedRail,
                          selectedIndex: _page,
                          groupAlignment: -0.72,
                          labelType: extendedRail
                              ? NavigationRailLabelType.none
                              : NavigationRailLabelType.all,
                          onDestinationSelected: _selectPage,
                          destinations: List.generate(
                            _labels.length,
                            (i) => NavigationRailDestination(
                              icon: Icon(_icons[i]),
                              selectedIcon: Icon(_selectedIcons[i]),
                              label: Text(_labels[i]),
                            ),
                          ),
                        ),
                      if (useRail)
                        VerticalDivider(
                          width: 1,
                          color: theme.colorScheme.outlineVariant
                              .withValues(alpha: 0.5),
                        ),
                      Expanded(
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth:
                                  AcatrainLayout.maxContentWidth(context),
                            ),
                            child: AnimatedSwitcher(
                              duration: acatrainMediumMotion,
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeInCubic,
                              transitionBuilder: (child, animation) {
                                final slide = Tween<Offset>(
                                  begin: const Offset(0.015, 0),
                                  end: Offset.zero,
                                ).animate(animation);
                                return FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(
                                    position: slide,
                                    child: child,
                                  ),
                                );
                              },
                              child: KeyedSubtree(
                                key: ValueKey(_page),
                                child: switch (_page) {
                                  0 => _today(theme),
                                  1 => _library(theme),
                                  2 => _review(theme),
                                  _ => _settings(theme),
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
            bottomNavigationBar: useRail
                ? null
                : NavigationBar(
                    selectedIndex: _page,
                    onDestinationSelected: _selectPage,
                    destinations: List.generate(
                      _labels.length,
                      (i) => NavigationDestination(
                        icon: Icon(_icons[i]),
                        selectedIcon: Icon(_selectedIcons[i]),
                        label: _labels[i],
                      ),
                    ),
                  ),
          );
        },
      );

  Widget _today(ThemeData theme) {
    final padding = AcatrainLayout.pagePadding(context);
    return ListView(
      padding: padding,
      children: [
        const SizedBox(height: 8),
        Text(
          'Make room for learning.',
          style: theme.textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -1.4,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Small sessions. Clear progress. Your own pace.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 28),
        _TodayHero(store: store, onOpen: _open),
        const SizedBox(height: 18),
        _MetricStrip(store: store),
        const SizedBox(height: 32),
        _sectionHeader(theme, 'Your study sets', store.bundle.sets.length),
        const SizedBox(height: 14),
        _grid(store.bundle.sets),
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

  Widget _library(ThemeData theme) {
    final subjects = [
      'All',
      ...store.bundle.sets.map((s) => s.subject).toSet(),
    ];
    final filter = subjects.contains(_subject) ? _subject : 'All';
    final sets = store.bundle.sets
        .where(
          (s) =>
              (filter == 'All' || s.subject == filter) &&
              '${s.title} ${s.subject} ${s.description}'
                  .toLowerCase()
                  .contains(_query.toLowerCase()),
        )
        .toList();
    return ListView(
      padding: AcatrainLayout.pagePadding(context),
      children: [
        const SizedBox(height: 8),
        Text(
          'Library',
          style: theme.textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Everything you can study, organised in one place.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        TextField(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search_rounded),
            hintText: 'Search your study sets',
          ),
          onChanged: (value) => setState(() => _query = value),
        ),
        const SizedBox(height: 18),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: subjects
                .map(
                  (subject) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(subject),
                      selected: filter == subject,
                      onSelected: (_) =>
                          setState(() => _subject = subject),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 24),
        if (sets.isEmpty)
          _EmptyState(
            icon: Icons.search_off_rounded,
            title: 'No matching study sets',
            message: 'Try another keyword or subject filter.',
          )
        else
          _grid(sets),
      ],
    );
  }

  Widget _grid(List<StudySet> sets) => LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 1050
              ? 4
              : constraints.maxWidth >= 760
                  ? 3
                  : constraints.maxWidth >= 500
                      ? 2
                      : 1;
          final aspect = columns == 1 ? 1.85 : 1.30;
          return GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: aspect,
            ),
            itemCount: sets.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemBuilder: (context, index) {
              final set = sets[index];
              return StudySetHero(
                setId: set.id,
                child: Material(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(28),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => _open(set),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .secondaryContainer,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.bookmark_outline_rounded,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  set.subject,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style:
                                      Theme.of(context).textTheme.labelLarge,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Expanded(
                            child: Text(
                              set.title,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${set.items.length} items · ${store.dueCount(set)} due',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      );

  Widget _review(ThemeData theme) => ListView(
        padding: AcatrainLayout.pagePadding(context),
        children: [
          const SizedBox(height: 8),
          Text(
            'Review, not relearn.',
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -1.2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Due items rise to the top. Missed answers stay easy to revisit.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 26),
          if (store.bundle.sets.every((s) => store.dueCount(s) == 0))
            const _EmptyState(
              icon: Icons.done_all_rounded,
              title: 'You are caught up',
              message: 'There are no review items due right now.',
            ),
          ...store.bundle.sets.map((set) {
            final mistakes =
                set.items.where((i) => store.isWrong(set, i)).toList();
            final due = store.dueCount(set);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final horizontal = constraints.maxWidth >= 620;
                      final info = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            set.title,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '$due due · ${mistakes.length} missed',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      );
                      final actions = Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          FilledButton(
                            onPressed: () => _open(set),
                            child: const Text('Review set'),
                          ),
                          OutlinedButton(
                            onPressed: mistakes.isEmpty
                                ? null
                                : () => Navigator.push(
                                      context,
                                      AcatrainPageRoute<void>(
                                        builder: (_) => StudyPage(
                                          set: set,
                                          items: mistakes,
                                          quiz: false,
                                          store: store,
                                        ),
                                      ),
                                    ),
                            child: const Text('Practise mistakes'),
                          ),
                        ],
                      );
                      if (!horizontal) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            info,
                            const SizedBox(height: 18),
                            actions,
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: info),
                          const SizedBox(width: 20),
                          actions,
                        ],
                      );
                    },
                  ),
                ),
              ),
            );
          }),
        ],
      );

  Widget _settings(ThemeData theme) => ListView(
        padding: AcatrainLayout.pagePadding(context),
        children: [
          const SizedBox(height: 8),
          Text(
            'Your learning space',
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -1.2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Account, sync and content controls without getting in your way.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 26),
          _SettingsCard(
            icon: store.uid == null
                ? Icons.person_outline_rounded
                : Icons.verified_user_outlined,
            title: 'Account & progress',
            body: store.email ?? 'Guest mode. No account needed to study.',
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: store.busy
                      ? null
                      : store.uid == null
                          ? _login
                          : store.syncProgress,
                  icon: Icon(
                    store.uid == null
                        ? Icons.login_rounded
                        : Icons.cloud_sync_outlined,
                  ),
                  label: Text(
                    store.uid == null
                        ? 'Sign in or create account'
                        : 'Sync progress',
                  ),
                ),
                if (store.uid != null)
                  OutlinedButton(
                    onPressed: store.busy ? null : store.signOut,
                    child: const Text('Sign out'),
                  ),
              ],
            ),
            footer:
                'Guest and account progress stay separate. Acatrain never uploads guest progress automatically.',
          ),
          const SizedBox(height: 14),
          _SettingsCard(
            icon: Icons.cloud_outlined,
            title: 'Live content',
            body: store.cloudConfigured
                ? 'Connected to your published content service.'
                : 'Bundled demo. Cloud service is not configured.',
            child: OutlinedButton.icon(
              onPressed: store.busy ? null : store.syncContent,
              icon: const Icon(Icons.sync_rounded),
              label: const Text('Check for content updates'),
            ),
            footer:
                'Release ${store.releaseId}. Study data can update independently; renderer changes still require an app update.',
          ),
          const SizedBox(height: 14),
          _SettingsCard(
            icon: Icons.speed_rounded,
            title: 'Display & motion',
            body:
                'Animations follow the device vsync. Android requests the highest refresh mode available; other platforms use the system display timing.',
            child: Text(
              '60 / 90 / 120 / 144Hz and variable-refresh displays are not artificially frame-capped by Acatrain.',
              style: theme.textTheme.bodyMedium,
            ),
            footer:
                'The operating system can still lower refresh rate for battery, thermal or window-management reasons.',
          ),
          const SizedBox(height: 22),
          Text(
            store.status,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Acatrain 0.1.0 · Build 1\nOriginal practice material, not an official exam or marking scheme.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      );

  Widget _sectionHeader(ThemeData theme, String title, int count) => Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            '$count',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );

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

class _TodayHero extends StatelessWidget {
  const _TodayHero({required this.store, required this.onOpen});

  final AppStore store;
  final ValueChanged<StudySet> onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final set = store.bundle.sets.isEmpty
        ? null
        : store.bundle.sets.firstWhere(
            (s) => store.dueCount(s) > 0,
            orElse: () => store.bundle.sets.first,
          );
    return Container(
      padding: EdgeInsets.all(AcatrainLayout.isCompact(context) ? 22 : 30),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(32),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final horizontal = constraints.maxWidth >= 680;
          final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.auto_stories_outlined,
                size: 38,
                color: theme.colorScheme.onPrimaryContainer,
              ),
              const SizedBox(height: 18),
              Text(
                '${store.totalDue} items ready to review',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Start with recall, then check what really stuck.',
                style: theme.textTheme.bodyLarge,
              ),
            ],
          );
          final button = FilledButton.icon(
            onPressed: set == null ? null : () => onOpen(set),
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('Start learning'),
          );
          if (!horizontal) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                copy,
                const SizedBox(height: 22),
                button,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: copy),
              const SizedBox(width: 24),
              button,
            ],
          );
        },
      ),
    );
  }
}

class _MetricStrip extends StatelessWidget {
  const _MetricStrip({required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _MetricChip(
            icon: Icons.collections_bookmark_outlined,
            label: '${store.bundle.sets.length} study sets',
          ),
          _MetricChip(
            icon: Icons.workspace_premium_outlined,
            label: '${store.mastered} well-practised',
          ),
          const _MetricChip(
            icon: Icons.offline_bolt_outlined,
            label: 'Offline ready',
          ),
        ],
      );
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 8),
            Text(label),
          ],
        ),
      );
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
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 5),
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
            const SizedBox(height: 20),
            child,
            const SizedBox(height: 16),
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
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          Icon(icon, size: 42),
          const SizedBox(height: 16),
          Text(title, style: theme.textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
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

  Future<void> _run(Future<bool> Function() action, {bool close = false}) async {
    setState(() {
      _submitting = true;
      _error = null;
      _notice = null;
    });
    final ok = await action();
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
      }
    });
  }

  Future<void> _submitPassword() => _run(
        () => widget.store.signIn(
          _email.text,
          _password.text,
          register: _creating,
        ),
        close: true,
      );

  Future<void> _sendLink() => _run(() async {
        final ok = await widget.store.sendEmailSignInLink(_email.text);
        if (ok && mounted) setState(() => _linkSent = true);
        return ok;
      });

  Future<void> _finishLink() => _run(
        () => widget.store.signInWithEmailLink(
          _email.text,
          _emailLink.text,
        ),
        close: true,
      );

  Future<void> _resetPassword() => _run(
        () => widget.store.sendPasswordReset(_email.text),
      );

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
            _passwordless
                ? 'Sign in without a password'
                : _creating
                    ? 'Create your account'
                    : 'Welcome back',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _passwordless
                ? 'We can send a one-time Firebase email link. On desktop/mobile you can paste the full link back here.'
                : 'Your cloud account only exists to sync learning progress across devices.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 22),
          TextField(
            controller: _email,
            enabled: !_submitting,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.mail_outline_rounded),
            ),
          ),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: acatrainFastMotion,
            child: _passwordless
                ? Column(
                    key: const ValueKey('link-auth'),
                    children: [
                      if (_linkSent) ...[
                        TextField(
                          controller: _emailLink,
                          enabled: !_submitting,
                          decoration: const InputDecoration(
                            labelText: 'Email link or oobCode',
                            prefixIcon: Icon(Icons.link_rounded),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      FilledButton.icon(
                        onPressed: _submitting
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
                          _linkSent
                              ? 'Complete sign in'
                              : 'Send sign-in link',
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
                        autofillHints: _creating
                            ? const [AutofillHints.newPassword]
                            : const [AutofillHints.password],
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          prefixIcon: Icon(Icons.lock_outline_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _submitting ? null : _submitPassword,
                        child: Text(
                          _submitting
                              ? 'Connecting...'
                              : _creating
                                  ? 'Create account'
                                  : 'Sign in',
                        ),
                      ),
                      if (!_creating)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: _submitting ? null : _resetPassword,
                            child: const Text('Forgot password?'),
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
          const Row(
            children: [
              Expanded(child: Divider()),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('or'),
              ),
              Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _submitting
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
              _passwordless
                  ? 'Use email and password'
                  : 'Use passwordless email link',
            ),
          ),
          if (!_passwordless)
            TextButton(
              onPressed: _submitting
                  ? null
                  : () => setState(() => _creating = !_creating),
              child: Text(
                _creating
                    ? 'Already have an account? Sign in'
                    : 'New to Acatrain? Create an account',
              ),
            ),
          const SizedBox(height: 8),
          Text(
            'Google, Apple and GitHub sign-in require provider-specific OAuth callback setup. The authentication layer is now structured so those providers can be added without changing progress storage.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
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
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(text)),
          ],
        ),
      );
}

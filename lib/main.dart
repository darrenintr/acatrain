import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'store.dart';
import 'study_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
    title: 'Acatrain', debugShowCheckedModeBanner: false,
    theme: _theme(Brightness.light), darkTheme: _theme(Brightness.dark),
    home: HomeShell(store: store),
  );
  ThemeData _theme(Brightness brightness) => ThemeData(
    useMaterial3: true, brightness: brightness,
    colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF426B58), brightness: brightness),
    inputDecorationTheme: InputDecorationTheme(border: OutlineInputBorder(borderRadius: BorderRadius.circular(18))),
    cardTheme: CardThemeData(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
    filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18))),
    outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18))),
  );
}
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.store});
  final AppStore store;
  @override
  State<HomeShell> createState() => _HomeShellState();
}
class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _page = 0;
  String _query = '', _subject = 'All';
  AppStore get store => widget.store;
  static const _labels = ['Today', 'Library', 'Review', 'Settings'];
  static const _icons = [Icons.space_dashboard_outlined, Icons.collections_bookmark_outlined,
    Icons.history_edu_outlined, Icons.tune];
  @override
  void initState() { super.initState(); WidgetsBinding.instance.addObserver(this); }
  @override
  void dispose() { WidgetsBinding.instance.removeObserver(this); super.dispose(); }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && store.cloudConfigured && !store.busy &&
        (store.lastContentSync == null || DateTime.now().difference(store.lastContentSync!).inMinutes >= 5)) {
      unawaited(store.syncContent());
    }
  }
  void _open(StudySet set) => Navigator.push(context,
    MaterialPageRoute<void>(builder: (_) => SetPage(set: set, store: store)));
  @override
  Widget build(BuildContext context) => AnimatedBuilder(animation: store, builder: (context, _) {
    final wide = MediaQuery.sizeOf(context).width >= 840;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('acatrain', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        actions: [IconButton(tooltip: 'Sync content', onPressed: store.busy ? null : store.syncContent,
          icon: const Icon(Icons.sync)), const SizedBox(width: 12)]),
      body: Column(children: [
        if (store.busy) const LinearProgressIndicator(minHeight: 2),
        Expanded(child: Row(children: [
          if (wide) ...[
            NavigationRail(extended: true, selectedIndex: _page,
              onDestinationSelected: (index) => setState(() => _page = index),
              destinations: List.generate(4, (i) => NavigationRailDestination(icon: Icon(_icons[i]), label: Text(_labels[i])))),
            const VerticalDivider(width: 1),
          ],
          Expanded(child: Align(alignment: Alignment.topCenter,
            child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1160), child:
              _page == 0 ? _today(theme) : _page == 1 ? _library(theme) :
              _page == 2 ? _review(theme) : _settings(theme)),
          )),
        ])),
      ]),
      bottomNavigationBar: wide ? null : NavigationBar(selectedIndex: _page,
        onDestinationSelected: (index) => setState(() => _page = index),
        destinations: List.generate(4, (i) => NavigationDestination(icon: Icon(_icons[i]), label: _labels[i]))),
    );
  });
  Widget _today(ThemeData theme) => ListView(padding: const EdgeInsets.all(24), children: [
    Text('Make room for learning.', style: theme.textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w700)),
    const SizedBox(height: 10), const Text('Small sessions. Clear progress. Your own pace.'),
    const SizedBox(height: 28),
    Container(padding: const EdgeInsets.all(28), decoration: BoxDecoration(
      color: theme.colorScheme.primaryContainer, borderRadius: BorderRadius.circular(28)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.auto_stories_outlined, size: 36), const SizedBox(height: 20),
        Text('${store.totalDue} items ready to review', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 10), const Text('Start with recall, then check what really stuck.'),
        const SizedBox(height: 20), FilledButton.icon(
          onPressed: store.bundle.sets.isEmpty ? null : () {
            final set = store.bundle.sets.firstWhere((s) => store.dueCount(s) > 0,
              orElse: () => store.bundle.sets.first);
            _open(set);
          }, icon: const Icon(Icons.arrow_forward), label: const Text('Start learning')),
      ])),
    const SizedBox(height: 20), Wrap(spacing: 10, runSpacing: 10, children: [
      Chip(label: Text('${store.bundle.sets.length} study sets')),
      Chip(label: Text('${store.mastered} well-practised items')),
      const Chip(avatar: Icon(Icons.offline_bolt_outlined, size: 18), label: Text('Offline ready')),
    ]),
    const SizedBox(height: 28), Text('Your study sets', style: theme.textTheme.titleLarge),
    const SizedBox(height: 14), _grid(store.bundle.sets),
    const SizedBox(height: 20), Text(store.status, style: theme.textTheme.bodySmall),
  ]);
  Widget _library(ThemeData theme) {
    final subjects = ['All', ...store.bundle.sets.map((s) => s.subject).toSet()];
    final filter = subjects.contains(_subject) ? _subject : 'All';
    final sets = store.bundle.sets.where((s) => (filter == 'All' || s.subject == filter) &&
      '${s.title} ${s.subject} ${s.description}'.toLowerCase().contains(_query.toLowerCase())).toList();
    return ListView(padding: const EdgeInsets.all(24), children: [
      Text('Library', style: theme.textTheme.headlineLarge), const SizedBox(height: 20),
      TextField(decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search your study sets'),
        onChanged: (value) => setState(() => _query = value)),
      const SizedBox(height: 18), Wrap(spacing: 8, runSpacing: 8, children: subjects.map((subject) =>
        ChoiceChip(label: Text(subject), selected: filter == subject,
          onSelected: (_) => setState(() => _subject = subject))).toList()),
      const SizedBox(height: 24),
      if (sets.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Text('No matching study sets.')) else _grid(sets),
    ]);
  }
  Widget _grid(List<StudySet> sets) => LayoutBuilder(builder: (context, constraints) {
    final columns = constraints.maxWidth >= 800 ? 3 : constraints.maxWidth >= 520 ? 2 : 1;
    return GridView.count(crossAxisCount: columns, shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(), mainAxisSpacing: 12, crossAxisSpacing: 12,
      childAspectRatio: columns == 1 ? 1.65 : 1.4,
      children: sets.map((set) => Card(clipBehavior: Clip.antiAlias, child: InkWell(
        onTap: () => _open(set), child: Padding(padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [const Icon(Icons.bookmark_outline), const SizedBox(width: 10),
              Expanded(child: Text(set.subject, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge))]),
            const SizedBox(height: 12), Expanded(child: Text(set.title, maxLines: 3,
              overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleLarge)),
            Text('${set.items.length} items  /  ${store.dueCount(set)} due', style: Theme.of(context).textTheme.bodySmall),
          ])),
      ))).toList(),
    );
  });
  Widget _review(ThemeData theme) => ListView(padding: const EdgeInsets.all(24), children: [
    Text('Review, not relearn.', style: theme.textTheme.headlineLarge),
    const SizedBox(height: 12), const Text('New and due items appear first. Missed answers stay in your mistake list.'),
    const SizedBox(height: 24),
    ...store.bundle.sets.map((set) {
      final mistakes = set.items.where((i) => store.isWrong(set, i)).toList();
      return Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(set.title, style: theme.textTheme.titleLarge), const SizedBox(height: 10),
          Text('${store.dueCount(set)} due  /  ${mistakes.length} missed'), const SizedBox(height: 16),
          Wrap(spacing: 10, runSpacing: 10, children: [
            FilledButton(onPressed: () => _open(set), child: const Text('Review set')),
            OutlinedButton(onPressed: mistakes.isEmpty ? null : () => Navigator.push(context,
              MaterialPageRoute<void>(builder: (_) => StudyPage(set: set, items: mistakes, quiz: false, store: store))),
              child: const Text('Practise mistakes')),
          ]),
        ])));
    }),
  ]);
  Widget _settings(ThemeData theme) => ListView(padding: const EdgeInsets.all(24), children: [
    Text('Your learning space', style: theme.textTheme.headlineLarge), const SizedBox(height: 24),
    Card(child: Padding(padding: const EdgeInsets.all(24), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Account & progress', style: theme.textTheme.titleLarge), const SizedBox(height: 10),
        Text(store.email ?? 'Guest mode. No account needed to study.'), const SizedBox(height: 16),
        Wrap(spacing: 10, runSpacing: 10, children: [
          FilledButton(onPressed: store.busy ? null : store.uid == null ? () => _login() : store.syncProgress,
            child: Text(store.uid == null ? 'Sign in / Create account' : 'Sync progress')),
          if (store.uid != null) OutlinedButton(onPressed: store.busy ? null : store.signOut, child: const Text('Sign out')),
        ]), const SizedBox(height: 14),
        const Text('Guest and account progress are separate. Sessions are kept in memory only; sign in again after restarting.'),
      ]))), const SizedBox(height: 16),
    Card(child: Padding(padding: const EdgeInsets.all(24), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Live content', style: theme.textTheme.titleLarge), const SizedBox(height: 10),
        SelectableText('Release: ${store.releaseId}'), const SizedBox(height: 8),
        Text(store.cloudConfigured ? 'Connected to your content API' : 'Bundled demo. Cloud service is not configured.'),
        const SizedBox(height: 16), OutlinedButton.icon(onPressed: store.busy ? null : store.syncContent,
          icon: const Icon(Icons.sync), label: const Text('Check for content updates')),
        const SizedBox(height: 14), const Text('Only study data is updated. No downloaded executable code. New renderer capabilities require a new app version.'),
      ]))), const SizedBox(height: 20),
    Text(store.status), const SizedBox(height: 24),
    const Text('Acatrain 0.1.0 / Build 1\nOriginal practice material, not an official exam or marking scheme.'),
  ]);
  Future<void> _login() async {
    await showDialog<void>(context: context, builder: (_) => _LoginDialog(store: store));
  }
}
class _LoginDialog extends StatefulWidget {
  const _LoginDialog({required this.store});
  final AppStore store;
  @override
  State<_LoginDialog> createState() => _LoginDialogState();
}
class _LoginDialogState extends State<_LoginDialog> {
  final _email = TextEditingController(), _password = TextEditingController();
  bool _creating = false, _submitting = false;
  String? _error;
  @override
  void dispose() { _email.dispose(); _password.dispose(); super.dispose(); }
  Future<void> _submit() async {
    setState(() { _submitting = true; _error = null; });
    final ok = await widget.store.signIn(_email.text, _password.text, register: _creating);
    if (!mounted) return;
    if (ok) { Navigator.pop(context); }
    else { setState(() { _submitting = false; _error = widget.store.status; }); }
  }
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(_creating ? 'Create your account' : 'Welcome back'),
    content: SizedBox(width: 380, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: _email, keyboardType: TextInputType.emailAddress,
        decoration: const InputDecoration(labelText: 'Email')), const SizedBox(height: 14),
      TextField(controller: _password, obscureText: true, enableSuggestions: false, autocorrect: false,
        decoration: const InputDecoration(labelText: 'Password')), const SizedBox(height: 12),
      if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
      TextButton(onPressed: _submitting ? null : () => setState(() => _creating = !_creating),
        child: Text(_creating ? 'Already have an account? Sign in' : 'Create an account instead')),
    ]))),
    actions: [TextButton(onPressed: _submitting ? null : () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(onPressed: _submitting ? null : _submit,
        child: Text(_submitting ? 'Connecting...' : _creating ? 'Create account' : 'Sign in'))],
  );
}

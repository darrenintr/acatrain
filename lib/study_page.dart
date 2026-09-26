import 'package:flutter/material.dart';
import 'language.dart';

import 'app_ui.dart';
import 'expressive.dart';
import 'models.dart';
import 'store.dart';
import 'game_page.dart';

/// Renders `^2`/`^3` as superscripts and a lone `-` as a proper minus sign,
/// for display only. Content itself is never rewritten.
String _displayMath(String text) {
  var result = text.replaceAll('^2', '²').replaceAll('^3', '³');
  result = result.replaceAllMapped(RegExp(r'(?<=\s)-(?=\s)'), (_) => '−');
  return result;
}

class SetPage extends StatelessWidget {
  const SetPage({super.key, required this.set, required this.store});

  final StudySet set;
  final AppStore store;

  void _start(BuildContext context, List<StudyItem> items, bool quiz) {
    Navigator.push(
      context,
      AcatrainPageRoute<void>(
        builder:
            (_) => StudyPage(set: set, items: items, quiz: quiz, store: store),
      ),
    );
  }

  void _startGame(BuildContext context, StudyGame game) {
    Navigator.push(
      context,
      AcatrainPageRoute<void>(
        builder: (_) => GamePage(set: set, store: store, game: game),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) => _buildContent(context),
  );

  Widget _buildContent(BuildContext context) {
    final theme = Theme.of(context);
    final quizzes = set.items.where((i) => i.isQuiz).toList();
    final matchable = matchableItems(set.items);
    final quickItems = quickAnswerItems(set.items);
    final due = store.dueItems(set);
    final practised = store.practisedCount(set);
    final style = SubjectStyle.of(context, set.subject);
    final progress = store.completion(set);

    return Scaffold(
      appBar: AppBar(),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: AcatrainLayout.maxContentWidth(context),
          ),
          child: FadingListView(
            padding: AcatrainLayout.pagePadding(context),
            children: [
              StudySetHero(
                setId: set.id,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ExpressiveBadge(
                      shape: style.shape,
                      size: 28,
                      color: style.fill,
                      child: Icon(style.icon, size: 16, color: style.onFill),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      set.subject,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(set.title, style: theme.textTheme.headlineLarge),
              const SizedBox(height: 8),
              Text(
                set.description,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      isCantonese(context)
                          ? '$practised / ${set.items.length} 題已熟習'
                          : '$practised of ${set.items.length} well-practised',
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: acatrainWeight(650),
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Text(
                    isCantonese(context)
                        ? '${due.length} 題待溫習'
                        : '${due.length} due',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 13,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              WavyProgress(
                value: progress,
                color: style.fill,
                semanticsLabel:
                    '$practised of ${set.items.length} well-practised',
              ),
              const SizedBox(height: 24),
              _ModeTile.primary(
                icon: Icons.style_rounded,
                title: tr(context, 'Flashcards'),
                detail:
                    isCantonese(context)
                        ? '重溫全部 ${set.items.length} 題'
                        : 'Recall all ${set.items.length} items',
                onTap: () => _start(context, set.items, false),
              ),
              const SizedBox(height: 8),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _ModeTile(
                        icon: Icons.quiz_rounded,
                        title: tr(context, 'Practice test'),
                        detail:
                            isCantonese(context)
                                ? '${quizzes.length} 條問題'
                                : '${quizzes.length} questions',
                        background: theme.colorScheme.tertiaryContainer,
                        foreground: theme.colorScheme.onTertiaryContainer,
                        primary: false,
                        onTap:
                            quizzes.isEmpty
                                ? null
                                : () => _start(context, quizzes, true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ModeTile(
                        icon: Icons.history_rounded,
                        title: tr(context, 'Review due'),
                        detail:
                            isCantonese(context)
                                ? '${due.length} 題可以溫習'
                                : '${due.length} items ready now',
                        background: theme.colorScheme.secondaryContainer,
                        foreground: theme.colorScheme.onSecondaryContainer,
                        primary: false,
                        onTap:
                            due.isEmpty
                                ? null
                                : () => _start(context, due, false),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                tr(context, 'Mini games'),
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _ModeTile(
                        icon: Icons.join_inner_rounded,
                        title: tr(context, 'Match pairs'),
                        detail:
                            isCantonese(context)
                                ? '${matchable.length} 組問答配對'
                                : '${matchable.length} pairs to connect',
                        background: theme.colorScheme.secondaryContainer,
                        foreground: theme.colorScheme.onSecondaryContainer,
                        onTap:
                            matchable.length < 2
                                ? null
                                : () => _startGame(context, StudyGame.match),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ModeTile(
                        icon: Icons.bolt_rounded,
                        title: tr(context, 'Quick answers'),
                        detail:
                            isCantonese(context)
                                ? '${quickItems.length} 題快速挑戰'
                                : '${quickItems.length} fast questions',
                        background: theme.colorScheme.tertiaryContainer,
                        foreground: theme.colorScheme.onTertiaryContainer,
                        onTap:
                            quickItems.isEmpty
                                ? null
                                : () =>
                                    _startGame(context, StudyGame.quickAnswer),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: Text(
                      tr(context, 'Inside this set'),
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  Text(
                    isCantonese(context)
                        ? '${set.items.length} 題'
                        : '${set.items.length} items',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: acatrainWeight(550),
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < set.items.length; i++)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: i == set.items.length - 1 ? 0 : 2,
                  ),
                  child: _SetItemRow(
                    item: set.items[i],
                    status: store.statusOf(set, set.items[i]),
                    radius: segmentRadius(
                      i,
                      set.items.length,
                      outer: AcatrainRadii.lPlus,
                      inner: AcatrainRadii.xs,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.icon,
    required this.title,
    required this.detail,
    required this.background,
    required this.foreground,
    required this.onTap,
    this.primary = false,
  });

  const _ModeTile.primary({
    required this.icon,
    required this.title,
    required this.detail,
    required this.onTap,
  }) : background = null,
       foreground = null,
       primary = true;

  final IconData icon;
  final String title;
  final String detail;
  final Color? background;
  final Color? foreground;
  final VoidCallback? onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = onTap != null;
    final bg =
        primary
            ? theme.colorScheme.primary
            : (background ?? theme.colorScheme.surfaceContainerLow);
    final fg =
        primary
            ? theme.colorScheme.onPrimary
            : (foreground ?? theme.colorScheme.onSurface);
    final opacity = enabled ? 1.0 : 0.38;

    final badge = ExpressiveBadge(
      shape: ExpressiveShape.sunny,
      size: primary ? 56 : 40,
      color:
          primary
              ? theme.colorScheme.primaryContainer
              : fg.withValues(alpha: 0.16),
      child: Icon(
        icon,
        color: primary ? theme.colorScheme.onPrimaryContainer : fg,
        size: primary ? 28 : 22,
      ),
    );

    final content =
        primary
            ? Row(
              children: [
                badge,
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleLarge?.copyWith(color: fg),
                      ),
                      Text(
                        detail,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: fg.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_rounded, color: fg),
              ],
            )
            : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                badge,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: fg,
                        fontSize: 17,
                      ),
                    ),
                    Text(
                      detail,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: fg,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            );

    return Opacity(
      opacity: opacity,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(
          primary ? AcatrainRadii.xl : AcatrainRadii.l,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: BoxConstraints(minHeight: primary ? 96 : 128),
            padding: const EdgeInsets.all(16),
            child: content,
          ),
        ),
      ),
    );
  }
}

class _SetItemRow extends StatelessWidget {
  const _SetItemRow({
    required this.item,
    required this.status,
    required this.radius,
  });
  final StudyItem item;
  final ItemStatus status;
  final BorderRadius radius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: radius,
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
      constraints: const BoxConstraints(minHeight: 64),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.prompt,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontSize: 15,
                    height: 21 / 15,
                    fontWeight: acatrainWeight(550),
                  ),
                ),
                Text(
                  tr(context, item.isQuiz ? 'Multiple choice' : 'Flashcard'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _StatusPill(status: status),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final ItemStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (label, bg, fg) = switch (status) {
      ItemStatus.missed => (
        'Missed',
        colors.errorContainer,
        colors.onErrorContainer,
      ),
      ItemStatus.due => (
        'Due',
        colors.tertiaryContainer,
        colors.onTertiaryContainer,
      ),
      ItemStatus.practised => (
        'Practised',
        colors.primaryContainer,
        colors.onPrimaryContainer,
      ),
      ItemStatus.new_ => (
        'New',
        colors.surfaceContainerHigh,
        colors.onSurfaceVariant,
      ),
    };
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AcatrainRadii.s),
      ),
      alignment: Alignment.center,
      child: Text(
        tr(context, label),
        style: TextStyle(
          fontSize: 11,
          height: 16 / 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: fg,
        ),
      ),
    );
  }
}

class StudyPage extends StatefulWidget {
  const StudyPage({
    super.key,
    required this.set,
    required this.items,
    required this.quiz,
    required this.store,
  });

  final StudySet set;
  final List<StudyItem> items;
  final bool quiz;
  final AppStore store;

  @override
  State<StudyPage> createState() => _StudyPageState();
}

class _StudyPageState extends State<StudyPage> {
  late List<StudyItem> _items;
  final List<StudyItem> _missed = [];
  int _index = 0;
  int _correct = 0;
  int? _selected;
  bool _revealed = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _items = List.of(widget.items);
  }

  Future<void> _advance(bool correct) async {
    if (_saving) return;
    setState(() => _saving = true);
    final item = _items[_index];
    await widget.store.record(widget.set, item, correct);
    if (!mounted) return;
    setState(() {
      if (correct) {
        _correct++;
      } else {
        _missed.add(item);
      }
      _index++;
      _selected = null;
      _revealed = false;
      _saving = false;
    });
  }

  void _retryMissed() {
    setState(() {
      _items = List.of(_missed);
      _missed.clear();
      _index = 0;
      _correct = 0;
      _selected = null;
      _revealed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final finished = _index >= _items.length;
    final compact = AcatrainLayout.isCompact(context);

    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 840),
            child: Column(
              children: [
                _SessionHeader(
                  finished: finished,
                  mode: tr(
                    context,
                    widget.quiz ? 'Practice test' : 'Flashcards',
                  ),
                  setTitle: widget.set.title,
                  index: _index,
                  total: _items.length,
                ),
                Expanded(
                  child: FadingListView(
                    padding: AcatrainLayout.pagePadding(context),
                    children: [
                      AnimatedSwitcher(
                        duration: AcatrainSprings.durationOf(
                          context,
                          AcatrainSprings.spatialDefault,
                        ),
                        layoutBuilder:
                            (currentChild, previousChildren) => Stack(
                              alignment: Alignment.topCenter,
                              children: [
                                ...previousChildren,
                                if (currentChild != null) currentChild,
                              ],
                            ),
                        transitionBuilder: (child, animation) {
                          final slide = Tween<Offset>(
                            begin: const Offset(0.035, 0),
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
                              curve: _contentFadeCurve,
                            ),
                            child: SlideTransition(
                              position: slide,
                              child: child,
                            ),
                          );
                        },
                        child:
                            finished
                                ? _FinishedSession(
                                  key: const ValueKey('finished'),
                                  set: widget.set,
                                  store: widget.store,
                                  correct: _correct,
                                  total: _items.length,
                                  quiz: widget.quiz,
                                  missed: _missed.length,
                                  onDone: () => Navigator.pop(context),
                                  onRetry:
                                      _missed.isEmpty ? null : _retryMissed,
                                )
                                : KeyedSubtree(
                                  key: ValueKey('item-$_index'),
                                  child:
                                      widget.quiz
                                          ? _QuizCard(
                                            item: _items[_index],
                                            questionNumber: _index + 1,
                                            selected: _selected,
                                            saving: _saving,
                                            onSelect:
                                                (value) => setState(
                                                  () => _selected = value,
                                                ),
                                            onContinue:
                                                () => _advance(
                                                  _selected ==
                                                      _items[_index]
                                                          .correctIndex,
                                                ),
                                          )
                                          : _Flashcard(
                                            item: _items[_index],
                                            revealed: _revealed,
                                            saving: _saving,
                                            compact: compact,
                                            onReveal:
                                                () => setState(
                                                  () => _revealed = true,
                                                ),
                                            onToggle:
                                                () => setState(
                                                  () => _revealed = !_revealed,
                                                ),
                                            onAgain: () => _advance(false),
                                            onGotIt: () => _advance(true),
                                          ),
                                ),
                      ),
                      const SizedBox(height: 100),
                    ],
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

class _SessionHeader extends StatelessWidget {
  const _SessionHeader({
    required this.finished,
    required this.mode,
    required this.setTitle,
    required this.index,
    required this.total,
  });

  final bool finished;
  final String mode;
  final String setTitle;
  final int index;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shownIndex = (index >= total ? total : index + 1).clamp(0, total);
    return Column(
      children: [
        SizedBox(
          height: 64,
          child: Row(
            children: [
              IconButton(
                tooltip: tr(context, finished ? 'Close' : 'End session'),
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
              if (!finished)
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mode,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontSize: 16,
                          height: 22 / 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        setTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                )
              else
                const Spacer(),
            ],
          ),
        ),
        if (!finished)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: Row(
              children: [
                Expanded(
                  child: WavyProgress(
                    value: total == 0 ? 0 : index / total,
                    semanticsLabel: '$shownIndex of $total',
                  ),
                ),
                const SizedBox(width: 12),
                Text.rich(
                  TextSpan(
                    style: TextStyle(
                      fontFamily: 'Google Sans Flex',
                      fontFamilyFallback: const ['Figtree'],
                      fontSize: 14,
                      height: 20 / 14,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                    children: [
                      TextSpan(
                        text: '$shownIndex',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      TextSpan(
                        text: ' / $total',
                        style: TextStyle(
                          fontWeight: acatrainWeight(550),
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
  });
  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) => Container(
    height: 28,
    padding: const EdgeInsets.fromLTRB(8, 0, 12, 0),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(AcatrainRadii.l),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: foreground),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
            color: foreground,
          ),
        ),
      ],
    ),
  );
}

/// Session content fade: the effects spring, stretched over the spatial
/// spring's settle time that drives the accompanying slide.
final _contentFadeCurve = AcatrainSpringCurve(
  AcatrainSprings.effectsDefault,
  span: AcatrainSprings.settle(AcatrainSprings.spatialDefault),
);

class _Flashcard extends StatelessWidget {
  const _Flashcard({
    required this.item,
    required this.revealed,
    required this.saving,
    required this.compact,
    required this.onReveal,
    required this.onToggle,
    required this.onAgain,
    required this.onGotIt,
  });

  final StudyItem item;
  final bool revealed;
  final bool saving;
  final bool compact;
  final VoidCallback onReveal;
  final VoidCallback onToggle;
  final VoidCallback onAgain;
  final VoidCallback onGotIt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final tones = theme.extension<AcatrainTones>() ?? AcatrainTones.light;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return Column(
      children: [
        Semantics(
          button: true,
          label: tr(
            context,
            revealed
                ? 'Answer shown. Tap to flip back.'
                : 'Tap to reveal answer',
          ),
          child: Material(
            color: colors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AcatrainRadii.xlPlus),
            clipBehavior: Clip.antiAlias,
            elevation: 0,
            child: InkWell(
              onTap: saving ? null : onToggle,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: AnimatedSize(
                  duration: AcatrainSprings.durationOf(
                    context,
                    AcatrainSprings.spatialDefault,
                  ),
                  curve: AcatrainSprings.spatialDefaultCurve,
                  alignment: Alignment.topCenter,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        constraints: const BoxConstraints(minHeight: 212),
                        padding: const EdgeInsets.fromLTRB(18, 20, 18, 28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _Chip(
                              icon: Icons.help_rounded,
                              label: tr(context, 'Question'),
                              background: colors.surfaceContainerHigh,
                              foreground: colors.onSurfaceVariant,
                            ),
                            const SizedBox(height: 20),
                            Text(
                              item.prompt,
                              style: TextStyle(
                                fontFamily: 'Google Sans Flex',
                                fontFamilyFallback: const ['Figtree'],
                                fontSize: 30,
                                height: 36 / 30,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.8,
                                color: colors.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (revealed)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
                          child: AcatrainSpringIn(
                            disabled: reduceMotion,
                            spring: AcatrainSprings.spatialDefault,
                            builder:
                                (context, t) => Opacity(
                                  opacity: t.clamp(0.0, 1.0),
                                  child: Container(
                                    margin: const EdgeInsets.fromLTRB(
                                      0,
                                      0,
                                      0,
                                      0,
                                    ),
                                    padding: const EdgeInsets.fromLTRB(
                                      18,
                                      20,
                                      18,
                                      22,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colors.primaryContainer,
                                      borderRadius: BorderRadius.circular(26),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _Chip(
                                          icon: Icons.lightbulb_rounded,
                                          label: tr(context, 'Answer'),
                                          background: tones.heroAccent,
                                          foreground: colors.onPrimaryContainer,
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          item.answerText,
                                          style: TextStyle(
                                            fontSize: 18,
                                            height: 27 / 18,
                                            fontWeight: FontWeight.w500,
                                            color: colors.onPrimaryContainer,
                                          ),
                                        ),
                                      ],
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
          ),
        ),
        const SizedBox(height: 14),
        Text(
          tr(
            context,
            revealed
                ? 'Tap the card to flip it back'
                : 'Tap card to reveal the answer',
          ),
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        AnimatedSwitcher(
          duration: AcatrainSprings.durationOf(
            context,
            AcatrainSprings.effectsDefault,
          ),
          switchInCurve: AcatrainSprings.effectsDefaultCurve,
          switchOutCurve: AcatrainSprings.effectsDefaultCurve,
          child:
              revealed
                  ? Column(
                    key: const ValueKey('rating'),
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 64,
                              child: AcatrainPressScale(
                                pressedScale: 0.96,
                                child: FilledButton.icon(
                                  onPressed: saving ? null : onAgain,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: colors.secondaryContainer,
                                    foregroundColor:
                                        colors.onSecondaryContainer,
                                    shape: const RoundedRectangleBorder(
                                      borderRadius: BorderRadius.horizontal(
                                        left: Radius.circular(32),
                                        right: Radius.circular(10),
                                      ),
                                    ),
                                  ),
                                  icon: const Icon(Icons.replay_rounded),
                                  label: Text(tr(context, 'Again')),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: SizedBox(
                              height: 64,
                              child: AcatrainPressScale(
                                pressedScale: 0.96,
                                child: FilledButton.icon(
                                  onPressed: saving ? null : onGotIt,
                                  style: FilledButton.styleFrom(
                                    shape: const RoundedRectangleBorder(
                                      borderRadius: BorderRadius.horizontal(
                                        left: Radius.circular(10),
                                        right: Radius.circular(32),
                                      ),
                                    ),
                                  ),
                                  icon: const Icon(Icons.check_rounded),
                                  label: Text(tr(context, 'Got it')),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        tr(context, 'Progress is saved on this device.'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  )
                  : SizedBox(
                    key: const ValueKey('reveal'),
                    width: double.infinity,
                    height: 64,
                    child: FilledButton(
                      onPressed: saving ? null : onReveal,
                      child: Text(tr(context, 'Show answer')),
                    ),
                  ),
        ),
      ],
    );
  }
}

class _QuizCard extends StatelessWidget {
  const _QuizCard({
    required this.item,
    required this.questionNumber,
    required this.selected,
    required this.saving,
    required this.onSelect,
    required this.onContinue,
  });

  final StudyItem item;
  final int questionNumber;
  final int? selected;
  final bool saving;
  final ValueChanged<int> onSelect;
  final VoidCallback onContinue;

  static const _letters = ['A', 'B', 'C', 'D', 'E', 'F'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          isCantonese(context)
              ? '第 $questionNumber 題'
              : 'QUESTION $questionNumber',
          style: TextStyle(
            fontSize: 13,
            height: 18 / 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: colors.tertiary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _displayMath(item.prompt),
          style: TextStyle(
            fontFamily: 'Google Sans Flex',
            fontFamilyFallback: const ['Figtree'],
            fontSize: 32,
            height: 40 / 32,
            fontWeight: acatrainWeight(750),
            letterSpacing: -0.8,
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: 22),
        for (var i = 0; i < item.choices.length; i++)
          Padding(
            padding: EdgeInsets.only(
              bottom: i == item.choices.length - 1 ? 0 : 3,
            ),
            child: _ChoiceRow(
              letter: _letters[i],
              text: _displayMath(item.choices[i]),
              state:
                  selected == null
                      ? (i == selected
                          ? _ChoiceState.selecting
                          : _ChoiceState.idle)
                      : i == item.correctIndex
                      ? _ChoiceState.correct
                      : i == selected
                      ? _ChoiceState.wrong
                      : _ChoiceState.idle,
              radius: segmentRadius(
                i,
                item.choices.length,
                outer: AcatrainRadii.xl,
                inner: AcatrainRadii.s,
              ),
              onTap: selected != null || saving ? null : () => onSelect(i),
            ),
          ),
        if (selected != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            decoration: BoxDecoration(
              color: colors.tertiaryContainer,
              borderRadius: BorderRadius.circular(AcatrainRadii.l),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExpressiveBadge(
                  shape: ExpressiveShape.sunny,
                  size: 36,
                  color: colors.tertiary,
                  child: Icon(
                    Icons.lightbulb_rounded,
                    size: 20,
                    color: colors.onTertiary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr(context, 'Why'),
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: colors.onTertiaryContainer,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.explanation,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontSize: 15,
                          height: 22 / 15,
                          color: colors.onTertiaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 64,
            child: FilledButton(
              onPressed: saving ? null : onContinue,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(tr(context, 'Continue')),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

enum _ChoiceState { idle, selecting, correct, wrong }

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.letter,
    required this.text,
    required this.state,
    required this.radius,
    required this.onTap,
  });

  final String letter;
  final String text;
  final _ChoiceState state;
  final BorderRadius radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (background, foreground) = switch (state) {
      _ChoiceState.idle => (colors.surfaceContainerLow, colors.onSurface),
      _ChoiceState.selecting => (
        colors.secondaryContainer,
        colors.onSecondaryContainer,
      ),
      _ChoiceState.correct => (
        colors.primaryContainer,
        colors.onPrimaryContainer,
      ),
      _ChoiceState.wrong => (colors.errorContainer, colors.onErrorContainer),
    };

    Widget badge;
    switch (state) {
      case _ChoiceState.correct:
        badge = ExpressiveBadge(
          shape: ExpressiveShape.cookie9,
          size: 36,
          color: colors.primary,
          child: Icon(Icons.check_rounded, size: 20, color: colors.onPrimary),
        );
      case _ChoiceState.wrong:
        badge = Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: colors.error,
            borderRadius: BorderRadius.circular(AcatrainRadii.m),
          ),
          alignment: Alignment.center,
          child: Icon(Icons.close_rounded, size: 20, color: colors.onError),
        );
      case _ChoiceState.selecting:
        badge = Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: colors.secondary,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            letter,
            style: TextStyle(
              color: colors.onSecondary,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        );
      case _ChoiceState.idle:
        badge = Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: colors.surfaceContainerHigh,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            letter,
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        );
    }

    final trailing = switch (state) {
      _ChoiceState.correct => tr(context, 'Correct answer'),
      _ChoiceState.wrong => tr(context, 'Your answer'),
      _ => null,
    };

    return Material(
      color: background,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
          child: Row(
            children: [
              badge,
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 18,
                    height: 24 / 18,
                    fontWeight: FontWeight.w600,
                    color: foreground,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              if (trailing != null)
                Text(
                  trailing,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                    color: foreground,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FinishedSession extends StatelessWidget {
  const _FinishedSession({
    super.key,
    required this.set,
    required this.store,
    required this.correct,
    required this.total,
    required this.quiz,
    required this.missed,
    required this.onDone,
    required this.onRetry,
  });

  final StudySet set;
  final AppStore store;
  final int correct;
  final int total;
  final bool quiz;
  final int missed;
  final VoidCallback onDone;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final practised = store.practisedCount(set);
    final resultLabel = tr(context, quiz ? 'correct' : 'recalled');
    final summary =
        missed == 0
            ? (isCantonese(context)
                ? '${set.title} 做得好！暫時冇題目需要再溫習。'
                : 'Nice work on ${set.title}. Nothing needs another look yet.')
            : (isCantonese(context)
                ? '${set.title} 做得好！$missed 題已加入溫習清單。'
                : 'Nice work on ${set.title}. ${missed == 1 ? '1 item is' : '$missed items are'} back in your review queue.');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          AcatrainSpringIn(
            disabled: reduceMotion,
            spring: AcatrainSprings.spatialSlow,
            begin: 0.6,
            builder:
                (context, scale) => Transform.scale(
                  scale: scale,
                  child: SizedBox(
                    width: 232,
                    height: 232,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        ExpressiveBadge(
                          shape: ExpressiveShape.cookie12,
                          size: 232,
                          color: colors.primaryContainer,
                        ),
                        ExpressiveBadge(
                          shape: ExpressiveShape.cookie9,
                          size: 176,
                          color: colors.primary,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: '$correct',
                                      style: TextStyle(
                                        fontFamily: 'Google Sans Flex',
                                        fontFamilyFallback: const ['Figtree'],
                                        fontSize: 60,
                                        height: 1,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -2,
                                        color: colors.onPrimary,
                                        fontFeatures: const [
                                          FontFeature.tabularFigures(),
                                        ],
                                      ),
                                    ),
                                    TextSpan(
                                      text: '/$total',
                                      style: TextStyle(
                                        fontFamily: 'Google Sans Flex',
                                        fontFamilyFallback: const ['Figtree'],
                                        fontSize: 32,
                                        fontWeight: FontWeight.w800,
                                        color: colors.inversePrimary,
                                        fontFeatures: const [
                                          FontFeature.tabularFigures(),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                resultLabel,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: acatrainWeight(650),
                                  letterSpacing: 0.4,
                                  color: colors.onPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ),
          const SizedBox(height: 28),
          AcatrainSpringIn(
            disabled: reduceMotion,
            spring: AcatrainSprings.effectsDefault,
            builder:
                (context, opacity) => Opacity(
                  opacity: opacity.clamp(0.0, 1.0),
                  child: Column(
                    children: [
                      Text(
                        tr(context, 'Session complete'),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineLarge,
                      ),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          summary,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Row(
                        children: [
                          for (final (i, stat)
                              in [
                                ('$correct', tr(context, 'got it')),
                                ('$missed', tr(context, 'to revisit')),
                                ('$practised', tr(context, 'now practised')),
                              ].indexed)
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(
                                  left: i == 0 ? 0 : 3,
                                  right: i == 2 ? 0 : 3,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                    horizontal: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colors.surfaceContainerLow,
                                    borderRadius: segmentRadius(
                                      i,
                                      3,
                                      outer: AcatrainRadii.lPlus,
                                      inner: 6,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        stat.$1,
                                        style: theme.textTheme.titleLarge
                                            ?.copyWith(
                                              fontSize: 22,
                                              fontWeight: acatrainWeight(750),
                                            ),
                                      ),
                                      Text(
                                        stat.$2,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
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
                      const SizedBox(height: 28),
                      if (onRetry != null)
                        SizedBox(
                          width: double.infinity,
                          height: 64,
                          child: FilledButton.icon(
                            onPressed: onRetry,
                            icon: const Icon(Icons.replay_rounded),
                            label: Text(
                              isCantonese(context)
                                  ? '練習 $missed 題錯題'
                                  : 'Practise $missed missed item${missed == 1 ? '' : 's'}',
                            ),
                          ),
                        ),
                      if (onRetry != null) const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: TextButton(
                          onPressed: onDone,
                          child: Text(tr(context, 'Back to learning')),
                        ),
                      ),
                    ],
                  ),
                ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import 'app_ui.dart';
import 'models.dart';
import 'store.dart';

class SetPage extends StatelessWidget {
  const SetPage({
    super.key,
    required this.set,
    required this.store,
  });

  final StudySet set;
  final AppStore store;

  void _start(BuildContext context, List<StudyItem> items, bool quiz) {
    Navigator.push(
      context,
      AcatrainPageRoute<void>(
        builder: (_) => StudyPage(
          set: set,
          items: items,
          quiz: quiz,
          store: store,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final quizzes = set.items.where((i) => i.isQuiz).toList();
    final due = store.dueItems(set);
    final compact = AcatrainLayout.isCompact(context);

    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0,
        title: Text(set.subject),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: AcatrainLayout.maxContentWidth(context),
          ),
          child: ListView(
            padding: AcatrainLayout.pagePadding(context),
            children: [
              StudySetHero(
                setId: set.id,
                child: Material(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(32),
                  child: Padding(
                    padding: EdgeInsets.all(compact ? 22 : 30),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final horizontal = constraints.maxWidth >= 720;
                        final title = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surface.withValues(
                                  alpha: 0.58,
                                ),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: const Icon(
                                Icons.collections_bookmark_outlined,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              set.title,
                              style: theme.textTheme.headlineLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.8,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              set.description,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color:
                                    theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ],
                        );
                        final metrics = Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _SetMetric(
                              icon: Icons.style_outlined,
                              label: '${set.items.length} items',
                            ),
                            _SetMetric(
                              icon: Icons.schedule_rounded,
                              label: '${due.length} due',
                            ),
                            _SetMetric(
                              icon: Icons.quiz_outlined,
                              label: '${quizzes.length} questions',
                            ),
                          ],
                        );
                        if (!horizontal) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              title,
                              const SizedBox(height: 22),
                              metrics,
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(child: title),
                            const SizedBox(width: 28),
                            Flexible(child: metrics),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              _StudyActions(
                set: set,
                due: due,
                quizzes: quizzes,
                onStart: (items, quiz) => _start(context, items, quiz),
              ),
              const SizedBox(height: 32),
              Text(
                'Inside this set',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              ...set.items.asMap().entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 8,
                          ),
                          leading: Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              entry.value.isQuiz
                                  ? Icons.quiz_outlined
                                  : Icons.style_outlined,
                              size: 20,
                            ),
                          ),
                          title: Text(entry.value.prompt),
                          subtitle: Text(
                            entry.value.isQuiz
                                ? 'Multiple choice'
                                : 'Flashcard',
                          ),
                          trailing: Text(
                            '${entry.key + 1}',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
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

class _SetMetric extends StatelessWidget {
  const _SetMetric({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.58),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17),
            const SizedBox(width: 7),
            Text(label),
          ],
        ),
      );
}

class _StudyActions extends StatelessWidget {
  const _StudyActions({
    required this.set,
    required this.due,
    required this.quizzes,
    required this.onStart,
  });

  final StudySet set;
  final List<StudyItem> due;
  final List<StudyItem> quizzes;
  final void Function(List<StudyItem>, bool) onStart;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 720;
          final cards = [
            _ActionCard(
              icon: Icons.style_outlined,
              title: 'Flashcards',
              detail: 'Recall all ${set.items.length} items',
              primary: true,
              onTap: () => onStart(set.items, false),
            ),
            _ActionCard(
              icon: Icons.quiz_outlined,
              title: 'Practice test',
              detail: '${quizzes.length} multiple-choice questions',
              onTap: quizzes.isEmpty ? null : () => onStart(quizzes, true),
            ),
            _ActionCard(
              icon: Icons.history_rounded,
              title: 'Review due',
              detail: '${due.length} items ready now',
              onTap: due.isEmpty ? null : () => onStart(due, false),
            ),
          ];
          if (!wide) {
            return Column(
              children: cards
                  .map(
                    (card) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: card,
                    ),
                  )
                  .toList(),
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: cards
                .map(
                  (card) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: card,
                    ),
                  ),
                )
                .toList(),
          );
        },
      );

}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.detail,
    this.primary = false,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String detail;
  final bool primary;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = onTap != null;
    final background = primary
        ? theme.colorScheme.secondaryContainer
        : theme.colorScheme.surfaceContainerLow;
    return Material(
      color: enabled
          ? background
          : theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(
                icon,
                color: enabled
                    ? null
                    : theme.colorScheme.onSurface.withValues(alpha: 0.35),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: enabled
                            ? null
                            : theme.colorScheme.onSurface
                                .withValues(alpha: 0.35),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      detail,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: enabled
                            ? theme.colorScheme.onSurfaceVariant
                            : theme.colorScheme.onSurface
                                .withValues(alpha: 0.28),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_rounded,
                size: 19,
                color: enabled
                    ? theme.colorScheme.onSurfaceVariant
                    : theme.colorScheme.onSurface.withValues(alpha: 0.25),
              ),
            ],
          ),
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
    final theme = Theme.of(context);
    final finished = _index >= _items.length;
    final compact = AcatrainLayout.isCompact(context);

    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0,
        title: Text(widget.quiz ? 'Practice test' : 'Flashcards'),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 840),
          child: ListView(
            padding: AcatrainLayout.pagePadding(context),
            children: [
              Text(
                widget.set.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: _items.isEmpty
                          ? 1
                          : (_index / _items.length).clamp(0, 1),
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    finished
                        ? '${_items.length}/${_items.length}'
                        : '${_index + 1}/${_items.length}',
                    style: theme.textTheme.labelLarge,
                  ),
                ],
              ),
              const SizedBox(height: 26),
              AnimatedSwitcher(
                duration: acatrainMediumMotion,
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                layoutBuilder: (currentChild, previousChildren) => Stack(
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
                  ).animate(animation);
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(position: slide, child: child),
                  );
                },
                child: finished
                    ? _FinishedSession(
                        key: const ValueKey('finished'),
                        correct: _correct,
                        total: _items.length,
                        quiz: widget.quiz,
                        missed: _missed.length,
                        onDone: () => Navigator.pop(context),
                        onRetry: _missed.isEmpty ? null : _retryMissed,
                      )
                    : KeyedSubtree(
                        key: ValueKey('item-$_index'),
                        child: widget.quiz
                            ? _QuizCard(
                                item: _items[_index],
                                selected: _selected,
                                saving: _saving,
                                onSelect: (value) =>
                                    setState(() => _selected = value),
                                onContinue: () => _advance(
                                  _selected ==
                                      _items[_index].correctIndex,
                                ),
                              )
                            : _Flashcard(
                                item: _items[_index],
                                revealed: _revealed,
                                saving: _saving,
                                compact: compact,
                                onReveal: () =>
                                    setState(() => _revealed = true),
                                onToggle: () => setState(
                                  () => _revealed = !_revealed,
                                ),
                                onAgain: () => _advance(false),
                                onGotIt: () => _advance(true),
                              ),
                      ),
              ),
              const SizedBox(height: 24),
              Text(
                'Progress is saved on this device. Content updates never interrupt a session.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
    return Column(
      children: [
        Semantics(
          button: true,
          label: revealed ? 'Answer shown' : 'Tap to reveal answer',
          child: Material(
            color: revealed
                ? colors.tertiaryContainer
                : colors.primaryContainer,
            borderRadius: BorderRadius.circular(32),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: saving ? null : onToggle,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: compact ? 300 : 360,
                ),
                child: Padding(
                  padding: EdgeInsets.all(compact ? 24 : 34),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedSwitcher(
                        duration: acatrainFastMotion,
                        child: Text(
                          revealed ? 'ANSWER' : 'RECALL',
                          key: ValueKey(revealed),
                          style: theme.textTheme.labelLarge,
                        ),
                      ),
                      const SizedBox(height: 24),
                      AnimatedSwitcher(
                        duration: acatrainMediumMotion,
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, animation) =>
                            FadeTransition(
                          opacity: animation,
                          child: ScaleTransition(
                            scale: Tween<double>(
                              begin: 0.985,
                              end: 1,
                            ).animate(animation),
                            child: child,
                          ),
                        ),
                        child: Text(
                          revealed ? item.answerText : item.prompt,
                          key: ValueKey(revealed),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Tap card to flip',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        AnimatedSwitcher(
          duration: acatrainFastMotion,
          child: revealed
              ? Row(
                  key: const ValueKey('rating'),
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: saving ? null : onAgain,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Again'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: saving ? null : onGotIt,
                        icon: const Icon(Icons.check_rounded),
                        label: const Text('Got it'),
                      ),
                    ),
                  ],
                )
              : SizedBox(
                  key: const ValueKey('reveal'),
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: saving ? null : onReveal,
                    child: const Text('Show answer'),
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
    required this.selected,
    required this.saving,
    required this.onSelect,
    required this.onContinue,
  });

  final StudyItem item;
  final int? selected;
  final bool saving;
  final ValueChanged<int> onSelect;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          item.prompt,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 24),
        for (var i = 0; i < item.choices.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: selected == null
                  ? colors.surfaceContainerLow
                  : i == item.correctIndex
                      ? colors.tertiaryContainer
                      : i == selected
                          ? colors.errorContainer
                          : colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(22),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: selected != null || saving
                    ? null
                    : () => onSelect(i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 18,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        selected == i
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                      ),
                      const SizedBox(width: 14),
                      Expanded(child: Text(item.choices[i])),
                    ],
                  ),
                ),
              ),
            ),
          ),
        if (selected != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: selected == item.correctIndex
                  ? colors.tertiaryContainer
                  : colors.errorContainer,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selected == item.correctIndex
                      ? 'Correct'
                      : 'Correct answer: ${item.answerText}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(item.explanation),
              ],
            ),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: saving ? null : onContinue,
            child: const Text('Continue'),
          ),
        ],
      ],
    );
  }
}

class _FinishedSession extends StatelessWidget {
  const _FinishedSession({
    super.key,
    required this.correct,
    required this.total,
    required this.quiz,
    required this.missed,
    required this.onDone,
    required this.onRetry,
  });

  final int correct;
  final int total;
  final bool quiz;
  final int missed;
  final VoidCallback onDone;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.task_alt_rounded, size: 42),
          ),
          const SizedBox(height: 20),
          Text(
            'Session complete',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '$correct / $total ${quiz ? 'correct' : 'remembered'}',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onDone,
              child: const Text('Back to learning'),
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onRetry,
                child: Text('Practice $missed missed items'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

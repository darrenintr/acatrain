import 'dart:math';

import 'package:flutter/material.dart';

import 'app_ui.dart';
import 'expressive.dart';
import 'language.dart';
import 'models.dart';
import 'store.dart';

enum StudyGame { match, quickAnswer }

String _key(String value) => value.trim().toLowerCase();

/// Repeated prompts or answers make a matching board ambiguous.
List<StudyItem> matchableItems(List<StudyItem> items) {
  final prompts = <String>{};
  final answers = <String>{};
  return items.where((item) {
    final prompt = _key(item.prompt);
    final answer = _key(item.answerText);
    if (prompts.contains(prompt) || answers.contains(answer)) return false;
    prompts.add(prompt);
    answers.add(answer);
    return true;
  }).toList();
}

/// Flashcards need another answer in the set to make plausible choices.
List<StudyItem> quickAnswerItems(List<StudyItem> items) {
  final answers = items.map((item) => _key(item.answerText)).toSet();
  return items.where((item) {
    if (!item.isQuiz) return answers.length > 1;
    return item.choices.map(_key).toSet().length > 1;
  }).toList();
}

class GamePage extends StatefulWidget {
  const GamePage({
    super.key,
    required this.set,
    required this.store,
    required this.game,
  });

  final StudySet set;
  final AppStore store;
  final StudyGame game;

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  final _random = Random();
  late List<StudyItem> _items;
  late List<List<StudyItem>> _rounds;
  late List<StudyItem> _answers;
  late List<String> _options;
  int _index = 0;
  int _roundIndex = 0;
  int _score = 0;
  int? _promptId;
  int? _answerId;
  int? _selectedOption;
  bool _busy = false;
  bool _mismatch = false;
  final Set<int> _matched = {};
  final Set<String> _mistakes = {};

  bool get _matching => widget.game == StudyGame.match;
  int get _total => _items.length;
  bool get _finished => _index >= _total;

  @override
  void initState() {
    super.initState();
    _restart();
  }

  void _restart() {
    _matched.clear();
    _mistakes.clear();
    _roundIndex = 0;
    _index = 0;
    _items = List.of(
      _matching
          ? matchableItems(widget.set.items)
          : quickAnswerItems(widget.set.items),
    )..shuffle(_random);
    _answers = List.of(_items);
    _rounds = [];
    if (_matching) {
      var offset = 0;
      while (offset < _items.length) {
        final remaining = _items.length - offset;
        final take = remaining == 5 ? 3 : min(4, remaining);
        _rounds.add(_items.sublist(offset, offset + take));
        offset += take;
      }
      _shuffleAnswers();
    } else {
      _prepareOptions();
    }
    _score = 0;
    _promptId = null;
    _answerId = null;
    _selectedOption = null;
    _busy = false;
    _mismatch = false;
  }

  List<StudyItem> get _round => _rounds[_roundIndex];

  void _shuffleAnswers() {
    if (_rounds.isEmpty) return;
    // Shuffle only the answers in the current short round.
    _answers = List.of(_round)..shuffle(_random);
  }

  void _prepareOptions() {
    if (_items.isEmpty || _index >= _items.length) {
      _options = [];
      return;
    }
    final item = _items[_index];
    if (item.isQuiz) {
      final seen = {_key(item.answerText)};
      _options = [
        item.answerText,
        ...item.choices.where((choice) => seen.add(_key(choice))),
      ]..shuffle(_random);
      return;
    }
    final seen = {_key(item.answerText)};
    final distractors =
        widget.set.items
            .map((other) => other.answerText)
            .where((answer) => seen.add(_key(answer)))
            .toList()
          ..shuffle(_random);
    _options = [item.answerText, ...distractors.take(3)]..shuffle(_random);
  }

  Future<void> _chooseMatch(bool prompt, int id) async {
    if (_busy || _matched.contains(id)) return;
    setState(() {
      _mismatch = false;
      if (prompt) {
        _promptId = id;
      } else {
        _answerId = id;
      }
    });
    if (_promptId == null || _answerId == null) return;
    if (_promptId != _answerId) {
      _mistakes.add(_items[_promptId!].id);
      _mistakes.add(_items[_answerId!].id);
      setState(() {
        _mismatch = true;
        _busy = true;
      });
      await Future<void>.delayed(const Duration(milliseconds: 650));
      if (!mounted) return;
      setState(() {
        _promptId = null;
        _answerId = null;
        _mismatch = false;
        _busy = false;
      });
      return;
    }
    final item = _items[id];
    final firstTry = !_mistakes.contains(item.id);
    setState(() => _busy = true);
    await widget.store.record(widget.set, item, firstTry);
    if (!mounted) return;
    setState(() {
      _matched.add(id);
      _index++;
      if (firstTry) _score++;
      _promptId = null;
      _answerId = null;
      _busy = false;
      if (!_finished &&
          _round.every((item) => _matched.contains(_items.indexOf(item)))) {
        _roundIndex++;
        _shuffleAnswers();
      }
    });
  }

  Future<void> _continueQuick() async {
    if (_busy || _selectedOption == null) return;
    final item = _items[_index];
    final correct = _options[_selectedOption!] == item.answerText;
    setState(() => _busy = true);
    await widget.store.record(widget.set, item, correct);
    if (!mounted) return;
    setState(() {
      if (correct) _score++;
      _index++;
      _selectedOption = null;
      _busy = false;
      _prepareOptions();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final title = tr(context, _matching ? 'Match pairs' : 'Quick answers');
    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 840),
            child: Column(
              children: [
                SizedBox(
                  height: 64,
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: tr(context, 'End session'),
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: theme.textTheme.titleMedium),
                            Text(
                              widget.set.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: WavyProgress(
                          value: _total == 0 ? 0 : _index / _total,
                          semanticsLabel: '$_index of $_total',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '$_index / $_total',
                        style: theme.textTheme.labelLarge,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: AcatrainLayout.pagePadding(context),
                    children: [
                      if (_finished)
                        _GameFinished(
                          title: title,
                          score: _score,
                          total: _total,
                          onReplay: () => setState(_restart),
                          onDone: () => Navigator.pop(context),
                        )
                      else if (_matching)
                        _buildMatching(context)
                      else
                        _buildQuick(context),
                      const SizedBox(height: 40),
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

  Widget _buildMatching(BuildContext context) {
    final theme = Theme.of(context);
    final round = _round;
    final roundNumber = _roundIndex + 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          isCantonese(context)
              ? '第 $roundNumber / ${_rounds.length} 回合'
              : 'ROUND $roundNumber OF ${_rounds.length}',
          style: theme.textTheme.labelSmall,
        ),
        const SizedBox(height: 8),
        Text(
          tr(context, 'Connect each question to its answer.'),
          style: theme.textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        Text(
          tr(
            context,
            'Choose one card from each column. Missed pairs are ready to review.',
          ),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Text(
                tr(context, 'Question'),
                style: theme.textTheme.labelLarge,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                tr(context, 'Answer'),
                style: theme.textTheme.labelLarge,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: [
                  for (final item in round)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _GameChoice(
                        text: item.prompt,
                        selected: _promptId == _items.indexOf(item),
                        matched: _matched.contains(_items.indexOf(item)),
                        wrong: _mismatch && _promptId == _items.indexOf(item),
                        onTap: () => _chooseMatch(true, _items.indexOf(item)),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                children: [
                  for (final item in _answers)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _GameChoice(
                        text: item.answerText,
                        selected: _answerId == _items.indexOf(item),
                        matched: _matched.contains(_items.indexOf(item)),
                        wrong: _mismatch && _answerId == _items.indexOf(item),
                        onTap: () => _chooseMatch(false, _items.indexOf(item)),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          _mismatch
              ? tr(context, 'Try another pair')
              : isCantonese(context)
              ? '第一次配對成功：$_score / $_total'
              : 'Matched on the first try: $_score / $_total',
          style: theme.textTheme.bodyMedium?.copyWith(
            color:
                _mismatch
                    ? theme.colorScheme.error
                    : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildQuick(BuildContext context) {
    final theme = Theme.of(context);
    final item = _items[_index];
    final selected = _selectedOption;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          isCantonese(context)
              ? '第 ${_index + 1} / $_total 題'
              : 'QUESTION ${_index + 1} OF $_total',
          style: theme.textTheme.labelSmall,
        ),
        const SizedBox(height: 12),
        Text(item.prompt, style: theme.textTheme.headlineMedium),
        const SizedBox(height: 10),
        Text(
          tr(context, 'Pick the answer that fits best.'),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        for (var i = 0; i < _options.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _GameChoice(
              text: _options[i],
              selected: selected == i,
              matched: selected != null && _options[i] == item.answerText,
              wrong: selected == i && _options[i] != item.answerText,
              onTap:
                  selected == null && !_busy
                      ? () => setState(() => _selectedOption = i)
                      : null,
            ),
          ),
        if (selected != null) ...[
          const SizedBox(height: 8),
          Text(
            _options[selected] == item.answerText
                ? tr(context, 'Correct!')
                : tr(context, 'Take a look at the highlighted answer.'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color:
                  _options[selected] == item.answerText
                      ? theme.colorScheme.primary
                      : theme.colorScheme.error,
            ),
          ),
          if (item.explanation.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(item.explanation, style: theme.textTheme.bodyMedium),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _busy ? null : _continueQuick,
              child: Text(tr(context, 'Continue')),
            ),
          ),
        ],
      ],
    );
  }
}

class _GameChoice extends StatelessWidget {
  const _GameChoice({
    required this.text,
    required this.selected,
    required this.matched,
    required this.wrong,
    required this.onTap,
  });

  final String text;
  final bool selected;
  final bool matched;
  final bool wrong;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final background =
        matched
            ? colors.primaryContainer
            : wrong
            ? colors.errorContainer
            : selected
            ? colors.tertiaryContainer
            : colors.surfaceContainerLow;
    final foreground =
        matched
            ? colors.onPrimaryContainer
            : wrong
            ? colors.onErrorContainer
            : selected
            ? colors.onTertiaryContainer
            : colors.onSurface;
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(AcatrainRadii.lPlus),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: matched ? null : onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 72),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    text,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight:
                          selected || matched ? acatrainWeight(650) : null,
                      color: foreground,
                    ),
                  ),
                ),
                if (matched) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.check_rounded, size: 18, color: foreground),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GameFinished extends StatelessWidget {
  const _GameFinished({
    required this.title,
    required this.score,
    required this.total,
    required this.onReplay,
    required this.onDone,
  });

  final String title;
  final int score;
  final int total;
  final VoidCallback onReplay;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          ExpressiveBadge(
            shape: ExpressiveShape.cookie12,
            size: 180,
            color: colors.primaryContainer,
            child: Text(
              '$score/$total',
              style: theme.textTheme.headlineLarge?.copyWith(
                color: colors.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            tr(context, 'Game complete'),
            style: theme.textTheme.headlineLarge,
          ),
          const SizedBox(height: 8),
          Text(
            isCantonese(context)
                ? '$title：$score / $total 題第一次答啱。再玩一次鞏固記憶！'
                : '$title: $score of $total right on the first try. Play again to make them stick.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onReplay,
              icon: const Icon(Icons.replay_rounded),
              label: Text(tr(context, 'Play again')),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: onDone,
              child: Text(tr(context, 'Back to learning')),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'models.dart';
import 'store.dart';

class SetPage extends StatelessWidget {
  const SetPage({super.key, required this.set, required this.store});
  final StudySet set;
  final AppStore store;
  void _start(BuildContext context, List<StudyItem> items, bool quiz) {
    Navigator.push(context, MaterialPageRoute<void>(builder: (_) =>
      StudyPage(set: set, items: items, quiz: quiz, store: store)));
  }
  @override
  Widget build(BuildContext context) {
    final quizzes = set.items.where((i) => i.isQuiz).toList();
    final due = set.items.where((i) {
      final state = store.progress[i.key(set.id)];
      return state == null || !state.dueAt.isAfter(DateTime.now());
    }).toList();
    return Scaffold(appBar: AppBar(title: Text(set.subject)), body: Center(
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 820),
        child: ListView(padding: const EdgeInsets.all(24), children: [
          Text(set.title, style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 12), Text(set.description),
          const SizedBox(height: 24),
          Wrap(spacing: 12, runSpacing: 12, children: [
            FilledButton.icon(onPressed: () => _start(context, set.items, false),
              icon: const Icon(Icons.style_outlined), label: Text('Flashcards (${set.items.length})')),
            OutlinedButton.icon(onPressed: quizzes.isEmpty ? null : () => _start(context, quizzes, true),
              icon: const Icon(Icons.quiz_outlined), label: Text('Test (${quizzes.length})')),
            OutlinedButton.icon(onPressed: due.isEmpty ? null : () => _start(context, due, false),
              icon: const Icon(Icons.history), label: Text('Review due (${due.length})')),
          ]),
          const SizedBox(height: 32),
          Text('Inside this set', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          ...set.items.map((item) => Card(child: ListTile(
            leading: Icon(item.isQuiz ? Icons.quiz_outlined : Icons.style_outlined),
            title: Text(item.prompt), subtitle: Text(item.isQuiz ? 'Multiple choice' : 'Flashcard'),
          ))),
        ]),
      ),
    ));
  }
}

class StudyPage extends StatefulWidget {
  const StudyPage({super.key, required this.set, required this.items,
    required this.quiz, required this.store});
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
  int _index = 0, _correct = 0;
  int? _selected;
  bool _revealed = false, _saving = false;
  @override
  void initState() { super.initState(); _items = List.of(widget.items); }
  Future<void> _advance(bool correct) async {
    if (_saving) return;
    setState(() => _saving = true);
    final item = _items[_index];
    await widget.store.record(widget.set, item, correct);
    if (!mounted) return;
    setState(() {
      if (correct) { _correct++; } else { _missed.add(item); }
      _index++; _selected = null; _revealed = false; _saving = false;
    });
  }
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final finished = _index >= _items.length;
    return Scaffold(
      appBar: AppBar(title: Text(widget.quiz ? 'Practice test' : 'Flashcards')),
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(padding: const EdgeInsets.all(24), children: [
          Text(widget.set.title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 16),
          LinearProgressIndicator(value: _items.isEmpty ? 1 : _index / _items.length,
            minHeight: 8, borderRadius: BorderRadius.circular(20)),
          const SizedBox(height: 24),
          if (finished) ...[
            const Icon(Icons.task_alt, size: 64), const SizedBox(height: 20),
            Text('Session complete', textAlign: TextAlign.center, style: theme.textTheme.headlineMedium),
            const SizedBox(height: 12),
            Text('$_correct / ${_items.length} ${widget.quiz ? 'correct' : 'remembered'}',
              textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
            const SizedBox(height: 24),
            FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Back to learning')),
            if (_missed.isNotEmpty) OutlinedButton(onPressed: () => setState(() {
              _items = List.of(_missed); _missed.clear(); _index = 0; _correct = 0;
            }), child: Text('Practice ${_missed.length} missed items')),
          ] else ...[
            Text('${_index + 1} of ${_items.length}', style: theme.textTheme.labelLarge),
            const SizedBox(height: 16),
            if (!widget.quiz) ...[
              Semantics(button: true, label: _revealed ? 'Answer shown' : 'Tap to reveal answer',
                child: Card(color: _revealed ? colors.tertiaryContainer : colors.primaryContainer,
                  clipBehavior: Clip.antiAlias, child: InkWell(
                    onTap: _saving ? null : () => setState(() => _revealed = !_revealed),
                    child: ConstrainedBox(constraints: const BoxConstraints(minHeight: 280),
                      child: Padding(padding: const EdgeInsets.all(28), child: Column(
                        mainAxisAlignment: MainAxisAlignment.center, children: [
                          Text(_revealed ? 'ANSWER' : 'RECALL', style: theme.textTheme.labelLarge),
                          const SizedBox(height: 24),
                          AnimatedSwitcher(duration: const Duration(milliseconds: 200),
                            child: Text(_revealed ? _items[_index].answerText : _items[_index].prompt,
                              key: ValueKey('$_index:$_revealed'), textAlign: TextAlign.center,
                              style: theme.textTheme.headlineSmall)),
                          const SizedBox(height: 24), const Text('Tap card to flip'),
                        ])),
                    ),
                  )),
              ),
              const SizedBox(height: 24),
              if (!_revealed) FilledButton(onPressed: () => setState(() => _revealed = true),
                child: const Text('Show answer'))
              else Row(children: [
                Expanded(child: OutlinedButton(onPressed: _saving ? null : () => _advance(false),
                  child: const Text('Again'))), const SizedBox(width: 12),
                Expanded(child: FilledButton(onPressed: _saving ? null : () => _advance(true),
                  child: const Text('Got it'))),
              ]),
            ] else ...[
              Text(_items[_index].prompt, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 24),
              for (var i = 0; i < _items[_index].choices.length; i++)
                Padding(padding: const EdgeInsets.only(bottom: 10), child: Card(
                  color: _selected == null ? colors.surfaceContainerLow :
                    i == _items[_index].correctIndex ? colors.tertiaryContainer :
                    i == _selected ? colors.errorContainer : colors.surfaceContainerLow,
                  child: ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    leading: Icon(_selected == i ? Icons.radio_button_checked : Icons.radio_button_off),
                    title: Text(_items[_index].choices[i]),
                    onTap: _selected != null ? null : () => setState(() => _selected = i)),
                )),
              if (_selected != null) ...[
                const SizedBox(height: 12),
                Text(_selected == _items[_index].correctIndex ? 'Correct' :
                  'Correct answer: ${_items[_index].answerText}', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8), Text(_items[_index].explanation),
                const SizedBox(height: 24),
                FilledButton(onPressed: _saving ? null : () =>
                  _advance(_selected == _items[_index].correctIndex), child: const Text('Continue')),
              ],
            ],
          ],
          const SizedBox(height: 24),
          Text('Progress is saved on this device. Content updates never interrupt a session.',
            style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
        ]),
      )),
    );
  }
}

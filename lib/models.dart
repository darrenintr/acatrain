import 'dart:convert';

const appBuild = 1;
const maxContentBytes = 128 * 1024;
final _id = RegExp(r'^[a-z0-9][a-z0-9_-]{0,63}$');
void _check(bool condition, String message) {
  if (!condition) throw FormatException(message);
}
String _text(dynamic value, String field, [int max = 8000]) {
  _check(value is String && value.trim().isNotEmpty && value.length <= max,
      'Invalid $field');
  return value as String;
}

class StudyItem {
  const StudyItem({required this.id, required this.revision, required this.type,
    required this.prompt, this.answer = '', this.choices = const [],
    this.correctIndex = 0, this.explanation = ''});
  final String id, type, prompt, answer, explanation;
  final int revision, correctIndex;
  final List<String> choices;
  bool get isQuiz => type == 'mcq';
  String get answerText => isQuiz ? choices[correctIndex] : answer;
  String key(String setId) => '$setId/$id@$revision';
  factory StudyItem.fromJson(Map<String, dynamic> json) {
    final id = _text(json['id'], 'item ID', 64);
    _check(_id.hasMatch(id), 'Invalid item ID');
    _check(json['revision'] is int && json['revision'] >= 1 &&
        json['revision'] <= 1000000, 'Invalid item revision');
    final type = json['type'];
    _check(type == 'flashcard' || type == 'mcq', 'Unsupported item type');
    final prompt = _text(json['prompt'], 'prompt');
    if (type == 'flashcard') {
      return StudyItem(id: id, revision: json['revision'], type: type,
          prompt: prompt, answer: _text(json['answer'], 'answer'));
    }
    _check(json['choices'] is List && json['choices'].length >= 2 &&
        json['choices'].length <= 6, 'Invalid choices');
    final choices = (json['choices'] as List)
        .map((value) => _text(value, 'choice', 2000)).toList(growable: false);
    _check(json['correctIndex'] is int && json['correctIndex'] >= 0 &&
        json['correctIndex'] < choices.length, 'Invalid correct answer');
    return StudyItem(id: id, revision: json['revision'], type: type,
        prompt: prompt, choices: List.unmodifiable(choices),
        correctIndex: json['correctIndex'],
        explanation: _text(json['explanation'], 'explanation'));
  }
}

class StudySet {
  const StudySet({required this.id, required this.title, required this.subject,
    required this.description, required this.items});
  final String id, title, subject, description;
  final List<StudyItem> items;
  factory StudySet.fromJson(Map<String, dynamic> json) {
    final id = _text(json['id'], 'set ID', 64);
    _check(_id.hasMatch(id), 'Invalid set ID');
    _check(json['description'] is String && json['description'].length <= 2000,
        'Invalid description');
    _check(json['items'] is List && json['items'].isNotEmpty,
        'A study set must have items');
    final items = (json['items'] as List)
        .map((item) => StudyItem.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList(growable: false);
    _check(items.map((i) => i.id).toSet().length == items.length,
        'Duplicate item IDs');
    return StudySet(id: id, title: _text(json['title'], 'title', 160),
        subject: _text(json['subject'], 'subject', 60),
        description: json['description'], items: List.unmodifiable(items));
  }
}

class ContentBundle {
  const ContentBundle(this.sets);
  final List<StudySet> sets;
  factory ContentBundle.parse(String source) {
    _check(utf8.encode(source).length <= maxContentBytes, 'Content is too large');
    final json = jsonDecode(source) as Map<String, dynamic>;
    _check(json['schemaVersion'] == 1 && json['minAppBuild'] == appBuild,
        'This content needs a different app version');
    _check(json['sets'] is List && json['sets'].isNotEmpty &&
        json['sets'].length <= 30, 'Invalid study sets');
    final sets = (json['sets'] as List)
        .map((set) => StudySet.fromJson(Map<String, dynamic>.from(set as Map)))
        .toList(growable: false);
    _check(sets.map((s) => s.id).toSet().length == sets.length,
        'Duplicate set IDs');
    _check(sets.fold<int>(0, (n, s) => n + s.items.length) <= 200,
        'Too many study items');
    return ContentBundle(List.unmodifiable(sets));
  }
}

class ReviewState {
  const ReviewState({required this.box, required this.updatedAt,
    required this.dueAt, required this.wrong});
  final int box;
  final DateTime updatedAt, dueAt;
  final bool wrong;
  Map<String, dynamic> toJson() => {'box': box,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'dueAt': dueAt.toUtc().toIso8601String(), 'wrong': wrong};
  factory ReviewState.fromJson(Map<String, dynamic> json) {
    _check(json['box'] is int && json['box'] >= 0 && json['box'] <= 5 &&
        json['wrong'] is bool, 'Invalid review state');
    return ReviewState(box: json['box'], wrong: json['wrong'],
        updatedAt: DateTime.parse(json['updatedAt']).toUtc(),
        dueAt: DateTime.parse(json['dueAt']).toUtc());
  }
}
ReviewState nextReview(ReviewState? previous, bool correct, DateTime now) {
  var at = now.toUtc();
  if (previous != null && !at.isAfter(previous.updatedAt)) {
    at = previous.updatedAt.add(const Duration(milliseconds: 1));
  }
  final box = correct ? ((previous?.box ?? 0) + 1).clamp(1, 5).toInt() : 0;
  const days = [0, 1, 3, 7, 14, 30];
  return ReviewState(box: box, updatedAt: at, wrong: !correct,
      dueAt: at.add(correct ? Duration(days: days[box]) :
          const Duration(minutes: 10)));
}
Map<String, ReviewState> decodeProgress(dynamic value) {
  final map = Map<String, dynamic>.from(value as Map);
  return map.map((key, value) => MapEntry(key,
      ReviewState.fromJson(Map<String, dynamic>.from(value as Map))));
}
Map<String, ReviewState> mergeProgress(Map<String, ReviewState> a,
    Map<String, ReviewState> b) {
  final result = Map<String, ReviewState>.of(a);
  for (final entry in b.entries) {
    final old = result[entry.key];
    if (old == null || entry.value.updatedAt.isAfter(old.updatedAt) ||
        (entry.value.updatedAt == old.updatedAt &&
          jsonEncode(entry.value.toJson()).compareTo(jsonEncode(old.toJson())) > 0)) {
      result[entry.key] = entry.value;
    }
  }
  return result;
}

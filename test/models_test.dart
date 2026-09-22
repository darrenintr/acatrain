import 'dart:io';
import 'package:acatrain/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bundled content has three original study sets and 19 items', () {
    final bundle = ContentBundle.parse(File('assets/seed.json').readAsStringSync());
    expect(bundle.sets.length, 3);
    expect(bundle.sets.fold<int>(0, (n, s) => n + s.items.length), 19);
  });
  test('unknown schema and unsupported renderer are rejected', () {
    final source = File('assets/seed.json').readAsStringSync();
    expect(() => ContentBundle.parse(source.replaceFirst('"schemaVersion": 1', '"schemaVersion": 8')), throwsFormatException);
    expect(() => ContentBundle.parse(source.replaceFirst('"flashcard"', '"executable"')), throwsFormatException);
  });
  test('review intervals grow and wrong answers become due in ten minutes', () {
    final now = DateTime.utc(2026, 9, 22);
    final first = nextReview(null, true, now);
    expect(first.box, 1);
    expect(first.dueAt, now.add(const Duration(days: 1)));
    final second = nextReview(first, true, now.add(const Duration(days: 1)));
    expect(second.box, 2);
    expect(second.dueAt, now.add(const Duration(days: 4)));
    final wrong = nextReview(second, false, now.add(const Duration(days: 2)));
    expect(wrong.box, 0); expect(wrong.wrong, true);
    expect(wrong.dueAt, now.add(const Duration(days: 2, minutes: 10)));
  });
  test('concurrent merges are deterministic and never delete local-only items', () {
    final now = DateTime.utc(2026);
    final a = nextReview(null, true, now);
    final b = nextReview(null, false, now);
    final forward = mergeProgress({'a': a}, {'a': b, 'b': b});
    final reverse = mergeProgress({'a': b, 'b': b}, {'a': a});
    expect(forward.map((k, v) => MapEntry(k, v.toJson())), reverse.map((k, v) => MapEntry(k, v.toJson())));
    expect(forward.length, 2);
  });
  test('revision bump gives corrected content a fresh progress identity', () {
    const item = StudyItem(id: 'card', revision: 2, type: 'flashcard', prompt: 'Q', answer: 'A');
    expect(item.key('set'), 'set/card@2');
  });
}

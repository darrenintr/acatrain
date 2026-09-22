import 'dart:io';
import 'package:acatrain/main.dart';
import 'package:acatrain/store.dart';
import 'package:acatrain/study_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Future<AppStore> store() async {
    SharedPreferences.setMockInitialValues({});
    final state = AppStore(await SharedPreferences.getInstance());
    await state.load(seed: File('assets/seed.json').readAsStringSync()); return state;
  }
  testWidgets('mobile and desktop shells render without overflow', (tester) async {
    final state = await store();
    for (final size in [const Size(390, 844), const Size(1440, 960)]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(AcatrainApp(store: state)); await tester.pumpAndSettle();
      expect(find.text('acatrain'), findsOneWidget);
      expect(find.text('Make room for learning.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    await tester.binding.setSurfaceSize(null);
    await tester.pumpWidget(const SizedBox()); state.dispose();
  });
  testWidgets('flashcard reveal and rating save progress', (tester) async {
    final state = await store(); final set = state.bundle.sets.first;
    await tester.pumpWidget(MaterialApp(home: StudyPage(set: set,
      items: [set.items.first], quiz: false, store: state)));
    await tester.ensureVisible(find.text('Show answer'));
    await tester.tap(find.text('Show answer')); await tester.pumpAndSettle();
    expect(find.text(set.items.first.answerText), findsOneWidget);
    await tester.ensureVisible(find.text('Got it'));
    await tester.tap(find.text('Got it')); await tester.pumpAndSettle();
    expect(find.text('Session complete'), findsOneWidget);
    expect(state.progress[set.items.first.key(set.id)]?.box, 1);
    await tester.pumpWidget(const SizedBox()); state.dispose();
  });
  testWidgets('quiz provides explanation and stores a wrong answer', (tester) async {
    final state = await store(); final set = state.bundle.sets.first;
    final item = set.items.firstWhere((i) => i.isQuiz);
    await tester.pumpWidget(MaterialApp(home: StudyPage(set: set,
      items: [item], quiz: true, store: state)));
    await tester.tap(find.text(item.choices.first)); await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text(item.explanation), 200,
      scrollable: find.byType(Scrollable));
    await tester.pumpAndSettle();
    expect(find.text(item.explanation), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Continue'), 150,
      scrollable: find.byType(Scrollable));
    await tester.tap(find.text('Continue')); await tester.pumpAndSettle();
    expect(state.isWrong(set, item), true);
    expect(find.text('0 / 1 correct'), findsOneWidget);
    await tester.pumpWidget(const SizedBox()); state.dispose();
  });
}

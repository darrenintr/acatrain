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
    await state.load(seed: File('assets/seed.json').readAsStringSync());
    return state;
  }

  testWidgets('mobile and desktop shells render without overflow', (
    tester,
  ) async {
    final state = await store();
    for (final size in [
      const Size(360, 740),
      const Size(768, 1024),
      const Size(1440, 960),
    ]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(AcatrainApp(store: state));
      await tester.pumpAndSettle();
      expect(find.text('acatrain'), findsOneWidget);
      expect(find.textContaining('Make room'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    await tester.binding.setSurfaceSize(null);
    await tester.pumpWidget(const SizedBox());
    state.dispose();
  });
  testWidgets('settings grid adapts and Cantonese preference updates the UI', (
    tester,
  ) async {
    final state = await store();
    await tester.binding.setSurfaceSize(const Size(360, 740));
    await tester.pumpWidget(AcatrainApp(store: state));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    final phoneAccountY = tester.getTopLeft(find.text('Account & progress')).dy;
    final phoneAppearanceY = tester.getTopLeft(find.text('Appearance')).dy;
    expect(phoneAppearanceY, greaterThan(phoneAccountY));
    await tester.scrollUntilVisible(
      find.byType(DropdownButtonFormField<String>),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cantonese (繁體中文)').last);
    await tester.pumpAndSettle();
    expect(state.languageCode, 'zh_HK');
    expect(find.text('設定'), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.binding.setSurfaceSize(const Size(1440, 960));
    await tester.pumpAndSettle();
    final desktopAccountY = tester.getTopLeft(find.text('帳戶同進度')).dy;
    final desktopAppearanceY = tester.getTopLeft(find.text('外觀').first).dy;
    expect((desktopAccountY - desktopAppearanceY).abs(), lessThan(25));
    expect(tester.takeException(), isNull);
    await tester.binding.setSurfaceSize(null);
    await tester.pumpWidget(const SizedBox());
    state.dispose();
  });
  testWidgets('set page adapts across phone, tablet and desktop', (
    tester,
  ) async {
    final state = await store();
    final set = state.bundle.sets.first;
    for (final size in [
      const Size(360, 740),
      const Size(768, 1024),
      const Size(1440, 960),
    ]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        MaterialApp(home: SetPage(set: set, store: state)),
      );
      await tester.pumpAndSettle();
      expect(find.text(set.title), findsOneWidget);
      expect(find.text('Flashcards'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    await tester.binding.setSurfaceSize(null);
    await tester.pumpWidget(const SizedBox());
    state.dispose();
  });

  testWidgets('flashcard reveal and rating save progress', (tester) async {
    final state = await store();
    final set = state.bundle.sets.first;
    await tester.pumpWidget(
      MaterialApp(
        home: StudyPage(
          set: set,
          items: [set.items.first],
          quiz: false,
          store: state,
        ),
      ),
    );
    await tester.ensureVisible(find.text('Show answer'));
    await tester.tap(find.text('Show answer'));
    await tester.pumpAndSettle();
    expect(find.text(set.items.first.answerText), findsOneWidget);
    await tester.ensureVisible(find.text('Got it'));
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();
    expect(find.text('Session complete'), findsOneWidget);
    expect(state.progress[set.items.first.key(set.id)]?.box, 1);
    await tester.pumpWidget(const SizedBox());
    state.dispose();
  });
  testWidgets('quiz provides explanation and stores a wrong answer', (
    tester,
  ) async {
    final state = await store();
    final set = state.bundle.sets.first;
    final item = set.items.firstWhere((i) => i.isQuiz);
    await tester.pumpWidget(
      MaterialApp(
        home: StudyPage(set: set, items: [item], quiz: true, store: state),
      ),
    );
    await tester.tap(find.text(item.choices.first));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text(item.explanation),
      200,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();
    expect(find.text(item.explanation), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Continue'),
      150,
      scrollable: find.byType(Scrollable),
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(state.isWrong(set, item), true);
    expect(find.text('0/1', findRichText: true), findsOneWidget);
    expect(find.text('correct'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    state.dispose();
  });
}

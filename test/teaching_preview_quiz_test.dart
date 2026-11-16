import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/components/teaching_preview_quiz.dart';
import 'package:gradeflow/teaching_preview.dart';

void main() {
  testWidgets('new quiz starts blank and accepts marks without later reset',
      (tester) async {
    final book = PreviewQuizBook();
    addTearDown(book.dispose);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body:
                PreviewQuizPanel(book: book, students: const {'s1': 'Alex'}))));
    await tester.tap(find.text('New demo quiz'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, 'Quiz name'), 'Chapter check');
    await tester.enterText(
        find.widgetWithText(TextField, 'Maximum marks'), '40');
    await tester.tap(find.text('Create quiz'));
    await tester.pump();
    await tester.enterText(find.byKey(const ValueKey('quiz-score-s1')), '30');
    await tester.pump(const Duration(milliseconds: 500));
    expect(book.selected.name, 'Chapter check');
    expect(book.mark('s1'), 30);
    expect(find.text('75.0%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('actual GradeFlow normalization excludes blank and invalid drafts', () {
    final book = PreviewQuizBook();
    addTearDown(book.dispose);
    expect(book.percentage('s1'), isNull);
    book.enter('s1', '16');
    expect(book.percentage('s1'), 80);
    book.enter('s1', '0');
    expect(book.percentage('s1'), 0);
    book.enter('s1', '21');
    expect(book.error('s1'), isNotNull);
    expect(book.percentage('s1'), isNull);
    book.enter('s1', 'NaN');
    expect(book.percentage('s1'), isNull);
    book.enter('s1', '');
    expect(book.error('s1'), isNull);
    expect(book.entered(['s1']), 0);
  });

  test('assessment selection isolates marks, including newly created quizzes',
      () {
    final book = PreviewQuizBook();
    addTearDown(book.dispose);
    final first = book.selectedId;
    book.enter('s1', '16');
    book.select(book.items[1].gradeItemId);
    expect(book.mark('s1'), isNull);
    book.enter('s1', '5');
    expect(book.percentage('s1'), 50);
    book.add('Chapter check', 40);
    expect(book.mark('s1'), isNull);
    book.enter('s1', '30');
    expect(book.percentage('s1'), 75);
    book.select(first);
    expect(book.mark('s1'), 16);
    expect(() => book.add('Bad maximum', 0), throwsArgumentError);
  });

  testWidgets(
      'Enter advances and marks survive closing, student selection and Finish',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 1300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const TeachingPreview());
    await tester.tap(find.text('Start class'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'Quiz scores'));
    await tester.pumpAndSettle();
    final alex = find.byKey(const ValueKey('quiz-score-s1'));
    await tester.enterText(alex, '16');
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();
    expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('quiz-score-s2')))
            .focusNode!
            .hasFocus,
        isTrue);
    expect(find.text('80.0%'), findsOneWidget);
    await tester.tap(find.byTooltip('Close panel'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('student-s1')));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(alex).controller!.text, '16');
    await tester.enterText(alex, '21');
    await tester.pump();
    expect(find.text('Enter 0–20'), findsOneWidget);
    await tester.enterText(alex, '0');
    await tester.pump();
    expect(find.text('0.0%'), findsOneWidget);
    await tester.tap(find.byTooltip('Close panel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finish class'));
    await tester.pumpAndSettle();
    expect(
        find.textContaining('Food webs quiz: 1 of 12 marks'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/teaching_preview.dart';
import 'package:gradeflow/components/teaching_preview_desktop.dart';

void main() {
  testWidgets('desktop calendar and reminders survive navigating to class',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const TeachingPreview());
    await tester.enterText(
        find.widgetWithText(TextField, 'Add a reminder'), 'Bring lab cards');
    await tester.tap(find.text('Add reminder'));
    await tester.pumpAndSettle();
    expect(find.text('Bring lab cards'), findsOneWidget);
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Bring lab cards'));
    await tester.pumpAndSettle();
    final book = tester
        .widget<TeachingPreviewDesktop>(find.byType(TeachingPreviewDesktop))
        .book;
    expect(book.reminders.last.done, isTrue);
    await tester.tap(find.byTooltip('Next month'));
    await tester.pumpAndSettle();
    final next = book.month;
    await tester
        .tap(find.byKey(ValueKey('calendar-${next.year}-${next.month}-1')));
    await tester.pumpAndSettle();
    expect(book.selected, DateTime(next.year, next.month, 1));
    await tester.tap(find.text('Classroom'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(book.selected, DateTime(next.year, next.month, 1));
    expect(book.reminders.last.done, isTrue);
    expect(find.text('Bring lab cards'), findsOneWidget);
    await tester.tap(find.text('Back to today'));
    await tester.pumpAndSettle();
    expect(DateUtils.isSameDay(book.selected, DateTime.now()), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Start menu opens timer and returns to narrow teacher desktop',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const TeachingPreview());
    await tester.tap(find.byTooltip('Start menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Focus timer').last);
    await tester.pumpAndSettle();
    expect(find.text('A moment to think'), findsOneWidget);
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Calendar'));
    await tester.pumpAndSettle();
    expect(find.byType(TeachingPreviewDesktop), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

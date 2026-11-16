import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/teaching_preview.dart';
import 'package:gradeflow/components/teaching_preview_room.dart';

void main() {
  for (final width in [390.0, 1400.0]) {
    testWidgets('bottom tools preserve room and student panel stays right at $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const TeachingPreview());
      await tester.ensureVisible(find.text('Start class'));
      await tester.tap(find.text('Start class'));
      await tester.pumpAndSettle();

      final room = find.byType(TeachingPreviewRoom);
      final roomSize = tester.getSize(room);
      final seats =
          List<String?>.of(tester.widget<TeachingPreviewRoom>(room).seats);

      final tools = find.widgetWithText(ActionChip, 'Class tools');
      tester.widget<ActionChip>(tools).onPressed!();
      await tester.pumpAndSettle();

      final sheet = find.byKey(const ValueKey('class-tools'));
      final sheetRect = tester.getRect(sheet);
      expect(sheetRect.width, width);
      expect(sheetRect.height, lessThanOrEqualTo(320));
      expect(sheetRect.height, greaterThanOrEqualTo(220));
      expect(tester.getSize(room), roomSize);
      expect(tester.widget<TeachingPreviewRoom>(room).seats, seats);

      tester.widget<TeachingPreviewRoom>(room).onStudent('s1');
      await tester.pump(const Duration(milliseconds: 100));
      expect(sheet, findsNothing);
      await tester.pumpAndSettle();

      final studentPanel = find.byKey(const ValueKey('student'));
      expect(studentPanel, findsOneWidget);
      expect(tester.getRect(studentPanel).right, width);
      expect(tester.getSize(studentPanel).width, lessThanOrEqualTo(340));

      tester.widget<ActionChip>(tools).onPressed!();
      await tester.pump(const Duration(milliseconds: 100));
      expect(studentPanel, findsNothing);
      await tester.pumpAndSettle();
      expect(sheet, findsOneWidget);

      await tester.tap(find.byTooltip('Dark mode'));
      await tester.pumpAndSettle();
      expect(Theme.of(tester.element(sheet)).brightness, Brightness.dark);

      await tester.tap(find.byTooltip('Close class tools'));
      await tester.pumpAndSettle();
      expect(sheet, findsNothing);
      expect(tester.getSize(room), roomSize);

      tester.widget<TeachingPreviewRoom>(room).onStudent('s1');
      await tester.pumpAndSettle();
      final barrier = find.byKey(const ValueKey('classroom-layer-dismiss'));
      await tester.tapAt(tester.getTopLeft(barrier) + const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(studentPanel, findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('presentation expands the room and keeps theme controls',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const TeachingPreview());
    await tester.tap(find.text('Start class'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ActionChip, 'Present'));
    await tester.pumpAndSettle();

    final room = find.byType(TeachingPreviewRoom);
    expect(room, findsOneWidget);
    expect(tester.getSize(room).width, greaterThan(1300));
    expect(find.byTooltip('Dark mode'), findsOneWidget);
    expect(find.text('Exit presentation'), findsOneWidget);

    await tester.tap(find.byTooltip('Dark mode'));
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(room)).brightness, Brightness.dark);
    expect(tester.takeException(), isNull);
  });

}

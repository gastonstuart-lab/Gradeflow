import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/teaching_preview.dart';
import 'package:gradeflow/components/teaching_preview_room.dart';

void main() {
  for (final width in [390.0, 1100.0, 1536.0]) {
    testWidgets('secondary area never covers the room at $width', (tester) async {
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
      final seats = List<String?>.of(tester.widget<TeachingPreviewRoom>(room).seats);
      final tools = find.widgetWithText(ActionChip, 'Class tools');
      final openTools = tester.widget<ActionChip>(tools).onPressed!;
      openTools();
      await tester.pumpAndSettle();
      final sheet = find.byKey(const ValueKey('class-tools'));
      final roomSpace = find.byKey(const ValueKey('classroom-room-space'));
      final panelSpace = find.byKey(const ValueKey('classroom-secondary-space'));
      void expectSeparateSpaces() {
        expect(tester.getRect(roomSpace).overlaps(tester.getRect(panelSpace)), isFalse);
      }
      expectSeparateSpaces();
      if (width >= 1360) {
        expect(tester.getRect(sheet).right, width);
        expect(tester.getSize(sheet).width, 340);
      } else {
        expect(tester.getRect(sheet).top, tester.getRect(roomSpace).bottom);
      }
      expect(tester.widget<TeachingPreviewRoom>(room).seats, seats);
      tester.widget<TeachingPreviewRoom>(room).onStudent('s1');
      await tester.pump(const Duration(milliseconds: 100));
      expect(sheet, findsNothing);
      expect(find.byTooltip('Close panel'), findsOneWidget);
      await tester.pumpAndSettle();
      openTools();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byTooltip('Close panel'), findsNothing);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Dark mode'));
      await tester.pumpAndSettle();
      expect(Theme.of(tester.element(sheet)).brightness, Brightness.dark);
      await tester.tap(find.byTooltip('Close class tools'));
      await tester.pumpAndSettle();
      expect(sheet, findsNothing);
      expect(tester.getSize(room), roomSize);
      openTools();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Close class tools'));
      await tester.pumpAndSettle();
      expect(sheet, findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}

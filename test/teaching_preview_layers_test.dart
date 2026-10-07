import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/teaching_preview.dart';
import 'package:gradeflow/components/teaching_preview_room.dart';

void main() {
  for (final width in [390.0, 1400.0]) {
    testWidgets('one right overlay preserves room at $width', (tester) async {
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
      expect(tester.getRect(sheet).right, width);
      expect(tester.getSize(sheet).width, lessThanOrEqualTo(340));
      expect(tester.getSize(room), roomSize);
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
      final barrier = find.byKey(const ValueKey('classroom-layer-dismiss'));
      await tester.tapAt(tester.getTopLeft(barrier) + const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(sheet, findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}


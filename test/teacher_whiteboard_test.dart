import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/components/teacher_whiteboard.dart';

void main() {
  test('teacher whiteboard controller supports stroke lifecycle and clear', () {
    final controller = TeacherWhiteboardController();

    expect(controller.isEmpty, isTrue);
    expect(controller.canUndo, isFalse);

    controller.startStroke(
      point: const Offset(24, 24),
      color: Colors.white,
      width: 4,
    );
    controller.appendPoint(const Offset(48, 52));
    controller.endStroke();

    expect(controller.strokeCount, 1);
    expect(controller.canUndo, isTrue);

    controller.undo();
    expect(controller.isEmpty, isTrue);

    controller.startStroke(
      point: const Offset(12, 12),
      color: Colors.amber,
      width: 6,
    );
    controller.endStroke();
    controller.clear();

    expect(controller.isEmpty, isTrue);
    expect(controller.canUndo, isFalse);
  });

  testWidgets('whiteboard workspace can clear existing strokes',
      (tester) async {
    final controller = TeacherWhiteboardController();
    controller.startStroke(
      point: const Offset(16, 16),
      color: Colors.white,
      width: 4,
    );
    controller.endStroke();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TeacherWhiteboardWorkspace(
            controller: controller,
            compact: true,
          ),
        ),
      ),
    );

    expect(find.text('1 stroke'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Clear'));
    await tester.pumpAndSettle();

    expect(controller.isEmpty, isTrue);
    expect(find.text('Tap and draw'), findsOneWidget);
  });

  testWidgets('whiteboard workspace forwards fullscreen action',
      (tester) async {
    var openCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TeacherWhiteboardWorkspace(
            onOpenFullscreen: () => openCount++,
            compact: true,
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.open_in_full_rounded));
    await tester.pumpAndSettle();

    expect(openCount, 1);
  });
}

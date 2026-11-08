import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/components/seating/seating_canvas.dart';
import 'package:gradeflow/models/seating_layout.dart';

SeatingLayout _room() {
  final now = DateTime(2026, 11, 9);
  return SeatingLayout(
    layoutId: 'preview-layout',
    classId: 'synthetic-class',
    name: 'Synthetic test',
    canvasWidth: 1200,
    canvasHeight: 800,
    tables: [
      SeatingTable(
        tableId: 'table-a',
        type: SeatingTableType.rectangular,
        label: 'Test table',
        x: 400,
        y: 300,
        seatCount: 0,
        width: 180,
        height: 90,
      ),
    ],
    seats: [],
    createdAt: now,
    updatedAt: now,
  );
}

Future<void> _mount(
  WidgetTester tester, {
  required TransformationController transform,
  required ValueChanged<SeatingTable> onCommit,
  bool selected = false,
}) async {
  tester.view.physicalSize = const Size(1600, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SeatingCanvas(
        layout: _room(),
        studentsById: const {},
        designMode: true,
        interactive: true,
        presentationMode: false,
        premiumAppearance: true,
        simplifiedArrange: true,
        plannerV2: true,
        selectedTableId: selected ? 'table-a' : null,
        transformationController: transform,
        onPlannerV2Commit: onCommit,
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('V2 drag previews continuously and commits once on release',
      (tester) async {
    final controller = TransformationController();
    addTearDown(controller.dispose);
    final commits = <SeatingTable>[];
    await _mount(tester, transform: controller, onCommit: commits.add);

    final table = find.byKey(const ValueKey('table-visual-table-a'));
    expect(table, findsOneWidget);
    final originalCenter = tester.getCenter(table);
    final pointer = await tester.startGesture(originalCenter);
    await pointer.moveBy(const Offset(-100, 60));
    await tester.pump();
    expect(commits, isEmpty);
    // The render position follows the pointer, not a saved-layout mutation.
    final visibleCenter = tester.getCenter(table);
    expect(visibleCenter.dx, closeTo(originalCenter.dx - 100, 1.0));
    expect(visibleCenter.dy, closeTo(originalCenter.dy + 60, 1.0));
    await pointer.up();
    await tester.pump();
    expect(commits, hasLength(1));
    expect(commits.single.x, closeTo(300, 0.01));
    expect(commits.single.y, closeTo(360, 0.01));
    expect(commits.single.tableId, 'table-a');
  });

  testWidgets('V2 pointer drag uses inverse viewport scale', (tester) async {
    final controller = TransformationController();
    controller.value = Matrix4.identity()
      ..setEntry(0, 0, 1.5)
      ..setEntry(1, 1, 1.5);
    addTearDown(controller.dispose);
    final commits = <SeatingTable>[];
    await _mount(tester, transform: controller, onCommit: commits.add);
    final table = find.byKey(const ValueKey('table-visual-table-a'));
    final pointer = await tester.startGesture(tester.getCenter(table));
    await pointer.moveBy(const Offset(-150, 75));
    await tester.pump();
    expect(commits, isEmpty);
    await pointer.up();
    await tester.pump();
    expect(commits, hasLength(1));
    expect(commits.single.x, closeTo(300, .01));
    expect(commits.single.y, closeTo(350, .01));
  });

  testWidgets('V2 selected corner resize commits one geometry proposal',
      (tester) async {
    final controller = TransformationController();
    addTearDown(controller.dispose);
    final commits = <SeatingTable>[];
    await _mount(tester,
        transform: controller, onCommit: commits.add, selected: true);
    final table = find.byKey(const ValueKey('table-visual-table-a'));
    final rect = tester.getRect(table);
    final pointer = await tester.startGesture(
      Offset(rect.right - 12, rect.bottom - 12),
    );
    await pointer.moveBy(const Offset(80, 40));
    await tester.pump();
    expect(commits, isEmpty);
    await pointer.up();
    await tester.pump();
    expect(commits, hasLength(1));
    expect(commits.single.width, closeTo(260, .01));
    expect(commits.single.height, closeTo(130, .01));
    expect(commits.single.x - commits.single.width / 2,
        closeTo(310, .01));
  });
}

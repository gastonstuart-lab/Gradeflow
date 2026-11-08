import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/components/seating/planner_v2_dimensions_editor.dart';
import 'package:gradeflow/models/seating_layout.dart';

SeatingTable _sampleTable() => SeatingTable(
  tableId: 'stable-table',
  type: SeatingTableType.rectangular,
  label: 'Test Table',
  x: 400,
  y: 300,
  seatCount: 4,
  width: 180,
  height: 90,
);

Future<void> _mount(WidgetTester tester,
    Future<void> Function(SeatingTable) onSave) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: PlannerV2DimensionsEditor(
          table: _sampleTable(),
          room: const Size(1200, 800),
          onSave: onSave,
        ),
      ),
    ),
  ));
}

void main() {
  testWidgets('Precise editor commits arbitrary width and depth once',
      (tester) async {
    final saved = <SeatingTable>[];
    await _mount(tester, (candidate) async => saved.add(candidate));

    await tester.enterText(
      find.byKey(const ValueKey('planner-v2-width')), '263.5');
    await tester.enterText(
      find.byKey(const ValueKey('planner-v2-depth')), '137');
    await tester.tap(
      find.byKey(const ValueKey('planner-v2-save-dimensions')));
    await tester.pump();

    expect(saved, hasLength(1));
    expect(saved.single.width, 263.5);
    expect(saved.single.height, 137);
    expect(saved.single.x, 400);
    expect(saved.single.y, 300);
    expect(saved.single.tableId, 'stable-table');
    expect(saved.single.seatCount, 4);
  });

  testWidgets('A large resize adjusts centre only to stay in the room',
      (tester) async {
    final saved = <SeatingTable>[];
    await _mount(tester, (candidate) async => saved.add(candidate));

    await tester.enterText(
      find.byKey(const ValueKey('planner-v2-width')), '1000');
    await tester.enterText(
      find.byKey(const ValueKey('planner-v2-depth')), '400');
    await tester.tap(
      find.byKey(const ValueKey('planner-v2-save-dimensions')));
    await tester.pump();

    expect(saved, hasLength(1));
    expect(saved.single.width, 1000);
    expect(saved.single.x, 500);
    expect(saved.single.y, 300);
    expect(saved.single.x - saved.single.width / 2, 0);
  });

  testWidgets('Invalid dimensions do not attempt to save', (tester) async {
    final saved = <SeatingTable>[];
    await _mount(tester, (candidate) async => saved.add(candidate));

    await tester.enterText(
      find.byKey(const ValueKey('planner-v2-width')), '12');
    await tester.enterText(
      find.byKey(const ValueKey('planner-v2-depth')), '2000');
    await tester.tap(
      find.byKey(const ValueKey('planner-v2-save-dimensions')));
    await tester.pump();

    expect(saved, isEmpty);
    expect(find.byKey(const ValueKey('planner-v2-dimension-error')),
        findsOneWidget);
  });

  testWidgets('Storage failure leaves the user with a visible error',
      (tester) async {
    await _mount(tester, (candidate) async {
      throw StateError('Simulated persistence failure');
    });
    await tester.enterText(
      find.byKey(const ValueKey('planner-v2-width')), '240');
    await tester.tap(
      find.byKey(const ValueKey('planner-v2-save-dimensions')));
    await tester.pump();

    expect(find.textContaining('Could not save'), findsOneWidget);
    expect(find.byKey(const ValueKey('planner-v2-save-dimensions')),
        findsOneWidget);
  });
}

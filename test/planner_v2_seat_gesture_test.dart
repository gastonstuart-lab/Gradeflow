import 'dart:ui' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/components/seating/seating_canvas.dart';
import 'package:gradeflow/models/seating_layout.dart';

void main() {
  for (final kind in [PointerDeviceKind.mouse, PointerDeviceKind.touch]) {
    for (final scale in [.6, 1.0, 1.5]) {
      testWidgets(
          'seat $kind scale $scale previews, saves once and remains hittable',
          (tester) async {
        final h = await mount(tester, scale: scale);
        final start = tester.getCenter(h.seat);
        final table = tester.getCenter(h.table);
        final p = await tester.startGesture(start, kind: kind);
        await p.moveBy(Offset(300 * scale, 50 * scale));
        await tester.pump();
        expect(h.commits, isEmpty);
        expect(
            tester.getCenter(h.seat).dx, closeTo(start.dx + 300 * scale, .01));
        expect(tester.getCenter(h.table), table);
        await p.up();
        await tester.pump();
        expect(h.commits, hasLength(1));
        expect(h.commits.single.x, 300);
        expect(h.commits.single.studentId, 'synthetic');
        expect(h.tableCommits, isEmpty);
        expect(h.taps, isEmpty);
        // Re-grab well outside the former table padding/hit box.
        final q =
            await tester.startGesture(tester.getCenter(h.seat), kind: kind);
        await q.moveBy(Offset(-50 * scale, 0));
        await q.up();
        await tester.pump();
        expect(h.commits, hasLength(2));
        expect(h.commits.last.x, closeTo(250, .01));
      });
    }
  }
  testWidgets(
      'seat overlapping tabletop never starts table gesture; click remains a click',
      (tester) async {
    final h = await mount(tester, seatY: 0);
    await tester.tap(h.seat);
    await tester.pump();
    expect(h.taps, ['seat']);
    expect(h.commits, isEmpty);
    await tester.drag(h.seat, const Offset(90, 45));
    await tester.pump();
    expect(h.commits, hasLength(1));
    expect(h.tableCommits, isEmpty);
    expect(h.taps, ['seat']);
  });
  for (final escape in [false, true]) {
    testWidgets(
        'seat cancellation escape=$escape restores preview without save',
        (tester) async {
      final h = await mount(tester);
      final start = tester.getCenter(h.seat);
      final p = await tester.startGesture(start);
      await p.moveBy(const Offset(200, 100));
      await tester.pump();
      if (escape) {
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await p.up();
      } else {
        await p.cancel();
      }
      await tester.pump();
      expect(tester.getCenter(h.seat), start);
      expect(h.commits, isEmpty);
      expect(h.taps, isEmpty);
    });
  }
  testWidgets(
      'only initiating pointer controls seat; room edges bound whole seat',
      (tester) async {
    final h = await mount(tester);
    final p = await tester.startGesture(tester.getCenter(h.seat), pointer: 1);
    final q = await tester.startGesture(tester.getCenter(h.seat), pointer: 2);
    await q.moveBy(const Offset(90, 90));
    await q.up();
    await tester.pump();
    expect(h.commits, isEmpty);
    await p.moveBy(const Offset(2000, 2000));
    await p.up();
    await tester.pump();
    expect(h.commits.single.x + 400, 1172);
    expect(h.commits.single.y + 300, 772);
  });
  testWidgets('Teach Mode taps work and seat geometry cannot move',
      (tester) async {
    final h = await mount(tester, design: false);
    await tester.tap(h.seat);
    await tester.pump();
    expect(h.taps, ['seat']);
    await tester.drag(h.seat, const Offset(100, 50));
    await tester.pump();
    expect(h.commits, isEmpty);
    expect(h.tableCommits, isEmpty);
  });
  testWidgets('table preview carries seats without changing seat geometry',
      (tester) async {
    final h = await mount(tester);
    final start = tester.getCenter(h.seat);
    final p = await tester.startGesture(tester.getCenter(h.table));
    await p.moveBy(const Offset(100, 50));
    await tester.pump();
    expect(tester.getCenter(h.seat), start + const Offset(100, 50));
    await p.up();
    await tester.pump();
    expect(h.tableCommits, hasLength(1));
    expect(h.commits, isEmpty);
  });
}

class Harness {
  final commits = <SeatingSeat>[];
  final tableCommits = <SeatingTable>[];
  final taps = <String>[];
  Finder get seat => find.byType(SeatWidget);
  Finder get table => find.byKey(const ValueKey('table-visual-table'));
}

Future<Harness> mount(WidgetTester tester,
    {double scale = 1, double seatY = 100, bool design = true}) async {
  tester.view.physicalSize = const Size(2000, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final h = Harness();
  final transform = TransformationController(Matrix4.identity()
    ..setEntry(0, 0, scale)
    ..setEntry(1, 1, scale)
    ..setEntry(0, 3, 45)
    ..setEntry(1, 3, 35));
  addTearDown(transform.dispose);
  var layout = SeatingLayout(
      layoutId: 'room',
      classId: 'class',
      name: 'Synthetic',
      canvasWidth: 1200,
      canvasHeight: 800,
      tables: [
        SeatingTable(
            tableId: 'table',
            type: SeatingTableType.rectangular,
            label: 'Table',
            x: 400,
            y: 300,
            width: 180,
            height: 90,
            seatCount: 1)
      ],
      seats: [
        SeatingSeat(
            seatId: 'seat',
            tableId: 'table',
            x: 0,
            y: seatY,
            studentId: 'synthetic',
            statusColor: SeatStatusColor.green,
            note: 'Keep',
            locked: true,
            reminder: true)
      ],
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026));
  await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: StatefulBuilder(
              builder: (context, setState) => SeatingCanvas(
                    layout: layout,
                    studentsById: const {},
                    designMode: design,
                    interactive: true,
                    presentationMode: false,
                    premiumAppearance: true,
                    simplifiedArrange: true,
                    plannerV2: true,
                    transformationController: transform,
                    onSeatTap: h.taps.add,
                    onPlannerV2Commit: (t) {
                      h.tableCommits.add(t);
                      setState(() => layout = layout.copyWith(tables: [t]));
                    },
                    onPlannerV2SeatCommit: (s) {
                      h.commits.add(s);
                      setState(() => layout = layout.copyWith(seats: [s]));
                    },
                  )))));
  await tester.pumpAndSettle();
  return h;
}

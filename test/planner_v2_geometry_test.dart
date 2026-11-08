import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/components/seating/planner_v2_geometry.dart';
import 'package:gradeflow/models/seating_layout.dart';

SeatingTable _table() => SeatingTable(
      tableId: 'fixed-table-id',
      type: SeatingTableType.rectangular,
      label: 'Science',
      x: 400,
      y: 300,
      seatCount: 4,
      width: 180,
      height: 90,
    );

void main() {
  const room = Size(1200, 800);

  test('pointer motion converts from displayed pixels to saved room units',
      () {
    final transform = Matrix4.identity()
      ..translateByDouble(250, 120, 0, 1)
      ..scaleByDouble(2, 2, 1, 1);
    final start = MatrixUtils.transformPoint(transform, const Offset(400, 300));
    final gesture = PlannerV2Geometry.begin(
      table: _table(),
      pointer: start,
      viewTransform: transform,
      roomSize: room,
      action: PlannerV2Action.move,
    );
    final next = gesture.update(start + const Offset(-200, 80));
    expect(next.x, closeTo(300, 0.00001));
    expect(next.y, closeTo(340, 0.00001));
    expect(next.tableId, 'fixed-table-id');
    expect(next.seatCount, 4);
    expect(next.width, 180);
    expect(next.height, 90);
  });

  test('drag goes all the way to the physical left and right edges', () {
    final gesture = PlannerV2Geometry.begin(
      table: _table(),
      pointer: const Offset(400, 300),
      viewTransform: Matrix4.identity(),
      roomSize: room,
      action: PlannerV2Action.move,
    );
    expect(gesture.update(const Offset(-6000, 300)).x, 90);
    expect(gesture.update(const Offset(6000, 300)).x, 1110);
    expect(gesture.update(const Offset(400, -6000)).y, 45);
    expect(gesture.update(const Offset(400, 6000)).y, 755);
  });

  test('resizing is continuous and keeps top-left anchored', () {
    final transform = Matrix4.identity()
      ..translateByDouble(40, 15, 0, 1)
      ..scaleByDouble(1.5, 1.5, 1, 1);
    final point = MatrixUtils.transformPoint(transform, const Offset(490, 345));
    final gesture = PlannerV2Geometry.begin(
      table: _table(),
      pointer: point,
      viewTransform: transform,
      roomSize: room,
      action: PlannerV2Action.resizeBottomRight,
    );
    final next = gesture.update(point + const Offset(120, 60));
    expect(next.width, closeTo(260, .00001));
    expect(next.height, closeTo(130, .00001));
    expect(next.x - next.width / 2, closeTo(310, .00001));
    expect(next.y - next.height / 2, closeTo(255, .00001));
    expect(next.tableId, _table().tableId);
  });

  test('resize respects minimum target size and visible physical bounds', () {
    final gesture = PlannerV2Geometry.begin(
      table: _table(),
      pointer: const Offset(490, 345),
      viewTransform: Matrix4.identity(),
      roomSize: room,
      action: PlannerV2Action.resizeBottomRight,
    );
    final small = gesture.update(const Offset(-999, -999));
    expect(small.width, 40);
    expect(small.height, 40);
    final large = gesture.update(const Offset(9000, 9000));
    expect(large.x + large.width / 2, 1200);
    expect(large.y + large.height / 2, 800);
  });

  test('the gesture is repeatable and never edits the source table', () {
    final original = _table();
    final gesture = PlannerV2Geometry.begin(
      table: original,
      pointer: const Offset(400, 300),
      viewTransform: Matrix4.identity(),
      roomSize: room,
      action: PlannerV2Action.move,
    );
    expect(gesture.update(const Offset(600, 450)).x, 600);
    expect(gesture.update(const Offset(600, 450)).x, 600);
    expect(gesture.update(const Offset(400, 300)).x, original.x);
    expect(original.x, 400);
    expect(original.y, 300);
  });

  test('noninvertible transforms are rejected rather than corrupting data',
      () {
    final matrix = Matrix4.identity()..setEntry(0, 0, 0);
    expect(
      () => PlannerV2Geometry.begin(
        table: _table(),
        pointer: const Offset(400, 300),
        viewTransform: matrix,
        roomSize: room,
        action: PlannerV2Action.move,
      ),
      throwsArgumentError,
    );
  });
}

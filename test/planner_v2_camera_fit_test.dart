import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/components/seating/classroom_map_framing.dart';
import 'package:gradeflow/models/seating_layout.dart';

SeatingLayout _furnitureAtBottom() {
  final at = DateTime(2026, 11, 9);
  return SeatingLayout(
    layoutId: 'camera-room',
    classId: 'synthetic-only',
    name: 'Synthetic camera test',
    canvasWidth: 1600,
    canvasHeight: 1200,
    tables: [
      SeatingTable(
        tableId: 'one',
        type: SeatingTableType.rectangular,
        label: 'One',
        x: 400,
        y: 650,
        seatCount: 0,
        width: 180,
        height: 90,
      ),
      SeatingTable(
        tableId: 'two',
        type: SeatingTableType.rectangular,
        label: 'Two',
        x: 890,
        y: 820,
        seatCount: 0,
        width: 180,
        height: 90,
      ),
    ],
    seats: const [],
    createdAt: at,
    updatedAt: at,
  );
}

void main() {
  const viewport = Size(1500, 650);

  test('Fit to screen centers real furniture rather than empty room origin',
      () {
    final layout = _furnitureAtBottom();
    final m = ClassroomMapFraming.plannerRoom(layout, viewport);
    final b = ClassroomMapFraming.roomBounds(layout, compact: true);
    final tl = MatrixUtils.transformPoint(m, b.topLeft);
    final br = MatrixUtils.transformPoint(m, b.bottomRight);
    final viewCentre =
        Offset((tl.dx + br.dx) / 2, (tl.dy + br.dy) / 2);
    expect(viewCentre.dx, closeTo(viewport.width / 2, 1));
    expect(viewCentre.dy, closeTo(viewport.height / 2, 1));
    expect(tl.dx, greaterThanOrEqualTo(0));
    expect(tl.dy, greaterThanOrEqualTo(0));
    expect(br.dx, lessThanOrEqualTo(viewport.width));
    expect(br.dy, lessThanOrEqualTo(viewport.height));
    expect(br.dy - tl.dy, greaterThan(viewport.height * .65));
    // Frame only: do not rewrite persisted positions.
    expect(layout.tables.first.y, 650);
  });

  test('Zoom retains centre point when fitted camera has translation', () {
    final before = ClassroomMapFraming.plannerRoom(
        _furnitureAtBottom(), viewport);
    final screenCentre = Offset(viewport.width / 2, viewport.height / 2);
    final roomCentreBefore = MatrixUtils.transformPoint(
        Matrix4.inverted(before), screenCentre);
    final after = ClassroomMapFraming.zoomKeepingCentre(
        before, viewport, before.getMaxScaleOnAxis() * 1.2);
    final roomCentreAfter = MatrixUtils.transformPoint(
        Matrix4.inverted(after), screenCentre);
    expect(roomCentreAfter.dx, closeTo(roomCentreBefore.dx, 0.0001));
    expect(roomCentreAfter.dy, closeTo(roomCentreBefore.dy, 0.0001));
    expect(after.entry(0, 3), isNot(equals(0)));
  });

  test('Arrange Mode never exposes inaccessible negative room coordinates',
      () {
    final initial = Matrix4.identity()
      ..setEntry(0, 0, 1.2)
      ..setEntry(1, 1, 1.2)
      ..setEntry(0, 3, 80)
      ..setEntry(1, 3, 90);
    final after = ClassroomMapFraming.zoomKeepingCentre(
      initial,
      viewport,
      1.0,
      zeroBasedFloor: true,
    );
    expect(after.entry(0, 3), lessThanOrEqualTo(0));
    expect(after.entry(1, 3), lessThanOrEqualTo(0));
  });

  test('Workspace includes translated visible right and bottom edges', () {
    final m = Matrix4.identity()
      ..setEntry(0, 0, 1.5)
      ..setEntry(1, 1, 1.5)
      ..setEntry(0, 3, -300)
      ..setEntry(1, 3, -220);
    final layout = _furnitureAtBottom();
    final size = ClassroomMapFraming.visibleWorkspace(
        layout, const Size(3000, 2400), m);
    expect(size.width, closeTo((3000 + 300) / 1.5, .001));
    expect(size.height, closeTo((2400 + 220) / 1.5, .001));
    expect(size.width, greaterThan(layout.canvasWidth));
    expect(size.height, greaterThan(layout.canvasHeight));
  });

  test('Invalid viewport does not produce singular fit', () {
    final m = ClassroomMapFraming.plannerRoom(
        _furnitureAtBottom(), const Size(0, 100));
    expect(m.determinant(), closeTo(1, .001));
  });
}

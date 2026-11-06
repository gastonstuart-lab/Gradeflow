import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/components/seating/classroom_map_framing.dart';
import 'package:gradeflow/models/seating_layout.dart';

void main() {
  final now = DateTime(2026, 11, 6);
  SeatingLayout layout({
    required List<SeatingTable> tables,
    required List<SeatingSeat> seats,
  }) =>
      SeatingLayout(
        layoutId: 'saved-room',
        classId: 'class-a',
        name: 'Saved room',
        canvasWidth: 2400,
        canvasHeight: 1400,
        tables: tables,
        seats: seats,
        createdAt: now,
        updatedAt: now,
      );

  test('premium viewport frames irregular saved furniture without mutation', () {
    final tables = [
      SeatingTable(
        tableId: 'a', type: SeatingTableType.rectangular,
        label: 'A', x: 500, y: 420, seatCount: 1, width: 180, height: 90),
      SeatingTable(
        tableId: 'b', type: SeatingTableType.singleDesk,
        label: 'B', x: 1400, y: 880, seatCount: 1, width: 100, height: 70),
    ];
    final seats = [
      SeatingSeat(
        seatId: 'seat-1', tableId: 'a',
        x: -40, y: -85, studentId: 'student-1',
        statusColor: SeatStatusColor.none),
    ];
    final room = layout(tables: tables, seats: seats);
    final original = room.toJson();
    final matrix = ClassroomMapFraming.fit(room, const Size(1050, 650));
    final scale = matrix.getMaxScaleOnAxis();
    expect(scale, greaterThan(0.15));
    expect(scale, lessThan(1.0));
    // Both actual table centres remain inside the visible viewport.
    for (final table in tables) {
      final x = matrix.storage[12] + table.x * scale;
      final y = matrix.storage[13] + table.y * scale;
      expect(x, inInclusiveRange(0, 1050));
      expect(y, inInclusiveRange(0, 650));
    }
    expect(room.toJson(), original);
  });

  test('compact viewport stays finite and fits the same real layout', () {
    final room = layout(
      tables: [SeatingTable(
        tableId: 'desk', type: SeatingTableType.singleDesk,
        label: 'Desk', x: 1200, y: 700,
        seatCount: 1, width: 90, height: 60)],
      seats: [],
    );
    final matrix = ClassroomMapFraming.fit(room, const Size(380, 400));
    expect(matrix.storage.every((value) => value.isFinite), isTrue);
    expect(matrix.getMaxScaleOnAxis(), greaterThanOrEqualTo(0.15));
  });

  test('empty room uses the saved canvas dimensions', () {
    final room = layout(tables: [], seats: []);
    final matrix = ClassroomMapFraming.fit(room, const Size(1000, 700));
    expect(matrix.getMaxScaleOnAxis(), lessThan(1));
  });
}

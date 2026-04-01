import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/components/seating/seating_canvas.dart';
import 'package:gradeflow/models/seating_layout.dart';

void main() {
  testWidgets('seat stays tappable in edit room mode', (tester) async {
    final table = SeatingTable(
      tableId: 'table-1',
      type: SeatingTableType.singleDesk,
      label: 'Desk',
      x: 200,
      y: 200,
      seatCount: 1,
      width: 70,
      height: 50,
    );
    final seat = SeatingSeat(
      seatId: 'seat-1',
      tableId: table.tableId,
      x: 0,
      y: 61,
      studentId: null,
      statusColor: SeatStatusColor.none,
    );

    String? tappedSeatId;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: TableWidget(
              table: table,
              seats: [seat],
              studentsById: const {},
              designMode: true,
              interactive: true,
              presentationMode: false,
              onSeatTap: (seatId) => tappedSeatId = seatId,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.event_seat_outlined));
    await tester.pumpAndSettle();

    expect(tappedSeatId, seat.seatId);
    expect(find.byTooltip('Move seat'), findsOneWidget);
  });

  testWidgets('locked seat shows a pin marker', (tester) async {
    final table = SeatingTable(
      tableId: 'table-1',
      type: SeatingTableType.singleDesk,
      label: 'Desk',
      x: 200,
      y: 200,
      seatCount: 1,
      width: 70,
      height: 50,
    );
    final seat = SeatingSeat(
      seatId: 'seat-1',
      tableId: table.tableId,
      x: 0,
      y: 61,
      studentId: 'stu-1',
      statusColor: SeatStatusColor.none,
      locked: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: TableWidget(
              table: table,
              seats: [seat],
              studentsById: const {},
              designMode: false,
              interactive: true,
              presentationMode: false,
            ),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.push_pin), findsOneWidget);
  });

  testWidgets('seat reminder shows a note marker', (tester) async {
    final table = SeatingTable(
      tableId: 'table-1',
      type: SeatingTableType.singleDesk,
      label: 'Desk',
      x: 200,
      y: 200,
      seatCount: 1,
      width: 70,
      height: 50,
    );
    final seat = SeatingSeat(
      seatId: 'seat-1',
      tableId: table.tableId,
      x: 0,
      y: 61,
      studentId: 'stu-1',
      statusColor: SeatStatusColor.none,
      note: 'Check in',
      reminder: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: TableWidget(
              table: table,
              seats: [seat],
              studentsById: const {},
              designMode: false,
              interactive: true,
              presentationMode: false,
            ),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.notifications_active_outlined), findsOneWidget);
  });
}

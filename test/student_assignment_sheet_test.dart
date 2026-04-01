import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/components/seating/student_assignment_sheet.dart';
import 'package:gradeflow/models/seating_layout.dart';
import 'package:gradeflow/models/student.dart';

void main() {
  Student buildStudent({
    required String id,
    required String chineseName,
    required String firstName,
    required String lastName,
    String? seatNo,
  }) {
    final now = DateTime(2026, 1, 1);
    return Student(
      studentId: id,
      chineseName: chineseName,
      englishFirstName: firstName,
      englishLastName: lastName,
      seatNo: seatNo,
      classId: 'class-a',
      createdAt: now,
      updatedAt: now,
    );
  }

  testWidgets('shows seat status and filters the roster', (tester) async {
    final students = [
      buildStudent(
        id: 'stu-1',
        chineseName: '王小明',
        firstName: 'Ming',
        lastName: 'Wang',
        seatNo: '1',
      ),
      buildStudent(
        id: 'stu-2',
        chineseName: '陳寶兒',
        firstName: 'Bao',
        lastName: 'Chen',
        seatNo: '2',
      ),
      buildStudent(
        id: 'stu-3',
        chineseName: '林安',
        firstName: 'An',
        lastName: 'Lin',
      ),
    ];
    final seats = [
      SeatingSeat(
        seatId: 'seat-1',
        tableId: 'table-1',
        x: 0,
        y: 0,
        studentId: 'stu-1',
        statusColor: SeatStatusColor.none,
      ),
      SeatingSeat(
        seatId: 'seat-2',
        tableId: 'table-1',
        x: 40,
        y: 0,
        studentId: 'stu-2',
        statusColor: SeatStatusColor.none,
      ),
      SeatingSeat(
        seatId: 'seat-3',
        tableId: 'table-1',
        x: 80,
        y: 0,
        studentId: null,
        statusColor: SeatStatusColor.none,
      ),
    ];

    String? selectedStudentId;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StudentAssignmentSheet(
            students: students,
            seats: seats,
            targetSeatId: 'seat-1',
            onSelected: (student) => selectedStudentId = student.studentId,
          ),
        ),
      ),
    );

    expect(find.text('ID stu-1 | Currently in this seat'), findsOneWidget);
    expect(find.text('ID stu-2 | Currently in seat 2'), findsOneWidget);
    expect(find.text('ID stu-3 | Not placed yet'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Bao');
    await tester.pumpAndSettle();

    expect(find.textContaining('陳寶兒'), findsOneWidget);
    expect(find.textContaining('王小明'), findsNothing);

    await tester.tap(find.textContaining('陳寶兒'));
    await tester.pumpAndSettle();

    expect(selectedStudentId, 'stu-2');
  });

  testWidgets('defaults to student id ascending order', (tester) async {
    final students = [
      buildStudent(
        id: 'stu-10',
        chineseName: 'Ten',
        firstName: 'Ten',
        lastName: 'Student',
      ),
      buildStudent(
        id: 'stu-2',
        chineseName: 'Two',
        firstName: 'Two',
        lastName: 'Student',
      ),
      buildStudent(
        id: 'stu-1',
        chineseName: 'One',
        firstName: 'One',
        lastName: 'Student',
      ),
    ];
    final seats = <SeatingSeat>[
      SeatingSeat(
        seatId: 'seat-1',
        tableId: 'table-1',
        x: 0,
        y: 0,
        studentId: null,
        statusColor: SeatStatusColor.none,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StudentAssignmentSheet(
            students: students,
            seats: seats,
            targetSeatId: 'seat-1',
            onSelected: (_) {},
          ),
        ),
      ),
    );

    expect(
      tester.getTopLeft(find.textContaining('One').first).dy,
      lessThan(tester.getTopLeft(find.textContaining('Two').first).dy),
    );
    expect(
      tester.getTopLeft(find.textContaining('Two').first).dy,
      lessThan(tester.getTopLeft(find.textContaining('Ten').first).dy),
    );
  });
}

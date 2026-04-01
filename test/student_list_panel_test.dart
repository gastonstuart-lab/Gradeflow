import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/components/seating/student_list_panel.dart';
import 'package:gradeflow/models/student.dart';

void main() {
  testWidgets(
      'student list defaults to ascending student id and can switch to name order',
      (tester) async {
    final students = [
      _student(
        studentId: 'student-10',
        chineseName: 'Charlie',
        englishFirstName: 'Charlie',
        englishLastName: 'Zephyr',
      ),
      _student(
        studentId: 'student-2',
        chineseName: 'Alice',
        englishFirstName: 'Alice',
        englishLastName: 'Bravo',
      ),
      _student(
        studentId: 'student-1',
        chineseName: 'Bob',
        englishFirstName: 'Bob',
        englishLastName: 'Alpha',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 420,
            child: StudentListPanel(
              students: students,
              assignedStudentIds: const {},
              compact: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .getTopLeft(find.byKey(const ValueKey('student-chip-student-1')))
          .dy,
      lessThan(
        tester
            .getTopLeft(find.byKey(const ValueKey('student-chip-student-2')))
            .dy,
      ),
    );
    expect(
      tester
          .getTopLeft(find.byKey(const ValueKey('student-chip-student-2')))
          .dy,
      lessThan(
        tester
            .getTopLeft(find.byKey(const ValueKey('student-chip-student-10')))
            .dy,
      ),
    );

    await tester.tap(find.byIcon(Icons.sort));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Name (A-Z)').last);
    await tester.pumpAndSettle();

    expect(
      tester
          .getTopLeft(find.byKey(const ValueKey('student-chip-student-2')))
          .dy,
      lessThan(
        tester
            .getTopLeft(find.byKey(const ValueKey('student-chip-student-1')))
            .dy,
      ),
    );
    expect(
      tester
          .getTopLeft(find.byKey(const ValueKey('student-chip-student-1')))
          .dy,
      lessThan(
        tester
            .getTopLeft(find.byKey(const ValueKey('student-chip-student-10')))
            .dy,
      ),
    );
  });
}

Student _student({
  required String studentId,
  required String chineseName,
  required String englishFirstName,
  required String englishLastName,
}) {
  return Student(
    studentId: studentId,
    chineseName: chineseName,
    englishFirstName: englishFirstName,
    englishLastName: englishLastName,
    classId: 'class-a',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
}

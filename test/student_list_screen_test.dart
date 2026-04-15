import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:gradeflow/models/class.dart';
import 'package:gradeflow/models/student.dart';
import 'package:gradeflow/screens/student_list_screen.dart';
import 'package:gradeflow/services/class_service.dart';
import 'package:gradeflow/services/student_service.dart';

void main() {
  testWidgets(
    'student list defaults to ascending student id and still supports seat sorting',
    (tester) async {
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });

      await tester.binding.setSurfaceSize(const Size(1280, 900));

      final classItem = Class(
        classId: 'class-a',
        className: 'EEP 3 J2FG',
        subject: 'English',
        schoolYear: '2025-2026',
        term: 'Spring',
        teacherId: 'teacher-a',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
      final students = [
        _student(
          studentId: '1130257',
          chineseName: 'Charlie',
          englishFirstName: 'Charlie',
          englishLastName: 'Zephyr',
          seatNo: '1',
        ),
        _student(
          studentId: '1130218',
          chineseName: 'Alice',
          englishFirstName: 'Alice',
          englishLastName: 'Bravo',
          seatNo: '3',
        ),
        _student(
          studentId: '1130219',
          chineseName: 'Bob',
          englishFirstName: 'Bob',
          englishLastName: 'Alpha',
          seatNo: '2',
        ),
      ];

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<StudentService>.value(
              value: _FakeStudentService(students),
            ),
            ChangeNotifierProvider<ClassService>.value(
              value: _FakeClassService(classItem),
            ),
          ],
          child: const MaterialApp(
            home: StudentListScreen(classId: 'class-a'),
          ),
        ),
      );
      await tester.pump();

      expect(
        _topForStudentId(tester, '1130218'),
        lessThan(_topForStudentId(tester, '1130219')),
      );
      expect(
        _topForStudentId(tester, '1130219'),
        lessThan(_topForStudentId(tester, '1130257')),
      );

      await tester.tap(find.byIcon(Icons.sort));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Student ID'), findsOneWidget);

      await tester.tap(find.text('Seat number'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        _topForStudentId(tester, '1130257'),
        lessThan(_topForStudentId(tester, '1130219')),
      );
      expect(
        _topForStudentId(tester, '1130219'),
        lessThan(_topForStudentId(tester, '1130218')),
      );
    },
  );
}

double _topForStudentId(WidgetTester tester, String studentId) {
  return tester.getTopLeft(find.textContaining('ID: $studentId')).dy;
}

Student _student({
  required String studentId,
  required String chineseName,
  required String englishFirstName,
  required String englishLastName,
  required String seatNo,
}) {
  return Student(
    studentId: studentId,
    chineseName: chineseName,
    englishFirstName: englishFirstName,
    englishLastName: englishLastName,
    seatNo: seatNo,
    classId: 'class-a',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
}

class _FakeStudentService extends StudentService {
  _FakeStudentService(this._fakeStudents);

  final List<Student> _fakeStudents;

  @override
  List<Student> get students => _fakeStudents;

  @override
  bool get isLoading => false;

  @override
  Future<void> loadStudents(String classId) async {}
}

class _FakeClassService extends ClassService {
  _FakeClassService(this._classItem);

  final Class _classItem;

  @override
  Class? getClassById(String classId) {
    if (_classItem.classId == classId) {
      return _classItem;
    }
    return null;
  }
}

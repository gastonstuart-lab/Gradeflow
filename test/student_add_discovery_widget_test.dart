import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:gradeflow/models/class.dart' as school;
import 'package:gradeflow/models/student.dart';
import 'package:gradeflow/screens/student_list_screen.dart';
import 'package:gradeflow/services/class_service.dart';
import 'package:gradeflow/services/student_service.dart';

Student _student(String id) {
  final date = DateTime(2026, 11, 12);
  return Student(
    studentId: id,
    chineseName: '測試',
    englishFirstName: 'Existing',
    englishLastName: id,
    classId: 'class-a',
    createdAt: date,
    updatedAt: date,
  );
}

class _FakeRosterService extends StudentService {
  _FakeRosterService() : records = [_student('101')];

  final List<Student> records;
  bool failSave = false;
  int attemptedSaves = 0;

  @override
  List<Student> get students => records;

  @override
  bool get isLoading => false;

  @override
  Future<void> loadStudents(String classId) async {}

  @override
  Future<void> addStudent(Student student) async {
    attemptedSaves++;
    if (failSave) throw StateError('Simulated save unavailable');
    records.add(student);
    notifyListeners();
  }
}

class _FakeClasses extends ClassService {
  @override
  school.Class? getClassById(String classId) {
    if (classId != 'class-a') return null;
    final date = DateTime(2026, 11, 12);
    return school.Class(
      classId: classId,
      className: 'EEP1 J1FG G1',
      subject: 'English',
      schoolYear: '2026-2027',
      term: 'Fall',
      teacherId: 'teacher',
      createdAt: date,
      updatedAt: date,
    );
  }
}

Future<void> _pumpRoster(
  WidgetTester tester,
  _FakeRosterService service, {
  bool openAddOnLoad = false,
}) async {
  tester.view.physicalSize = const Size(1280, 930);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider<StudentService>.value(value: service),
      ChangeNotifierProvider<ClassService>.value(value: _FakeClasses()),
    ],
    child: MaterialApp(
      home: StudentListScreen(
        classId: 'class-a',
        openAddOnLoad: openAddOnLoad,
      ),
    ),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
}

void main() {
  testWidgets('The occupied roster presents an obvious labelled Add student button',
      (tester) async {
    final service = _FakeRosterService();
    await _pumpRoster(tester, service);
    expect(find.byKey(const ValueKey('roster-add-student')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('roster-add-student')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('add-student-dialog')), findsOneWidget);
    expect(find.text('Adding to EEP1 J1FG G1'), findsOneWidget);
    expect(find.textContaining('Place her in a chair separately'), findsOneWidget);
    expect(service.attemptedSaves, 0);
  });

  testWidgets('Required fields and existing ID stop accidental duplicates',
      (tester) async {
    final service = _FakeRosterService();
    await _pumpRoster(tester, service);
    await tester.tap(find.byKey(const ValueKey('roster-add-student')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('save-new-student')));
    await tester.pump();
    expect(find.text('Student ID is required'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('new-student-id')), '101');
    await tester.enterText(
      find.byKey(const ValueKey('new-student-chinese-name')), '新生');
    await tester.enterText(
      find.byKey(const ValueKey('new-student-first-name')), 'New');
    await tester.enterText(
      find.byKey(const ValueKey('new-student-last-name')), 'Student');
    await tester.ensureVisible(find.byKey(const ValueKey('save-new-student')));
    await tester.tap(find.byKey(const ValueKey('save-new-student')));
    await tester.pump();
    expect(find.text('That student ID is already in this class'), findsOneWidget);
    expect(service.attemptedSaves, 0);
  });

  testWidgets('Save failure retains the dialog and does not claim success',
      (tester) async {
    final service = _FakeRosterService()..failSave = true;
    await _pumpRoster(tester, service, openAddOnLoad: true);
    expect(find.byKey(const ValueKey('add-student-dialog')), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('new-student-id')), '102');
    await tester.enterText(
      find.byKey(const ValueKey('new-student-chinese-name')), '新生');
    await tester.enterText(
      find.byKey(const ValueKey('new-student-first-name')), 'New');
    await tester.enterText(
      find.byKey(const ValueKey('new-student-last-name')), 'Student');
    await tester.ensureVisible(find.byKey(const ValueKey('save-new-student')));
    await tester.tap(find.byKey(const ValueKey('save-new-student')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Simulated save unavailable'), findsOneWidget);
    expect(find.byKey(const ValueKey('add-student-dialog')), findsOneWidget);
    expect(service.records, hasLength(1));
    expect(service.attemptedSaves, 1);
    service.failSave = false;
    await tester.tap(find.byKey(const ValueKey('save-new-student')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    expect(service.records, hasLength(2));
    expect(service.records.last.studentId, '102');
    expect(find.byKey(const ValueKey('add-student-dialog')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

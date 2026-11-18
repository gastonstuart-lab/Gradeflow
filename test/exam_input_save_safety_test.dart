import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:gradeflow/models/class.dart' as school;
import 'package:gradeflow/models/student.dart';
import 'package:gradeflow/screens/exam_input_screen.dart';
import 'package:gradeflow/services/class_service.dart';
import 'package:gradeflow/services/student_service.dart';
import 'package:gradeflow/services/final_exam_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'final_exam_save_safety_test.dart' show FailingExamRepository;

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


void main() {
  testWidgets('failed autosave and exit retain text until Save all retry succeeds', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = FailingExamRepository();
    final service = FinalExamService(repository: repo);
    await service.upsertManyExams('class-a', {'101': 70});
    repo.failWrites = true;
    final router = GoRouter(initialLocation: '/exam', routes: [
      GoRoute(path: '/exam', builder: (_, __) => const ExamInputScreen(classId: 'class-a')),
      GoRoute(path: '/os/class/class-a', builder: (_, __) => const Scaffold(body: Text('Class destination'))),
    ]);
    await tester.pumpWidget(MultiProvider(providers: [
      ChangeNotifierProvider<StudentService>.value(value: _FakeRosterService()),
      ChangeNotifierProvider<ClassService>.value(value: _FakeClasses()),
      ChangeNotifierProvider<FinalExamService>.value(value: service),
    ], child: MaterialApp.router(routerConfig: router)));
    await tester.pumpAndSettle();
    final field = find.byType(TextField).first;
    await tester.enterText(field, '90');
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(find.textContaining('could not be saved'), findsOneWidget);
    expect(tester.widget<TextField>(field).controller!.text, '90');
    expect(service.getExam('101')!.examScore, 70);
    await tester.tap(find.byTooltip('Back to class workspace'));
    await tester.pumpAndSettle();
    expect(find.byType(ExamInputScreen), findsOneWidget);
    expect(tester.widget<TextField>(field).controller!.text, '90');
    repo.failWrites = false;
    await tester.tap(find.text('Save all'));
    await tester.pumpAndSettle();
    expect(service.getExam('101')!.examScore, 90);
    expect((await repo.loadExams('class-a')).single.examScore, 90);
    await tester.tap(find.byTooltip('Back to class workspace'));
    await tester.pumpAndSettle();
    expect(find.text('Class destination'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    router.dispose();
    service.dispose();
  });
}

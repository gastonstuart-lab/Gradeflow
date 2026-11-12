import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gradeflow/models/student.dart';
import 'package:gradeflow/repositories/local_repository.dart';
import 'package:gradeflow/services/student_service.dart';

Student _student(String id, String classId) {
  final now = DateTime(2026, 11, 12);
  return Student(
    studentId: id,
    chineseName: '測試',
    englishFirstName: 'Test',
    englishLastName: id,
    classId: classId,
    createdAt: now,
    updatedAt: now,
  );
}

class _FailingSaveRepository extends LocalRepository {
  @override
  Future<void> saveStudents(String classId, List<Student> students) {
    throw StateError('Simulated unavailable write');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('Adding one student retains all existing students and the other class',
      () async {
    final repo = LocalRepository();
    await repo.saveStudents('class-1', [
      _student('101', 'class-1'),
      _student('102', 'class-1'),
    ]);
    await repo.saveStudents('class-2', [_student('201', 'class-2')]);
    final service = StudentService(repository: repo);
    await service.loadStudents('class-1');
    await service.addStudent(_student('103', 'class-1'));
    expect(service.students.map((s) => s.studentId), ['101', '102', '103']);
    expect((await repo.loadStudents('class-1')).map((s) => s.studentId),
        ['101', '102', '103']);
    expect((await repo.loadStudents('class-2')).map((s) => s.studentId),
        ['201']);
    service.dispose();
  });

  test('Rejects duplicate IDs without touching existing roster or scores',
      () async {
    final repo = LocalRepository();
    await repo.saveStudents('class-1', [_student('101', 'class-1')]);
    final service = StudentService(repository: repo);
    await service.loadStudents('class-1');
    await expectLater(
      service.addStudent(_student(' 101 ', 'class-1')),
      throwsA(isA<StateError>()),
    );
    expect(service.students.single.studentId, '101');
    expect((await repo.loadStudents('class-1')).length, 1);
    service.dispose();
  });

  test('Preserves students added since the previous roster load', () async {
    final repo = LocalRepository();
    await repo.saveStudents('class-1', [_student('101', 'class-1')]);
    final service = StudentService(repository: repo);
    await service.loadStudents('class-1');
    // Another device added a student after this service loaded the roster.
    await repo.saveStudents('class-1', [
      _student('101', 'class-1'),
      _student('102', 'class-1'),
    ]);
    await service.addStudent(_student('103', 'class-1'));
    expect((await repo.loadStudents('class-1')).map((s) => s.studentId),
        ['101', '102', '103']);
    service.dispose();
  });

  test('Failed repository save leaves in-memory state intact and rethrows',
      () async {
    final repo = _FailingSaveRepository();
    final service = StudentService(repository: repo);
    expect(service.students, isEmpty);
    await expectLater(
      service.addStudent(_student('101', 'class-1')),
      throwsA(isA<StateError>()),
    );
    expect(service.students, isEmpty);
    service.dispose();
  });

  test('Blank student ID fails before repository writes', () async {
    final repo = LocalRepository();
    final service = StudentService(repository: repo);
    await expectLater(
      service.addStudent(_student('   ', 'class-1')),
      throwsA(isA<ArgumentError>()),
    );
    expect((await repo.loadStudents('class-1')), isEmpty);
    service.dispose();
  });
}

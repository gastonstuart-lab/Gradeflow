import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gradeflow/models/student.dart';
import 'package:gradeflow/repositories/local_repository.dart';
import 'package:gradeflow/services/student_service.dart';
// Existing repository tests use this platform seam.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

Student pupil(String id, {String classId = 'class-a'}) => Student(
  studentId: id,
  chineseName: 'Fictional pupil',
  englishFirstName: 'Fictional',
  englishLastName: id,
  classId: classId,
  createdAt: DateTime(2026, 11, 16),
  updatedAt: DateTime(2026, 11, 16),
);

class FailingRoster extends LocalRepository {
  @override
  Future<void> saveStudents(String classId, List<Student> students) async {
    throw StateError('Fictional storage failure');
  }
}

class RejectRosterWrite extends InMemorySharedPreferencesStore {
  RejectRosterWrite() : super.empty();
  bool reject = false;
  @override
  Future<bool> setValue(String type, String key, Object value) async {
    if (reject && key.endsWith('students_class-a')) return false;
    return super.setValue(type, key, value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'bulk import reads destination roster, not another class in memory',
    () async {
      final repo = LocalRepository();
      await repo.saveStudents('class-a', [pupil('101')]);
      await repo.saveStudents('class-b', [pupil('201', classId: 'class-b')]);
      final service = StudentService(repository: repo);
      await service.loadStudents('class-b');
      await service.addStudents([pupil('102')]);
      expect((await repo.loadStudents('class-a')).map((s) => s.studentId), [
        '101',
        '102',
      ]);
      expect((await repo.loadStudents('class-b')).single.studentId, '201');
      expect(service.students.every((s) => s.classId == 'class-a'), isTrue);
      service.dispose();
    },
  );

  test('bulk import retains students added since the previous load', () async {
    final repo = LocalRepository();
    await repo.saveStudents('class-a', [pupil('101')]);
    final service = StudentService(repository: repo);
    await service.loadStudents('class-a');
    await repo.saveStudents('class-a', [pupil('101'), pupil('102')]);
    await service.addStudents([pupil('103')]);
    expect((await repo.loadStudents('class-a')).map((s) => s.studentId), [
      '101',
      '102',
      '103',
    ]);
    service.dispose();
  });

  test(
    'existing and within-file duplicate IDs reject the entire batch',
    () async {
      final repo = LocalRepository();
      await repo.saveStudents('class-a', [pupil('ABC')]);
      final service = StudentService(repository: repo);
      await expectLater(
        service.addStudents([pupil('102'), pupil(' abc ')]),
        throwsStateError,
      );
      await expectLater(
        service.addStudents([pupil('102'), pupil(' 102 ')]),
        throwsStateError,
      );
      expect((await repo.loadStudents('class-a')).single.studentId, 'ABC');
      service.dispose();
    },
  );

  test(
    'blank IDs and mixed classes fail before any roster is written',
    () async {
      final repo = LocalRepository();
      final service = StudentService(repository: repo);
      await expectLater(service.addStudents([pupil(' ')]), throwsArgumentError);
      await expectLater(
        service.addStudents([pupil('101'), pupil('201', classId: 'class-b')]),
        throwsArgumentError,
      );
      expect(await repo.loadStudents('class-a'), isEmpty);
      expect(await repo.loadStudents('class-b'), isEmpty);
      service.dispose();
    },
  );

  test(
    'failed bulk persistence rethrows and leaves UI state unchanged',
    () async {
      final service = StudentService(repository: FailingRoster());
      var notifications = 0;
      service.addListener(() => notifications++);
      await expectLater(service.addStudents([pupil('101')]), throwsStateError);
      expect(service.students, isEmpty);
      expect(notifications, 0);
      service.dispose();
    },
  );

  test(
    'false local write is a failure, reloads durable roster and permits retry',
    () async {
      final store = RejectRosterWrite();
      SharedPreferencesStorePlatform.instance = store;
      final repo = LocalRepository();
      await repo.saveStudents('class-a', [pupil('101')]);
      final service = StudentService(repository: repo);
      await service.loadStudents('class-a');
      store.reject = true;
      await expectLater(service.addStudents([pupil('102')]), throwsStateError);
      expect(service.students.single.studentId, '101');
      expect((await repo.loadStudents('class-a')).single.studentId, '101');
      store.reject = false;
      await service.addStudents([pupil('102')]);
      expect((await repo.loadStudents('class-a')).map((s) => s.studentId), [
        '101',
        '102',
      ]);
      service.dispose();
    },
  );
}

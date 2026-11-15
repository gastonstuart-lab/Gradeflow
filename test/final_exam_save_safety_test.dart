import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/models/final_exam.dart';
import 'package:gradeflow/repositories/local_repository.dart';
import 'package:gradeflow/services/final_exam_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FailingExamRepository extends LocalRepository {
  bool failWrites = false;
  Completer<void>? writeGate;
  int writesStarted = 0;

  @override
  Future<void> saveExams(String classId, List<FinalExam> exams) async {
    writesStarted++;
    await writeGate?.future;
    if (failWrites) throw StateError('Synthetic write failure');
    await super.saveExams(classId, exams);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('failed single save propagates and preserves persisted score for retry', () async {
    final repo = FailingExamRepository();
    final service = FinalExamService(repository: repo);
    await service.upsertManyExams('c', {'s': 70});
    final now = DateTime(2026);
    final edit = FinalExam(studentId: 's', examScore: 90, createdAt: now, updatedAt: now);
    repo.failWrites = true;
    await expectLater(service.updateExam('c', edit), throwsStateError);
    expect(service.getExam('s')!.examScore, 70);
    expect((await repo.loadExams('c')).single.examScore, 70);
    repo.failWrites = false;
    await service.updateExam('c', edit);
    expect(service.getExam('s')!.examScore, 90);
    service.dispose();
  });

  test('failed batch preserves updates and removals until a successful retry', () async {
    final repo = FailingExamRepository();
    final service = FinalExamService(repository: repo);
    await service.upsertManyExams('c', {'a': 70, 'b': 80});
    repo.failWrites = true;
    await expectLater(service.upsertManyExams('c', {'a': 0, 'b': null}), throwsStateError);
    expect(service.getExam('a')!.examScore, 70);
    expect(service.getExam('b')!.examScore, 80);
    expect(await repo.loadExams('c'), hasLength(2));
    repo.failWrites = false;
    expect(await service.upsertManyExams('c', {'a': 0, 'b': null}), 2);
    expect(service.getExam('a')!.examScore, 0);
    expect(service.getExam('b'), isNull);
    service.dispose();
  });
  test('overlapping single and batch saves retain both students and latest edit', () async {
    final repo = FailingExamRepository();
    final service = FinalExamService(repository: repo);
    repo.writeGate = Completer<void>();
    final now = DateTime(2026);
    final first = service.updateExam('c', FinalExam(
      studentId: 'a', examScore: 70, createdAt: now, updatedAt: now));
    await Future<void>.delayed(Duration.zero);
    final second = service.upsertManyExams('c', {'b': 80, 'a': 90});
    await Future<void>.delayed(Duration.zero);
    expect(repo.writesStarted, 1);
    repo.writeGate!.complete();
    await Future.wait([first, second]);
    final saved = await repo.loadExams('c');
    expect(saved.singleWhere((e) => e.studentId == 'a').examScore, 90);
    expect(saved.singleWhere((e) => e.studentId == 'b').examScore, 80);
    expect(service.getExam('a')!.examScore, 90);
    service.dispose();
  });

  test('a failed queued save permits a later retry', () async {
    final repo = FailingExamRepository()..failWrites = true;
    final service = FinalExamService(repository: repo);
    await expectLater(service.upsertManyExams('c', {'a': 70}), throwsStateError);
    repo.failWrites = false;
    expect(await service.upsertManyExams('c', {'a': 90}), 1);
    expect(service.getExam('a')!.examScore, 90);
    service.dispose();
  });

}

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/models/student_score.dart';
import 'package:gradeflow/repositories/repository_factory.dart';
import 'package:gradeflow/services/student_score_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Use the already-resolved plugin's test store to inject persistence failures
// without adding dependencies or changing production repository/service seams.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

class _ControlledStore extends InMemorySharedPreferencesStore {
  _ControlledStore() : super.empty();

  bool failScoreWrites = false;
  bool refuseScoreWrites = false;
  bool failHistoryWrites = false;
  Completer<void>? scoreGate;
  final scoreWriteStarted = Completer<void>();

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (key.startsWith('flutter.scores_')) {
      if (!scoreWriteStarted.isCompleted) scoreWriteStarted.complete();
      await scoreGate?.future;
      if (failScoreWrites) throw StateError('Synthetic score write failure');
      if (refuseScoreWrites) return false;
    }
    if (failHistoryWrites && key.startsWith('flutter.change_history_')) {
      throw StateError('Synthetic history write failure');
    }
    return super.setValue(valueType, key, value);
  }
}

StudentScore _score(double? value,
    {String student = 'synthetic-a', String item = 'synthetic-item'}) {
  final now = DateTime(2026, 10, 6);
  return StudentScore(
      studentId: student,
      gradeItemId: item,
      score: value,
      createdAt: now,
      updatedAt: now);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late StudentScoreService service;
  late _ControlledStore store;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    store = _ControlledStore();
    SharedPreferencesStorePlatform.instance = store;
    RepositoryFactory.useLocal();
    service = StudentScoreService();
  });

  tearDown(() async {
    if (store.scoreGate != null && !store.scoreGate!.isCompleted) {
      store.scoreGate!.complete();
    }
    await service.flushPendingWrites();
    service.dispose();
    SharedPreferences.setMockInitialValues({});
    RepositoryFactory.useLocal();
  });

  test('save replaces only matching student/item and persists change history',
      () async {
    await service.updateScore(
        _score(80), 'synthetic-teacher', 'synthetic-class');
    await service.updateScore(_score(40, student: 'synthetic-b'),
        'synthetic-teacher', 'synthetic-class');
    await service.updateScore(_score(70, item: 'synthetic-other-item'),
        'synthetic-teacher', 'synthetic-class');
    await service.updateScore(
        _score(60), 'synthetic-teacher', 'synthetic-class');
    await service.flushPendingWrites();
    final repo = RepositoryFactory.instance;
    final saved = await repo.loadScores('synthetic-class', 'synthetic-item');
    expect(saved.length, 2);
    expect(saved.singleWhere((s) => s.studentId == 'synthetic-a').score, 60);
    expect(saved.singleWhere((s) => s.studentId == 'synthetic-b').score, 40);
    expect(
        (await repo.loadScores('synthetic-class', 'synthetic-other-item'))
            .single
            .score,
        70);
    expect(await repo.loadScores('synthetic-other-class', 'synthetic-item'),
        isEmpty);
    final history = await repo.loadScoreHistory('synthetic-class', limit: 1);
    expect(history.single.oldScore, 80);
    expect(history.single.newScore, 60);
    expect(history.single.teacherId, 'synthetic-teacher');
    expect(history.single.classId, 'synthetic-class');
    expect(await repo.loadScoreHistory('synthetic-other-class'), isEmpty);
    final restored = StudentScoreService();
    addTearDown(restored.dispose);
    await restored.loadScores(
        'synthetic-class', ['synthetic-item', 'synthetic-other-item']);
    expect(restored.getStudentScores('synthetic-a').length, 2);
    expect(restored.getScore('synthetic-a', 'synthetic-item')!.score, 60);
  });

  test('explicit null survives save/reload and default fill can preserve it',
      () async {
    await service.updateScore(
        _score(null), 'synthetic-teacher', 'synthetic-class');
    await service.ensureDefaultScoresForGradeItem(
        'synthetic-class', 'synthetic-item', ['synthetic-a', 'synthetic-b'], 20,
        fillNulls: false);
    await service.loadScores('synthetic-class', ['synthetic-item']);
    expect(service.getScore('synthetic-a', 'synthetic-item')!.score, isNull);
    expect(service.getScore('synthetic-b', 'synthetic-item')!.score, 20);
    expect(service.getScore('synthetic-missing', 'synthetic-item'), isNull);
  });

  test('existing default fill replaces null but preserves numeric scores',
      () async {
    await service.updateScore(
        _score(null), 'synthetic-teacher', 'synthetic-class');
    await service.updateScore(_score(12, student: 'synthetic-b'),
        'synthetic-teacher', 'synthetic-class');
    await service.ensureDefaultScoresForGradeItem('synthetic-class',
        'synthetic-item', ['synthetic-a', 'synthetic-b'], 20);
    await service.loadScores('synthetic-class', ['synthetic-item']);
    expect(service.getScore('synthetic-a', 'synthetic-item')!.score, 20);
    expect(service.getScore('synthetic-b', 'synthetic-item')!.score, 12);
  });

  test('undo restores prior value without adding another history entry',
      () async {
    await service.updateScore(
        _score(80), 'synthetic-teacher', 'synthetic-class');
    await service.updateScore(
        _score(60), 'synthetic-teacher', 'synthetic-class');
    expect(
        await service.undoLastChange(
            'synthetic-other-teacher', 'synthetic-class'),
        isFalse);
    expect(await service.undoLastChange('synthetic-teacher', 'synthetic-class'),
        isTrue);
    await service.flushPendingWrites();
    expect(
        (await RepositoryFactory.instance
                .loadScores('synthetic-class', 'synthetic-item'))
            .single
            .score,
        80);
    final history =
        await RepositoryFactory.instance.loadScoreHistory('synthetic-class');
    expect(history.length, 1);
    expect(history.single.newScore, 80);
  });

  test('queue serializes rapid edits and flush waits for the held write',
      () async {
    store.scoreGate = Completer<void>();
    final first =
        service.updateScore(_score(80), 'synthetic-teacher', 'synthetic-class');
    final second =
        service.updateScore(_score(60), 'synthetic-teacher', 'synthetic-class');
    await store.scoreWriteStarted.future;
    expect(service.hasPendingWrites, isTrue);
    var flushed = false;
    final flush = service.flushPendingWrites().then((_) => flushed = true);
    await Future<void>.delayed(Duration.zero);
    expect(flushed, isFalse);
    store.scoreGate!.complete();
    await Future.wait([first, second, flush]);
    expect(service.hasPendingWrites, isFalse);
    expect(
        (await RepositoryFactory.instance
                .loadScores('synthetic-class', 'synthetic-item'))
            .single
            .score,
        60);
    final history =
        await RepositoryFactory.instance.loadScoreHistory('synthetic-class');
    expect(history.length, 2);
    expect(history.last.oldScore, 80);
    expect(history.last.newScore, 60);
  });

  test(
      'characterization: thrown score write is swallowed; flush is not success',
      () async {
    store.failScoreWrites = true;
    await expectLater(
        service.updateScore(_score(80), 'synthetic-teacher', 'synthetic-class'),
        completes);
    await service.flushPendingWrites();
    expect(service.hasPendingWrites, isFalse);
    expect(service.getScore('synthetic-a', 'synthetic-item'), isNull);
    expect(
        (await store.getAll())
            .containsKey('flutter.scores_synthetic-class_synthetic-item'),
        isFalse);
    expect(await RepositoryFactory.instance.loadScoreHistory('synthetic-class'),
        isEmpty);
    // SharedPreferences updates its cache before the platform write succeeds.
    await (await SharedPreferences.getInstance()).reload();
    expect(
        await RepositoryFactory.instance
            .loadScores('synthetic-class', 'synthetic-item'),
        isEmpty);
    store.failScoreWrites = false;
    await service.updateScore(
        _score(60), 'synthetic-teacher', 'synthetic-class');
    await service.flushPendingWrites();
    expect(
        (await RepositoryFactory.instance
                .loadScores('synthetic-class', 'synthetic-item'))
            .single
            .score,
        60);
  });

  test('characterization: false platform result is treated as saved', () async {
    store.refuseScoreWrites = true;
    await service.updateScore(
        _score(80), 'synthetic-teacher', 'synthetic-class');
    await service.flushPendingWrites();
    expect(service.getScore('synthetic-a', 'synthetic-item')!.score, 80);
    expect(
        (await store.getAll())
            .containsKey('flutter.scores_synthetic-class_synthetic-item'),
        isFalse);
    expect(
        (await RepositoryFactory.instance.loadScoreHistory('synthetic-class'))
            .single
            .newScore,
        80);
    await (await SharedPreferences.getInstance()).reload();
    expect(
        await RepositoryFactory.instance
            .loadScores('synthetic-class', 'synthetic-item'),
        isEmpty);
  });

  test('characterization: history failure does not report a partial save',
      () async {
    store.failHistoryWrites = true;
    await service.updateScore(
        _score(80), 'synthetic-teacher', 'synthetic-class');
    await service.flushPendingWrites();
    await (await SharedPreferences.getInstance()).reload();
    expect(
        (await RepositoryFactory.instance
                .loadScores('synthetic-class', 'synthetic-item'))
            .single
            .score,
        80);
    expect(await RepositoryFactory.instance.loadScoreHistory('synthetic-class'),
        isEmpty);
    expect(service.getScore('synthetic-a', 'synthetic-item')!.score, 80);
  });
}

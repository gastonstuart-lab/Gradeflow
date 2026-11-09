import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/models/student_score.dart';
import 'package:gradeflow/repositories/local_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Uses the platform test seam already present in GradeFlow's gradebook tests.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

class _PausedFirstScoreWrite extends InMemorySharedPreferencesStore {
  _PausedFirstScoreWrite() : super.empty();

  final firstStarted = Completer<void>();
  final releaseFirst = Completer<void>();
  int scoreWritesStarted = 0;
  final List<double> completedScores = [];

  @override
  Future<bool> setValue(String type, String key, Object value) async {
    if (key == 'scores_class-a_quiz-a') {
      scoreWritesStarted++;
      if (scoreWritesStarted == 1) {
        firstStarted.complete();
        await releaseFirst.future;
      }
      final scores = jsonDecode(value as String) as List<dynamic>;
      final firstScore = (scores.first as Map<String, dynamic>)['score'] as num;
      completedScores.add(firstScore.toDouble());
    }
    return super.setValue(type, key, value);
  }
}

class _RejectFirstScoreWrite extends InMemorySharedPreferencesStore {
  _RejectFirstScoreWrite() : super.empty();
  int scoreWrites = 0;

  @override
  Future<bool> setValue(String type, String key, Object value) async {
    if (key == 'scores_class-a_quiz-a' && ++scoreWrites == 1) {
      return false;
    }
    return super.setValue(type, key, value);
  }
}

StudentScore _score(double value) {
  final now = DateTime(2026, 11, 9);
  return StudentScore(
    studentId: 'fictional-pupil',
    gradeItemId: 'quiz-a',
    score: value,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('overlapping score saves serialize and flush waits for durable writes',
      () async {
    final store = _PausedFirstScoreWrite();
    SharedPreferencesStorePlatform.instance = store;
    final repo = LocalRepository();

    final first = repo.saveScores('class-a', 'quiz-a', [_score(94)]);
    await store.firstStarted.future;
    final second = repo.saveScores('class-a', 'quiz-a', [_score(96)]);

    // First write is deliberately blocked. A second save must not begin
    // or claim completion while the first is still in progress.
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(store.scoreWritesStarted, 1);
    expect(await repo.hasPendingWrites(), isTrue);

    var flushed = false;
    final flush = repo.flushPendingWrites().then((_) => flushed = true);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(flushed, isFalse);

    store.releaseFirst.complete();
    await Future.wait([first, second, flush]);

    expect(store.completedScores, [94.0, 96.0]);
    expect(await repo.hasPendingWrites(), isFalse);
    expect((await LocalRepository().loadScores('class-a', 'quiz-a')).single.score,
        96.0);
  });

  test('a rejected first save fails its caller but does not poison later saves',
      () async {
    final store = _RejectFirstScoreWrite();
    SharedPreferencesStorePlatform.instance = store;
    final repo = LocalRepository();

    final failed = repo.saveScores('class-a', 'quiz-a', [_score(94)]);
    final later = repo.saveScores('class-a', 'quiz-a', [_score(96)]);
    await expectLater(failed, throwsStateError);
    await later;
    await repo.flushPendingWrites();

    expect(store.scoreWrites, 2);
    expect(await repo.hasPendingWrites(), isFalse);
    expect((await LocalRepository().loadScores('class-a', 'quiz-a')).single.score,
        96.0);
  });
}

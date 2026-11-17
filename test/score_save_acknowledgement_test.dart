import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/models/student_score.dart';
import 'package:gradeflow/repositories/repository_factory.dart';
import 'package:gradeflow/services/student_score_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

class RejectScoreStore extends InMemorySharedPreferencesStore {
  RejectScoreStore() : super.empty();
  bool reject = true;
  bool throws = false;
  int rejectedWrites = 0;
  @override
  Future<bool> setValue(String type, String key, Object value) async {
    if (reject && key.endsWith('scores_pilot-class_pilot-item')) {
      rejectedWrites++;
      if (throws) throw StateError('Fictional rejected score write');
      return false;
    }
    return super.setValue(type, key, value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final thrown in [false, true]) {
    test('reports ${thrown ? "thrown" : "refused"} save and accepts retry',
        () async {
      SharedPreferences.setMockInitialValues({});
      final store = RejectScoreStore()..throws = thrown;
      SharedPreferencesStorePlatform.instance = store;
      RepositoryFactory.useLocal();
      final service = StudentScoreService();
      addTearDown(() async {
        await service.flushPendingWrites();
        service.dispose();
        SharedPreferences.setMockInitialValues({});
        RepositoryFactory.useLocal();
      });
      final now = DateTime(2026);
      final score = StudentScore(
          studentId: 'fictional-pupil',
          gradeItemId: 'pilot-item',
          score: 80,
          createdAt: now,
          updatedAt: now);
      await expectLater(
          service.updateScore(score, 'fictional-teacher', 'pilot-class'),
          throwsStateError);
      expect(store.rejectedWrites, 1);
      await service.flushPendingWrites();
      expect(service.hasPendingWrites, isFalse);
      expect(service.getScore('fictional-pupil', 'pilot-item'), isNull);
      await (await SharedPreferences.getInstance()).reload();
      expect(
          await RepositoryFactory.instance
              .loadScores('pilot-class', 'pilot-item'),
          isEmpty);
      expect(await RepositoryFactory.instance.loadScoreHistory('pilot-class'),
          isEmpty);
      store.reject = false;
      await service.updateScore(score, 'fictional-teacher', 'pilot-class');
      await (await SharedPreferences.getInstance()).reload();
      expect(
          (await RepositoryFactory.instance
                  .loadScores('pilot-class', 'pilot-item'))
              .single
              .score,
          80);
      expect(
          (await RepositoryFactory.instance.loadScoreHistory('pilot-class'))
              .length,
          1);
    });
  }
}

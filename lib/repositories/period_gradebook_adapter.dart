import '../models/class.dart';
import '../models/student.dart';
import '../models/grade_item.dart';
import '../models/grading_category.dart';
import '../models/student_score.dart';
import '../models/final_exam.dart';
import '../models/change_history.dart';
import '../services/grading_period_ui_controller.dart';
import 'data_repository.dart';

/// Bridge used solely by the existing gradebook's injected service instances.
/// Unsupported operations fail closed instead of falling back to local/cloud.
class PeriodGradebookAdapter implements DataRepository {
  final GradingPeriodUiController session;
  final Class classRecord;
  PeriodGradebookAdapter(this.session, this.classRecord) {
    if (classRecord.classId != session.classId ||
        classRecord.teacherId != session.repository.ownerId)
      throw ArgumentError('Wrong class/owner');
  }
  void _scope(String id) {
    if (id != session.classId) throw StateError('Wrong class');
  }

  @override
  Future<List<Class>> loadClasses() async => [classRecord];
  @override
  Future<List<Student>> loadStudents(String id) async {
    _scope(id);
    return session.selected.dataset.students.toList();
  }

  @override
  Future<List<GradingCategory>> loadCategories(String id) async {
    _scope(id);
    return session.selected.dataset.categories.toList();
  }

  @override
  Future<List<GradeItem>> loadGradeItems(String id) async {
    _scope(id);
    return session.selected.dataset.assessments.toList();
  }

  @override
  Future<List<StudentScore>> loadScores(String id, String item) async {
    _scope(id);
    return session.selected.dataset.scores
        .where((s) => s.gradeItemId == item)
        .toList();
  }

  @override
  Future<List<FinalExam>> loadExams(String id) async {
    _scope(id);
    return session.selected.dataset.exams.toList();
  }

  @override
  Future<void> saveGradeItems(String id, List<GradeItem> values) {
    _scope(id);
    return session.mutate(
        'assessments', [...session.selected.dataset.assessments.where((a) => !values.any((v) => v.gradeItemId == a.gradeItemId)).map((a) => a.toJson()), ...values.map((v) => v.toJson())]);
  }

  @override
  Future<void> saveCategories(String id, List<GradingCategory> values) {
    _scope(id);
    return session.mutate('categories', [...session.selected.dataset.categories.where((a) => !values.any((v) => v.categoryId == a.categoryId)).map((a) => a.toJson()), ...values.map((v) => v.toJson())]);
  }

  @override
  Future<void> saveScores(String id, String item, List<StudentScore> values) {
    _scope(id);
    if (values.any((v) => v.gradeItemId != item))
      throw ArgumentError('Wrong assessment');
    return session.mutate('scores', [
      ...session.selected.dataset.scores
          .where((s) => s.gradeItemId != item)
          .map((s) => s.toJson()),
      ...values.map((s) => s.toJson()),
    ]);
  }

  @override
  Future<List<ChangeHistory>> loadScoreHistory(String id,
      {int limit = 100}) async {
    _scope(id);
    return [];
  }

  @override
  Future<void> addScoreHistory(String id, ChangeHistory entry,
      {int maxEntries = 100}) async {
    _scope(id);
  }

  @override
  Future<bool> hasPendingWrites() async => session.busy;
  @override
  Future<void> flushPendingWrites() async {
    if (session.busy) throw StateError('Saving');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError(
      'Not available in the isolated grading-period gradebook');
}

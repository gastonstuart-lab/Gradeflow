import '../models/grading_period.dart';
import '../models/student_score.dart';
import '../repositories/data_repository.dart';

/// Captures the native gradebook's stored records, not inferred display
/// values. Only called from the synthetic review entry until a trusted
/// transactional migration of real records has been approved.
class NativePeriodSnapshot {
  static Future<GradebookDataset> capture(DataRepository repo, {
    required String ownerId, required String classId,
  }) async {
    final record = (await repo.loadClasses()).singleWhere(
        (c) => c.classId == classId && c.teacherId == ownerId);
    final students = await repo.loadStudents(classId);
    final categories = await repo.loadCategories(classId);
    final items = await repo.loadGradeItems(classId);
    final scores = <StudentScore>[];
    for (final item in items) {
      final rows = await repo.loadScores(classId, item.gradeItemId);
      if (rows.any((s) => s.gradeItemId != item.gradeItemId)) {
        throw StateError('Assessment scope mismatch');
      }
      scores.addAll(rows);
    }
    return GradebookDataset.fromLegacy(classRecord: record,
        courseworkWeightPercent: record.courseworkWeightPercent,
        students: students, categories: categories, assessments: items,
        scores: scores, exams: await repo.loadExams(classId));
  }
}

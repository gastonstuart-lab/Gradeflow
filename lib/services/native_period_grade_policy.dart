import '../models/grading_period.dart';
import '../models/grading_category.dart';

/// Frozen native-v2 policy matching GradebookWorkspace at verified revision
/// 9c79f56. Missing scores remain missing, not full marks. No pseudo totals.
class NativePeriodGradePolicy {
  static String canonical(String name) {
    final n = name.toLowerCase();
    if (n.contains('quiz')) return 'Quizzes';
    for (final k in ['Participation', 'Homework', 'Classwork']) {
      if (n.contains(k.toLowerCase())) return k;
    }
    return name;
  }

  static Map<String, double?> calculate(GradebookDataset data, String student) {
    final split = data.courseworkWeightPercent;
    if (split == null) throw StateError('Native snapshot is missing saved coursework percentage');
    final categories = data.categories.where((c) => c.isActive).toList();
    final marks = {for (final s in data.scores.where((s) => s.studentId == student))
      s.gradeItemId: s.score};
    final result = <String, double?>{};
    for (final c in categories) {
      final items = data.assessments.where((a) => a.isActive &&
          a.categoryId == c.categoryId && a.name.toLowerCase() != 'category total').toList();
      result[c.categoryId] = items.isEmpty ||
          items.any((a) => a.maxScore <= 0 || marks[a.gradeItemId] == null)
          ? null : items.fold<double>(0, (sum, a) =>
              sum + marks[a.gradeItemId]! / a.maxScore * 100) / items.length;
    }
    final matches = categories.length == 4 &&
        categories.every((c) => c.weightPercent > 0 && c.weightPercent.isFinite &&
            c.aggregationMethod == AggregationMethod.average) &&
        ['Participation', 'Homework', 'Quizzes', 'Classwork'].every((name) =>
            categories.where((c) => canonical(c.name) == name).length == 1) &&
        (categories.fold<double>(0, (sum, c) => sum + c.weightPercent) - 100).abs() < .001;
    double? process;
    if (matches && result.values.every((v) => v != null)) {
      process = categories.fold<double>(0, (sum, c) =>
          sum + result[c.categoryId]! * c.weightPercent / 100);
    }
    final exam = data.exams.where((e) => e.studentId == student).firstOrNull?.examScore;
    return {...result, 'processScore': process, 'examScore': exam,
      'finalGrade': process == null || exam == null ? null :
          process * split / 100 + exam * (100 - split) / 100};
  }
}

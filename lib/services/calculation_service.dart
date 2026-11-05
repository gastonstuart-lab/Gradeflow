import 'package:gradeflow/models/grading_category.dart';
import 'package:gradeflow/models/grade_item.dart';
import 'package:gradeflow/models/student_score.dart';
import 'package:gradeflow/models/final_exam.dart';

class CalculationService {
  double? calculateCategoryScore(
    GradingCategory category,
    List<GradeItem> items,
    List<StudentScore> scores,
  ) {
    final assessments = items
        .where((i) => i.isActive && i.name.toLowerCase() != 'category total')
        .toList();
    if (assessments.isEmpty) return null;
    final itemScores = <double>[];
    for (final item in assessments) {
      if (!item.maxScore.isFinite || item.maxScore <= 0) return null;
      final existing =
          scores.where((s) => s.gradeItemId == item.gradeItemId).firstOrNull;
      final value = existing?.score;
      if (value == null ||
          !value.isFinite ||
          value < 0 ||
          value > item.maxScore) return null;
      itemScores.add(value / item.maxScore * 100);
    }
    switch (category.aggregationMethod) {
      case AggregationMethod.average:
        return itemScores.reduce((a, b) => a + b) / itemScores.length;

      case AggregationMethod.sum:
        return itemScores.reduce((a, b) => a + b);

      case AggregationMethod.bestN:
        if (category.aggregationParam == null ||
            category.aggregationParam! <= 0 ||
            category.aggregationParam! > itemScores.length) return null;
        itemScores.sort((a, b) => b.compareTo(a));
        final topN = itemScores.take(category.aggregationParam!).toList();
        return topN.reduce((a, b) => a + b) / topN.length;

      case AggregationMethod.dropLowestN:
        if (category.aggregationParam == null ||
            category.aggregationParam! < 0 ||
            category.aggregationParam! >= itemScores.length) return null;
        itemScores.sort((a, b) => a.compareTo(b));
        final dropped = itemScores.skip(category.aggregationParam!).toList();
        if (dropped.isEmpty) return null;
        return dropped.reduce((a, b) => a + b) / dropped.length;
    }
  }

  double? calculateProcessScore(
    List<GradingCategory> categories,
    List<GradeItem> allItems,
    List<StudentScore> studentScores,
  ) {
    final activeCategories = categories.where((c) => c.isActive).toList();
    if (activeCategories.isEmpty ||
        activeCategories
            .any((c) => !c.weightPercent.isFinite || c.weightPercent < 0))
      return null;
    final totalWeight =
        activeCategories.fold<double>(0, (sum, c) => sum + c.weightPercent);
    if ((totalWeight - 100).abs() > .001) return null;
    double weighted = 0;
    for (final category in activeCategories.where((c) => c.weightPercent > 0)) {
      final items = allItems
          .where((i) => i.categoryId == category.categoryId && i.isActive)
          .toList();
      final score = calculateCategoryScore(category, items, studentScores);
      if (score == null) return null;
      weighted += score * category.weightPercent / 100;
    }
    return weighted;
  }

  double? calculateFinalGrade(double? processScore, FinalExam? exam) {
    if (processScore == null ||
        !processScore.isFinite ||
        exam == null ||
        exam.examScore == null ||
        !validateScore(exam.examScore)) return null;

    return (processScore * 0.40) + (exam.examScore! * 0.60);
  }

  Map<String, double?> calculateStudentGrades(
    String studentId,
    List<GradingCategory> categories,
    List<GradeItem> allItems,
    List<StudentScore> allScores,
    FinalExam? exam,
  ) {
    final studentScores =
        allScores.where((s) => s.studentId == studentId).toList();

    final categoryScores = <String, double?>{};
    for (var category in categories) {
      final categoryItems = allItems
          .where((i) => i.categoryId == category.categoryId && i.isActive)
          .toList();
      categoryScores[category.categoryId] =
          calculateCategoryScore(category, categoryItems, studentScores);
    }

    final processScore =
        calculateProcessScore(categories, allItems, studentScores);
    final finalGrade = calculateFinalGrade(processScore, exam);

    return {
      ...categoryScores,
      'processScore': processScore,
      'examScore': exam?.examScore,
      'finalGrade': finalGrade,
    };
  }

  bool validateScore(double? score) {
    if (score == null) return true;
    return score >= 0 && score <= 100;
  }
}

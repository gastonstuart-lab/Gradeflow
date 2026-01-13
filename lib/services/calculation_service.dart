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
    if (items.isEmpty) return null;
    
    final itemScores = items.map((item) {
      final score = scores.firstWhere(
        (s) => s.gradeItemId == item.gradeItemId,
        orElse: () => StudentScore(
          studentId: '',
          gradeItemId: item.gradeItemId,
          score: null,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      return score.score != null ? (score.score! / item.maxScore) * 100 : null;
    }).where((s) => s != null).cast<double>().toList();
    
    if (itemScores.isEmpty) return null;
    
    switch (category.aggregationMethod) {
      case AggregationMethod.average:
        return itemScores.reduce((a, b) => a + b) / itemScores.length;
        
      case AggregationMethod.sum:
        return itemScores.reduce((a, b) => a + b);
        
      case AggregationMethod.bestN:
        if (category.aggregationParam == null) return null;
        itemScores.sort((a, b) => b.compareTo(a));
        final topN = itemScores.take(category.aggregationParam!).toList();
        return topN.reduce((a, b) => a + b) / topN.length;
        
      case AggregationMethod.dropLowestN:
        if (category.aggregationParam == null) return null;
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
    if (activeCategories.isEmpty) return null;
    double weightedSum = 0.0;
    double totalWeight = 0.0;
    for (var category in activeCategories) {
      final categoryItems = allItems.where((i) => i.categoryId == category.categoryId && i.isActive).toList();
      final categoryScore = calculateCategoryScore(category, categoryItems, studentScores);
      if (categoryScore != null) {
        weightedSum += categoryScore * category.weightPercent;
        totalWeight += category.weightPercent;
      }
    }
    if (totalWeight == 0) return null;
    return weightedSum / totalWeight; // normalized 0–100
  }

  double? calculateFinalGrade(double? processScore, FinalExam? exam) {
    if (processScore == null || exam == null || exam.examScore == null) return null;
    
    return (processScore * 0.40) + (exam.examScore! * 0.60);
  }

  Map<String, double?> calculateStudentGrades(
    String studentId,
    List<GradingCategory> categories,
    List<GradeItem> allItems,
    List<StudentScore> allScores,
    FinalExam? exam,
  ) {
    final studentScores = allScores.where((s) => s.studentId == studentId).toList();
    
    final categoryScores = <String, double?>{};
    for (var category in categories) {
      final categoryItems = allItems.where((i) => i.categoryId == category.categoryId && i.isActive).toList();
      categoryScores[category.categoryId] = calculateCategoryScore(category, categoryItems, studentScores);
    }
    
    final processScore = calculateProcessScore(categories, allItems, studentScores);
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

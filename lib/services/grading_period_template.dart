import '../models/grade_item.dart';
import '../models/grading_category.dart';
import '../models/grading_period.dart';

class GradingPeriodTemplate {
  static GradingPeriod create(
      {required GradebookDataset context,
      required String periodId,
      required String label,
      required DateTime at,
      Map<AssessmentKind, double>? weights}) {
    if (weights != null &&
        (weights.length != AssessmentKind.values.length ||
            AssessmentKind.values.any((k) =>
                !weights.containsKey(k) ||
                !weights[k]!.isFinite ||
                weights[k]! < 0) ||
            weights.values.fold(0.0, (a, b) => a + b) <= 0)) {
      throw ArgumentError('Provide all four category weights');
    }
    const names = ['Quiz', 'Classwork', 'Homework', 'Participation'];
    final native = context.courseworkWeightPercent != null;
    final effectiveWeights = weights ?? (native ? _nativeWeights(context) : null);
    if (native && (effectiveWeights!.values.any((w) => !w.isFinite || w <= 0) ||
        (effectiveWeights.values.fold<double>(0, (a, b) => a + b) - 100).abs() >= .001)) {
      throw ArgumentError('Native category weights must be positive and total 100');
    }
    final categories = [
      for (final kind in AssessmentKind.values)
        GradingCategory(
            categoryId: '$periodId:${kind.name}',
            classId: context.classId,
            name: names[kind.index],
            weightPercent: effectiveWeights?[kind] ?? 25,
            aggregationMethod: AggregationMethod.average,
            isActive: true,
            createdAt: at,
            updatedAt: at)
    ];
    final items = [
      for (final kind in AssessmentKind.values)
        for (var n = 1; n <= (kind == AssessmentKind.quiz ? 2 : 6); n++)
          GradeItem(
              gradeItemId: '$periodId:${kind.name}:$n',
              classId: context.classId,
              categoryId: categories[kind.index].categoryId,
              name: '${names[kind.index]} $n',
              maxScore: 100,
              isActive: true,
              createdAt: at,
              updatedAt: at)
    ];
    return GradingPeriod(
        periodId: periodId,
        label: label,
        createdAt: at,
        policyVersion: native ? GradingPeriod.nativeCalculationVersion : GradingPeriod.calculationVersion,
        dataset: GradebookDataset(
            ownerId: context.ownerId,
            classId: context.classId,
            className: context.className,
            subject: context.subject,
            groupNumber: context.groupNumber,
            schoolYear: context.schoolYear,
            term: context.term,
            courseworkWeightPercent: context.courseworkWeightPercent,
            students: context.students,
            categories: categories,
            assessments: items,
            scores: [],
            exams: []));
  }

  static Map<AssessmentKind, double> _nativeWeights(GradebookDataset context) {
    if (context.categories.isEmpty) {
      return const {
        AssessmentKind.quiz: 30, AssessmentKind.classwork: 20,
        AssessmentKind.homework: 30, AssessmentKind.participation: 20,
      };
    }
    final active = context.categories.where((c) => c.isActive).toList();
    if (active.length != 4 || active.any((c) => c.aggregationMethod != AggregationMethod.average)) {
      throw StateError('Review native grading category policy before rollover');
    }
    return {
      for (final kind in AssessmentKind.values)
        kind: active.singleWhere((c) => c.name.toLowerCase().contains(kind.name)).weightPercent,
    };
  }
}

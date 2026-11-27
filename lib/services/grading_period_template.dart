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
    final categories = [
      for (final kind in AssessmentKind.values)
        GradingCategory(
            categoryId: '$periodId:${kind.name}',
            classId: context.classId,
            name: names[kind.index],
            weightPercent: weights?[kind] ?? 25,
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
        dataset: GradebookDataset(
            ownerId: context.ownerId,
            classId: context.classId,
            className: context.className,
            subject: context.subject,
            groupNumber: context.groupNumber,
            schoolYear: context.schoolYear,
            term: context.term,
            students: context.students,
            categories: categories,
            assessments: items,
            scores: [],
            exams: []));
  }
}

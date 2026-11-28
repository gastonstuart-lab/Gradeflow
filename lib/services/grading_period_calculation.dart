import '../models/grading_category.dart';
import '../models/grading_period.dart';
import 'calculation_service.dart';
import 'native_period_grade_policy.dart';

class GradingPeriodCalculation {
  final CalculationService _calculation;
  GradingPeriodCalculation({CalculationService? calculation})
      : _calculation = calculation ?? CalculationService();
  Map<String, Map<String, double?>> calculate(GradingPeriod period) {
    final native = period.policyVersion == GradingPeriod.nativeCalculationVersion;
    if (!native && period.policyVersion != GradingPeriod.calculationVersion) {
      throw UnsupportedError('Unknown historical calculation policy');
    }
    final data = period.dataset;
    if (native != (data.courseworkWeightPercent != null)) {
      throw StateError('Snapshot and calculation policy do not match');
    }
    // Do not normalize/repair historical inputs or emit NaN/Infinity silently.
    if (data.assessments.any((a) => !a.maxScore.isFinite || a.maxScore <= 0) ||
        data.categories.any((c) =>
            !c.weightPercent.isFinite ||
            (c.aggregationMethod == AggregationMethod.bestN &&
                (c.aggregationParam ?? 0) <= 0) ||
            (c.aggregationMethod == AggregationMethod.dropLowestN &&
                (c.aggregationParam == null || c.aggregationParam! < 0)))) {
      throw StateError('Historical calculation inputs require review');
    }
    final exams = {for (final e in data.exams) e.studentId: e};
    final grades = <String, Map<String, double?>>{};
    for (final student in data.students) {
      grades[student.studentId] = Map.unmodifiable(native
          ? NativePeriodGradePolicy.calculate(data, student.studentId)
          : _calculation.calculateStudentGrades(
              student.studentId,
              data.categories.where((c) => c.isActive).toList(),
              data.assessments,
              data.scores,
              exams[student.studentId]));
    }
    if (grades.values
        .any((g) => g.values.any((v) => v != null && !v.isFinite))) {
      throw StateError('Nonfinite historical calculation');
    }
    if (period.isSealed) {
      // Stored results are evidence, not permission to silently change policy.
      final frozen = period.results!;
      if (grades.length != frozen.length ||
          grades.entries.any((row) {
            final expected = frozen[row.key];
            return expected == null ||
                expected.length != row.value.length ||
                row.value.entries.any((cell) =>
                    !expected.containsKey(cell.key) ||
                    expected[cell.key] != cell.value);
          })) {
        throw StateError('Historical result parity failure');
      }
      return frozen;
    }
    return Map.unmodifiable(grades);
  }
}

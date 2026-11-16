import 'package:gradeflow/models/final_exam.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/services/calculation_service.dart';
import 'package:gradeflow/models/grade_item.dart';
import 'package:gradeflow/models/grading_category.dart';
import 'package:gradeflow/models/student_score.dart';

void main() {
  final now = DateTime(2026, 11, 5);
  final calc = CalculationService();
  GradingCategory category(String id, double weight) => GradingCategory(
      categoryId: id,
      classId: 'class',
      name: id,
      weightPercent: weight,
      aggregationMethod: AggregationMethod.average,
      isActive: true,
      createdAt: now,
      updatedAt: now);
  GradeItem item(String id, String category, {double max = 100}) => GradeItem(
      gradeItemId: id,
      classId: 'class',
      categoryId: category,
      name: id,
      maxScore: max,
      isActive: true,
      createdAt: now,
      updatedAt: now);
  StudentScore score(String id, double? value) => StudentScore(
      studentId: 'student',
      gradeItemId: id,
      score: value,
      createdAt: now,
      updatedAt: now);
  test(
      'absent and cleared scores stay incomplete instead of becoming full marks',
      () {
    expect(
        calc.calculateCategoryScore(
            category('work', 100), [item('quiz', 'work')], []),
        isNull);
    expect(
        calc.calculateCategoryScore(category('work', 100),
            [item('quiz', 'work')], [score('quiz', null)]),
        isNull);
  });
  test('zero counts and different assessment maxima normalize correctly', () {
    expect(
        calc.calculateCategoryScore(
            category('work', 100),
            [item('one', 'work', max: 20), item('two', 'work')],
            [score('one', 0), score('two', 80)]),
        40);
  });
  test('partially entered assessments never make a completed category', () {
    expect(
        calc.calculateCategoryScore(category('work', 100),
            [item('one', 'work'), item('two', 'work')], [score('one', 80)]),
        isNull);
  });
  test('process requires each weighted category and valid stored weights', () {
    final cats = [category('one', 40), category('two', 60)];
    final items = [item('a', 'one'), item('b', 'two')];
    expect(calc.calculateProcessScore(cats, items, [score('a', 80)]), isNull);
    expect(
        calc.calculateProcessScore(
            cats, items, [score('a', 80), score('b', 90)]),
        86);
    expect(
        calc.calculateProcessScore(
            [category('one', 20)], items, [score('a', 80)]),
        isNull);
  });
  test('inactive items and category-total placeholders do not distort results',
      () {
    final inactive = item('ignored', 'work').copyWith(isActive: false);
    final placeholder = item('category total', 'work');
    expect(
        calc.calculateCategoryScore(category('work', 100),
            [item('one', 'work'), inactive, placeholder], [score('one', 70)]),
        70);
  });
  test('final grade honors custom split and rejects invalid policy', () {
    final now = DateTime(2026);
    final exam = FinalExam(studentId: 's', examScore: 60, createdAt: now, updatedAt: now);
    expect(calc.calculateFinalGrade(85, exam, courseworkWeightPercent: 70), 77.5);
    expect(calc.calculateFinalGrade(85, exam), 70);
    expect(calc.calculateFinalGrade(85, exam, courseworkWeightPercent: 0), 60);
    expect(calc.calculateFinalGrade(85, exam, courseworkWeightPercent: 100), 85);
    for (final weight in [-1.0, 101.0, double.nan, double.infinity]) {
      expect(calc.calculateFinalGrade(85, exam, courseworkWeightPercent: weight), isNull);
    }
    expect(calc.calculateFinalGrade(null, exam, courseworkWeightPercent: 70), isNull);
    expect(calc.calculateFinalGrade(85, null, courseworkWeightPercent: 70), isNull);
  });

  test('student results isolate marks from other students', () {
    final grades = calc.calculateStudentGrades('other', [category('work', 100)],
        [item('one', 'work')], [score('one', 99)], null);
    expect(grades['processScore'], isNull);
    expect(grades['finalGrade'], isNull);
  });
}

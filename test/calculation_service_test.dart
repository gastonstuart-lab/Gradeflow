import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/models/final_exam.dart';
import 'package:gradeflow/models/grade_item.dart';
import 'package:gradeflow/models/grading_category.dart';
import 'package:gradeflow/models/student_score.dart';
import 'package:gradeflow/services/calculation_service.dart';

final _now = DateTime(2026, 10, 6);

GradingCategory _category(String id,
        {double weight = 25,
        bool active = true,
        AggregationMethod method = AggregationMethod.average,
        int? param}) =>
    GradingCategory(
      categoryId: id,
      classId: 'synthetic-class',
      name: id,
      weightPercent: weight,
      aggregationMethod: method,
      aggregationParam: param,
      isActive: active,
      createdAt: _now,
      updatedAt: _now,
    );

GradeItem _item(String id,
        {String category = 'homework', double max = 100, bool active = true}) =>
    GradeItem(
      gradeItemId: id,
      classId: 'synthetic-class',
      categoryId: category,
      name: id,
      maxScore: max,
      isActive: active,
      createdAt: _now,
      updatedAt: _now,
    );

StudentScore _score(String item, double? value,
        {String student = 'synthetic-student'}) =>
    StudentScore(
      studentId: student,
      gradeItemId: item,
      score: value,
      createdAt: _now,
      updatedAt: _now,
    );

void main() {
  final service = CalculationService();

  test('no items or only explicitly cleared scores have no category result',
      () {
    expect(
        service.calculateCategoryScore(_category('homework'), [], []), isNull);
    expect(
      service.calculateCategoryScore(
          _category('homework'), [_item('a')], [_score('a', null)]),
      isNull,
    );
  });

  test('absent score row contributes full marks; explicit null is excluded',
      () {
    final items = [_item('a', max: 20), _item('b', max: 20)];
    expect(
      service.calculateCategoryScore(
          _category('homework'), items, [_score('a', 10)]),
      75,
    );
    expect(
      service.calculateCategoryScore(
          _category('homework'), items, [_score('a', 10), _score('b', null)]),
      50,
    );
    // This academic default says nothing about whether homework was submitted.
  });

  test('custom item maxima normalize each score before averaging', () {
    expect(
      service.calculateCategoryScore(
          _category('homework'),
          [_item('a', max: 20), _item('b', max: 40)],
          [_score('a', 15), _score('b', 20)]),
      62.5,
    );
  });

  for (final entry in {
    AggregationMethod.average: 70.0,
    AggregationMethod.sum: 210.0,
    AggregationMethod.bestN: 85.0,
    AggregationMethod.dropLowestN: 85.0,
  }.entries) {
    test('${entry.key.name} uses normalized, non-null item scores', () {
      expect(
        service.calculateCategoryScore(
            _category('homework',
                method: entry.key,
                param: entry.key == AggregationMethod.bestN ? 2 : 1),
            [
              _item('a'),
              _item('b'),
              _item('c'),
              _item('d')
            ],
            [
              _score('a', 40),
              _score('b', 70),
              _score('c', 100),
              _score('d', null)
            ]),
        entry.value,
      );
    });
  }

  test('best-N accepts fewer available scores; dropping all returns null', () {
    expect(
        service.calculateCategoryScore(
            _category('homework', method: AggregationMethod.bestN, param: 5),
            [_item('a')],
            [_score('a', 80)]),
        80);
    expect(
        service.calculateCategoryScore(
            _category('homework',
                method: AggregationMethod.dropLowestN, param: 1),
            [_item('a')],
            [_score('a', 80)]),
        isNull);
  });

  test('process weights normalize over active categories with results', () {
    final categories = [
      _category('homework', weight: 10),
      _category('participation', weight: 30),
      _category('empty', weight: 60),
      _category('retired', weight: 100, active: false),
    ];
    expect(
        service.calculateProcessScore(categories, [
          _item('a'),
          _item('b', category: 'participation'),
          _item('c', category: 'retired'),
          _item('d', active: false),
        ], [
          _score('a', 50),
          _score('b', 90),
          _score('c', 0),
          _score('d', 0)
        ]),
        80);
  });

  test('all-cleared category does not dilute another category weight', () {
    expect(
        service.calculateProcessScore(
          [
            _category('homework', weight: 75),
            _category('participation', weight: 25)
          ],
          [_item('a'), _item('b', category: 'participation')],
          [_score('a', null), _score('b', 60)],
        ),
        60);
    expect(
        service.calculateProcessScore([_category('homework', weight: 0)],
            [_item('a')], [_score('a', 60)]),
        isNull);
  });

  test('final grade requires process and exam; uses existing 40/60 weighting',
      () {
    final exam = FinalExam(
        studentId: 'synthetic-student',
        examScore: 90,
        createdAt: _now,
        updatedAt: _now);
    expect(service.calculateFinalGrade(50, exam), 74);
    expect(service.calculateFinalGrade(null, exam), isNull);
    expect(service.calculateFinalGrade(50, null), isNull);
    expect(
        service.calculateFinalGrade(
            50,
            FinalExam(
                studentId: 'synthetic-student',
                createdAt: _now,
                updatedAt: _now)),
        isNull);
  });

  test('student projection excludes another student score for the same item',
      () {
    final result = service.calculateStudentGrades(
        'synthetic-student',
        [_category('homework')],
        [_item('a')],
        [_score('a', 0, student: 'synthetic-other'), _score('a', 80)],
        null);
    expect(result['homework'], 80);
    expect(result['processScore'], 80);
    expect(result['examScore'], isNull);
    expect(result['finalGrade'], isNull);
  });
}

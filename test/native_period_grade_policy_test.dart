import 'dart:convert';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/models/grading_period.dart';
import 'package:gradeflow/services/historical_grade_export_adapter.dart';
import 'grading_period_test.dart' as fixture;

void main() {
  final adapter = HistoricalGradeExportAdapter();
  GradebookDataset native({bool incomplete = false}) => GradebookDataset.fromLegacy(
    classRecord: fixture.classRecord(), courseworkWeightPercent: 70,
    students: [fixture.pupil('one')],
    categories: [
      fixture.category('Quiz', 30), fixture.category('Homework', 30),
      fixture.category('Classwork', 20), fixture.category('Participation', 20),
    ],
    assessments: [
      fixture.assessment('q', 'Quiz', max: 20),
      fixture.assessment('h', 'Homework'), fixture.assessment('c', 'Classwork'),
      fixture.assessment('p', 'Participation'),
      fixture.assessment('total', 'Quiz').copyWith(name: 'Category Total'),
      fixture.assessment('inactive', 'Quiz', active: false),
    ],
    scores: [
      fixture.score('q', 16), fixture.score('h', 100),
      if (!incomplete) fixture.score('c', 90),
      fixture.score('p', 0), fixture.score('total', 0), fixture.score('inactive', 0),
    ],
    exams: fixture.legacy().exams,
  );

  test('native policy preserves 70/30 split, category weights, zero and ignored totals', () {
    final p = fixture.period(native(), policy: GradingPeriod.nativeCalculationVersion);
    final grades = adapter.calculate(p)['one']!;
    expect(grades['Quiz'], 80);
    expect(grades['Participation'], 0);
    expect(grades['processScore'], 72);
    expect(grades['finalGrade'], closeTo(77.4, .000001));
    final sealed = p.seal(fixture.at, adapter.calculate(p));
    final restored = GradingPeriod.fromJson(jsonDecode(jsonEncode(sealed.toJson())));
    expect(restored.toJson(), sealed.toJson());
    expect(adapter.calculate(restored), adapter.calculate(sealed));
    final bytes = adapter.generateXlsx(restored, ownerId: 'owner', classId: 'class');
    expect(fixture.cells(bytes).first, containsAll(['Process Score (70%)', 'Exam Score (30%)']));
    expect(fixture.cells(bytes)[1].last, '77.40');
    final combined = adapter.generateCombinedXlsx([restored], ownerId: 'owner', classIds: {'class'});
    expect(fixture.cells(combined).first, contains('Process Score (saved period weights)'));
    expect(Excel.decodeBytes(combined).tables['Periods']!.rows[1].last?.value.toString(), '30.0');
  });

  test('missing mark is not an automatic full grade; legacy stays unchanged', () {
    final p = fixture.period(native(incomplete: true), policy: GradingPeriod.nativeCalculationVersion);
    final grades = adapter.calculate(p)['one']!;
    expect(grades['Classwork'], isNull);
    expect(grades['processScore'], isNull);
    expect(grades['finalGrade'], isNull);
    final legacy = fixture.period(fixture.legacy());
    expect(legacy.dataset.toJson().containsKey('courseworkWeightPercent'), isFalse);
    expect(adapter.calculate(legacy)['one']!['finalGrade'], 84.5);
    expect(() => adapter.calculate(fixture.period(fixture.legacy(),
        policy: GradingPeriod.nativeCalculationVersion)), throwsStateError);
    expect(() => adapter.calculate(fixture.period(native())), throwsStateError);
  });
}

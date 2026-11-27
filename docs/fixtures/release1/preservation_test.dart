// Executed by flutter test; kept under docs for the fixture-only assignment.
// Analyzer recognizes test/ paths, so explicitly allow the test-only mock API.
// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:convert';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/models/class.dart';
import 'package:gradeflow/models/final_exam.dart';
import 'package:gradeflow/models/grade_item.dart';
import 'package:gradeflow/models/grading_category.dart';
import 'package:gradeflow/models/student.dart';
import 'package:gradeflow/models/student_score.dart';
import 'package:gradeflow/repositories/local_repository.dart';
import 'package:gradeflow/repositories/repository_factory.dart';
import 'package:gradeflow/services/calculation_service.dart';
import 'package:gradeflow/services/export_service.dart';
import 'package:gradeflow/services/grade_item_service.dart';
import 'package:gradeflow/services/student_score_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

final stamp = DateTime.utc(2026, 1, 1);
const classId = 'synthetic-class';
const counts = {'Quiz': 2, 'Classwork': 6, 'Homework': 6, 'Participation': 6};

GradingCategory category(String name, double weight,
        {AggregationMethod method = AggregationMethod.average, int? n}) =>
    GradingCategory(
      categoryId: name,
      classId: classId,
      name: name,
      weightPercent: weight,
      aggregationMethod: method,
      aggregationParam: n,
      isActive: true,
      createdAt: stamp,
      updatedAt: stamp,
    );

GradeItem item(String id, String cat, {double max = 100, bool active = true}) =>
    GradeItem(
      gradeItemId: id,
      classId: classId,
      categoryId: cat,
      name: id,
      maxScore: max,
      isActive: active,
      createdAt: stamp,
      updatedAt: stamp,
    );

StudentScore score(String id, double? value, {String sid = 'synthetic-1'}) =>
    StudentScore(
        studentId: sid,
        gradeItemId: id,
        score: value,
        createdAt: stamp,
        updatedAt: stamp);

Student student([String id = 'synthetic-1']) => Student(
    studentId: id,
    classId: classId,
    chineseName: '合成學生',
    englishFirstName: 'Synthetic',
    englishLastName: 'Student',
    seatNo: '01',
    createdAt: stamp,
    updatedAt: stamp);

List<List<String?>> cells(List<int> bytes) {
  final book = Excel.decodeBytes(bytes);
  return book.tables.values.first.rows
      .map((row) => row.map((cell) => cell?.value?.toString()).toList())
      .toList();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    RepositoryFactory.useLocal();
  });

  test(
      'missing is full marks; explicit null excluded; normalized max and weights',
      () {
    final calc = CalculationService();
    final cats = [category('Quiz', 75), category('Homework', 25)];
    final items = [
      item('q1', 'Quiz', max: 20),
      item('q2', 'Quiz'),
      item('h1', 'Homework'),
      item('h2', 'Homework'),
      item('inactive', 'Quiz', active: false)
    ];
    final scores = [
      score('q1', 10),
      score('h1', null),
      score('h2', 80),
      score('inactive', 0)
    ];
    final exam = FinalExam(
        studentId: 'synthetic-1',
        examScore: 90,
        createdAt: stamp,
        updatedAt: stamp);
    final grades =
        calc.calculateStudentGrades('synthetic-1', cats, items, scores, exam);
    expect(grades['Quiz'], 75); // 50% and absent=100%
    expect(grades['Homework'], 80); // null excluded
    expect(grades['processScore'], 76.25);
    expect(grades['finalGrade'], 84.5);
    expect(calc.calculateFinalGrade(76.25, null), isNull);
    expect(calc.calculateCategoryScore(cats.first, [], []), isNull);
    expect(
        calc.calculateCategoryScore(
            cats.first, [items.first], [score('q1', null)]),
        isNull);
  });

  test('aggregation policy must be frozen with raw scores', () {
    final calc = CalculationService();
    final items = [item('a', 'c'), item('b', 'c'), item('c', 'c')];
    final scores = [score('a', 20), score('b', 60), score('c', 100)];
    for (final entry in {
      AggregationMethod.average: 60.0,
      AggregationMethod.sum: 180.0,
      AggregationMethod.bestN: 80.0,
      AggregationMethod.dropLowestN: 80.0,
    }.entries) {
      expect(
          calc.calculateCategoryScore(
              category('c', 100,
                  method: entry.key,
                  n: entry.key == AggregationMethod.bestN ? 2 : 1),
              items,
              scores),
          entry.value);
    }
  });

  test('JSON snapshot preserves calculation and decoded XLSX after live edits',
      () async {
    final repo = LocalRepository();
    final cats = [category('Quiz', 100)];
    final items = [item('q1', 'Quiz', max: 20), item('q2', 'Quiz')];
    final scores = [score('q1', 10), score('q2', null)];
    final pupils = [student(), student('synthetic-no-exam')];
    final exams = [
      FinalExam(
          studentId: 'synthetic-1',
          examScore: 90,
          createdAt: stamp,
          updatedAt: stamp)
    ];
    await repo.saveStudents(classId, pupils);
    await repo.saveCategories(classId, cats);
    await repo.saveGradeItems(classId, items);
    for (final g in items) {
      await repo.saveScores(classId, g.gradeItemId,
          scores.where((s) => s.gradeItemId == g.gradeItemId).toList());
    }
    await repo.saveExams(classId, exams);
    final frozen = jsonEncode({
      'students': pupils.map((s) => s.toJson()).toList(),
      'categories': cats.map((c) => c.toJson()).toList(),
      'items': items.map((i) => i.toJson()).toList(),
      'scores': scores.map((s) => s.toJson()).toList(),
      'exams': exams.map((e) => e.toJson()).toList(),
    });
    Map<String, Map<String, double?>> grades(
            List<Student> ss,
            List<GradingCategory> cc,
            List<GradeItem> ii,
            List<StudentScore> sc,
            List<FinalExam> ee) =>
        {
          for (final s in ss)
            s.studentId: CalculationService().calculateStudentGrades(
                s.studentId,
                cc,
                ii,
                sc,
                ee.where((e) => e.studentId == s.studentId).firstOrNull)
        };
    final before = grades(pupils, cats, items, scores, exams);
    final beforeCells =
        cells(ExportService().generateXlsx(pupils, cats, before));
    expect(beforeCells[1], [
      'synthetic-1',
      '合成學生',
      'Synthetic Student',
      '50.00',
      '50.00',
      '90.00',
      '74.00'
    ]);
    expect(beforeCells[2].last, '');
    await repo.saveStudents(
        classId, [student().copyWith(englishFirstName: 'Renamed')]);
    await repo.saveCategories(
        classId, [cats.first.copyWith(name: 'Changed', weightPercent: 20)]);
    await repo.saveGradeItems(classId, [items.first.copyWith(maxScore: 50)]);
    await repo.saveScores(classId, 'q1', [score('q1', 0)]);
    await repo.saveExams(classId, []);
    final restored = jsonDecode(frozen) as Map<String, dynamic>;
    List<T> decode<T>(String key, T Function(Map<String, dynamic>) factory) =>
        (restored[key] as List)
            .map((e) => factory(Map<String, dynamic>.from(e)))
            .toList();
    final ss = decode('students', Student.fromJson);
    final cc = decode('categories', GradingCategory.fromJson);
    final ii = decode('items', GradeItem.fromJson);
    final sc = decode('scores', StudentScore.fromJson);
    final ee = decode('exams', FinalExam.fromJson);
    expect(grades(ss, cc, ii, sc, ee), before);
    final bytes =
        ExportService().generateXlsx(ss, cc, grades(ss, cc, ii, sc, ee));
    expect(cells(bytes), beforeCells);
    expect(Excel.decodeBytes(bytes).tables.values.first.rows[1][3]!.value,
        isA<TextCellValue>());
  });

  test('20 proposed defaults can all be edited through existing local service',
      () async {
    final repo = LocalRepository();
    final defaults = [
      for (final entry in counts.entries)
        for (var n = 1; n <= entry.value; n++)
          item('${entry.key} $n', entry.key)
    ];
    expect(defaults.length, 20);
    for (final entry in counts.entries) {
      expect(
          defaults.where((i) => i.categoryId == entry.key).length, entry.value);
    }
    await repo.saveGradeItems(classId, defaults);
    final svc = GradeItemService();
    await svc.loadGradeItems(classId);
    for (final original in List<GradeItem>.of(svc.gradeItems)) {
      await svc.updateGradeItem(
          original.copyWith(name: 'Edited ${original.name}', maxScore: 20));
    }
    final loaded = await repo.loadGradeItems(classId);
    expect(loaded.length, 20);
    expect(
        loaded.every((i) => i.name.startsWith('Edited ') && i.maxScore == 20),
        isTrue);
    // Fixture provides defaults; existing app does not yet create this template.
  });

  test('mock backup restore retains exact keys and academic values', () async {
    final repo = LocalRepository();
    await repo.saveClasses([
      Class(
          classId: classId,
          className: 'Synthetic class',
          subject: 'Test',
          schoolYear: '2026',
          term: 'Synthetic period',
          teacherId: 'synthetic-owner',
          createdAt: stamp,
          updatedAt: stamp)
    ]);
    await repo.saveStudents(classId, [student()]);
    await repo.saveGradeItems(classId, [item('q1', 'Quiz')]);
    await repo.saveCategories(classId, [category('Quiz', 100)]);
    await repo.saveScores(classId, 'q1', [score('q1', null)]);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('class_schedule_v1:synthetic-owner:$classId', '[]');
    await prefs.setString('seating_active_layout_$classId', 'synthetic-layout');
    await prefs.setString('synthetic-settings', '{"unchanged":true}');
    final backup = {for (final key in prefs.getKeys()) key: prefs.get(key)};
    final encoded = jsonEncode(backup);
    await prefs.clear(); // mock store only
    expect(prefs.getKeys(), isEmpty);
    SharedPreferences.setMockInitialValues(
        Map<String, Object>.from(jsonDecode(encoded)));
    final recovered = await SharedPreferences.getInstance();
    expect({for (final k in recovered.getKeys()) k: recovered.get(k)}, backup);
    expect((await repo.loadScores(classId, 'q1')).single.score, isNull);
    expect((await repo.loadStudents(classId)).single.chineseName, '合成學生');
    expect((await repo.loadClasses()).single.term, 'Synthetic period');
  });

  test('legacy precedence and baseline isolation hazards are explicit',
      () async {
    SharedPreferences.setMockInitialValues({
      'grade_items': jsonEncode([item('legacy', 'Quiz').toJson()]),
      'student_scores': jsonEncode([score('legacy', 35).toJson()]),
    });
    final repo = LocalRepository();
    expect((await repo.loadGradeItems(classId)).single.gradeItemId, 'legacy');
    // Legacy scores filter item identity only: no class/account boundary.
    expect(
        (await repo.loadScores('different-class', 'legacy')).single.score, 35);
    await repo.saveGradeItems(classId, []);
    expect(await repo.loadGradeItems(classId), isEmpty); // empty canonical wins
    RepositoryFactory.useLocal();
    expect(
        (await RepositoryFactory.instance.loadScores(classId, 'legacy')).length,
        1);
    // A new local repository instance is not an account namespace.
  });

  test('default seeding fills explicit null unless fillNulls is false',
      () async {
    final repo = LocalRepository();
    await repo.saveScores(classId, 'q1', [score('q1', null)]);
    final svc = StudentScoreService();
    await svc.ensureDefaultScoresForGradeItem(
        classId, 'q1', ['synthetic-1'], 100,
        fillNulls: false);
    expect((await repo.loadScores(classId, 'q1')).single.score, isNull);
    await svc.ensureDefaultScoresForGradeItem(
        classId, 'q1', ['synthetic-1'], 100);
    expect((await repo.loadScores(classId, 'q1')).single.score, 100);
  });

  test(
      'local class deletion leaves global legacy data available by old class ID',
      () async {
    SharedPreferences.setMockInitialValues({
      'grade_items': jsonEncode([item('legacy', 'Quiz').toJson()]),
      'student_scores': jsonEncode([score('legacy', 35).toJson()]),
    });
    final repo = LocalRepository();
    await repo.deleteClass(classId);
    expect((await repo.loadGradeItems(classId)).length, 1);
    expect((await repo.loadScores(classId, 'legacy')).single.score, 35);
  });

  test('1000 synthetic roster and score rows roundtrip locally', () async {
    final repo = LocalRepository();
    final pupils = [for (var n = 0; n < 1000; n++) student('synthetic-$n')];
    await repo.saveStudents(classId, pupils);
    await repo.saveScores(classId, 'q1',
        [for (final s in pupils) score('q1', 50, sid: s.studentId)]);
    expect((await repo.loadStudents(classId)).length, 1000);
    expect((await repo.loadScores(classId, 'q1')).length, 1000);
    // Not a Firestore batch, quota, browser storage or performance test.
  });
}

import 'dart:convert';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/models/class.dart';
import 'package:gradeflow/models/final_exam.dart';
import 'package:gradeflow/models/grade_item.dart';
import 'package:gradeflow/models/grading_category.dart';
import 'package:gradeflow/models/grading_period.dart';
import 'package:gradeflow/models/student.dart';
import 'package:gradeflow/models/student_score.dart';
import 'package:gradeflow/repositories/grading_period_repository.dart';
import 'package:gradeflow/repositories/local_repository.dart';
import 'package:gradeflow/services/calculation_service.dart';
import 'package:gradeflow/services/export_service.dart';
import 'package:gradeflow/services/grading_period_service.dart';
import 'package:gradeflow/services/grading_period_ui_controller.dart';
import 'package:gradeflow/services/historical_grade_export_adapter.dart';
import 'package:shared_preferences/shared_preferences.dart';

final at = DateTime.utc(2026, 1, 1);
Class classRecord({String owner = 'owner', String id = 'class'}) => Class(
    classId: id,
    teacherId: owner,
    className: 'Synthetic class',
    subject: 'Test',
    schoolYear: '2026',
    term: 'Original term',
    createdAt: at,
    updatedAt: at);
Student pupil(String id, {String classId = 'class'}) => Student(
    studentId: id,
    classId: classId,
    chineseName: '合成學生',
    englishFirstName: 'Synthetic',
    englishLastName: id,
    createdAt: at,
    updatedAt: at);
GradingCategory category(String id, double weight,
        {AggregationMethod method = AggregationMethod.average,
        int? n,
        bool active = true}) =>
    GradingCategory(
        categoryId: id,
        classId: 'class',
        name: id,
        weightPercent: weight,
        aggregationMethod: method,
        aggregationParam: n,
        isActive: active,
        createdAt: at,
        updatedAt: at);
GradeItem assessment(String id, String category,
        {double max = 100, bool active = true}) =>
    GradeItem(
        gradeItemId: id,
        classId: 'class',
        categoryId: category,
        name: id,
        maxScore: max,
        isActive: active,
        createdAt: at,
        updatedAt: at);
StudentScore score(String item, double? value, {String student = 'one'}) =>
    StudentScore(
        studentId: student,
        gradeItemId: item,
        score: value,
        createdAt: at,
        updatedAt: at);
GradebookDataset legacy(
        {List<GradingCategory>? categories,
        List<GradeItem>? items,
        List<StudentScore>? scores,
        List<FinalExam>? exams}) =>
    GradebookDataset.fromLegacy(
        classRecord: classRecord(),
        students: [pupil('one'), pupil('two')],
        categories:
            categories ?? [category('Quiz', 75), category('Homework', 25)],
        assessments: items ??
            [
              assessment('q1', 'Quiz', max: 20),
              assessment('q2', 'Quiz'),
              assessment('h1', 'Homework'),
              assessment('h2', 'Homework'),
              assessment('inactive', 'Quiz', active: false)
            ],
        scores: scores ??
            [
              score('q1', 10),
              score('h1', null),
              score('h2', 80),
              score('inactive', 0)
            ],
        exams: exams ??
            [
              FinalExam(
                  studentId: 'one', examScore: 90, createdAt: at, updatedAt: at)
            ]);
GradingPeriod period(GradebookDataset data,
        {String policy = GradingPeriod.calculationVersion}) =>
    GradingPeriod(
        periodId: 'old',
        label: 'Historical period',
        createdAt: at,
        dataset: data,
        policyVersion: policy);
List<List<String?>> cells(List<int> bytes) => Excel.decodeBytes(bytes)
    .tables
    .values
    .first
    .rows
    .map((r) => r.map((c) => c?.value?.toString()).toList())
    .toList();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late InMemoryGradingPeriodRepository repo;
  late GradingPeriodService service;
  late HistoricalGradeExportAdapter adapter;
  setUp(() {
    repo = InMemoryGradingPeriodRepository(ownerId: 'owner');
    service = GradingPeriodService(repo);
    adapter = HistoricalGradeExportAdapter();
  });
  Future<GradingPeriodBook> create() => service.create(
      context: legacy(), periodId: 'new', label: 'New period', at: at);
  Future<GradingPeriodBook> archiveLegacy() async {
    await service.adoptLegacy(
        dataset: legacy(), periodId: 'old', label: 'Old period', at: at);
    return service.rollover(
        classId: 'class',
        periodId: 'old',
        expectedRevision: 0,
        nextPeriodId: 'new',
        label: 'New period',
        at: at.add(const Duration(days: 1)));
  }

  test(
    'period UI rejects a second rollover while retaining the first',
    () async {
      SharedPreferences.setMockInitialValues({});
      await create();
      final session = GradingPeriodUiController(repo, 'class');
      addTearDown(session.dispose);
      await session.initialize();

      final first = session.start('First request');
      final second = expectLater(
        session.start('Second request'),
        throwsStateError,
      );
      await Future.wait([first, second]);

      final book = (await repo.load('class'))!;
      expect(book.active.label, 'First request');
      expect(book.active.dataset.assessments, hasLength(20));
      expect(book.periods.where((period) => period.isSealed), hasLength(1));
      expect(session.pending, isNull);
    },
  );

  test('creates one active period and all 20 deterministic default assessments',
      () async {
    final book = await create();
    expect(book.activePeriodId, 'new');
    expect(book.revision, 0);
    expect(book.periods.where((p) => !p.isSealed).length, 1);
    final data = book.active.dataset;
    expect(data.assessments.length, 20);
    for (final c in data.categories) {
      expect(data.assessments.where((a) => a.categoryId == c.categoryId).length,
          c.name == 'Quiz' ? 2 : 6);
      expect(c.weightPercent, 25);
    }
    expect(
        data.assessments.map((a) => a.name),
        containsAll([
          'Quiz 1',
          'Quiz 2',
          'Classwork 6',
          'Homework 6',
          'Participation 6'
        ]));
    expect(
        data.assessments.every((a) => a.isActive && a.maxScore == 100), isTrue);
    expect(data.scores, isEmpty);
    expect(data.exams, isEmpty);
    expect(data.students.map((s) => s.toJson()),
        legacy().students.map((s) => s.toJson()));
    expect((await repo.load('class'))!.activePeriodId, 'new');
    final repeated = GradingPeriodService.defaultPeriod(
        context: legacy(), periodId: 'new', label: 'New period', at: at);
    expect(repeated.toJson(), book.active.toJson());
  });

  test('combined historical summary matches legacy layout with frozen metadata',
      () async {
    final old = (await archiveLegacy()).periods.first;
    final bytes = adapter.generateCombinedXlsx([old],
        ownerId: 'owner', classIds: {'class'});
    final rows = cells(bytes);
    expect(rows.first, [
      'Class',
      'Subject',
      'School Year',
      'Term',
      'Student ID',
      'Chinese Name',
      'English Name',
      'Quiz',
      'Homework',
      'Process Score (40%)',
      'Exam Score (60%)',
      'Final Grade'
    ]);
    expect(rows[1], [
      'Synthetic class',
      'Test',
      '2026',
      'Original term',
      'one',
      '合成學生',
      'Synthetic one',
      '75.00',
      '80.00',
      '76.25',
      '90.00',
      '84.50'
    ]);
    final metadata = Excel.decodeBytes(bytes).tables['Periods']!.rows;
    expect(metadata[1].map((c) => c?.value?.toString()), [
      'class',
      'old',
      'Old period',
      GradingPeriod.calculationVersion,
      'Synthetic class',
      'Test',
      '2026',
      'Original term'
    ]);
    for (final args in [
      ([old, old], 'owner', {'class'}),
      ([old], 'other', {'class'}),
      ([old], 'owner', {'other'})
    ]) {
      expect(
          () => adapter.generateCombinedXlsx(args.$1,
              ownerId: args.$2, classIds: args.$3),
          throwsStateError);
    }
  });

  test(
      'combined export rejects duplicate active category labels rather than dropping data',
      () {
    final data = legacy(categories: [
      category('Quiz', 75),
      category('Homework', 25).copyWith(name: 'Quiz')
    ]);
    final p = period(data);
    final sealed = p.seal(at, adapter.calculate(p));
    expect(
        () => adapter.generateCombinedXlsx([sealed],
            ownerId: 'owner', classIds: {'class'}),
        throwsStateError);
  });

  test(
      'same period and student IDs remain isolated across independent classes and accounts',
      () async {
    final first = await create();
    final context = GradebookDataset.fromLegacy(
        classRecord: classRecord(id: 'second'),
        students: [pupil('one', classId: 'second')],
        categories: [],
        assessments: [],
        scores: [],
        exams: []);
    final second = await service.create(
        context: context, periodId: 'new', label: 'Second', at: at);
    await service.deleteAssessment(
        classId: 'second',
        periodId: 'new',
        expectedRevision: 0,
        assessmentId: second.active.dataset.assessments.first.gradeItemId,
        at: at);
    expect((await repo.load('class'))!.toJson(), first.toJson());
    final other = InMemoryGradingPeriodRepository(ownerId: 'other');
    final otherContext = GradebookDataset.fromLegacy(
        classRecord: classRecord(owner: 'other'),
        students: [pupil('one')],
        categories: [],
        assessments: [],
        scores: [],
        exams: []);
    await GradingPeriodService(other)
        .create(context: otherContext, periodId: 'new', label: 'Other', at: at);
    expect((await other.load('class'))!.ownerId, 'other');
    expect((await repo.load('class'))!.ownerId, 'owner');
  });

  test(
      'source lists include inactive categories and former-student raw records without rewriting',
      () {
    final data = legacy(categories: [
      category('Quiz', 75),
      category('Homework', 25, active: false)
    ], scores: [
      score('q1', null),
      score('q2', 0),
      score('q1', 17, student: 'former')
    ]);
    final p = period(data);
    final sealed = p.seal(at, adapter.calculate(p));
    final restored =
        GradingPeriod.fromJson(jsonDecode(jsonEncode(sealed.toJson())));
    expect(restored.dataset.toJson(), data.toJson());
    expect(adapter.calculate(restored)['one']!['processScore'], 0);
    expect(restored.dataset.scores.last.studentId, 'former');
    expect(
        cells(adapter.generateXlsx(restored,
                ownerId: 'owner', classId: 'class'))
            .first,
        isNot(contains('Homework')));
  });

  test('duplicate creation and stale revisions are rejected', () async {
    final book = await create();
    await expectLater(create(), throwsStateError);
    await service.putAssessment(
        classId: 'class',
        periodId: 'new',
        expectedRevision: 0,
        assessment:
            book.active.dataset.assessments.first.copyWith(name: 'Edited'));
    await expectLater(
        service.putAssessment(
            classId: 'class',
            periodId: 'new',
            expectedRevision: 0,
            assessment: book.active.dataset.assessments.last),
        throwsStateError);
  });

  test(
      'every default can be edited, extras added, and delete is soft without reseed',
      () async {
    var book = await create();
    for (final a in List.of(book.active.dataset.assessments)) {
      book = await service.putAssessment(
          classId: 'class',
          periodId: 'new',
          expectedRevision: book.revision,
          assessment: a.copyWith(name: 'Edited ${a.name}', maxScore: 20));
    }
    expect(
        book.active.dataset.assessments
            .every((a) => a.name.startsWith('Edited ') && a.maxScore == 20),
        isTrue);
    final extra =
        assessment('extra', book.active.dataset.categories.last.categoryId);
    book = await service.putAssessment(
        classId: 'class',
        periodId: 'new',
        expectedRevision: book.revision,
        assessment: extra);
    expect(book.active.dataset.assessments.length, 21);
    book = await service.deleteAssessment(
        classId: 'class',
        periodId: 'new',
        expectedRevision: book.revision,
        assessmentId: extra.gradeItemId,
        at: at);
    expect(book.active.dataset.assessments.where((a) => a.isActive).length, 20);
    expect(book.active.dataset.assessments.last.isActive, isFalse);
    expect((await repo.load('class'))!.active.dataset.assessments.length, 21);
    await expectLater(
        service.deleteAssessment(
            classId: 'class',
            periodId: 'new',
            expectedRevision: book.revision,
            assessmentId: 'unknown',
            at: at),
        throwsArgumentError);
  });

  test(
      'rollover seals the exact old data and atomically advances one active pointer',
      () async {
    final original = legacy();
    final book = await archiveLegacy();
    final old = book.periods.first;
    expect(old.isSealed, isTrue);
    expect(old.dataset.toJson(), original.toJson());
    expect(old.results!['one']!['processScore'], 76.25);
    expect(old.results!['one']!['finalGrade'], 84.5);
    expect(book.active.dataset.assessments.length, 20);
    expect(book.active.dataset.scores, isEmpty);
    expect(book.active.dataset.exams, isEmpty);
    await expectLater(
        service.rollover(
            classId: 'class',
            periodId: 'old',
            expectedRevision: 0,
            nextPeriodId: 'third',
            label: 'Third',
            at: at),
        throwsStateError);
  });

  test(
      'two concurrent creations or rollovers cannot produce two active periods',
      () async {
    var successes = 0;
    var failures = 0;
    await Future.wait([create(), create()].map((f) => f.then((_) {
          successes++;
        }, onError: (_) {
          failures++;
        })));
    expect([successes, failures], [1, 1]);
    successes = 0;
    failures = 0;
    await Future.wait(['next-a', 'next-b'].map((id) => service
            .rollover(
                classId: 'class',
                periodId: 'new',
                expectedRevision: 0,
                nextPeriodId: id,
                label: id,
                at: at)
            .then((_) {
          successes++;
        }, onError: (_) {
          failures++;
        })));
    expect([successes, failures], [1, 1]);
    expect((await repo.load('class'))!.periods.where((p) => !p.isSealed).length,
        1);
  });

  test(
      'historical calculations match existing calculation for null/missing/max/weights',
      () async {
    final old = (await archiveLegacy()).periods.first;
    final d = old.dataset;
    final expected = {
      for (final s in d.students)
        s.studentId: CalculationService().calculateStudentGrades(
            s.studentId,
            d.categories,
            d.assessments,
            d.scores,
            d.exams.where((e) => e.studentId == s.studentId).firstOrNull)
    };
    expect(adapter.calculate(old), expected);
    expect(expected['one']!['Quiz'], 75);
    expect(expected['one']!['Homework'], 80);
    expect(expected['two']!['finalGrade'], isNull);
  });

  for (final method in AggregationMethod.values) {
    test(
        'archive retains ${method.name} aggregation and exact original weights',
        () {
      final data = legacy(categories: [
        category('Quiz', 37.5,
            method: method, n: method == AggregationMethod.bestN ? 2 : 1)
      ], items: [
        assessment('a', 'Quiz'),
        assessment('b', 'Quiz'),
        assessment('c', 'Quiz')
      ], scores: [
        score('a', 20),
        score('b', 60),
        score('c', 100)
      ]);
      final p = period(data);
      final sealed = p.seal(at, adapter.calculate(p));
      expect(sealed.dataset.categories.single.weightPercent, 37.5);
      expect(
          adapter.calculate(sealed)['one']!['Quiz'],
          switch (method) {
            AggregationMethod.average => 60,
            AggregationMethod.sum => 180,
            AggregationMethod.bestN => 80,
            AggregationMethod.dropLowestN => 80,
          });
    });
  }

  test(
      'historical XLSX class/student values, ordering and types match legacy export',
      () async {
    final old = (await archiveLegacy()).periods.first;
    final d = old.dataset;
    final expected = ExportService()
        .generateXlsx(d.students, d.categories, adapter.calculate(old));
    final actual =
        adapter.generateXlsx(old, ownerId: 'owner', classId: 'class');
    expect(cells(actual), cells(expected));
    expect(cells(actual)[1].last, '84.50');
    expect(cells(actual)[2].last, '');
    expect(Excel.decodeBytes(actual).tables.values.first.rows[1][3]!.value,
        isA<TextCellValue>());
    final single = adapter.generateXlsx(old,
        ownerId: 'owner', classId: 'class', studentId: 'one');
    expect(
        cells(single),
        cells(ExportService().generateXlsx(
            [d.students.first], d.categories, adapter.calculate(old))));
    expect(
        () => adapter.generateXlsx(old,
            ownerId: 'owner', classId: 'class', studentId: 'absent'),
        throwsArgumentError);
  });

  test('archive collections, results and exported JSON cannot mutate original',
      () async {
    final old = (await archiveLegacy()).periods.first;
    final original = jsonEncode(old.toJson());
    expect(() => old.dataset.assessments.clear(), throwsUnsupportedError);
    expect(() => old.dataset.categories.clear(), throwsUnsupportedError);
    expect(() => old.dataset.scores.clear(), throwsUnsupportedError);
    expect(() => old.dataset.students.clear(), throwsUnsupportedError);
    expect(() => old.results!.clear(), throwsUnsupportedError);
    expect(
        () => old.results!['one']!['finalGrade'] = 0, throwsUnsupportedError);
    expect(() => old.editAssessments([]), throwsStateError);
    expect(() => old.seal(at, {}), throwsStateError);
    final json = old.toJson();
    (json['dataset']['students'] as List).clear();
    (json['results']['one'] as Map).clear();
    expect(jsonEncode(old.toJson()), original);
  });

  test(
      'service cannot write archived assessments; repository rejects archive rewrite/removal',
      () async {
    final book = await archiveLegacy();
    final old = book.periods.first;
    await expectLater(
        service.putAssessment(
            classId: 'class',
            periodId: 'old',
            expectedRevision: book.revision,
            assessment:
                old.dataset.assessments.first.copyWith(name: 'Changed')),
        throwsStateError);
    await expectLater(
        service.deleteAssessment(
            classId: 'class',
            periodId: 'old',
            expectedRevision: book.revision,
            assessmentId: 'q1',
            at: at),
        throwsStateError);
    final altered = GradingPeriod(
        periodId: old.periodId,
        label: 'Forged',
        createdAt: old.createdAt,
        dataset: old.dataset,
        sealedAt: old.sealedAt,
        results: old.results);
    for (final periods in [
      [altered, book.active],
      [book.active]
    ]) {
      await expectLater(
          repo.compareAndSet(
              GradingPeriodBook(
                  ownerId: 'owner',
                  classId: 'class',
                  revision: book.revision + 1,
                  activePeriodId: 'new',
                  periods: periods),
              expectedRevision: book.revision),
          throwsStateError);
    }
  });

  test('account and class isolation on create, writes, repository and export',
      () async {
    final book = await archiveLegacy();
    final otherRepo = InMemoryGradingPeriodRepository(ownerId: 'other');
    expect(await otherRepo.load('class'), isNull);
    await expectLater(
        GradingPeriodService(otherRepo).adoptLegacy(
            dataset: legacy(), periodId: 'same', label: 'same', at: at),
        throwsStateError);
    await expectLater(otherRepo.compareAndSet(book, expectedRevision: null),
        throwsStateError);
    expect(await repo.load('other-class'), isNull);
    await expectLater(
        service.putAssessment(
            classId: 'other-class',
            periodId: 'new',
            expectedRevision: 1,
            assessment: book.active.dataset.assessments.first),
        throwsStateError);
    await expectLater(
        service.putAssessment(
            classId: 'class',
            periodId: 'new',
            expectedRevision: 1,
            assessment: book.active.dataset.assessments.first
                .copyWith(classId: 'other-class')),
        throwsArgumentError);
    for (final scope in [('other', 'class'), ('owner', 'other-class')]) {
      expect(
          () => adapter.generateXlsx(book.periods.first,
              ownerId: scope.$1, classId: scope.$2),
          throwsStateError);
    }
    expect(
        () => GradebookDataset.fromLegacy(
            classRecord: classRecord(id: 'other'),
            students: legacy().students,
            categories: [],
            assessments: [],
            scores: [],
            exams: []),
        throwsArgumentError);
  });

  test(
      'serialization roundtrip preserves complete book and rejects unsupported versions',
      () async {
    final book = await archiveLegacy();
    final decoded =
        GradingPeriodBook.fromJson(jsonDecode(jsonEncode(book.toJson())));
    expect(decoded.toJson(), book.toJson());
    expect(
        adapter.calculate(decoded.periods.first), book.periods.first.results);
    final json = book.toJson()..['schemaVersion'] = 999;
    expect(() => GradingPeriodBook.fromJson(json), throwsFormatException);
    final periodJson = book.active.toJson()..['schemaVersion'] = 999;
    expect(() => GradingPeriod.fromJson(periodJson), throwsFormatException);
    final dataJson = legacy().toJson()..['schemaVersion'] = 999;
    expect(() => GradebookDataset.fromJson(dataJson), throwsFormatException);
  });

  test('legacy local canonical and global records are read without mutation',
      () async {
    final source = legacy();
    SharedPreferences.setMockInitialValues({
      'students': jsonEncode(source.students.map((s) => s.toJson()).toList()),
      'grade_items':
          jsonEncode(source.assessments.map((a) => a.toJson()).toList()),
      'grading_categories':
          jsonEncode(source.categories.map((c) => c.toJson()).toList()),
      'student_scores':
          jsonEncode(source.scores.map((s) => s.toJson()).toList()),
      'final_exams': jsonEncode(source.exams.map((e) => e.toJson()).toList()),
    });
    final prefs = await SharedPreferences.getInstance();
    final before = {for (final k in prefs.getKeys()) k: prefs.get(k)};
    final local = LocalRepository();
    final items = await local.loadGradeItems('class');
    final data = GradebookDataset.fromLegacy(
        classRecord: classRecord(),
        students: await local.loadStudents('class'),
        categories: await local.loadCategories('class'),
        assessments: items,
        scores: [
          for (final a in items)
            ...await local.loadScores('class', a.gradeItemId)
        ],
        exams: await local.loadExams('class'));
    await service.adoptLegacy(
        dataset: data, periodId: 'old', label: 'Legacy', at: at);
    expect(data.toJson(), source.toJson());
    expect({for (final k in prefs.getKeys()) k: prefs.get(k)}, before);
    await local.saveGradeItems('class', items);
    expect((await local.loadGradeItems('class')).map((a) => a.toJson()),
        items.map((a) => a.toJson()));
  });

  test(
      'caller-owned lists and later live labels/weights do not alter snapshots',
      () {
    final pupils = [pupil('one')];
    final categories = [category('Quiz', 75)];
    final data = GradebookDataset.fromLegacy(
        classRecord: classRecord(),
        students: pupils,
        categories: categories,
        assessments: [assessment('q', 'Quiz')],
        scores: [],
        exams: []);
    final old = period(data).seal(at, adapter.calculate(period(data)));
    final before =
        cells(adapter.generateXlsx(old, ownerId: 'owner', classId: 'class'));
    pupils[0] = pupil('renamed');
    categories[0] = category('Quiz', 1);
    expect(data.students.single.studentId, 'one');
    expect(data.categories.single.weightPercent, 75);
    expect(cells(adapter.generateXlsx(old, ownerId: 'owner', classId: 'class')),
        before);
  });

  test(
      'invalid aggregate, duplicates, joins, bad policy and corrupt results fail closed',
      () async {
    final book = await create();
    expect(
        () => GradingPeriodBook(
            ownerId: 'owner',
            classId: 'class',
            revision: 0,
            activePeriodId: 'new',
            periods: [book.active, period(legacy())]),
        throwsArgumentError);
    expect(
        () => legacy(
            items: [assessment('same', 'Quiz'), assessment('same', 'Quiz')]),
        throwsArgumentError);
    expect(() => legacy(items: [assessment('unknown', 'missing')], scores: []),
        throwsArgumentError);
    expect(() => adapter.calculate(period(legacy(), policy: 'future')),
        throwsUnsupportedError);
    expect(
        () => adapter.calculate(period(
            legacy(items: [assessment('q1', 'Quiz', max: 0)], scores: []))),
        throwsStateError);
    final p = period(legacy());
    final grades = {
      for (final e in adapter.calculate(p).entries)
        e.key: Map<String, double?>.of(e.value)
    };
    grades['one']!['finalGrade'] = 0;
    expect(() => adapter.calculate(p.seal(at, grades)), throwsStateError);
    expect(
        () => adapter.generateXlsx(book.active,
            ownerId: 'owner', classId: 'class'),
        throwsStateError);
  });

  test(
      'custom new-period weights preserved exactly and incomplete templates rejected',
      () {
    final weights = {
      AssessmentKind.quiz: 70.0,
      AssessmentKind.classwork: 15.0,
      AssessmentKind.homework: 10.0,
      AssessmentKind.participation: 5.0
    };
    final p = GradingPeriodService.defaultPeriod(
        context: legacy(),
        periodId: 'new',
        label: 'New',
        at: at,
        weights: weights);
    expect(p.dataset.categories.map((c) => c.weightPercent), [70, 15, 10, 5]);
    expect(
        () => GradingPeriodService.defaultPeriod(
            context: legacy(),
            periodId: 'new',
            label: 'New',
            at: at,
            weights: {AssessmentKind.quiz: 100}),
        throwsArgumentError);
  });
}

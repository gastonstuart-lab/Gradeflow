import '../models/grade_item.dart';
import '../models/grading_category.dart';
import '../models/grading_period.dart';
import '../repositories/grading_period_repository.dart';
import 'historical_grade_export_adapter.dart';

/// Explicit, opt-in period operations. Does not call legacy repository writes,
/// auto-seeders, Firebase, UI providers or migration code.
class GradingPeriodService {
  final GradingPeriodRepository repository;
  final HistoricalGradeExportAdapter _history;
  GradingPeriodService(this.repository, {HistoricalGradeExportAdapter? history})
      : _history = history ?? HistoricalGradeExportAdapter();

  Future<GradingPeriodBook> create(
      {required GradebookDataset context,
      required String periodId,
      required String label,
      required DateTime at,
      Map<AssessmentKind, double>? weights}) async {
    _scope(context);
    return _initial(defaultPeriod(
        context: context,
        periodId: periodId,
        label: label,
        at: at,
        weights: weights));
  }

  /// Adopts an explicitly supplied snapshot, preserving every source value.
  /// This does not migrate/read/overwrite any legacy storage.
  Future<GradingPeriodBook> adoptLegacy(
      {required GradebookDataset dataset,
      required String periodId,
      required String label,
      required DateTime at}) async {
    _scope(dataset);
    return _initial(GradingPeriod(
        periodId: periodId, label: label, createdAt: at, dataset: dataset));
  }

  Future<GradingPeriodBook> _initial(GradingPeriod period) async {
    final book = GradingPeriodBook(
        ownerId: repository.ownerId,
        classId: period.dataset.classId,
        revision: 0,
        activePeriodId: period.periodId,
        periods: [period]);
    await repository.compareAndSet(book, expectedRevision: null);
    return book;
  }

  Future<GradingPeriodBook> rollover(
      {required String classId,
      required String periodId,
      required int expectedRevision,
      required String nextPeriodId,
      required String label,
      required DateTime at,
      Map<AssessmentKind, double>? weights}) async {
    final book = await _active(classId, periodId, expectedRevision);
    if (book.periods.any((p) => p.periodId == nextPeriodId)) {
      throw StateError('Period identity already exists');
    }
    final source = book.active;
    final sealed = source.seal(at, _history.calculate(source));
    final next = defaultPeriod(
        context: source.dataset,
        periodId: nextPeriodId,
        label: label,
        at: at,
        weights: weights);
    return _save(
        book,
        [...book.periods.where((p) => p.periodId != periodId), sealed, next],
        nextPeriodId);
  }

  Future<GradingPeriodBook> putAssessment(
      {required String classId,
      required String periodId,
      required int expectedRevision,
      required GradeItem assessment}) async {
    final book = await _active(classId, periodId, expectedRevision);
    if (assessment.classId != classId ||
        !assessment.maxScore.isFinite ||
        assessment.maxScore <= 0) {
      throw ArgumentError('Invalid assessment scope or maximum');
    }
    final items = [...book.active.dataset.assessments];
    final index =
        items.indexWhere((a) => a.gradeItemId == assessment.gradeItemId);
    if (index < 0) {
      items.add(assessment);
    } else {
      items[index] = assessment;
    }
    return _edit(book, items);
  }

  Future<GradingPeriodBook> deleteAssessment(
      {required String classId,
      required String periodId,
      required int expectedRevision,
      required String assessmentId,
      required DateTime at}) async {
    final book = await _active(classId, periodId, expectedRevision);
    if (!book.active.dataset.assessments
        .any((a) => a.gradeItemId == assessmentId)) {
      throw ArgumentError('Unknown assessment');
    }
    // Preserve score identities/raw history; deletion follows legacy soft-delete.
    return _edit(book, [
      for (final a in book.active.dataset.assessments)
        a.gradeItemId == assessmentId
            ? a.copyWith(isActive: false, updatedAt: at)
            : a
    ]);
  }

  Future<GradingPeriodBook> _edit(
          GradingPeriodBook book, List<GradeItem> items) =>
      _save(
          book,
          [
            for (final p in book.periods)
              p.periodId == book.activePeriodId ? p.editAssessments(items) : p
          ],
          book.activePeriodId);

  Future<GradingPeriodBook> _save(GradingPeriodBook old,
      List<GradingPeriod> periods, String activeId) async {
    final next = GradingPeriodBook(
        ownerId: old.ownerId,
        classId: old.classId,
        revision: old.revision + 1,
        activePeriodId: activeId,
        periods: periods);
    await repository.compareAndSet(next, expectedRevision: old.revision);
    return next;
  }

  Future<GradingPeriodBook> _active(
      String classId, String periodId, int revision) async {
    final book = await repository.load(classId);
    if (book == null ||
        book.ownerId != repository.ownerId ||
        book.classId != classId ||
        book.revision != revision ||
        book.activePeriodId != periodId) {
      throw StateError('Stale, archived or wrong grading context');
    }
    return book;
  }

  void _scope(GradebookDataset dataset) {
    if (dataset.ownerId != repository.ownerId)
      throw StateError('Account mismatch');
  }

  static GradingPeriod defaultPeriod(
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

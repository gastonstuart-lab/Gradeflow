import '../models/grade_item.dart';
import '../models/grading_category.dart';
import '../models/student_score.dart';
import 'lesson_participation_ledger.dart';

/// A receipt for an atomic lesson -> assessment projection. Persist the
/// binding, grade item, scores and revision together in a future trusted
/// period transaction. This pure planner never mutates existing grades.
class ParticipationAssessmentBinding {
  ParticipationAssessmentBinding({
    required this.scope, required this.assessmentId,
    required this.ledgerRevision, required Map<String, int> lastScores,
  }) : lastScores = Map.unmodifiable(lastScores);
  final LessonScope scope;
  final String assessmentId;
  final int ledgerRevision;
  final Map<String, int> lastScores;
}

class ParticipationGradeProjection {
  ParticipationGradeProjection({
    required this.binding, required this.item, required List<StudentScore> scores,
    required this.createsAssessment,
  }) : scores = List.unmodifiable(scores);
  final ParticipationAssessmentBinding binding;
  final GradeItem item;
  final List<StudentScore> scores;
  final bool createsAssessment;

  /// No inference from a column label or weekday. The caller must provide
  /// the exact active period, participation category, explicitly reserved
  /// unused default IDs, and the complete current period snapshot.
  /// For a new assessment beyond those defaults, the caller supplies a
  /// preallocated ID and retains it through transaction retries.
  static ParticipationGradeProjection plan({
    required LessonParticipationLedger ledger,
    required String ownerId,
    required String classId,
    required String activePeriodId,
    required bool periodSealed,
    required GradingCategory participationCategory,
    required List<GradeItem> assessments,
    required List<StudentScore> existingScores,
    required List<String> reservedDefaultIds,
    required List<ParticipationAssessmentBinding> bindings,
    required String newAssessmentId,
    required DateTime at,
  }) {
    final scope = ledger.scope;
    if (periodSealed || scope.ownerId != ownerId || scope.classId != classId ||
        scope.periodId != activePeriodId || !participationCategory.isActive ||
        participationCategory.classId != classId || at.isBefore(scope.startsAt)) {
      throw StateError('Lesson is outside the editable participation period');
    }
    final byId = {for (final a in assessments) a.gradeItemId: a};
    if (byId.length != assessments.length ||
        assessments.any((a) => a.classId != classId) ||
        reservedDefaultIds.toSet().length != reservedDefaultIds.length ||
        existingScores.any((s) => !byId.containsKey(s.gradeItemId))) {
      throw StateError('Invalid assessment snapshot');
    }
    final byScope = {for (final b in bindings) b.scope: b};
    final boundIds = bindings.map((b) => b.assessmentId).toSet();
    if (byScope.length != bindings.length || boundIds.length != bindings.length ||
        bindings.any((b) => b.scope.ownerId != ownerId ||
            b.scope.classId != classId || b.scope.periodId != activePeriodId)) {
      throw StateError('Invalid or duplicate lesson binding');
    }
    bool compatible(GradeItem a) => a.isActive &&
        a.categoryId == participationCategory.categoryId && a.maxScore == 100;
    final prior = byScope[scope];
    late final GradeItem item;
    var creates = false;
    if (prior != null) {
      final existing = byId[prior.assessmentId];
      if (existing == null || !compatible(existing) ||
          prior.ledgerRevision > ledger.revision ||
          prior.lastScores.length != ledger.studentIds.length ||
          !ledger.studentIds.containsAll(prior.lastScores.keys)) {
        throw StateError('Existing participation binding no longer matches');
      }
      final stored = existingScores.where((s) => s.gradeItemId == prior.assessmentId).toList();
      final storedByStudent = {for (final s in stored) s.studentId: s};
      if (stored.length != storedByStudent.length ||
          stored.length != prior.lastScores.length ||
          prior.lastScores.entries.any((e) => storedByStudent[e.key]?.score != e.value)) {
        throw StateError('Participation grade was edited outside the ledger; reconcile first');
      }
      item = existing;
    } else {
      GradeItem? reserved;
      for (final id in reservedDefaultIds) {
        final candidate = byId[id];
        if (candidate == null || !compatible(candidate) || boundIds.contains(id) ||
            existingScores.any((s) => s.gradeItemId == id)) continue;
        reserved = candidate;
        break;
      }
      if (reserved != null) {
        item = reserved;
      } else {
        if (newAssessmentId.trim().isEmpty || byId.containsKey(newAssessmentId) ||
            boundIds.contains(newAssessmentId)) {
          throw StateError('A unique preallocated assessment ID is required');
        }
        creates = true;
        item = GradeItem(gradeItemId: newAssessmentId, classId: classId,
            categoryId: participationCategory.categoryId,
            name: 'Participation ${bindings.length + 1}',
            maxScore: 100, isActive: true, createdAt: at, updatedAt: at);
      }
    }
    final values = {for (final id in ledger.studentIds) id: ledger.scoreFor(id)};
    if (prior != null && prior.ledgerRevision == ledger.revision &&
        prior.lastScores.entries.any((e) => values[e.key] != e.value)) {
      throw StateError('Same ledger revision has different scores');
    }
    final old = {for (final s in existingScores)
      if (s.gradeItemId == item.gradeItemId) s.studentId: s};
    final scores = [
      for (final e in values.entries)
        if (old[e.key]?.score == e.value)
          old[e.key]!
        else
          StudentScore(studentId: e.key, gradeItemId: item.gradeItemId,
              score: e.value.toDouble(), createdAt: old[e.key]?.createdAt ?? at,
              updatedAt: at),
    ];
    return ParticipationGradeProjection(
      binding: ParticipationAssessmentBinding(scope: scope,
          assessmentId: item.gradeItemId, ledgerRevision: ledger.revision,
          lastScores: values),
      item: item, scores: scores, createsAssessment: creates,
    );
  }
}

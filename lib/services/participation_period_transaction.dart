import '../models/grade_item.dart';
import '../models/grading_category.dart';
import '../models/student_score.dart';
import 'lesson_participation_ledger.dart';
import 'participation_grade_projection.dart';
import 'participation_ledger_repository.dart';

/// Reference transaction boundary for a future trusted period adapter.
/// All four data sets travel together; no separate grade or ledger writes.
/// Deliberately not registered with a live repository or Firebase.
class ParticipationPeriodSnapshot {
  ParticipationPeriodSnapshot({
    required this.ownerId, required this.classId, required this.periodId,
    required this.revision, required this.sealed,
    required this.category, required List<GradeItem> assessments,
    required List<StudentScore> scores, required List<String> reservedIds,
    List<LessonParticipationLedger> lessons = const [],
    List<ParticipationAssessmentBinding> bindings = const [],
  }) : assessments = List.unmodifiable(assessments),
       scores = List.unmodifiable(scores),
       reservedIds = List.unmodifiable(reservedIds),
       lessons = List.unmodifiable(lessons),
       bindings = List.unmodifiable(bindings) {
    if (ownerId.trim().isEmpty || classId.trim().isEmpty ||
        periodId.trim().isEmpty || revision < 0 || category.classId != classId ||
        lessons.any((l) => !owns(l.scope)) ||
        bindings.any((b) => !owns(b.scope)) ||
        lessons.map((l) => l.scope).toSet().length != lessons.length ||
        bindings.map((b) => b.scope).toSet().length != bindings.length) {
      throw ArgumentError('Invalid period participation snapshot');
    }
  }
  final String ownerId, classId, periodId;
  final int revision;
  final bool sealed;
  final GradingCategory category;
  final List<GradeItem> assessments;
  final List<StudentScore> scores;
  final List<String> reservedIds;
  final List<LessonParticipationLedger> lessons;
  final List<ParticipationAssessmentBinding> bindings;

  bool owns(LessonScope s) => s.ownerId == ownerId &&
      s.classId == classId && s.periodId == periodId;
}

/// The storage adapter must enforce authorization, current active period,
/// expected revision, sealed-history preservation and atomic writes. An
/// exact retry is allowed to return its existing receipt, not write again.
abstract interface class ParticipationPeriodStore {
  Future<ParticipationPeriodSnapshot> load();
  Future<bool> compareAndSet(ParticipationPeriodSnapshot next,
      {required int expectedRevision});
}

class ParticipationPeriodTransaction {
  const ParticipationPeriodTransaction(this.store);
  final ParticipationPeriodStore store;

  /// Explicitly opened lesson with its roster snapshot. A 100 score is
  /// projected only for that lesson's supplied roster, never future lessons.
  Future<ParticipationPeriodSnapshot> record({
    required LessonScope scope,
    required Iterable<String> roster,
    required String newAssessmentId,
    required DateTime at,
    required int expectedRevision,
    ParticipationEvent? event,
  }) async {
    final before = await store.load();
    if (!before.owns(scope) || (event != null && event.scope != scope)) {
      throw StateError('Wrong period or event scope');
    }
    final old = before.lessons.where((l) => l.scope == scope).firstOrNull;
    var ledger = old ?? LessonParticipationLedger(scope: scope, studentIds: roster);
    final rosterIds = roster.toSet();
    if (ledger.studentIds.length != rosterIds.length ||
        !ledger.studentIds.containsAll(rosterIds)) {
      throw StateError('Lesson roster changed; review before editing');
    }
    if (event != null) ledger = ledger.append(event);
    // An exact retry must return the existing committed snapshot, including
    // after sealing, without mutating it or relying on a fresh revision.
    if (old != null && identical(old, ledger)) return before;
    if (before.sealed) throw StateError('Archived period is immutable');
    if (before.revision != expectedRevision) throw const ParticipationConflict();
    final projection = ParticipationGradeProjection.plan(
      ledger: ledger, ownerId: before.ownerId, classId: before.classId,
      activePeriodId: before.periodId, periodSealed: before.sealed,
      participationCategory: before.category,
      assessments: before.assessments, existingScores: before.scores,
      reservedDefaultIds: before.reservedIds, bindings: before.bindings,
      newAssessmentId: newAssessmentId, at: at,
    );
    final next = ParticipationPeriodSnapshot(
      ownerId: before.ownerId, classId: before.classId, periodId: before.periodId,
      revision: before.revision + 1, sealed: before.sealed, category: before.category,
      assessments: [...before.assessments, if (projection.createsAssessment) projection.item],
      scores: [
        ...before.scores.where((s) => s.gradeItemId != projection.item.gradeItemId),
        ...projection.scores,
      ],
      reservedIds: before.reservedIds,
      lessons: [...before.lessons.where((l) => l.scope != scope), ledger],
      bindings: [...before.bindings.where((b) => b.scope != scope), projection.binding],
    );
    if (!await store.compareAndSet(next, expectedRevision: before.revision)) {
      throw const ParticipationConflict();
    }
    return next;
  }
}

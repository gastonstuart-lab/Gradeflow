/// Pure participation calculation. No persistence, Firebase, gradebook or UI
/// wiring: only synthetic fixtures should use this draft until integration is
/// reviewed. Ledger events are immutable and replayed in append order.
library;

enum BehaviourReason {
  talkingAfterWarning('Talking after being asked to stop'),
  eating('Eating'),
  sleeping('Sleeping'),
  walkingWithoutPermission('Walking around without permission'),
  incompleteWork('Not completing work'),
  lateAtStart('Late at start'),
  lateAfterBreak('Late from break'),
  extraToiletBreak('More than one toilet break'),
  otherHomework('Doing other homework'),
  badLanguage('Bad language');

  const BehaviourReason(this.label);
  final String label;
}

/// Policy is snapshotted into each deduction so later settings changes cannot
/// rewrite earlier incidents. Zero is not a valid deduction; disable a reason
/// at the UI level rather than recording an ambiguous zero-point incident.
class BehaviourPolicy {
  BehaviourPolicy({Map<BehaviourReason, int> overrides = const {}})
      : points = Map.unmodifiable({
          for (final reason in BehaviourReason.values)
            reason: overrides[reason] ?? 10,
        }) {
    if (points.values.any((n) => n < 1 || n > 100)) {
      throw ArgumentError('Deduction must be between 1 and 100');
    }
  }

  final Map<BehaviourReason, int> points;
}

typedef LessonScope = ({
  String ownerId,
  String classId,
  String periodId,
  String occurrenceId,
  DateTime startsAt,
});

enum ParticipationEventKind { deduction, overrideScore, undo }

class ParticipationEvent {
  ParticipationEvent._({
    required this.scope,
    required this.operationId,
    required this.studentId,
    required DateTime at,
    required this.kind,
    this.reason,
    this.points,
    this.note,
    this.targetOperationId,
  }) : at = at.toUtc() {
    if (operationId.trim().isEmpty || studentId.trim().isEmpty ||
        scope.ownerId.trim().isEmpty || scope.classId.trim().isEmpty ||
        scope.periodId.trim().isEmpty || scope.occurrenceId.trim().isEmpty ||
        !scope.startsAt.isUtc) {
      throw ArgumentError('A complete, UTC lesson scope and event identity are required');
    }
    if (this.at.isBefore(scope.startsAt)) {
      throw ArgumentError('Event precedes lesson');
    }
  }

  factory ParticipationEvent.deduction({
    required LessonScope scope,
    required String operationId,
    required String studentId,
    required DateTime at,
    required BehaviourReason reason,
    required BehaviourPolicy policy,
  }) => ParticipationEvent._(
      scope: scope, operationId: operationId, studentId: studentId, at: at,
      kind: ParticipationEventKind.deduction, reason: reason,
      points: policy.points[reason]);

  factory ParticipationEvent.overrideScore({
    required LessonScope scope,
    required String operationId,
    required String studentId,
    required DateTime at,
    required int score,
    required String explanation,
  }) {
    if (score < 0 || score > 100 || explanation.trim().isEmpty) {
      throw ArgumentError('Override requires 0–100 and a reason');
    }
    return ParticipationEvent._(
        scope: scope, operationId: operationId, studentId: studentId, at: at,
        kind: ParticipationEventKind.overrideScore, points: score,
        note: explanation.trim());
  }

  factory ParticipationEvent.undo({
    required LessonScope scope,
    required String operationId,
    required String studentId,
    required DateTime at,
    required String targetOperationId,
  }) {
    if (targetOperationId.trim().isEmpty || targetOperationId == operationId) {
      throw ArgumentError('Undo requires a different target operation');
    }
    return ParticipationEvent._(
        scope: scope, operationId: operationId, studentId: studentId, at: at,
        kind: ParticipationEventKind.undo, targetOperationId: targetOperationId);
  }

  final LessonScope scope;
  final String operationId;
  final String studentId;
  final DateTime at;
  final ParticipationEventKind kind;
  final BehaviourReason? reason;
  final int? points;
  final String? note;
  final String? targetOperationId;

  /// Compare the entire intent, not merely its ID. Retrying after lost
  /// acknowledgement must reuse the same exact operation and timestamp.
  bool sameIntent(ParticipationEvent other) =>
      scope == other.scope && operationId == other.operationId &&
      studentId == other.studentId && at == other.at && kind == other.kind &&
      reason == other.reason && points == other.points && note == other.note &&
      targetOperationId == other.targetOperationId;
}

/// Immutable, lesson-scoped aggregate. Caller must serialize writes / compare
/// revisions in a future repository; this class is not a persistence guarantee.
class LessonParticipationLedger {
  LessonParticipationLedger({
    required this.scope,
    required Iterable<String> studentIds,
  }) : studentIds = Set.unmodifiable(studentIds), events = const [] {
    if (scope.ownerId.trim().isEmpty || scope.classId.trim().isEmpty ||
        scope.periodId.trim().isEmpty || scope.occurrenceId.trim().isEmpty ||
        !scope.startsAt.isUtc || this.studentIds.any((s) => s.trim().isEmpty)) {
      throw ArgumentError('Invalid lesson scope or roster');
    }
  }

  LessonParticipationLedger._(this.scope, this.studentIds, List<ParticipationEvent> events)
      : events = List.unmodifiable(events);

  final LessonScope scope;
  final Set<String> studentIds;
  final List<ParticipationEvent> events;
  int get revision => events.length;

  LessonParticipationLedger append(ParticipationEvent event) {
    if (event.scope != scope || !studentIds.contains(event.studentId)) {
      throw StateError('Incident outside lesson or roster');
    }
    for (final existing in events) {
      if (existing.operationId == event.operationId) {
        if (existing.sameIntent(event)) return this;
        throw StateError('Operation ID already used for another intent');
      }
    }
    if (event.kind == ParticipationEventKind.undo) {
      final targets = events.where((e) => e.operationId == event.targetOperationId);
      if (targets.isEmpty || targets.single.studentId != event.studentId ||
          targets.single.kind == ParticipationEventKind.undo ||
          event.at.isBefore(targets.single.at) ||
          events.any((e) => e.kind == ParticipationEventKind.undo &&
              e.targetOperationId == event.targetOperationId)) {
        throw StateError('Undo target missing, out of scope or already undone');
      }
    }
    return LessonParticipationLedger._(scope, studentIds, [...events, event]);
  }

  List<ParticipationEvent> historyFor(String studentId) {
    if (!studentIds.contains(studentId)) throw StateError('Unknown student');
    return List.unmodifiable(events.where((e) => e.studentId == studentId));
  }

  int scoreFor(String studentId) {
    final history = historyFor(studentId);
    final undone = history.where((e) => e.kind == ParticipationEventKind.undo)
        .map((e) => e.targetOperationId).toSet();
    var score = 100;
    for (final event in history) {
      if (undone.contains(event.operationId)) continue;
      switch (event.kind) {
        case ParticipationEventKind.deduction:
          score = (score - event.points!).clamp(0, 100).toInt();
        case ParticipationEventKind.overrideScore:
          score = event.points!;
        case ParticipationEventKind.undo:
          break;
      }
    }
    return score;
  }
}

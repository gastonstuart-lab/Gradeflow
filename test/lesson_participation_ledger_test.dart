import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/services/lesson_participation_ledger.dart';

void main() {
  final start = DateTime.utc(2026, 11, 28, 1);
  final scope = (ownerId: 'fictional-teacher', classId: 'fictional-class',
      periodId: 'november', occurrenceId: 'slot-one', startsAt: start);
  final policy = BehaviourPolicy();
  LessonParticipationLedger lesson([LessonScope? other]) =>
      LessonParticipationLedger(scope: other ?? scope, studentIds: ['a', 'b']);
  ParticipationEvent incident(String id, {String student = 'a',
      BehaviourReason reason = BehaviourReason.eating,
      BehaviourPolicy? using, LessonScope? inScope}) =>
      ParticipationEvent.deduction(scope: inScope ?? scope, operationId: id,
          studentId: student, at: start, reason: reason, policy: using ?? policy);
  ParticipationEvent undo(String id, String target, {String student = 'a'}) =>
      ParticipationEvent.undo(scope: scope, operationId: id, studentId: student,
          at: start.add(const Duration(minutes: 1)), targetOperationId: target);

  test('ten requested defaults and each learner begins at 100 per lesson', () {
    expect(BehaviourReason.values, hasLength(10));
    expect(policy.points.values, everyElement(10));
    expect(lesson().scoreFor('a'), 100);
    expect(lesson().scoreFor('b'), 100);
    expect(lesson().events, isEmpty);
    expect(() => lesson().scoreFor('missing'), throwsStateError);
  });

  test('repeated incidents accumulate, not one deduction per category', () {
    final a = lesson().append(incident('one')).append(incident('two'));
    expect(a.scoreFor('a'), 80);
    expect(a.scoreFor('b'), 100);
    expect(a.historyFor('a'), hasLength(2));
    expect(a.historyFor('b'), isEmpty);
    expect(a.revision, 2);
  });

  test('floor and undo recompute from the full ledger', () {
    var a = lesson();
    for (var i = 0; i < 12; i++) { a = a.append(incident('d$i')); }
    expect(a.scoreFor('a'), 0);
    a = a.append(undo('u1', 'd0')).append(undo('u2', 'd1'));
    expect(a.scoreFor('a'), 0);
    a = a.append(undo('u3', 'd2'));
    expect(a.scoreFor('a'), 10);
    expect(a.historyFor('a'), hasLength(15));
  });

  test('deduction and undo retries are idempotent, changed intent rejected', () {
    final first = incident('op');
    final a = lesson().append(first);
    expect(identical(a.append(incident('op')), a), isTrue);
    expect(() => a.append(incident('op', reason: BehaviourReason.sleeping)),
        throwsStateError);
    final b = a.append(undo('u', 'op'));
    expect(identical(b.append(undo('u', 'op')), b), isTrue);
    expect(b.scoreFor('a'), 100);
    expect(() => b.append(undo('again', 'op')), throwsStateError);
    expect(() => b.append(undo('undo-undo', 'u')), throwsStateError);
  });

  test('policy change affects future deductions only', () {
    final custom = BehaviourPolicy(overrides: {BehaviourReason.eating: 5});
    final a = lesson().append(incident('old')).append(incident('new', using: custom));
    expect(a.scoreFor('a'), 85);
    expect(a.events.map((e) => e.points), [10, 5]);
    expect(custom.points[BehaviourReason.sleeping], 10);
    expect(() => BehaviourPolicy(overrides: {BehaviourReason.eating: 0}), throwsArgumentError);
    expect(() => BehaviourPolicy(overrides: {BehaviourReason.eating: 101}), throwsArgumentError);
  });

  test('manual override is explained, auditable and reversible', () {
    final correction = ParticipationEvent.overrideScore(scope: scope,
        operationId: 'correct', studentId: 'a', at: start, score: 95,
        explanation: 'Teacher correction');
    final a = lesson().append(incident('one')).append(correction).append(incident('two'));
    expect(a.scoreFor('a'), 85);
    expect(a.historyFor('a')[1].note, 'Teacher correction');
    expect(a.append(undo('u', 'correct')).scoreFor('a'), 80);
    expect(() => ParticipationEvent.overrideScore(scope: scope,
        operationId: 'bad', studentId: 'a', at: start, score: 101,
        explanation: 'invalid'), throwsArgumentError);
    expect(() => ParticipationEvent.overrideScore(scope: scope,
        operationId: 'bad', studentId: 'a', at: start, score: 95,
        explanation: ' '), throwsArgumentError);
  });

  test('scope isolates owner, class, period, lesson and roster', () {
    final a = lesson().append(incident('one'));
    for (final other in [
      (ownerId: 'other', classId: scope.classId, periodId: scope.periodId,
          occurrenceId: scope.occurrenceId, startsAt: start),
      (ownerId: scope.ownerId, classId: 'other', periodId: scope.periodId,
          occurrenceId: scope.occurrenceId, startsAt: start),
      (ownerId: scope.ownerId, classId: scope.classId, periodId: 'other',
          occurrenceId: scope.occurrenceId, startsAt: start),
      (ownerId: scope.ownerId, classId: scope.classId, periodId: scope.periodId,
          occurrenceId: 'slot-two', startsAt: start),
    ]) {
      expect(() => a.append(incident('cross', inScope: other)), throwsStateError);
      expect(lesson(other).scoreFor('a'), 100);
    }
    expect(() => a.append(incident('cross', student: 'missing')), throwsStateError);
    expect(() => a.append(undo('cross', 'one', student: 'b')), throwsStateError);
    expect(() => a.append(undo('missing', 'not-present')), throwsStateError);
  });

  test('ledger and policy cannot be changed by caller; replay restores scores', () {
    final original = ['a', 'b'];
    final empty = LessonParticipationLedger(scope: scope, studentIds: original);
    final a = empty.append(incident('one')).append(incident('two'));
    original.clear();
    expect(a.studentIds, {'a', 'b'});
    expect(empty.events, isEmpty);
    expect(() => a.events.clear(), throwsUnsupportedError);
    expect(() => a.studentIds.clear(), throwsUnsupportedError);
    expect(() => policy.points.clear(), throwsUnsupportedError);
    final replayed = a.events.fold(lesson(), (ledger, event) => ledger.append(event));
    expect(replayed.scoreFor('a'), 80);
    expect(replayed.historyFor('a'), a.historyFor('a'));
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/models/grade_item.dart';
import 'package:gradeflow/models/grading_category.dart';
import 'package:gradeflow/models/student_score.dart';
import 'package:gradeflow/services/lesson_participation_ledger.dart';
import 'package:gradeflow/services/participation_grade_projection.dart';

void main() {
  final at = DateTime.utc(2026, 11, 28);
  final category = GradingCategory(categoryId: 'participation', classId: 'class',
      name: 'Participation', weightPercent: 25, aggregationMethod: AggregationMethod.average,
      isActive: true, createdAt: at, updatedAt: at);
  GradeItem item(String id, {String cat = 'participation', double max = 100, bool active = true}) =>
      GradeItem(gradeItemId: id, classId: 'class', categoryId: cat, name: id,
          maxScore: max, isActive: active, createdAt: at, updatedAt: at);
  final defaults = List.generate(6, (i) => 'slot-${i+1}');
  LessonParticipationLedger lesson(int n, {String period = 'period'}) =>
      LessonParticipationLedger(scope: (ownerId: 'teacher', classId: 'class',
          periodId: period, occurrenceId: 'lesson-$n', startsAt: at),
          studentIds: ['a', 'b']);
  ParticipationEvent event(LessonParticipationLedger l, String id) =>
      ParticipationEvent.deduction(scope: l.scope, operationId: id,
          studentId: 'a', at: at, reason: BehaviourReason.eating, policy: BehaviourPolicy());
  ParticipationGradeProjection project(LessonParticipationLedger l, {
      List<GradeItem>? items, List<StudentScore> scores = const [],
      List<ParticipationAssessmentBinding> bindings = const [],
      String newId = 'new-item', bool sealed = false,
  }) => ParticipationGradeProjection.plan(ledger: l, ownerId: 'teacher',
      classId: 'class', activePeriodId: 'period', periodSealed: sealed,
      participationCategory: category, assessments: items ?? defaults.map((id) => item(id)).toList(),
      existingScores: scores, reservedDefaultIds: defaults, bindings: bindings,
      newAssessmentId: newId, at: at);

  test('first six use explicit unused slots and seventh and eighth create new assessments', () {
    final items = defaults.map((id) => item(id)).toList();
    final scores = <StudentScore>[];
    final bindings = <ParticipationAssessmentBinding>[];
    for (var n = 1; n <= 8; n++) {
      var l = lesson(n);
      l = l.append(event(l, 'incident'));
      final p = project(l, items: items, scores: scores, bindings: bindings, newId: 'extra-$n');
      expect(p.item.gradeItemId, n <= 6 ? 'slot-$n' : 'extra-$n');
      expect(p.createsAssessment, n > 6);
      expect(p.scores.map((s) => s.score), [90, 100]);
      if (p.createsAssessment) items.add(p.item);
      bindings.add(p.binding); scores.addAll(p.scores);
    }
    expect(items, hasLength(8));
    expect(scores, hasLength(16));
    expect(bindings.map((b) => b.assessmentId).toSet(), hasLength(8));
  });

  test('preexisting manual grade and incompatible defaults are never overwritten', () {
    final manual = StudentScore(studentId: 'a', gradeItemId: 'slot-1',
        score: 76, createdAt: at, updatedAt: at);
    final items = [item('slot-1'), item('slot-2', cat: 'quiz'), item('slot-3', max: 20),
      item('slot-4', active: false), item('slot-5'), item('slot-6')];
    final p = project(lesson(1), items: items, scores: [manual]);
    expect(p.item.gradeItemId, 'slot-5');
    expect(manual.score, 76);
  });

  test('same lesson and retry reuse binding and preserve timestamps', () {
    var l = lesson(1);
    l = l.append(event(l, 'one'));
    final p = project(l);
    final same = project(l, bindings: [p.binding], scores: p.scores, newId: 'unused');
    expect(same.item.gradeItemId, p.item.gradeItemId);
    expect(same.scores.map((s) => s.toJson()), p.scores.map((s) => s.toJson()));
    l = l.append(event(l, 'two'));
    final updated = project(l, bindings: [p.binding], scores: p.scores);
    expect(updated.item.gradeItemId, p.item.gradeItemId);
    expect(updated.binding.ledgerRevision, 2);
    expect(updated.scores.map((s) => s.score), [80, 100]);
  });

  test('archived period, stale revision or externally modified grades fail closed', () {
    var l = lesson(1);
    l = l.append(event(l, 'one'));
    final p = project(l);
    expect(() => project(l, sealed: true), throwsStateError);
    expect(() => project(lesson(1, period: 'old')), throwsStateError);
    expect(() => project(lesson(1), bindings: [p.binding], scores: p.scores), throwsStateError);
    final edited = [p.scores.first.copyWith(score: 99), p.scores.last];
    expect(() => project(l, bindings: [p.binding], scores: edited), throwsStateError);
    expect(() => project(l, bindings: [p.binding, p.binding], scores: p.scores), throwsStateError);
  });

  test('no suitable default and colliding new assessment ID fails without modifying snapshot', () {
    final items = [item('new-item', cat: 'quiz')];
    expect(() => project(lesson(1), items: items), throwsStateError);
    expect(items.single.categoryId, 'quiz');
    final p = project(lesson(1), items: items, newId: 'new-unique');
    expect(p.createsAssessment, isTrue);
    expect(p.item.gradeItemId, 'new-unique');
  });
}

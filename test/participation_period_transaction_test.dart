import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/models/grade_item.dart';
import 'package:gradeflow/models/grading_category.dart';
import 'package:gradeflow/models/student_score.dart';
import 'package:gradeflow/services/lesson_participation_ledger.dart';
import 'package:gradeflow/services/participation_period_transaction.dart';
import 'package:gradeflow/services/participation_ledger_repository.dart';

class FictionalAtomicStore implements ParticipationPeriodStore {
  FictionalAtomicStore(this.value);
  ParticipationPeriodSnapshot value;
  bool reject = false, loseAck = false;
  @override
  Future<ParticipationPeriodSnapshot> load() async => value;
  @override
  Future<bool> compareAndSet(ParticipationPeriodSnapshot next,
      {required int expectedRevision}) async {
    if (reject || value.revision != expectedRevision || value.sealed) return false;
    value = next;
    if (loseAck) { loseAck = false; throw StateError('Lost acknowledgement'); }
    return true;
  }
}

void main() {
  final at = DateTime.utc(2026, 11, 28);
  final scope = (ownerId:'teacher',classId:'class',periodId:'period',
      occurrenceId:'lesson-1',startsAt:at);
  final category = GradingCategory(categoryId:'p',classId:'class',
      name:'Participation',weightPercent:20,aggregationMethod:AggregationMethod.average,
      isActive:true,createdAt:at,updatedAt:at);
  GradeItem item(String id,String cat) => GradeItem(gradeItemId:id,classId:'class',
      categoryId:cat,name:id,isActive:true,createdAt:at,updatedAt:at);
  final manual = StudentScore(studentId:'a',gradeItemId:'quiz',score:76,
      createdAt:at,updatedAt:at);
  FictionalAtomicStore store({bool sealed = false}) => FictionalAtomicStore(
    ParticipationPeriodSnapshot(ownerId:'teacher',classId:'class',periodId:'period',
      revision:0,sealed:sealed,category:category,assessments:[item('slot','p'),item('quiz','q')],
      scores:[manual],reservedIds:['slot']));
  ParticipationEvent event(String id, {LessonScope? lesson}) =>
      ParticipationEvent.deduction(scope:lesson ?? scope,operationId:id,studentId:'a',
        at:at,reason:BehaviourReason.eating,policy:BehaviourPolicy());
  Future<ParticipationPeriodSnapshot> record(FictionalAtomicStore s,int revision,
      {ParticipationEvent? incident,LessonScope? lesson}) =>
    ParticipationPeriodTransaction(s).record(scope:lesson ?? scope,roster:['a','b'],
      newAssessmentId:'extra',at:at,expectedRevision:revision,event:incident);

  test('opening a lesson and recording incidents commits ledger, binding and scores together',() async {
    final s = store();
    final first = await record(s,0);
    expect(first.lessons.single.scoreFor('a'),100);
    expect(first.bindings.single.assessmentId,'slot');
    expect(first.scores.where((v)=>v.gradeItemId=='slot').map((v)=>v.score),[100,100]);
    final next = await record(s,1,incident:event('one'));
    expect(next.revision,2);
    expect(next.lessons.single.scoreFor('a'),90);
    expect(next.bindings.single.ledgerRevision,1);
    expect(next.scores.where((v)=>v.gradeItemId=='slot').map((v)=>v.score),[90,100]);
    expect(next.scores.singleWhere((v)=>v.gradeItemId=='quiz').toJson(),manual.toJson());
  });

  test('failed CAS changes none of the four data sets',() async {
    final s = store();
    final initial = s.value;
    s.reject = true;
    await expectLater(record(s,0,incident:event('one')),throwsA(isA<ParticipationConflict>()));
    expect(identical(s.value,initial),isTrue);
    expect(s.value.lessons,isEmpty);
    expect(s.value.bindings,isEmpty);
    expect(s.value.scores.single,manual);
  });

  test('lost acknowledgement returns original committed transaction on exact retry',() async {
    final s = store();
    s.loseAck = true;
    await expectLater(record(s,0,incident:event('one')),throwsStateError);
    final committed = s.value;
    final recovered = await record(s,0,incident:event('one'));
    expect(identical(recovered,committed),isTrue);
    expect(recovered.revision,1);
    expect(recovered.lessons.single.events,hasLength(1));
    expect(recovered.scores.singleWhere((v)=>v.studentId=='a'&&v.gradeItemId=='slot').score,90);
  });

  test('concurrent lessons cannot consume the same reserved assessment',() async {
    final s = store();
    final other = (ownerId:'teacher',classId:'class',periodId:'period',
        occurrenceId:'lesson-2',startsAt:at);
    Future<bool> attempt(LessonScope l) async {
      try { await record(s,0,lesson:l); return true; }
      on ParticipationConflict { return false; }
    }
    final result = await Future.wait([attempt(scope),attempt(other)]);
    expect(result.where((v)=>v),hasLength(1));
    final remaining = s.value.lessons.single.scope==scope?other:scope;
    final next = await record(s,1,lesson:remaining);
    expect(next.bindings.map((b)=>b.assessmentId).toSet(),{'slot','extra'});
    expect(next.lessons,hasLength(2));
    expect(next.scores,hasLength(5));
  });

  test('sealed period cannot receive a new lesson or incident',() async {
    final s = store(sealed:true);
    await expectLater(record(s,0,incident:event('one')),throwsStateError);
    expect(s.value.revision,0);
    expect(s.value.lessons,isEmpty);
  });
}

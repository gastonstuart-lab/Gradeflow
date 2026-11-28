import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/services/lesson_participation_ledger.dart';
import 'package:gradeflow/services/participation_ledger_repository.dart';
import 'package:gradeflow/services/synthetic_participation_local_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AtomicMemoryStore implements ParticipationSnapshotStore {
  final values = <String, String>{};
  bool loseNextAck = false;
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<bool> compareAndSet(String key, {required String? expected, required String value}) async {
    if (values[key] != expected) return false;
    values[key] = value;
    if (loseNextAck) {
      loseNextAck = false;
      throw StateError('Fictional lost acknowledgement');
    }
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final at = DateTime.utc(2026, 11, 28, 1);
  final scope = (ownerId: 'fictional', classId: 'class', periodId: 'period',
      occurrenceId: 'lesson', startsAt: at);
  final other = (ownerId: 'fictional', classId: 'class', periodId: 'next',
      occurrenceId: 'lesson', startsAt: at);
  ParticipationEvent incident(String id, {LessonScope? inScope, BehaviourReason reason = BehaviourReason.eating}) =>
      ParticipationEvent.deduction(scope: inScope ?? scope, operationId: id, studentId: 'a',
          at: at, reason: reason, policy: BehaviourPolicy(overrides: {reason: 7}));

  test('snapshot round trips custom penalty, correction, undo and full audit history', () {
    var ledger = LessonParticipationLedger(scope: scope, studentIds: ['b', 'a']);
    ledger = ledger.append(incident('one'));
    ledger = ledger.append(ParticipationEvent.overrideScore(scope: scope,
        operationId: 'two', studentId: 'a', at: at, score: 80, explanation: 'Correction'));
    ledger = ledger.append(ParticipationEvent.undo(scope: scope, operationId: 'three',
        studentId: 'a', at: at, targetOperationId: 'two'));
    final raw = ParticipationLedgerCodec.encode(ledger);
    final decoded = ParticipationLedgerCodec.decode(raw);
    expect(decoded.scoreFor('a'), 93);
    expect(decoded.scoreFor('b'), 100);
    expect(decoded.revision, 3);
    expect(ParticipationLedgerCodec.encode(decoded), raw);
    for (var i = 0; i < ledger.events.length; i++) {
      expect(decoded.events[i].sameIntent(ledger.events[i]), isTrue);
    }
  });

  test('corrupted or duplicated event data fails rather than resetting to 100', () {
    final ledger = LessonParticipationLedger(scope: scope, studentIds: ['a']).append(incident('one'));
    final raw = jsonDecode(ParticipationLedgerCodec.encode(ledger)) as Map<String, dynamic>;
    raw['revision'] = 99;
    expect(() => ParticipationLedgerCodec.decode(jsonEncode(raw)), throwsFormatException);
    raw['revision'] = 2;
    (raw['events'] as List).add((raw['events'] as List).first);
    expect(() => ParticipationLedgerCodec.decode(jsonEncode(raw)), throwsFormatException);
  });

  test('restart, stale writer and exact lost receipt retry', () async {
    final store = AtomicMemoryStore();
    final a = ParticipationLedgerRepository(ownerId: 'fictional', store: store);
    final b = ParticipationLedgerRepository(ownerId: 'fictional', store: store);
    await a.open(scope, ['a', 'b']);
    final event = incident('op');
    store.loseNextAck = true;
    await expectLater(a.record(event, expectedRevision: 0), throwsStateError);
    expect((await b.load(scope))!.scoreFor('a'), 93);
    final confirmed = await b.record(event, expectedRevision: 0);
    expect(confirmed.revision, 1);
    await expectLater(a.record(incident('second'), expectedRevision: 0),
        throwsA(isA<ParticipationConflict>()));
    final second = await a.record(incident('second'), expectedRevision: 1);
    expect(second.scoreFor('a'), 86);
    expect((await b.record(event, expectedRevision: 0)).revision, 2);
    await expectLater(a.record(incident('op', reason: BehaviourReason.sleeping), expectedRevision: 2),
        throwsStateError);
  });

  test('concurrent writers do not overwrite and can reload then retry', () async {
    final repo = ParticipationLedgerRepository(ownerId: 'fictional', store: AtomicMemoryStore());
    await repo.open(scope, ['a']);
    Future<bool> write(String id) async {
      try { await repo.record(incident(id), expectedRevision: 0); return true; }
      on ParticipationConflict { return false; }
    }
    final outcomes = await Future.wait([write('first'), write('second')]);
    expect(outcomes.where((v) => v), hasLength(1));
    final current = (await repo.load(scope))!;
    expect(current.revision, 1);
    final missing = current.events.single.operationId == 'first' ? 'second' : 'first';
    final updated = await repo.record(incident(missing), expectedRevision: 1);
    expect(updated.scoreFor('a'), 86);
  });

  test('owner, period and roster are isolated; opening never overwrites history', () async {
    final store = AtomicMemoryStore();
    final repo = ParticipationLedgerRepository(ownerId: 'fictional', store: store);
    await repo.open(scope, ['a', 'b']);
    await repo.record(incident('one'), expectedRevision: 0);
    expect((await repo.open(scope, ['b', 'a'])).scoreFor('a'), 93);
    await expectLater(repo.open(scope, ['a']), throwsStateError);
    expect((await repo.open(other, ['a'])).scoreFor('a'), 100);
    final wrong = ParticipationLedgerRepository(ownerId: 'other', store: store);
    await expectLater(wrong.load(scope), throwsStateError);
    expect(ParticipationLedgerCodec.keyFor(scope), isNot(ParticipationLedgerCodec.keyFor(other)));
  });

  test('fictional local store restores after repository recreation and serializes same-isolate writers', () async {
    SharedPreferences.setMockInitialValues({});
    expect(() => SyntheticParticipationLocalStore(syntheticOnly: false), throwsStateError);
    final a = ParticipationLedgerRepository(ownerId: 'fictional',
        store: SyntheticParticipationLocalStore(syntheticOnly: true));
    await a.open(scope, ['a']);
    await a.record(incident('one'), expectedRevision: 0);
    final b = ParticipationLedgerRepository(ownerId: 'fictional',
        store: SyntheticParticipationLocalStore(syntheticOnly: true));
    expect((await b.open(scope, ['a'])).scoreFor('a'), 93);
    final outcomes = await Future.wait([
      for (final pair in [(a, 'two'), (b, 'three')])
        pair.$1.record(incident(pair.$2), expectedRevision: 1)
          .then((_) => true, onError: (Object e) {
            if (e is ParticipationConflict) return false;
            throw e;
          }),
    ]);
    expect(outcomes.where((v) => v), hasLength(1));
    expect((await b.load(scope))!.scoreFor('a'), 86);
  });
}

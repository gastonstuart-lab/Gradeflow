import 'dart:convert';
import 'lesson_participation_ledger.dart';

/// The store must implement atomic compare-and-set over the entire value.
/// The repository never assumes a read followed by an unconditional write
/// is safe. No Firebase or production storage is wired by this draft.
abstract interface class ParticipationSnapshotStore {
  Future<String?> read(String key);
  Future<bool> compareAndSet(String key, {required String? expected, required String value});
}

class ParticipationConflict implements Exception {
  const ParticipationConflict();
  @override
  String toString() => 'Participation changed elsewhere. Reload before editing.';
}

class ParticipationLedgerCodec {
  static Map<String, Object> scopeJson(LessonScope scope) => {
    'owner': scope.ownerId, 'class': scope.classId, 'period': scope.periodId,
    'occurrence': scope.occurrenceId, 'startsAt': scope.startsAt.toIso8601String(),
  };

  static String keyFor(LessonScope scope) =>
      'participation-draft:v1:${base64Url.encode(utf8.encode(jsonEncode(scopeJson(scope))))}';

  static String encode(LessonParticipationLedger ledger) => jsonEncode({
    'version': 1, 'scope': scopeJson(ledger.scope),
    'students': ledger.studentIds.toList()..sort(),
    'revision': ledger.revision,
    'events': [
      for (final e in ledger.events) {
        'id': e.operationId, 'student': e.studentId,
        'at': e.at.toIso8601String(), 'kind': e.kind.name,
        'reason': e.reason?.name, 'points': e.points, 'note': e.note,
        'target': e.targetOperationId,
      },
    ],
  });

  static DateTime _utc(Object? raw) {
    final date = DateTime.parse(raw as String);
    if (!date.isUtc) throw const FormatException('UTC timestamp required');
    return date;
  }

  static LessonParticipationLedger decode(String raw) {
    final data = jsonDecode(raw) as Map<String, dynamic>;
    if (data['version'] != 1) throw const FormatException('Unknown participation version');
    final s = data['scope'] as Map<String, dynamic>;
    final LessonScope scope = (
      ownerId: s['owner'] as String, classId: s['class'] as String,
      periodId: s['period'] as String, occurrenceId: s['occurrence'] as String,
      startsAt: _utc(s['startsAt']),
    );
    final students = (data['students'] as List).cast<String>();
    if (students.toSet().length != students.length) {
      throw const FormatException('Duplicate roster ID');
    }
    var ledger = LessonParticipationLedger(scope: scope, studentIds: students);
    for (final rawEvent in data['events'] as List) {
      final e = rawEvent as Map<String, dynamic>;
      final id = e['id'] as String, student = e['student'] as String;
      final at = _utc(e['at']);
      final kind = ParticipationEventKind.values.byName(e['kind'] as String);
      late final ParticipationEvent event;
      switch (kind) {
        case ParticipationEventKind.deduction:
          if (e['note'] != null || e['target'] != null) {
            throw const FormatException('Invalid deduction fields');
          }
          final reason = BehaviourReason.values.byName(e['reason'] as String);
          event = ParticipationEvent.deduction(scope: scope, operationId: id,
              studentId: student, at: at, reason: reason,
              policy: BehaviourPolicy(overrides: {reason: e['points'] as int}));
        case ParticipationEventKind.overrideScore:
          if (e['reason'] != null || e['target'] != null) {
            throw const FormatException('Invalid correction fields');
          }
          event = ParticipationEvent.overrideScore(scope: scope, operationId: id,
              studentId: student, at: at, score: e['points'] as int,
              explanation: e['note'] as String);
        case ParticipationEventKind.undo:
          if (e['reason'] != null || e['points'] != null || e['note'] != null) {
            throw const FormatException('Invalid undo fields');
          }
          event = ParticipationEvent.undo(scope: scope, operationId: id,
              studentId: student, at: at, targetOperationId: e['target'] as String);
      }
      final next = ledger.append(event);
      if (identical(next, ledger)) throw const FormatException('Duplicate stored operation');
      ledger = next;
    }
    if (data['revision'] != ledger.revision) {
      throw const FormatException('Participation revision mismatch');
    }
    return ledger;
  }
}

/// Scoped optimistic-concurrency boundary. Authorization and the active period
/// must be checked by an eventual trusted storage adapter; ownerId alone is not
/// authorization. A lost acknowledgement is recovered by submitting the exact
/// same event ID and intent, even after a later revision has committed.
class ParticipationLedgerRepository {
  ParticipationLedgerRepository({required this.ownerId, required this.store}) {
    if (ownerId.trim().isEmpty) throw ArgumentError('Owner required');
  }
  final String ownerId;
  final ParticipationSnapshotStore store;

  String _key(LessonScope scope) {
    if (scope.ownerId != ownerId) throw StateError('Wrong participation owner');
    return ParticipationLedgerCodec.keyFor(scope);
  }

  LessonParticipationLedger _checked(String raw, LessonScope scope) {
    final ledger = ParticipationLedgerCodec.decode(raw);
    if (ledger.scope != scope) throw StateError('Stored lesson scope mismatch');
    return ledger;
  }

  Future<LessonParticipationLedger?> load(LessonScope scope) async {
    final raw = await store.read(_key(scope));
    return raw == null ? null : _checked(raw, scope);
  }

  Future<LessonParticipationLedger> open(LessonScope scope, Iterable<String> roster) async {
    final key = _key(scope);
    final empty = LessonParticipationLedger(scope: scope, studentIds: roster);
    var raw = await store.read(key);
    if (raw == null) {
      final created = await store.compareAndSet(key, expected: null,
          value: ParticipationLedgerCodec.encode(empty));
      if (created) return empty;
      raw = await store.read(key);
      if (raw == null) throw const ParticipationConflict();
    }
    final existing = _checked(raw, scope);
    if (existing.studentIds.length != empty.studentIds.length ||
        !existing.studentIds.containsAll(empty.studentIds)) {
      throw StateError('Lesson roster differs; review rather than replacing history');
    }
    return existing;
  }

  Future<LessonParticipationLedger> record(ParticipationEvent event,
      {required int expectedRevision}) async {
    final key = _key(event.scope);
    final raw = await store.read(key);
    if (raw == null) throw StateError('Open lesson before recording');
    final current = _checked(raw, event.scope);
    // Validate the operation even when its caller is stale. Exact retries
    // return the confirmed current state; conflicting IDs never pass.
    final next = current.append(event);
    if (identical(next, current)) return current;
    if (current.revision != expectedRevision) throw const ParticipationConflict();
    if (!await store.compareAndSet(key, expected: raw,
        value: ParticipationLedgerCodec.encode(next))) {
      throw const ParticipationConflict();
    }
    return next;
  }
}

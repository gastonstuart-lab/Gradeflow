import 'dart:convert';
import '../models/grading_period.dart';

/// Bound to a single authenticated owner by the host. A durable adapter MUST
/// enforce ownership, revision CAS and sealed-period preservation atomically.
/// This contract is intentionally separate from legacy DataRepository writes.
abstract interface class GradingPeriodRepository {
  String get ownerId;
  Future<GradingPeriodBook?> load(String classId);
  Future<void> compareAndSet(GradingPeriodBook next,
      {required int? expectedRevision});
}

/// Isolated reference adapter for Slice 1. No disk, Firebase or factory wiring.
/// CAS is atomic within this instance's isolate, not across processes/devices.
class InMemoryGradingPeriodRepository implements GradingPeriodRepository {
  @override
  final String ownerId;
  final _books = <String, GradingPeriodBook>{};
  InMemoryGradingPeriodRepository({required this.ownerId}) {
    if (ownerId.isEmpty) throw ArgumentError('Owner is required');
  }
  @override
  Future<GradingPeriodBook?> load(String classId) async => _books[classId];

  @override
  Future<void> compareAndSet(GradingPeriodBook next,
      {required int? expectedRevision}) async {
    validateGradingPeriodTransition(
        ownerId, _books[next.classId], next, expectedRevision);
    _books[next.classId] = next;
  }
}

void validateGradingPeriodTransition(String ownerId, GradingPeriodBook? old,
    GradingPeriodBook next, int? expectedRevision) {
  if (next.ownerId != ownerId) throw StateError('Account mismatch');
  if (old?.revision != expectedRevision ||
      next.revision != (expectedRevision == null ? 0 : expectedRevision + 1)) {
    throw StateError('Stale grading period revision');
  }
  if (old != null) {
    for (final previous in old.periods) {
      final matches =
          next.periods.where((p) => p.periodId == previous.periodId);
      if (matches.isEmpty ||
          (previous.isSealed &&
              jsonEncode(matches.single.toJson()) !=
                  jsonEncode(previous.toJson()))) {
        throw StateError('Archive cannot be replaced or removed');
      }
      final updated = matches.single;
      if (!previous.isSealed &&
          updated.isSealed &&
          (jsonEncode(previous.dataset.toJson()) !=
                  jsonEncode(updated.dataset.toJson()) ||
              previous.label != updated.label ||
              previous.createdAt != updated.createdAt ||
              previous.policyVersion != updated.policyVersion)) {
        throw StateError('Sealing cannot rewrite the source period');
      }
    }
  }

  if (old == null) {
    if (next.periods.length != 1)
      throw StateError('Initial book must have one active period');
  } else {
    final oldIds = old.periods.map((p) => p.periodId).toList();
    final nextIds = next.periods.map((p) => p.periodId).toList();
    final rollover = next.activePeriodId != old.activePeriodId;
    final expectedIds = [...oldIds, if (rollover) next.activePeriodId];
    if (jsonEncode(nextIds) != jsonEncode(expectedIds) ||
        (rollover &&
            (oldIds.contains(next.activePeriodId) ||
                !next.periods
                    .firstWhere((p) => p.periodId == old.activePeriodId)
                    .isSealed))) {
      throw StateError('Invalid period transition');
    }
  }
}

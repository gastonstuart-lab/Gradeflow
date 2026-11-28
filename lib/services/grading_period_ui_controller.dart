import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/grading_period.dart';
import '../models/grading_rollover_request.dart';
import '../repositories/grading_period_repository.dart';
import 'grading_period_service.dart';

/// Opt-in UI session. Never installs a global repository or migrates records.
class GradingPeriodUiController extends ChangeNotifier {
  final GradingPeriodRepository repository;
  final String classId;
  GradingPeriodBook? book;
  String? selectedId;
  GradingRolloverRequest? pending;
  String message = 'Loading grading periods…';
  String? error;
  int _saving = 0;
  int viewEpoch = 0;
  Future<void> _writes = Future.value();
  GradingPeriodUiController(this.repository, this.classId);
  bool get busy => _saving > 0;
  bool get locked => busy || pending != null || error != null;
  GradingPeriod get selected =>
      book!.periods.firstWhere((p) => p.periodId == selectedId);
  String get pendingKey =>
      'grading-period-preview:v1:${repository.ownerId}:$classId';

  Future<void> initialize() async {
    _saving++;
    notifyListeners();
    try {
      final stored =
          (await SharedPreferences.getInstance()).getString(pendingKey);
      if (stored != null) {
        final intent = GradingRolloverRequest.fromJson(jsonDecode(stored));
        if (intent.ownerId != repository.ownerId || intent.classId != classId)
          throw StateError('Wrong pending context');
        pending = intent;
      }
      final loaded = await repository.load(classId);
      if (loaded == null ||
          loaded.ownerId != repository.ownerId ||
          loaded.classId != classId)
        throw StateError('Grading period unavailable');
      book = loaded;
      if (!loaded.periods.any((p) => p.periodId == selectedId))
        selectedId = loaded.activePeriodId;
      viewEpoch++;
      error = null;
      message = pending == null
          ? 'All changes saved'
          : 'Rollover outcome unconfirmed. Recover before editing.';
    } catch (_) {
      error = 'Could not load this gradebook. Check the emulators and reload.';
    } finally {
      _saving--;
      notifyListeners();
    }
  }

  void select(String id) {
    if (busy || !book!.periods.any((p) => p.periodId == id)) return;
    selectedId = id;
    viewEpoch++;
    notifyListeners();
  }

  Future<void> mutate(String field, Object value) {
    _saving++;
    message = 'Saving grades…';
    notifyListeners();
    final operation = _writes.then((_) async {
      if (pending != null || error != null || selected.isSealed)
        throw StateError('This period is read only');
      final before = book!;
      final json = before.active.dataset.toJson()..[field] = value;
      final updated = GradingPeriod(
          periodId: before.active.periodId,
          label: before.active.label,
          createdAt: before.active.createdAt,
          policyVersion: before.active.policyVersion,
          dataset: GradebookDataset.fromJson(json));
      final next = GradingPeriodBook(
          ownerId: before.ownerId,
          classId: classId,
          revision: before.revision + 1,
          activePeriodId: before.activePeriodId,
          periods: [for (final p in before.periods) p.isSealed ? p : updated]);
      await repository.compareAndSet(next, expectedRevision: before.revision);
      book = next;
      message = 'All changes saved';
    });
    _writes = operation.catchError((_) {});
    return operation.catchError((Object e) {
      error =
          'Save could not be confirmed. Reload before editing.';
      throw e;
    }).whenComplete(() {
      _saving--;
      notifyListeners();
    });
  }

  Future<void> start(String name) async {
    if (locked || selected.isSealed || name.trim().isEmpty)
      throw StateError('Cannot start a period now');
    // Reserve the rollover before yielding so another request cannot replace it.
    pending = GradingRolloverRequest(
        ownerId: repository.ownerId,
        classId: classId,
        sourcePeriodId: book!.activePeriodId,
        expectedRevision: book!.revision,
        nextPeriodId: const Uuid().v4(),
        operationId: const Uuid().v4(),
        label: name.trim(),
        at: DateTime.now().toUtc());
    _saving++;
    message = 'Saving rollover request…';
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString(pendingKey, jsonEncode(pending!.toJson())))
        throw StateError('Intent was not saved');
    } catch (_) {
      pending = null;
      error = 'Cannot retain the request on this device. No rollover was sent.';
      _saving--;
      notifyListeners();
      return;
    }
    _saving--;
    await recover();
  }

  Future<void> recover() async {
    if (busy || pending == null) return;
    final intent = pending!;
    _saving++;
    error = null;
    message = 'Confirming rollover receipt…';
    notifyListeners();
    try {
      final result = await GradingPeriodService(repository).rollover(
          classId: intent.classId,
          periodId: intent.sourcePeriodId,
          expectedRevision: intent.expectedRevision,
          nextPeriodId: intent.nextPeriodId,
          label: intent.label,
          at: intent.at,
          weights: intent.weights,
          operationId: intent.operationId);
      if (result.ownerId != repository.ownerId || result.classId != classId)
        throw StateError('Response mismatch');
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.remove(pendingKey))
        throw StateError('Receipt confirmed but request could not be cleared');
      book = result;
      selectedId = result.activePeriodId;
      pending = null;
      viewEpoch++;
      message = 'Grading period ready · 20 editable assessments';
    } catch (_) {
      error =
          'Rollover is unconfirmed. Check the connection, then Recover rollover. The same request is retained.';
    } finally {
      _saving--;
      notifyListeners();
    }
  }
}

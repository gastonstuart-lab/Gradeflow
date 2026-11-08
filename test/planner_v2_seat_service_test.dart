import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Existing platform test seam; no new dependency.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:gradeflow/models/seating_layout.dart';
import 'package:gradeflow/repositories/repository_factory.dart';
import 'package:gradeflow/services/seating_service.dart';

class ControlledPreferences extends InMemorySharedPreferencesStore {
  ControlledPreferences() : super.empty();
  int writes = 0;
  bool reject = false;
  Completer<void>? hold;
  @override
  Future<bool> setValue(String type, String key, Object value) async {
    if (key.contains('seating_layouts_')) {
      writes++;
      if (hold != null) await hold!.future;
      if (reject) return false;
    }
    return super.setValue(type, key, value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SeatingService service;
  late ControlledPreferences store;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = ControlledPreferences();
    SharedPreferencesStorePlatform.instance = store;
    RepositoryFactory.useLocal();
    service = SeatingService();
    await service.loadLayouts('synthetic');
    await service.addTable('synthetic', SeatingTableType.rectangular,
        seatCount: 4);
    final s = service.activeLayout('synthetic')!.seats.first;
    await service.assignStudentToSeat(
        'synthetic', s.seatId, 'synthetic-student');
    await service.setSeatStatus('synthetic', s.seatId, SeatStatusColor.green);
    await RepositoryFactory.instance.flushPendingWrites();
    store.writes = 0;
  });
  tearDown(() => service.dispose());
  test(
      'one save beyond legacy clamp preserves metadata, siblings and table; reload is durable',
      () async {
    final before = service.activeLayout('synthetic')!;
    final seat = before.seats.first;
    final t = before.tables.single;
    final moved = seat.copyWith(
        x: before.canvasWidth - 50 - t.x,
        y: before.canvasHeight - 50 - t.y,
        studentId: 'forged',
        note: 'forged',
        tableId: 'forged');
    await service.commitPlannerV2SeatGeometry('synthetic', moved);
    expect(store.writes, 1);
    final after = service.activeLayout('synthetic')!;
    expect(after.tables.map((t) => t.toJson()),
        before.tables.map((t) => t.toJson()));
    expect(after.seats.first.toJson(),
        seat.copyWith(x: moved.x, y: moved.y).toJson());
    expect(after.seats.skip(1).map((s) => s.toJson()),
        before.seats.skip(1).map((s) => s.toJson()));
    final reopened = SeatingService();
    await reopened.loadLayouts('synthetic');
    expect(reopened.activeLayout('synthetic')!.toJson(), after.toJson());
    reopened.dispose();
  });
  test(
      'mixed table/seat history is chronological and retains newer assignments on undo',
      () async {
    final before = service.activeLayout('synthetic')!;
    final seat = before.seats.first;
    final t = before.tables.single;
    await service.commitPlannerV2SeatGeometry(
        'synthetic', seat.copyWith(x: seat.x + 100));
    await service.commitPlannerV2TableGeometry(
        'synthetic', t.copyWith(x: t.x + 50));
    await service.assignStudentToSeat('synthetic', seat.seatId, 'new-student');
    await service.undoPlannerV2('synthetic');
    expect(service.activeLayout('synthetic')!.tables.single.x, t.x);
    await service.undoPlannerV2('synthetic');
    expect(service.activeLayout('synthetic')!.seats.first.x, seat.x);
    expect(service.activeLayout('synthetic')!.seats.first.studentId,
        'new-student');
    await service.redoPlannerV2('synthetic');
    await service.redoPlannerV2('synthetic');
    expect(service.activeLayout('synthetic')!.tables.single.x, t.x + 50);
    expect(service.activeLayout('synthetic')!.seats.first.x, seat.x + 100);
    await service.undoPlannerV2('synthetic');
    await service.commitPlannerV2SeatGeometry(
        'synthetic', seat.copyWith(x: seat.x + 120));
    expect(service.canRedoPlannerV2('synthetic'), false);
  });
  test(
      'failed write rolls back memory and preference cache without history; retry succeeds',
      () async {
    final before = service.activeLayout('synthetic')!;
    final seat = before.seats.first;
    store.reject = true;
    await expectLater(
        service.commitPlannerV2SeatGeometry(
            'synthetic', seat.copyWith(x: seat.x + 100)),
        throwsStateError);
    expect(service.activeLayout('synthetic')!.toJson(), before.toJson());
    expect(service.plannerV2SaveState('synthetic'), PlannerV2SaveState.failed);
    expect(service.canUndoPlannerV2('synthetic'), false);
    final reopened = SeatingService();
    await reopened.loadLayouts('synthetic');
    expect(reopened.activeLayout('synthetic')!.toJson(), before.toJson());
    reopened.dispose();
    store.reject = false;
    await service.commitPlannerV2SeatGeometry(
        'synthetic', seat.copyWith(x: seat.x + 100));
    expect(service.canUndoPlannerV2('synthetic'), true);
    store.reject = true;
    await expectLater(service.undoPlannerV2('synthetic'), throwsStateError);
    expect(service.canUndoPlannerV2('synthetic'), true);
    expect(service.canRedoPlannerV2('synthetic'), false);
  });
  test(
      'pending write rejects competing transactions and does not create extra saves',
      () async {
    final seat = service.activeLayout('synthetic')!.seats.first;
    store.hold = Completer<void>();
    final pending = service.commitPlannerV2SeatGeometry(
        'synthetic', seat.copyWith(x: seat.x + 100));
    await Future<void>.delayed(Duration.zero);
    expect(service.plannerV2SaveState('synthetic'), PlannerV2SaveState.saving);
    await expectLater(
        service.commitPlannerV2SeatGeometry(
            'synthetic', seat.copyWith(x: seat.x + 150)),
        throwsStateError);
    expect(await service.undoPlannerV2('synthetic'), false);
    store.hold!.complete();
    await pending;
    expect(store.writes, 1);
  });
  test('non-finite/outside room proposals are rejected; no-op writes nothing',
      () async {
    final seat = service.activeLayout('synthetic')!.seats.first;
    for (final x in [double.nan, double.infinity, 99999.0, -99999.0]) {
      await expectLater(
          service.commitPlannerV2SeatGeometry('synthetic', seat.copyWith(x: x)),
          throwsArgumentError);
    }
    await service.commitPlannerV2SeatGeometry('synthetic', seat);
    expect(store.writes, 0);
    expect(service.canUndoPlannerV2('synthetic'), false);
  });
}

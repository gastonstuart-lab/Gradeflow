import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:gradeflow/models/seating_layout.dart';
import 'package:gradeflow/repositories/repository_factory.dart';
import 'package:gradeflow/services/seating_service.dart';

class RejectRoomStage extends InMemorySharedPreferencesStore {
  RejectRoomStage() : super.empty();
  String? failKey;
  bool throws = false;
  bool persistent = false;
  @override
  Future<bool> setValue(String type, String key, Object value) async {
    if (failKey != null && key.endsWith(failKey!)) {
      if (!persistent) failKey = null;
      if (throws) throw StateError('Fictional failed write');
      return false;
    }
    return super.setValue(type, key, value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('unconfirmed recovery is reported and is never counted as success', () async {
    final store = RejectRoomStage();
    SharedPreferencesStorePlatform.instance = store;
    RepositoryFactory.useLocal();
    final service = SeatingService();
    await service.loadLayouts('source');
    await service.loadLayouts('target');
    await service.addTable('source', SeatingTableType.rectangular, seatCount: 4);
    final room = await service.saveRoomSetupFromLayout(classId: 'source', name: 'Fictional room');
    store.failKey = 'seating_layouts_target'; store.persistent = true;
    await expectLater(service.applyRoomSetupToClass(classId: 'target', roomSetupId: room!.roomSetupId),
      throwsA(isA<StateError>().having((e) => e.message.toString(), 'recovery error', contains('recovery could not be confirmed'))));
    expect(service.activeLayout('target')!.tables, isEmpty);
    store.failKey = null;
    expect(await service.applyRoomSetupToClass(classId: 'target', roomSetupId: room.roomSetupId), isNotNull);
    service.dispose();
  });
  test('failed source-room link rolls back the newly saved template', () async {
    final store = RejectRoomStage();
    SharedPreferencesStorePlatform.instance = store;
    RepositoryFactory.useLocal();
    final service = SeatingService();
    await service.loadLayouts('source');
    await service.addTable('source', SeatingTableType.rectangular, seatCount: 4);
    store.failKey = 'seating_room_setup_source';
    await expectLater(service.saveRoomSetupFromLayout(classId: 'source', name: 'Fictional room'), throwsStateError);
    expect(await RepositoryFactory.instance.loadRoomSetups(), isEmpty);
    expect(await RepositoryFactory.instance.loadAssignedRoomSetupId('source'), isNull);
    expect(service.roomSetups, isEmpty);
    service.dispose();
  });
  for (final thrown in [false, true]) {
    for (final key in [
      'seating_layouts_target',
      'seating_active_layout_target',
      'seating_room_setup_target'
    ]) {
      test(
          'room reuse rejects ${thrown ? "thrown" : "false"} $key write, restores and retries',
          () async {
        final store = RejectRoomStage();
        SharedPreferencesStorePlatform.instance = store;
        RepositoryFactory.useLocal();
        final service = SeatingService();
        await service.loadLayouts('source');
        await service.loadLayouts('target');
        await service.addTable('source', SeatingTableType.rectangular,
            seatCount: 4);
        await service.assignStudentToSeat('source',
            service.activeLayout('source')!.seats.first.seatId, 'source-only');
        // Protect a target arrangement which must stay available as an alternative.
        await service.addTable('target', SeatingTableType.singleDesk,
            seatCount: 1);
        await service.assignStudentToSeat('target',
            service.activeLayout('target')!.seats.first.seatId, 'target-only');
        final oldId = service.activeLayout('target')!.layoutId;
        final room = await service.saveRoomSetupFromLayout(
            classId: 'source', name: 'Fictional room');
        store.failKey = key;
        store.throws = thrown;
        await expectLater(
            service.applyRoomSetupToClass(
                classId: 'target', roomSetupId: room!.roomSetupId),
            throwsStateError);
        expect(service.activeLayout('target')!.layoutId, oldId);
        final fresh = SeatingService();
        await fresh.loadLayouts('target');
        expect(fresh.activeLayout('target')!.layoutId, oldId);
        expect(fresh.activeLayout('target')!.seats.single.studentId,
            'target-only');
        expect(fresh.assignedRoomSetupId('target'), isNull);
        await service.applyRoomSetupToClass(
            classId: 'target', roomSetupId: room.roomSetupId);
        final reopened = SeatingService();
        await reopened.loadLayouts('target');
        expect(reopened.assignedRoomSetupId('target'), room.roomSetupId);
        expect(reopened.activeLayout('target')!.seats, hasLength(4));
        expect(
            reopened
                .activeLayout('target')!
                .seats
                .every((s) => s.studentId == null),
            isTrue);
        expect(
            reopened
                .layoutsForClass('target')
                .where((l) => l.layoutId == oldId)
                .single
                .seats
                .single
                .studentId,
            'target-only');
        service.dispose();
        fresh.dispose();
        reopened.dispose();
      });
    }
  }
  test(
      'shared template rejection leaves no saved template or phantom room and permits retry',
      () async {
    final store = RejectRoomStage();
    SharedPreferencesStorePlatform.instance = store;
    RepositoryFactory.useLocal();
    final service = SeatingService();
    await service.loadLayouts('source');
    await service.addTable('source', SeatingTableType.rectangular,
        seatCount: 4);
    store.failKey = 'room_setups';
    await expectLater(
        service.saveRoomSetupFromLayout(
            classId: 'source', name: 'Fictional room'),
        throwsStateError);
    expect(service.roomSetups, isEmpty);
    expect(await RepositoryFactory.instance.loadRoomSetups(), isEmpty);
    expect(
        await service.saveRoomSetupFromLayout(
            classId: 'source', name: 'Fictional room'),
        isNotNull);
    service.dispose();
  });

  test('Classroom status labels have no corrupt control or replacement characters', () {
    final source = File('lib/os/surfaces/classroom_surface.dart').readAsStringSync();
    expect(source.contains('\u0007'), isFalse);
    expect(source.contains('\uFFFD'), isFalse);
    expect(source, contains('students ·'));
    expect(source, contains('  •  '));
  });
}

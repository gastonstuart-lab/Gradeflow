import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/models/class.dart';
import 'package:gradeflow/models/seating_layout.dart';
import 'package:gradeflow/models/student.dart';
import 'package:gradeflow/repositories/repository_factory.dart';
import 'package:gradeflow/services/seating_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    RepositoryFactory.useLocal();
  });

  test('rotateTable swaps table orientation and preserves assignments',
      () async {
    final service = SeatingService();

    await service.loadLayouts('class-a');
    await service.addTable(
      'class-a',
      SeatingTableType.rectangular,
      seatCount: 4,
    );

    final initialLayout = service.activeLayout('class-a')!;
    final initialTable = initialLayout.tables.single;
    final initialSeat = initialLayout.seats.first;

    await service.assignStudentToSeat('class-a', initialSeat.seatId, 'stu-1');
    await service.setSeatStatus(
      'class-a',
      initialSeat.seatId,
      SeatStatusColor.green,
    );
    await service.rotateTable('class-a', initialTable.tableId);

    final rotatedLayout = service.activeLayout('class-a')!;
    final rotatedTable = rotatedLayout.tables.single;

    expect(rotatedTable.width, greaterThanOrEqualTo(initialTable.height));
    expect(rotatedTable.height, initialTable.width);
    expect(rotatedTable.width, lessThan(rotatedTable.height));
    expect(rotatedLayout.seats, hasLength(initialLayout.seats.length));
    expect(
      rotatedLayout.seats.where((seat) => seat.studentId == 'stu-1'),
      hasLength(1),
    );
    expect(
      rotatedLayout.seats
          .where((seat) => seat.statusColor == SeatStatusColor.green),
      hasLength(1),
    );
  });

  test('moveTable keeps tables inside the room bounds', () async {
    final service = SeatingService();

    await service.loadLayouts('class-a');
    await service.addTable(
      'class-a',
      SeatingTableType.rectangular,
      seatCount: 4,
    );

    final initialLayout = service.activeLayout('class-a')!;
    final tableId = initialLayout.tables.single.tableId;

    await service.moveTable('class-a', tableId, 5000, 5000);
    var table = service.activeLayout('class-a')!.tables.single;
    expect(table.x, 1020);
    expect(table.y, 655);

    await service.moveTable('class-a', tableId, -5000, -5000);
    table = service.activeLayout('class-a')!.tables.single;
    expect(table.x, 180);
    expect(table.y, 145);
  });

  test('updateCanvasSize pulls existing tables back into view', () async {
    final service = SeatingService();

    await service.loadLayouts('class-a');
    await service.addTable(
      'class-a',
      SeatingTableType.rectangular,
      seatCount: 4,
    );

    final initialLayout = service.activeLayout('class-a')!;
    final tableId = initialLayout.tables.single.tableId;

    await service.moveTable('class-a', tableId, 5000, 5000);
    await service.updateCanvasSize(
      'class-a',
      width: 600,
      height: 400,
    );

    final resizedLayout = service.activeLayout('class-a')!;
    final table = resizedLayout.tables.single;
    expect(resizedLayout.canvasWidth, 600);
    expect(resizedLayout.canvasHeight, 400);
    expect(table.x, 420);
    expect(table.y, 255);
  });

  test('duplicateTable copies the furniture without copying assignments',
      () async {
    final service = SeatingService();

    await service.loadLayouts('class-a');
    await service.addTable(
      'class-a',
      SeatingTableType.rectangular,
      seatCount: 4,
    );

    final initialLayout = service.activeLayout('class-a')!;
    final originalTable = initialLayout.tables.single;
    final originalSeat = initialLayout.seats.first;
    await service.assignStudentToSeat('class-a', originalSeat.seatId, 'stu-1');

    await service.duplicateTable('class-a', originalTable.tableId);

    final duplicatedLayout = service.activeLayout('class-a')!;
    expect(duplicatedLayout.tables, hasLength(2));
    expect(duplicatedLayout.seats, hasLength(8));
    expect(
      duplicatedLayout.seats.where((seat) => seat.studentId == 'stu-1'),
      hasLength(1),
    );
  });

  test('duplicateSeat adds another seat and moveSeat can push it farther out',
      () async {
    final service = SeatingService();

    await service.loadLayouts('class-a');
    await service.addTable(
      'class-a',
      SeatingTableType.rectangular,
      seatCount: 4,
    );

    final initialLayout = service.activeLayout('class-a')!;
    final table = initialLayout.tables.single;
    final seat = initialLayout.seats.first;

    await service.duplicateSeat('class-a', seat.seatId);

    final duplicatedLayout = service.activeLayout('class-a')!;
    final duplicatedTable = duplicatedLayout.tables.single;
    final duplicatedSeats = duplicatedLayout.seats
        .where((entry) => entry.tableId == table.tableId)
        .toList();
    final copiedSeat =
        duplicatedSeats.firstWhere((entry) => entry.seatId != seat.seatId);

    expect(duplicatedTable.seatCount, 5);
    expect(duplicatedSeats, hasLength(5));

    await service.moveSeat('class-a', copiedSeat.seatId, 999, 999);

    final movedSeat = service
        .activeLayout('class-a')!
        .seats
        .firstWhere((entry) => entry.seatId == copiedSeat.seatId);
    expect(movedSeat.x, greaterThan(200));
    expect(movedSeat.y, greaterThan(150));
  });

  test('assignStudentToTable uses the next empty seat on the target table',
      () async {
    final service = SeatingService();

    await service.loadLayouts('class-a');
    await service.addTable(
      'class-a',
      SeatingTableType.rectangular,
      seatCount: 4,
    );
    await service.addTable(
      'class-a',
      SeatingTableType.singleDesk,
      seatCount: 1,
    );

    final initialLayout = service.activeLayout('class-a')!;
    final sourceSeat = initialLayout.seats.first;
    final targetTable = initialLayout.tables.last;
    final targetSeat = initialLayout.seats
        .firstWhere((seat) => seat.tableId == targetTable.tableId);

    await service.assignStudentToSeat('class-a', sourceSeat.seatId, 'stu-1');
    final assigned = await service.assignStudentToTable(
      'class-a',
      targetTable.tableId,
      'stu-1',
      fromSeatId: sourceSeat.seatId,
    );

    final updatedLayout = service.activeLayout('class-a')!;
    expect(assigned, isTrue);
    expect(
      updatedLayout.seats
          .firstWhere((seat) => seat.seatId == targetSeat.seatId)
          .studentId,
      'stu-1',
    );
    expect(
      updatedLayout.seats
          .firstWhere((seat) => seat.seatId == sourceSeat.seatId)
          .studentId,
      isNull,
    );
  });

  test('updateSeatNote saves note text and reminder state', () async {
    final service = SeatingService();

    await service.loadLayouts('class-a');
    await service.addTable(
      'class-a',
      SeatingTableType.singleDesk,
      seatCount: 1,
    );

    final seatId = service.activeLayout('class-a')!.seats.single.seatId;
    await service.updateSeatNote(
      'class-a',
      seatId,
      note: 'Check homework before dismissal',
      reminder: true,
    );

    final updatedSeat = service.activeLayout('class-a')!.seats.single;
    expect(updatedSeat.note, 'Check homework before dismissal');
    expect(updatedSeat.reminder, isTrue);
  });

  test('copyRoomLayoutToClass copies room structure without placements',
      () async {
    final service = SeatingService();

    await service.loadLayouts('class-a');
    await service.loadLayouts('class-b');
    await service.addTable(
      'class-a',
      SeatingTableType.rectangular,
      seatCount: 4,
    );
    await service.addTable(
      'class-a',
      SeatingTableType.singleDesk,
      seatCount: 1,
    );

    final sourceLayout = service.activeLayout('class-a')!;
    final sourceSeat = sourceLayout.seats.first;
    await service.assignStudentToSeat('class-a', sourceSeat.seatId, 'stu-1');
    await service.setSeatLocked('class-a', sourceSeat.seatId, true);
    await service.updateSeatNote(
      'class-a',
      sourceSeat.seatId,
      note: 'Front row focus',
      reminder: true,
    );

    final copiedLayout = await service.copyRoomLayoutToClass(
      sourceClassId: 'class-a',
      targetClassId: 'class-b',
      sourceLayoutId: sourceLayout.layoutId,
      name: 'Copied room',
    );

    expect(copiedLayout, isNotNull);
    expect(copiedLayout!.classId, 'class-b');
    expect(copiedLayout.name, 'Copied room');
    expect(copiedLayout.tables, hasLength(sourceLayout.tables.length));
    expect(copiedLayout.seats, hasLength(sourceLayout.seats.length));
    expect(service.layoutsForClass('class-b'), hasLength(1));
    expect(
      copiedLayout.tables.map((table) => table.tableId).toSet().length,
      copiedLayout.tables.length,
    );
    for (final table in copiedLayout.tables) {
      final copiedSeatCount = copiedLayout.seats
          .where((seat) => seat.tableId == table.tableId)
          .length;
      expect(copiedSeatCount, table.seatCount);
    }
    expect(
      copiedLayout.seats.every(
        (seat) =>
            seat.studentId == null &&
            !seat.locked &&
            seat.note.isEmpty &&
            !seat.reminder,
      ),
      isTrue,
    );
  });

  test('saveRoomSetupFromLayout stores a reusable room and links the class',
      () async {
    final service = SeatingService();

    await service.loadLayouts('class-a');
    await service.addTable(
      'class-a',
      SeatingTableType.rectangular,
      seatCount: 4,
    );

    final layout = service.activeLayout('class-a')!;
    await service.assignStudentToSeat(
        'class-a', layout.seats.first.seatId, 'stu-1');
    await service.updateSeatNote(
      'class-a',
      layout.seats.first.seatId,
      note: 'Needs front row',
      reminder: true,
    );

    final roomSetup = await service.saveRoomSetupFromLayout(
      classId: 'class-a',
      name: 'Room 101',
    );

    expect(roomSetup, isNotNull);
    expect(service.roomSetups, hasLength(1));
    expect(service.assignedRoomSetupId('class-a'), roomSetup!.roomSetupId);
    expect(roomSetup.tables, hasLength(layout.tables.length));
    expect(roomSetup.seats, hasLength(layout.seats.length));
    expect(
      roomSetup.seats.every(
        (seat) =>
            seat.studentId == null &&
            seat.statusColor == SeatStatusColor.none &&
            !seat.locked &&
            seat.note.isEmpty &&
            !seat.reminder,
      ),
      isTrue,
    );

    final reloaded = SeatingService();
    await reloaded.loadRoomSetups();
    await reloaded.loadLayouts('class-a');

    expect(reloaded.roomSetups, hasLength(1));
    expect(reloaded.roomSetups.single.name, 'Room 101');
    expect(
      reloaded.assignedRoomSetupId('class-a'),
      roomSetup.roomSetupId,
    );
  });

  test(
      'applyRoomSetupToClass reuses a blank class and protects an existing arrangement',
      () async {
    final service = SeatingService();

    await service.loadLayouts('class-a');
    await service.addTable(
      'class-a',
      SeatingTableType.rectangular,
      seatCount: 4,
    );
    final savedRoom = await service.saveRoomSetupFromLayout(
      classId: 'class-a',
      name: 'Science Lab',
    );

    await service.loadLayouts('class-b');
    final blankApply = await service.applyRoomSetupToClass(
      classId: 'class-b',
      roomSetupId: savedRoom!.roomSetupId,
    );

    expect(blankApply, isNotNull);
    expect(blankApply!.createdNewLayout, isFalse);
    expect(service.layoutsForClass('class-b'), hasLength(1));
    expect(service.activeLayout('class-b')!.name, 'Science Lab');
    expect(service.activeLayout('class-b')!.tables, hasLength(1));
    expect(service.assignedRoomSetupId('class-b'), savedRoom.roomSetupId);

    await service.loadLayouts('class-c');
    await service.addTable(
      'class-c',
      SeatingTableType.singleDesk,
      seatCount: 1,
    );
    final occupiedSeat = service.activeLayout('class-c')!.seats.single;
    await service.assignStudentToSeat('class-c', occupiedSeat.seatId, 'stu-9');

    final occupiedApply = await service.applyRoomSetupToClass(
      classId: 'class-c',
      roomSetupId: savedRoom.roomSetupId,
    );

    expect(occupiedApply, isNotNull);
    expect(occupiedApply!.createdNewLayout, isTrue);
    expect(service.layoutsForClass('class-c'), hasLength(2));
    expect(service.activeLayout('class-c')!.layoutId,
        occupiedApply.layout.layoutId);
    expect(service.activeLayout('class-c')!.name, 'Science Lab');
    expect(
      service.activeLayout('class-c')!.seats.every(
            (seat) => seat.studentId == null,
          ),
      isTrue,
    );
  });

  test(
      'refreshLinkedClassesFromRoomSetup updates linked rooms and preserves seat annotations',
      () async {
    final service = SeatingService();
    final repo = RepositoryFactory.instance;
    final timestamp = DateTime(2026, 1, 1);

    await repo.saveClasses([
      Class(
        classId: 'class-a',
        className: 'Alpha',
        subject: 'Science',
        schoolYear: '2025-2026',
        term: 'Spring',
        teacherId: 'teacher-1',
        createdAt: timestamp,
        updatedAt: timestamp,
      ),
      Class(
        classId: 'class-b',
        className: 'Beta',
        subject: 'Science',
        schoolYear: '2025-2026',
        term: 'Spring',
        teacherId: 'teacher-1',
        createdAt: timestamp,
        updatedAt: timestamp,
      ),
    ]);

    await service.loadLayouts('class-a');
    await service.loadLayouts('class-b');
    await service.addTable(
      'class-a',
      SeatingTableType.rectangular,
      seatCount: 4,
    );

    final savedRoom = await service.saveRoomSetupFromLayout(
      classId: 'class-a',
      name: 'Shared Lab',
    );

    await service.applyRoomSetupToClass(
      classId: 'class-b',
      roomSetupId: savedRoom!.roomSetupId,
    );

    final originalSeatCount = service.activeLayout('class-b')!.seats.length;
    final trackedSeat = service.activeLayout('class-b')!.seats.first;
    await service.assignStudentToSeat('class-b', trackedSeat.seatId, 'stu-1');
    await service.setSeatLocked('class-b', trackedSeat.seatId, true);
    await service.updateSeatNote(
      'class-b',
      trackedSeat.seatId,
      note: 'Needs front row',
      reminder: true,
    );

    await service.addTable(
      'class-a',
      SeatingTableType.singleDesk,
      seatCount: 1,
    );
    await service.saveRoomSetupFromLayout(
      classId: 'class-a',
      roomSetupId: savedRoom.roomSetupId,
      name: 'Shared Lab',
    );

    final refreshedCount =
        await service.refreshLinkedClassesFromRoomSetup(savedRoom.roomSetupId);
    final refreshedLayout = service.activeLayout('class-b')!;
    final refreshedSeat = refreshedLayout.seats.firstWhere(
      (seat) => seat.seatId == trackedSeat.seatId,
    );

    expect(refreshedCount, 2);
    expect(refreshedLayout.tables, hasLength(2));
    expect(refreshedLayout.seats.length, greaterThan(originalSeatCount));
    expect(refreshedSeat.studentId, 'stu-1');
    expect(refreshedSeat.locked, isTrue);
    expect(refreshedSeat.note, 'Needs front row');
    expect(refreshedSeat.reminder, isTrue);
    expect(service.assignedRoomSetupId('class-b'), savedRoom.roomSetupId);
  });

  test('shuffleStudentPlacements randomizes seated students in seat order',
      () async {
    final service = SeatingService();

    await service.loadLayouts('class-a');
    await service.addTable(
      'class-a',
      SeatingTableType.rectangular,
      seatCount: 4,
    );

    final students = [
      Student(
        studentId: 'stu-1',
        chineseName: 'A',
        englishFirstName: 'A',
        englishLastName: 'One',
        classId: 'class-a',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
      Student(
        studentId: 'stu-2',
        chineseName: 'B',
        englishFirstName: 'B',
        englishLastName: 'Two',
        classId: 'class-a',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
      Student(
        studentId: 'stu-3',
        chineseName: 'C',
        englishFirstName: 'C',
        englishLastName: 'Three',
        classId: 'class-a',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
      Student(
        studentId: 'stu-4',
        chineseName: 'D',
        englishFirstName: 'D',
        englishLastName: 'Four',
        classId: 'class-a',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
    ];

    final layout = service.activeLayout('class-a')!;
    for (int i = 0; i < layout.seats.length; i++) {
      await service.assignStudentToSeat(
        'class-a',
        layout.seats[i].seatId,
        students[i].studentId,
      );
    }

    final before = service
        .orderedSeatsForLayout(service.activeLayout('class-a')!)
        .map((seat) => seat.studentId)
        .toList();

    await service.shuffleStudentPlacements(
      'class-a',
      students,
      random: math.Random(3),
    );

    final after = service
        .orderedSeatsForLayout(service.activeLayout('class-a')!)
        .map((seat) => seat.studentId)
        .toList();

    expect(after.toSet(), before.toSet());
    expect(after, isNot(before));
  });

  test('shuffleStudentPlacements keeps locked seats fixed', () async {
    final service = SeatingService();

    await service.loadLayouts('class-a');
    await service.addTable(
      'class-a',
      SeatingTableType.rectangular,
      seatCount: 4,
    );

    final students = [
      Student(
        studentId: 'stu-1',
        chineseName: 'A',
        englishFirstName: 'A',
        englishLastName: 'One',
        classId: 'class-a',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
      Student(
        studentId: 'stu-2',
        chineseName: 'B',
        englishFirstName: 'B',
        englishLastName: 'Two',
        classId: 'class-a',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
      Student(
        studentId: 'stu-3',
        chineseName: 'C',
        englishFirstName: 'C',
        englishLastName: 'Three',
        classId: 'class-a',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
      Student(
        studentId: 'stu-4',
        chineseName: 'D',
        englishFirstName: 'D',
        englishLastName: 'Four',
        classId: 'class-a',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
    ];

    final layout = service.activeLayout('class-a')!;
    for (int i = 0; i < layout.seats.length; i++) {
      await service.assignStudentToSeat(
        'class-a',
        layout.seats[i].seatId,
        students[i].studentId,
      );
    }
    await service.setSeatLocked('class-a', layout.seats.first.seatId, true);

    final lockedBefore = service
        .activeLayout('class-a')!
        .seats
        .firstWhere((seat) => seat.seatId == layout.seats.first.seatId);

    await service.shuffleStudentPlacements(
      'class-a',
      students,
      random: math.Random(7),
    );

    final shuffledLayout = service.activeLayout('class-a')!;
    final lockedAfter = shuffledLayout.seats
        .firstWhere((seat) => seat.seatId == layout.seats.first.seatId);
    final unlockedAfter = shuffledLayout.seats
        .where((seat) => seat.seatId != layout.seats.first.seatId)
        .map((seat) => seat.studentId)
        .toList();

    expect(lockedAfter.locked, isTrue);
    expect(lockedAfter.studentId, lockedBefore.studentId);
    expect(unlockedAfter.toSet(), {
      'stu-2',
      'stu-3',
      'stu-4',
    });
  });
}

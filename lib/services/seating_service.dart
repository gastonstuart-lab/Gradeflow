import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:gradeflow/models/room_setup.dart';
import 'package:gradeflow/models/seating_layout.dart';
import 'package:gradeflow/models/student.dart';
import 'package:gradeflow/repositories/repository_factory.dart';

enum SeatingTemplateType { rows, groups, exam, currentClassroom }

class RoomSetupApplication {
  final SeatingLayout layout;
  final bool createdNewLayout;

  const RoomSetupApplication({
    required this.layout,
    required this.createdNewLayout,
  });
}

class SeatingService extends ChangeNotifier {
  static const double _tableBoundaryPadding = 110.0;
  static const double _seatBoundaryPadding = 180.0;
  final Map<String, List<SeatingLayout>> _layoutsByClass = {};
  final Map<String, String?> _activeLayoutIdByClass = {};
  final Map<String, String?> _assignedRoomSetupIdByClass = {};
  final List<RoomSetup> _roomSetups = [];
  int _idSequence = 0;
  bool _isLoading = false;

  bool get isLoading => _isLoading;
  List<RoomSetup> get roomSetups => List.unmodifiable(_roomSetups);

  List<SeatingLayout> layoutsForClass(String classId) =>
      _layoutsByClass[classId] ?? [];

  String? assignedRoomSetupId(String classId) =>
      _assignedRoomSetupIdByClass[classId];

  RoomSetup? roomSetupById(String roomSetupId) {
    return _roomSetups.cast<RoomSetup?>().firstWhere(
          (setup) => setup?.roomSetupId == roomSetupId,
          orElse: () => null,
        );
  }

  RoomSetup? assignedRoomSetup(String classId) {
    final roomSetupId = assignedRoomSetupId(classId);
    if (roomSetupId == null || roomSetupId.isEmpty) return null;
    return roomSetupById(roomSetupId);
  }

  SeatingLayout? activeLayout(String classId) {
    final layouts = layoutsForClass(classId);
    if (layouts.isEmpty) return null;
    final activeId = _activeLayoutIdByClass[classId];
    return activeId == null
        ? layouts.first
        : layouts.firstWhere((l) => l.layoutId == activeId,
            orElse: () => layouts.first);
  }

  Future<void> loadLayouts(String classId, {int studentCount = 0}) async {
    _isLoading = true;
    notifyListeners();
    try {
      final repo = RepositoryFactory.instance;
      final layouts = await repo.loadSeatingLayouts(classId);
      final storedActiveId = await repo.loadActiveSeatingLayoutId(classId);
      final storedRoomSetupId = await repo.loadAssignedRoomSetupId(classId);
      _assignedRoomSetupIdByClass[classId] = storedRoomSetupId;
      if (layouts.isEmpty) {
        final defaultLayout = buildBlankLayout(
          classId: classId,
          name: 'Blank canvas',
        );
        _layoutsByClass[classId] = [defaultLayout];
        _activeLayoutIdByClass[classId] = defaultLayout.layoutId;
        unawaited(repo.saveSeatingLayouts(classId, [defaultLayout]));
        unawaited(
            repo.saveActiveSeatingLayoutId(classId, defaultLayout.layoutId));
      } else {
        final normalized = layouts.map(_normalizeLayout).toList();
        _layoutsByClass[classId] = normalized;
        final preferred = storedActiveId != null &&
                normalized.any((l) => l.layoutId == storedActiveId)
            ? storedActiveId
            : normalized.first.layoutId;
        _activeLayoutIdByClass[classId] = preferred;
      }
    } catch (e) {
      debugPrint('Failed to load seating layouts: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadRoomSetups() async {
    try {
      final repo = RepositoryFactory.instance;
      final roomSetups = await repo.loadRoomSetups();
      _roomSetups
        ..clear()
        ..addAll(roomSetups.map(_normalizeRoomSetup));
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load room setups: $e');
    }
  }

  Future<void> selectLayout(String classId, String layoutId) async {
    _activeLayoutIdByClass[classId] = layoutId;
    try {
      final repo = RepositoryFactory.instance;
      await repo.saveActiveSeatingLayoutId(classId, layoutId);
    } catch (e) {
      debugPrint('Failed to save active layout: $e');
    }
    notifyListeners();
  }

  Future<SeatingLayout> createLayout(
    String classId,
    String name, {
    SeatingLayout? from,
  }) async {
    final now = DateTime.now();
    final layout = from?.copyWith(
          layoutId: _newId('layout'),
          name: name,
          createdAt: now,
          updatedAt: now,
        ) ??
        buildBlankLayout(
          classId: classId,
          name: name,
          layoutId: _newId('layout'),
          timestamp: now,
        );
    final layouts = layoutsForClass(classId);
    _layoutsByClass[classId] = [...layouts, layout];
    _activeLayoutIdByClass[classId] = layout.layoutId;
    await _persistLayouts(classId);
    try {
      final repo = RepositoryFactory.instance;
      await repo.saveActiveSeatingLayoutId(classId, layout.layoutId);
    } catch (e) {
      debugPrint('Failed to save active layout: $e');
    }
    notifyListeners();
    return layout;
  }

  Future<void> deleteLayout(String classId, String layoutId) async {
    final layouts = layoutsForClass(classId);
    layouts.removeWhere((l) => l.layoutId == layoutId);
    _layoutsByClass[classId] = layouts;
    _activeLayoutIdByClass[classId] =
        layouts.isEmpty ? null : layouts.first.layoutId;
    try {
      final repo = RepositoryFactory.instance;
      await repo.deleteSeatingLayout(classId, layoutId);
      if (layouts.isNotEmpty) {
        await repo.saveActiveSeatingLayoutId(classId, layouts.first.layoutId);
      }
    } catch (e) {
      debugPrint('Failed to delete seating layout: $e');
    }
    notifyListeners();
  }

  Future<void> renameLayout(
      String classId, String layoutId, String name) async {
    _updateLayout(
      classId,
      layoutId,
      (layout) => layout.copyWith(name: name, updatedAt: DateTime.now()),
    );
  }

  Future<RoomSetup?> saveRoomSetupFromLayout({
    required String classId,
    required String name,
    String? sourceLayoutId,
    String? roomSetupId,
  }) async {
    if (!_layoutsByClass.containsKey(classId)) {
      await loadLayouts(classId);
    }
    if (_roomSetups.isEmpty) {
      await loadRoomSetups();
    }

    final sourceLayouts = layoutsForClass(classId);
    final sourceLayout = sourceLayoutId == null
        ? activeLayout(classId)
        : sourceLayouts.cast<SeatingLayout?>().firstWhere(
              (layout) => layout?.layoutId == sourceLayoutId,
              orElse: () => null,
            );
    if (sourceLayout == null) return null;

    final existing = roomSetupId == null ? null : roomSetupById(roomSetupId);
    final now = DateTime.now();
    final roomSetup = RoomSetup.fromLayout(
      sourceLayout,
      roomSetupId: existing?.roomSetupId ?? _newId('room'),
      name: name,
      timestamp: now,
    ).copyWith(
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );

    final roomSetups = List<RoomSetup>.from(_roomSetups);
    final existingIndex = roomSetups.indexWhere(
      (setup) => setup.roomSetupId == roomSetup.roomSetupId,
    );
    if (existingIndex == -1) {
      roomSetups.add(roomSetup);
    } else {
      roomSetups[existingIndex] = roomSetup;
    }

    _roomSetups
      ..clear()
      ..addAll(roomSetups);
    await _persistRoomSetups();
    await _setAssignedRoomSetupId(
      classId,
      roomSetup.roomSetupId,
      notify: false,
    );
    notifyListeners();
    return roomSetup;
  }

  Future<SeatingLayout?> refreshClassFromAssignedRoom(String classId) async {
    if (!_layoutsByClass.containsKey(classId)) {
      await loadLayouts(classId);
    }
    if (_roomSetups.isEmpty) {
      await loadRoomSetups();
    }

    final roomSetupId = assignedRoomSetupId(classId);
    if (roomSetupId == null || roomSetupId.isEmpty) return null;
    final roomSetup = roomSetupById(roomSetupId);
    if (roomSetup == null) return null;

    final syncedLayouts = await _syncClassLayoutsFromRoomSetup(
      classId,
      roomSetup,
    );
    if (syncedLayouts == null || syncedLayouts.isEmpty) return null;

    final activeLayoutId = _activeLayoutIdByClass[classId];
    return syncedLayouts.cast<SeatingLayout?>().firstWhere(
          (layout) => layout?.layoutId == activeLayoutId,
          orElse: () => syncedLayouts.first,
        );
  }

  Future<int> refreshLinkedClassesFromRoomSetup(String roomSetupId) async {
    if (_roomSetups.isEmpty) {
      await loadRoomSetups();
    }
    final roomSetup = roomSetupById(roomSetupId);
    if (roomSetup == null) return 0;

    try {
      final repo = RepositoryFactory.instance;
      final classes = await repo.loadClasses();
      int refreshed = 0;

      for (final classItem in classes) {
        if (!_layoutsByClass.containsKey(classItem.classId)) {
          await loadLayouts(classItem.classId);
        }
        if (assignedRoomSetupId(classItem.classId) != roomSetupId) {
          continue;
        }

        final syncedLayouts = await _syncClassLayoutsFromRoomSetup(
          classItem.classId,
          roomSetup,
          notify: false,
        );
        if (syncedLayouts != null && syncedLayouts.isNotEmpty) {
          refreshed++;
        }
      }

      if (refreshed > 0) {
        notifyListeners();
      }
      return refreshed;
    } catch (e) {
      debugPrint('Failed to refresh linked classes from room setup: $e');
      return 0;
    }
  }

  Future<void> detachRoomSetupFromClass(String classId) async {
    await _setAssignedRoomSetupId(classId, null);
  }

  Future<RoomSetupApplication?> applyRoomSetupToClass({
    required String classId,
    required String roomSetupId,
  }) async {
    if (!_layoutsByClass.containsKey(classId)) {
      await loadLayouts(classId);
    }
    if (_roomSetups.isEmpty) {
      await loadRoomSetups();
    }

    final roomSetup = roomSetupById(roomSetupId);
    if (roomSetup == null) return null;

    final currentLayout = activeLayout(classId);
    if (currentLayout == null) return null;

    final shouldReplaceActiveLayout = _canReplaceLayoutWithRoomSetup(
      currentLayout,
    );
    final now = DateTime.now();
    final appliedLayout = roomSetup.toLayout(
      classId: classId,
      layoutId:
          shouldReplaceActiveLayout ? currentLayout.layoutId : _newId('layout'),
      name: _layoutNameForAppliedRoomSetup(
        roomSetup: roomSetup,
        currentLayout: currentLayout,
        replacingActiveLayout: shouldReplaceActiveLayout,
      ),
      timestamp: now,
    );

    if (shouldReplaceActiveLayout) {
      _replaceLayout(classId, appliedLayout);
    } else {
      final layouts = List<SeatingLayout>.from(layoutsForClass(classId))
        ..add(appliedLayout);
      _layoutsByClass[classId] = layouts;
      _activeLayoutIdByClass[classId] = appliedLayout.layoutId;
      await _persistLayouts(classId);
      try {
        final repo = RepositoryFactory.instance;
        await repo.saveActiveSeatingLayoutId(classId, appliedLayout.layoutId);
      } catch (e) {
        debugPrint('Failed to save active layout after applying room: $e');
      }
    }

    await _setAssignedRoomSetupId(
      classId,
      roomSetupId,
      notify: false,
    );
    notifyListeners();
    return RoomSetupApplication(
      layout: appliedLayout,
      createdNewLayout: !shouldReplaceActiveLayout,
    );
  }

  Future<void> deleteRoomSetup(String roomSetupId) async {
    _roomSetups.removeWhere((setup) => setup.roomSetupId == roomSetupId);
    try {
      final repo = RepositoryFactory.instance;
      await repo.deleteRoomSetup(roomSetupId);
    } catch (e) {
      debugPrint('Failed to delete room setup: $e');
    }

    final affectedClasses = _assignedRoomSetupIdByClass.entries
        .where((entry) => entry.value == roomSetupId)
        .map((entry) => entry.key)
        .toList();
    for (final classId in affectedClasses) {
      await _setAssignedRoomSetupId(classId, null, notify: false);
    }
    notifyListeners();
  }

  Future<SeatingLayout?> copyRoomLayoutToClass({
    required String sourceClassId,
    required String targetClassId,
    String? sourceLayoutId,
    String? name,
  }) async {
    if (!_layoutsByClass.containsKey(sourceClassId)) {
      await loadLayouts(sourceClassId);
    }
    if (!_layoutsByClass.containsKey(targetClassId)) {
      await loadLayouts(targetClassId);
    }

    final sourceLayouts = layoutsForClass(sourceClassId);
    final sourceLayout = sourceLayoutId == null
        ? activeLayout(sourceClassId)
        : sourceLayouts.cast<SeatingLayout?>().firstWhere(
              (layout) => layout?.layoutId == sourceLayoutId,
              orElse: () => null,
            );
    if (sourceLayout == null) return null;

    final targetLayouts =
        List<SeatingLayout>.from(layoutsForClass(targetClassId));
    final replaceBlankStarter = targetLayouts.length == 1 &&
        _isBlankStarterLayout(targetLayouts.single);
    final now = DateTime.now();
    final copiedLayoutId =
        replaceBlankStarter ? targetLayouts.single.layoutId : _newId('layout');
    final copiedTables = <SeatingTable>[];
    final copiedSeats = <SeatingSeat>[];

    for (int tableIndex = 0;
        tableIndex < sourceLayout.tables.length;
        tableIndex++) {
      final sourceTable = sourceLayout.tables[tableIndex];
      final copiedTableId = '$copiedLayoutId-table-$tableIndex';
      final copiedTable = sourceTable.copyWith(tableId: copiedTableId);
      copiedTables.add(copiedTable);

      final sourceSeats = sourceLayout.seats
          .where((seat) => seat.tableId == sourceTable.tableId)
          .toList();
      for (int seatIndex = 0; seatIndex < sourceSeats.length; seatIndex++) {
        copiedSeats.add(
          sourceSeats[seatIndex].copyWith(
            seatId: '$copiedTableId-seat-$seatIndex',
            tableId: copiedTableId,
            studentId: null,
            statusColor: SeatStatusColor.none,
            locked: false,
            note: '',
            reminder: false,
          ),
        );
      }
    }

    final copiedLayout = SeatingLayout(
      layoutId: copiedLayoutId,
      classId: targetClassId,
      name:
          name == null || name.trim().isEmpty ? sourceLayout.name : name.trim(),
      canvasWidth: sourceLayout.canvasWidth,
      canvasHeight: sourceLayout.canvasHeight,
      tables: copiedTables,
      seats: copiedSeats,
      createdAt: now,
      updatedAt: now,
    );

    _layoutsByClass[targetClassId] =
        replaceBlankStarter ? [copiedLayout] : [...targetLayouts, copiedLayout];
    _activeLayoutIdByClass[targetClassId] = copiedLayout.layoutId;
    await _persistLayouts(targetClassId);
    try {
      final repo = RepositoryFactory.instance;
      await repo.saveActiveSeatingLayoutId(
          targetClassId, copiedLayout.layoutId);
    } catch (e) {
      debugPrint('Failed to save copied room layout: $e');
    }
    notifyListeners();
    return copiedLayout;
  }

  Future<void> applyTemplate(
    String classId,
    SeatingTemplateType template,
    int studentCount,
  ) async {
    final current = activeLayout(classId);
    if (current == null) return;
    final updated = buildTemplateLayout(
      classId: classId,
      name: current.name,
      template: template,
      studentCount: studentCount,
      layoutId: current.layoutId,
    );
    _replaceLayout(classId, updated);
  }

  Future<void> addTable(
    String classId,
    SeatingTableType type, {
    int seatCount = 4,
  }) async {
    final layout = activeLayout(classId);
    if (layout == null) return;
    final table = _constrainTableToCanvas(
      buildTable(
        type: type,
        seatCount: seatCount,
        x: 120 + (layout.tables.length * 40),
        y: 120 + (layout.tables.length * 30),
      ),
      layout,
    );
    final seats = generateSeatsForTable(table);
    final updated = layout.copyWith(
      tables: [...layout.tables, table],
      seats: [...layout.seats, ...seats],
      updatedAt: DateTime.now(),
    );
    _replaceLayout(classId, updated);
  }

  Future<void> removeTable(String classId, String tableId) async {
    final layout = activeLayout(classId);
    if (layout == null) return;
    final updated = layout.copyWith(
      tables: layout.tables.where((t) => t.tableId != tableId).toList(),
      seats: layout.seats.where((s) => s.tableId != tableId).toList(),
      updatedAt: DateTime.now(),
    );
    _replaceLayout(classId, updated);
  }

  Future<void> duplicateTable(String classId, String tableId) async {
    final layout = activeLayout(classId);
    if (layout == null) return;

    final table = layout.tables.cast<SeatingTable?>().firstWhere(
          (entry) => entry?.tableId == tableId,
          orElse: () => null,
        );
    if (table == null) return;

    final copiedTable = _constrainTableToCanvas(
      table.copyWith(
        tableId: _newId('table'),
        x: table.x + math.max(56.0, table.width * 0.55),
        y: table.y + math.max(48.0, table.height * 0.55),
      ),
      layout,
    );
    final copiedSeats = _copySeatsForTable(
      seats:
          layout.seats.where((seat) => seat.tableId == table.tableId).toList(),
      targetTable: copiedTable,
    );

    _replaceLayout(
      classId,
      layout.copyWith(
        tables: [...layout.tables, copiedTable],
        seats: [...layout.seats, ...copiedSeats],
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<void> clearRoom(String classId) async {
    final layout = activeLayout(classId);
    if (layout == null) return;
    _replaceLayout(
      classId,
      layout.copyWith(
        tables: [],
        seats: [],
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<void> updateTable(
    String classId,
    String tableId, {
    SeatingTableType? type,
    int? seatCount,
    String? label,
    double? width,
    double? height,
  }) async {
    final layout = activeLayout(classId);
    if (layout == null) return;
    final tableIndex = layout.tables.indexWhere((t) => t.tableId == tableId);
    if (tableIndex == -1) return;

    final previousTable = layout.tables[tableIndex];
    final updatedType = type ?? previousTable.type;
    final updatedSeatCount = seatCount ?? previousTable.seatCount;
    final typeChanged = updatedType != previousTable.type;

    final rebuilt = _constrainTableToCanvas(
      buildTable(
        type: updatedType,
        seatCount: updatedSeatCount,
        x: previousTable.x,
        y: previousTable.y,
      ).copyWith(
        tableId: previousTable.tableId,
        label: label ??
            (typeChanged ? rebuiltLabel(updatedType) : previousTable.label),
        width: width ??
            (typeChanged
                ? buildDefaultWidth(updatedType)
                : previousTable.width),
        height: height ??
            (typeChanged
                ? buildDefaultHeight(updatedType)
                : previousTable.height),
      ),
      layout,
    );

    final tables = List<SeatingTable>.from(layout.tables)
      ..[tableIndex] = rebuilt;
    final oldSeats = layout.seats.where((s) => s.tableId == tableId).toList();
    final structureChanged =
        typeChanged || updatedSeatCount != previousTable.seatCount;
    final dimensionsChanged = rebuilt.width != previousTable.width ||
        rebuilt.height != previousTable.height;

    final updatedSeatsForTable = structureChanged
        ? _reassignSeatsByProximity(oldSeats, generateSeatsForTable(rebuilt))
        : dimensionsChanged
            ? oldSeats
                .map((seat) => _scaleSeatForTable(
                      seat,
                      previousTable: previousTable,
                      updatedTable: rebuilt,
                    ))
                .toList()
            : oldSeats;

    final seats = [
      for (final s in layout.seats)
        if (s.tableId != tableId) s,
      ...updatedSeatsForTable,
    ];

    final updated = layout.copyWith(
      tables: tables,
      seats: seats,
      updatedAt: DateTime.now(),
    );
    _replaceLayout(classId, updated);
  }

  List<SeatingSeat> _reassignSeatsByProximity(
    List<SeatingSeat> oldSeats,
    List<SeatingSeat> newSeats,
  ) {
    final assigned = List<SeatingSeat>.from(newSeats);
    final used = <String>{};

    double dist(SeatingSeat a, SeatingSeat b) {
      final dx = a.x - b.x;
      final dy = a.y - b.y;
      return (dx * dx) + (dy * dy);
    }

    void assignSeat(SeatingSeat oldSeat) {
      int bestIndex = -1;
      double best = double.infinity;
      for (int i = 0; i < assigned.length; i++) {
        final seat = assigned[i];
        if (used.contains(seat.seatId)) continue;
        final d = dist(oldSeat, seat);
        if (d < best) {
          best = d;
          bestIndex = i;
        }
      }
      if (bestIndex != -1) {
        used.add(assigned[bestIndex].seatId);
        assigned[bestIndex] = assigned[bestIndex].copyWith(
          studentId: oldSeat.studentId,
          statusColor: oldSeat.statusColor,
        );
      }
    }

    // First keep student assignments.
    for (final oldSeat in oldSeats) {
      if (oldSeat.studentId != null && oldSeat.studentId!.isNotEmpty) {
        assignSeat(oldSeat);
      }
    }

    // Then keep any remaining status colors.
    for (final oldSeat in oldSeats) {
      if (oldSeat.studentId == null &&
          oldSeat.statusColor != SeatStatusColor.none) {
        assignSeat(oldSeat);
      }
    }

    return assigned;
  }

  Future<void> moveTable(
      String classId, String tableId, double dx, double dy) async {
    _updateLayout(classId, tableId, (layout) {
      final tables = layout.tables.map((t) {
        if (t.tableId != tableId) return t;
        return _constrainTableToCanvas(
          t.copyWith(x: t.x + dx, y: t.y + dy),
          layout,
        );
      }).toList();
      return layout.copyWith(tables: tables, updatedAt: DateTime.now());
    });
  }

  Future<void> moveSeat(
    String classId,
    String seatId,
    double dx,
    double dy,
  ) async {
    final layout = activeLayout(classId);
    if (layout == null) return;

    final tablesById = {
      for (final table in layout.tables) table.tableId: table,
    };
    final updatedSeats = layout.seats.map((seat) {
      if (seat.seatId != seatId) return seat;
      final table = tablesById[seat.tableId];
      return seat.copyWith(
        x: _clampSeatX(seat.x + dx, table),
        y: _clampSeatY(seat.y + dy, table),
      );
    }).toList();

    _replaceLayout(
      classId,
      layout.copyWith(seats: updatedSeats, updatedAt: DateTime.now()),
    );
  }

  Future<void> duplicateSeat(String classId, String seatId) async {
    final layout = activeLayout(classId);
    if (layout == null) return;

    final seat = layout.seats.cast<SeatingSeat?>().firstWhere(
          (entry) => entry?.seatId == seatId,
          orElse: () => null,
        );
    if (seat == null) return;

    final tableIndex =
        layout.tables.indexWhere((table) => table.tableId == seat.tableId);
    if (tableIndex == -1) return;

    final table = layout.tables[tableIndex];
    if (!_supportsDirectSeatEditing(table.type)) return;

    final tableSeats =
        layout.seats.where((entry) => entry.tableId == table.tableId).toList();
    final duplicatePosition = _findDuplicateSeatPosition(
      source: seat,
      table: table,
      existingSeats: tableSeats,
    );
    final duplicatedSeat = seat.copyWith(
      seatId: _newId('seat'),
      x: duplicatePosition.dx,
      y: duplicatePosition.dy,
      studentId: null,
      statusColor: SeatStatusColor.none,
      locked: false,
      note: '',
      reminder: false,
    );

    final updatedTables = List<SeatingTable>.from(layout.tables)
      ..[tableIndex] = table.copyWith(seatCount: tableSeats.length + 1);

    _replaceLayout(
      classId,
      layout.copyWith(
        tables: updatedTables,
        seats: [...layout.seats, duplicatedSeat],
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<void> removeSeat(String classId, String seatId) async {
    final layout = activeLayout(classId);
    if (layout == null) return;

    final seat = layout.seats.cast<SeatingSeat?>().firstWhere(
          (entry) => entry?.seatId == seatId,
          orElse: () => null,
        );
    if (seat == null) return;

    final tableIndex =
        layout.tables.indexWhere((table) => table.tableId == seat.tableId);
    if (tableIndex == -1) return;

    final table = layout.tables[tableIndex];
    final tableSeats =
        layout.seats.where((entry) => entry.tableId == table.tableId).toList();
    if (!_supportsDirectSeatEditing(table.type) || tableSeats.length <= 1) {
      return;
    }

    final updatedTables = List<SeatingTable>.from(layout.tables)
      ..[tableIndex] = table.copyWith(seatCount: tableSeats.length - 1);

    _replaceLayout(
      classId,
      layout.copyWith(
        tables: updatedTables,
        seats: layout.seats.where((entry) => entry.seatId != seatId).toList(),
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<void> resizeTable(
    String classId,
    String tableId,
    double dx,
    double dy,
  ) async {
    final layout = activeLayout(classId);
    if (layout == null) return;

    final tableIndex = layout.tables.indexWhere((t) => t.tableId == tableId);
    if (tableIndex == -1) return;

    final previousTable = layout.tables[tableIndex];
    final updatedTable = _constrainTableToCanvas(
      previousTable.copyWith(
        width: (previousTable.width + dx)
            .clamp(_minWidthForType(previousTable.type), 600)
            .toDouble(),
        height: (previousTable.height + dy)
            .clamp(_minHeightForType(previousTable.type), 400)
            .toDouble(),
      ),
      layout,
    );

    if (updatedTable.width == previousTable.width &&
        updatedTable.height == previousTable.height) {
      return;
    }

    final updatedTables = List<SeatingTable>.from(layout.tables)
      ..[tableIndex] = updatedTable;
    final updatedSeats = layout.seats.map((seat) {
      if (seat.tableId != tableId) return seat;
      return _scaleSeatForTable(
        seat,
        previousTable: previousTable,
        updatedTable: updatedTable,
      );
    }).toList();

    _replaceLayout(
      classId,
      layout.copyWith(
        tables: updatedTables,
        seats: updatedSeats,
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<void> rotateTable(String classId, String tableId) async {
    final layout = activeLayout(classId);
    if (layout == null) return;

    final tableIndex = layout.tables.indexWhere((t) => t.tableId == tableId);
    if (tableIndex == -1) return;

    final previousTable = layout.tables[tableIndex];
    if (previousTable.width == previousTable.height) return;

    final rotatedTable = _constrainTableToCanvas(
      previousTable.copyWith(
        width: previousTable.height,
        height: previousTable.width,
      ),
      layout,
    );

    final updatedTables = List<SeatingTable>.from(layout.tables)
      ..[tableIndex] = rotatedTable;
    final oldSeats =
        layout.seats.where((seat) => seat.tableId == tableId).toList();
    final regeneratedSeats = generateSeatsForTable(rotatedTable);
    final updatedSeatsForTable = regeneratedSeats.isEmpty
        ? const <SeatingSeat>[]
        : _reassignSeatsByProximity(oldSeats, regeneratedSeats);
    final updatedSeats = [
      for (final seat in layout.seats)
        if (seat.tableId != tableId) seat,
      ...updatedSeatsForTable,
    ];

    _replaceLayout(
      classId,
      layout.copyWith(
        tables: updatedTables,
        seats: updatedSeats,
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<void> assignStudentToSeat(
    String classId,
    String seatId,
    String studentId, {
    String? fromSeatId,
  }) async {
    final layout = activeLayout(classId);
    if (layout == null) return;
    final seats = layout.seats.map((s) {
      if (s.studentId == studentId && s.seatId != seatId) {
        return s.copyWith(studentId: null);
      }
      return s;
    }).toList();

    final targetIndex = seats.indexWhere((s) => s.seatId == seatId);
    if (targetIndex == -1) return;

    if (fromSeatId != null && fromSeatId != seatId) {
      final fromIndex = seats.indexWhere((s) => s.seatId == fromSeatId);
      if (fromIndex != -1) {
        final existing = seats[targetIndex].studentId;
        seats[targetIndex] = seats[targetIndex].copyWith(studentId: studentId);
        seats[fromIndex] = seats[fromIndex].copyWith(studentId: existing);
      } else {
        seats[targetIndex] = seats[targetIndex].copyWith(studentId: studentId);
      }
    } else {
      seats[targetIndex] = seats[targetIndex].copyWith(studentId: studentId);
    }

    final updated = layout.copyWith(seats: seats, updatedAt: DateTime.now());
    _replaceLayout(classId, updated);
  }

  Future<void> clearSeat(String classId, String seatId) async {
    _updateLayout(classId, seatId, (layout) {
      final seats = layout.seats.map((s) {
        if (s.seatId != seatId) return s;
        return s.copyWith(studentId: null);
      }).toList();
      return layout.copyWith(seats: seats, updatedAt: DateTime.now());
    });
  }

  Future<void> clearAssignments(String classId) async {
    final layout = activeLayout(classId);
    if (layout == null) return;
    final cleared =
        layout.seats.map((seat) => seat.copyWith(studentId: null)).toList();
    _replaceLayout(
      classId,
      layout.copyWith(seats: cleared, updatedAt: DateTime.now()),
    );
  }

  Future<bool> assignStudentToTable(
    String classId,
    String tableId,
    String studentId, {
    String? fromSeatId,
  }) async {
    final layout = activeLayout(classId);
    if (layout == null) return false;

    final targetSeat =
        orderedSeatsForLayout(layout).cast<SeatingSeat?>().firstWhere(
              (seat) =>
                  seat?.tableId == tableId &&
                  (seat?.studentId == null || seat!.studentId!.isEmpty),
              orElse: () => null,
            );
    if (targetSeat == null) {
      return false;
    }

    await assignStudentToSeat(
      classId,
      targetSeat.seatId,
      studentId,
      fromSeatId: fromSeatId,
    );
    return true;
  }

  Future<void> updateCanvasSize(
    String classId, {
    required double width,
    required double height,
  }) async {
    final layout = activeLayout(classId);
    if (layout == null) return;
    final normalizedWidth = width.clamp(600, 2400).toDouble();
    final normalizedHeight = height.clamp(400, 1800).toDouble();
    final resizedLayout = layout.copyWith(
      canvasWidth: normalizedWidth,
      canvasHeight: normalizedHeight,
    );
    final constrainedTables = resizedLayout.tables
        .map((table) => _constrainTableToCanvas(table, resizedLayout))
        .toList();
    _replaceLayout(
      classId,
      resizedLayout.copyWith(
        canvasWidth: normalizedWidth,
        canvasHeight: normalizedHeight,
        tables: constrainedTables,
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<void> autoAssignStudents(
      String classId, List<Student> students) async {
    final layout = activeLayout(classId);
    if (layout == null) return;

    final sortedStudents = List<Student>.from(students)
      ..sort((a, b) {
        final aSeat = int.tryParse((a.seatNo ?? '').trim());
        final bSeat = int.tryParse((b.seatNo ?? '').trim());
        if (aSeat != null && bSeat != null) {
          final compare = aSeat.compareTo(bSeat);
          if (compare != 0) return compare;
        } else if (aSeat != null) {
          return -1;
        } else if (bSeat != null) {
          return 1;
        } else {
          final seatCompare = (a.seatNo ?? '')
              .toLowerCase()
              .compareTo((b.seatNo ?? '').toLowerCase());
          if (seatCompare != 0) return seatCompare;
        }

        return a.englishFullName
            .toLowerCase()
            .compareTo(b.englishFullName.toLowerCase());
      });

    final tablesById = {
      for (final table in layout.tables) table.tableId: table
    };
    final orderedSeats = List<SeatingSeat>.from(layout.seats)
      ..sort((a, b) {
        final aTable = tablesById[a.tableId];
        final bTable = tablesById[b.tableId];
        final aY = (aTable?.y ?? 0) + a.y;
        final bY = (bTable?.y ?? 0) + b.y;
        final yCompare = aY.compareTo(bY);
        if (yCompare != 0) return yCompare;
        final aX = (aTable?.x ?? 0) + a.x;
        final bX = (bTable?.x ?? 0) + b.x;
        return aX.compareTo(bX);
      });

    final assignments = <String, String?>{};
    for (int i = 0; i < orderedSeats.length; i++) {
      assignments[orderedSeats[i].seatId] =
          i < sortedStudents.length ? sortedStudents[i].studentId : null;
    }

    final updatedSeats = layout.seats
        .map((seat) => seat.copyWith(studentId: assignments[seat.seatId]))
        .toList();
    _replaceLayout(
      classId,
      layout.copyWith(seats: updatedSeats, updatedAt: DateTime.now()),
    );
  }

  Future<void> shuffleStudentPlacements(
    String classId,
    List<Student> students, {
    math.Random? random,
  }) async {
    final layout = activeLayout(classId);
    if (layout == null || layout.seats.isEmpty) return;

    final rng = random ?? math.Random();
    final orderedSeats = orderedSeatsForLayout(layout);
    final lockedAssignments = <String, String?>{
      for (final seat in orderedSeats.where((seat) => seat.locked))
        seat.seatId: seat.studentId,
    };
    final unlockedSeats = orderedSeats.where((seat) => !seat.locked).toList();
    if (unlockedSeats.isEmpty) return;
    final sourceStudentIds = layout.seats.any(
      (seat) => seat.studentId != null && seat.studentId!.isNotEmpty,
    )
        ? unlockedSeats
            .where(
                (seat) => seat.studentId != null && seat.studentId!.isNotEmpty)
            .map((seat) => seat.studentId!)
            .toList()
        : List<String>.from(students.map((student) => student.studentId));

    if (sourceStudentIds.length < 2) return;

    sourceStudentIds.shuffle(rng);
    if (_listsEqual(
        sourceStudentIds,
        unlockedSeats
            .where(
                (seat) => seat.studentId != null && seat.studentId!.isNotEmpty)
            .map((seat) => seat.studentId!)
            .toList())) {
      sourceStudentIds.add(sourceStudentIds.removeAt(0));
    }

    final assignments = <String, String?>{
      ...lockedAssignments,
    };
    for (int i = 0; i < unlockedSeats.length; i++) {
      assignments[unlockedSeats[i].seatId] =
          i < sourceStudentIds.length ? sourceStudentIds[i] : null;
    }

    final updatedSeats = layout.seats
        .map((seat) => seat.copyWith(studentId: assignments[seat.seatId]))
        .toList();

    _replaceLayout(
      classId,
      layout.copyWith(
        seats: updatedSeats,
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<void> setSeatStatus(
    String classId,
    String seatId,
    SeatStatusColor status,
  ) async {
    _updateLayout(classId, seatId, (layout) {
      final seats = layout.seats.map((s) {
        if (s.seatId != seatId) return s;
        return s.copyWith(statusColor: status);
      }).toList();
      return layout.copyWith(seats: seats, updatedAt: DateTime.now());
    });
  }

  Future<void> setSeatLocked(
    String classId,
    String seatId,
    bool locked,
  ) async {
    _updateLayout(classId, seatId, (layout) {
      final seats = layout.seats.map((s) {
        if (s.seatId != seatId) return s;
        return s.copyWith(locked: locked);
      }).toList();
      return layout.copyWith(seats: seats, updatedAt: DateTime.now());
    });
  }

  Future<void> updateSeatNote(
    String classId,
    String seatId, {
    required String note,
    required bool reminder,
  }) async {
    _updateLayout(classId, seatId, (layout) {
      final seats = layout.seats.map((s) {
        if (s.seatId != seatId) return s;
        return s.copyWith(
          note: note.trim(),
          reminder: reminder,
        );
      }).toList();
      return layout.copyWith(seats: seats, updatedAt: DateTime.now());
    });
  }

  SeatingLayout buildTemplateLayout({
    required String classId,
    required String name,
    required SeatingTemplateType template,
    required int studentCount,
    String? layoutId,
  }) {
    final now = DateTime.now();
    final layout = SeatingLayout(
      layoutId: layoutId ?? _newId('layout'),
      classId: classId,
      name: name,
      canvasWidth: 1200,
      canvasHeight: 800,
      tables: [],
      seats: [],
      createdAt: now,
      updatedAt: now,
    );

    switch (template) {
      case SeatingTemplateType.rows:
        return _buildRowsLayout(layout, studentCount);
      case SeatingTemplateType.groups:
        return _buildGroupLayout(layout, studentCount);
      case SeatingTemplateType.exam:
        return _buildExamLayout(layout, studentCount);
      case SeatingTemplateType.currentClassroom:
        return _buildCurrentClassroomLayout(layout);
    }
  }

  SeatingLayout buildBlankLayout({
    required String classId,
    required String name,
    String? layoutId,
    DateTime? timestamp,
  }) {
    final now = timestamp ?? DateTime.now();
    return SeatingLayout(
      layoutId: layoutId ?? _newId('layout'),
      classId: classId,
      name: name,
      canvasWidth: 1200,
      canvasHeight: 800,
      tables: const [],
      seats: const [],
      createdAt: now,
      updatedAt: now,
    );
  }

  SeatingLayout _buildRowsLayout(SeatingLayout base, int studentCount) {
    final count = studentCount <= 0 ? 20 : studentCount;
    final columns = count <= 12 ? 4 : 5;
    final spacingX = 140.0;
    final spacingY = 120.0;
    final tables = <SeatingTable>[];
    final seats = <SeatingSeat>[];
    for (int i = 0; i < count; i++) {
      final row = i ~/ columns;
      final col = i % columns;
      final table = buildTable(
        type: SeatingTableType.singleDesk,
        seatCount: 1,
        x: 120 + col * spacingX,
        y: 120 + row * spacingY,
      );
      tables.add(table);
      seats.addAll(generateSeatsForTable(table));
    }
    return base.copyWith(
        tables: tables, seats: seats, updatedAt: DateTime.now());
  }

  SeatingLayout _buildGroupLayout(SeatingLayout base, int studentCount) {
    final count = studentCount <= 0 ? 20 : studentCount;
    final tablesNeeded = (count / 4).ceil();
    final columns = tablesNeeded <= 6 ? 3 : 4;
    final spacingX = 200.0;
    final spacingY = 180.0;
    final tables = <SeatingTable>[];
    final seats = <SeatingSeat>[];
    for (int i = 0; i < tablesNeeded; i++) {
      final row = i ~/ columns;
      final col = i % columns;
      final table = buildTable(
        type: SeatingTableType.rectangular,
        seatCount: 4,
        x: 140 + col * spacingX,
        y: 140 + row * spacingY,
      );
      tables.add(table);
      seats.addAll(generateSeatsForTable(table));
    }
    return base.copyWith(
        tables: tables, seats: seats, updatedAt: DateTime.now());
  }

  SeatingLayout _buildExamLayout(SeatingLayout base, int studentCount) {
    final count = studentCount <= 0 ? 20 : studentCount;
    final columns = count <= 10 ? 3 : 4;
    final spacingX = 200.0;
    final spacingY = 160.0;
    final tables = <SeatingTable>[];
    final seats = <SeatingSeat>[];
    for (int i = 0; i < count; i++) {
      final row = i ~/ columns;
      final col = i % columns;
      final table = buildTable(
        type: SeatingTableType.singleDesk,
        seatCount: 1,
        x: 140 + col * spacingX,
        y: 140 + row * spacingY,
      );
      tables.add(table);
      seats.addAll(generateSeatsForTable(table));
    }
    return base.copyWith(
        tables: tables, seats: seats, updatedAt: DateTime.now());
  }

  SeatingTable buildTable({
    required SeatingTableType type,
    required int seatCount,
    required double x,
    required double y,
  }) {
    switch (type) {
      case SeatingTableType.round:
        return SeatingTable(
          tableId: _newId('table'),
          type: type,
          label: 'Round Table',
          x: x,
          y: y,
          seatCount: seatCount,
          width: 110,
          height: 110,
        );
      case SeatingTableType.square:
        return SeatingTable(
          tableId: _newId('table'),
          type: type,
          label: 'Square Table',
          x: x,
          y: y,
          seatCount: seatCount,
          width: 120,
          height: 120,
        );
      case SeatingTableType.singleDesk:
        return SeatingTable(
          tableId: _newId('table'),
          type: type,
          label: 'Desk',
          x: x,
          y: y,
          seatCount: 1,
          width: 70,
          height: 50,
        );
      case SeatingTableType.teacherDesk:
        return SeatingTable(
          tableId: _newId('table'),
          type: type,
          label: 'Teacher Desk',
          x: x,
          y: y,
          seatCount: 0,
          width: 140,
          height: 70,
        );
      case SeatingTableType.rectangular:
        return SeatingTable(
          tableId: _newId('table'),
          type: type,
          label: 'Table',
          x: x,
          y: y,
          seatCount: seatCount,
          width: 140,
          height: 70,
        );
      case SeatingTableType.pairedRect:
        return SeatingTable(
          tableId: _newId('table'),
          type: type,
          label: 'Paired tables',
          x: x,
          y: y,
          seatCount: seatCount,
          width: 240,
          height: 110,
        );
      case SeatingTableType.longDouble:
        return SeatingTable(
          tableId: _newId('table'),
          type: type,
          label: 'Long tables',
          x: x,
          y: y,
          seatCount: seatCount,
          width: 300,
          height: 80,
        );
    }
  }

  double buildDefaultWidth(SeatingTableType type) {
    switch (type) {
      case SeatingTableType.round:
        return 110;
      case SeatingTableType.square:
        return 120;
      case SeatingTableType.singleDesk:
        return 70;
      case SeatingTableType.teacherDesk:
        return 140;
      case SeatingTableType.rectangular:
        return 140;
      case SeatingTableType.pairedRect:
        return 240;
      case SeatingTableType.longDouble:
        return 300;
    }
  }

  double buildDefaultHeight(SeatingTableType type) {
    switch (type) {
      case SeatingTableType.round:
        return 110;
      case SeatingTableType.square:
        return 120;
      case SeatingTableType.singleDesk:
        return 50;
      case SeatingTableType.teacherDesk:
        return 70;
      case SeatingTableType.rectangular:
        return 70;
      case SeatingTableType.pairedRect:
        return 110;
      case SeatingTableType.longDouble:
        return 80;
    }
  }

  String rebuiltLabel(SeatingTableType type) {
    switch (type) {
      case SeatingTableType.round:
        return 'Round Table';
      case SeatingTableType.square:
        return 'Square Table';
      case SeatingTableType.singleDesk:
        return 'Desk';
      case SeatingTableType.teacherDesk:
        return 'Teacher Desk';
      case SeatingTableType.rectangular:
        return 'Table';
      case SeatingTableType.pairedRect:
        return 'Paired tables';
      case SeatingTableType.longDouble:
        return 'Long tables';
    }
  }

  List<SeatingSeat> generateSeatsForTable(SeatingTable table) {
    if (table.seatCount == 0) return [];
    final offsets = <OffsetPair>[];
    switch (table.type) {
      case SeatingTableType.rectangular:
        offsets.addAll(
          _ellipseSeatOffsets(
            table.seatCount,
            width: table.width,
            height: table.height,
          ),
        );
        break;
      case SeatingTableType.round:
        offsets.addAll(
          _ellipseSeatOffsets(
            table.seatCount,
            width: table.width,
            height: table.height,
          ),
        );
        break;
      case SeatingTableType.square:
        offsets.addAll(
          _ellipseSeatOffsets(
            table.seatCount,
            width: table.width,
            height: table.height,
          ),
        );
        break;
      case SeatingTableType.singleDesk:
        offsets.add(OffsetPair(0, (table.height / 2) + 36));
        break;
      case SeatingTableType.teacherDesk:
        break;
      case SeatingTableType.pairedRect:
        offsets.addAll(
          _ellipseSeatOffsets(
            table.seatCount,
            width: table.width,
            height: table.height,
            seatGap: 42,
          ),
        );
        break;
      case SeatingTableType.longDouble:
        offsets.addAll(
          _ellipseSeatOffsets(
            table.seatCount,
            width: table.width,
            height: table.height,
            seatGap: 44,
          ),
        );
        break;
    }
    return [
      for (int i = 0; i < offsets.length; i++)
        SeatingSeat(
          seatId: '${table.tableId}-seat-$i',
          tableId: table.tableId,
          x: offsets[i].dx,
          y: offsets[i].dy,
          studentId: null,
          statusColor: SeatStatusColor.none,
        )
    ];
  }

  List<OffsetPair> _ellipseSeatOffsets(
    int count, {
    required double width,
    required double height,
    double seatGap = 36,
  }) {
    if (count <= 1) {
      return [OffsetPair(0, (height / 2) + seatGap)];
    }
    if (count == 2) {
      final radiusX = (width / 2) + seatGap;
      return [
        OffsetPair(-radiusX, 0),
        OffsetPair(radiusX, 0),
      ];
    }

    final positions = <OffsetPair>[];
    final radiusX = (width / 2) + seatGap;
    final radiusY = (height / 2) + seatGap;
    final step = 360 / count;
    const startAngle = -90.0;
    for (int i = 0; i < count; i++) {
      final angle = (startAngle + (step * i)) * math.pi / 180;
      positions.add(
        OffsetPair(radiusX * math.cos(angle), radiusY * math.sin(angle)),
      );
    }
    return positions;
  }

  SeatingSeat _scaleSeatForTable(
    SeatingSeat seat, {
    required SeatingTable previousTable,
    required SeatingTable updatedTable,
  }) {
    final widthScale = previousTable.width == 0
        ? 1.0
        : updatedTable.width / previousTable.width;
    final heightScale = previousTable.height == 0
        ? 1.0
        : updatedTable.height / previousTable.height;

    return seat.copyWith(
      x: _clampSeatX(seat.x * widthScale, updatedTable),
      y: _clampSeatY(seat.y * heightScale, updatedTable),
    );
  }

  double _clampSeatX(double value, SeatingTable? table) {
    final width = table?.width ?? 120.0;
    const seatHalfSize = 28.0;
    final limit = (width / 2) + _seatBoundaryPadding - seatHalfSize;
    return value.clamp(-limit, limit).toDouble();
  }

  double _clampSeatY(double value, SeatingTable? table) {
    final height = table?.height ?? 60.0;
    const seatHalfSize = 28.0;
    final limit = (height / 2) + _seatBoundaryPadding - seatHalfSize;
    return value.clamp(-limit, limit).toDouble();
  }

  double _minWidthForType(SeatingTableType type) {
    switch (type) {
      case SeatingTableType.singleDesk:
        return 60;
      case SeatingTableType.teacherDesk:
        return 100;
      case SeatingTableType.round:
        return 80;
      case SeatingTableType.rectangular:
        return 90;
      case SeatingTableType.pairedRect:
        return 140;
      case SeatingTableType.longDouble:
        return 180;
      case SeatingTableType.square:
        return 80;
    }
  }

  double _minHeightForType(SeatingTableType type) {
    switch (type) {
      case SeatingTableType.singleDesk:
        return 44;
      case SeatingTableType.teacherDesk:
        return 56;
      case SeatingTableType.round:
        return 80;
      case SeatingTableType.rectangular:
        return 56;
      case SeatingTableType.pairedRect:
        return 70;
      case SeatingTableType.longDouble:
        return 56;
      case SeatingTableType.square:
        return 80;
    }
  }

  SeatingLayout _buildCurrentClassroomLayout(SeatingLayout base) {
    final tables = <SeatingTable>[];
    final seats = <SeatingSeat>[];

    // Front of room is at the top. Use paired tables on top row.
    final leftTop = buildTable(
      type: SeatingTableType.pairedRect,
      seatCount: 6,
      x: 280,
      y: 180,
    );
    final rightTop = buildTable(
      type: SeatingTableType.pairedRect,
      seatCount: 6,
      x: 700,
      y: 180,
    );
    final bottom = buildTable(
      type: SeatingTableType.longDouble,
      seatCount: 8,
      x: 490,
      y: 420,
    );

    tables.addAll([leftTop, rightTop, bottom]);
    seats.addAll(generateSeatsForTable(leftTop));
    seats.addAll(generateSeatsForTable(rightTop));
    seats.addAll(generateSeatsForTable(bottom));

    return base.copyWith(
        tables: tables, seats: seats, updatedAt: DateTime.now());
  }

  void _replaceLayout(String classId, SeatingLayout updated) {
    final layouts = layoutsForClass(classId);
    final index = layouts.indexWhere((l) => l.layoutId == updated.layoutId);
    if (index == -1) return;
    layouts[index] = updated;
    _layoutsByClass[classId] = List<SeatingLayout>.from(layouts);
    unawaited(_persistLayouts(classId));
    notifyListeners();
  }

  SeatingLayout _normalizeLayout(SeatingLayout layout) {
    if (layout.seats.isNotEmpty || layout.tables.isEmpty) return layout;
    final seats = <SeatingSeat>[];
    for (final table in layout.tables) {
      seats.addAll(generateSeatsForTable(table));
    }
    return layout.copyWith(seats: seats, updatedAt: DateTime.now());
  }

  void _updateLayout(
    String classId,
    String id,
    SeatingLayout Function(SeatingLayout layout) update,
  ) {
    final layout = activeLayout(classId);
    if (layout == null) return;
    final updated = update(layout);
    _replaceLayout(classId, updated);
  }

  Future<void> _persistLayouts(String classId) async {
    try {
      final repo = RepositoryFactory.instance;
      await repo.saveSeatingLayouts(classId, layoutsForClass(classId));
    } catch (e) {
      debugPrint('Failed to save seating layouts: $e');
    }
  }

  Future<void> _persistRoomSetups() async {
    try {
      final repo = RepositoryFactory.instance;
      await repo.saveRoomSetups(_roomSetups);
    } catch (e) {
      debugPrint('Failed to save room setups: $e');
    }
  }

  Future<List<SeatingLayout>?> _syncClassLayoutsFromRoomSetup(
    String classId,
    RoomSetup roomSetup, {
    bool notify = true,
  }) async {
    final layouts = layoutsForClass(classId);
    if (layouts.isEmpty) return null;

    final now = DateTime.now();
    final updatedLayouts = layouts
        .map(
          (layout) => _mergeLayoutWithRoomSetup(
            layout,
            roomSetup,
            now,
          ),
        )
        .toList();
    _layoutsByClass[classId] = updatedLayouts;
    await _persistLayouts(classId);
    if (notify) {
      notifyListeners();
    }
    return updatedLayouts;
  }

  Future<void> _setAssignedRoomSetupId(
    String classId,
    String? roomSetupId, {
    bool notify = true,
  }) async {
    _assignedRoomSetupIdByClass[classId] = roomSetupId;
    try {
      final repo = RepositoryFactory.instance;
      await repo.saveAssignedRoomSetupId(classId, roomSetupId);
    } catch (e) {
      debugPrint('Failed to save assigned room setup: $e');
    }
    if (notify) {
      notifyListeners();
    }
  }

  String _newId(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}-${_idSequence++}';

  bool _isBlankStarterLayout(SeatingLayout layout) {
    return layout.tables.isEmpty &&
        layout.seats.isEmpty &&
        layout.name.trim().toLowerCase() == 'blank canvas';
  }

  RoomSetup _normalizeRoomSetup(RoomSetup roomSetup) {
    if (roomSetup.seats.isNotEmpty || roomSetup.tables.isEmpty) {
      return roomSetup;
    }
    final generatedSeats = <SeatingSeat>[];
    for (final table in roomSetup.tables) {
      generatedSeats.addAll(generateSeatsForTable(table));
    }
    return roomSetup.copyWith(
      seats: generatedSeats,
      updatedAt: DateTime.now(),
    );
  }

  SeatingLayout _mergeLayoutWithRoomSetup(
    SeatingLayout layout,
    RoomSetup roomSetup,
    DateTime timestamp,
  ) {
    final seatsById = {
      for (final seat in layout.seats) seat.seatId: seat,
    };

    return SeatingLayout(
      layoutId: layout.layoutId,
      classId: layout.classId,
      name: _isBlankStarterLayout(layout) ? roomSetup.name : layout.name,
      canvasWidth: roomSetup.canvasWidth,
      canvasHeight: roomSetup.canvasHeight,
      tables: [
        for (final table in roomSetup.tables) table.copyWith(),
      ],
      seats: [
        for (final seat in roomSetup.seats)
          _mergeSeatWithClassState(seat, seatsById[seat.seatId]),
      ],
      createdAt: layout.createdAt,
      updatedAt: timestamp,
    );
  }

  SeatingSeat _mergeSeatWithClassState(
    SeatingSeat roomSeat,
    SeatingSeat? existingSeat,
  ) {
    return roomSeat.copyWith(
      studentId: existingSeat?.studentId,
      statusColor: existingSeat?.statusColor ?? SeatStatusColor.none,
      locked: existingSeat?.locked ?? false,
      note: existingSeat?.note ?? '',
      reminder: existingSeat?.reminder ?? false,
    );
  }

  bool _canReplaceLayoutWithRoomSetup(SeatingLayout layout) {
    if (_isBlankStarterLayout(layout)) return true;
    return !layout.seats.any((seat) {
      final hasStudent = seat.studentId != null && seat.studentId!.isNotEmpty;
      return hasStudent ||
          seat.statusColor != SeatStatusColor.none ||
          seat.locked ||
          seat.note.trim().isNotEmpty ||
          seat.reminder;
    });
  }

  String _layoutNameForAppliedRoomSetup({
    required RoomSetup roomSetup,
    required SeatingLayout currentLayout,
    required bool replacingActiveLayout,
  }) {
    if (!replacingActiveLayout || _isBlankStarterLayout(currentLayout)) {
      return roomSetup.name;
    }
    return currentLayout.name;
  }

  List<SeatingSeat> orderedSeatsForLayout(SeatingLayout layout) {
    final tablesById = {
      for (final table in layout.tables) table.tableId: table,
    };
    final orderedSeats = List<SeatingSeat>.from(layout.seats)
      ..sort((a, b) {
        final aTable = tablesById[a.tableId];
        final bTable = tablesById[b.tableId];
        final aY = (aTable?.y ?? 0) + a.y;
        final bY = (bTable?.y ?? 0) + b.y;
        final yCompare = aY.compareTo(bY);
        if (yCompare != 0) return yCompare;
        final aX = (aTable?.x ?? 0) + a.x;
        final bX = (bTable?.x ?? 0) + b.x;
        return aX.compareTo(bX);
      });
    return orderedSeats;
  }

  List<SeatingSeat> _copySeatsForTable({
    required List<SeatingSeat> seats,
    required SeatingTable targetTable,
  }) {
    return [
      for (int index = 0; index < seats.length; index++)
        seats[index].copyWith(
          seatId: '${targetTable.tableId}-seat-$index',
          tableId: targetTable.tableId,
          x: _clampSeatX(seats[index].x, targetTable),
          y: _clampSeatY(seats[index].y, targetTable),
          studentId: null,
          locked: false,
          note: '',
          reminder: false,
        ),
    ];
  }

  OffsetPair _findDuplicateSeatPosition({
    required SeatingSeat source,
    required SeatingTable table,
    required List<SeatingSeat> existingSeats,
  }) {
    const offsets = [
      OffsetPair(72, 0),
      OffsetPair(0, 72),
      OffsetPair(-72, 0),
      OffsetPair(0, -72),
      OffsetPair(56, 56),
      OffsetPair(-56, 56),
    ];

    for (final offset in offsets) {
      final candidateX = _clampSeatX(source.x + offset.dx, table);
      final candidateY = _clampSeatY(source.y + offset.dy, table);
      final overlapsExisting = existingSeats.any((seat) {
        final dx = seat.x - candidateX;
        final dy = seat.y - candidateY;
        return (dx * dx) + (dy * dy) < 900;
      });
      if (!overlapsExisting) {
        return OffsetPair(candidateX, candidateY);
      }
    }

    return OffsetPair(
      _clampSeatX(source.x + 84, table),
      _clampSeatY(source.y + 36, table),
    );
  }

  bool _supportsDirectSeatEditing(SeatingTableType type) {
    switch (type) {
      case SeatingTableType.rectangular:
      case SeatingTableType.round:
      case SeatingTableType.pairedRect:
      case SeatingTableType.longDouble:
      case SeatingTableType.square:
        return true;
      case SeatingTableType.singleDesk:
      case SeatingTableType.teacherDesk:
        return false;
    }
  }

  bool _listsEqual(List<String> left, List<String> right) {
    if (left.length != right.length) return false;
    for (int i = 0; i < left.length; i++) {
      if (left[i] != right[i]) return false;
    }
    return true;
  }

  SeatingTable _constrainTableToCanvas(
    SeatingTable table,
    SeatingLayout layout,
  ) {
    final minWidth = _minWidthForType(table.type);
    final minHeight = _minHeightForType(table.type);
    final maxWidth = math.max(
      minWidth,
      layout.canvasWidth - (_tableBoundaryPadding * 2),
    );
    final maxHeight = math.max(
      minHeight,
      layout.canvasHeight - (_tableBoundaryPadding * 2),
    );
    final normalizedWidth = table.width.clamp(minWidth, maxWidth).toDouble();
    final normalizedHeight =
        table.height.clamp(minHeight, maxHeight).toDouble();

    final minX = (normalizedWidth / 2) + _tableBoundaryPadding;
    final maxX =
        layout.canvasWidth - (normalizedWidth / 2) - _tableBoundaryPadding;
    final minY = (normalizedHeight / 2) + _tableBoundaryPadding;
    final maxY =
        layout.canvasHeight - (normalizedHeight / 2) - _tableBoundaryPadding;

    final normalizedX = maxX < minX
        ? layout.canvasWidth / 2
        : table.x.clamp(minX, maxX).toDouble();
    final normalizedY = maxY < minY
        ? layout.canvasHeight / 2
        : table.y.clamp(minY, maxY).toDouble();

    return table.copyWith(
      width: normalizedWidth,
      height: normalizedHeight,
      x: normalizedX,
      y: normalizedY,
    );
  }
}

class OffsetPair {
  final double dx;
  final double dy;
  const OffsetPair(this.dx, this.dy);
}

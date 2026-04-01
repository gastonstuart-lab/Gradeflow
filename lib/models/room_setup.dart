import 'package:gradeflow/models/seating_layout.dart';

class RoomSetup {
  final String roomSetupId;
  final String name;
  final double canvasWidth;
  final double canvasHeight;
  final List<SeatingTable> tables;
  final List<SeatingSeat> seats;
  final DateTime createdAt;
  final DateTime updatedAt;

  RoomSetup({
    required this.roomSetupId,
    required this.name,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.tables,
    required this.seats,
    required this.createdAt,
    required this.updatedAt,
  });

  RoomSetup copyWith({
    String? roomSetupId,
    String? name,
    double? canvasWidth,
    double? canvasHeight,
    List<SeatingTable>? tables,
    List<SeatingSeat>? seats,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RoomSetup(
      roomSetupId: roomSetupId ?? this.roomSetupId,
      name: name ?? this.name,
      canvasWidth: canvasWidth ?? this.canvasWidth,
      canvasHeight: canvasHeight ?? this.canvasHeight,
      tables: tables ?? this.tables,
      seats: seats ?? this.seats,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'roomSetupId': roomSetupId,
        'name': name,
        'canvasWidth': canvasWidth,
        'canvasHeight': canvasHeight,
        'tables': tables.map((table) => table.toJson()).toList(),
        'seats': seats.map((seat) => seat.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory RoomSetup.fromJson(Map<String, dynamic> json) => RoomSetup(
        roomSetupId: json['roomSetupId'] as String,
        name: json['name'] as String? ?? 'Room setup',
        canvasWidth: (json['canvasWidth'] as num?)?.toDouble() ?? 1200,
        canvasHeight: (json['canvasHeight'] as num?)?.toDouble() ?? 800,
        tables: (json['tables'] as List? ?? [])
            .map(
                (entry) => SeatingTable.fromJson(entry as Map<String, dynamic>))
            .toList(),
        seats: (json['seats'] as List? ?? [])
            .map((entry) => SeatingSeat.fromJson(entry as Map<String, dynamic>))
            .toList(),
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
            DateTime.now(),
        updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
            DateTime.now(),
      );

  factory RoomSetup.fromLayout(
    SeatingLayout layout, {
    required String roomSetupId,
    String? name,
    DateTime? timestamp,
  }) {
    final now = timestamp ?? DateTime.now();
    return RoomSetup(
      roomSetupId: roomSetupId,
      name: (name == null || name.trim().isEmpty) ? layout.name : name.trim(),
      canvasWidth: layout.canvasWidth,
      canvasHeight: layout.canvasHeight,
      tables: [
        for (final table in layout.tables) table.copyWith(),
      ],
      seats: [
        for (final seat in layout.seats)
          seat.copyWith(
            studentId: null,
            statusColor: SeatStatusColor.none,
            locked: false,
            note: '',
            reminder: false,
          ),
      ],
      createdAt: now,
      updatedAt: now,
    );
  }

  SeatingLayout toLayout({
    required String classId,
    required String layoutId,
    required String name,
    DateTime? timestamp,
  }) {
    final now = timestamp ?? DateTime.now();
    return SeatingLayout(
      layoutId: layoutId,
      classId: classId,
      name: name,
      canvasWidth: canvasWidth,
      canvasHeight: canvasHeight,
      tables: [
        for (final table in tables) table.copyWith(),
      ],
      seats: [
        for (final seat in seats)
          seat.copyWith(
            studentId: null,
            statusColor: SeatStatusColor.none,
            locked: false,
            note: '',
            reminder: false,
          ),
      ],
      createdAt: now,
      updatedAt: now,
    );
  }
}

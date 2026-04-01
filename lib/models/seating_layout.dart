const Object _unsetStudentId = Object();

class SeatingLayout {
  final String layoutId;
  final String classId;
  final String name;
  final double canvasWidth;
  final double canvasHeight;
  final List<SeatingTable> tables;
  final List<SeatingSeat> seats;
  final DateTime createdAt;
  final DateTime updatedAt;

  SeatingLayout({
    required this.layoutId,
    required this.classId,
    required this.name,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.tables,
    required this.seats,
    required this.createdAt,
    required this.updatedAt,
  });

  SeatingLayout copyWith({
    String? layoutId,
    String? classId,
    String? name,
    double? canvasWidth,
    double? canvasHeight,
    List<SeatingTable>? tables,
    List<SeatingSeat>? seats,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      SeatingLayout(
        layoutId: layoutId ?? this.layoutId,
        classId: classId ?? this.classId,
        name: name ?? this.name,
        canvasWidth: canvasWidth ?? this.canvasWidth,
        canvasHeight: canvasHeight ?? this.canvasHeight,
        tables: tables ?? this.tables,
        seats: seats ?? this.seats,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toJson() => {
        'layoutId': layoutId,
        'classId': classId,
        'name': name,
        'canvasWidth': canvasWidth,
        'canvasHeight': canvasHeight,
        'tables': tables.map((t) => t.toJson()).toList(),
        'seats': seats.map((s) => s.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory SeatingLayout.fromJson(Map<String, dynamic> json) => SeatingLayout(
        layoutId: json['layoutId'] as String,
        classId: json['classId'] as String,
        name: json['name'] as String? ?? 'Layout',
        canvasWidth: (json['canvasWidth'] as num?)?.toDouble() ?? 1200,
        canvasHeight: (json['canvasHeight'] as num?)?.toDouble() ?? 800,
        tables: (json['tables'] as List? ?? [])
            .map((e) => SeatingTable.fromJson(e as Map<String, dynamic>))
            .toList(),
        seats: (json['seats'] as List? ?? [])
            .map((e) => SeatingSeat.fromJson(e as Map<String, dynamic>))
            .toList(),
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
            DateTime.now(),
        updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
            DateTime.now(),
      );
}

enum SeatingTableType {
  rectangular,
  round,
  singleDesk,
  teacherDesk,
  pairedRect,
  longDouble,
  square,
}

class SeatingTable {
  final String tableId;
  final SeatingTableType type;
  final String label;
  final double x;
  final double y;
  final int seatCount;
  final double width;
  final double height;

  SeatingTable({
    required this.tableId,
    required this.type,
    required this.label,
    required this.x,
    required this.y,
    required this.seatCount,
    required this.width,
    required this.height,
  });

  SeatingTable copyWith({
    String? tableId,
    SeatingTableType? type,
    String? label,
    double? x,
    double? y,
    int? seatCount,
    double? width,
    double? height,
  }) =>
      SeatingTable(
        tableId: tableId ?? this.tableId,
        type: type ?? this.type,
        label: label ?? this.label,
        x: x ?? this.x,
        y: y ?? this.y,
        seatCount: seatCount ?? this.seatCount,
        width: width ?? this.width,
        height: height ?? this.height,
      );

  Map<String, dynamic> toJson() => {
        'tableId': tableId,
        'type': type.name,
        'label': label,
        'x': x,
        'y': y,
        'seatCount': seatCount,
        'width': width,
        'height': height,
      };

  factory SeatingTable.fromJson(Map<String, dynamic> json) => SeatingTable(
        tableId: json['tableId'] as String,
        type: SeatingTableType.values.firstWhere(
          (t) => t.name == json['type'],
          orElse: () => SeatingTableType.rectangular,
        ),
        label: json['label'] as String? ?? '',
        x: (json['x'] as num?)?.toDouble() ?? 0,
        y: (json['y'] as num?)?.toDouble() ?? 0,
        seatCount: (json['seatCount'] as num?)?.toInt() ?? 4,
        width: (json['width'] as num?)?.toDouble() ?? 120,
        height: (json['height'] as num?)?.toDouble() ?? 60,
      );
}

enum SeatStatusColor {
  none,
  green,
  yellow,
  red,
  blue,
}

class SeatingSeat {
  final String seatId;
  final String tableId;
  final double x;
  final double y;
  final String? studentId;
  final SeatStatusColor statusColor;
  final bool locked;
  final String note;
  final bool reminder;

  SeatingSeat({
    required this.seatId,
    required this.tableId,
    required this.x,
    required this.y,
    required this.studentId,
    required this.statusColor,
    this.locked = false,
    this.note = '',
    this.reminder = false,
  });

  SeatingSeat copyWith({
    String? seatId,
    String? tableId,
    double? x,
    double? y,
    Object? studentId = _unsetStudentId,
    SeatStatusColor? statusColor,
    bool? locked,
    String? note,
    bool? reminder,
  }) =>
      SeatingSeat(
        seatId: seatId ?? this.seatId,
        tableId: tableId ?? this.tableId,
        x: x ?? this.x,
        y: y ?? this.y,
        studentId: identical(studentId, _unsetStudentId)
            ? this.studentId
            : studentId as String?,
        statusColor: statusColor ?? this.statusColor,
        locked: locked ?? this.locked,
        note: note ?? this.note,
        reminder: reminder ?? this.reminder,
      );

  Map<String, dynamic> toJson() => {
        'seatId': seatId,
        'tableId': tableId,
        'x': x,
        'y': y,
        'studentId': studentId,
        'statusColor': statusColor.name,
        'locked': locked,
        'note': note,
        'reminder': reminder,
      };

  factory SeatingSeat.fromJson(Map<String, dynamic> json) => SeatingSeat(
        seatId: json['seatId'] as String,
        tableId: json['tableId'] as String,
        x: (json['x'] as num?)?.toDouble() ?? 0,
        y: (json['y'] as num?)?.toDouble() ?? 0,
        studentId: json['studentId'] as String?,
        statusColor: SeatStatusColor.values.firstWhere(
          (c) => c.name == json['statusColor'],
          orElse: () => SeatStatusColor.none,
        ),
        locked: json['locked'] as bool? ?? false,
        note: json['note'] as String? ?? '',
        reminder: json['reminder'] as bool? ?? false,
      );
}

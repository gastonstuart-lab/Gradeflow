class ClassScheduleItem {
  final DateTime? date;
  final int? week;
  final String title;
  final Map<String, String> details;
  final DateTime? startTime;  // e.g., 2026-01-16 13:55
  final DateTime? endTime;    // e.g., 2026-01-16 14:45
  final String? room;         // e.g., "Classroom 1"
  final String? dayOfWeek;    // e.g., "Monday" for repeating schedules
  final int? startTimeMinutes; // Minutes since midnight for weekly schedules
  final int? endTimeMinutes;   // Minutes since midnight for weekly schedules

  const ClassScheduleItem({
    required this.title,
    this.date,
    this.week,
    this.details = const {},
    this.startTime,
    this.endTime,
    this.room,
    this.dayOfWeek,
    this.startTimeMinutes,
    this.endTimeMinutes,
  });

  Map<String, dynamic> toJson() {
    return {
      'date': date?.toIso8601String(),
      'startTime': startTime?.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'week': week,
      'title': title,
      'details': details,
      'room': room,
      'dayOfWeek': dayOfWeek,
      'startTimeMinutes': startTimeMinutes,
      'endTimeMinutes': endTimeMinutes,
    };
  }

  static ClassScheduleItem fromJson(Map<String, dynamic> json) {
    final dateStr = (json['date'] as String?)?.trim();
    final startTimeStr = (json['startTime'] as String?)?.trim();
    final endTimeStr = (json['endTime'] as String?)?.trim();
    final detailsRaw = json['details'];
    final details = <String, String>{};
    if (detailsRaw is Map) {
      for (final entry in detailsRaw.entries) {
        final k = entry.key?.toString();
        final v = entry.value?.toString();
        if (k == null || v == null) continue;
        final kk = k.trim();
        final vv = v.trim();
        if (kk.isEmpty || vv.isEmpty) continue;
        details[kk] = vv;
      }
    }

    return ClassScheduleItem(
      title: (json['title'] ?? '').toString(),
      week: (json['week'] is int)
          ? (json['week'] as int)
          : int.tryParse((json['week'] ?? '').toString().trim()),
      date: dateStr == null || dateStr.isEmpty ? null : DateTime.tryParse(dateStr),
      startTime: startTimeStr == null || startTimeStr.isEmpty ? null : DateTime.tryParse(startTimeStr),
      endTime: endTimeStr == null || endTimeStr.isEmpty ? null : DateTime.tryParse(endTimeStr),
      room: json['room'] as String?,
      dayOfWeek: json['dayOfWeek'] as String?,
      startTimeMinutes: json['startTimeMinutes'] as int?,
      endTimeMinutes: json['endTimeMinutes'] as int?,
      details: details,
    );
  }
}

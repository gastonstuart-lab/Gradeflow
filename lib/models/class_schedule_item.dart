class ClassScheduleItem {
  final DateTime? date;
  final int? week;
  final String title;
  final Map<String, String> details;

  const ClassScheduleItem({
    required this.title,
    this.date,
    this.week,
    this.details = const {},
  });

  Map<String, dynamic> toJson() {
    return {
      'date': date?.toIso8601String(),
      'week': week,
      'title': title,
      'details': details,
    };
  }

  static ClassScheduleItem fromJson(Map<String, dynamic> json) {
    final dateStr = (json['date'] as String?)?.trim();
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
      details: details,
    );
  }
}

class PilotFeedbackEntry {
  final String entryId;
  final String category;
  final String area;
  final String summary;
  final String details;
  final String route;
  final DateTime createdAt;

  PilotFeedbackEntry({
    required this.entryId,
    required this.category,
    required this.area,
    required this.summary,
    required this.details,
    required this.route,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'entryId': entryId,
        'category': category,
        'area': area,
        'summary': summary,
        'details': details,
        'route': route,
        'createdAt': createdAt.toIso8601String(),
      };

  factory PilotFeedbackEntry.fromJson(Map<String, dynamic> json) {
    return PilotFeedbackEntry(
      entryId: json['entryId'] as String? ?? '',
      category: json['category'] as String? ?? 'General',
      area: json['area'] as String? ?? 'General',
      summary: json['summary'] as String? ?? '',
      details: json['details'] as String? ?? '',
      route: json['route'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

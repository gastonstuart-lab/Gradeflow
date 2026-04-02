class ClassNoteItem {
  final String id;
  final String text;
  final DateTime createdAt;
  final DateTime? remindAt;
  final bool isDone;

  const ClassNoteItem({
    required this.id,
    required this.text,
    required this.createdAt,
    this.remindAt,
    this.isDone = false,
  });

  bool get hasReminderDate => remindAt != null;

  ClassNoteItem copyWith({
    String? id,
    String? text,
    DateTime? createdAt,
    DateTime? remindAt,
    bool clearReminderDate = false,
    bool? isDone,
  }) {
    return ClassNoteItem(
      id: id ?? this.id,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
      remindAt: clearReminderDate ? null : (remindAt ?? this.remindAt),
      isDone: isDone ?? this.isDone,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'createdAt': createdAt.toIso8601String(),
      'remindAt': remindAt?.toIso8601String(),
      'isDone': isDone,
    };
  }

  static ClassNoteItem fromJson(Map<String, dynamic> json) {
    final createdAtRaw = (json['createdAt'] ?? '').toString().trim();
    final remindAtRaw = (json['remindAt'] ?? '').toString().trim();

    return ClassNoteItem(
      id: (json['id'] ?? '').toString(),
      text: (json['text'] ?? '').toString(),
      createdAt: DateTime.tryParse(createdAtRaw) ?? DateTime.now(),
      remindAt: remindAtRaw.isEmpty ? null : DateTime.tryParse(remindAtRaw),
      isDone: json['isDone'] as bool? ?? false,
    );
  }
}

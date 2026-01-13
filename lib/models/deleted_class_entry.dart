import 'package:gradeflow/models/class.dart';

class DeletedClassEntry {
  final Class classItem;
  final DateTime deletedAt;

  const DeletedClassEntry({required this.classItem, required this.deletedAt});

  Map<String, dynamic> toJson() => {
        'class': classItem.toJson(),
        'deletedAt': deletedAt.toIso8601String(),
      };

  factory DeletedClassEntry.fromJson(Map<String, dynamic> json) => DeletedClassEntry(
        classItem: Class.fromJson((json['class'] as Map).cast<String, dynamic>()),
        deletedAt: DateTime.parse(json['deletedAt'] as String),
      );
}

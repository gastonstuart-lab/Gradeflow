class GradeItem {
  final String gradeItemId;
  final String classId;
  final String categoryId;
  final String name;
  final double maxScore;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  GradeItem({
    required this.gradeItemId,
    required this.classId,
    required this.categoryId,
    required this.name,
    this.maxScore = 100.0,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'gradeItemId': gradeItemId,
    'classId': classId,
    'categoryId': categoryId,
    'name': name,
    'maxScore': maxScore,
    'isActive': isActive,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory GradeItem.fromJson(Map<String, dynamic> json) => GradeItem(
    gradeItemId: json['gradeItemId'] as String,
    classId: json['classId'] as String,
    categoryId: json['categoryId'] as String,
    name: json['name'] as String,
    maxScore: (json['maxScore'] as num?)?.toDouble() ?? 100.0,
    isActive: json['isActive'] as bool,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );

  GradeItem copyWith({
    String? gradeItemId,
    String? classId,
    String? categoryId,
    String? name,
    double? maxScore,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => GradeItem(
    gradeItemId: gradeItemId ?? this.gradeItemId,
    classId: classId ?? this.classId,
    categoryId: categoryId ?? this.categoryId,
    name: name ?? this.name,
    maxScore: maxScore ?? this.maxScore,
    isActive: isActive ?? this.isActive,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}

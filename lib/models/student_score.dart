class StudentScore {
  final String studentId;
  final String gradeItemId;
  final double? score;
  final DateTime createdAt;
  final DateTime updatedAt;

  StudentScore({
    required this.studentId,
    required this.gradeItemId,
    this.score,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'studentId': studentId,
    'gradeItemId': gradeItemId,
    'score': score,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory StudentScore.fromJson(Map<String, dynamic> json) => StudentScore(
    studentId: json['studentId'] as String,
    gradeItemId: json['gradeItemId'] as String,
    score: (json['score'] as num?)?.toDouble(),
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );

  StudentScore copyWith({
    String? studentId,
    String? gradeItemId,
    double? score,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => StudentScore(
    studentId: studentId ?? this.studentId,
    gradeItemId: gradeItemId ?? this.gradeItemId,
    score: score ?? this.score,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}

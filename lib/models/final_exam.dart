class FinalExam {
  final String studentId;
  final double? examScore;
  final DateTime createdAt;
  final DateTime updatedAt;

  FinalExam({
    required this.studentId,
    this.examScore,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'studentId': studentId,
    'examScore': examScore,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory FinalExam.fromJson(Map<String, dynamic> json) => FinalExam(
    studentId: json['studentId'] as String,
    examScore: (json['examScore'] as num?)?.toDouble(),
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );

  FinalExam copyWith({
    String? studentId,
    double? examScore,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => FinalExam(
    studentId: studentId ?? this.studentId,
    examScore: examScore ?? this.examScore,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}

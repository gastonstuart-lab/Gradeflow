class ChangeHistory {
  final String changeId;
  final String studentId;
  final String gradeItemId;
  final String? classId;
  final double? oldScore;
  final double? newScore;
  final String teacherId;
  final DateTime timestamp;

  ChangeHistory({
    required this.changeId,
    required this.studentId,
    required this.gradeItemId,
    this.classId,
    this.oldScore,
    this.newScore,
    required this.teacherId,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'changeId': changeId,
    'studentId': studentId,
    'gradeItemId': gradeItemId,
    'classId': classId,
    'oldScore': oldScore,
    'newScore': newScore,
    'teacherId': teacherId,
    'timestamp': timestamp.toIso8601String(),
  };

  factory ChangeHistory.fromJson(Map<String, dynamic> json) => ChangeHistory(
    changeId: json['changeId'] as String,
    studentId: json['studentId'] as String,
    gradeItemId: json['gradeItemId'] as String,
    classId: json['classId'] as String?,
    oldScore: (json['oldScore'] as num?)?.toDouble(),
    newScore: (json['newScore'] as num?)?.toDouble(),
    teacherId: json['teacherId'] as String,
    timestamp: DateTime.parse(json['timestamp'] as String),
  );
}

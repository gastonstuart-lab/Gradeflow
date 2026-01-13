import 'package:gradeflow/models/student.dart';
import 'package:gradeflow/models/student_score.dart';
import 'package:gradeflow/models/final_exam.dart';

class DeletedStudentEntry {
  final Student student;
  final List<StudentScore> scores;
  final FinalExam? exam;
  final DateTime deletedAt;
  final String? reason;

  DeletedStudentEntry({required this.student, required this.scores, required this.exam, required this.deletedAt, this.reason});

  Map<String, dynamic> toJson() => {
        'student': student.toJson(),
        'scores': scores.map((s) => s.toJson()).toList(),
        'exam': exam?.toJson(),
        'deletedAt': deletedAt.toIso8601String(),
        'reason': reason,
      };

  factory DeletedStudentEntry.fromJson(Map<String, dynamic> json) => DeletedStudentEntry(
        student: Student.fromJson(json['student'] as Map<String, dynamic>),
        scores: ((json['scores'] as List?) ?? const [])
            .map((m) => StudentScore.fromJson(m as Map<String, dynamic>))
            .toList(),
        exam: json['exam'] == null ? null : FinalExam.fromJson(json['exam'] as Map<String, dynamic>),
        deletedAt: DateTime.parse(json['deletedAt'] as String),
        reason: json['reason'] as String?,
      );
}

import 'class.dart';
import 'final_exam.dart';
import 'grade_item.dart';
import 'grading_category.dart';
import 'student.dart';
import 'student_score.dart';

enum AssessmentKind { quiz, classwork, homework, participation }

/// A value snapshot. Existing model values contain only immutable scalar fields;
/// collections are copied so neither a caller nor a service can mutate history.
class GradebookDataset {
  final String ownerId;
  final String classId;
  final String className;
  final String subject;
  final String? groupNumber;
  final String schoolYear;
  final String term;
  /// Explicit native policy input; absent in legacy-v1 snapshots.
  final double? courseworkWeightPercent;
  final List<Student> students;
  final List<GradingCategory> categories;
  final List<GradeItem> assessments;
  final List<StudentScore> scores;
  final List<FinalExam> exams;

  GradebookDataset({
    required this.ownerId,
    required this.classId,
    required this.className,
    required this.subject,
    this.groupNumber,
    required this.schoolYear,
    required this.term,
    this.courseworkWeightPercent,
    required List<Student> students,
    required List<GradingCategory> categories,
    required List<GradeItem> assessments,
    required List<StudentScore> scores,
    required List<FinalExam> exams,
  })  : students = List.unmodifiable(students),
        categories = List.unmodifiable(categories),
        assessments = List.unmodifiable(assessments),
        scores = List.unmodifiable(scores),
        exams = List.unmodifiable(exams) {
    final split = courseworkWeightPercent;
    if (split != null && (!split.isFinite || split < 0 || split > 100)) {
      throw ArgumentError('Invalid saved coursework percentage');
    }
    if (ownerId.isEmpty || classId.isEmpty) {
      throw ArgumentError('Owner and class are required');
    }
    if (students.any((s) => s.classId != classId) ||
        categories.any((c) => c.classId != classId) ||
        assessments.any((a) => a.classId != classId)) {
      throw ArgumentError('Dataset crosses class boundaries');
    }
    _unique(students.map((s) => s.studentId));
    _unique(categories.map((c) => c.categoryId));
    _unique(assessments.map((a) => a.gradeItemId));
    _unique(exams.map((e) => e.studentId));
    final identities = <(String, String)>{};
    final categoryIds = categories.map((c) => c.categoryId).toSet();
    final itemIds = assessments.map((a) => a.gradeItemId).toSet();
    if (assessments.any((a) => !categoryIds.contains(a.categoryId))) {
      throw ArgumentError('Assessment references an unknown category');
    }
    for (final score in scores) {
      if (!itemIds.contains(score.gradeItemId) ||
          !identities.add((score.studentId, score.gradeItemId))) {
        throw ArgumentError('Unknown assessment or duplicate score');
      }
    }
    // Scores/exams for former roster members are retained, not discarded.
  }

  factory GradebookDataset.fromLegacy({
    required Class classRecord,
    double? courseworkWeightPercent,
    required List<Student> students,
    required List<GradingCategory> categories,
    required List<GradeItem> assessments,
    required List<StudentScore> scores,
    required List<FinalExam> exams,
  }) =>
      GradebookDataset(
        ownerId: classRecord.teacherId,
        classId: classRecord.classId,
        className: classRecord.className,
        subject: classRecord.subject,
        groupNumber: classRecord.groupNumber,
        schoolYear: classRecord.schoolYear,
        term: classRecord.term,
        courseworkWeightPercent: courseworkWeightPercent,
        students: students,
        categories: categories,
        assessments: assessments,
        scores: scores,
        exams: exams,
      );

  GradebookDataset withAssessments(List<GradeItem> values) => GradebookDataset(
        ownerId: ownerId,
        classId: classId,
        className: className,
        subject: subject,
        groupNumber: groupNumber,
        schoolYear: schoolYear,
        term: term,
        courseworkWeightPercent: courseworkWeightPercent,
        students: students,
        categories: categories,
        assessments: values,
        scores: scores,
        exams: exams,
      );

  Map<String, dynamic> toJson() => {
        'schemaVersion': 1,
        'ownerId': ownerId,
        'classId': classId,
        'className': className,
        'subject': subject,
        'groupNumber': groupNumber,
        'schoolYear': schoolYear,
        'term': term,
        if (courseworkWeightPercent != null)
          'courseworkWeightPercent': courseworkWeightPercent,
        'students': students.map((s) => s.toJson()).toList(),
        'categories': categories.map((c) => c.toJson()).toList(),
        'assessments': assessments.map((a) => a.toJson()).toList(),
        'scores': scores.map((s) => s.toJson()).toList(),
        'exams': exams.map((e) => e.toJson()).toList(),
      };

  factory GradebookDataset.fromJson(Map<String, dynamic> json) {
    _version(json);
    return GradebookDataset(
      ownerId: json['ownerId'] as String,
      classId: json['classId'] as String,
      className: json['className'] as String,
      subject: json['subject'] as String,
      groupNumber: json['groupNumber'] as String?,
      schoolYear: json['schoolYear'] as String,
      term: json['term'] as String,
      courseworkWeightPercent: (json['courseworkWeightPercent'] as num?)?.toDouble(),
      students: _rows(json, 'students', Student.fromJson),
      categories: _rows(json, 'categories', GradingCategory.fromJson),
      assessments: _rows(json, 'assessments', GradeItem.fromJson),
      scores: _rows(json, 'scores', StudentScore.fromJson),
      exams: _rows(json, 'exams', FinalExam.fromJson),
    );
  }
}

/// Sealed periods carry the exact calculation policy and materialized results.
/// Construction is pure; persistence/authorization belongs to the repository.
class GradingPeriod {
  static const calculationVersion = 'gradeflow-legacy-v1';
  static const nativeCalculationVersion = 'gradeflow-native-v2';
  final String periodId;
  final String label;
  final DateTime createdAt;
  final DateTime? sealedAt;
  final String policyVersion;
  final GradebookDataset dataset;
  final Map<String, Map<String, double?>>? results;
  bool get isSealed => sealedAt != null;

  GradingPeriod({
    required this.periodId,
    required this.label,
    required this.createdAt,
    required this.dataset,
    this.sealedAt,
    this.policyVersion = calculationVersion,
    Map<String, Map<String, double?>>? results,
  }) : results = results == null
            ? null
            : Map.unmodifiable({
                for (final entry in results.entries)
                  entry.key: Map<String, double?>.unmodifiable(entry.value),
              }) {
    if (periodId.isEmpty ||
        label.trim().isEmpty ||
        (isSealed != (results != null)) ||
        (sealedAt != null && sealedAt!.isBefore(createdAt))) {
      throw ArgumentError('Invalid period identity or seal');
    }
    if (isSealed) {
      final ids = dataset.students.map((s) => s.studentId).toSet();
      if (results!.keys.toSet().difference(ids).isNotEmpty ||
          ids.difference(results.keys.toSet()).isNotEmpty) {
        throw ArgumentError('Archive result roster differs from snapshot');
      }
    }
  }

  GradingPeriod editAssessments(List<GradeItem> values) {
    if (isSealed) throw StateError('Archived periods are immutable');
    return GradingPeriod(
        periodId: periodId,
        label: label,
        createdAt: createdAt,
        policyVersion: policyVersion,
        dataset: dataset.withAssessments(values));
  }

  GradingPeriod seal(DateTime at, Map<String, Map<String, double?>> grades) {
    if (isSealed) throw StateError('Period is already sealed');
    return GradingPeriod(
        periodId: periodId,
        label: label,
        createdAt: createdAt,
        dataset: dataset,
        policyVersion: policyVersion,
        sealedAt: at,
        results: grades);
  }

  Map<String, dynamic> toJson() => {
        'schemaVersion': 1,
        'periodId': periodId,
        'label': label,
        'createdAt': createdAt.toIso8601String(),
        'sealedAt': sealedAt?.toIso8601String(),
        'policyVersion': policyVersion,
        'dataset': dataset.toJson(),
        'results': results == null
            ? null
            : {
                for (final entry in results!.entries)
                  entry.key: Map.of(entry.value),
              },
      };

  factory GradingPeriod.fromJson(Map<String, dynamic> json) {
    _version(json);
    final raw = json['results'] as Map<String, dynamic>?;
    return GradingPeriod(
      periodId: json['periodId'] as String,
      label: json['label'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      sealedAt: json['sealedAt'] == null
          ? null
          : DateTime.parse(json['sealedAt'] as String),
      policyVersion: json['policyVersion'] as String,
      dataset: GradebookDataset.fromJson(
          Map<String, dynamic>.from(json['dataset'] as Map)),
      results: raw == null
          ? null
          : {
              for (final entry in raw.entries)
                entry.key: {
                  for (final grade in (entry.value as Map).entries)
                    grade.key as String: (grade.value as num?)?.toDouble()
                }
            },
    );
  }
}

/// Aggregate boundary: exactly one active period for this owner/class.
class GradingPeriodBook {
  final String ownerId;
  final String classId;
  final int revision;
  final String activePeriodId;
  final List<GradingPeriod> periods;
  GradingPeriodBook(
      {required this.ownerId,
      required this.classId,
      required this.revision,
      required this.activePeriodId,
      required List<GradingPeriod> periods})
      : periods = List.unmodifiable(periods) {
    _unique(periods.map((p) => p.periodId));
    if (ownerId.isEmpty ||
        classId.isEmpty ||
        revision < 0 ||
        periods.where((p) => !p.isSealed).length != 1 ||
        !periods.any((p) => p.periodId == activePeriodId && !p.isSealed) ||
        periods.any((p) =>
            p.dataset.ownerId != ownerId || p.dataset.classId != classId)) {
      throw ArgumentError('Invalid active period or book scope');
    }
  }
  GradingPeriod get active =>
      periods.firstWhere((p) => p.periodId == activePeriodId);
  Map<String, dynamic> toJson() => {
        'schemaVersion': 1,
        'ownerId': ownerId,
        'classId': classId,
        'revision': revision,
        'activePeriodId': activePeriodId,
        'periods': periods.map((p) => p.toJson()).toList(),
      };
  factory GradingPeriodBook.fromJson(Map<String, dynamic> json) {
    _version(json);
    return GradingPeriodBook(
        ownerId: json['ownerId'] as String,
        classId: json['classId'] as String,
        revision: json['revision'] as int,
        activePeriodId: json['activePeriodId'] as String,
        periods: _rows(json, 'periods', GradingPeriod.fromJson));
  }
}

void _unique(Iterable<String> values) {
  final seen = <String>{};
  if (values.any((v) => v.isEmpty || !seen.add(v))) {
    throw ArgumentError('Empty or duplicate identity');
  }
}

void _version(Map<String, dynamic> json) {
  if (json['schemaVersion'] != 1)
    throw FormatException('Unsupported grading schema');
}

List<T> _rows<T>(Map<String, dynamic> json, String key,
        T Function(Map<String, dynamic>) read) =>
    (json[key] as List)
        .map((e) => read(Map<String, dynamic>.from(e as Map)))
        .toList();

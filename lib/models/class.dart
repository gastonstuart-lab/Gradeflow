class Class {
  final String classId;
  final String className;
  final String subject;
  final String? groupNumber;
  final String schoolYear;
  final String term;
  final String teacherId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isArchived;

  Class({
    required this.classId,
    required this.className,
    required this.subject,
    this.groupNumber,
    required this.schoolYear,
    required this.term,
    required this.teacherId,
    required this.createdAt,
    required this.updatedAt,
    this.isArchived = false,
  });

  Map<String, dynamic> toJson() => {
    'classId': classId,
    'className': className,
    'subject': subject,
    'groupNumber': groupNumber,
    'schoolYear': schoolYear,
    'term': term,
    'teacherId': teacherId,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'isArchived': isArchived,
  };

  factory Class.fromJson(Map<String, dynamic> json) => Class(
    classId: json['classId'] as String,
    className: json['className'] as String,
    subject: json['subject'] as String,
    groupNumber: json['groupNumber'] as String?,
    schoolYear: json['schoolYear'] as String,
    term: json['term'] as String,
    teacherId: json['teacherId'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
    isArchived: (json['isArchived'] as bool?) ?? false,
  );

  Class copyWith({
    String? classId,
    String? className,
    String? subject,
    String? groupNumber,
    String? schoolYear,
    String? term,
    String? teacherId,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isArchived,
  }) => Class(
    classId: classId ?? this.classId,
    className: className ?? this.className,
    subject: subject ?? this.subject,
    groupNumber: groupNumber ?? this.groupNumber,
    schoolYear: schoolYear ?? this.schoolYear,
    term: term ?? this.term,
    teacherId: teacherId ?? this.teacherId,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    isArchived: isArchived ?? this.isArchived,
  );
}

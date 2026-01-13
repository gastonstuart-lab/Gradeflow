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
  final ClassSyllabus? syllabus;

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
    this.syllabus,
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
    'syllabus': syllabus?.toJson(),
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
    syllabus: (json['syllabus'] is Map)
        ? ClassSyllabus.fromJson(Map<String, dynamic>.from(json['syllabus'] as Map))
        : null,
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
    ClassSyllabus? syllabus,
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
    syllabus: syllabus ?? this.syllabus,
  );
}

class ClassSyllabus {
  final String? sourceFilename;
  final List<String> headerLines;
  final List<ClassSyllabusEntry> entries;
  final DateTime extractedAt;

  ClassSyllabus({
    required this.headerLines,
    required this.entries,
    required this.extractedAt,
    this.sourceFilename,
  });

  Map<String, dynamic> toJson() => {
        'sourceFilename': sourceFilename,
        'headerLines': headerLines,
        'entries': entries.map((e) => e.toJson()).toList(),
        'extractedAt': extractedAt.toIso8601String(),
      };

  factory ClassSyllabus.fromJson(Map<String, dynamic> json) => ClassSyllabus(
        sourceFilename: json['sourceFilename'] as String?,
        headerLines: (json['headerLines'] as List?)
                ?.map((e) => e?.toString() ?? '')
                .where((s) => s.trim().isNotEmpty)
                .toList() ??
            const [],
        entries: (json['entries'] as List?)
                ?.whereType<Map>()
                .map((e) =>
                    ClassSyllabusEntry.fromJson(Map<String, dynamic>.from(e)))
                .toList() ??
            const [],
        extractedAt:
            DateTime.tryParse(json['extractedAt'] as String? ?? '') ??
                DateTime.now(),
      );
}

class ClassSyllabusEntry {
  final String? section;
  final String week;
  final String dateRange;
  final String lessonContent;
  final String? dateEvents;

  ClassSyllabusEntry({
    required this.week,
    required this.dateRange,
    required this.lessonContent,
    this.dateEvents,
    this.section,
  });

  Map<String, dynamic> toJson() => {
        'section': section,
        'week': week,
        'dateRange': dateRange,
        'lessonContent': lessonContent,
        'dateEvents': dateEvents,
      };

  factory ClassSyllabusEntry.fromJson(Map<String, dynamic> json) =>
      ClassSyllabusEntry(
        section: json['section'] as String?,
        week: (json['week'] ?? '').toString(),
        dateRange: (json['dateRange'] ?? '').toString(),
        lessonContent: (json['lessonContent'] ?? '').toString(),
        dateEvents: json['dateEvents']?.toString(),
      );
}

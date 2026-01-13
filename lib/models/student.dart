class Student {
  final String studentId;
  final String chineseName;
  final String englishFirstName;
  final String englishLastName;
  final String? seatNo;
  final String? classCode;
  final String? photoBase64; // Optional inline avatar image
  final String classId;
  final DateTime createdAt;
  final DateTime updatedAt;

  Student({
    required this.studentId,
    required this.chineseName,
    required this.englishFirstName,
    required this.englishLastName,
    this.seatNo,
    this.classCode,
    this.photoBase64,
    required this.classId,
    required this.createdAt,
    required this.updatedAt,
  });

  String get englishFullName => '$englishFirstName $englishLastName';

  Map<String, dynamic> toJson() => {
    'studentId': studentId,
    'chineseName': chineseName,
    'englishFirstName': englishFirstName,
    'englishLastName': englishLastName,
    'seatNo': seatNo,
    'classCode': classCode,
    'photoBase64': photoBase64,
    'classId': classId,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory Student.fromJson(Map<String, dynamic> json) => Student(
    studentId: json['studentId'] as String,
    chineseName: json['chineseName'] as String,
    englishFirstName: json['englishFirstName'] as String,
    englishLastName: json['englishLastName'] as String,
    seatNo: json['seatNo'] as String?,
    classCode: json['classCode'] as String?,
    photoBase64: json['photoBase64'] as String?,
    classId: json['classId'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );

  Student copyWith({
    String? studentId,
    String? chineseName,
    String? englishFirstName,
    String? englishLastName,
    String? seatNo,
    String? classCode,
    String? photoBase64,
    String? classId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Student(
    studentId: studentId ?? this.studentId,
    chineseName: chineseName ?? this.chineseName,
    englishFirstName: englishFirstName ?? this.englishFirstName,
    englishLastName: englishLastName ?? this.englishLastName,
    seatNo: seatNo ?? this.seatNo,
    classCode: classCode ?? this.classCode,
    photoBase64: photoBase64 ?? this.photoBase64,
    classId: classId ?? this.classId,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}

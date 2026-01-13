class User {
  final String userId;
  final String email;
  final String fullName;
  final String? schoolName;
  final String? photoBase64; // Optional inline avatar image for teacher
  final DateTime createdAt;
  final DateTime updatedAt;

  User({
    required this.userId,
    required this.email,
    required this.fullName,
    this.schoolName,
    this.photoBase64,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'email': email,
        'fullName': fullName,
        'schoolName': schoolName,
        'photoBase64': photoBase64,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory User.fromJson(Map<String, dynamic> json) => User(
        userId: json['userId'] as String,
        email: json['email'] as String,
        fullName: json['fullName'] as String,
        schoolName: json['schoolName'] as String?,
        photoBase64: json['photoBase64'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );

  User copyWith({
    String? userId,
    String? email,
    String? fullName,
    String? schoolName,
    String? photoBase64,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      User(
        userId: userId ?? this.userId,
        email: email ?? this.email,
        fullName: fullName ?? this.fullName,
        schoolName: schoolName ?? this.schoolName,
        photoBase64: photoBase64 ?? this.photoBase64,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

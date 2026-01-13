import 'package:gradeflow/models/grading_category.dart';

class CategoryTemplate {
  final String name;
  final double weightPercent;
  final AggregationMethod aggregationMethod;
  final int? aggregationParam;

  CategoryTemplate({
    required this.name,
    required this.weightPercent,
    required this.aggregationMethod,
    this.aggregationParam,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'weightPercent': weightPercent,
    'aggregationMethod': aggregationMethod.name,
    'aggregationParam': aggregationParam,
  };

  factory CategoryTemplate.fromJson(Map<String, dynamic> json) => CategoryTemplate(
    name: json['name'] as String,
    weightPercent: (json['weightPercent'] as num).toDouble(),
    aggregationMethod: AggregationMethod.values.firstWhere(
      (e) => e.name == json['aggregationMethod'],
    ),
    aggregationParam: json['aggregationParam'] as int?,
  );
}

class GradingTemplate {
  final String templateId;
  final String name;
  final String teacherId;
  final List<CategoryTemplate> categories;
  final DateTime createdAt;
  final DateTime updatedAt;

  GradingTemplate({
    required this.templateId,
    required this.name,
    required this.teacherId,
    required this.categories,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'templateId': templateId,
    'name': name,
    'teacherId': teacherId,
    'categories': categories.map((c) => c.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory GradingTemplate.fromJson(Map<String, dynamic> json) => GradingTemplate(
    templateId: json['templateId'] as String,
    name: json['name'] as String,
    teacherId: json['teacherId'] as String,
    categories: (json['categories'] as List)
        .map((c) => CategoryTemplate.fromJson(c as Map<String, dynamic>))
        .toList(),
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );

  GradingTemplate copyWith({
    String? templateId,
    String? name,
    String? teacherId,
    List<CategoryTemplate>? categories,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => GradingTemplate(
    templateId: templateId ?? this.templateId,
    name: name ?? this.name,
    teacherId: teacherId ?? this.teacherId,
    categories: categories ?? this.categories,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}

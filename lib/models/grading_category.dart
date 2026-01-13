enum AggregationMethod {
  average,
  sum,
  bestN,
  dropLowestN;

  String get displayName {
    switch (this) {
      case AggregationMethod.average:
        return 'Average';
      case AggregationMethod.sum:
        return 'Sum';
      case AggregationMethod.bestN:
        return 'Best N';
      case AggregationMethod.dropLowestN:
        return 'Drop Lowest N';
    }
  }
}

class GradingCategory {
  final String categoryId;
  final String classId;
  final String name;
  final double weightPercent;
  final AggregationMethod aggregationMethod;
  final int? aggregationParam;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  GradingCategory({
    required this.categoryId,
    required this.classId,
    required this.name,
    required this.weightPercent,
    required this.aggregationMethod,
    this.aggregationParam,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'categoryId': categoryId,
    'classId': classId,
    'name': name,
    'weightPercent': weightPercent,
    'aggregationMethod': aggregationMethod.name,
    'aggregationParam': aggregationParam,
    'isActive': isActive,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory GradingCategory.fromJson(Map<String, dynamic> json) => GradingCategory(
    categoryId: json['categoryId'] as String,
    classId: json['classId'] as String,
    name: json['name'] as String,
    weightPercent: (json['weightPercent'] as num).toDouble(),
    aggregationMethod: AggregationMethod.values.firstWhere(
      (e) => e.name == json['aggregationMethod'],
    ),
    aggregationParam: json['aggregationParam'] as int?,
    isActive: json['isActive'] as bool,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );

  GradingCategory copyWith({
    String? categoryId,
    String? classId,
    String? name,
    double? weightPercent,
    AggregationMethod? aggregationMethod,
    int? aggregationParam,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => GradingCategory(
    categoryId: categoryId ?? this.categoryId,
    classId: classId ?? this.classId,
    name: name ?? this.name,
    weightPercent: weightPercent ?? this.weightPercent,
    aggregationMethod: aggregationMethod ?? this.aggregationMethod,
    aggregationParam: aggregationParam ?? this.aggregationParam,
    isActive: isActive ?? this.isActive,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}

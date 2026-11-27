import 'grading_period.dart';

/// Stable intent, retained unchanged until its receipt is known. No client
/// snapshot/results are accepted by the trusted coordinator.
class GradingRolloverRequest {
  final String ownerId,
      classId,
      sourcePeriodId,
      nextPeriodId,
      label,
      operationId;
  final int expectedRevision;
  final DateTime at;
  final Map<AssessmentKind, double>? weights;
  GradingRolloverRequest(
      {required this.ownerId,
      required this.classId,
      required this.sourcePeriodId,
      required this.nextPeriodId,
      required this.label,
      required this.expectedRevision,
      required this.at,
      Map<AssessmentKind, double>? weights,
      String? operationId})
      : weights = weights == null ? null : Map.unmodifiable(weights),
        operationId = operationId ??
            'rollover:$expectedRevision:$sourcePeriodId:$nextPeriodId' {
    for (final id in [
      ownerId,
      classId,
      sourcePeriodId,
      nextPeriodId,
      this.operationId
    ]) {
      if (id.isEmpty ||
          id.contains('/') ||
          id == '.' ||
          id == '..' ||
          id.length > 1000) {
        throw ArgumentError('Invalid rollover identity');
      }
    }
    if (sourcePeriodId == nextPeriodId ||
        expectedRevision < 0 ||
        label.trim().isEmpty ||
        label.length > 1000) throw ArgumentError('Invalid rollover intent');
  }
  Map<String, dynamic> toJson() => {
        'ownerId': ownerId,
        'classId': classId,
        'sourcePeriodId': sourcePeriodId,
        'nextPeriodId': nextPeriodId,
        'label': label,
        'operationId': operationId,
        'expectedRevision': expectedRevision,
        'at': at.toUtc().toIso8601String(),
        'weights': weights == null
            ? null
            : {
                for (final k in AssessmentKind.values)
                  if (weights!.containsKey(k)) k.name: weights![k]
              },
      };
  factory GradingRolloverRequest.fromJson(Map<String, dynamic> json) {
    const keys = {
      'ownerId',
      'classId',
      'sourcePeriodId',
      'nextPeriodId',
      'label',
      'operationId',
      'expectedRevision',
      'at',
      'weights'
    };
    if (json.keys.toSet().difference(keys).isNotEmpty ||
        !json.keys.toSet().containsAll(keys)) {
      throw FormatException('Rollover accepts intent only');
    }
    final raw = json['weights'] as Map<String, dynamic>?;
    return GradingRolloverRequest(
      ownerId: json['ownerId'] as String,
      classId: json['classId'] as String,
      sourcePeriodId: json['sourcePeriodId'] as String,
      nextPeriodId: json['nextPeriodId'] as String,
      label: json['label'] as String,
      operationId: json['operationId'] as String,
      expectedRevision: json['expectedRevision'] as int,
      at: DateTime.parse(json['at'] as String),
      weights: raw == null
          ? null
          : {
              for (final e in raw.entries)
                AssessmentKind.values.byName(e.key): (e.value as num).toDouble()
            },
    );
  }
}

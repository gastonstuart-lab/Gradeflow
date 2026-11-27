import 'dart:convert';
import '../models/grading_period.dart';

Map<String, dynamic> encodeStoredPeriod(GradingPeriod period) {
  final json = period.toJson();
  final data = <String, dynamic>{
    'schemaVersion': 1,
    'ownerId': period.dataset.ownerId,
    'classId': period.dataset.classId,
    'periodId': period.periodId,
    'label': period.label,
    'createdAt': json['createdAt'],
    'sealedAt': json['sealedAt'],
    'policyVersion': period.policyVersion,
    'datasetJson': jsonEncode(json['dataset']),
    'resultsJson': period.results == null ? null : jsonEncode(json['results']),
  };
  if (utf8.encode(jsonEncode(data)).length > 600000) {
    throw ArgumentError(
        'Period exceeds 600 KB; chunked storage is not supported');
  }
  return data;
}

GradingPeriod decodeStoredPeriod(Map<String, dynamic> data) =>
    GradingPeriod.fromJson({
      ...data,
      'dataset': jsonDecode(data['datasetJson'] as String),
      'results': data['resultsJson'] == null
          ? null
          : jsonDecode(data['resultsJson'] as String),
    });

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:gradeflow/models/pilot_feedback_entry.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PilotFeedbackService extends ChangeNotifier {
  static const String _entriesKey = 'pilot_feedback_entries_v1';
  static const String _guideDismissedKey = 'pilot_feedback_guide_dismissed_v1';

  final List<PilotFeedbackEntry> _entries = [];
  bool _guideDismissed = false;
  bool _loaded = false;

  List<PilotFeedbackEntry> get entries => List.unmodifiable(_entries);
  bool get guideDismissed => _guideDismissed;
  bool get isLoaded => _loaded;

  PilotFeedbackService() {
    load();
  }

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawEntries = prefs.getString(_entriesKey);
      final guideDismissed = prefs.getBool(_guideDismissedKey) ?? false;

      if (rawEntries != null && rawEntries.isNotEmpty) {
        final decoded = json.decode(rawEntries) as List<dynamic>;
        _entries
          ..clear()
          ..addAll(decoded.map((entry) {
            return PilotFeedbackEntry.fromJson(
              entry as Map<String, dynamic>,
            );
          }));
      }

      _guideDismissed = guideDismissed;
    } catch (e) {
      debugPrint('Failed to load pilot feedback: $e');
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  Future<PilotFeedbackEntry> addEntry({
    required String category,
    required String area,
    required String summary,
    required String details,
    String route = '',
  }) async {
    final entry = PilotFeedbackEntry(
      entryId: 'feedback-${DateTime.now().microsecondsSinceEpoch}',
      category: category,
      area: area.trim().isEmpty ? 'General' : area.trim(),
      summary: summary.trim(),
      details: details.trim(),
      route: route.trim(),
      createdAt: DateTime.now(),
    );

    _entries.insert(0, entry);
    if (_entries.length > 40) {
      _entries.removeRange(40, _entries.length);
    }
    await _persistEntries();
    notifyListeners();
    return entry;
  }

  Future<void> dismissGuide() async {
    _guideDismissed = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_guideDismissedKey, true);
    notifyListeners();
  }

  Future<void> showGuide() async {
    _guideDismissed = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_guideDismissedKey, false);
    notifyListeners();
  }

  String buildReportText(
    PilotFeedbackEntry entry, {
    String? teacherName,
  }) {
    final buffer = StringBuffer()
      ..writeln('GradeFlow Pilot Feedback')
      ..writeln(
          'Teacher: ${teacherName?.trim().isNotEmpty == true ? teacherName!.trim() : 'Unknown'}')
      ..writeln('Submitted: ${entry.createdAt.toIso8601String()}')
      ..writeln('Category: ${entry.category}')
      ..writeln('Area: ${entry.area}')
      ..writeln('Route: ${entry.route.isEmpty ? 'Not provided' : entry.route}')
      ..writeln()
      ..writeln('Summary')
      ..writeln(entry.summary)
      ..writeln()
      ..writeln('Details')
      ..writeln(entry.details);
    return buffer.toString().trim();
  }

  Future<void> _persistEntries() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = json.encode(
        _entries.map((entry) => entry.toJson()).toList(),
      );
      await prefs.setString(_entriesKey, encoded);
    } catch (e) {
      debugPrint('Failed to save pilot feedback: $e');
    }
  }
}

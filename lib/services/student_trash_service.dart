import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gradeflow/models/deleted_student_entry.dart';

class StudentTrashService extends ChangeNotifier {
  static const String _trashKey = 'student_trash';

  final List<DeletedStudentEntry> _trash = [];
  bool _isLoading = false;

  List<DeletedStudentEntry> get trash => List.unmodifiable(_trash);
  bool get isLoading => _isLoading;

  Future<void> loadTrash({String? classId}) async {
    _isLoading = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_trashKey);
      _trash.clear();
      if (raw != null) {
        final list = (json.decode(raw) as List).cast<Map<String, dynamic>>();
        final entries = list.map((m) => DeletedStudentEntry.fromJson(m)).toList();
        if (classId == null) {
          _trash.addAll(entries);
        } else {
          _trash.addAll(entries.where((e) => e.student.classId == classId));
        }
      }
    } catch (e) {
      debugPrint('Failed to load student trash: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addToTrash(DeletedStudentEntry entry) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_trashKey);
      List<Map<String, dynamic>> list = [];
      if (raw != null) list = (json.decode(raw) as List).cast<Map<String, dynamic>>();
      // ensure unique by studentId (remove older ones for same student)
      list.removeWhere((m) => (m['student'] as Map<String, dynamic>)['studentId'] == entry.student.studentId);
      list.add(entry.toJson());
      await prefs.setString(_trashKey, json.encode(list));
      // update in-memory if filtered view includes it
      final idx = _trash.indexWhere((e) => e.student.studentId == entry.student.studentId);
      if (idx != -1) {
        _trash[idx] = entry;
      } else {
        _trash.add(entry);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to add to trash: $e');
    }
  }

  Future<DeletedStudentEntry?> getEntry(String studentId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_trashKey);
      if (raw == null) return null;
      final list = (json.decode(raw) as List).cast<Map<String, dynamic>>();
      final idx = list.indexWhere((m) => (m['student'] as Map<String, dynamic>)['studentId'] == studentId);
      if (idx == -1) return null;
      return DeletedStudentEntry.fromJson(list[idx]);
    } catch (e) {
      debugPrint('Failed to read entry from trash: $e');
      return null;
    }
  }

  Future<void> removeFromTrash(String studentId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_trashKey);
      if (raw == null) return;
      final list = (json.decode(raw) as List).cast<Map<String, dynamic>>();
      list.removeWhere((m) => (m['student'] as Map<String, dynamic>)['studentId'] == studentId);
      await prefs.setString(_trashKey, json.encode(list));
      _trash.removeWhere((e) => e.student.studentId == studentId);
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to remove from trash: $e');
    }
  }

  Future<int> emptyTrash({String? classId, Duration? olderThan}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_trashKey);
      if (raw == null) return 0;
      final now = DateTime.now();
      final list = (json.decode(raw) as List).cast<Map<String, dynamic>>();
      final before = list.length;
      List<Map<String, dynamic>> kept = list.where((m) {
        final s = m['student'] as Map<String, dynamic>;
        final sidClass = s['classId'] as String;
        final delAt = DateTime.parse(m['deletedAt'] as String);
        final classFilter = classId == null || sidClass == classId;
        final timeFilter = olderThan == null || now.difference(delAt) > olderThan;
        // Keep if it doesn't match both filters (i.e., do not delete)
        return !(classFilter && timeFilter);
      }).toList();
      await prefs.setString(_trashKey, json.encode(kept));
      // refresh in-memory
      await loadTrash(classId: classId);
      return before - kept.length;
    } catch (e) {
      debugPrint('Failed to empty trash: $e');
      return 0;
    }
  }
}

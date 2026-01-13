import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:gradeflow/models/deleted_class_entry.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ClassTrashService extends ChangeNotifier {
  static const String _trashKey = 'class_trash';

  final List<DeletedClassEntry> _trash = [];
  bool _isLoading = false;

  List<DeletedClassEntry> get trash => List.unmodifiable(_trash);
  bool get isLoading => _isLoading;

  Future<void> loadTrash({required String teacherId}) async {
    _isLoading = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_trashKey);
      _trash.clear();
      if (raw != null) {
        final list = (json.decode(raw) as List).cast<Map<String, dynamic>>();
        final entries = list.map((m) => DeletedClassEntry.fromJson(m)).toList();
        _trash.addAll(entries.where((e) => e.classItem.teacherId == teacherId));
      }
    } catch (e) {
      debugPrint('Failed to load class trash: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addToTrash(DeletedClassEntry entry) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_trashKey);
      List<Map<String, dynamic>> list = [];
      if (raw != null) list = (json.decode(raw) as List).cast<Map<String, dynamic>>();

      list.removeWhere((m) => (m['class'] as Map<String, dynamic>)['classId'] == entry.classItem.classId);
      list.add(entry.toJson());
      await prefs.setString(_trashKey, json.encode(list));

      final idx = _trash.indexWhere((e) => e.classItem.classId == entry.classItem.classId);
      if (idx != -1) {
        _trash[idx] = entry;
      } else {
        _trash.add(entry);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to add class to trash: $e');
    }
  }

  Future<void> removeFromTrash(String classId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_trashKey);
      if (raw == null) return;
      final list = (json.decode(raw) as List).cast<Map<String, dynamic>>();
      list.removeWhere((m) => (m['class'] as Map<String, dynamic>)['classId'] == classId);
      await prefs.setString(_trashKey, json.encode(list));
      _trash.removeWhere((e) => e.classItem.classId == classId);
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to remove class from trash: $e');
    }
  }

  Future<int> emptyTrash({required String teacherId, Duration? olderThan}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_trashKey);
      if (raw == null) return 0;

      final now = DateTime.now();
      final list = (json.decode(raw) as List).cast<Map<String, dynamic>>();
      final before = list.length;

      final kept = list.where((m) {
        final c = (m['class'] as Map<String, dynamic>);
        final isTeacher = (c['teacherId'] as String?) == teacherId;
        if (!isTeacher) return true;

        if (olderThan == null) return false;
        final delAt = DateTime.parse(m['deletedAt'] as String);
        return now.difference(delAt) <= olderThan;
      }).toList();

      await prefs.setString(_trashKey, json.encode(kept));
      await loadTrash(teacherId: teacherId);
      return before - kept.length;
    } catch (e) {
      debugPrint('Failed to empty class trash: $e');
      return 0;
    }
  }
}

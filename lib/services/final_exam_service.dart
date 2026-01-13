import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:gradeflow/models/final_exam.dart';

class FinalExamService extends ChangeNotifier {
  static const String _examsKey = 'final_exams';
  List<FinalExam> _exams = [];
  bool _isLoading = false;

  List<FinalExam> get exams => _exams;
  bool get isLoading => _isLoading;

  Future<void> loadExams(List<String> studentIds) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final examsJson = prefs.getString(_examsKey);
      
      if (examsJson != null) {
        final List<dynamic> examList = json.decode(examsJson) as List;
        _exams = examList
            .map((e) => FinalExam.fromJson(e as Map<String, dynamic>))
            .where((e) => studentIds.contains(e.studentId))
            .toList();
      }
    } catch (e) {
      debugPrint('Failed to load exams: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateExam(FinalExam exam) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final examsJson = prefs.getString(_examsKey);
      List<Map<String, dynamic>> examList = [];
      
      if (examsJson != null) {
        examList = (json.decode(examsJson) as List).cast<Map<String, dynamic>>();
      }
      
      final index = examList.indexWhere((e) => e['studentId'] == exam.studentId);
      
      if (index != -1) {
        examList[index] = exam.toJson();
      } else {
        examList.add(exam.toJson());
      }
      
      await prefs.setString(_examsKey, json.encode(examList));
      
      final localIndex = _exams.indexWhere((e) => e.studentId == exam.studentId);
      if (localIndex != -1) {
        _exams[localIndex] = exam;
      } else {
        _exams.add(exam);
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to update exam: $e');
    }
  }

  Future<void> bulkUpdateExams(Map<String, double> examScores) async {
    for (var entry in examScores.entries) {
      final now = DateTime.now();
      await updateExam(FinalExam(
        studentId: entry.key,
        examScore: entry.value,
        createdAt: now,
        updatedAt: now,
      ));
    }
  }

  /// Efficiently upsert many exam scores in a single storage write.
  /// Pass null to remove a student's exam record.
  /// Returns the number of items that were changed.
  Future<int> upsertManyExams(Map<String, double?> changes) async {
    if (changes.isEmpty) return 0;
    int changed = 0;
    try {
      final prefs = await SharedPreferences.getInstance();
      final examsJson = prefs.getString(_examsKey);
      List<Map<String, dynamic>> examList = [];
      if (examsJson != null) {
        examList = (json.decode(examsJson) as List).cast<Map<String, dynamic>>();
      }

      // Build an index for quick lookups
      final indexById = <String, int>{};
      for (var i = 0; i < examList.length; i++) {
        final id = examList[i]['studentId'] as String?;
        if (id != null) indexById[id] = i;
      }

      final now = DateTime.now();
      for (final entry in changes.entries) {
        final sid = entry.key;
        final val = entry.value;
        final idx = indexById[sid];
        if (val == null) {
          // remove if exists
          if (idx != null) {
            examList.removeAt(idx);
            // re-build index lazily for correctness
            indexById.clear();
            for (var i = 0; i < examList.length; i++) {
              final id = examList[i]['studentId'] as String?;
              if (id != null) indexById[id] = i;
            }
            _exams.removeWhere((e) => e.studentId == sid);
            changed++;
          }
        } else {
          final exam = FinalExam(
            studentId: sid,
            examScore: val,
            createdAt: now,
            updatedAt: now,
          );
          if (idx != null) {
            examList[idx] = exam.toJson();
          } else {
            examList.add(exam.toJson());
            // update index for subsequent ops
            indexById[sid] = examList.length - 1;
          }
          final localIdx = _exams.indexWhere((e) => e.studentId == sid);
          if (localIdx != -1) {
            _exams[localIdx] = exam;
          } else {
            _exams.add(exam);
          }
          changed++;
        }
      }

      await prefs.setString(_examsKey, json.encode(examList));
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to upsert many exams: $e');
    }
    return changed;
  }

  FinalExam? getExam(String studentId) {
    try {
      return _exams.firstWhere((e) => e.studentId == studentId);
    } catch (e) {
      return null;
    }
  }

  /// Delete the final exam record for a specific student, if it exists.
  Future<void> deleteExamForStudent(String studentId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final examsJson = prefs.getString(_examsKey);
      if (examsJson != null) {
        List<Map<String, dynamic>> examList = (json.decode(examsJson) as List).cast<Map<String, dynamic>>();
        final before = examList.length;
        examList.removeWhere((e) => e['studentId'] == studentId);
        await prefs.setString(_examsKey, json.encode(examList));
        _exams.removeWhere((e) => e.studentId == studentId);
        notifyListeners();
        debugPrint('Deleted ${before - examList.length} exam entries for student $studentId');
      }
    } catch (e) {
      debugPrint('Failed to delete exam for student $studentId: $e');
    }
  }

  /// Removes and returns the student's exam, to support undo.
  Future<FinalExam?> removeAndReturnExamForStudent(String studentId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final examsJson = prefs.getString(_examsKey);
      if (examsJson == null) return null;
      List<Map<String, dynamic>> examList = (json.decode(examsJson) as List).cast<Map<String, dynamic>>();
      final idx = examList.indexWhere((e) => e['studentId'] == studentId);
      if (idx == -1) return null;
      final removedMap = examList.removeAt(idx);
      await prefs.setString(_examsKey, json.encode(examList));
      final removed = FinalExam.fromJson(removedMap);
      _exams.removeWhere((e) => e.studentId == studentId);
      notifyListeners();
      debugPrint('Temporarily removed final exam for $studentId');
      return removed;
    } catch (e) {
      debugPrint('Failed to remove and return exam for $studentId: $e');
      return null;
    }
  }

  /// Restores a student's exam back into storage.
  Future<void> restoreExam(FinalExam exam) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final examsJson = prefs.getString(_examsKey);
      List<Map<String, dynamic>> examList = [];
      if (examsJson != null) {
        examList = (json.decode(examsJson) as List).cast<Map<String, dynamic>>();
      }
      // Ensure unique per studentId
      examList.removeWhere((e) => e['studentId'] == exam.studentId);
      examList.add(exam.toJson());
      await prefs.setString(_examsKey, json.encode(examList));
      final localIdx = _exams.indexWhere((e) => e.studentId == exam.studentId);
      if (localIdx != -1) {
        _exams[localIdx] = exam;
      } else {
        _exams.add(exam);
      }
      notifyListeners();
      debugPrint('Restored final exam for ${exam.studentId}');
    } catch (e) {
      debugPrint('Failed to restore exam: $e');
    }
  }

  Future<void> seedDemoExams(List<String> studentIds) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final examsJson = prefs.getString(_examsKey);
      List<Map<String, dynamic>> examList = [];
      
      if (examsJson != null) {
        examList = (json.decode(examsJson) as List).cast<Map<String, dynamic>>();
      }
      
      final now = DateTime.now();
      for (var studentId in studentIds) {
        final exists = examList.any((e) => e['studentId'] == studentId);
        
        if (!exists) {
          final exam = FinalExam(
            studentId: studentId,
            examScore: 75.0 + (studentId.hashCode % 20).toDouble(),
            createdAt: now,
            updatedAt: now,
          );
          examList.add(exam.toJson());
        }
      }
      
      await prefs.setString(_examsKey, json.encode(examList));
      debugPrint('Demo final exams seeded successfully');
    } catch (e) {
      debugPrint('Failed to seed demo exams: $e');
    }
  }
}

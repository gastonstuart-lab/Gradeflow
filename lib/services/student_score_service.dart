import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:gradeflow/models/student_score.dart';
import 'package:gradeflow/models/change_history.dart';
import 'package:uuid/uuid.dart';

class StudentScoreService extends ChangeNotifier {
  static const String _scoresKey = 'student_scores';
  static const String _historyKey = 'change_history';
  List<StudentScore> _scores = [];
  List<ChangeHistory> _history = [];
  bool _isLoading = false;

  List<StudentScore> get scores => _scores;
  bool get isLoading => _isLoading;

  Future<void> loadScores(String classId, List<String> gradeItemIds) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final scoresJson = prefs.getString(_scoresKey);
      
      if (scoresJson != null) {
        final List<dynamic> scoreList = json.decode(scoresJson) as List;
        _scores = scoreList
            .map((s) => StudentScore.fromJson(s as Map<String, dynamic>))
            .where((s) => gradeItemIds.contains(s.gradeItemId))
            .toList();
      }
    } catch (e) {
      debugPrint('Failed to load scores: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateScore(StudentScore score, String teacherId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final scoresJson = prefs.getString(_scoresKey);
      List<Map<String, dynamic>> scoreList = [];
      
      if (scoresJson != null) {
        scoreList = (json.decode(scoresJson) as List).cast<Map<String, dynamic>>();
      }
      
      final index = scoreList.indexWhere(
        (s) => s['studentId'] == score.studentId && s['gradeItemId'] == score.gradeItemId,
      );
      
      double? oldScore;
      if (index != -1) {
        oldScore = (scoreList[index]['score'] as num?)?.toDouble();
        scoreList[index] = score.toJson();
      } else {
        scoreList.add(score.toJson());
      }
      
      await prefs.setString(_scoresKey, json.encode(scoreList));
      
      await _addHistory(score.studentId, score.gradeItemId, oldScore, score.score, teacherId);
      
      final localIndex = _scores.indexWhere(
        (s) => s.studentId == score.studentId && s.gradeItemId == score.gradeItemId,
      );
      
      if (localIndex != -1) {
        _scores[localIndex] = score;
      } else {
        _scores.add(score);
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to update score: $e');
    }
  }

  Future<void> setAllScoresForGradeItem(String gradeItemId, List<String> studentIds, double? score, String teacherId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final scoresJson = prefs.getString(_scoresKey);
      List<Map<String, dynamic>> scoreList = [];
      if (scoresJson != null) {
        scoreList = (json.decode(scoresJson) as List).cast<Map<String, dynamic>>();
      }

      final now = DateTime.now();
      for (final studentId in studentIds) {
        final idx = scoreList.indexWhere((s) => s['studentId'] == studentId && s['gradeItemId'] == gradeItemId);
        double? oldScore;
        final entry = StudentScore(studentId: studentId, gradeItemId: gradeItemId, score: score, createdAt: now, updatedAt: now);
        if (idx != -1) {
          oldScore = (scoreList[idx]['score'] as num?)?.toDouble();
          scoreList[idx] = entry.toJson();
        } else {
          scoreList.add(entry.toJson());
        }
        await _addHistory(studentId, gradeItemId, oldScore, score, teacherId);

        final localIndex = _scores.indexWhere((s) => s.studentId == studentId && s.gradeItemId == gradeItemId);
        if (localIndex != -1) {
          _scores[localIndex] = entry;
        } else {
          _scores.add(entry);
        }
      }

      await prefs.setString(_scoresKey, json.encode(scoreList));
      notifyListeners();
      debugPrint('Applied score ${score?.toStringAsFixed(0)} to ${studentIds.length} students for item=$gradeItemId');
    } catch (e) {
      debugPrint('Failed to apply score to all: $e');
    }
  }

  Future<void> _addHistory(String studentId, String gradeItemId, double? oldScore, double? newScore, String teacherId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString(_historyKey);
      List<Map<String, dynamic>> historyList = [];
      
      if (historyJson != null) {
        historyList = (json.decode(historyJson) as List).cast<Map<String, dynamic>>();
      }
      
      final change = ChangeHistory(
        changeId: const Uuid().v4(),
        studentId: studentId,
        gradeItemId: gradeItemId,
        oldScore: oldScore,
        newScore: newScore,
        teacherId: teacherId,
        timestamp: DateTime.now(),
      );
      
      historyList.add(change.toJson());
      
      if (historyList.length > 100) {
        historyList = historyList.sublist(historyList.length - 100);
      }
      
      await prefs.setString(_historyKey, json.encode(historyList));
      _history.insert(0, change);
      
      if (_history.length > 100) {
        _history = _history.sublist(0, 100);
      }
    } catch (e) {
      debugPrint('Failed to add change history: $e');
    }
  }

  /// Delete all scores associated with a specific student across all grade items.
  Future<void> deleteScoresForStudent(String studentId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final scoresJson = prefs.getString(_scoresKey);
      if (scoresJson != null) {
        List<Map<String, dynamic>> scoreList = (json.decode(scoresJson) as List).cast<Map<String, dynamic>>();
        final before = scoreList.length;
        scoreList.removeWhere((s) => s['studentId'] == studentId);
        await prefs.setString(_scoresKey, json.encode(scoreList));
        _scores.removeWhere((s) => s.studentId == studentId);
        notifyListeners();
        debugPrint('Deleted ${before - scoreList.length} score entries for student $studentId');
      }
    } catch (e) {
      debugPrint('Failed to delete scores for student $studentId: $e');
    }
  }

  /// Removes and returns all scores for a student. Useful for implementing undo.
  Future<List<StudentScore>> removeAndReturnScoresForStudent(String studentId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final scoresJson = prefs.getString(_scoresKey);
      if (scoresJson == null) return [];
      List<Map<String, dynamic>> scoreList = (json.decode(scoresJson) as List).cast<Map<String, dynamic>>();
      // Collect removed scores
      final removed = scoreList
          .where((s) => s['studentId'] == studentId)
          .map((m) => StudentScore.fromJson(m))
          .toList();
      if (removed.isEmpty) return [];
      // Remove and persist
      scoreList.removeWhere((s) => s['studentId'] == studentId);
      await prefs.setString(_scoresKey, json.encode(scoreList));
      _scores.removeWhere((s) => s.studentId == studentId);
      notifyListeners();
      debugPrint('Temporarily removed ${removed.length} scores for student $studentId');
      return removed;
    } catch (e) {
      debugPrint('Failed to remove and return scores for $studentId: $e');
      return [];
    }
  }

  /// Restores a list of scores back into storage without adding history entries.
  Future<void> restoreScoresForStudent(List<StudentScore> scoresToRestore) async {
    if (scoresToRestore.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final scoresJson = prefs.getString(_scoresKey);
      List<Map<String, dynamic>> scoreList = [];
      if (scoresJson != null) {
        scoreList = (json.decode(scoresJson) as List).cast<Map<String, dynamic>>();
      }
      // Remove any duplicates for the same (studentId, gradeItemId) then add
      for (final sc in scoresToRestore) {
        scoreList.removeWhere((m) => m['studentId'] == sc.studentId && m['gradeItemId'] == sc.gradeItemId);
        scoreList.add(sc.toJson());
        final localIdx = _scores.indexWhere((s) => s.studentId == sc.studentId && s.gradeItemId == sc.gradeItemId);
        if (localIdx != -1) {
          _scores[localIdx] = sc;
        } else {
          _scores.add(sc);
        }
      }
      await prefs.setString(_scoresKey, json.encode(scoreList));
      notifyListeners();
      debugPrint('Restored ${scoresToRestore.length} scores from undo');
    } catch (e) {
      debugPrint('Failed to restore scores: $e');
    }
  }

  Future<bool> undoLastChange(String teacherId) async {
    try {
      if (_history.isEmpty) return false;
      
      final lastChange = _history.first;
      if (lastChange.teacherId != teacherId) return false;
      
      final now = DateTime.now();
      final revertedScore = StudentScore(
        studentId: lastChange.studentId,
        gradeItemId: lastChange.gradeItemId,
        score: lastChange.oldScore,
        createdAt: now,
        updatedAt: now,
      );
      
      await updateScore(revertedScore, teacherId);
      
      _history.removeAt(0);
      
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString(_historyKey);
      if (historyJson != null) {
        List<Map<String, dynamic>> historyList = (json.decode(historyJson) as List).cast<Map<String, dynamic>>();
        if (historyList.isNotEmpty) {
          historyList.removeAt(historyList.length - 1);
          await prefs.setString(_historyKey, json.encode(historyList));
        }
      }
      
      return true;
    } catch (e) {
      debugPrint('Failed to undo last change: $e');
      return false;
    }
  }

  StudentScore? getScore(String studentId, String gradeItemId) {
    try {
      return _scores.firstWhere(
        (s) => s.studentId == studentId && s.gradeItemId == gradeItemId,
      );
    } catch (e) {
      return null;
    }
  }

  List<StudentScore> getStudentScores(String studentId) {
    return _scores.where((s) => s.studentId == studentId).toList();
  }

  Future<void> seedDemoScores(List<String> studentIds, List<String> gradeItemIds) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final scoresJson = prefs.getString(_scoresKey);
      List<Map<String, dynamic>> scoreList = [];
      
      if (scoresJson != null) {
        scoreList = (json.decode(scoresJson) as List).cast<Map<String, dynamic>>();
      }
      
      final now = DateTime.now();
      for (var studentId in studentIds) {
        for (var gradeItemId in gradeItemIds) {
          final exists = scoreList.any(
            (s) => s['studentId'] == studentId && s['gradeItemId'] == gradeItemId,
          );
          
          if (!exists) {
            final score = StudentScore(
              studentId: studentId,
              gradeItemId: gradeItemId,
              score: 70.0 + (studentId.hashCode % 30).toDouble(),
              createdAt: now,
              updatedAt: now,
            );
            scoreList.add(score.toJson());
          }
        }
      }
      
      await prefs.setString(_scoresKey, json.encode(scoreList));
      debugPrint('Demo scores seeded successfully');
    } catch (e) {
      debugPrint('Failed to seed demo scores: $e');
    }
  }
}

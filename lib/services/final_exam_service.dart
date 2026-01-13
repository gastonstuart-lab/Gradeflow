import 'package:flutter/foundation.dart';
import 'package:gradeflow/models/final_exam.dart';
import 'package:gradeflow/repositories/repository_factory.dart';

class FinalExamService extends ChangeNotifier {
  List<FinalExam> _exams = [];
  bool _isLoading = false;

  List<FinalExam> get exams => _exams;
  bool get isLoading => _isLoading;

  Future<void> loadExams(String classId, List<String> studentIds) async {
    _isLoading = true;
    notifyListeners();

    try {
      final repo = RepositoryFactory.instance;
      final all = await repo.loadExams(classId);
      _exams = all.where((e) => studentIds.contains(e.studentId)).toList();
    } catch (e) {
      debugPrint('Failed to load exams: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateExam(String classId, FinalExam exam) async {
    try {
      final repo = RepositoryFactory.instance;
      final existing = await repo.loadExams(classId);
      final index = existing.indexWhere((e) => e.studentId == exam.studentId);

      if (index != -1) {
        existing[index] = exam;
      } else {
        existing.add(exam);
      }

      await repo.saveExams(classId, existing);

      final localIndex =
          _exams.indexWhere((e) => e.studentId == exam.studentId);
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

  Future<void> bulkUpdateExams(
      String classId, Map<String, double> examScores) async {
    await upsertManyExams(classId, examScores.map((k, v) => MapEntry(k, v)));
  }

  /// Efficiently upsert many exam scores in a single storage write.
  /// Pass null to remove a student's exam record.
  /// Returns the number of items that were changed.
  Future<int> upsertManyExams(
      String classId, Map<String, double?> changes) async {
    if (changes.isEmpty) return 0;
    int changed = 0;
    try {
      final repo = RepositoryFactory.instance;
      final existing = await repo.loadExams(classId);
      final indexById = <String, int>{
        for (var i = 0; i < existing.length; i++) existing[i].studentId: i,
      };

      final now = DateTime.now();
      for (final entry in changes.entries) {
        final sid = entry.key;
        final val = entry.value;
        final idx = indexById[sid];
        if (val == null) {
          // remove if exists
          if (idx != null) {
            existing.removeAt(idx);
            indexById
              ..clear()
              ..addEntries(
                [
                  for (var i = 0; i < existing.length; i++)
                    MapEntry(existing[i].studentId, i),
                ],
              );
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
            existing[idx] = exam;
          } else {
            existing.add(exam);
            indexById[sid] = existing.length - 1;
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

      await repo.saveExams(classId, existing);
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
  Future<void> deleteExamForStudent(String classId, String studentId) async {
    try {
      final repo = RepositoryFactory.instance;
      final existing = await repo.loadExams(classId);
      final before = existing.length;
      existing.removeWhere((e) => e.studentId == studentId);
      await repo.saveExams(classId, existing);
      _exams.removeWhere((e) => e.studentId == studentId);
      notifyListeners();
      debugPrint(
          'Deleted ${before - existing.length} exam entries for student $studentId');
    } catch (e) {
      debugPrint('Failed to delete exam for student $studentId: $e');
    }
  }

  /// Removes and returns the student's exam, to support undo.
  Future<FinalExam?> removeAndReturnExamForStudent(
      String classId, String studentId) async {
    try {
      final repo = RepositoryFactory.instance;
      final existing = await repo.loadExams(classId);
      final idx = existing.indexWhere((e) => e.studentId == studentId);
      if (idx == -1) return null;
      final removed = existing.removeAt(idx);
      await repo.saveExams(classId, existing);
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
  Future<void> restoreExam(String classId, FinalExam exam) async {
    try {
      final repo = RepositoryFactory.instance;
      final existing = await repo.loadExams(classId);
      existing.removeWhere((e) => e.studentId == exam.studentId);
      existing.add(exam);
      await repo.saveExams(classId, existing);
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

  Future<void> seedDemoExams(String classId, List<String> studentIds) async {
    try {
      final repo = RepositoryFactory.instance;
      final existing = await repo.loadExams(classId);

      final now = DateTime.now();
      for (var studentId in studentIds) {
        final exists = existing.any((e) => e.studentId == studentId);

        if (!exists) {
          final exam = FinalExam(
            studentId: studentId,
            examScore: 75.0 + (studentId.hashCode % 20).toDouble(),
            createdAt: now,
            updatedAt: now,
          );
          existing.add(exam);
        }
      }

      await repo.saveExams(classId, existing);
      debugPrint('Demo final exams seeded successfully');
    } catch (e) {
      debugPrint('Failed to seed demo exams: $e');
    }
  }
}

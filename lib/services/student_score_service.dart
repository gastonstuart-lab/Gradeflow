import 'package:flutter/foundation.dart';
import 'package:gradeflow/models/student_score.dart';
import 'package:gradeflow/models/change_history.dart';
import 'package:uuid/uuid.dart';
import 'dart:async';
import 'package:gradeflow/repositories/repository_factory.dart';

class StudentScoreService extends ChangeNotifier {
  List<StudentScore> _scores = [];
  List<ChangeHistory> _history = [];
  bool _isLoading = false;

  Future<void> _writeQueue = Future.value();
  int _pendingWrites = 0;

  List<StudentScore> get scores => _scores;
  bool get isLoading => _isLoading;
  bool get hasPendingWrites => _pendingWrites > 0;

  Future<void> flushPendingWrites() => _writeQueue;

  Future<T> _enqueueWrite<T>(Future<T> Function() fn) {
    _pendingWrites++;
    if (_pendingWrites == 1) notifyListeners();

    final completer = Completer<T>();

    _writeQueue = _writeQueue
        .then((_) async {
          try {
            final result = await fn();
            completer.complete(result);
          } catch (e, st) {
            completer.completeError(e, st);
          }
        })
        // Never let one failure break the queue
        .catchError((_) {})
        .whenComplete(() {
          _pendingWrites = (_pendingWrites - 1).clamp(0, 1 << 30);
          if (_pendingWrites == 0) notifyListeners();
        });

    return completer.future;
  }

  Future<void> loadScores(String classId, List<String> gradeItemIds) async {
    _isLoading = true;
    notifyListeners();

    try {
      final repo = RepositoryFactory.instance;
      final out = <StudentScore>[];
      for (final gid in gradeItemIds) {
        final list = await repo.loadScores(classId, gid);
        out.addAll(list);
      }
      _scores = out;
    } catch (e) {
      debugPrint('Failed to load scores: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateScore(
    StudentScore score,
    String teacherId,
    String classId, {
    bool recordHistory = true,
  }) async {
    await _enqueueWrite(() async => _updateScoreInternal(
          score,
          teacherId,
          classId,
          recordHistory: recordHistory,
        ));
  }

  Future<void> _updateScoreInternal(
    StudentScore score,
    String teacherId,
    String classId, {
    required bool recordHistory,
  }) async {
    try {
      final repo = RepositoryFactory.instance;
      final existing = await repo.loadScores(classId, score.gradeItemId);

      final idx = existing.indexWhere(
        (s) =>
            s.studentId == score.studentId &&
            s.gradeItemId == score.gradeItemId,
      );
      final oldScore = idx == -1 ? null : existing[idx].score;
      if (idx == -1) {
        existing.add(score);
      } else {
        existing[idx] = score;
      }

      await repo.saveScores(classId, score.gradeItemId, existing);
      if (recordHistory) {
        await _addHistory(
          classId,
          score.studentId,
          score.gradeItemId,
          oldScore,
          score.score,
          teacherId,
        );
      }

      final localIndex = _scores.indexWhere(
        (s) =>
            s.studentId == score.studentId &&
            s.gradeItemId == score.gradeItemId,
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

  Future<void> setAllScoresForGradeItem(String classId, String gradeItemId,
      List<String> studentIds, double? score, String teacherId) async {
    await _enqueueWrite(() async {
      try {
        final repo = RepositoryFactory.instance;
        final existing = await repo.loadScores(classId, gradeItemId);

        final now = DateTime.now();
        for (final studentId in studentIds) {
          final entry = StudentScore(
              studentId: studentId,
              gradeItemId: gradeItemId,
              score: score,
              createdAt: now,
              updatedAt: now);
          final idx = existing.indexWhere(
              (s) => s.studentId == studentId && s.gradeItemId == gradeItemId);
          final oldScore = idx == -1 ? null : existing[idx].score;
          if (idx == -1) {
            existing.add(entry);
          } else {
            existing[idx] = entry;
          }
          await _addHistory(
              classId, studentId, gradeItemId, oldScore, score, teacherId);

          final localIndex = _scores.indexWhere(
              (s) => s.studentId == studentId && s.gradeItemId == gradeItemId);
          if (localIndex != -1) {
            _scores[localIndex] = entry;
          } else {
            _scores.add(entry);
          }
        }

        await repo.saveScores(classId, gradeItemId, existing);
        notifyListeners();
        debugPrint(
            'Applied score ${score?.toStringAsFixed(0)} to ${studentIds.length} students for item=$gradeItemId');
      } catch (e) {
        debugPrint('Failed to apply score to all: $e');
      }
    });
  }

  Future<void> _addHistory(String classId, String studentId, String gradeItemId,
      double? oldScore, double? newScore, String teacherId) async {
    try {
      final change = ChangeHistory(
        changeId: const Uuid().v4(),
        studentId: studentId,
        gradeItemId: gradeItemId,
        classId: classId,
        oldScore: oldScore,
        newScore: newScore,
        teacherId: teacherId,
        timestamp: DateTime.now(),
      );

      final repo = RepositoryFactory.instance;
      await repo.addScoreHistory(classId, change, maxEntries: 100);
      _history.insert(0, change);

      if (_history.length > 100) {
        _history = _history.sublist(0, 100);
      }
    } catch (e) {
      debugPrint('Failed to add change history: $e');
    }
  }

  /// Delete all scores associated with a specific student across all grade items.
  Future<void> deleteScoresForStudent(
      String classId, String studentId, List<String> gradeItemIds) async {
    await _enqueueWrite(() async {
      try {
        final repo = RepositoryFactory.instance;
        for (final gid in gradeItemIds) {
          final existing = await repo.loadScores(classId, gid);
          existing.removeWhere((s) => s.studentId == studentId);
          await repo.saveScores(classId, gid, existing);
        }
        _scores.removeWhere((s) => s.studentId == studentId);
        notifyListeners();
      } catch (e) {
        debugPrint('Failed to delete scores for student $studentId: $e');
      }
    });
  }

  /// Removes and returns all scores for a student. Useful for implementing undo.
  Future<List<StudentScore>> removeAndReturnScoresForStudent(
      String classId, String studentId, List<String> gradeItemIds) async {
    return _enqueueWrite(() async {
      try {
        final repo = RepositoryFactory.instance;
        final removed = <StudentScore>[];

        for (final gid in gradeItemIds) {
          final existing = await repo.loadScores(classId, gid);
          final take = existing.where((s) => s.studentId == studentId).toList();
          if (take.isNotEmpty) {
            removed.addAll(take);
            existing.removeWhere((s) => s.studentId == studentId);
            await repo.saveScores(classId, gid, existing);
          }
        }

        if (removed.isEmpty) return <StudentScore>[];
        _scores.removeWhere((s) => s.studentId == studentId);
        notifyListeners();
        debugPrint(
            'Temporarily removed ${removed.length} scores for student $studentId');
        return removed;
      } catch (e) {
        debugPrint('Failed to remove and return scores for $studentId: $e');
        return <StudentScore>[];
      }
    });
  }

  /// Restores a list of scores back into storage without adding history entries.
  Future<void> restoreScoresForStudent(
      String classId, List<StudentScore> scoresToRestore) async {
    if (scoresToRestore.isEmpty) return;
    await _enqueueWrite(() async {
      try {
        final repo = RepositoryFactory.instance;
        final byItem = <String, List<StudentScore>>{};
        for (final sc in scoresToRestore) {
          byItem.putIfAbsent(sc.gradeItemId, () => []).add(sc);
        }

        for (final entry in byItem.entries) {
          final gid = entry.key;
          final existing = await repo.loadScores(classId, gid);
          for (final sc in entry.value) {
            final idx = existing.indexWhere((s) =>
                s.studentId == sc.studentId && s.gradeItemId == sc.gradeItemId);
            if (idx == -1) {
              existing.add(sc);
            } else {
              existing[idx] = sc;
            }
            final localIdx = _scores.indexWhere((s) =>
                s.studentId == sc.studentId && s.gradeItemId == sc.gradeItemId);
            if (localIdx != -1) {
              _scores[localIdx] = sc;
            } else {
              _scores.add(sc);
            }
          }
          await repo.saveScores(classId, gid, existing);
        }

        notifyListeners();
        debugPrint('Restored ${scoresToRestore.length} scores from undo');
      } catch (e) {
        debugPrint('Failed to restore scores: $e');
      }
    });
  }

  Future<bool> undoLastChange(String teacherId, String classId) async {
    return _enqueueWrite(() async {
      try {
        final repo = RepositoryFactory.instance;
        final latest = await repo.loadScoreHistory(classId, limit: 1);
        if (latest.isEmpty) return false;
        final lastChange = latest.first;
        if (lastChange.teacherId != teacherId) return false;

        final now = DateTime.now();
        final revertedScore = StudentScore(
          studentId: lastChange.studentId,
          gradeItemId: lastChange.gradeItemId,
          score: lastChange.oldScore,
          createdAt: now,
          updatedAt: now,
        );

        final effectiveClassId = lastChange.classId ?? classId;
        await _updateScoreInternal(
          revertedScore,
          teacherId,
          effectiveClassId,
          recordHistory: false,
        );

        await repo.deleteScoreHistoryEntry(
            effectiveClassId, lastChange.changeId);

        // Best-effort keep in-memory cache aligned.
        _history.removeWhere((h) => h.changeId == lastChange.changeId);

        return true;
      } catch (e) {
        debugPrint('Failed to undo last change: $e');
        return false;
      }
    });
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

  /// Ensures every student has a stored score entry for the given grade item.
  ///
  /// This supports the “default to 100 (full marks) until changed” behavior by
  /// creating missing `StudentScore` rows (and optionally filling null scores)
  /// without overwriting any existing non-null scores.
  Future<void> ensureDefaultScoresForGradeItem(
    String classId,
    String gradeItemId,
    List<String> studentIds,
    double defaultScore, {
    bool fillNulls = true,
  }) async {
    if (studentIds.isEmpty) return;
    await _enqueueWrite(() async {
      try {
        final repo = RepositoryFactory.instance;
        final existing = await repo.loadScores(classId, gradeItemId);
        final byStudent = <String, StudentScore>{
          for (final s in existing) s.studentId: s,
        };

        final now = DateTime.now();
        bool changed = false;

        for (final studentId in studentIds) {
          final cur = byStudent[studentId];
          if (cur == null) {
            final entry = StudentScore(
              studentId: studentId,
              gradeItemId: gradeItemId,
              score: defaultScore,
              createdAt: now,
              updatedAt: now,
            );
            existing.add(entry);
            byStudent[studentId] = entry;
            changed = true;

            final localIdx = _scores.indexWhere(
              (s) => s.studentId == studentId && s.gradeItemId == gradeItemId,
            );
            if (localIdx != -1) {
              _scores[localIdx] = entry;
            } else {
              _scores.add(entry);
            }
            continue;
          }

          if (fillNulls && cur.score == null) {
            final updated = StudentScore(
              studentId: cur.studentId,
              gradeItemId: cur.gradeItemId,
              score: defaultScore,
              createdAt: cur.createdAt,
              updatedAt: now,
            );
            final idx = existing.indexWhere(
              (s) => s.studentId == studentId && s.gradeItemId == gradeItemId,
            );
            if (idx != -1) existing[idx] = updated;
            byStudent[studentId] = updated;
            changed = true;

            final localIdx = _scores.indexWhere(
              (s) => s.studentId == studentId && s.gradeItemId == gradeItemId,
            );
            if (localIdx != -1) {
              _scores[localIdx] = updated;
            } else {
              _scores.add(updated);
            }
          }
        }

        if (changed) {
          await repo.saveScores(classId, gradeItemId, existing);
          notifyListeners();
          debugPrint(
              'Ensured default scores for item=$gradeItemId (${studentIds.length} students)');
        }
      } catch (e) {
        debugPrint('Failed to ensure default scores for $gradeItemId: $e');
      }
    });
  }

  Future<void> seedDemoScores(String classId, List<String> studentIds,
      List<String> gradeItemIds) async {
    await _enqueueWrite(() async {
      try {
        final repo = RepositoryFactory.instance;
        final now = DateTime.now();
        for (final gradeItemId in gradeItemIds) {
          final existing = await repo.loadScores(classId, gradeItemId);
          final existingStudentIds = existing.map((s) => s.studentId).toSet();

          bool changed = false;
          for (final studentId in studentIds) {
            if (existingStudentIds.contains(studentId)) continue;
            existing.add(
              StudentScore(
                studentId: studentId,
                gradeItemId: gradeItemId,
                score: 70.0 + (studentId.hashCode % 30).toDouble(),
                createdAt: now,
                updatedAt: now,
              ),
            );
            changed = true;
          }

          if (changed) {
            await repo.saveScores(classId, gradeItemId, existing);
          }
        }

        debugPrint('Demo scores seeded successfully');
      } catch (e) {
        debugPrint('Failed to seed demo scores: $e');
      }
    });
  }
}

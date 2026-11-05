import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:gradeflow/models/student.dart';
import 'package:gradeflow/models/student_score.dart';
import 'package:gradeflow/models/grade_item.dart';
import 'package:gradeflow/models/grading_category.dart';
import 'package:gradeflow/models/final_exam.dart';
import 'package:gradeflow/models/change_history.dart';
import 'package:gradeflow/repositories/data_repository.dart';
import 'package:uuid/uuid.dart';

enum GradebookSaveState { ready, saving, saved, failed, historyIncomplete }

/// Both the classroom quick editor and full-page editor use these existing
/// repository records. No alternate browser store or default score generation.
class GradebookWorkspace extends ChangeNotifier {
  GradebookWorkspace(this.repository, this.classId);
  final DataRepository repository;
  final String classId;
  List<Student> students = [];
  List<GradingCategory> categories = [];
  List<GradeItem> items = [];
  final Map<String, double?> values = {};
  List<FinalExam> exams = [];
  GradebookSaveState saveState = GradebookSaveState.ready;
  String? error;
  bool loaded = false;
  final List<Future<void> Function()> _undo = [];
  bool _undoing = false;
  bool get canUndo => _undo.isNotEmpty;
  Future<void> undoLastEdit() async {
    if(_undo.isEmpty)return;
    final action=_undo.removeLast();_undoing=true;
    try { await action(); } catch(_) { _undo.add(action); rethrow; }
    finally { _undoing=false;_notify(); }
  }
  bool _disposed = false;
  static Future<void> _tail = Future.value();
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  String key(String student, String item) => '$student::$item';
  double? score(String student, String item) => values[key(student, item)];
  List<GradeItem> categoryItems(String category) => items
      .where(
        (i) =>
            i.categoryId == category &&
            i.isActive &&
            i.name.toLowerCase() != 'category total',
      )
      .toList();

  Future<void> load() async {
    final roster = await repository.loadStudents(classId);
    final cats = await repository.loadCategories(classId);
    final assessments = await repository.loadGradeItems(classId);
    final marks = <String, double?>{};
    for (final item in assessments.where((i) => i.isActive)) {
      for (final s in await repository.loadScores(classId, item.gradeItemId)) {
        if (roster.any((r) => r.studentId == s.studentId))
          marks[key(s.studentId, item.gradeItemId)] = s.score;
      }
    }
    exams = await repository.loadExams(classId);
    students = roster.where((s) => s.classId == classId).toList();
    categories = cats.where((c) => c.classId == classId && c.isActive).toList();
    items =
        assessments.where((i) => i.classId == classId && i.isActive).toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    values
      ..clear()
      ..addAll(marks);
    loaded = true;
    _notify();
  }

  static const processWeights = {
    'Participation': .2,
    'Homework': .3,
    'Quizzes': .3,
    'Classwork': .2,
  };
  static String canonical(String name) {
    final n = name.toLowerCase();
    if (n.contains('quiz')) return 'Quizzes';
    for (final k in ['Participation', 'Homework', 'Classwork']) {
      if (n.contains(k.toLowerCase())) return k;
    }
    return name;
  }

  double? average(String student, String category) {
    final list = categoryItems(category);
    if (list.isEmpty ||
        list.any(
          (i) => i.maxScore <= 0 || score(student, i.gradeItemId) == null,
        ))
      return null;
    return list.fold<double>(
          0,
          (n, i) => n + score(student, i.gradeItemId)! / i.maxScore * 100,
        ) /
        list.length;
  }

  double? process(String student) {
    if (!policyMatches) return null;
    double result = 0;
    for (final entry in processWeights.entries) {
      final matches = categories
          .where((c) => canonical(c.name) == entry.key)
          .toList();
      if (matches.length != 1 ||
          matches.single.aggregationMethod != AggregationMethod.average)
        return null;
      final value = average(student, matches.single.categoryId);
      if (value == null) return null;
      result += value * entry.value;
    }
    return result;
  }

  double? exam(String student) =>
      exams.where((e) => e.studentId == student).firstOrNull?.examScore;

  bool get policyMatches => categories.length == 4 && processWeights.entries.every((e) {
    final found = categories.where((c) => canonical(c.name) == e.key).toList();
    return found.length == 1 && found.single.aggregationMethod == AggregationMethod.average && (found.single.weightPercent-e.value*100).abs()<.001;
  });
  double? finalGrade(String student) {
    final p = process(student), e = exam(student);
    return p == null || e == null ? null : p * .4 + e * .6;
  }

  Future<T> _write<T>(Future<T> Function() task) {
    final completer = Completer<T>();
    saveState = GradebookSaveState.saving;
    error = null;
    _notify();
    _tail = _tail.then((_) async {
      try {
        final result = await task();
        if (saveState != GradebookSaveState.historyIncomplete)
          saveState = GradebookSaveState.saved;
        completer.complete(result);
      } catch (e, st) {
        saveState = GradebookSaveState.failed;
        error = e.toString();
        completer.completeError(e, st);
      } finally {
        _notify();
      }
    });
    return completer.future;
  }

  void _student(String id) {
    if (!students.any((s) => s.studentId == id))
      throw StateError('Student is not in this class.');
  }

  Future<void> saveScore(
    String student,
    GradeItem item,
    double? value,
    String teacher,
  ) => _write(() async {
    _student(student);
    if (item.classId != classId ||
        !items.any((i) => i.gradeItemId == item.gradeItemId))
      throw StateError('Assessment is not in this class.');
    if (value != null &&
        (!value.isFinite || value < 0 || value > item.maxScore))
      throw ArgumentError('Score must be between 0 and ${item.maxScore}.');
    final existing = await repository.loadScores(classId, item.gradeItemId);
    final old = existing.where((s) => s.studentId == student).firstOrNull;
    if (old?.score == value) return;
    final now = DateTime.now();
    final next = StudentScore(
      studentId: student,
      gradeItemId: item.gradeItemId,
      score: value,
      createdAt: old?.createdAt ?? now,
      updatedAt: now,
    );
    final updated = existing.where((s) => s.studentId != student).toList()
      ..add(next);
    await repository.saveScores(classId, item.gradeItemId, updated);
        if(!_undoing) _undo.add(()=>saveScore(student,item,old?.score,teacher));
    values[key(student, item.gradeItemId)] = value;
    try {
      await repository.addScoreHistory(
        classId,
        ChangeHistory(
          changeId: const Uuid().v4(),
          classId: classId,
          studentId: student,
          gradeItemId: item.gradeItemId,
          oldScore: old?.score,
          newScore: value,
          teacherId: teacher,
          timestamp: now,
        ),
        maxEntries: 100,
      );
    } catch (e) {
      saveState = GradebookSaveState.historyIncomplete;
      error = 'Score saved; change history was not saved. $e';
    }
  });
  Future<void> saveExam(String student, double? value) => _write(() async {
    _student(student);
    if (value != null && (!value.isFinite || value < 0 || value > 100))
      throw ArgumentError('Exam must be between 0 and 100.');
    final existing = await repository.loadExams(classId);
        final oldValue=existing.where((e)=>e.studentId==student).firstOrNull?.examScore;
    final now = DateTime.now();
    final next = existing.where((e) => e.studentId != student).toList()
      ..add(
        FinalExam(
          studentId: student,
          examScore: value,
          createdAt: now,
          updatedAt: now,
        ),
      );
    await repository.saveExams(classId, next);
        if(!_undoing) _undo.add(()=>saveExam(student,oldValue));
    exams = next;
  });
  Future<void> addAssessment(String category, String name, double maxScore) =>
      _write(() async {
        if (!categories.any((c) => c.categoryId == category) ||
            name.trim().isEmpty ||
            !maxScore.isFinite ||
            maxScore <= 0)
          throw ArgumentError('Enter a name and a positive maximum score.');
        final now = DateTime.now();
        final item = GradeItem(
          gradeItemId: const Uuid().v4(),
          classId: classId,
          categoryId: category,
          name: name.trim(),
          maxScore: maxScore,
          isActive: true,
          createdAt: now,
          updatedAt: now,
        );
        final existing = await repository.loadGradeItems(classId);
        await repository.saveGradeItems(classId, [...existing, item]);
        items.add(item);
      });

  /// Explicit setup, never a side effect of opening a class.
  Future<void> setUpCategories() => _write(() async {
    final existing = await repository.loadCategories(classId);
    final active=existing.where((c)=>c.isActive).toList();
    if(active.isNotEmpty) {
      if(active.length!=4 || !processWeights.keys.every((k)=>active.where((c)=>canonical(c.name)==k && c.aggregationMethod==AggregationMethod.average).length==1)) throw StateError('Existing categories need review; no policy was changed.');
      final next=existing.map((c)=>c.isActive?c.copyWith(weightPercent:processWeights[canonical(c.name)]!*100,updatedAt:DateTime.now()):c).toList();
      await repository.saveCategories(classId,next);
      categories=next.where((c)=>c.isActive).toList();
      return;
    }
    final now = DateTime.now();
    final next = processWeights.entries
        .map(
          (e) => GradingCategory(
            categoryId: const Uuid().v4(),
            classId: classId,
            name: e.key,
            weightPercent: e.value * 100,
            aggregationMethod: AggregationMethod.average,
            isActive: true,
            createdAt: now,
            updatedAt: now,
          ),
        )
        .toList();
    await repository.saveCategories(classId, [...existing, ...next]);
    categories = next;
  });
}

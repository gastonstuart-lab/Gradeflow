import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:gradeflow/repositories/data_repository.dart';
import 'package:gradeflow/models/student.dart';
import 'package:gradeflow/models/class.dart';
import 'package:gradeflow/models/grade_item.dart';
import 'package:gradeflow/models/student_score.dart';
import 'package:gradeflow/models/final_exam.dart';
import 'package:gradeflow/models/change_history.dart';
import 'package:gradeflow/models/grading_category.dart';
import 'package:gradeflow/models/grading_template.dart';

/// Local-only implementation using SharedPreferences.
/// This is the current storage backend - all existing services will migrate to this.
class LocalRepository implements DataRepository {
  static const String _classesKey = 'classes';
  // Legacy keys used by the original services (global lists)
  static const String _legacyStudentsKey = 'students';
  static const String _legacyGradeItemsKey = 'grade_items';
  static const String _legacyScoresKey = 'student_scores';
  static const String _legacyExamsKey = 'final_exams';
  static const String _legacyCategoriesKey = 'grading_categories';
  static const String _legacyHistoryKey = 'change_history';

  static const String _studentsKeyPrefix = 'students_';
  static const String _gradeItemsKeyPrefix = 'grade_items_';
  static const String _scoresKeyPrefix = 'scores_';
  static const String _examsKeyPrefix = 'exams_';
  static const String _categoriesKeyPrefix = 'categories_';
  static const String _historyKeyPrefix = 'change_history_';
  static const String _templatesKey = 'grading_templates';
  
  // Write queue to serialize SharedPreferences operations
  final List<Future<void> Function()> _writeQueue = [];
  final Set<Future<void>> _pendingWrites = {};
  
  Future<void> _enqueueWrite(Future<void> Function() operation) async {
    _writeQueue.add(operation);
    if (_writeQueue.length == 1) {
      await _processQueue();
    }
  }
  
  Future<void> _processQueue() async {
    while (_writeQueue.isNotEmpty) {
      final operation = _writeQueue.removeAt(0);
      final future = operation();
      _pendingWrites.add(future);
      try {
        await future;
      } finally {
        _pendingWrites.remove(future);
      }
    }
  }
  
  @override
  Future<bool> hasPendingWrites() async {
    return _pendingWrites.isNotEmpty || _writeQueue.isNotEmpty;
  }
  
  @override
  Future<void> flushPendingWrites() async {
    await _processQueue();
    await Future.wait(_pendingWrites.toList());
  }
  
  // Students
  @override
  Future<List<Student>> loadStudents(String classId) async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString('$_studentsKeyPrefix$classId');
    if (data != null) {
      final List<dynamic> jsonList = json.decode(data);
      return jsonList.map((json) => Student.fromJson(json)).toList();
    }

    // Legacy fallback: a single global list under 'students'
    final legacy = prefs.getString(_legacyStudentsKey);
    if (legacy == null) return [];
    final List<dynamic> list = json.decode(legacy);
    return list
        .map((e) => Student.fromJson(e as Map<String, dynamic>))
        .where((s) => s.classId == classId)
        .toList();
  }
  
  @override
  Future<void> saveStudents(String classId, List<Student> students) async {
    await _enqueueWrite(() async {
      final prefs = await SharedPreferences.getInstance();
      final String data = json.encode(students.map((s) => s.toJson()).toList());
      await prefs.setString('$_studentsKeyPrefix$classId', data);
    });
  }
  
  @override
  Future<void> deleteStudent(String classId, String studentId) async {
    final students = await loadStudents(classId);
    students.removeWhere((s) => s.studentId == studentId);
    await saveStudents(classId, students);
  }
  
  // Classes
  @override
  Future<List<Class>> loadClasses() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_classesKey);
    if (data == null) return [];
    final List<dynamic> jsonList = json.decode(data);
    return jsonList.map((json) => Class.fromJson(json)).toList();
  }
  
  @override
  Future<void> saveClasses(List<Class> classes) async {
    await _enqueueWrite(() async {
      final prefs = await SharedPreferences.getInstance();
      final String data = json.encode(classes.map((c) => c.toJson()).toList());
      await prefs.setString(_classesKey, data);
    });
  }
  
  @override
  Future<void> deleteClass(String classId) async {
    final classes = await loadClasses();
    classes.removeWhere((c) => c.classId == classId);
    await saveClasses(classes);
    
    // Clean up related data
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_studentsKeyPrefix$classId');
    await prefs.remove('$_gradeItemsKeyPrefix$classId');
    await prefs.remove('$_examsKeyPrefix$classId');
    await prefs.remove('$_categoriesKeyPrefix$classId');
  }
  
  // Grade Items
  @override
  Future<List<GradeItem>> loadGradeItems(String classId) async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString('$_gradeItemsKeyPrefix$classId');
    if (data != null) {
      final List<dynamic> jsonList = json.decode(data);
      return jsonList.map((json) => GradeItem.fromJson(json)).toList();
    }

    // Legacy fallback: a single global list under 'grade_items'
    final legacy = prefs.getString(_legacyGradeItemsKey);
    if (legacy == null) return [];
    final List<dynamic> list = json.decode(legacy);
    return list
        .map((e) => GradeItem.fromJson(e as Map<String, dynamic>))
        .where((g) => g.classId == classId)
        .toList();
  }
  
  @override
  Future<void> saveGradeItems(String classId, List<GradeItem> items) async {
    await _enqueueWrite(() async {
      final prefs = await SharedPreferences.getInstance();
      final String data = json.encode(items.map((i) => i.toJson()).toList());
      await prefs.setString('$_gradeItemsKeyPrefix$classId', data);
    });
  }
  
  @override
  Future<void> deleteGradeItem(String classId, String itemId) async {
    final items = await loadGradeItems(classId);
    items.removeWhere((i) => i.gradeItemId == itemId);
    await saveGradeItems(classId, items);
  }
  
  // Student Scores
  @override
  Future<List<StudentScore>> loadScores(String classId, String gradeItemId) async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString('$_scoresKeyPrefix${classId}_$gradeItemId');
    if (data != null) {
      final List<dynamic> jsonList = json.decode(data);
      return jsonList.map((json) => StudentScore.fromJson(json)).toList();
    }

    // Legacy fallback: a single global list under 'student_scores'
    final legacy = prefs.getString(_legacyScoresKey);
    if (legacy == null) return [];
    final List<dynamic> list = json.decode(legacy);
    return list
        .map((e) => StudentScore.fromJson(e as Map<String, dynamic>))
        .where((s) => s.gradeItemId == gradeItemId)
        .toList();
  }
  
  @override
  Future<void> saveScores(String classId, String gradeItemId, List<StudentScore> scores) async {
    await _enqueueWrite(() async {
      final prefs = await SharedPreferences.getInstance();
      final String data = json.encode(scores.map((s) => s.toJson()).toList());
      await prefs.setString('$_scoresKeyPrefix${classId}_$gradeItemId', data);
    });
  }

  // Score Change History (Undo)
  @override
  Future<List<ChangeHistory>> loadScoreHistory(String classId, {int limit = 100}) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('$_historyKeyPrefix$classId');
    if (data != null) {
      final List<dynamic> jsonList = json.decode(data);
      final out = jsonList.map((e) => ChangeHistory.fromJson(e as Map<String, dynamic>)).toList();
      return out.reversed.take(limit).toList().reversed.toList();
    }

    // Legacy fallback: a single global list under 'change_history'
    final legacy = prefs.getString(_legacyHistoryKey);
    if (legacy == null) return [];
    final List<dynamic> list = json.decode(legacy);
    final out = list
        .map((e) => ChangeHistory.fromJson(e as Map<String, dynamic>))
        .where((h) => h.classId == null || h.classId == classId)
        .toList();

    // Keep only the newest `limit` items.
    out.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return out.take(limit).toList();
  }

  @override
  Future<void> addScoreHistory(String classId, ChangeHistory entry, {int maxEntries = 100}) async {
    await _enqueueWrite(() async {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_historyKeyPrefix$classId';
      final existing = prefs.getString(key);
      List<Map<String, dynamic>> list = [];
      if (existing != null) {
        list = (json.decode(existing) as List).cast<Map<String, dynamic>>();
      }
      list.add(entry.toJson());
      if (list.length > maxEntries) {
        list = list.sublist(list.length - maxEntries);
      }
      await prefs.setString(key, json.encode(list));
    });
  }

  @override
  Future<void> deleteScoreHistoryEntry(String classId, String changeId) async {
    await _enqueueWrite(() async {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_historyKeyPrefix$classId';
      final existing = prefs.getString(key);
      if (existing == null) return;
      List<Map<String, dynamic>> list = (json.decode(existing) as List).cast<Map<String, dynamic>>();
      list.removeWhere((e) => e['changeId'] == changeId);
      await prefs.setString(key, json.encode(list));
    });
  }
  
  // Final Exams
  @override
  Future<List<FinalExam>> loadExams(String classId) async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString('$_examsKeyPrefix$classId');
    if (data != null) {
      final List<dynamic> jsonList = json.decode(data);
      return jsonList.map((json) => FinalExam.fromJson(json)).toList();
    }

    // Legacy fallback: a single global list under 'final_exams'
    final legacy = prefs.getString(_legacyExamsKey);
    if (legacy == null) return [];

    // To map exams to a class, filter by the class roster.
    final students = await loadStudents(classId);
    final studentIds = students.map((s) => s.studentId).toSet();
    final List<dynamic> list = json.decode(legacy);
    return list
        .map((e) => FinalExam.fromJson(e as Map<String, dynamic>))
        .where((e) => studentIds.contains(e.studentId))
        .toList();
  }
  
  @override
  Future<void> saveExams(String classId, List<FinalExam> exams) async {
    await _enqueueWrite(() async {
      final prefs = await SharedPreferences.getInstance();
      final String data = json.encode(exams.map((e) => e.toJson()).toList());
      await prefs.setString('$_examsKeyPrefix$classId', data);
    });
  }
  
  // Grading Categories
  @override
  Future<List<GradingCategory>> loadCategories(String classId) async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString('$_categoriesKeyPrefix$classId');
    if (data != null) {
      final List<dynamic> jsonList = json.decode(data);
      return jsonList.map((json) => GradingCategory.fromJson(json)).toList();
    }

    // Legacy fallback: a single global list under 'grading_categories'
    final legacy = prefs.getString(_legacyCategoriesKey);
    if (legacy == null) return [];
    final List<dynamic> list = json.decode(legacy);
    return list
        .map((e) => GradingCategory.fromJson(e as Map<String, dynamic>))
        .where((c) => c.classId == classId)
        .toList();
  }
  
  @override
  Future<void> saveCategories(String classId, List<GradingCategory> categories) async {
    await _enqueueWrite(() async {
      final prefs = await SharedPreferences.getInstance();
      final String data = json.encode(categories.map((c) => c.toJson()).toList());
      await prefs.setString('$_categoriesKeyPrefix$classId', data);
    });
  }
  
  // Grading Templates
  @override
  Future<List<GradingTemplate>> loadTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_templatesKey);
    if (data == null) return [];
    final List<dynamic> jsonList = json.decode(data);
    return jsonList.map((json) => GradingTemplate.fromJson(json)).toList();
  }
  
  @override
  Future<void> saveTemplates(List<GradingTemplate> templates) async {
    await _enqueueWrite(() async {
      final prefs = await SharedPreferences.getInstance();
      final String data = json.encode(templates.map((t) => t.toJson()).toList());
      await prefs.setString(_templatesKey, data);
    });
  }
  
  // Utility
  @override
  Future<void> clearAll() async {
    await _enqueueWrite(() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    });
  }
}

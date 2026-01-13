import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gradeflow/repositories/data_repository.dart';
import 'package:gradeflow/models/student.dart';
import 'package:gradeflow/models/class.dart';
import 'package:gradeflow/models/grade_item.dart';
import 'package:gradeflow/models/student_score.dart';
import 'package:gradeflow/models/final_exam.dart';
import 'package:gradeflow/models/change_history.dart';
import 'package:gradeflow/models/grading_category.dart';
import 'package:gradeflow/models/grading_template.dart';

/// Cloud-based implementation using Cloud Firestore.
/// Provides real-time sync and multi-device access.
class FirestoreRepository implements DataRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String userId;
  
  FirestoreRepository({required this.userId});
  
  // Collection paths
  String get _classesPath => 'users/$userId/classes';
  String _studentsPath(String classId) => '$_classesPath/$classId/students';
  String _gradeItemsPath(String classId) => '$_classesPath/$classId/gradeItems';
  String _scoresPath(String classId, String gradeItemId) => '$_classesPath/$classId/gradeItems/$gradeItemId/scores';
  String _scoreHistoryPath(String classId) => '$_classesPath/$classId/scoreHistory';
  String _examsPath(String classId) => '$_classesPath/$classId/exams';
  String _categoriesPath(String classId) => '$_classesPath/$classId/categories';
  String get _templatesPath => 'users/$userId/templates';
  
  @override
  Future<bool> hasPendingWrites() async {
    // Firestore writes are queued automatically
    await _firestore.waitForPendingWrites();
    return false;
  }
  
  @override
  Future<void> flushPendingWrites() async {
    await _firestore.waitForPendingWrites();
  }
  
  // Students
  @override
  Future<List<Student>> loadStudents(String classId) async {
    final snapshot = await _firestore.collection(_studentsPath(classId)).get();
    return snapshot.docs.map((doc) => Student.fromJson(doc.data())).toList();
  }
  
  @override
  Future<void> saveStudents(String classId, List<Student> students) async {
    final batch = _firestore.batch();
    final collection = _firestore.collection(_studentsPath(classId));
    
    for (final student in students) {
      batch.set(collection.doc(student.studentId), student.toJson());
    }
    
    await batch.commit();
  }
  
  @override
  Future<void> deleteStudent(String classId, String studentId) async {
    await _firestore.collection(_studentsPath(classId)).doc(studentId).delete();
  }
  
  // Classes
  @override
  Future<List<Class>> loadClasses() async {
    final snapshot = await _firestore.collection(_classesPath).get();
    return snapshot.docs.map((doc) => Class.fromJson(doc.data())).toList();
  }
  
  @override
  Future<void> saveClasses(List<Class> classes) async {
    final batch = _firestore.batch();
    final collection = _firestore.collection(_classesPath);
    
    for (final cls in classes) {
      batch.set(collection.doc(cls.classId), cls.toJson());
    }
    
    await batch.commit();
  }
  
  @override
  Future<void> deleteClass(String classId) async {
    // Delete class document and all subcollections
    await _firestore.collection(_classesPath).doc(classId).delete();
    // Note: Firestore subcollections are not auto-deleted; would need a Cloud Function for full cleanup
  }
  
  // Grade Items
  @override
  Future<List<GradeItem>> loadGradeItems(String classId) async {
    final snapshot = await _firestore.collection(_gradeItemsPath(classId)).get();
    return snapshot.docs.map((doc) => GradeItem.fromJson(doc.data())).toList();
  }
  
  @override
  Future<void> saveGradeItems(String classId, List<GradeItem> items) async {
    final batch = _firestore.batch();
    final collection = _firestore.collection(_gradeItemsPath(classId));
    
    for (final item in items) {
      batch.set(collection.doc(item.gradeItemId), item.toJson());
    }
    
    await batch.commit();
  }
  
  @override
  Future<void> deleteGradeItem(String classId, String itemId) async {
    await _firestore.collection(_gradeItemsPath(classId)).doc(itemId).delete();
  }
  
  // Student Scores
  @override
  Future<List<StudentScore>> loadScores(String classId, String gradeItemId) async {
    final snapshot = await _firestore.collection(_scoresPath(classId, gradeItemId)).get();
    return snapshot.docs.map((doc) => StudentScore.fromJson(doc.data())).toList();
  }
  
  @override
  Future<void> saveScores(String classId, String gradeItemId, List<StudentScore> scores) async {
    final batch = _firestore.batch();
    final collection = _firestore.collection(_scoresPath(classId, gradeItemId));
    
    for (final score in scores) {
      batch.set(collection.doc(score.studentId), score.toJson());
    }
    
    await batch.commit();
  }

  // Score Change History (Undo)
  @override
  Future<List<ChangeHistory>> loadScoreHistory(String classId, {int limit = 100}) async {
    final query = _firestore
        .collection(_scoreHistoryPath(classId))
        .orderBy('timestamp', descending: true)
        .limit(limit);
    final snapshot = await query.get();
    return snapshot.docs.map((doc) => ChangeHistory.fromJson(doc.data())).toList();
  }

  @override
  Future<void> addScoreHistory(String classId, ChangeHistory entry, {int maxEntries = 100}) async {
    await _firestore.collection(_scoreHistoryPath(classId)).doc(entry.changeId).set(entry.toJson());

    // Best-effort trimming (non-atomic): delete anything beyond maxEntries.
    try {
      final snapshot = await _firestore
          .collection(_scoreHistoryPath(classId))
          .orderBy('timestamp', descending: true)
          .limit(maxEntries + 25)
          .get();
      if (snapshot.docs.length <= maxEntries) return;
      final batch = _firestore.batch();
      for (final doc in snapshot.docs.sublist(maxEntries)) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (_) {
      // Ignore trim failures; history will self-heal on next add.
    }
  }

  @override
  Future<void> deleteScoreHistoryEntry(String classId, String changeId) async {
    await _firestore.collection(_scoreHistoryPath(classId)).doc(changeId).delete();
  }
  
  // Final Exams
  @override
  Future<List<FinalExam>> loadExams(String classId) async {
    final snapshot = await _firestore.collection(_examsPath(classId)).get();
    return snapshot.docs.map((doc) => FinalExam.fromJson(doc.data())).toList();
  }
  
  @override
  Future<void> saveExams(String classId, List<FinalExam> exams) async {
    final batch = _firestore.batch();
    final collection = _firestore.collection(_examsPath(classId));
    
    for (final exam in exams) {
      batch.set(collection.doc(exam.studentId), exam.toJson());
    }
    
    await batch.commit();
  }
  
  // Grading Categories
  @override
  Future<List<GradingCategory>> loadCategories(String classId) async {
    final snapshot = await _firestore.collection(_categoriesPath(classId)).get();
    return snapshot.docs.map((doc) => GradingCategory.fromJson(doc.data())).toList();
  }
  
  @override
  Future<void> saveCategories(String classId, List<GradingCategory> categories) async {
    final batch = _firestore.batch();
    final collection = _firestore.collection(_categoriesPath(classId));
    
    for (final category in categories) {
      batch.set(collection.doc(category.categoryId), category.toJson());
    }
    
    await batch.commit();
  }
  
  // Grading Templates
  @override
  Future<List<GradingTemplate>> loadTemplates() async {
    final snapshot = await _firestore.collection(_templatesPath).get();
    return snapshot.docs.map((doc) => GradingTemplate.fromJson(doc.data())).toList();
  }
  
  @override
  Future<void> saveTemplates(List<GradingTemplate> templates) async {
    final batch = _firestore.batch();
    final collection = _firestore.collection(_templatesPath);
    
    for (final template in templates) {
      batch.set(collection.doc(template.templateId), template.toJson());
    }
    
    await batch.commit();
  }
  
  // Utility
  @override
  Future<void> clearAll() async {
    // Firestore doesn't support clearing all data client-side
    // This would require a Cloud Function or manual collection deletion
    throw UnimplementedError('clearAll not supported in Firestore - use Firebase Console');
  }
}

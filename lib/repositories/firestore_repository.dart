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
import 'package:gradeflow/models/room_setup.dart';
import 'package:gradeflow/models/seating_layout.dart';

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
  String _scoresPath(String classId, String gradeItemId) =>
      '$_classesPath/$classId/gradeItems/$gradeItemId/scores';
  String _scoreHistoryPath(String classId) =>
      '$_classesPath/$classId/scoreHistory';
  String _examsPath(String classId) => '$_classesPath/$classId/exams';
  String _categoriesPath(String classId) => '$_classesPath/$classId/categories';
  String get _templatesPath => 'users/$userId/templates';
  String get _roomSetupsPath => 'users/$userId/roomSetups';
  String _seatingLayoutsPath(String classId) =>
      '$_classesPath/$classId/seatingLayouts';
  String _seatingMetaPath(String classId) =>
      '$_classesPath/$classId/seatingMeta';

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
    await _deleteFlatCollection(_studentsPath(classId));
    await _deleteGradeItemsWithScores(classId);
    await _deleteFlatCollection(_scoreHistoryPath(classId));
    await _deleteFlatCollection(_examsPath(classId));
    await _deleteFlatCollection(_categoriesPath(classId));
    await _deleteFlatCollection(_seatingLayoutsPath(classId));
    await _deleteFlatCollection(_seatingMetaPath(classId));
    await _firestore.collection(_classesPath).doc(classId).delete();
  }

  // Grade Items
  @override
  Future<List<GradeItem>> loadGradeItems(String classId) async {
    final snapshot =
        await _firestore.collection(_gradeItemsPath(classId)).get();
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
  Future<List<StudentScore>> loadScores(
      String classId, String gradeItemId) async {
    final snapshot =
        await _firestore.collection(_scoresPath(classId, gradeItemId)).get();
    return snapshot.docs
        .map((doc) => StudentScore.fromJson(doc.data()))
        .toList();
  }

  @override
  Future<void> saveScores(
      String classId, String gradeItemId, List<StudentScore> scores) async {
    final batch = _firestore.batch();
    final collection = _firestore.collection(_scoresPath(classId, gradeItemId));

    for (final score in scores) {
      batch.set(collection.doc(score.studentId), score.toJson());
    }

    await batch.commit();
  }

  // Score Change History (Undo)
  @override
  Future<List<ChangeHistory>> loadScoreHistory(String classId,
      {int limit = 100}) async {
    final query = _firestore
        .collection(_scoreHistoryPath(classId))
        .orderBy('timestamp', descending: true)
        .limit(limit);
    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => ChangeHistory.fromJson(doc.data()))
        .toList();
  }

  @override
  Future<void> addScoreHistory(String classId, ChangeHistory entry,
      {int maxEntries = 100}) async {
    await _firestore
        .collection(_scoreHistoryPath(classId))
        .doc(entry.changeId)
        .set(entry.toJson());

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
    await _firestore
        .collection(_scoreHistoryPath(classId))
        .doc(changeId)
        .delete();
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
    final snapshot =
        await _firestore.collection(_categoriesPath(classId)).get();
    return snapshot.docs
        .map((doc) => GradingCategory.fromJson(doc.data()))
        .toList();
  }

  @override
  Future<void> saveCategories(
      String classId, List<GradingCategory> categories) async {
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
    return snapshot.docs
        .map((doc) => GradingTemplate.fromJson(doc.data()))
        .toList();
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

  // Seating Layouts
  @override
  Future<List<SeatingLayout>> loadSeatingLayouts(String classId) async {
    final snapshot =
        await _firestore.collection(_seatingLayoutsPath(classId)).get();
    return snapshot.docs
        .map((doc) => SeatingLayout.fromJson(doc.data()))
        .toList();
  }

  @override
  Future<void> saveSeatingLayouts(
      String classId, List<SeatingLayout> layouts) async {
    final batch = _firestore.batch();
    final collection = _firestore.collection(_seatingLayoutsPath(classId));
    for (final layout in layouts) {
      batch.set(collection.doc(layout.layoutId), layout.toJson());
    }
    await batch.commit();
  }

  @override
  Future<void> deleteSeatingLayout(String classId, String layoutId) async {
    await _firestore
        .collection(_seatingLayoutsPath(classId))
        .doc(layoutId)
        .delete();
  }

  @override
  Future<String?> loadActiveSeatingLayoutId(String classId) async {
    final doc = await _firestore
        .collection(_seatingMetaPath(classId))
        .doc('default')
        .get();
    final data = doc.data();
    return data == null ? null : data['activeLayoutId'] as String?;
  }

  @override
  Future<void> saveActiveSeatingLayoutId(
      String classId, String layoutId) async {
    await _firestore
        .collection(_seatingMetaPath(classId))
        .doc('default')
        .set({'activeLayoutId': layoutId}, SetOptions(merge: true));
  }

  @override
  Future<String?> loadAssignedRoomSetupId(String classId) async {
    final doc = await _firestore
        .collection(_seatingMetaPath(classId))
        .doc('default')
        .get();
    final data = doc.data();
    return data == null ? null : data['roomSetupId'] as String?;
  }

  @override
  Future<void> saveAssignedRoomSetupId(
      String classId, String? roomSetupId) async {
    await _firestore
        .collection(_seatingMetaPath(classId))
        .doc('default')
        .set({'roomSetupId': roomSetupId}, SetOptions(merge: true));
  }

  @override
  Future<List<RoomSetup>> loadRoomSetups() async {
    final snapshot = await _firestore.collection(_roomSetupsPath).get();
    return snapshot.docs.map((doc) => RoomSetup.fromJson(doc.data())).toList();
  }

  @override
  Future<void> saveRoomSetups(List<RoomSetup> roomSetups) async {
    final batch = _firestore.batch();
    final collection = _firestore.collection(_roomSetupsPath);
    for (final roomSetup in roomSetups) {
      batch.set(collection.doc(roomSetup.roomSetupId), roomSetup.toJson());
    }
    await batch.commit();
  }

  @override
  Future<void> deleteRoomSetup(String roomSetupId) async {
    await _firestore.collection(_roomSetupsPath).doc(roomSetupId).delete();
  }

  // Utility
  @override
  Future<void> clearAll() async {
    // Firestore doesn't support clearing all data client-side
    // This would require a Cloud Function or manual collection deletion
    throw UnimplementedError(
        'clearAll not supported in Firestore - use Firebase Console');
  }

  Future<void> _deleteFlatCollection(String path) async {
    final snapshot = await _firestore.collection(path).get();
    if (snapshot.docs.isEmpty) return;
    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  Future<void> _deleteGradeItemsWithScores(String classId) async {
    final gradeItems =
        await _firestore.collection(_gradeItemsPath(classId)).get();
    for (final item in gradeItems.docs) {
      final scores = await item.reference.collection('scores').get();
      final batch = _firestore.batch();
      for (final score in scores.docs) {
        batch.delete(score.reference);
      }
      batch.delete(item.reference);
      await batch.commit();
    }
  }
}

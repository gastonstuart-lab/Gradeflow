import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gradeflow/repositories/local_repository.dart';
import 'package:gradeflow/repositories/firestore_repository.dart';

/// One-time migration of local SharedPreferences data into Firestore.
///
/// This is intentionally conservative:
/// - Only runs when local has data AND Firestore is empty for this user.
/// - Uses a per-user flag so it won't repeat.
class MigrationService {
  static String _flagKey(String userId) => 'migrated_to_firestore_$userId';

  static Future<void> maybeMigrateLocalToFirestore({required String userId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final already = prefs.getBool(_flagKey(userId)) ?? false;
      if (already) return;

      final local = LocalRepository();
      final remote = FirestoreRepository(userId: userId);

      final localClasses = await local.loadClasses();
      if (localClasses.isEmpty) return;

      final remoteClasses = await remote.loadClasses();
      if (remoteClasses.isNotEmpty) {
        await prefs.setBool(_flagKey(userId), true);
        return;
      }

      final now = DateTime.now();
      final classesForUser = localClasses
          .map((c) => c.copyWith(teacherId: userId, updatedAt: now))
          .toList();

      await remote.saveClasses(classesForUser);

      for (final cls in classesForUser) {
        final classId = cls.classId;

        final students = await local.loadStudents(classId);
        if (students.isNotEmpty) {
          await remote.saveStudents(classId, students);
        }

        final categories = await local.loadCategories(classId);
        if (categories.isNotEmpty) {
          await remote.saveCategories(classId, categories);
        }

        final items = await local.loadGradeItems(classId);
        if (items.isNotEmpty) {
          await remote.saveGradeItems(classId, items);
        }

        for (final item in items) {
          final scores = await local.loadScores(classId, item.gradeItemId);
          if (scores.isNotEmpty) {
            await remote.saveScores(classId, item.gradeItemId, scores);
          }
        }

        final exams = await local.loadExams(classId);
        if (exams.isNotEmpty) {
          await remote.saveExams(classId, exams);
        }
      }

      final templates = await local.loadTemplates();
      if (templates.isNotEmpty) {
        final templatesForUser = templates
            .map((t) => t.copyWith(teacherId: userId, updatedAt: now))
            .toList();
        await remote.saveTemplates(templatesForUser);
      }

      await prefs.setBool(_flagKey(userId), true);
      debugPrint(
          'MigrationService: migrated local data to Firestore for user=$userId (classes=${classesForUser.length})');
    } catch (e) {
      debugPrint('MigrationService: migration skipped/failed: $e');
    }
  }
}

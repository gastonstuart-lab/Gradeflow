import 'package:flutter/foundation.dart';
import 'package:gradeflow/models/class.dart';
import 'package:gradeflow/repositories/repository_factory.dart';

class ClassService extends ChangeNotifier {
  List<Class> _classes = [];
  bool _isLoading = false;

  // Active classes by default for UI
  List<Class> get classes => _classes.where((c) => !c.isArchived).toList();
  List<Class> get activeClasses => _classes.where((c) => !c.isArchived).toList();
  List<Class> get archivedClasses => _classes.where((c) => c.isArchived).toList();
  bool get isLoading => _isLoading;

  Future<void> loadClasses(String teacherId) async {
    _isLoading = true;
    // Removed early notify to avoid setState/markNeedsBuild during build
    
    try {
      final repo = RepositoryFactory.instance;
      final all = await repo.loadClasses();
      _classes = all.where((c) => c.teacherId == teacherId).toList();
    } catch (e) {
      debugPrint('Failed to load classes: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addClass(Class newClass) async {
    try {
      _classes.add(newClass);
      final repo = RepositoryFactory.instance;
      await repo.saveClasses(_classes);
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to add class: $e');
    }
  }

  Future<void> updateClass(Class updatedClass) async {
    try {
      final localIndex = _classes.indexWhere((c) => c.classId == updatedClass.classId);
      if (localIndex == -1) return;
      _classes[localIndex] = updatedClass;
      final repo = RepositoryFactory.instance;
      await repo.saveClasses(_classes);
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to update class: $e');
    }
  }

  Future<void> archiveClass(String classId) async {
    try {
      final idx = _classes.indexWhere((c) => c.classId == classId);
      if (idx == -1) return;
      final updated = _classes[idx].copyWith(isArchived: true, updatedAt: DateTime.now());
      await updateClass(updated);
    } catch (e) {
      debugPrint('Failed to archive class: $e');
    }
  }

  Future<void> unarchiveClass(String classId) async {
    try {
      final idx = _classes.indexWhere((c) => c.classId == classId);
      if (idx == -1) return;
      final updated = _classes[idx].copyWith(isArchived: false, updatedAt: DateTime.now());
      await updateClass(updated);
    } catch (e) {
      debugPrint('Failed to unarchive class: $e');
    }
  }

  Future<void> deleteClass(String classId) async {
    try {
      final repo = RepositoryFactory.instance;
      await repo.deleteClass(classId);
      _classes.removeWhere((c) => c.classId == classId);
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to delete class: $e');
    }
  }

  Class? getClassById(String classId) {
    try {
      return _classes.firstWhere((c) => c.classId == classId);
    } catch (e) {
      return null;
    }
  }

  Future<void> seedDemoClasses(String teacherId) async {
    try {
      final repo = RepositoryFactory.instance;
      final existing = await repo.loadClasses();
      if (existing.any((c) => c.teacherId == teacherId)) return;

      final now = DateTime.now();
      final demoClasses = [
        Class(
          classId: 'demo-class-1',
          className: 'Grade 10A',
          subject: 'Mathematics',
          groupNumber: 'A',
          schoolYear: '2024-2025',
          term: 'Fall',
          teacherId: teacherId,
          createdAt: now,
          updatedAt: now,
        ),
        Class(
          classId: 'demo-class-2',
          className: 'Grade 11B',
          subject: 'English',
          groupNumber: 'B',
          schoolYear: '2024-2025',
          term: 'Fall',
          teacherId: teacherId,
          createdAt: now,
          updatedAt: now,
        ),
        Class(
          classId: 'demo-class-3',
          className: 'Grade 12C',
          subject: 'Physics',
          groupNumber: 'C',
          schoolYear: '2024-2025',
          term: 'Fall',
          teacherId: teacherId,
          createdAt: now,
          updatedAt: now,
        ),
      ];
      await repo.saveClasses([...existing, ...demoClasses]);
      debugPrint('Demo classes seeded successfully');
    } catch (e) {
      debugPrint('Failed to seed demo classes: $e');
    }
  }
}

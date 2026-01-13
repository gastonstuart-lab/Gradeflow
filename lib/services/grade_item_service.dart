import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:gradeflow/models/grade_item.dart';
import 'package:gradeflow/repositories/repository_factory.dart';

class GradeItemService extends ChangeNotifier {
  List<GradeItem> _gradeItems = [];
  bool _isLoading = false;

  List<GradeItem> get gradeItems => _gradeItems;
  bool get isLoading => _isLoading;

  Future<void> loadGradeItems(String classId) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final repo = RepositoryFactory.instance;
      final all = await repo.loadGradeItems(classId);
      _gradeItems = all.where((g) => g.isActive).toList();
    } catch (e) {
      debugPrint('Failed to load grade items: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addGradeItem(GradeItem newGradeItem) async {
    try {
      _gradeItems.add(newGradeItem);
      final repo = RepositoryFactory.instance;
      await repo.saveGradeItems(newGradeItem.classId, _gradeItems);
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to add grade item: $e');
    }
  }

  Future<void> updateGradeItem(GradeItem updatedGradeItem) async {
    try {
      final localIndex = _gradeItems.indexWhere((g) => g.gradeItemId == updatedGradeItem.gradeItemId);
      if (localIndex == -1) return;
      _gradeItems[localIndex] = updatedGradeItem;
      final repo = RepositoryFactory.instance;
      await repo.saveGradeItems(updatedGradeItem.classId, _gradeItems);
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to update grade item: $e');
    }
  }

  Future<void> deleteGradeItem(String gradeItemId) async {
    try {
      final idx = _gradeItems.indexWhere((g) => g.gradeItemId == gradeItemId);
      if (idx == -1) return;
      final classId = _gradeItems[idx].classId;
      final updated = _gradeItems[idx].copyWith(isActive: false, updatedAt: DateTime.now());
      _gradeItems[idx] = updated;
      final repo = RepositoryFactory.instance;
      await repo.saveGradeItems(classId, _gradeItems);
      _gradeItems.removeWhere((g) => g.gradeItemId == gradeItemId);
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to delete grade item: $e');
    }
  }

  List<GradeItem> getItemsByCategory(String categoryId) {
    return _gradeItems.where((g) => g.categoryId == categoryId && g.isActive).toList();
  }

  Future<void> seedDemoGradeItems(String classId, List<String> categoryIds) async {
    try {
      final repo = RepositoryFactory.instance;
      final existingItems = await repo.loadGradeItems(classId);
      if (existingItems.isEmpty && categoryIds.isNotEmpty) {
        final now = DateTime.now();
        final demoItems = <GradeItem>[];
        
        for (int i = 0; i < categoryIds.length; i++) {
          final categoryId = categoryIds[i];
          demoItems.addAll([
            GradeItem(
              gradeItemId: const Uuid().v4(),
              classId: classId,
              categoryId: categoryId,
              name: 'Week 1',
              maxScore: 100.0,
              isActive: true,
              createdAt: now,
              updatedAt: now,
            ),
            GradeItem(
              gradeItemId: const Uuid().v4(),
              classId: classId,
              categoryId: categoryId,
              name: 'Week 2',
              maxScore: 100.0,
              isActive: true,
              createdAt: now,
              updatedAt: now,
            ),
          ]);
        }
        
        await repo.saveGradeItems(classId, demoItems);
        debugPrint('Demo grade items seeded for class $classId');
      }
    } catch (e) {
      debugPrint('Failed to seed demo grade items: $e');
    }
  }
}

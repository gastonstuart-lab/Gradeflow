import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:gradeflow/models/grading_category.dart';
import 'package:gradeflow/repositories/repository_factory.dart';

class GradingCategoryService extends ChangeNotifier {
  List<GradingCategory> _categories = [];
  bool _isLoading = false;

  List<GradingCategory> get categories => _categories;
  bool get isLoading => _isLoading;

  Future<void> loadCategories(String classId) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final repo = RepositoryFactory.instance;
      final all = await repo.loadCategories(classId);
      _categories = all.where((c) => c.isActive).toList();
    } catch (e) {
      debugPrint('Failed to load categories: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addCategory(GradingCategory newCategory) async {
    try {
      _categories.add(newCategory);
      final repo = RepositoryFactory.instance;
      await repo.saveCategories(newCategory.classId, _categories);
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to add category: $e');
    }
  }

  Future<void> updateCategory(GradingCategory updatedCategory) async {
    try {
      final localIndex = _categories.indexWhere((c) => c.categoryId == updatedCategory.categoryId);
      if (localIndex == -1) return;
      _categories[localIndex] = updatedCategory;
      final repo = RepositoryFactory.instance;
      await repo.saveCategories(updatedCategory.classId, _categories);
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to update category: $e');
    }
  }

  Future<void> deleteCategory(String categoryId) async {
    try {
      final idx = _categories.indexWhere((c) => c.categoryId == categoryId);
      if (idx == -1) return;
      final classId = _categories[idx].classId;
      final updated = _categories[idx].copyWith(isActive: false, updatedAt: DateTime.now());
      _categories[idx] = updated;
      final repo = RepositoryFactory.instance;
      await repo.saveCategories(classId, _categories);
      _categories.removeWhere((c) => c.categoryId == categoryId);
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to delete category: $e');
    }
  }

  double getTotalWeight(String classId) {
    return _categories.where((c) => c.classId == classId && c.isActive).fold(0.0, (sum, c) => sum + c.weightPercent);
  }

  bool isWeightValid(String classId) {
    final total = getTotalWeight(classId);
    return (total - 100.0).abs() < 0.01;
  }

  Future<void> autoFixWeights(String classId) async {
    final activeCategories = _categories.where((c) => c.classId == classId && c.isActive).toList();
    
    if (activeCategories.isEmpty) return;
    
    final equalWeight = 100.0 / activeCategories.length;
    
    for (var category in activeCategories) {
      final updated = category.copyWith(weightPercent: equalWeight, updatedAt: DateTime.now());
      await updateCategory(updated);
    }
  }

  Future<void> seedDefaultCategories(String classId) async {
    try {
      final repo = RepositoryFactory.instance;
      final existing = await repo.loadCategories(classId);
      if (existing.isEmpty) {
        final now = DateTime.now();
        final defaultCategories = [
          GradingCategory(
            categoryId: const Uuid().v4(),
            classId: classId,
            name: 'Participation',
            weightPercent: 25.0,
            aggregationMethod: AggregationMethod.average,
            isActive: true,
            createdAt: now,
            updatedAt: now,
          ),
          GradingCategory(
            categoryId: const Uuid().v4(),
            classId: classId,
            name: 'Homework',
            weightPercent: 25.0,
            aggregationMethod: AggregationMethod.average,
            isActive: true,
            createdAt: now,
            updatedAt: now,
          ),
          GradingCategory(
            categoryId: const Uuid().v4(),
            classId: classId,
            name: 'Classwork',
            weightPercent: 25.0,
            aggregationMethod: AggregationMethod.average,
            isActive: true,
            createdAt: now,
            updatedAt: now,
          ),
          GradingCategory(
            categoryId: const Uuid().v4(),
            classId: classId,
            name: 'Quiz',
            weightPercent: 25.0,
            aggregationMethod: AggregationMethod.average,
            isActive: true,
            createdAt: now,
            updatedAt: now,
          ),
        ];
        
        await repo.saveCategories(classId, defaultCategories);
        debugPrint('Default categories seeded for class $classId');
      }
    } catch (e) {
      debugPrint('Failed to seed default categories: $e');
    }
  }
}

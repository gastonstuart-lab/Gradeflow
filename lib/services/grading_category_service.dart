import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'package:gradeflow/models/grading_category.dart';

class GradingCategoryService extends ChangeNotifier {
  static const String _categoriesKey = 'grading_categories';
  List<GradingCategory> _categories = [];
  bool _isLoading = false;

  List<GradingCategory> get categories => _categories;
  bool get isLoading => _isLoading;

  Future<void> loadCategories(String classId) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final categoriesJson = prefs.getString(_categoriesKey);
      
      if (categoriesJson != null) {
        final List<dynamic> categoryList = json.decode(categoriesJson) as List;
        _categories = categoryList
            .map((c) => GradingCategory.fromJson(c as Map<String, dynamic>))
            .where((c) => c.classId == classId && c.isActive)
            .toList();
      }
    } catch (e) {
      debugPrint('Failed to load categories: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addCategory(GradingCategory newCategory) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final categoriesJson = prefs.getString(_categoriesKey);
      List<Map<String, dynamic>> categoryList = [];
      
      if (categoriesJson != null) {
        categoryList = (json.decode(categoriesJson) as List).cast<Map<String, dynamic>>();
      }
      
      categoryList.add(newCategory.toJson());
      await prefs.setString(_categoriesKey, json.encode(categoryList));
      
      _categories.add(newCategory);
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to add category: $e');
    }
  }

  Future<void> updateCategory(GradingCategory updatedCategory) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final categoriesJson = prefs.getString(_categoriesKey);
      
      if (categoriesJson != null) {
        List<Map<String, dynamic>> categoryList = (json.decode(categoriesJson) as List).cast<Map<String, dynamic>>();
        final index = categoryList.indexWhere((c) => c['categoryId'] == updatedCategory.categoryId);
        
        if (index != -1) {
          categoryList[index] = updatedCategory.toJson();
          await prefs.setString(_categoriesKey, json.encode(categoryList));
          
          final localIndex = _categories.indexWhere((c) => c.categoryId == updatedCategory.categoryId);
          if (localIndex != -1) {
            _categories[localIndex] = updatedCategory;
            notifyListeners();
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to update category: $e');
    }
  }

  Future<void> deleteCategory(String categoryId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final categoriesJson = prefs.getString(_categoriesKey);
      
      if (categoriesJson != null) {
        List<Map<String, dynamic>> categoryList = (json.decode(categoriesJson) as List).cast<Map<String, dynamic>>();
        final index = categoryList.indexWhere((c) => c['categoryId'] == categoryId);
        
        if (index != -1) {
          var category = GradingCategory.fromJson(categoryList[index]);
          category = category.copyWith(isActive: false, updatedAt: DateTime.now());
          categoryList[index] = category.toJson();
          await prefs.setString(_categoriesKey, json.encode(categoryList));
          
          _categories.removeWhere((c) => c.categoryId == categoryId);
          notifyListeners();
        }
      }
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
      final prefs = await SharedPreferences.getInstance();
      final categoriesJson = prefs.getString(_categoriesKey);
      List<Map<String, dynamic>> categoryList = [];
      
      if (categoriesJson != null) {
        categoryList = (json.decode(categoriesJson) as List).cast<Map<String, dynamic>>();
      }
      
      final existingCategories = categoryList.where((c) => c['classId'] == classId).toList();
      
      if (existingCategories.isEmpty) {
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
        
        for (var category in defaultCategories) {
          categoryList.add(category.toJson());
        }
        
        await prefs.setString(_categoriesKey, json.encode(categoryList));
        debugPrint('Default categories seeded for class $classId');
      }
    } catch (e) {
      debugPrint('Failed to seed default categories: $e');
    }
  }
}

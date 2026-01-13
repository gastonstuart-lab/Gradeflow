import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'package:gradeflow/models/grade_item.dart';

class GradeItemService extends ChangeNotifier {
  static const String _gradeItemsKey = 'grade_items';
  List<GradeItem> _gradeItems = [];
  bool _isLoading = false;

  List<GradeItem> get gradeItems => _gradeItems;
  bool get isLoading => _isLoading;

  Future<void> loadGradeItems(String classId) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final gradeItemsJson = prefs.getString(_gradeItemsKey);
      
      if (gradeItemsJson != null) {
        final List<dynamic> gradeItemList = json.decode(gradeItemsJson) as List;
        _gradeItems = gradeItemList
            .map((g) => GradeItem.fromJson(g as Map<String, dynamic>))
            .where((g) => g.classId == classId && g.isActive)
            .toList();
      }
    } catch (e) {
      debugPrint('Failed to load grade items: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addGradeItem(GradeItem newGradeItem) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final gradeItemsJson = prefs.getString(_gradeItemsKey);
      List<Map<String, dynamic>> gradeItemList = [];
      
      if (gradeItemsJson != null) {
        gradeItemList = (json.decode(gradeItemsJson) as List).cast<Map<String, dynamic>>();
      }
      
      gradeItemList.add(newGradeItem.toJson());
      await prefs.setString(_gradeItemsKey, json.encode(gradeItemList));
      
      _gradeItems.add(newGradeItem);
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to add grade item: $e');
    }
  }

  Future<void> updateGradeItem(GradeItem updatedGradeItem) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final gradeItemsJson = prefs.getString(_gradeItemsKey);
      
      if (gradeItemsJson != null) {
        List<Map<String, dynamic>> gradeItemList = (json.decode(gradeItemsJson) as List).cast<Map<String, dynamic>>();
        final index = gradeItemList.indexWhere((g) => g['gradeItemId'] == updatedGradeItem.gradeItemId);
        
        if (index != -1) {
          gradeItemList[index] = updatedGradeItem.toJson();
          await prefs.setString(_gradeItemsKey, json.encode(gradeItemList));
          
          final localIndex = _gradeItems.indexWhere((g) => g.gradeItemId == updatedGradeItem.gradeItemId);
          if (localIndex != -1) {
            _gradeItems[localIndex] = updatedGradeItem;
            notifyListeners();
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to update grade item: $e');
    }
  }

  Future<void> deleteGradeItem(String gradeItemId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final gradeItemsJson = prefs.getString(_gradeItemsKey);
      
      if (gradeItemsJson != null) {
        List<Map<String, dynamic>> gradeItemList = (json.decode(gradeItemsJson) as List).cast<Map<String, dynamic>>();
        final index = gradeItemList.indexWhere((g) => g['gradeItemId'] == gradeItemId);
        
        if (index != -1) {
          var gradeItem = GradeItem.fromJson(gradeItemList[index]);
          gradeItem = gradeItem.copyWith(isActive: false, updatedAt: DateTime.now());
          gradeItemList[index] = gradeItem.toJson();
          await prefs.setString(_gradeItemsKey, json.encode(gradeItemList));
          
          _gradeItems.removeWhere((g) => g.gradeItemId == gradeItemId);
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Failed to delete grade item: $e');
    }
  }

  List<GradeItem> getItemsByCategory(String categoryId) {
    return _gradeItems.where((g) => g.categoryId == categoryId && g.isActive).toList();
  }

  Future<void> seedDemoGradeItems(String classId, List<String> categoryIds) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final gradeItemsJson = prefs.getString(_gradeItemsKey);
      List<Map<String, dynamic>> gradeItemList = [];
      
      if (gradeItemsJson != null) {
        gradeItemList = (json.decode(gradeItemsJson) as List).cast<Map<String, dynamic>>();
      }
      
      final existingItems = gradeItemList.where((g) => g['classId'] == classId).toList();
      
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
        
        for (var item in demoItems) {
          gradeItemList.add(item.toJson());
        }
        
        await prefs.setString(_gradeItemsKey, json.encode(gradeItemList));
        debugPrint('Demo grade items seeded for class $classId');
      }
    } catch (e) {
      debugPrint('Failed to seed demo grade items: $e');
    }
  }
}

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:gradeflow/models/class.dart';

class ClassService extends ChangeNotifier {
  static const String _classesKey = 'classes';
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
      final prefs = await SharedPreferences.getInstance();
      final classesJson = prefs.getString(_classesKey);
      
      if (classesJson != null) {
        final List<dynamic> classList = json.decode(classesJson) as List;
        debugPrint('ClassService.loadClasses: total stored=${classList.length} for teacher=$teacherId');
        _classes = classList
            .map((c) => Class.fromJson(c as Map<String, dynamic>))
            .where((c) => c.teacherId == teacherId)
            .toList();
        debugPrint('ClassService.loadClasses: filtered count=${_classes.length}');
      }
    } catch (e) {
      debugPrint('Failed to load classes: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addClass(Class newClass) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final classesJson = prefs.getString(_classesKey);
      List<Map<String, dynamic>> classList = [];
      
      if (classesJson != null) {
        classList = (json.decode(classesJson) as List).cast<Map<String, dynamic>>();
      }
      
      debugPrint('ClassService.addClass: before add total stored=${classList.length}');
      classList.add(newClass.toJson());
      await prefs.setString(_classesKey, json.encode(classList));
      
      _classes.add(newClass);
      debugPrint('ClassService.addClass: added ${newClass.className} (teacher=${newClass.teacherId}), now local=${_classes.length}');
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to add class: $e');
    }
  }

  Future<void> updateClass(Class updatedClass) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final classesJson = prefs.getString(_classesKey);
      
      if (classesJson != null) {
        List<Map<String, dynamic>> classList = (json.decode(classesJson) as List).cast<Map<String, dynamic>>();
        final index = classList.indexWhere((c) => c['classId'] == updatedClass.classId);
        
        if (index != -1) {
          classList[index] = updatedClass.toJson();
          await prefs.setString(_classesKey, json.encode(classList));
          
          final localIndex = _classes.indexWhere((c) => c.classId == updatedClass.classId);
          if (localIndex != -1) {
            _classes[localIndex] = updatedClass;
            notifyListeners();
          }
        }
      }
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
      final prefs = await SharedPreferences.getInstance();
      final classesJson = prefs.getString(_classesKey);
      
      if (classesJson != null) {
        List<Map<String, dynamic>> classList = (json.decode(classesJson) as List).cast<Map<String, dynamic>>();
        classList.removeWhere((c) => c['classId'] == classId);
        await prefs.setString(_classesKey, json.encode(classList));
        
        _classes.removeWhere((c) => c.classId == classId);
        notifyListeners();
      }
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
      final prefs = await SharedPreferences.getInstance();
      final classesJson = prefs.getString(_classesKey);
      
      if (classesJson == null) {
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
        ];
        
        await prefs.setString(_classesKey, json.encode(demoClasses.map((c) => c.toJson()).toList()));
        debugPrint('Demo classes seeded successfully');
      }
    } catch (e) {
      debugPrint('Failed to seed demo classes: $e');
    }
  }
}

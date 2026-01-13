import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:gradeflow/models/grading_template.dart';

class GradingTemplateService extends ChangeNotifier {
  static const String _templatesKey = 'grading_templates';
  List<GradingTemplate> _templates = [];
  bool _isLoading = false;

  List<GradingTemplate> get templates => _templates;
  bool get isLoading => _isLoading;

  Future<void> loadTemplates(String teacherId) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final templatesJson = prefs.getString(_templatesKey);
      
      if (templatesJson != null) {
        final List<dynamic> templateList = json.decode(templatesJson) as List;
        _templates = templateList
            .map((t) => GradingTemplate.fromJson(t as Map<String, dynamic>))
            .where((t) => t.teacherId == teacherId)
            .toList();
      }
    } catch (e) {
      debugPrint('Failed to load templates: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> saveTemplate(GradingTemplate template) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final templatesJson = prefs.getString(_templatesKey);
      List<Map<String, dynamic>> templateList = [];
      
      if (templatesJson != null) {
        templateList = (json.decode(templatesJson) as List).cast<Map<String, dynamic>>();
      }
      
      templateList.add(template.toJson());
      await prefs.setString(_templatesKey, json.encode(templateList));
      
      _templates.add(template);
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to save template: $e');
    }
  }

  Future<void> deleteTemplate(String templateId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final templatesJson = prefs.getString(_templatesKey);
      
      if (templatesJson != null) {
        List<Map<String, dynamic>> templateList = (json.decode(templatesJson) as List).cast<Map<String, dynamic>>();
        templateList.removeWhere((t) => t['templateId'] == templateId);
        await prefs.setString(_templatesKey, json.encode(templateList));
        
        _templates.removeWhere((t) => t.templateId == templateId);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Failed to delete template: $e');
    }
  }
}

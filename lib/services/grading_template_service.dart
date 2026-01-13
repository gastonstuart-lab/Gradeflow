import 'package:flutter/foundation.dart';
import 'package:gradeflow/models/grading_template.dart';
import 'package:gradeflow/repositories/repository_factory.dart';

class GradingTemplateService extends ChangeNotifier {
  List<GradingTemplate> _templates = [];
  bool _isLoading = false;

  List<GradingTemplate> get templates => _templates;
  bool get isLoading => _isLoading;

  Future<void> loadTemplates(String teacherId) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final repo = RepositoryFactory.instance;
      final all = await repo.loadTemplates();
      _templates = all.where((t) => t.teacherId == teacherId).toList();
    } catch (e) {
      debugPrint('Failed to load templates: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> saveTemplate(GradingTemplate template) async {
    try {
      _templates.add(template);
      final repo = RepositoryFactory.instance;
      await repo.saveTemplates(_templates);
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to save template: $e');
    }
  }

  Future<void> deleteTemplate(String templateId) async {
    try {
      _templates.removeWhere((t) => t.templateId == templateId);
      final repo = RepositoryFactory.instance;
      await repo.saveTemplates(_templates);
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to delete template: $e');
    }
  }
}

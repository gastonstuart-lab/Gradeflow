import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gradeflow/services/auth_service.dart';

/// Local, user-scoped appearance preferences. Never stores classroom data.
class TeacherAppearanceController extends ChangeNotifier {
  String? _userId;
  String _background = 'minimal';
  String _accent = 'indigo';
  double _intensity = 0.40;
  bool _enabled = true;
  bool _showInTeachMode = false;
  int _loadGeneration = 0;

  static const backgrounds = <String, String>{
    'minimal': 'Minimal',
    'boxes': 'Interactive boxes',
    'aurora': 'Aurora',
    'dots': 'Soft dots',
  };
  static const accents = <String, Color>{
    'indigo': Color(0xFF818CF8),
    'cyan': Color(0xFF22D3EE),
    'emerald': Color(0xFF34D399),
    'rose': Color(0xFFFB7185),
  };

  String get background => _background;
  String get accent => _accent;
  Color get accentColor => accents[_accent]!;

  /// Contrast-aware primary used for actual buttons and active UI states.
  Color themeAccent(Brightness brightness) {
    if (brightness == Brightness.dark) return accentColor;
    switch (_accent) {
      case 'cyan':
        return const Color(0xFF0E7490);
      case 'emerald':
        return const Color(0xFF047857);
      case 'rose':
        return const Color(0xFFBE123C);
      default:
        return const Color(0xFF4F46E5);
    }
  }
  double get intensity => _intensity;
  bool get enabled => _enabled;
  bool get showInTeachMode => _showInTeachMode;

  String _key(String item) => 'teacher_appearance_v1_${_userId ?? 'local'}_$item';

  void syncAuth(AuthService auth) {
    final next = auth.isAuthenticated ? (auth.currentUser?.userId ?? 'local') : null;
    if (next == _userId) return;
    _userId = next;
    final generation = ++_loadGeneration;
    _background = 'minimal';
    _accent = 'indigo';
    _intensity = 0.40;
    _enabled = true;
    _showInTeachMode = false;
    notifyListeners();
    if (next != null) _load(generation);
  }

  Future<void> _load(int generation) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bg = prefs.getString(_key('background'));
      final color = prefs.getString(_key('accent'));
      final intensity = prefs.getDouble(_key('intensity'));
      final enabled = prefs.getBool(_key('enabled'));
      final teaching = prefs.getBool(_key('teach_mode'));
      if (generation != _loadGeneration) return;
      _background = backgrounds.containsKey(bg) ? bg! : 'minimal';
      _accent = accents.containsKey(color) ? color! : 'indigo';
      _intensity = (intensity ?? 0.40).clamp(0.0, 1.0);
      _enabled = enabled ?? true;
      _showInTeachMode = teaching ?? false;
      notifyListeners();
    } catch (_) {
      // Default appearance remains available even when storage is blocked.
    }
  }

  void setBackground(String value) {
    if (!backgrounds.containsKey(value) || value == _background) return;
    _background = value;
    notifyListeners();
    _save('background', value);
  }

  void setAccent(String value) {
    if (!accents.containsKey(value) || value == _accent) return;
    _accent = value;
    notifyListeners();
    _save('accent', value);
  }

  void setIntensity(double value) {
    final next = value.clamp(0.0, 1.0);
    if (next == _intensity) return;
    _intensity = next;
    notifyListeners();
    _save('intensity', next);
  }

  void setEnabled(bool value) {
    if (value == _enabled) return;
    _enabled = value;
    notifyListeners();
    _save('enabled', value);
  }

  /// Opt-in only: protect a projected classroom screen by default.
  void setShowInTeachMode(bool value) {
    if (_showInTeachMode == value) return;
    _showInTeachMode = value;
    notifyListeners();
    _save('teach_mode', value);
  }

  void reset() {
    _showInTeachMode = false;
    _background = 'minimal';
    _accent = 'indigo';
    _intensity = 0.40;
    _enabled = true;
    notifyListeners();
    _saveAll();
  }

  Future<void> _save(String suffix, Object value) async {
    if (_userId == null) return;
    final user = _userId;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'teacher_appearance_v1_${user}_$suffix';
      if (value is String) await prefs.setString(key, value);
      if (value is double) await prefs.setDouble(key, value);
      if (value is bool) await prefs.setBool(key, value);
    } catch (_) {
      // Keep the user's immediate in-memory selection if storage is unavailable.
    }
  }

  void _saveAll() {
    _save('background', _background);
    _save('accent', _accent);
    _save('intensity', _intensity);
    _save('enabled', _enabled);
    _save('teach_mode', _showInTeachMode);
  }
}

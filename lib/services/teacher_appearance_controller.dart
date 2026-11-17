import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gradeflow/services/auth_service.dart';

/// Local, user-scoped appearance preferences. Never stores classroom data.
class TeacherAppearanceController extends ChangeNotifier {
  String? _userId;
  String _background = 'minimal';
  String _accent = 'indigo';
  Color _customAccent = const Color(0xFFAD7EF7);
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
    'amber': Color(0xFFFBBF24),
    'orange': Color(0xFFFB923C),
    'violet': Color(0xFFA78BFA),
    'blue': Color(0xFF60A5FA),
    'teal': Color(0xFF2DD4BF),
    'pink': Color(0xFFF472B6),
  };

  String get background => _background;
  String get accent => _accent;
  Color get accentColor => _accent == 'custom'
      ? _customAccent
      : (accents[_accent] ?? accents['indigo']!);
  Color get customAccent => _customAccent;

  static String toHex(Color color) {
    final hex = color.toARGB32() & 0xFFFFFF;
    return '#${hex.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  static Color? fromHex(String? value) {
    if (value == null ||
        !RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(value)) {
      return null;
    }
    return Color(0xFF000000 | int.parse(value.substring(1), radix: 16));
  }

  bool get isCustomAccent => _accent == 'custom';

  /// Contrast-aware primary used for actual buttons and active UI states.
  Color themeAccent(Brightness brightness) {
    // Keep each teacher's chosen hue, but protect button-label contrast.
    // Light-mode buttons use white labels; dark-mode buttons use dark labels.
    if (_accent == 'indigo') {
      return brightness == Brightness.light
          ? const Color(0xFF4F46E5)
          : accentColor;
    }
    var colour = accentColor;
    final target = brightness == Brightness.light
        ? Colors.black
        : Colors.white;
    final limit = brightness == Brightness.light ? 0.175 : 0.37;
    for (var attempt = 0; attempt < 20; attempt++) {
      final luminance = colour.computeLuminance();
      if (brightness == Brightness.light
          ? luminance <= limit
          : luminance >= limit) break;
      colour = Color.lerp(colour, target, 0.10)!;
    }
    return colour;
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
    _customAccent = const Color(0xFFAD7EF7);
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
      final customColour = fromHex(prefs.getString(_key('custom_accent')));
      final intensity = prefs.getDouble(_key('intensity'));
      final enabled = prefs.getBool(_key('enabled'));
      final teaching = prefs.getBool(_key('teach_mode'));
      if (generation != _loadGeneration) return;
      _background = backgrounds.containsKey(bg) ? bg! : 'minimal';
      _customAccent = customColour ?? const Color(0xFFAD7EF7);
      _accent = color == 'custom' && customColour != null
          ? 'custom'
          : accents.containsKey(color) ? color! : 'indigo';
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

  void setCustomAccent(Color colour) {
    // Normalise user choices to opaque RGB; the appearance never affects data.
    final normalised = Color(0xFF000000 | (colour.toARGB32() & 0xFFFFFF));
    if (_accent == 'custom' && _customAccent == normalised) return;
    _customAccent = normalised;
    _accent = 'custom';
    notifyListeners();
    _save('custom_accent', toHex(normalised));
    _save('accent', 'custom');
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
    _customAccent = const Color(0xFFAD7EF7);
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
    _save('custom_accent', toHex(_customAccent));
    _save('intensity', _intensity);
    _save('enabled', _enabled);
    _save('teach_mode', _showInTeachMode);
  }
}

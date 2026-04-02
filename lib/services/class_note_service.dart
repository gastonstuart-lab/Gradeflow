import 'dart:convert';

import 'package:gradeflow/models/class_note_item.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ClassNoteService {
  static String _key(String classId, String userId) =>
      'class_notes_v1:$userId:$classId';

  Future<List<ClassNoteItem>> load({
    required String classId,
    required String userId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(classId, userId));
    if (raw == null || raw.trim().isEmpty) return const [];

    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];

    return decoded
        .whereType<Map>()
        .map((item) => ClassNoteItem.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<void> save({
    required String classId,
    required String userId,
    required List<ClassNoteItem> items,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final data = items.map((item) => item.toJson()).toList();
    await prefs.setString(_key(classId, userId), jsonEncode(data));
  }

  Future<void> clear({
    required String classId,
    required String userId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(classId, userId));
  }
}

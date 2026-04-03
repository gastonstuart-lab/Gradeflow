import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class DashboardPreferencesService {
  const DashboardPreferencesService();

  String scopedKey({
    required String baseKey,
    required String userId,
  }) {
    return '$baseKey:$userId';
  }

  Future<String?> readScopedString({
    required String scopedKey,
    String? legacyKey,
    String? migrationFlagKey,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final scopedValue = prefs.getString(scopedKey);
    if (scopedValue != null) {
      return scopedValue;
    }

    if (legacyKey == null || migrationFlagKey == null) {
      return null;
    }

    final alreadyMigrated = prefs.getBool(migrationFlagKey) ?? false;
    if (alreadyMigrated) {
      return null;
    }

    final legacyValue = prefs.getString(legacyKey);
    if (legacyValue == null) {
      return null;
    }

    await prefs.setString(scopedKey, legacyValue);
    await prefs.setBool(migrationFlagKey, true);
    await prefs.remove(legacyKey);
    return legacyValue;
  }

  Future<List<dynamic>> readScopedJsonList({
    required String scopedKey,
    String? legacyKey,
    String? migrationFlagKey,
  }) async {
    final raw = await readScopedString(
      scopedKey: scopedKey,
      legacyKey: legacyKey,
      migrationFlagKey: migrationFlagKey,
    );
    if (raw == null || raw.trim().isEmpty) {
      return const <dynamic>[];
    }

    final decoded = jsonDecode(raw);
    if (decoded is List<dynamic>) {
      return decoded;
    }
    return const <dynamic>[];
  }

  Future<void> writeString({
    required String key,
    required String? value,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (value == null) {
      await prefs.remove(key);
      return;
    }
    await prefs.setString(key, value);
  }

  Future<void> writeJsonList({
    required String key,
    required List<Object?> items,
  }) async {
    await writeString(key: key, value: jsonEncode(items));
  }
}

// ignore_for_file: invalid_use_of_protected_member, library_private_types_in_public_api

part of '../teacher_dashboard_screen.dart';

extension TeacherDashboardPersistence on _TeacherDashboardScreenState {
  Future<void> _loadReminders() async {
    try {
      final list = await _dashboardPreferencesService.readScopedJsonList(
        scopedKey: _remindersPrefsKey(),
        legacyKey: _TeacherDashboardScreenState._legacyRemindersPrefsKey,
        migrationFlagKey:
            _TeacherDashboardScreenState._remindersMigrationFlagKey,
      );
      final parsed = list.map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        final ids = (m['classIds'] as List?)
            ?.map((x) => x?.toString() ?? '')
            .where((s) => s.isNotEmpty)
            .cast<String>()
            .toList();
        return _Reminder(
          (m['text'] ?? '') as String,
          DateTime.tryParse(m['timestamp'] as String? ?? '') ?? DateTime.now(),
          done: (m['done'] as bool?) ?? false,
          classIds: ids == null || ids.isEmpty ? null : ids,
        );
      }).toList();
      if (!mounted) {
        return;
      }
      setState(() {
        _reminders
          ..clear()
          ..addAll(parsed);
      });
    } catch (e) {
      debugPrint('Failed to load reminders: $e');
    }
  }

  Future<void> _saveReminders() async {
    try {
      await _dashboardPreferencesService.writeJsonList(
        key: _remindersPrefsKey(),
        items: _reminders
            .map((r) => {
                  'text': r.text,
                  'timestamp': r.timestamp.toIso8601String(),
                  'done': r.done,
                  'classIds': r.classIds,
                })
            .toList(),
      );
    } catch (e) {
      debugPrint('Failed to save reminders: $e');
    }
  }

  String _dashboardStorageUserId() {
    return context.read<AuthService>().currentUser?.userId ?? 'local';
  }

  String _remindersPrefsKey() => _dashboardPreferencesService.scopedKey(
        baseKey: 'dashboard_reminders_v1',
        userId: _dashboardStorageUserId(),
      );

  String _timetablePrefsKey() => _dashboardPreferencesService.scopedKey(
        baseKey: 'dashboard_timetables_v1',
        userId: _dashboardStorageUserId(),
      );

  String _selectedTimetablePrefsKey() => _dashboardPreferencesService.scopedKey(
        baseKey: 'dashboard_selected_timetable_v1',
        userId: _dashboardStorageUserId(),
      );

  String _attendanceUrlPrefsKey() => _dashboardPreferencesService.scopedKey(
        baseKey: 'attendance_url_v1',
        userId: _dashboardStorageUserId(),
      );

  String _quickLinksPrefsKey() => _dashboardPreferencesService.scopedKey(
        baseKey: 'custom_quick_links_v1',
        userId: _dashboardStorageUserId(),
      );

  String _heroStylePrefsKey() => _dashboardPreferencesService.scopedKey(
        baseKey: 'dashboard_hero_style_v1',
        userId: _dashboardStorageUserId(),
      );

  String _heroImagePrefsKey() => _dashboardPreferencesService.scopedKey(
        baseKey: 'dashboard_hero_image_v1',
        userId: _dashboardStorageUserId(),
      );

  Future<void> _loadTimetables() async {
    try {
      final raw = await _dashboardPreferencesService.readScopedString(
        scopedKey: _timetablePrefsKey(),
      );
      final selectedId = await _dashboardPreferencesService.readScopedString(
        scopedKey: _selectedTimetablePrefsKey(),
      );

      final parsed = <_Timetable>[];
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List<dynamic>;
        for (final entry in list) {
          parsed.add(
              _Timetable.fromJson(Map<String, dynamic>.from(entry as Map)));
        }
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _timetables
          ..clear()
          ..addAll(parsed);
        _selectedTimetableId = selectedId;
        if (_selectedTimetableId != null &&
            !_timetables.any((t) => t.id == _selectedTimetableId)) {
          _selectedTimetableId = null;
        }
      });
    } catch (e) {
      debugPrint('Failed to load timetables: $e');
    }
  }

  Future<void> _saveTimetables() async {
    try {
      await _dashboardPreferencesService.writeString(
        key: _timetablePrefsKey(),
        value: jsonEncode(_timetables.map((t) => t.toJson()).toList()),
      );
      await _dashboardPreferencesService.writeString(
        key: _selectedTimetablePrefsKey(),
        value: _selectedTimetableId,
      );
    } catch (e) {
      debugPrint('Failed to save timetables: $e');
    }
  }

  Future<void> _loadQuickLinks() async {
    try {
      final attendanceUrl = await _dashboardPreferencesService.readScopedString(
        scopedKey: _attendanceUrlPrefsKey(),
        legacyKey:
            _TeacherDashboardScreenState._legacyAttendanceUrlPrefsKey,
        migrationFlagKey:
            _TeacherDashboardScreenState._attendanceUrlMigrationFlagKey,
      );
      final parsedJson = await _dashboardPreferencesService.readScopedJsonList(
        scopedKey: _quickLinksPrefsKey(),
        legacyKey: _TeacherDashboardScreenState._legacyQuickLinksPrefsKey,
        migrationFlagKey:
            _TeacherDashboardScreenState._quickLinksMigrationFlagKey,
      );
      final parsed = parsedJson
          .map((entry) => Map<String, dynamic>.from(entry as Map))
          .toList();
      if (!mounted) {
        return;
      }
      setState(() {
        _attendanceUrlCtrl.text =
            (attendanceUrl == null || attendanceUrl.trim().isEmpty)
                ? _TeacherDashboardScreenState._defaultAttendancePortalUrl
                : attendanceUrl.trim();
        _customLinks
          ..clear()
          ..addAll(parsed.map((m) => _QuickLink(
                label: (m['label'] ?? '') as String,
                url: (m['url'] ?? '') as String,
              )));
      });
    } catch (e) {
      debugPrint('Failed to load quick links: $e');
    }
  }

  Future<void> _saveQuickLinks() async {
    try {
      final attendanceUrl = _attendanceUrlCtrl.text.trim().isEmpty
          ? _TeacherDashboardScreenState._defaultAttendancePortalUrl
          : _attendanceUrlCtrl.text.trim();
      await _dashboardPreferencesService.writeString(
        key: _attendanceUrlPrefsKey(),
        value: attendanceUrl,
      );
      await _dashboardPreferencesService.writeJsonList(
        key: _quickLinksPrefsKey(),
        items: _customLinks
            .map((e) => {
                  'label': e.label,
                  'url': e.url,
                })
            .toList(),
      );
    } catch (e) {
      debugPrint('Failed to save quick links: $e');
    }
  }

  Future<void> _loadHeroPersonalization() async {
    try {
      final rawStyle = await _dashboardPreferencesService.readScopedString(
        scopedKey: _heroStylePrefsKey(),
      );
      final rawImage = await _dashboardPreferencesService.readScopedString(
        scopedKey: _heroImagePrefsKey(),
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _dashboardHeroStyle = _dashboardHeroStyleFromId(rawStyle);
        _dashboardHeroImageBase64 = rawImage;
        _dashboardHeroImageBytes = rawImage == null || rawImage.trim().isEmpty
            ? null
            : base64Decode(rawImage);
      });
    } catch (e) {
      debugPrint('Failed to load dashboard hero personalization: $e');
    }
  }

  Future<void> _saveHeroPersonalization() async {
    try {
      await _dashboardPreferencesService.writeString(
        key: _heroStylePrefsKey(),
        value: _dashboardHeroStyleId(_dashboardHeroStyle),
      );
      await _dashboardPreferencesService.writeString(
        key: _heroImagePrefsKey(),
        value: _dashboardHeroImageBase64,
      );
    } catch (e) {
      debugPrint('Failed to save dashboard hero personalization: $e');
    }
  }
}

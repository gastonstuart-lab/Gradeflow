import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:gradeflow/models/class.dart' as school;
import 'package:gradeflow/services/timetable_import_plan.dart';
import 'dart:typed_data';

import 'package:csv/csv.dart';

import 'package:gradeflow/components/time_slot_timetable.dart';
import 'package:gradeflow/services/dashboard_preferences_service.dart';
import 'package:gradeflow/services/file_import_service.dart';

/// One local timetable format shared with the existing teacher dashboard.
/// Only teacher-scoped preferences are read or changed; never student records.
class HomeWeeklyTimetable {
  final String name;
  final List<TimeSlotClass> classes;
  const HomeWeeklyTimetable({required this.name, required this.classes});
}

class HomeTeachingMoment {
  final String title;
  final DateTime startAt;
  final DateTime endAt;
  final int periodCount;

  const HomeTeachingMoment({
    required this.title,
    required this.startAt,
    required this.endAt,
    this.periodCount = 1,
  });
}

class HomeTeachingSequence {
  final HomeTeachingMoment? current;
  final HomeTeachingMoment? next;
  final HomeTeachingMoment? following;

  const HomeTeachingSequence({this.current, this.next, this.following});

  factory HomeTeachingSequence.fromSchedule(
    List<TimeSlotClass> classes,
    DateTime now, {
    bool combineConsecutivePeriods = true,
  }) {
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: now.weekday - 1));
    final moments = <HomeTeachingMoment>[];
    for (final entry in classes) {
      if (entry.dayOfWeek < 0 ||
          entry.dayOfWeek > 6 ||
          entry.endMinutes <= entry.startMinutes) {
        continue;
      }
      for (final week in const [0, 7]) {
        final date = monday.add(Duration(days: week + entry.dayOfWeek));
        final dayStart = DateTime(date.year, date.month, date.day);
        moments.add(HomeTeachingMoment(
          title: entry.title,
          startAt: dayStart.add(Duration(minutes: entry.startMinutes)),
          endAt: dayStart.add(Duration(minutes: entry.endMinutes)),
        ));
      }
    }
    moments.sort((a, b) => a.startAt.compareTo(b.startAt));

    // Merge presentation only. The saved timetable still contains its original
    // individual class periods, so imports and period counts remain intact.
    // A short supervised break (up to 15 minutes) between two periods counts
    // as one session if the class label is exactly the same after trimming.
    final sessions = <HomeTeachingMoment>[];
    for (final moment in moments) {
      if (combineConsecutivePeriods && sessions.isNotEmpty) {
        final previous = sessions.last;
        final gap = moment.startAt.difference(previous.endAt);
        final sameDay = previous.startAt.year == moment.startAt.year &&
            previous.startAt.month == moment.startAt.month &&
            previous.startAt.day == moment.startAt.day;
        final sameClass = previous.title.trim().toLowerCase() ==
            moment.title.trim().toLowerCase();
        if (sameDay &&
            sameClass &&
            !gap.isNegative &&
            gap <= const Duration(minutes: 15)) {
          sessions[sessions.length - 1] = HomeTeachingMoment(
            title: previous.title,
            startAt: previous.startAt,
            endAt: moment.endAt,
            periodCount: previous.periodCount + moment.periodCount,
          );
          continue;
        }
      }
      sessions.add(moment);
    }

    HomeTeachingMoment? current;
    final upcoming = <HomeTeachingMoment>[];
    for (final moment in sessions) {
      if (!now.isBefore(moment.startAt) && now.isBefore(moment.endAt)) {
        current ??= moment;
      } else if (!moment.startAt.isBefore(now)) {
        upcoming.add(moment);
      }
    }
    return HomeTeachingSequence(
      current: current,
      next: upcoming.isNotEmpty ? upcoming[0] : null,
      following: upcoming.length > 1 ? upcoming[1] : null,
    );
  }
}

class HomeWeeklyTimetableService {
  static const _timetablesKey = 'dashboard_timetables_v1';
  static Future<void> _writeTail = Future<void>.value();
  static int _outstandingWrites = 0;

  // Follow LocalRepository's queue contract, including immediate idle starts.
  static Future<T> _queue<T>(Future<T> Function() operation) {
    final wasIdle = _outstandingWrites == 0;
    _outstandingWrites++;
    final result = wasIdle
        ? Future<T>.sync(operation)
        : _writeTail.then((_) => operation());
    _writeTail =
        result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result.whenComplete(() {
      _outstandingWrites--;
    });
  }

  static const _selectedKey = 'dashboard_selected_timetable_v1';
  const HomeWeeklyTimetableService({DashboardPreferencesService? preferences})
      : _preferences = preferences;
  final DashboardPreferencesService? _preferences;

  DashboardPreferencesService get _prefs =>
      _preferences ?? const DashboardPreferencesService();

  Future<HomeWeeklyTimetable?> loadSelected(String userId) async {
    final items = await _prefs.readScopedJsonList(
      scopedKey: _prefs.scopedKey(baseKey: _timetablesKey, userId: userId),
    );
    final selected = await _prefs.readScopedString(
      scopedKey: _prefs.scopedKey(baseKey: _selectedKey, userId: userId),
    );
    final valid = <Map<String, dynamic>>[];
    for (final item in items) {
      if (item is Map) valid.add(Map<String, dynamic>.from(item));
    }
    if (valid.isEmpty) return null;
    final chosen =
        valid.where((item) => item['selected'] == true).firstOrNull ??
            valid.where((item) => item['id'] == selected).firstOrNull ??
            valid.last;
    final rawGrid = chosen['grid'];
    if (rawGrid is! List) return null;
    final grid = rawGrid.map((r) {
      if (r is! List) return <String>[];
      return r.map((value) => value?.toString() ?? '').toList();
    }).toList();
    final classes = chosen['lessons'] is List
        ? (chosen['lessons'] as List)
            .map((v) => lessonFromJson(Map<String, dynamic>.from(v as Map)))
            .toList()
        : parseGridToTimeSlots(grid);
    if (classes.isEmpty) return null;
    return HomeWeeklyTimetable(
      name: chosen['name']?.toString() ?? 'Timetable',
      classes: classes,
    );
  }

  /// Validate a weekly schedule without storing anything. Use this result
  /// to show a confirmation preview before choosing to save the import.
  static ({List<List<String>> grid, List<TimeSlotClass> classes}) inspectBytes({
    required String filename,
    required Uint8List bytes,
  }) {
    if (bytes.isEmpty || bytes.lengthInBytes > 2 * 1024 * 1024) {
      throw const FormatException(
          'Choose a non-empty timetable smaller than 2 MB.');
    }
    final extension = filename.split('.').last.toLowerCase();
    final fileService = FileImportService();
    List<List<String>> grid;
    if (extension == 'docx') {
      grid = fileService.cleanTimetableGrid(
        fileService.extractDocxBestTableGrid(bytes),
      );
    } else if (extension == 'csv') {
      // The legacy generic CSV decoder can keep LF-only files in one row.
      // Parse CSV here with explicit LF boundaries (including CRLF exports).
      final text = utf8
          .decode(bytes)
          .replaceAll('\uFEFF', '')
          .replaceAll('\r\n', '\n')
          .replaceAll('\r', '\n');
      final rows = const CsvToListConverter(
        eol: '\n',
        shouldParseNumbers: false,
      ).convert(text);
      grid = fileService.cleanTimetableGrid(
        rows
            .map((row) => row.map((c) => c?.toString().trim() ?? '').toList())
            .toList(),
      );
    } else if (extension == 'xlsx') {
      grid =
          fileService.cleanTimetableGrid(fileService.rowsFromAnyBytes(bytes));
    } else {
      throw const FormatException('Use an Excel, CSV or Word timetable.');
    }
    final classes = parseGridToTimeSlots(grid);
    if (classes.isEmpty) {
      throw const FormatException(
        'Could not find weekday headings and class times. '
        'Use a table with Monday–Friday columns and clock times.',
      );
    }

    return (grid: grid, classes: classes);
  }

  static TimeSlotClass lessonFromJson(Map<String, dynamic> item) =>
      TimeSlotClass(
          title: item['title'] as String,
          dayOfWeek: item['day'] as int,
          startMinutes: item['start'] as int,
          endMinutes: item['end'] as int,
          classId: item['classId'] as String?,
          room: item['room'] as String?);

  static Map<String, dynamic> lessonToJson(TimeSlotClass lesson) => {
        'title': lesson.title,
        'day': lesson.dayOfWeek,
        'start': lesson.startMinutes,
        'end': lesson.endMinutes,
        'classId': lesson.classId,
        'room': lesson.room,
      };

  Future<HomeWeeklyTimetable> importForTeacher({
    required String userId,
    required String filename,
    required Uint8List bytes,
    Map<String, String> classMatches = const {},
    List<school.Class> availableClasses = const [],
  }) =>
      _queue(() async {
        if (userId.trim().isEmpty || userId == 'local')
          throw StateError('Sign in before saving a timetable.');
        final parsed = inspectBytes(filename: filename, bytes: bytes);
        final lessons = TimetableImportPlan(parsed.classes)
            .confirmMatches(classMatches, availableClasses, userId);
        final previous = await loadVersions(userId);
        final id = const Uuid().v4();
        final item = <String, dynamic>{
          'id': id,
          'name': filename,
          'base64': base64Encode(bytes),
          'mimeType': filename.split('.').last.toLowerCase(),
          'uploadedAt': DateTime.now().toIso8601String(),
          'grid': parsed.grid,
          'lessons': lessons.map(lessonToJson).toList(),
        };
        await saveVersions(userId, [...previous, item], id);
        return HomeWeeklyTimetable(name: filename, classes: lessons);
      });

  Future<void> changeVersion(String userId,
          {required String versionId, bool delete = false}) =>
      _queue(() async {
        final versions = await loadVersions(userId);
        if (!versions.any((v) => v['id'] == versionId))
          throw const FormatException(
              'Version no longer exists. Reload Planner.');
        final selected =
            versions.where((v) => v['selected'] == true).firstOrNull;
        final previousId = selected?['id'] as String? ??
            await _prefs.readScopedString(
                scopedKey:
                    _prefs.scopedKey(baseKey: _selectedKey, userId: userId));
        final remaining =
            versions.where((v) => !delete || v['id'] != versionId).toList();
        final nextId = !delete
            ? versionId
            : previousId == versionId
                ? (remaining.isEmpty ? null : remaining.last['id'] as String)
                : previousId;
        await saveVersions(userId, remaining, nextId);
      });

  Future<List<Map<String, dynamic>>> loadVersions(String userId) async {
    if (userId.trim().isEmpty || userId == 'local')
      throw StateError('Sign in to manage timetables.');
    final items = await _prefs.readScopedJsonList(
        scopedKey: _prefs.scopedKey(baseKey: _timetablesKey, userId: userId));
    return items.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  /// Versions and selection share one checked write. A failed write leaves the
  /// previous selection and all its versions intact. Legacy keys remain readable.
  Future<void> saveVersions(String userId, List<Map<String, dynamic>> versions,
      String? selectedId) async {
    if (userId.trim().isEmpty || userId == 'local')
      throw StateError('Sign in to manage timetables.');
    if (selectedId != null && !versions.any((v) => v['id'] == selectedId)) {
      throw const FormatException(
          'That timetable version is no longer available.');
    }
    final selected = versions.where((v) => v['id'] == selectedId).firstOrNull;
    if (selected != null) {
      final grid = (selected['grid'] as List)
          .map((r) => (r as List).map((c) => c.toString()).toList())
          .toList();
      TimetableImportPlan.fromGrid(grid);
    }
    await _prefs.writeJsonList(
      key: _prefs.scopedKey(baseKey: _timetablesKey, userId: userId),
      items: [
        for (final item in versions)
          {...item, 'selected': item['id'] == selectedId}
      ],
    );
  }

  /// Strict parsing never invents an end time or combines timed periods.
  static List<TimeSlotClass> parseGridToTimeSlots(List<List<String>> grid) =>
      TimetableImportPlan.fromGrid(grid).lessons;
}

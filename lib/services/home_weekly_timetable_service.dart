import 'dart:convert';
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

  const HomeTeachingMoment({
    required this.title,
    required this.startAt,
    required this.endAt,
  });
}

class HomeTeachingSequence {
  final HomeTeachingMoment? current;
  final HomeTeachingMoment? next;
  final HomeTeachingMoment? following;

  const HomeTeachingSequence({this.current, this.next, this.following});

  factory HomeTeachingSequence.fromSchedule(
    List<TimeSlotClass> classes,
    DateTime now,
  ) {
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: now.weekday - 1));
    final moments = <HomeTeachingMoment>[];
    for (final entry in classes) {
      if (entry.dayOfWeek < 0 || entry.dayOfWeek > 6 ||
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
    HomeTeachingMoment? current;
    final upcoming = <HomeTeachingMoment>[];
    for (final moment in moments) {
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
  static const _selectedKey = 'dashboard_selected_timetable_v1';
  const HomeWeeklyTimetableService();

  DashboardPreferencesService get _prefs => const DashboardPreferencesService();

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
    final chosen = valid.where((item) => item['id'] == selected).firstOrNull ??
        valid.last;
    final rawGrid = chosen['grid'];
    if (rawGrid is! List) return null;
    final grid = rawGrid.map((r) {
      if (r is! List) return <String>[];
      return r.map((value) => value?.toString() ?? '').toList();
    }).toList();
    final classes = parseGridToTimeSlots(grid);
    if (classes.isEmpty) return null;
    return HomeWeeklyTimetable(
      name: chosen['name']?.toString() ?? 'Timetable',
      classes: classes,
    );
  }

  Future<HomeWeeklyTimetable> importForTeacher({
    required String userId,
    required String filename,
    required Uint8List bytes,
  }) async {
    if (bytes.isEmpty || bytes.lengthInBytes > 2 * 1024 * 1024) {
      throw const FormatException('Choose a non-empty timetable smaller than 2 MB.');
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
      final text = utf8.decode(bytes, allowMalformed: true)
          .replaceAll('\r\n', '\n')
          .replaceAll('\r', '\n');
      final rows = const CsvToListConverter(
        eol: '\n',
        shouldParseNumbers: false,
      ).convert(text);
      grid = fileService.cleanTimetableGrid(
        rows.map((row) => row.map((c) => c?.toString().trim() ?? '').toList())
            .toList(),
      );
    } else if (extension == 'xlsx') {
      grid = fileService.cleanTimetableGrid(fileService.rowsFromAnyBytes(bytes));
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

    final previous = await _prefs.readScopedJsonList(
      scopedKey: _prefs.scopedKey(baseKey: _timetablesKey, userId: userId),
    );
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final item = <String, dynamic>{
      'id': id,
      'name': filename,
      'base64': base64Encode(bytes),
      'mimeType': extension,
      'uploadedAt': DateTime.now().toIso8601String(),
      'grid': grid,
    };
    await _prefs.writeString(
      key: _prefs.scopedKey(baseKey: _timetablesKey, userId: userId),
      value: jsonEncode([...previous, item]),
    );
    await _prefs.writeString(
      key: _prefs.scopedKey(baseKey: _selectedKey, userId: userId),
      value: id,
    );
    return HomeWeeklyTimetable(name: filename, classes: classes);
  }

  /// Parses the same weekly grid as the original timetable viewer.
  static List<TimeSlotClass> parseGridToTimeSlots(List<List<String>> grid) {
    final slots = <TimeSlotClass>[];
    if (grid.isEmpty) return slots;

    final dayMap = {
      'mon': 0,
      'monday': 0,
      'm': 0,
      'tue': 1,
      'tuesday': 1,
      'tu': 1,
      'wed': 2,
      'wednesday': 2,
      'w': 2,
      'thu': 3,
      'thursday': 3,
      'th': 3,
      'fri': 4,
      'friday': 4,
      'f': 4,
      '\u4e00': 0,
      '\u661f\u671f\u4e00': 0,
      '\u9031\u4e00': 0,
      '\u4e8c': 1,
      '\u661f\u671f\u4e8c': 1,
      '\u9031\u4e8c': 1,
      '\u4e09': 2,
      '\u661f\u671f\u4e09': 2,
      '\u9031\u4e09': 2,
      '\u56db': 3,
      '\u661f\u671f\u56db': 3,
      '\u9031\u56db': 3,
      '\u4e94': 4,
      '\u661f\u671f\u4e94': 4,
      '\u9031\u4e94': 4,
    };

    String normalizeCell(String value) =>
        value.toLowerCase().replaceAll('\u00a0', ' ').trim();

    ({int? start, int? end}) parseTimeRange(String value) {
      final match = RegExp(
        r'(\d{1,2})\s*:\s*(\d{2})(?:\s*(?:-|~)\s*(\d{1,2})\s*:\s*(\d{2}))?',
      ).firstMatch(value.replaceAll('\u00a0', ' ').trim());
      if (match == null) {
        return (start: null, end: null);
      }

      final startH = int.tryParse(match.group(1) ?? '');
      final startM = int.tryParse(match.group(2) ?? '');
      if (startH == null || startM == null) {
        return (start: null, end: null);
      }

      final start = startH * 60 + startM;
      final endH = int.tryParse(match.group(3) ?? '');
      final endM = int.tryParse(match.group(4) ?? '');
      final end = endH != null && endM != null ? (endH * 60 + endM) : null;
      return (start: start, end: end);
    }

    Map<int, int> headerDays = {};
    int headerRowIndex = -1;
    final headerScanLimit = grid.length < 4 ? grid.length : 4;
    for (int r = 0; r < headerScanLimit; r++) {
      final row = grid[r];
      final rowDays = <int, int>{};
      for (int c = 0; c < row.length; c++) {
        final norm = normalizeCell(row[c]);
        final day = dayMap[norm];
        if (day != null) {
          rowDays[c] = day;
        }
      }
      if (rowDays.length >= 3) {
        headerDays = rowDays;
        headerRowIndex = r;
        break;
      }
    }

    if (headerDays.isEmpty || headerRowIndex == -1) return slots;

    bool rowHasClassData(List<String> row) {
      for (final col in headerDays.keys) {
        if (col < row.length && row[col].trim().isNotEmpty) {
          return true;
        }
      }
      return false;
    }

    final maxCols = grid.fold<int>(
      0,
      (max, row) => row.length > max ? row.length : max,
    );
    int timeColumn = 0;
    int timeMatchCount = -1;
    for (int c = 0; c < maxCols; c++) {
      if (headerDays.containsKey(c)) continue;
      int matches = 0;
      for (int r = headerRowIndex + 1; r < grid.length; r++) {
        if (c >= grid[r].length) continue;
        if (parseTimeRange(grid[r][c]).start != null) {
          matches++;
        }
      }
      if (matches > timeMatchCount) {
        timeMatchCount = matches;
        timeColumn = c;
      }
    }

    int inferEndMinutes(int rowIndex, int startMinutes) {
      for (int r = rowIndex + 1; r < grid.length; r++) {
        final row = grid[r];
        if (timeColumn >= row.length) {
          if (rowHasClassData(row)) break;
          continue;
        }

        final candidate = parseTimeRange(row[timeColumn]).start;
        if (candidate != null && candidate > startMinutes) {
          return candidate;
        }
      }
      return startMinutes + 50;
    }

    for (int r = headerRowIndex + 1; r < grid.length; r++) {
      final row = grid[r];
      if (row.isEmpty || !rowHasClassData(row)) continue;
      if (timeColumn >= row.length) continue;

      final timeRange = parseTimeRange(row[timeColumn]);
      final startMin = timeRange.start;
      if (startMin == null) continue;
      final inferredEnd = timeRange.end ?? inferEndMinutes(r, startMin);
      final endMin = inferredEnd > startMin ? inferredEnd : startMin + 50;

      for (final entry in headerDays.entries) {
        final c = entry.key;
        if (c >= row.length) continue;
        final className = row[c].trim();
        if (className.isEmpty) continue;
        slots.add(TimeSlotClass(
          title: className,
          dayOfWeek: entry.value,
          startMinutes: startMin,
          endMinutes: endMin,
        ));
      }
    }

    return slots;
  }

}

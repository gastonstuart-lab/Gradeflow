import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:icalendar_parser/icalendar_parser.dart';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import 'package:gradeflow/models/student.dart';
import 'package:gradeflow/models/class.dart';
import 'package:uuid/uuid.dart';

part 'file_import/file_import_classes.dart';
part 'file_import/file_import_detection.dart';

enum ImportFileType {
  roster, // Student names/IDs
  calendar, // School calendar with dates/events
  timetable, // Weekly class schedule
  examResults, // Scores/grades
  unknown,
}

class CalendarEvent {
  final DateTime start;
  final DateTime end;
  final String summary;
  final String? location;

  CalendarEvent({
    required this.start,
    required this.end,
    required this.summary,
    this.location,
  });
}

class FileTypeDetection {
  final ImportFileType type;
  final String message;
  final String suggestion;

  const FileTypeDetection({
    required this.type,
    required this.message,
    required this.suggestion,
  });
}

class ImportedStudent {
  final String? studentId;
  final String? chineseName;
  final String? englishFirstName;
  final String? englishLastName;
  final String? seatNo;
  final String? classCode;
  final bool isValid;
  final String? error;
  // Calendar detection
  ImportedStudent({
    this.studentId,
    this.chineseName,
    this.englishFirstName,
    this.englishLastName,
    this.seatNo,
    this.classCode,
    required this.isValid,
    this.error,
  });
}

class FileImportService {
  /// Parse .ics calendar bytes into structured events.
  List<CalendarEvent> parseIcs(Uint8List bytes) {
    final text = utf8.decode(bytes, allowMalformed: true);
    final parser = ICalendar.fromString(text);
    final events = <CalendarEvent>[];
    for (final comp in parser.data) {
      final vevents = comp['VEVENT'];
      if (vevents is List) {
        for (final e in vevents) {
          try {
            final dtStart = e['DTSTART']?.value;
            final dtEnd = e['DTEND']?.value;
            final summary = e['SUMMARY']?.value?.toString() ?? '';
            final location = e['LOCATION']?.value?.toString();
            if (dtStart is DateTime &&
                dtEnd is DateTime &&
                summary.isNotEmpty) {
              events.add(CalendarEvent(
                start: dtStart,
                end: dtEnd,
                summary: summary,
                location: location,
              ));
            }
          } catch (_) {
            continue;
          }
        }
      }
    }
    return events;
  }

  /// Extract the "best" table from a DOCX file as a 2D grid of cell text.
  /// Heuristic-based: prefers tables that contain weekday headers (Mon/Tue/一/二/...).
  List<List<String>> extractDocxBestTableGrid(Uint8List bytes) {
    if (bytes.isEmpty) return const [];

    final archive = ZipDecoder().decodeBytes(bytes);
    final docFile = archive.files
        .where((f) => f.name.replaceAll('\\', '/') == 'word/document.xml')
        .cast<ArchiveFile?>()
        .firstWhere((f) => f != null, orElse: () => null);
    if (docFile == null) return const [];

    final xmlStr =
        utf8.decode(docFile.content as List<int>, allowMalformed: true);
    final doc = XmlDocument.parse(xmlStr);

    final weekdayTokens = <String>{
      'mon',
      'tue',
      'wed',
      'thu',
      'fri',
      'sat',
      'sun',
      // Chinese weekday columns commonly used in TW schedules
      '一',
      '二',
      '三',
      '四',
      '五',
      '六',
      '日',
    };

    const scheduleTokens = <String>{
      'week',
      'date',
      'lesson',
      'subject',
      'goals',
      'activities',
      'tests',
      'quizzes',
      'remarks',
      'issues',
      'topic',
      'title',
      'unit',
      'homework',
      'notes',
      'assessment',
    };

    int scoreTable(List<List<String>> grid) {
      if (grid.isEmpty) return 0;

      int score = 0;
      for (final row in grid.take(8)) {
        for (final cell in row) {
          final t = cell.trim();
          if (t.isEmpty) continue;
          final lower = t.toLowerCase();
          if (weekdayTokens.contains(t) || weekdayTokens.contains(lower)) {
            score += 3;
          }
          for (final token in scheduleTokens) {
            if (lower.contains(token)) {
              score += 2;
              break;
            }
          }
          if (lower.contains('semester') ||
              lower.contains('fall') ||
              lower.contains('spring')) {
            score += 1;
          }
        }
      }
      // Prefer moderately sized grids (typical timetable/class schedule)
      if (grid.length >= 6) score += 1;
      if (grid.first.length >= 4) score += 2;
      if (grid.first.length >= 6) score += 1;
      return score;
    }

    List<List<String>>? best;
    int bestScore = -1;

    for (final tbl in doc.findAllElements('tbl', namespace: '*')) {
      final grid = <List<String>>[];
      for (final tr in tbl.findElements('tr', namespace: '*')) {
        final row = <String>[];
        for (final tc in tr.findElements('tc', namespace: '*')) {
          final texts = tc
              .findAllElements('t', namespace: '*')
              .map((e) => e.innerText)
              .where((s) => s.trim().isNotEmpty)
              .toList();
          row.add(texts.join(' ').trim());
        }
        // Keep empty rows if they contain some structure
        if (row.isNotEmpty) grid.add(row);
      }
      if (grid.isEmpty) continue;

      final s = scoreTable(grid);
      if (s > bestScore) {
        bestScore = s;
        best = grid;
      }
    }

    return best ?? const [];
  }

  /// Cleans up a timetable grid by removing duplicate/empty rows and merging period blocks.
  /// Typical school timetable: Header + 4 class periods + lunch = 6-7 rows
  List<List<String>> cleanTimetableGrid(List<List<String>> rawGrid) {
    if (rawGrid.isEmpty) return rawGrid;

    // Helper: check if a row is meaningful (has actual class/time data)
    bool isMeaningfulRow(List<String> row) {
      if (row.length <= 1) return false;
      for (int i = 1; i < row.length; i++) {
        final cell = row[i].trim().toLowerCase();
        if (cell.isEmpty || cell == 'class') continue;
        return true;
      }
      return false;
    }

    // Helper: check if row looks like a lunch period
    bool isLunchRow(List<String> row) {
      if (row.isEmpty) return false;
      final firstCell = row.first.toLowerCase();
      return firstCell.contains('lunch') ||
          firstCell.contains('12:') ||
          firstCell.contains('13:');
    }

    // Helper: extract hour:minute from time string
    List<int>? parseTime(String timeStr) {
      final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(timeStr.trim());
      if (match != null) {
        final h = int.tryParse(match.group(1) ?? '');
        final m = int.tryParse(match.group(2) ?? '');
        if (h != null && m != null) return [h, m];
      }
      return null;
    }

    // Helper: check if two times are consecutive (45-55 minutes apart, typical for class periods)
    bool areConsecutiveTimes(String time1, String time2) {
      final t1 = parseTime(time1);
      final t2 = parseTime(time2);
      if (t1 == null || t2 == null) return false;
      final mins1 = t1[0] * 60 + t1[1];
      final mins2 = t2[0] * 60 + t2[1];
      final diff = mins2 - mins1;
      return diff >= 45 && diff <= 55;
    }

    final cleaned = <List<String>>[];
    cleaned.add(rawGrid.first);

    List<String>? previousRow;
    for (int i = 1; i < rawGrid.length; i++) {
      final row = rawGrid[i];

      if (isLunchRow(row)) {
        cleaned.add(row);
        previousRow = null;
        continue;
      }

      if (!isMeaningfulRow(row)) {
        continue;
      }

      if (previousRow != null &&
          row.length == previousRow.length &&
          previousRow.isNotEmpty &&
          row.isNotEmpty &&
          areConsecutiveTimes(previousRow[0], row[0])) {
        bool isSameClass = true;
        for (int col = 1; col < row.length; col++) {
          final prevCell = previousRow[col].trim();
          final currCell = row[col].trim();
          if (prevCell.isNotEmpty &&
              currCell.isNotEmpty &&
              prevCell != currCell) {
            isSameClass = false;
            break;
          }
        }

        if (isSameClass) {
          final mergedRow = List<String>.from(previousRow);
          final prevTime = previousRow[0].trim();
          final currTime = row[0].trim();
          final t1 = parseTime(prevTime);
          final t2 = parseTime(currTime);
          if (t1 != null && t2 != null) {
            final endMins = t2[0] * 60 + t2[1] + 50;
            final endH = (endMins ~/ 60) % 24;
            final endM = endMins % 60;
            mergedRow[0] =
                '$prevTime-${endH.toString().padLeft(2, '0')}:${endM.toString().padLeft(2, '0')}';
          }
          for (int col = 1; col < row.length; col++) {
            if (mergedRow[col].trim().isEmpty && row[col].trim().isNotEmpty) {
              mergedRow[col] = row[col];
            }
          }
          cleaned[cleaned.length - 1] = mergedRow;
          continue;
        }
      }

      cleaned.add(row);
      previousRow = row;
    }

    return cleaned;
  }

  // --------------------
  // CSV: Students Roster
  // --------------------
  List<ImportedStudent> parseCSV(String csvContent) {
    try {
      final rows = _parseDelimitedText(csvContent);
      if (rows.isEmpty) return [];

      final headerRowIndex = _pickHeaderRowIndex(rows);
      if (headerRowIndex < 0 || headerRowIndex >= rows.length) return [];
      final headers = rows[headerRowIndex].map(_normalizeName).toList();

      if (_looksLikeCalendarScheduleHeaders(headers)) {
        return [
          ImportedStudent(
            isValid: false,
            error:
                'This file looks like a calendar/schedule, not a student roster. Use Planner for school-wide calendars or Class Workspace > Schedule for class schedules.',
          ),
        ];
      }

      final analysisRows = rows.sublist(headerRowIndex);

      // Use smart auto-detection
      final cols = _autoDetectColumns(headers, analysisRows);
      final studentIdIndex = cols['studentId'] ?? -1;
      final chineseNameIndex = cols['chineseName'] ?? -1;
      final firstNameIndex = cols['firstName'] ?? -1;
      final lastNameIndex = cols['lastName'] ?? -1;
      final englishNameIndex = cols['englishName'] ?? -1;
      final seatNoIndex = cols['seatNo'] ?? -1;
      final classCodeIndex = cols['classCode'] ?? -1;
      final formIndex = cols['form'] ?? -1;

      final results = <ImportedStudent>[];

      for (int i = headerRowIndex + 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.every((c) => c.trim().isEmpty)) continue;

        final studentId = studentIdIndex != -1 && studentIdIndex < row.length
            ? row[studentIdIndex].trim()
            : null;
        String? chineseName =
            chineseNameIndex != -1 && chineseNameIndex < row.length
                ? row[chineseNameIndex].trim()
                : null;
        String? firstName = firstNameIndex != -1 && firstNameIndex < row.length
            ? row[firstNameIndex].trim()
            : null;
        String? lastName = lastNameIndex != -1 && lastNameIndex < row.length
            ? row[lastNameIndex].trim()
            : null;
        // Fallback: combined English name in a single column
        if ((firstName == null || firstName.isEmpty) ||
            (lastName == null || lastName.isEmpty)) {
          final englishName =
              englishNameIndex != -1 && englishNameIndex < row.length
                  ? row[englishNameIndex].trim()
                  : null;
          if (englishName != null && englishName.isNotEmpty) {
            final parts = englishName
                .split(RegExp(r'\s+'))
                .where((p) => p.isNotEmpty)
                .toList();
            if (parts.length >= 2) {
              firstName = parts.sublist(0, parts.length - 1).join(' ');
              lastName = parts.last;
            } else {
              // Single token: duplicate to satisfy required fields
              firstName = parts.first;
              lastName = parts.first;
            }
          }
        }
        final seatNo = seatNoIndex != -1 && seatNoIndex < row.length
            ? row[seatNoIndex].trim()
            : null;
        String? classCode = classCodeIndex != -1 && classCodeIndex < row.length
            ? row[classCodeIndex].trim()
            : null;
        final form = formIndex != -1 && formIndex < row.length
            ? row[formIndex].trim()
            : null;
        if (form != null && form.isNotEmpty) {
          // If both form and class present, combine (e.g., J2 + F => J2F); if only form, use it
          if (classCode != null && classCode.isNotEmpty) {
            classCode =
                '${form.replaceAll(' ', '')}${classCode.replaceAll(' ', '')}';
          } else {
            classCode = form.replaceAll(' ', '');
          }
        }

        // Make import forgiving: accept either Chinese or English name and auto-fill the other.
        final hasEnglish = (firstName != null && firstName.isNotEmpty) &&
            (lastName != null && lastName.isNotEmpty);
        final hasChinese = chineseName != null && chineseName.isNotEmpty;
        if (!hasChinese && hasEnglish) {
          chineseName = '$firstName $lastName'.trim();
        }
        if (!hasEnglish && hasChinese) {
          firstName = chineseName;
          lastName = chineseName;
        }

        if (studentId == null || studentId.isEmpty) {
          results.add(ImportedStudent(
            studentId: studentId,
            chineseName: chineseName,
            englishFirstName: firstName,
            englishLastName: lastName,
            seatNo: seatNo,
            classCode: classCode,
            isValid: false,
            error: 'Student ID is required',
          ));
          continue;
        }

        final finalHasEnglish = (firstName != null && firstName.isNotEmpty) &&
            (lastName != null && lastName.isNotEmpty);
        final finalHasChinese = chineseName != null && chineseName.isNotEmpty;
        if (!finalHasEnglish && !finalHasChinese) {
          results.add(ImportedStudent(
            studentId: studentId,
            chineseName: chineseName,
            englishFirstName: firstName,
            englishLastName: lastName,
            seatNo: seatNo,
            classCode: classCode,
            isValid: false,
            error: 'A name is required (Chinese or English)',
          ));
          continue;
        }

        results.add(ImportedStudent(
          studentId: studentId,
          chineseName: chineseName,
          englishFirstName: firstName,
          englishLastName: lastName,
          seatNo: seatNo,
          classCode: classCode,
          isValid: true,
        ));
      }

      return results;
    } catch (e) {
      debugPrint('Failed to parse CSV: $e');
      return [];
    }
  }

  // --------------------
  // Excel (XLSX): Students Roster
  // --------------------
  List<ImportedStudent> parseXlsxRoster(Uint8List bytes,
      {String? teacherName}) {
    try {
      // First pass: handle school-wide, multi-sheet roster workbooks where
      // each row may contain repeated student blocks (e.g. Cls/Seat/ID/Name...).
      final schoolWide =
          _parseSchoolWideRosterWorkbook(bytes, teacherName: teacherName);
      if (schoolWide.isNotEmpty) {
        return schoolWide;
      }

      final rows = _rowsFromExcel(bytes);
      if (rows.isEmpty) return [];

      final headerRowIndex = _pickHeaderRowIndex(rows);
      if (headerRowIndex < 0 || headerRowIndex >= rows.length) return [];
      final headers = rows[headerRowIndex].map(_normalizeName).toList();

      if (_looksLikeCalendarScheduleHeaders(headers)) {
        return [
          ImportedStudent(
            isValid: false,
            error:
                'This file looks like a calendar/schedule, not a student roster. Use Planner for school-wide calendars or Class Workspace > Schedule for class schedules.',
          ),
        ];
      }

      final analysisRows = rows.sublist(headerRowIndex);

      // Use smart auto-detection
      final cols = _autoDetectColumns(headers, analysisRows);
      final studentIdIndex = cols['studentId'] ?? -1;
      final chineseNameIndex = cols['chineseName'] ?? -1;
      final firstNameIndex = cols['firstName'] ?? -1;
      final lastNameIndex = cols['lastName'] ?? -1;
      final englishNameIndex = cols['englishName'] ?? -1;
      final seatNoIndex = cols['seatNo'] ?? -1;
      final classCodeIndex = cols['classCode'] ?? -1;
      final formIndex = cols['form'] ?? -1;

      final results = <ImportedStudent>[];

      for (int i = headerRowIndex + 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.every((c) => c.trim().isEmpty)) continue;
        String? cell(int idx) =>
            idx != -1 && idx < row.length ? row[idx].toString().trim() : null;

        final studentId = cell(studentIdIndex);
        String? chineseName = cell(chineseNameIndex);
        String? firstName = cell(firstNameIndex);
        String? lastName = cell(lastNameIndex);
        // Fallback: combined English name
        if ((firstName == null || firstName.isEmpty) ||
            (lastName == null || lastName.isEmpty)) {
          final englishName = cell(englishNameIndex);
          if (englishName != null && englishName.isNotEmpty) {
            final parts = englishName
                .split(RegExp(r'\s+'))
                .where((p) => p.isNotEmpty)
                .toList();
            if (parts.length >= 2) {
              firstName = parts.sublist(0, parts.length - 1).join(' ');
              lastName = parts.last;
            } else {
              firstName = parts.first;
              lastName = parts.first;
            }
          }
        }
        final seatNo = cell(seatNoIndex);
        String? classCode = cell(classCodeIndex);
        final form = cell(formIndex);
        if (form != null && form.isNotEmpty) {
          if (classCode != null && classCode.isNotEmpty) {
            classCode =
                '${form.replaceAll(' ', '')}${classCode.replaceAll(' ', '')}';
          } else {
            classCode = form.replaceAll(' ', '');
          }
        }

        // Make import forgiving: accept either Chinese or English name and auto-fill the other.
        final hasEnglish = (firstName != null && firstName.isNotEmpty) &&
            (lastName != null && lastName.isNotEmpty);
        final hasChinese = chineseName != null && chineseName.isNotEmpty;
        if (!hasChinese && hasEnglish) {
          chineseName = '$firstName $lastName'.trim();
        }
        if (!hasEnglish && hasChinese) {
          firstName = chineseName;
          lastName = chineseName;
        }

        if (studentId == null || studentId.isEmpty) {
          results.add(ImportedStudent(
            studentId: studentId,
            chineseName: chineseName,
            englishFirstName: firstName,
            englishLastName: lastName,
            seatNo: seatNo,
            classCode: classCode,
            isValid: false,
            error: 'Student ID is required',
          ));
          continue;
        }

        final finalHasEnglish = (firstName != null && firstName.isNotEmpty) &&
            (lastName != null && lastName.isNotEmpty);
        final finalHasChinese = chineseName != null && chineseName.isNotEmpty;
        if (!finalHasEnglish && !finalHasChinese) {
          results.add(ImportedStudent(
            studentId: studentId,
            chineseName: chineseName,
            englishFirstName: firstName,
            englishLastName: lastName,
            seatNo: seatNo,
            classCode: classCode,
            isValid: false,
            error: 'A name is required (Chinese or English)',
          ));
          continue;
        }

        results.add(ImportedStudent(
          studentId: studentId,
          chineseName: chineseName,
          englishFirstName: firstName,
          englishLastName: lastName,
          seatNo: seatNo,
          classCode: classCode,
          isValid: true,
        ));
      }

      return results;
    } catch (e) {
      debugPrint('Failed to parse XLSX roster: $e');
      return [];
    }
  }

  /// Best-effort extraction of class codes taught by a teacher from a school
  /// roster workbook. Used to preselect target classes in import UI.
  Set<String> inferClassCodesForTeacherFromRoster(
      Uint8List bytes, String teacherName) {
    try {
      final sheets = _xlsxSheetRowsFromZip(bytes);
      if (sheets.isEmpty) return const {};

      final normalizedTeacher = teacherName.trim().toLowerCase();
      if (normalizedTeacher.isEmpty) return const {};
      final teacherTokens = normalizedTeacher
          .split(RegExp(r'[^a-z0-9]+'))
          .where((t) => t.length >= 3)
          .toSet();

      bool cellMatchesTeacher(String raw) {
        final t = raw.trim().toLowerCase();
        if (t.isEmpty) return false;
        if (t.contains(normalizedTeacher)) return true;
        for (final token in teacherTokens) {
          if (t.contains(token)) return true;
        }
        return false;
      }

      bool looksLikeClassCode(String raw) {
        final t = raw.trim().toUpperCase();
        return RegExp(r'^[JH]\d[A-Z]{1,3}$').hasMatch(t);
      }

      final out = <String>{};
      for (final entry in sheets) {
        final sheetName = entry.name;
        final rows = entry.rows;
        if (rows.isEmpty) continue;

        bool teacherMatched = false;
        final scanRows = rows.length < 14 ? rows.length : 14;
        for (int r = 0; r < scanRows; r++) {
          for (final raw in rows[r]) {
            if (cellMatchesTeacher(raw)) {
              teacherMatched = true;
              break;
            }
          }
          if (teacherMatched) break;
        }
        if (!teacherMatched) continue;

        final inferred = _inferTeachingClassCodeFromSheetName(sheetName);
        if (inferred != null && inferred.isNotEmpty) {
          out.add(inferred);
        }

        // Also extract class codes from "Cls" columns in student rows.
        int? headerRow;
        List<int> classCols = const [];
        for (int r = 0; r < rows.length && r < 40; r++) {
          final normalized =
              rows[r].map((c) => c.trim().toLowerCase()).toList();
          final cols = <int>[];
          for (int i = 0; i < normalized.length; i++) {
            final h = normalized[i];
            if (h == 'cls' || h == 'class' || h.contains('class')) cols.add(i);
          }
          if (cols.isNotEmpty) {
            headerRow = r;
            classCols = cols;
            break;
          }
        }
        if (headerRow == null || classCols.isEmpty) continue;

        for (int r = headerRow + 1; r < rows.length; r++) {
          final row = rows[r];
          if (row.isEmpty) continue;
          for (final col in classCols) {
            if (col >= row.length) continue;
            final code = row[col].trim().toUpperCase();
            if (looksLikeClassCode(code)) out.add(code);
          }
        }
      }

      return out;
    } catch (_) {
      return const {};
    }
  }

  List<ImportedStudent> _parseSchoolWideRosterWorkbook(Uint8List bytes,
      {String? teacherName}) {
    try {
      final sheets = _xlsxSheetRowsFromZip(bytes);
      if (sheets.isEmpty) return const [];

      final out = <ImportedStudent>[];
      final seen = <String>{};
      final normalizedTeacher = (teacherName ?? '').trim().toLowerCase();
      final teacherTokens = normalizedTeacher
          .split(RegExp(r'[^a-z0-9]+'))
          .where((t) => t.length >= 3)
          .toSet();
      final teacherFilterEnabled = normalizedTeacher.isNotEmpty;

      bool isLikelyRosterHeader(List<String> row) {
        final norm = row.map(_normalizeName).toList();
        final hasClass = norm.any((c) =>
            c == 'class' ||
            c == 'cls' ||
            c.contains('class') ||
            c.contains('classname'));
        final hasSeat = norm.any((c) => c.contains('seat'));
        final hasId = norm.any((c) => c == 'id' || c.contains('studentid'));
        final hasName = norm.any((c) =>
            c == 'name' ||
            c.contains('chinesename') ||
            c.contains('firstname') ||
            c.contains('lastname'));
        return hasClass && hasSeat && hasId && hasName;
      }

      bool hasStudentDataInBlock(List<String> row, int startCol) {
        final classCode = _safeCell(row, startCol);
        final seat = _safeCell(row, startCol + 1);
        final id = _safeCell(row, startCol + 2);
        final name = _safeCell(row, startCol + 3);
        final first = _safeCell(row, startCol + 4);
        final last = _safeCell(row, startCol + 5);

        final hasAnyName =
            name.isNotEmpty || first.isNotEmpty || last.isNotEmpty;
        final hasLikelyId = RegExp(r'^\d{5,}$').hasMatch(_normalizeNumber(id));
        final hasLikelySeat =
            int.tryParse(_normalizeNumber(seat)) != null && seat.isNotEmpty;
        final hasClassCode = classCode.isNotEmpty &&
            RegExp(r'^[A-Za-z0-9\u4e00-\u9fff]{2,}$').hasMatch(classCode);

        return hasAnyName && (hasLikelyId || hasLikelySeat || hasClassCode);
      }

      ImportedStudent? parseBlock(
          List<String> row, int startCol, String? teachingClassCode) {
        final classCodeRaw = _safeCell(row, startCol);
        final seatRaw = _safeCell(row, startCol + 1);
        final idRaw = _safeCell(row, startCol + 2);
        final chineseNameRaw = _safeCell(row, startCol + 3);
        final firstRaw = _safeCell(row, startCol + 4);
        final lastRaw = _safeCell(row, startCol + 5);

        final studentId = _normalizeNumber(idRaw);
        final seatNo = _normalizeNumber(seatRaw);
        String? classCode =
            (teachingClassCode != null && teachingClassCode.trim().isNotEmpty)
                ? teachingClassCode.trim()
                : (classCodeRaw.trim().isEmpty
                    ? null
                    : classCodeRaw.trim().replaceAll(' ', ''));
        String? chineseName =
            chineseNameRaw.trim().isEmpty ? null : chineseNameRaw.trim();
        String? first =
            firstRaw.trim().isEmpty ? null : _normalizeNameToken(firstRaw);
        String? last =
            lastRaw.trim().isEmpty ? null : _normalizeNameToken(lastRaw);

        // Fallback: if Chinese name is absent but we have English parts.
        if ((chineseName == null || chineseName.isEmpty) &&
            (first != null && first.isNotEmpty) &&
            (last != null && last.isNotEmpty)) {
          chineseName = '$first $last';
        }

        // Fallback: if English parts are absent, mirror Chinese name.
        if ((first == null || first.isEmpty || last == null || last.isEmpty) &&
            chineseName != null &&
            chineseName.isNotEmpty) {
          first ??= chineseName;
          last ??= chineseName;
        }

        if (studentId.isEmpty) return null;
        if ((chineseName == null || chineseName.isEmpty) &&
            ((first == null || first.isEmpty) ||
                (last == null || last.isEmpty))) {
          return null;
        }

        final dedupeKey = '${classCode ?? ''}|$studentId';
        if (seen.contains(dedupeKey)) return null;
        seen.add(dedupeKey);

        return ImportedStudent(
          studentId: studentId,
          chineseName: chineseName,
          englishFirstName: first,
          englishLastName: last,
          seatNo: seatNo.isEmpty ? null : seatNo,
          classCode: classCode,
          isValid: true,
        );
      }

      for (final entry in sheets) {
        final teachingClassCode =
            _inferTeachingClassCodeFromSheetName(entry.name);
        final rows = entry.rows;
        if (rows.isEmpty) continue;

        for (int r = 0; r < rows.length; r++) {
          final row = rows[r];
          if (!isLikelyRosterHeader(row)) continue;

          // Determine where repeated 6-column roster blocks begin.
          final blockStarts = <int>[];
          final nRow = row.map(_normalizeName).toList();
          for (int c = 0; c < nRow.length; c++) {
            final h = nRow[c];
            if (h == 'cls' || h == 'class' || h.contains('classname')) {
              blockStarts.add(c);
            }
          }

          if (blockStarts.isEmpty) {
            blockStarts.add(0);
          }
          final teacherByBlock = <int, String>{};
          for (final start in blockStarts) {
            teacherByBlock[start] =
                _inferTeacherForRosterBlock(rows, r, start).trim();
          }
          final sheetTeacherMatched = !teacherFilterEnabled
              ? true
              : _sheetLikelyBelongsToTeacher(
                  rows, r, normalizedTeacher, teacherTokens);

          for (int rr = r + 1; rr < rows.length; rr++) {
            final dataRow = rows[rr];
            if (dataRow.every((c) => c.trim().isEmpty)) continue;
            if (isLikelyRosterHeader(dataRow)) break;

            var foundAny = false;
            for (final start in blockStarts) {
              if (teacherFilterEnabled) {
                final blockTeacher = teacherByBlock[start] ?? '';
                final blockMatches = _matchesTeacherName(
                    blockTeacher, normalizedTeacher, teacherTokens);
                if (!blockMatches && !sheetTeacherMatched) {
                  continue;
                }
              }
              if (start + 2 >= dataRow.length) continue;
              if (!hasStudentDataInBlock(dataRow, start)) continue;
              final parsed = parseBlock(dataRow, start, teachingClassCode);
              if (parsed != null) {
                out.add(parsed);
                foundAny = true;
              }
            }

            // If a row in the section has no parseable student blocks, and
            // looks like section metadata, keep scanning. If it's fully blank,
            // continue.
            if (!foundAny &&
                dataRow.where((c) => c.trim().isNotEmpty).length <= 1) {
              continue;
            }
          }
        }
      }

      return out;
    } catch (e) {
      debugPrint('School-wide roster parse fallback failed: $e');
      return const [];
    }
  }

  String _safeCell(List<String> row, int idx) {
    if (idx < 0 || idx >= row.length) return '';
    return row[idx].trim();
  }

  String _normalizeNumber(String raw) {
    var value = raw.trim();
    if (value.isEmpty) return value;
    if (value.endsWith('.0')) {
      value = value.substring(0, value.length - 2);
    }
    value = value.replaceAll(',', '').trim();
    return value;
  }

  String _normalizeNameToken(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return trimmed;
    return trimmed.replaceAll(RegExp(r'\s+'), ' ');
  }

  String? _inferTeachingClassCodeFromSheetName(String sheetName) {
    final compact = sheetName.replaceAll(' ', '').toUpperCase();

    // Prefer patterns like "J2-EEP-FG" => J2FG or "J1-ESL-ABC" => J1ABC.
    final grouped = RegExp(r'([JH]\d)[^A-Z0-9]*[A-Z]+[^A-Z0-9]*([A-Z]{1,3})')
        .firstMatch(compact);
    if (grouped != null) {
      return '${grouped.group(1)}${grouped.group(2)}';
    }

    // Fallback direct code in sheet name like J2FG.
    final direct = RegExp(r'([JH]\d[A-Z]{1,3})').firstMatch(compact);
    if (direct != null) return direct.group(1);

    return null;
  }

  bool _matchesTeacherName(
      String raw, String normalizedTeacher, Set<String> teacherTokens) {
    final v = raw.trim().toLowerCase();
    if (v.isEmpty || normalizedTeacher.isEmpty) return false;
    if (v.contains(normalizedTeacher)) return true;
    for (final token in teacherTokens) {
      if (v.contains(token)) return true;
    }
    return false;
  }

  bool _sheetLikelyBelongsToTeacher(List<List<String>> rows, int headerRow,
      String normalizedTeacher, Set<String> teacherTokens) {
    final scanTo = headerRow < 14 ? headerRow : 14;
    for (int r = 0; r < scanTo; r++) {
      final row = rows[r];
      for (final cell in row) {
        if (_matchesTeacherName(cell, normalizedTeacher, teacherTokens)) {
          return true;
        }
      }
    }
    return false;
  }

  String _inferTeacherForRosterBlock(
      List<List<String>> rows, int headerRow, int blockStart) {
    final minRow = headerRow - 12 < 0 ? 0 : headerRow - 12;
    for (int r = headerRow - 1; r >= minRow; r--) {
      final candidate = _safeCell(rows[r], blockStart + 5);
      if (_looksLikeTeacherNameCell(candidate)) {
        return candidate;
      }
    }
    return '';
  }

  bool _looksLikeTeacherNameCell(String value) {
    final v = value.trim();
    if (v.isEmpty) return false;
    final lower = v.toLowerCase();
    if (RegExp(r'^\d+(\.\d+)?$').hasMatch(lower)) return false;
    if (lower.contains('teacher') ||
        lower.contains('subject') ||
        lower.contains('group') ||
        lower == 'cls' ||
        lower == 'class') {
      return false;
    }
    return true;
  }

  int _findColumnIndex(List<String> headers, List<String> possibleNames) {
    final normalized = headers.map(_normalizeName).toList();
    for (var raw in possibleNames) {
      final name = _normalizeName(raw);
      // Try exact match first
      final exact = normalized.indexWhere((h) => h == name);
      if (exact != -1) return exact;
      // Then contains (for headers like "student id number")
      final contains = normalized.indexWhere((h) => h.contains(name));
      if (contains != -1) return contains;
    }
    return -1;
  }

  // Smart auto-detection: analyze actual data to find columns
  Map<String, int> _autoDetectColumns(
      List<String> headers, List<List<String>> rows) {
    final result = <String, int>{};

    // First try header matching
    result['studentId'] = _findColumnIndex(headers, [
      'student id',
      'studentid',
      'id',
      'student no',
      'studentno',
      'stu id',
      'stuid',
      'student number',
      '學號',
      'no',
      'number',
      '#'
    ]);
    result['chineseName'] = _findColumnIndex(headers, [
      'chinese name',
      'chinesename',
      '中文名',
      '姓名',
      'name chinese',
      'chinese',
      '中文',
      '名字'
    ]);
    result['firstName'] = _findColumnIndex(headers, [
      'first name',
      'firstname',
      'english first name',
      'given name',
      'givenname',
      'eng first name',
      'eng firstname',
      'first',
      '英文名'
    ]);
    result['lastName'] = _findColumnIndex(headers, [
      'last name',
      'lastname',
      'english last name',
      'surname',
      'family name',
      'eng last name',
      'eng lastname',
      'last',
      '姓'
    ]);
    result['englishName'] = _findColumnIndex(headers, [
      'english name',
      'englishname',
      'eng name',
      'name english',
      'name (english)',
      'eng name',
      'name'
    ]);
    result['seatNo'] = _findColumnIndex(headers,
        ['seat no', 'seatno', 'seat', 'seat number', '座號', '號', 'no.', 'num']);
    result['classCode'] = _findColumnIndex(headers, [
      'class code',
      'classcode',
      'code',
      'class',
      '班別',
      '班級',
      'class name',
      'classname',
      '班',
      'section'
    ]);
    result['form'] = _findColumnIndex(headers, [
      'form',
      'grade',
      'year level',
      'yearlevel',
      'level',
      'form class',
      '級別',
      '年級',
      'year'
    ]);

    // Data-based detection if headers failed
    if (rows.length > 1) {
      final scannedRows = (rows.length - 1).clamp(1, 20);
      // Detect student ID by pattern: usually numeric, 4-10 digits
      if (result['studentId'] == -1) {
        for (int col = 0; col < headers.length; col++) {
          int numericCount = 0;
          int validIdCount = 0;
          for (int row = 1; row <= scannedRows; row++) {
            if (col >= rows[row].length) continue;
            final val =
                col < rows[row].length ? rows[row][col].toString().trim() : '';
            if (val.isEmpty) continue;
            if (RegExp(r'^\d{4,10}$').hasMatch(val)) validIdCount++;
            if (RegExp(r'^\d+$').hasMatch(val)) numericCount++;
          }
          if (validIdCount > scannedRows * 0.5 ||
              numericCount > scannedRows * 0.6) {
            result['studentId'] = col;
            break;
          }
        }
      }

      // Detect Chinese name by Unicode range
      if (result['chineseName'] == -1) {
        for (int col = 0; col < headers.length; col++) {
          int chineseCount = 0;
          for (int row = 1; row <= scannedRows; row++) {
            if (col >= rows[row].length) continue;
            final val =
                col < rows[row].length ? rows[row][col].toString().trim() : '';
            if (val.isEmpty) continue;
            if (RegExp(r'[\u4e00-\u9fff]+').hasMatch(val)) chineseCount++;
          }
          if (chineseCount > scannedRows * 0.5) {
            result['chineseName'] = col;
            break;
          }
        }
      }

      // Detect English names by Latin characters
      if (result['englishName'] == -1 &&
          (result['firstName'] == -1 || result['lastName'] == -1)) {
        for (int col = 0; col < headers.length; col++) {
          if (col == result['studentId'] || col == result['chineseName']) {
            continue;
          }
          int englishCount = 0;
          for (int row = 1; row <= scannedRows; row++) {
            if (col >= rows[row].length) continue;
            final val =
                col < rows[row].length ? rows[row][col].toString().trim() : '';
            if (val.isEmpty) continue;
            if (RegExp(r"^[a-zA-Z\s\.\-']+$").hasMatch(val) && val.length > 1) {
              englishCount++;
            }
          }
          if (englishCount > scannedRows * 0.5) {
            result['englishName'] = col;
            break;
          }
        }
      }

      // Detect seat number: usually small integers 1-50
      if (result['seatNo'] == -1) {
        for (int col = 0; col < headers.length; col++) {
          if (col == result['studentId']) continue;
          int validSeatCount = 0;
          for (int row = 1; row <= scannedRows; row++) {
            if (col >= rows[row].length) continue;
            final val =
                col < rows[row].length ? rows[row][col].toString().trim() : '';
            if (val.isEmpty) continue;
            final num = int.tryParse(val);
            if (num != null && num >= 1 && num <= 50) validSeatCount++;
          }
          if (validSeatCount > scannedRows * 0.4) {
            result['seatNo'] = col;
            break;
          }
        }
      }
    }

    return result;
  }

  List<List<String>> _parseDelimitedText(String text) {
    if (text.trim().isEmpty) return [];
    final delimiter = _guessDelimiter(text);
    final converter = CsvToListConverter(
        fieldDelimiter: delimiter, shouldParseNumbers: false);
    final parsed = converter.convert(text);
    final rows = parsed
        .map((r) => r.map((c) => (c ?? '').toString().trim()).toList())
        .toList();
    // Trim trailing empty cells per row
    for (final r in rows) {
      while (r.isNotEmpty && r.last.trim().isEmpty) {
        r.removeLast();
      }
    }
    // Drop leading all-empty rows
    while (rows.isNotEmpty && rows.first.every((c) => c.trim().isEmpty)) {
      rows.removeAt(0);
    }
    return rows;
  }

  String _guessDelimiter(String text) {
    // Inspect first non-empty line.
    final lines = text.split(RegExp(r'\r?\n'));
    String first = '';
    for (final l in lines) {
      if (l.trim().isNotEmpty) {
        first = l;
        break;
      }
    }
    if (first.isEmpty) return ',';
    final candidates = <String>[',', '\t', ';', '|'];
    int bestCount = -1;
    String best = ',';
    for (final c in candidates) {
      final count = _countOccurrences(first, c);
      if (count > bestCount) {
        bestCount = count;
        best = c;
      }
    }
    return best;
  }

  int _countOccurrences(String s, String needle) {
    if (needle.isEmpty) return 0;
    int count = 0;
    int idx = 0;
    while (true) {
      idx = s.indexOf(needle, idx);
      if (idx == -1) return count;
      count++;
      idx += needle.length;
    }
  }

  int _pickHeaderRowIndex(List<List<String>> rows) {
    final maxScan = rows.length.clamp(1, 20);
    int bestIdx = 0;
    int bestScore = -1;

    for (int i = 0; i < maxScan; i++) {
      final row = rows[i];
      final nonEmpty = row.where((c) => c.trim().isNotEmpty).length;
      if (nonEmpty < 2) continue;

      int headerHits = 0;
      int numericCells = 0;
      for (final raw in row) {
        final v = _normalizeName(raw);
        if (v.isEmpty) continue;
        if (RegExp(r'^\d+(\.\d+)?$').hasMatch(v)) numericCells++;
        if (v.contains('student') ||
            v == 'id' ||
            v.contains('name') ||
            v.contains('class') ||
            v.contains('seat') ||
            v.contains('學號') ||
            v.contains('姓名') ||
            v.contains('班')) {
          headerHits++;
        }
      }

      // Weight header hits heavily; penalize numeric-heavy rows.
      final score = (headerHits * 5) + nonEmpty - (numericCells * 2);
      if (score > bestScore) {
        bestScore = score;
        bestIdx = i;
      }
    }

    return bestIdx;
  }

  String _decodeUtf16(Uint8List bytes, {required bool littleEndian}) {
    if (bytes.isEmpty) return '';
    final len = bytes.length - (bytes.length % 2);
    final codeUnits = <int>[];
    for (int i = 0; i < len; i += 2) {
      final lo = bytes[i];
      final hi = bytes[i + 1];
      final unit = littleEndian ? (lo | (hi << 8)) : (hi | (lo << 8));
      codeUnits.add(unit);
    }
    return String.fromCharCodes(codeUnits);
  }

  String _normalizeName(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[_\-\./\\()\[\]:]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  List<Student> convertToStudents(
      List<ImportedStudent> importedStudents, String classId) {
    final now = DateTime.now();
    return importedStudents
        .where((i) => i.isValid)
        .map((i) => Student(
              studentId: i.studentId!,
              chineseName: i.chineseName!,
              englishFirstName: i.englishFirstName!,
              englishLastName: i.englishLastName!,
              seatNo: i.seatNo,
              classCode: i.classCode,
              photoBase64: null,
              classId: classId,
              createdAt: now,
              updatedAt: now,
            ))
        .toList();
  }

  // --------------------
  // CSV: Exam Scores
  // --------------------
  Map<String, double> parseExamScores(String csvContent) {
    try {
      final rows = const CsvToListConverter().convert(csvContent);

      if (rows.isEmpty || rows.length < 2) {
        return {};
      }

      final headers = rows[0].map((h) => _normalizeName(h.toString())).toList();
      final studentIdIndex = _findColumnIndex(headers, [
        'student id',
        'studentid',
        'id',
        'student no',
        'studentno',
        'stuid',
        '學號'
      ]);
      final scoreIndex = _findColumnIndex(headers, [
        'exam score',
        'examscore',
        'score',
        'final exam',
        'finalexam',
        'exam',
        '分數',
        '成績'
      ]);

      if (studentIdIndex == -1 || scoreIndex == -1) {
        return {};
      }

      final scores = <String, double>{};

      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];

        if (studentIdIndex < row.length && scoreIndex < row.length) {
          final studentId = row[studentIdIndex]?.toString().trim();
          final scoreStr = row[scoreIndex]?.toString().trim();

          if (studentId != null && scoreStr != null) {
            final score = double.tryParse(scoreStr);
            if (score != null && score >= 0 && score <= 100) {
              scores[studentId] = score;
            }
          }
        }
      }

      return scores;
    } catch (e) {
      debugPrint('Failed to parse exam scores: $e');
      return {};
    }
  }

  // --------------------
  // Excel (XLSX): Exam Scores
  // --------------------
  Map<String, double> parseExamScoresXlsx(Uint8List bytes) {
    try {
      final rows = _rowsFromExcel(bytes);
      if (rows.isEmpty || rows.length < 2) return {};

      final headers =
          rows.first.map((h) => _normalizeName(h.toString())).toList();
      final studentIdIndex = _findColumnIndex(headers, [
        'student id',
        'studentid',
        'id',
        'student no',
        'studentno',
        'stuid',
        '學號'
      ]);
      final scoreIndex = _findColumnIndex(headers, [
        'exam score',
        'examscore',
        'score',
        'final exam',
        'finalexam',
        'exam',
        '分數',
        '成績'
      ]);
      if (studentIdIndex == -1 || scoreIndex == -1) return {};

      final scores = <String, double>{};
      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (studentIdIndex < row.length && scoreIndex < row.length) {
          final studentId = row[studentIdIndex].toString().trim();
          final scoreStr = row[scoreIndex].toString().trim();
          if (studentId.isNotEmpty && scoreStr.isNotEmpty) {
            final score = double.tryParse(scoreStr);
            if (score != null && score >= 0 && score <= 100) {
              scores[studentId] = score;
            }
          }
        }
      }
      return scores;
    } catch (e) {
      debugPrint('Failed to parse XLSX exam scores: $e');
      return {};
    }
  }

  // --------------------
  // Excel/CSV: Classes
  // --------------------
}

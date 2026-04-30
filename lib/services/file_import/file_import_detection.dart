part of '../file_import_service.dart';

extension FileImportServiceDetection on FileImportService {
  ClassSyllabus? parseClassSyllabusFromBytes(Uint8List bytes,
      {required String filename}) {
    final rows = rowsFromAnyBytes(bytes);
    return parseClassSyllabusFromRows(rows, filename: filename);
  }

  ClassSyllabus? parseClassSyllabusFromRows(List<List<String>> rows,
      {String? filename}) {
    if (rows.isEmpty) return null;

    String norm(String s) => _normalizeName(s);
    bool hasAll(List<String> row, List<String> keys) {
      final set = row.map(norm).where((e) => e.isNotEmpty).toSet();
      return keys.every(set.contains);
    }

    int? headerIdx;
    for (var i = 0; i < rows.length; i++) {
      final r = rows[i];
      if (r.isEmpty) continue;
      if (hasAll(r, const ['week', 'date', 'lessoncontent'])) {
        headerIdx = i;
        break;
      }
      // Common variant: "Lesson Content" split across cells or different spacing
      final normalized = r.map(norm).toList();
      final hasWeek = normalized.contains('week');
      final hasDate = normalized.contains('date');
      final hasLesson = normalized.any((c) => c.contains('lesson')) &&
          normalized.any((c) => c.contains('content'));
      if (hasWeek && hasDate && hasLesson) {
        headerIdx = i;
        break;
      }
    }

    if (headerIdx == null) return null;

    final headerLines = <String>[];
    for (var i = 0; i < headerIdx; i++) {
      final text = rows[i].join(' ').trim();
      if (text.isEmpty) continue;
      headerLines.add(text);
      if (headerLines.length >= 12) break;
    }

    int idxWeek = -1;
    int idxDate = -1;
    int idxLesson = -1;
    int idxEvent = -1;

    String? currentSection;
    final entries = <ClassSyllabusEntry>[];

    void readHeader(List<String> r) {
      final normalized = r.map(norm).toList();
      idxWeek = normalized.indexOf('week');
      idxDate = normalized.indexOf('date');
      // lesson content may appear as one cell or two adjacent cells
      idxLesson = normalized.indexWhere((c) => c == 'lessoncontent');
      if (idxLesson == -1) {
        // best-effort: cell containing both words
        idxLesson = normalized
            .indexWhere((c) => c.contains('lesson') && c.contains('content'));
      }
      idxEvent = normalized.indexWhere((c) => c.contains('event'));
      if (idxEvent == -1) {
        idxEvent = normalized.indexWhere((c) => c.contains('dateevent'));
      }
    }

    readHeader(rows[headerIdx]);

    bool looksLikeBookSection(String s) {
      final t = s.trim();
      if (t.isEmpty) return false;
      return RegExp(r'^book\s*\d+\s*:', caseSensitive: false).hasMatch(t) ||
          RegExp(r'^book\s*\d+\b', caseSensitive: false).hasMatch(t);
    }

    bool looksLikeHeaderRow(List<String> r) {
      if (r.isEmpty) return false;
      final normalized = r.map(norm).toList();
      return normalized.contains('week') &&
          normalized.contains('date') &&
          (normalized.contains('lessoncontent') ||
              (normalized.any((c) => c.contains('lesson')) &&
                  normalized.any((c) => c.contains('content'))));
    }

    bool looksLikeWeek(String s) {
      final t = s.trim();
      if (t.isEmpty) return false;
      return RegExp(r'^\d{1,2}$').hasMatch(t) ||
          RegExp(r'^w\d{1,2}$', caseSensitive: false).hasMatch(t);
    }

    for (var i = headerIdx + 1; i < rows.length; i++) {
      final r = rows[i];
      if (r.isEmpty) continue;

      final first = (r.isNotEmpty ? r[0] : '').trim();
      if (looksLikeBookSection(first)) {
        currentSection = first;
        continue;
      }

      if (looksLikeHeaderRow(r)) {
        readHeader(r);
        continue;
      }

      if (idxWeek < 0 || idxDate < 0 || idxLesson < 0) {
        continue;
      }
      if (idxWeek >= r.length) continue;

      final week = r[idxWeek].trim();
      if (!looksLikeWeek(week)) {
        continue;
      }

      final dateRange =
          (idxDate >= 0 && idxDate < r.length) ? r[idxDate].trim() : '';
      final lessonContent =
          (idxLesson >= 0 && idxLesson < r.length) ? r[idxLesson].trim() : '';
      final dateEvents =
          (idxEvent >= 0 && idxEvent < r.length) ? r[idxEvent].trim() : '';

      if (dateRange.isEmpty && lessonContent.isEmpty && dateEvents.isEmpty) {
        continue;
      }

      entries.add(ClassSyllabusEntry(
        section: currentSection,
        week: week,
        dateRange: dateRange,
        lessonContent: lessonContent,
        dateEvents: dateEvents.isEmpty ? null : dateEvents,
      ));
    }

    if (entries.isEmpty) return null;
    return ClassSyllabus(
      sourceFilename: filename,
      headerLines: headerLines,
      entries: entries,
      extractedAt: DateTime.now(),
    );
  }

  bool _looksLikeCalendarScheduleHeaders(List<String> headers) {
    final normalized = headers
        .map(_normalizeName)
        .where((h) => h.isNotEmpty)
        .toList(growable: false);

    if (!normalized.contains('week')) {
      return false;
    }

    const dayKeys = {
      'sun',
      'mon',
      'tue',
      'wed',
      'thu',
      'fri',
      'sat',
      // Some templates use single-letter day columns.
      's',
      'm',
      't',
      'w',
      'f',
    };

    final dayCount = normalized.where(dayKeys.contains).length;
    final hasDateOrEvent =
        normalized.any((h) => h.contains('date') || h.contains('event'));
    final hasMonth = normalized.contains('month');
    final hasDateStamp = normalized.any(
      (h) => RegExp(r'^\d{4}\s+\d{1,2}\s+\d{1,2}$').hasMatch(h),
    );

    return dayCount >= 5 && (hasMonth || hasDateOrEvent || hasDateStamp);
  }

  /// Intelligently detect what type of file this is based on headers and content
  FileTypeDetection detectFileType(Uint8List bytes,
      {required String filename}) {
    final lowerName = filename.toLowerCase();
    if (lowerName.endsWith('.ics')) {
      return const FileTypeDetection(
        type: ImportFileType.calendar,
        message: 'Calendar file detected (.ics)',
        suggestion: 'Import this in Planner for school-wide events.',
      );
    }

    try {
      final isZip = bytes.length > 3 && bytes[0] == 0x50 && bytes[1] == 0x4B;
      List<String> headers = [];

      if (isZip) {
        final rows = rowsFromAnyBytes(bytes);
        if (rows.isNotEmpty) {
          final headerIdx = _pickHeaderRowIndex(rows);
          headers = (headerIdx >= 0 && headerIdx < rows.length)
              ? rows[headerIdx].map(_normalizeName).toList()
              : rows.first.map(_normalizeName).toList();
        }
      } else {
        final text = decodeTextFromBytes(bytes);
        final rows = _parseDelimitedText(text);
        if (rows.isNotEmpty) {
          final headerIdx = _pickHeaderRowIndex(rows);
          headers = (headerIdx >= 0 && headerIdx < rows.length)
              ? rows[headerIdx].map(_normalizeName).toList()
              : rows.first.map(_normalizeName).toList();
        }
      }

      // Calendar detection
      if (_looksLikeCalendarScheduleHeaders(headers)) {
        return const FileTypeDetection(
          type: ImportFileType.calendar,
          message: 'This looks like a school calendar or schedule.',
          suggestion:
              'Import school-wide calendars in Planner, or class schedules in Class Workspace > Schedule.',
        );
      }

      // Timetable detection (weekly class periods)
      if (_looksLikeTimetable(headers)) {
        return const FileTypeDetection(
          type: ImportFileType.timetable,
          message: 'This looks like a weekly timetable/schedule.',
          suggestion:
              'Import teacher timetables in Planner, or class schedules in Class Workspace > Schedule.',
        );
      }

      // Exam results detection (has score/grade columns)
      if (_looksLikeExamResults(headers)) {
        return const FileTypeDetection(
          type: ImportFileType.examResults,
          message: 'This looks like exam results or gradebook data.',
          suggestion: 'Import this in Class Workspace > Exams.',
        );
      }

      // Roster detection (has student name/ID fields)
      if (_looksLikeRoster(headers)) {
        return const FileTypeDetection(
          type: ImportFileType.roster,
          message: 'This looks like a student roster.',
          suggestion:
              'You\'re in the right place! Use the import function on this screen.',
        );
      }

      return const FileTypeDetection(
        type: ImportFileType.unknown,
        message: 'Could not determine file type.',
        suggestion:
            'Make sure the file has clear column headers like: Name, Student ID, Email',
      );
    } catch (e) {
      return FileTypeDetection(
        type: ImportFileType.unknown,
        message: 'Error analyzing file: $e',
        suggestion: 'Try re-saving the file as CSV (UTF-8)',
      );
    }
  }

  bool _looksLikeTimetable(List<String> headers) {
    final normalized = headers.where((h) => h.isNotEmpty).toList();

    // Look for period/time indicators
    final hasPeriod = normalized.any((h) =>
        h.contains('period') || h.contains('time') || h.contains('class'));

    // Look for weekday columns
    const weekdays = {
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'mon',
      'tue',
      'wed',
      'thu',
      'fri'
    };
    final weekdayCount =
        normalized.where((h) => weekdays.any(h.contains)).length;

    return hasPeriod && weekdayCount >= 3;
  }

  bool _looksLikeExamResults(List<String> headers) {
    final normalized = headers.where((h) => h.isNotEmpty).toList();

    // Look for score/grade indicators
    final hasScores = normalized.any((h) =>
        h.contains('score') ||
        h.contains('grade') ||
        h.contains('mark') ||
        h.contains('result') ||
        h.contains('exam') ||
        h.contains('test'));

    // Look for student identifier
    final hasStudent = normalized.any(
        (h) => h.contains('name') || h.contains('student') || h.contains('id'));

    return hasScores && hasStudent;
  }

  bool _looksLikeRoster(List<String> headers) {
    final normalized = headers.where((h) => h.isNotEmpty).toList();

    // Must have name field
    final hasName =
        normalized.any((h) => h.contains('name') || h.contains('student'));

    // Should have ID or email
    final hasIdentifier = normalized.any(
        (h) => h.contains('id') || h.contains('email') || h.contains('number'));

    // Should NOT look like scores/exams
    final looksLikeScores = normalized.any(
        (h) => h.contains('score') || h.contains('exam') || h.contains('test'));

    return hasName && hasIdentifier && !looksLikeScores;
  }

  /// Best-effort decode for CSV-ish text exported from Excel.
  /// Handles UTF-8 (with/without BOM) and UTF-16LE/BE.
  String decodeTextFromBytes(Uint8List bytes) {
    if (bytes.isEmpty) return '';

    // UTF-8 BOM
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      return utf8.decode(bytes.sublist(3), allowMalformed: true);
    }

    // UTF-16 BOM
    if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
      // UTF-16LE
      return _decodeUtf16(bytes.sublist(2), littleEndian: true);
    }
    if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
      // UTF-16BE
      return _decodeUtf16(bytes.sublist(2), littleEndian: false);
    }

    // Heuristic: if many NUL bytes, it's likely UTF-16 without BOM.
    int nulCount = 0;
    final sampleLen = bytes.length.clamp(0, 512);
    for (int i = 0; i < sampleLen; i++) {
      if (bytes[i] == 0x00) nulCount++;
    }
    if (sampleLen > 0 && (nulCount / sampleLen) > 0.15) {
      // Guess endianness by where NULs appear.
      int nulEven = 0;
      int nulOdd = 0;
      for (int i = 0; i < sampleLen; i++) {
        if (bytes[i] != 0x00) continue;
        if (i.isEven) {
          nulEven++;
        } else {
          nulOdd++;
        }
      }
      final littleEndian = nulOdd > nulEven;
      return _decodeUtf16(bytes, littleEndian: littleEndian);
    }

    // Default UTF-8 with malformed allowed.
    return utf8.decode(bytes, allowMalformed: true);
  }

  /// Build a human-readable diagnostics string for troubleshooting imports.
  /// Safe to show in UI; includes only structural info (row counts, headers).
  String diagnosticsForFile(Uint8List bytes, {required String filename}) {
    final isZip = bytes.length > 3 && bytes[0] == 0x50 && bytes[1] == 0x4B;
    final lines = <String>[];
    lines.add('File: $filename');
    lines.add('Bytes: ${bytes.length}');
    lines.add('Looks like XLSX (ZIP): $isZip');

    try {
      if (!isZip) {
        final text = decodeTextFromBytes(bytes);
        final delim = _guessDelimiter(text);
        lines.add('Detected delimiter: ${delim == "\t" ? "TAB" : delim}');
        final rows = _parseDelimitedText(text);
        lines.add('Rows decoded: ${rows.length}');
        if (rows.isNotEmpty) {
          final headerIdx = _pickHeaderRowIndex(rows);
          lines.add('Header row index: $headerIdx');
          final hdr = (headerIdx >= 0 && headerIdx < rows.length)
              ? rows[headerIdx]
              : rows.first;
          lines.add('Header sample: ${hdr.take(12).toList()}');

          if (_looksLikeCalendarScheduleHeaders(hdr)) {
            lines.add(
                'Detected file type: calendar/schedule (not a student roster)');
            lines.add('Tip: Import schedules via Class Workspace > Schedule.');
          }
        }
        final roster = parseCSV(text);
        lines.add(
            'Roster parse: total=${roster.length} valid=${roster.where((r) => r.isValid).length} invalid=${roster.where((r) => !r.isValid).length}');
        final firstErr = roster.firstWhere((r) => !r.isValid,
            orElse: () => ImportedStudent(isValid: true));
        if (firstErr.isValid == false) {
          lines.add('First error: ${firstErr.error ?? ""}');
        }
      } else {
        final rows = rowsFromAnyBytes(bytes);
        lines.add('Rows extracted: ${rows.length}');
        if (rows.isNotEmpty) {
          final headerIdx = _pickHeaderRowIndex(rows);
          lines.add('Header row index: $headerIdx');
          final hdr = (headerIdx >= 0 && headerIdx < rows.length)
              ? rows[headerIdx]
              : rows.first;
          lines.add('Header sample: ${hdr.take(12).toList()}');
          lines.add(
              'First data row sample: ${(rows.length > headerIdx + 1 ? rows[headerIdx + 1] : const <String>[]).take(12).toList()}');

          if (_looksLikeCalendarScheduleHeaders(hdr)) {
            lines.add(
                'Detected file type: calendar/schedule (not a student roster)');
            lines.add('Tip: Import schedules via Class Workspace > Schedule.');
          }
        }
        final roster = parseXlsxRoster(bytes);
        lines.add(
            'Roster parse: total=${roster.length} valid=${roster.where((r) => r.isValid).length} invalid=${roster.where((r) => !r.isValid).length}');
        final firstErr = roster.firstWhere((r) => !r.isValid,
            orElse: () => ImportedStudent(isValid: true));
        if (firstErr.isValid == false) {
          lines.add('First error: ${firstErr.error ?? ""}');
        }
      }
    } catch (e) {
      lines.add('Diagnostics error: $e');
    }

    return lines.join('\n');
  }
}

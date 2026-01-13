import 'dart:convert';
import 'dart:typed_data';

import 'package:gradeflow/models/class_schedule_item.dart';
import 'package:gradeflow/services/file_import_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ClassScheduleService {
  static String _key(String classId) => 'class_schedule_v1:$classId';

  Future<List<ClassScheduleItem>> load(String classId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(classId));
    if (raw == null || raw.trim().isEmpty) return const [];

    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((m) => ClassScheduleItem.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  Future<void> save(String classId, List<ClassScheduleItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final data = items.map((i) => i.toJson()).toList();
    await prefs.setString(_key(classId), jsonEncode(data));
  }

  List<ClassScheduleItem> parseFromBytes(Uint8List bytes) {
    final rows = FileImportService().rowsFromAnyBytes(bytes);
    return parseFromRows(rows);
  }

  List<ClassScheduleItem> parseFromRows(List<List<String>> rows) {
    if (rows.isEmpty) return const [];

    int headerIdx = _pickHeaderRowIndex(rows);
    final header = rows[headerIdx].map(_norm).toList();

    final calendarEventIdx = _findCalendarEventColumnIndex(header);
    final calendarMonthIdx = _findHeaderIndex(header, ['month']);
    final calendarWeekIdx = _findHeaderIndex(header, ['week']);
    if (calendarEventIdx != -1) {
      return _parseCalendarEventFormat(
        rows,
        headerIdx: headerIdx,
        eventIdx: calendarEventIdx,
        monthIdx: calendarMonthIdx,
        weekIdx: calendarWeekIdx,
      );
    }

    int idxOf(List<String> keys) => _findHeaderIndex(header, keys);

    final dateIdx = idxOf(['date', 'day', '日期', '日期date']);
    final weekIdx = idxOf(['week', 'wk', '週', '周', 'week no', 'week number']);

    final titleIdx = idxOf([
      'topic',
      'title',
      'lesson',
      'unit',
      'theme',
      'content',
      '內容',
      '課程',
      '進度',
      'lesson focus'
    ]);

    final bookIdx = idxOf(['book', 'textbook', 'reader', '教材', '課本']);
    final chapterIdx = idxOf(['chapter', 'ch', 'unit', 'lesson', '章', '單元']);
    final pagesIdx = idxOf(['pages', 'page', 'pp', 'p.', '頁']);
    final homeworkIdx = idxOf(['homework', 'hw', 'assignment', '作業']);
    final notesIdx = idxOf(['notes', 'note', 'remark', 'remarks', '備註', '提醒']);
    final assessmentIdx =
        idxOf(['quiz', 'test', 'exam', 'assessment', '測驗', '考試']);
    final linkIdx = idxOf(
        ['link', 'url', 'resource', 'resources', 'drive', 'google', '資料']);

    String cell(List<String> row, int idx) {
      if (idx < 0 || idx >= row.length) return '';
      return row[idx].trim();
    }

    final items = <ClassScheduleItem>[];
    for (int r = headerIdx + 1; r < rows.length; r++) {
      final row = rows[r];
      if (row.isEmpty || row.every((c) => c.trim().isEmpty)) continue;

      DateTime? date;
      if (dateIdx != -1) {
        date = _parseDateFlexible(cell(row, dateIdx));
      }

      int? week;
      if (weekIdx != -1) {
        week = _parseWeek(cell(row, weekIdx));
      }

      final title = (titleIdx != -1 ? cell(row, titleIdx) : '').trim();

      final details = <String, String>{};
      void add(String label, String value) {
        final v = value.trim();
        if (v.isEmpty) return;
        details[label] = v;
      }

      add('Book', cell(row, bookIdx));
      add('Chapter/Unit', cell(row, chapterIdx));
      add('Pages', cell(row, pagesIdx));
      add('Homework', cell(row, homeworkIdx));
      add('Assessment', cell(row, assessmentIdx));
      add('Notes', cell(row, notesIdx));
      add('Link', cell(row, linkIdx));

      // Fallback title if the file doesn't have a clear topic/title column.
      final computedTitle = title.isNotEmpty
          ? title
          : _bestEffortTitleFromRow(row, header, preferredIndices: [
              bookIdx,
              chapterIdx,
              pagesIdx,
              homeworkIdx,
              notesIdx,
              assessmentIdx
            ]);

      if (computedTitle.trim().isEmpty) continue;

      items.add(ClassScheduleItem(
          title: computedTitle.trim(),
          date: date,
          week: week,
          details: details));
    }

    // Stable ordering: dated items first by date, then week, then title.
    items.sort((a, b) {
      if (a.date != null && b.date != null) return a.date!.compareTo(b.date!);
      if (a.date != null && b.date == null) return -1;
      if (a.date == null && b.date != null) return 1;

      if (a.week != null && b.week != null) return a.week!.compareTo(b.week!);
      if (a.week != null && b.week == null) return -1;
      if (a.week == null && b.week != null) return 1;

      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });

    return items;
  }

  int _findCalendarEventColumnIndex(List<String> header) {
    for (int i = 0; i < header.length; i++) {
      final h = header[i];
      if (h.contains('date') && h.contains('event')) return i;
    }
    return -1;
  }

  List<ClassScheduleItem> _parseCalendarEventFormat(
    List<List<String>> rows, {
    required int headerIdx,
    required int eventIdx,
    required int monthIdx,
    required int weekIdx,
  }) {
    String cell(List<String> row, int idx) {
      if (idx < 0 || idx >= row.length) return '';
      return row[idx].trim();
    }

    DateTime? firstDateInRow(List<String> row) {
      for (final c in row) {
        final d = _parseDateFlexible(c.trim());
        if (d != null) return d;
      }
      return null;
    }

    final items = <ClassScheduleItem>[];
    for (int r = headerIdx + 1; r < rows.length; r++) {
      final row = rows[r];
      if (row.isEmpty) continue;
      final raw = cell(row, eventIdx);
      if (raw.isEmpty) continue;

      final inferredYear = firstDateInRow(row)?.year ?? DateTime.now().year;
      final monthLabel = monthIdx != -1 ? cell(row, monthIdx) : '';
      final weekLabel = weekIdx != -1 ? cell(row, weekIdx) : '';
      final weekNum = _parseWeek(weekLabel);

      final parts = raw
          .split(RegExp(r'[\r\n]+'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty);
      for (final p in parts) {
        final m = RegExp(r'(\d{1,2})\s*/\s*(\d{1,2})').firstMatch(p);
        if (m == null) continue;
        final mm = int.tryParse(m.group(1) ?? '');
        final dd = int.tryParse(m.group(2) ?? '');
        if (mm == null || dd == null) continue;

        DateTime? date;
        try {
          date = DateTime(inferredYear, mm, dd);
        } catch (_) {
          date = null;
        }

        final colon = p.indexOf(':');
        final title = (colon >= 0 ? p.substring(colon + 1) : p).trim();
        if (title.isEmpty) continue;

        final details = <String, String>{};
        if (monthLabel.isNotEmpty) details['Month'] = monthLabel;
        if (weekLabel.isNotEmpty) details['Week'] = weekLabel;
        details['Raw'] = p;

        items.add(ClassScheduleItem(
            title: title, date: date, week: weekNum, details: details));
      }
    }

    items.sort((a, b) {
      if (a.date != null && b.date != null) return a.date!.compareTo(b.date!);
      if (a.date != null && b.date == null) return -1;
      if (a.date == null && b.date != null) return 1;

      if (a.week != null && b.week != null) return a.week!.compareTo(b.week!);
      if (a.week != null && b.week == null) return -1;
      if (a.week == null && b.week != null) return 1;

      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });

    return items;
  }

  int _findHeaderIndex(List<String> header, List<String> candidates) {
    for (int i = 0; i < header.length; i++) {
      final h = header[i];
      for (final c in candidates) {
        final cc = _norm(c);
        if (cc.isEmpty) continue;
        if (h == cc) return i;
        if (h.contains(cc)) return i;
      }
    }
    return -1;
  }

  int _pickHeaderRowIndex(List<List<String>> rows) {
    final max = rows.length < 12 ? rows.length : 12;
    int bestIdx = 0;
    int bestScore = -1;

    const known = [
      'date',
      'day',
      'week',
      'topic',
      'title',
      'lesson',
      'unit',
      'book',
      'chapter',
      'pages',
      'homework',
      'notes',
      'quiz',
      'test',
      'assessment',
      'link',
      'url',
      'resource',
      '內容',
      '課程',
      '進度',
      '作業',
      '備註',
      '測驗',
      '考試',
      '週',
      '周',
      '日期',
      '課本',
      '教材',
    ];

    for (int i = 0; i < max; i++) {
      final row = rows[i];
      if (row.isEmpty) continue;
      final cells = row.map(_norm).where((s) => s.isNotEmpty).toList();
      if (cells.length < 2) continue;

      int score = 0;
      for (final c in cells) {
        for (final k in known) {
          final kk = _norm(k);
          if (kk.isEmpty) continue;
          if (c == kk || c.contains(kk)) {
            score++;
            break;
          }
        }
      }

      if (score > bestScore) {
        bestScore = score;
        bestIdx = i;
      }
    }

    // If we didn't find anything header-like, default to first row.
    return bestScore >= 2 ? bestIdx : 0;
  }

  String _bestEffortTitleFromRow(List<String> row, List<String> header,
      {required List<int> preferredIndices}) {
    // Try preferred columns first.
    for (final idx in preferredIndices) {
      if (idx < 0 || idx >= row.length) continue;
      final v = row[idx].trim();
      if (v.isNotEmpty) return v;
    }

    // Otherwise, pick the first non-empty value that doesn't look like a pure number.
    for (final v in row) {
      final t = v.trim();
      if (t.isEmpty) continue;
      if (RegExp(r'^\d+(\.\d+)?$').hasMatch(t)) continue;
      return t;
    }
    return '';
  }

  int? _parseWeek(String s) {
    final t = s.trim();
    if (t.isEmpty) return null;
    final m = RegExp(r'(\d{1,2})').firstMatch(t);
    if (m == null) return null;
    return int.tryParse(m.group(1)!);
  }

  DateTime? _parseDateFlexible(String input) {
    final s = input.trim();
    if (s.isEmpty) return null;

    // ISO
    final iso = DateTime.tryParse(s);
    if (iso != null) return DateTime(iso.year, iso.month, iso.day);

    // Common formats: YYYY/MM/DD, MM/DD/YYYY, DD/MM/YYYY
    final parts =
        s.split(RegExp(r'[^0-9]+')).where((p) => p.isNotEmpty).toList();
    if (parts.length >= 3) {
      final a = int.tryParse(parts[0]);
      final b = int.tryParse(parts[1]);
      final c = int.tryParse(parts[2]);
      if (a == null || b == null || c == null) return null;

      // If first is 4 digits => Y/M/D
      if (parts[0].length == 4) {
        return DateTime(a, b, c);
      }

      // Otherwise prefer M/D/Y when year is last and 4 digits.
      if (parts[2].length == 4) {
        final year = c;
        final m = a;
        final d = b;
        if (m >= 1 && m <= 12) return DateTime(year, m, d);
        // fallback D/M/Y
        if (b >= 1 && b <= 12) return DateTime(year, b, a);
      }

      // Fallback: treat as Y/M/D if last seems like year.
      if (c > 31) return DateTime(c, a, b);
    }

    return null;
  }

  String _norm(String s) {
    return s
        .toLowerCase()
        .replaceAll(RegExp(r'[_\-\./\\()\[\]:]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

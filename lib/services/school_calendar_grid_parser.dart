/// Parses school calendars laid out as weekly grids with "Date: Event"
/// notes in a single Excel cell. Does not alter any existing Planner records.
class SchoolCalendarGridEvent {
  const SchoolCalendarGridEvent({
    required this.title,
    required this.start,
    required this.end,
  });

  final String title;
  final DateTime start;
  /// Inclusive last calendar day; a single-day event has end == start.
  final DateTime end;
}

class SchoolCalendarGridParser {
  const SchoolCalendarGridParser._();

  static String _norm(String input) => input
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]'), '');

  static int? _month(String value) {
    const names = {
      'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
      'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
    };
    final token = value.trim().toLowerCase();
    if (token.length < 3) return null;
    return names[token.substring(0, 3)];
  }

  static int _yearFromFilename(String filename) {
    final m = RegExp(r'20\d{2}').firstMatch(filename);
    return m == null ? DateTime.now().year : int.parse(m.group(0)!);
  }

  static int? _eventColumn(List<String> row) {
    for (var c = 0; c < row.length; c++) {
      final token = _norm(row[c]);
      if (token == 'dateevent' || token == 'dateevents' ||
          token == 'eventnotes') {
        return c;
      }
    }
    return null;
  }

  static int? _headerRow(List<List<String>> rows) {
    for (var i = 0; i < rows.length && i < 12; i++) {
      final row = rows[i].map(_norm).toList();
      if (!row.contains('month') || !row.contains('week')) continue;
      final days = row.where((v) => const {
        'sun', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat'
      }.contains(v)).length;
      if (days >= 5 && _eventColumn(rows[i]) != null) return i;
    }
    return null;
  }

  static bool matches(List<List<String>> rows) => _headerRow(rows) != null;

  static DateTime? _date(int year, int month, int day) {
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    final candidate = DateTime(year, month, day);
    return candidate.year == year &&
            candidate.month == month &&
            candidate.day == day
        ? candidate
        : null;
  }

  static (int, int)? _monthAndDay(String text, int assumedMonth) {
    final slash = text.split('/');
    if (slash.length == 2) {
      final month = int.tryParse(slash[0]);
      final day = int.tryParse(slash[1]);
      return month == null || day == null ? null : (month, day);
    }
    final day = int.tryParse(text);
    return day == null ? null : (assumedMonth, day);
  }

  static int _resolveYear(int rowYear, int rowMonth, int eventMonth) {
    // The first semester continues into January/February of the next year.
    if (rowMonth >= 10 && eventMonth <= 2) return rowYear + 1;
    if (rowMonth <= 2 && eventMonth >= 10) return rowYear - 1;
    return rowYear;
  }

  static (DateTime, DateTime)? _range(
    String token,
    int rowYear,
    int rowMonth,
  ) {
    final compact = token
        .replaceAll(RegExp(r'\([^)]*\)'), '')
        .replaceAll(RegExp(r'\s+'), '')
        .trim();
    final tokens = compact.split('-');
    if (tokens.isEmpty || tokens.length > 2) return null;
    final hasStartMonth = tokens.first.contains('/');
    final hasEndMonth = tokens.length == 2 && tokens.last.contains('/');

    var startInfo = _monthAndDay(tokens.first, rowMonth);
    if (startInfo == null) return null;

    if (!hasStartMonth && hasEndMonth) {
      final endInfo = _monthAndDay(tokens.last, rowMonth);
      if (endInfo == null) return null;
      // "29-10/5" in October means Sep 29–Oct 5, while
      // "27-11/2" in October means Oct 27–Nov 2.
      if (startInfo.$2 > endInfo.$2) {
        final prior = endInfo.$1 == 1 ? 12 : endInfo.$1 - 1;
        startInfo = (prior, startInfo.$2);
      }
    }

    final startYear = _resolveYear(rowYear, rowMonth, startInfo.$1);
    final start = _date(startYear, startInfo.$1, startInfo.$2);
    if (start == null) return null;
    if (tokens.length == 1) return (start, start);

    var endInfo = _monthAndDay(tokens.last, startInfo.$1);
    if (endInfo == null) return null;

    if (!hasEndMonth && endInfo.$2 < startInfo.$2) {
      endInfo = (startInfo.$1 == 12 ? 1 : startInfo.$1 + 1, endInfo.$2);
    }
    var endYear = _resolveYear(rowYear, rowMonth, endInfo.$1);
    if (endYear < start.year ||
        (endYear == start.year && endInfo.$1 < start.month)) {
      endYear = start.year + (endInfo.$1 < start.month ? 1 : 0);
    }
    final end = _date(endYear, endInfo.$1, endInfo.$2);
    if (end == null || end.isBefore(start) ||
        end.difference(start).inDays > 180) {
      return null;
    }
    return (start, end);
  }

  static List<SchoolCalendarGridEvent> parse(
    List<List<String>> rows, {
    required String filename,
  }) {
    final headerIdx = _headerRow(rows);
    if (headerIdx == null) return const [];
    final header = rows[headerIdx];
    final monthIdx = header.indexWhere((x) => _norm(x) == 'month');
    final eventIdx = _eventColumn(header)!;
    final events = <SchoolCalendarGridEvent>[];
    int? rowMonth;
    int rowYear = _yearFromFilename(filename);
    int? previousLabelMonth;

    final notePattern = RegExp(
      r'^\s*((?:\d{1,2}/)?\d{1,2}(?:\s*\([^)]*\))?'
      r'(?:\s*-\s*(?:\d{1,2}/)?\d{1,2})?)'
      r'\s*(?:[:：]\s*|\s+)(.+)$',
    );

    for (var i = headerIdx + 1; i < rows.length; i++) {
      final row = rows[i];
      if (monthIdx < row.length) {
        final label = _month(row[monthIdx]);
        if (label != null) {
          if (previousLabelMonth != null &&
              previousLabelMonth >= 11 && label <= 2) {
            rowYear++;
          }
          rowMonth = label;
          previousLabelMonth = label;
        }
      }
      if (rowMonth == null || eventIdx >= row.length) continue;
      final eventCell = row[eventIdx];
      if (eventCell.trim().isEmpty) continue;

      for (final piece in eventCell.split(RegExp(r'\r?\n|\s{3,}'))) {
        final line = piece.trim();
        if (line.isEmpty) continue;
        final match = notePattern.firstMatch(line);
        if (match == null) continue;
        final dateToken = match.group(1)!.trim();
        final title = match.group(2)!.trim();
        if (title.isEmpty) continue;
        final range = _range(dateToken, rowYear, rowMonth);
        if (range == null) continue;
        events.add(SchoolCalendarGridEvent(
          title: title,
          start: range.$1,
          end: range.$2,
        ));
      }
    }
    events.sort((a, b) => a.start.compareTo(b.start));
    return events;
  }
}

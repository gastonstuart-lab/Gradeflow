import 'package:gradeflow/components/time_slot_timetable.dart';
import 'package:gradeflow/models/class.dart' as school;

/// Pure validation and matching for the existing weekly timetable service.
class TimetableImportPlan {
  final List<TimeSlotClass> lessons;
  const TimetableImportPlan(this.lessons);

  static const weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday'
  ];

  static int? weekday(String value) {
    final token = value.trim().toLowerCase();
    const aliases = [
      ['mon', 'monday', '一', '星期一', '週一', '周一'],
      ['tue', 'tuesday', '二', '星期二', '週二', '周二'],
      ['wed', 'wednesday', '三', '星期三', '週三', '周三'],
      ['thu', 'thursday', '四', '星期四', '週四', '周四'],
      ['fri', 'friday', '五', '星期五', '週五', '周五'],
    ];
    for (var day = 0; day < aliases.length; day++) {
      if (aliases[day].contains(token)) return day;
    }
    return null;
  }

  static int clock(String value) {
    final match =
        RegExp(r'^(\d{1,2}):(\d{2})(?::00)?$').firstMatch(value.trim());
    if (match == null)
      throw FormatException('Invalid clock time "$value". Use HH:mm.');
    final hour = int.parse(match[1]!);
    final minute = int.parse(match[2]!);
    if (hour > 23 || minute > 59)
      throw FormatException('Invalid clock time "$value".');
    return hour * 60 + minute;
  }

  static TimetableImportPlan fromGrid(List<List<String>> grid) {
    if (grid.isEmpty) throw const FormatException('No timetable table found.');
    final header = grid.indexWhere((row) =>
        row.any((c) => weekday(c) != null) ||
        row.any((c) => c.trim().toLowerCase() == 'day'));
    if (header < 0)
      throw const FormatException(
          'Missing Monday–Friday headings or Day column.');
    final names = grid[header]
        .map((c) => c.trim().toLowerCase().replaceAll(RegExp(r'\s*/\s*'), '/'))
        .toList();
    final dayColumn = names.indexOf('day');
    final result = <TimeSlotClass>[];
    if (dayColumn >= 0) {
      final start = names.indexOf('start');
      final end = names.indexOf('end');
      final title = names.indexOf('class');
      final id = names.indexOf('class id');
      final room = names.indexOf('room');
      if (start < 0 || end < 0 || title < 0) {
        throw const FormatException(
            'Use Day, Start, End and Class columns. Class ID is optional.');
      }
      for (var r = header + 1; r < grid.length; r++) {
        final row = grid[r];
        String cell(int c) => c >= 0 && c < row.length ? row[c].trim() : '';
        if (row.every((c) => c.trim().isEmpty)) continue;
        final day = weekday(cell(dayColumn));
        if (day == null)
          throw FormatException('Row ${r + 1}: invalid or missing weekday.');
        result.add(TimeSlotClass(
            title: cell(title),
            dayOfWeek: day,
            startMinutes: clock(cell(start)),
            endMinutes: clock(cell(end)),
            classId: cell(id).isEmpty ? null : cell(id),
            room: cell(room).isEmpty ? null : cell(room)));
      }
    } else {
      final days = <int, int>{};
      for (var c = 0; c < names.length; c++) {
        final day = weekday(names[c]);
        if (day != null) days[c] = day;
      }
      if (days.values.toSet().length != 5 || days.length != 5) {
        throw const FormatException(
            'Provide each weekday Monday–Friday exactly once.');
      }
      // Horizontal merged weekday headings may leave blank subcolumns.
      int? currentDay;
      for (var c = 0; c < names.length; c++) {
        if (days.containsKey(c)) currentDay = days[c];
        if (names[c].isEmpty && currentDay != null) days[c] = currentDay;
      }
      for (var c = 0; c < names.length; c++) {
        if (!days.containsKey(c) &&
            !const [
              '',
              'index',
              'period',
              'time',
              'period/time',
              'start',
              'end',
              '節次',
              '時間'
            ].contains(names[c])) {
          throw FormatException(
              'Unsupported timetable column "${grid[header][c]}". Use Monday–Friday with Period/Time or Start/End.');
        }
      }
      final range = RegExp(
          r'(\d{1,2}:\d{2}(?::\d{2})?)\s*[-~–—]\s*(\d{1,2}:\d{2}(?::\d{2})?)');
      List<String>? pending;
      List<String>? pendingRooms;
      int? pendingStart;
      int? pendingEnd;
      void appendPending() {
        if (pending == null) return;
        final roomValues = pendingRooms!;
        for (var day = 0; day < 5; day++) {
          final label = [
            for (final entry in days.entries)
              if (entry.value == day && pending[entry.key].trim().isNotEmpty)
                pending[entry.key].trim()
          ].join(' ');
          final rooms = <String>{
            for (final entry in days.entries)
              if (entry.value == day && roomValues[entry.key].isNotEmpty)
                roomValues[entry.key]
          };
          if (rooms.length > 1)
            throw FormatException('${weekdays[day]}: conflicting room values.');
          if (label.isEmpty && rooms.isNotEmpty)
            throw FormatException(
                '${weekdays[day]}: room information has no class.');
          if (label.isEmpty) continue;
          result.add(TimeSlotClass(
              title: label,
              dayOfWeek: day,
              startMinutes: pendingStart!,
              endMinutes: pendingEnd!,
              room: rooms.firstOrNull));
        }
      }

      for (var r = header + 1; r < grid.length; r++) {
        if (grid[r].length > names.length &&
            grid[r].skip(names.length).any((c) => c.trim().isNotEmpty)) {
          throw FormatException(
              'Row ${r + 1}: extra cells have no weekday heading.');
        }
        final row = List<String>.generate(
            names.length, (c) => c < grid[r].length ? grid[r][c].trim() : '');
        final metadata = [
          for (var c = 0; c < row.length; c++)
            if (!days.containsKey(c) &&
                (!const ['index', 'period', '節次'].contains(names[c]) ||
                    RegExp(r'^(subject|class|group|room|科目|班級|組別|教室)$',
                            caseSensitive: false)
                        .hasMatch(row[c])))
              row[c]
        ].join(' ');
        final clocks = RegExp(r'\d{1,2}:\d{2}(?::\d{2})?')
            .allMatches(metadata)
            .map((m) => m[0]!)
            .toList();
        if (clocks.length > 2)
          throw FormatException(
              'Row ${r + 1}: multiple time ranges are ambiguous.');
        final match = range.firstMatch(metadata);
        final hasExplicitRange = match != null || clocks.length == 2;
        final hasLabels = days.keys.any((c) => row[c].isNotEmpty);
        final isBreak = RegExp(r'\b(lunch|break)\b|午餐|午休', caseSensitive: false)
            .hasMatch(row.join(' '));
        if (isBreak) {
          appendPending();
          pending = null;
          continue;
        }
        if (hasExplicitRange) {
          appendPending();
          pending = row;
          pendingRooms = List.filled(names.length, '');
          pendingStart = clock(match?[1] ?? clocks[0]);
          pendingEnd = clock(match?[2] ?? clocks[1]);
        } else if (RegExp(r'\d{1,2}:\d{2}(?::\d{2})?').hasMatch(metadata)) {
          throw FormatException(
              'Row ${r + 1}: provide explicit start and end times.');
        } else if (hasLabels) {
          final hasIdentifier = List.generate(names.length, (i) => i).any((c) =>
              const ['index', 'period', '節次'].contains(names[c]) &&
              row[c].isNotEmpty);
          final continuation = (!hasIdentifier && metadata.trim().isEmpty) ||
              RegExp(r'^(subject|class|group|room|科目|班級|組別|教室)$',
                      caseSensitive: false)
                  .hasMatch(metadata.trim());
          if (pending == null || !continuation)
            throw FormatException(
                'Row ${r + 1}: class information has no explicit time range.');
          // School multi-row periods put subject/group/room on separate rows.
          // Only untimed continuation rows join labels, never timed periods.
          final roomRow = RegExp(r'^(room|教室)$', caseSensitive: false)
              .hasMatch(metadata.trim());
          final roomValues = pendingRooms!;
          for (final c in days.keys) {
            if (row[c].isEmpty) continue;
            if (roomRow) {
              if (roomValues[c].isNotEmpty && roomValues[c] != row[c]) {
                throw FormatException('Row ${r + 1}: conflicting room values.');
              }
              roomValues[c] = row[c];
            } else {
              pending[c] = '${pending[c]} ${row[c]}'.trim();
            }
          }
        }
      }
      appendPending();
    }
    validate(result);
    return TimetableImportPlan(List.unmodifiable(result));
  }

  static void validate(List<TimeSlotClass> lessons) {
    if (lessons.isEmpty)
      throw const FormatException('No teaching periods found.');
    final sorted = [...lessons]..sort((a, b) => a.dayOfWeek != b.dayOfWeek
        ? a.dayOfWeek.compareTo(b.dayOfWeek)
        : a.startMinutes.compareTo(b.startMinutes));
    TimeSlotClass? previous;
    for (final lesson in sorted) {
      if (lesson.title.trim().isEmpty ||
          lesson.dayOfWeek < 0 ||
          lesson.dayOfWeek > 4 ||
          lesson.startMinutes < 0 ||
          lesson.endMinutes >= 1440 ||
          lesson.endMinutes <= lesson.startMinutes) {
        throw const FormatException(
            'Every lesson needs a class label, weekday and valid start/end times.');
      }
      if (previous != null &&
          previous.dayOfWeek == lesson.dayOfWeek &&
          lesson.startMinutes < previous.endMinutes) {
        throw FormatException(
            '${weekdays[lesson.dayOfWeek]}: duplicate or overlapping periods for "${previous.title}" and "${lesson.title}".');
      }
      previous = lesson;
    }
  }

  static String normalized(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\u3400-\u9fff]'), '');

  static String matchKey(TimeSlotClass lesson) =>
      lesson.classId == null ? lesson.title : 'id:${lesson.classId}';

  static List<school.Class> candidates(
      TimeSlotClass lesson, List<school.Class> classes) {
    if (lesson.classId != null)
      return classes.where((c) => c.classId == lesson.classId).toList();
    final label = normalized(lesson.title);
    return classes
        .where((c) => [
              c.className,
              '${c.subject} ${c.className}',
              '${c.className} ${c.subject}',
              '${c.subject} ${c.className} ${c.groupNumber ?? ''}'
            ].any((alias) => normalized(alias) == label))
        .toList();
  }

  List<TimeSlotClass> confirmMatches(
      Map<String, String> choices, List<school.Class> classes, String userId) {
    final owned =
        classes.where((c) => c.teacherId == userId && !c.isArchived).toList();
    return lessons.map((lesson) {
      final id = choices[matchKey(lesson)];
      if (id == null ||
          !owned.any((c) => c.classId == id) ||
          (lesson.classId != null && lesson.classId != id)) {
        throw FormatException(
            'Confirm an existing class for "${lesson.title}".');
      }
      return TimeSlotClass(
          title: lesson.title,
          dayOfWeek: lesson.dayOfWeek,
          startMinutes: lesson.startMinutes,
          endMinutes: lesson.endMinutes,
          room: lesson.room,
          classId: id);
    }).toList();
  }
}

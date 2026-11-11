import 'package:gradeflow/services/teacher_workspace_snapshot_service.dart';

/// Non-destructive presentation rules for the teacher's Home planning cards.
/// The Planner remains the source of truth; this model never edits its data.
class HomePlanningSummary {
  const HomePlanningSummary._();

  static DateTime _date(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static DateTime _lastDate(TeacherWorkspaceReminderSnapshot item) =>
      _date(item.endDate ?? item.timestamp);

  /// The Home month includes both imported events and unfinished dated tasks.
  /// Explicit school events remain visible after their completion flag changes.
  static int entriesOnDay(
    Iterable<TeacherWorkspaceReminderSnapshot> items,
    DateTime day,
  ) =>
      items
          .where((item) =>
              (item.isSchoolEvent || !item.done) && item.occursOn(day))
          .length;

  /// Genuine tasks, including overdue ones. Legacy items aren't guessed to
  /// be tasks: they remain available in Planner and its upcoming agenda.
  static List<TeacherWorkspaceReminderSnapshot> needsAttention(
    Iterable<TeacherWorkspaceReminderSnapshot> items,
    DateTime now, {
    int limit = 3,
  }) {
    final endExclusive = _date(now).add(const Duration(days: 8));
    final result = items
        .where((item) =>
            !item.done && item.isTask && item.timestamp.isBefore(endExclusive))
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return result.take(limit).toList(growable: false);
  }

  /// Upcoming school events and unclassified legacy reminders. Past entries
  /// are excluded; ongoing multi-day events are still included.
  static List<TeacherWorkspaceReminderSnapshot> comingUp(
    Iterable<TeacherWorkspaceReminderSnapshot> items,
    DateTime now, {
    int horizonDays = 14,
    int limit = 4,
  }) {
    final today = _date(now);
    final endExclusive = today.add(Duration(days: horizonDays));
    final result = items
        .where((item) =>
            !item.done &&
            !item.isTask &&
            !_lastDate(item).isBefore(today) &&
            _date(item.timestamp).isBefore(endExclusive))
        .toList()
      ..sort((a, b) {
        final aDate = _date(a.timestamp);
        final bDate = _date(b.timestamp);
        final aEffective = aDate.isBefore(today) ? today : aDate;
        final bEffective = bDate.isBefore(today) ? today : bDate;
        final byDate = aEffective.compareTo(bEffective);
        return byDate != 0 ? byDate : a.text.compareTo(b.text);
      });
    return result.take(limit).toList(growable: false);
  }
}

/// Date-only calendar calculations shared by GradeFlow's week/month views.
/// All ranges are inclusive and use the teacher's local calendar dates.
class PlannerDateMath {
  const PlannerDateMath._();

  static DateTime day(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static DateTime weekStart(DateTime value) =>
      day(value).subtract(Duration(days: value.weekday - DateTime.monday));

  static DateTime shiftWeek(DateTime value, int weeks) =>
      day(value).add(Duration(days: weeks * 7));

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static bool coversDay(DateTime start, DateTime? end, DateTime target) {
    final first = day(start);
    final last = day(end ?? start);
    final requested = day(target);
    return !requested.isBefore(first) && !requested.isAfter(last);
  }

  static bool intersects(
    DateTime start,
    DateTime? end,
    DateTime windowStart,
    DateTime windowEndInclusive,
  ) {
    final first = day(start);
    final last = day(end ?? start);
    return !last.isBefore(day(windowStart)) &&
        !first.isAfter(day(windowEndInclusive));
  }
}

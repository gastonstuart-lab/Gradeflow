import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/components/planner/planner_date_math.dart';

void main() {
  test('a teaching week starts on Monday and crosses months and years', () {
    expect(PlannerDateMath.weekStart(DateTime(2026, 11, 11)),
        DateTime(2026, 11, 9));
    expect(PlannerDateMath.weekStart(DateTime(2027, 1, 1)),
        DateTime(2026, 12, 28));
    expect(PlannerDateMath.shiftWeek(DateTime(2026, 12, 28), 1),
        DateTime(2027, 1, 4));
  });

  test('inclusive school events appear every day of a multi-day span', () {
    final first = DateTime(2026, 12, 30);
    final last = DateTime(2027, 1, 3);
    expect(PlannerDateMath.coversDay(first, last, DateTime(2026, 12, 30)),
        isTrue);
    expect(PlannerDateMath.coversDay(first, last, DateTime(2027, 1, 1)),
        isTrue);
    expect(PlannerDateMath.coversDay(first, last, DateTime(2027, 1, 3)),
        isTrue);
    expect(PlannerDateMath.coversDay(first, last, DateTime(2027, 1, 4)),
        isFalse);
    expect(PlannerDateMath.intersects(first, last,
        DateTime(2026, 12, 28), DateTime(2027, 1, 3)), isTrue);
    expect(PlannerDateMath.intersects(first, last,
        DateTime(2027, 1, 4), DateTime(2027, 1, 10)), isFalse);
  });

  test('date comparisons ignore time of day', () {
    expect(PlannerDateMath.isSameDay(
        DateTime(2026, 11, 11, 8), DateTime(2026, 11, 11, 23)), isTrue);
    expect(PlannerDateMath.coversDay(
        DateTime(2026, 11, 11, 16), null, DateTime(2026, 11, 11, 6)), isTrue);
  });
}

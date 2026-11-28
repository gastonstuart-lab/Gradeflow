import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/models/class.dart';
import 'package:gradeflow/components/time_slot_timetable.dart';
import 'package:gradeflow/components/home/home_teaching_class_context.dart';
import 'package:gradeflow/services/home_weekly_timetable_service.dart';

void main() {
  final now = DateTime(2026, 11, 25, 9, 15);
  Class roster(String id, String owner, {bool archived = false}) => Class(
    classId: id, className: 'J2 Science', subject: 'Science',
    schoolYear: '2026', term: '1', teacherId: owner,
    createdAt: now, updatedAt: now, isArchived: archived,
  );
  TimeSlotClass period(int start, int end, String? id) => TimeSlotClass(
    title: 'J2 Science', dayOfWeek: 2, startMinutes: start, endMinutes: end,
    classId: id,
  );
  test('current and next preserve explicit class links and ownership', () {
    final sequence = HomeTeachingSequence.fromSchedule([
      period(540, 590, 'a'), period(600, 650, 'b'),
    ], now);
    expect(sequence.current?.classId, 'a');
    expect(sequence.next?.classId, 'b');
    final classes = [roster('a', 'teacher'), roster('b', 'another')];
    expect(resolveScheduledTeachingClass(sequence.current, classes, 'teacher')?.classId, 'a');
    expect(resolveScheduledTeachingClass(sequence.next, classes, 'teacher'), isNull);
  });
  test('unlinked duplicate names do not select a random roster', () {
    final sequence = HomeTeachingSequence.fromSchedule([period(540, 590, null)], now);
    expect(resolveScheduledTeachingClass(sequence.current,
        [roster('a', 'teacher'), roster('b', 'teacher')], 'teacher'), isNull);
    expect(resolveScheduledTeachingClass(sequence.current,
        [roster('a', 'teacher'), roster('b', 'teacher', archived: true)], 'teacher')?.classId, 'a');
  });
  test('combined periods preserve a single roster link and end time', () {
    final sequence = HomeTeachingSequence.fromSchedule([
      period(540, 590, 'a'), period(600, 650, 'a'),
    ], now);
    expect(sequence.current?.periodCount, 2);
    expect(sequence.current?.classId, 'a');
    expect(sequence.current?.endAt, DateTime(2026, 11, 25, 10, 50));
  });
}

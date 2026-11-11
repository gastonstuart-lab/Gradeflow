import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/components/home/home_planning_summary.dart';
import 'package:gradeflow/services/teacher_workspace_snapshot_service.dart';

TeacherWorkspaceReminderSnapshot item(
  String text,
  DateTime start, {
  DateTime? end,
  String kind = 'legacy',
  bool done = false,
}) =>
    TeacherWorkspaceReminderSnapshot(
      text: text,
      timestamp: start,
      endDate: end,
      kind: kind,
      done: done,
      classIds: const [],
    );

void main() {
  test('month markers include imported and cross-month events', () {
    final records = [
      item('Mock exams', DateTime(2026, 11, 29),
          end: DateTime(2026, 12, 2), kind: 'school_event'),
      item('Prepare notes', DateTime(2026, 11, 30), kind: 'task'),
      item('Completed task', DateTime(2026, 11, 30), kind: 'task',
          done: true),
    ];
    expect(HomePlanningSummary.entriesOnDay(records, DateTime(2026, 11, 29)), 1);
    expect(HomePlanningSummary.entriesOnDay(records, DateTime(2026, 11, 30)), 2);
    expect(HomePlanningSummary.entriesOnDay(records, DateTime(2026, 12, 1)), 1);
    expect(HomePlanningSummary.entriesOnDay(records, DateTime(2026, 12, 3)), 0);
  });

  test('Home does not fill up with old school calendar items', () {
    final now = DateTime(2026, 11, 11, 15);
    final records = [
      for (var i = 1; i <= 30; i++)
        item('Old event $i', DateTime(2026, 7, i), kind: 'legacy'),
      item('Week 1', DateTime(2026, 11, 12), kind: 'school_event'),
      item('Week 2', DateTime(2026, 11, 13), kind: 'school_event'),
      item('Week 3', DateTime(2026, 11, 14), kind: 'legacy'),
      item('Week 4', DateTime(2026, 11, 15), kind: 'school_event'),
      item('Week 5', DateTime(2026, 11, 16), kind: 'school_event'),
    ];
    expect(HomePlanningSummary.comingUp(records, now).map((x) => x.text),
        ['Week 1', 'Week 2', 'Week 3', 'Week 4']);
  });

  test('ongoing multi-day event shows in upcoming, expired event does not', () {
    final now = DateTime(2026, 11, 11);
    final records = [
      item('Finished', DateTime(2026, 11, 1),
          end: DateTime(2026, 11, 10)),
      item('In progress', DateTime(2026, 11, 8),
          end: DateTime(2026, 11, 12)),
      item('Later', DateTime(2026, 11, 25)),
      item('Done', DateTime(2026, 11, 12), done: true),
    ];
    expect(HomePlanningSummary.comingUp(records, now).map((x) => x.text),
        ['In progress']);
  });

  test('tasks needing attention are separate from events and legacy entries', () {
    final now = DateTime(2026, 11, 11);
    final records = [
      item('School assembly', DateTime(2026, 11, 12), kind: 'school_event'),
      item('Ambiguous old item', DateTime(2026, 11, 12)),
      item('Grade reports', DateTime(2026, 11, 10), kind: 'task'),
      item('Prepare science', DateTime(2026, 11, 13), kind: 'task'),
      item('Far future', DateTime(2026, 12, 5), kind: 'task'),
      item('Completed', DateTime(2026, 11, 12), kind: 'task', done: true),
    ];
    expect(HomePlanningSummary.needsAttention(records, now).map((x) => x.text),
        ['Grade reports', 'Prepare science']);
    expect(HomePlanningSummary.comingUp(records, now).map((x) => x.text),
        ['Ambiguous old item', 'School assembly']);
  });
}

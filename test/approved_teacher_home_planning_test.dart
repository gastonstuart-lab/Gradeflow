import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/components/home/approved_teacher_home.dart';
import 'package:gradeflow/models/class.dart';
import 'package:gradeflow/services/teacher_workspace_snapshot_service.dart';

TeacherWorkspaceReminderSnapshot _item(
  String text,
  DateTime date, {
  String kind = 'legacy',
  DateTime? endDate,
}) =>
    TeacherWorkspaceReminderSnapshot(
      text: text,
      timestamp: date,
      endDate: endDate,
      kind: kind,
      done: false,
      classIds: const [],
    );

void main() {
  testWidgets('approved Home marks imported dates and does not list old events',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final today = DateTime.now();
    final todayKey =
        '${today.year.toString().padLeft(4, '0')}-'
        '${today.month.toString().padLeft(2, '0')}-'
        '${today.day.toString().padLeft(2, '0')}';
    final items = [
      _item('Old orientation', today.subtract(const Duration(days: 50))),
      _item('Current school event', DateTime(today.year, today.month, today.day),
          kind: 'school_event'),
      _item('Teacher task', DateTime(today.year, today.month, today.day),
          kind: 'task'),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ApprovedTeacherHome(
            teacherName: 'Test Teacher',
            schoolName: 'Test School',
            primaryClass: null,
            classes: const <Class>[],
            studentCounts: const {},
            reminders: items,
            loading: false,
            remindersAvailable: true,
            onSelectClass: (_) {},
            onOpenClassroom: () {},
            onOpenPlanner: () {},
            onOpenGrades: () {},
            onOpenStudents: () {},
            onOpenIedStudio: () {},
            onOpenScience: () {},
            onMoreHomeTools: () {},
            onToggleTheme: () {},
            onAttention: () {},
            onAssistant: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(ValueKey('home-calendar-marker-$todayKey')),
        findsOneWidget);
    expect(find.text('Your week'), findsOneWidget);
    expect(find.text('Current school event'), findsOneWidget);
    expect(find.text('Teacher task'), findsOneWidget);
    expect(find.text('Old orientation'), findsNothing);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gradeflow/components/time_slot_timetable.dart';
import 'package:gradeflow/os/surfaces/planner_surface.dart';
import 'package:gradeflow/services/class_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'Complete synthetic Planner displays Week Today Month Agenda and Tasks '
      'without Firebase or an AuthService provider', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final lessons = <TimeSlotClass>[
      TimeSlotClass(
          title: 'Synthetic Science',
          classId: 'fictional-science',
          dayOfWeek: 4,
          startMinutes: 480,
          endMinutes: 530),
      TimeSlotClass(
          title: 'Synthetic Science',
          classId: 'fictional-science',
          dayOfWeek: 4,
          startMinutes: 540,
          endMinutes: 590),
      TimeSlotClass(
          title: 'Synthetic EEP',
          classId: 'fictional-eep',
          dayOfWeek: 0,
          startMinutes: 600,
          endMinutes: 650),
    ];

    final preview = PlannerSyntheticPreviewData(
      teacherId: 'fictional-teacher-not-a-real-user',
      teacherName: 'Fictional Teacher',
      lessons: lessons,
      reminders: [
        PlannerSyntheticReminder(
          text: 'Review fictional lesson materials',
          timestamp: DateTime(2026, 11, 13, 8),
          kind: 'task',
        ),
        PlannerSyntheticReminder(
          text: 'Fictional Friday assembly',
          timestamp: DateTime(2026, 11, 13, 11),
          kind: 'school_event',
        ),
        PlannerSyntheticReminder(
          text: 'Fictional following-week deadline',
          timestamp: DateTime(2026, 11, 17, 9),
          kind: 'task',
        ),
      ],
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<ClassService>(
        create: (_) => ClassService(),
        child: MaterialApp(
          home: PlannerSurface(
            initialDate: DateTime(2026, 11, 13),
            syntheticPreview: preview,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    expect(find.text('Weekly timetable'), findsOneWidget);
    expect(find.text('Week dates & school events'), findsOneWidget);
    expect(find.text('Import timetable'), findsOneWidget);
    expect(find.textContaining('Lunch'), findsNWidgets(5));
    expect(find.text('Synthetic Science'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('planner-view-today')));
    await tester.pump();
    expect(find.text('Teaching today'), findsOneWidget);
    expect(find.text('Review fictional lesson materials'), findsWidgets);
    expect(find.text('Fictional Friday assembly'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('planner-view-month')));
    await tester.pump();
    expect(find.text('Nov 2026'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('planner-view-agenda')));
    await tester.pump();
    expect(find.text('Fictional following-week deadline'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('planner-view-tasks')));
    await tester.pump();
    expect(find.text('Review fictional lesson materials'), findsWidgets);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('current_user'), isNull);
    expect(prefs.getString('dashboard_reminders_v1:fictional-teacher-not-a-real-user'),
        isNull);
    expect(tester.takeException(), isNull);
  });
}
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gradeflow/components/home/teacher_home_integration_panel.dart';
import 'package:gradeflow/models/class.dart';
import 'package:gradeflow/nav.dart';
import 'package:gradeflow/services/teacher_workspace_snapshot_service.dart';
import 'package:gradeflow/theme.dart';

Class _class(String id, String name) => Class(
      classId: id,
      className: name,
      subject: 'Synthetic Biology',
      schoolYear: '2026-2027',
      term: 'Fall',
      teacherId: 'synthetic-teacher',
      createdAt: DateTime(2026, 10, 29),
      updatedAt: DateTime(2026, 10, 29),
    );

void main() {
  void size(WidgetTester tester, [Size value = const Size(1440, 960)]) {
    tester.view.physicalSize = value;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets(
      'approved Home sends the selected existing class to each class destination',
      (tester) async {
    size(tester);
    final classes = [
      _class('existing-a', 'First class'),
      _class('existing-b', 'Second class')
    ];
    var selected = classes.first;
    final router = GoRouter(initialLocation: '/home-test', routes: [
      GoRoute(
          path: '/home-test',
          builder: (context, state) => Scaffold(
              body: StatefulBuilder(
                  builder: (context, setState) => TeacherHomeIntegrationPanel(
                        approvedAppearance: true,
                        teacherName: 'Synthetic',
                        primaryClass: selected,
                        classes: classes,
                        primaryReminder: null,
                        studentCounts: const {
                          'existing-a': 7,
                          'existing-b': 29
                        },
                        onSelectClass: (id) => setState(() => selected =
                            classes.singleWhere((c) => c.classId == id)),
                      )))),
      for (final destination in ['classroom', 'gradebook', 'students'])
        GoRoute(
            path: '${AppRoutes.osClass}/:classId/$destination',
            builder: (context, state) => Scaffold(
                body: Text('$destination:${state.pathParameters['classId']}'))),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(
        MaterialApp.router(theme: lightTheme, routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Second class').last);
    await tester.pumpAndSettle();
    expect(find.text('Synthetic Biology · 29 students'), findsOneWidget);
    for (final destination in {
      'Open Classroom': 'classroom',
      'Grades': 'gradebook',
      'Students': 'students'
    }.entries) {
      await tester.ensureVisible(find.text(destination.key));
      await tester.tap(find.text(destination.key));
      await tester.pumpAndSettle();
      expect(find.text('${destination.value}:existing-b'), findsOneWidget);
      router.go('/home-test');
      await tester.pumpAndSettle();
    }
  });

  testWidgets(
      'approved Home discloses unavailable capabilities without preview fixtures or editors',
      (tester) async {
    size(tester);
    await tester.pumpWidget(MaterialApp(
        theme: lightTheme,
        home: Scaffold(
            body: TeacherHomeIntegrationPanel(
          approvedAppearance: true,
          primaryClass: null,
          classes: const [],
          primaryReminder: null,
          remindersAvailable: false,
          onOpenClassroom: () {},
          onOpenPlanner: () {},
        ))));
    expect(find.text('Unavailable on Home'), findsNWidgets(2));
    expect(find.text('Reminders unavailable'), findsOneWidget);
    expect(find.text('No pending reminders loaded'), findsNothing);
    expect(find.text('Local date only · No calendar synchronization'),
        findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.textContaining('10:10'), findsNothing);
    expect(find.textContaining('J2 Science'), findsNothing);
    expect(find.textContaining('Food web'), findsNothing);
    expect(find.text('Choose class'), findsOneWidget);
  });

  testWidgets(
      'approved Home displays supplied reminders read-only and distinguishes loading',
      (tester) async {
    size(tester, const Size(825, 764));
    final item = _class('existing-a', 'First class');
    await tester.pumpWidget(MaterialApp(
        theme: darkTheme,
        home: Scaffold(
            body: TeacherHomeIntegrationPanel(
          approvedAppearance: true,
          primaryClass: item,
          classes: [item],
          primaryReminder: null,
          reminders: [
            TeacherWorkspaceReminderSnapshot(
                text: 'Saved reminder from repository',
                timestamp: DateTime(2026, 10, 29),
                done: false,
                classIds: const ['existing-a'])
          ],
          onOpenPlanner: () {},
        ))));
    expect(find.text('Saved reminder from repository'), findsOneWidget);
    expect(find.byType(CheckboxListTile), findsNothing);
    expect(find.byType(TextField), findsNothing);
    await tester.pumpWidget(MaterialApp(
        theme: darkTheme,
        home: Scaffold(
            body: TeacherHomeIntegrationPanel(
          approvedAppearance: true,
          primaryClass: item,
          classes: [item],
          primaryReminder: null,
          loading: true,
        ))));
    expect(find.text('Loading your classes…'), findsOneWidget);
    expect(find.text('Loading reminders…'), findsOneWidget);
    final button = tester.widget<FilledButton>(find.ancestor(
      of: find.text('Open Classroom'),
      matching: find.byWidgetPredicate((widget) => widget is FilledButton),
    ));
    expect(button.onPressed, isNull);
    expect(tester.takeException(), isNull);
  });
}

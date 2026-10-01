import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:gradeflow/components/home/teacher_home_integration_panel.dart';
import 'package:gradeflow/models/class.dart';
import 'package:gradeflow/nav.dart';
import 'package:gradeflow/theme.dart';

void main() {
  Class testClass() {
    final now = DateTime(2026, 10, 1);
    return Class(
      classId: 'j2-science',
      className: 'J2 Science',
      subject: 'Science',
      schoolYear: '2026-2027',
      term: 'Fall',
      teacherId: 'teacher-1',
      createdAt: now,
      updatedAt: now,
    );
  }

  testWidgets('Teacher Home routes class work through existing InstructOS destinations',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final classItem = testClass();

    final router = GoRouter(
      initialLocation: '/test-home',
      routes: [
        GoRoute(
          path: '/test-home',
          builder: (context, state) => Scaffold(
            body: TeacherHomeIntegrationPanel(
              primaryClass: classItem,
              classes: [classItem],
              primaryReminder: null,
              onOpenIedStudio: () {},
              onOpenScience: () {},
            ),
          ),
        ),
        GoRoute(
          path: '${AppRoutes.osClass}/:classId/classroom',
          builder: (context, state) =>
              const Scaffold(body: Text('CLASSROOM ROUTE')),
        ),
        GoRoute(
          path: AppRoutes.osPlanner,
          builder: (context, state) =>
              const Scaffold(body: Text('PLANNER ROUTE')),
        ),
        GoRoute(
          path: '${AppRoutes.osClass}/:classId/gradebook',
          builder: (context, state) =>
              const Scaffold(body: Text('GRADES ROUTE')),
        ),
        GoRoute(
          path: '${AppRoutes.osClass}/:classId/students',
          builder: (context, state) =>
              const Scaffold(body: Text('STUDENTS ROUTE')),
        ),
        GoRoute(
          path: AppRoutes.classes,
          builder: (context, state) =>
              const Scaffold(body: Text('CLASSES ROUTE')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(
        theme: darkTheme,
        routerConfig: router,
      ),
    );

    await tester.tap(find.text('Open Classroom'));
    await tester.pumpAndSettle();
    expect(find.text('CLASSROOM ROUTE'), findsOneWidget);

    router.go('/test-home');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Planner'));
    await tester.pumpAndSettle();
    expect(find.text('PLANNER ROUTE'), findsOneWidget);

    router.go('/test-home');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Grades'));
    await tester.pumpAndSettle();
    expect(find.text('GRADES ROUTE'), findsOneWidget);

    router.go('/test-home');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Students'));
    await tester.pumpAndSettle();
    expect(find.text('STUDENTS ROUTE'), findsOneWidget);
  });

  testWidgets('Teacher Home exposes IED and Science without fake Science progress',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var iedOpens = 0;
    var scienceOpens = 0;
    final classItem = testClass();

    await tester.pumpWidget(
      MaterialApp(
        theme: darkTheme,
        home: Scaffold(
          body: TeacherHomeIntegrationPanel(
            primaryClass: classItem,
            classes: [classItem],
            primaryReminder: null,
            onOpenClassroom: () {},
            onOpenPlanner: () {},
            onOpenGrades: () {},
            onOpenStudents: () {},
            onOpenIedStudio: () => iedOpens++,
            onOpenScience: () => scienceOpens++,
          ),
        ),
      ),
    );

    expect(find.text('TEACHER HOME'), findsOneWidget);
    expect(find.text('J2 Science'), findsWidgets);
    expect(find.text('IED Studio'), findsOneWidget);
    expect(find.text('Science'), findsOneWidget);

    expect(find.textContaining('42%'), findsNothing);
    expect(find.textContaining('Continue last lesson'), findsNothing);
    expect(find.textContaining('Last opened at slide'), findsNothing);

    await tester.ensureVisible(find.text('IED Studio'));
    await tester.tap(find.text('IED Studio'));
    await tester.pump();
    expect(iedOpens, 1);

    await tester.ensureVisible(find.text('Science'));
    await tester.tap(find.text('Science'));
    await tester.pump();
    expect(scienceOpens, 1);
  });
}

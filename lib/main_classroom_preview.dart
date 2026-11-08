import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gradeflow/models/class.dart';
import 'package:gradeflow/models/student.dart';
import 'package:gradeflow/models/seating_layout.dart';
import 'package:gradeflow/os/surfaces/classroom_surface.dart';
import 'package:gradeflow/repositories/repository_factory.dart';
import 'package:gradeflow/services/auth_service.dart';
import 'package:gradeflow/services/class_service.dart';
import 'package:gradeflow/services/student_service.dart';
import 'package:gradeflow/services/seating_service.dart';
import 'package:gradeflow/theme.dart';

/// Standalone public preview. It does NOT boot the full GradeFlow application,
/// Firebase, sign-in, student imports or any production service.
const _classId = 'synthetic-public-classroom-preview';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  RepositoryFactory.useLocal();
  await SharedPreferences.getInstance();

  final classes = ClassService();
  final students = StudentService();
  final seating = SeatingService();
  final existing = await RepositoryFactory.instance.loadClasses();
  if (!existing.any((c) => c.classId == _classId)) {
    final now = DateTime(2026, 11, 8);
    await classes.addClass(Class(
      classId: _classId,
      className: 'Sample Science Classroom',
      subject: 'Synthetic demo — no real pupils',
      schoolYear: '2026',
      term: 'Demo',
      teacherId: 'synthetic-demo-only',
      createdAt: now,
      updatedAt: now,
    ));
  } else {
    await classes.loadClasses('synthetic-demo-only');
  }

  await students.loadStudents(_classId);
  if (students.students.isEmpty) {
    final names = [
      ('Alex', 'Review', '測試一'),
      ('Bella', 'Review', '測試二'),
      ('Chloe', 'Review', '測試三'),
      ('Daniel', 'Review', '測試四'),
      ('Emma', 'Review', '測試五'),
      ('Finn', 'Review', '測試六'),
      ('Grace', 'Review', '測試七'),
      ('Henry', 'Review', '測試八'),
    ];
    final now = DateTime(2026, 11, 8);
    await students.addStudents([
      for (var i = 0; i < names.length; i++)
        Student(
          studentId: 'preview-student-${i + 1}',
          chineseName: names[i].$3,
          englishFirstName: names[i].$1,
          englishLastName: names[i].$2,
          seatNo: '${i + 1}',
          classId: _classId,
          createdAt: now,
          updatedAt: now,
        ),
    ]);
  }

  await seating.loadRoomSetups();
  await seating.loadLayouts(_classId, studentCount: students.students.length);
  var layout = seating.activeLayout(_classId)!;
  if (layout.tables.isEmpty) {
    await seating.addTable(_classId, SeatingTableType.rectangular, seatCount: 4);
    await seating.addTable(_classId, SeatingTableType.round, seatCount: 4);
    layout = seating.activeLayout(_classId)!;
    for (var i = 0; i < layout.tables.length; i++) {
      final table = layout.tables[i];
      await seating.moveTable(_classId, table.tableId,
          (i == 0 ? 360.0 : 760.0) - table.x,
          (i == 0 ? 300.0 : 420.0) - table.y);
    }
    layout = seating.activeLayout(_classId)!;
    for (var i = 0; i < students.students.length && i < layout.seats.length; i++) {
      await seating.assignStudentToSeat(
          _classId, layout.seats[i].seatId, students.students[i].studentId);
    }
  }

  final router = GoRouter(
    initialLocation: '/preview/classroom',
    routes: [
      GoRoute(
        path: '/preview/classroom',
        builder: (context, state) => const ClassroomSurface(classId: _classId),
      ),
      GoRoute(
        path: '/os/classes',
        redirect: (context, state) => '/preview/classroom',
      ),
    ],
  );

  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthService>(create: (_) => AuthService()),
      ChangeNotifierProvider<ClassService>.value(value: classes),
      ChangeNotifierProvider<StudentService>.value(value: students),
      ChangeNotifierProvider<SeatingService>.value(value: seating),
    ],
    child: MaterialApp.router(
      title: 'GradeFlow Classroom — SYNTHETIC PREVIEW',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      routerConfig: router,
    ),
  ));
}

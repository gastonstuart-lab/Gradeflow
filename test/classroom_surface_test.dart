import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/models/class.dart';
import 'package:gradeflow/models/seating_layout.dart';
import 'package:gradeflow/models/student.dart';
import 'package:gradeflow/os/surfaces/classroom_surface.dart';
import 'package:gradeflow/repositories/repository_factory.dart';
import 'package:gradeflow/services/auth_service.dart';
import 'package:gradeflow/services/class_service.dart';
import 'package:gradeflow/services/seating_service.dart';
import 'package:gradeflow/services/student_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    RepositoryFactory.useLocal();
  });

  testWidgets('classroom drawer collapses and map remains available',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final services = await _buildServices('classroom-a');
    await tester.pumpWidget(_harness(services, 'classroom-a'));
    await tester.pumpAndSettle();

    expect(find.text('Grade 8 Science'), findsOneWidget);
    expect(find.text('Classroom tools'), findsOneWidget);
    expect(find.text('Hide tools'), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsWidgets);

    await tester.tap(find.text('Hide tools'));
    await tester.pumpAndSettle();

    expect(find.text('Classroom tools'), findsNothing);
    expect(find.text('Show tools'), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsWidgets);

    await tester.tap(find.text('Show tools'));
    await tester.pumpAndSettle();

    expect(find.text('Classroom tools'), findsOneWidget);
  });

  testWidgets('setup controls appear only when setup mode is enabled',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final services = await _buildServices('classroom-b');
    await tester.pumpWidget(_harness(services, 'classroom-b'));
    await tester.pumpAndSettle();

    expect(find.text('New room map'), findsNothing);

    await tester.tap(find.text('Setup'));
    await tester.pumpAndSettle();
    expect(find.text('Setup room'), findsOneWidget);

    await tester.tap(find.text('Setup room'));
    await tester.pumpAndSettle();

    expect(find.text('New room map'), findsOneWidget);
    expect(find.textContaining('Setup Room'), findsWidgets);
  });

  testWidgets('presentation hides private classroom drawer and setup controls',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final services = await _buildServices('classroom-c');
    await tester.pumpWidget(_harness(services, 'classroom-c'));
    await tester.pumpAndSettle();

    expect(find.text('Classroom tools'), findsOneWidget);

    await tester.tap(find.text('Present'));
    await tester.pumpAndSettle();

    expect(find.text('Exit presentation'), findsOneWidget);
    expect(find.text('Classroom tools'), findsNothing);
    expect(find.text('Setup room'), findsNothing);
    expect(find.text('Open student records'), findsNothing);
    expect(find.byType(InteractiveViewer), findsWidgets);

    await tester.tap(find.text('Exit presentation'));
    await tester.pumpAndSettle();

    expect(find.text('Classroom tools'), findsOneWidget);
  });

  testWidgets('narrow classroom uses an overlay drawer that can be dismissed',
      (tester) async {
    tester.view.physicalSize = const Size(700, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final services = await _buildServices('classroom-d');
    await tester.pumpWidget(_harness(services, 'classroom-d'));
    await tester.pumpAndSettle();

    expect(find.text('Classroom tools'), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsWidgets);

    await tester.tap(find.byTooltip('Hide tools'));
    await tester.pumpAndSettle();

    expect(find.text('Classroom tools'), findsNothing);
    expect(find.byType(InteractiveViewer), findsWidgets);
  });
}

class _Services {
  const _Services({
    required this.classService,
    required this.studentService,
    required this.seatingService,
  });

  final ClassService classService;
  final StudentService studentService;
  final SeatingService seatingService;
}

Future<_Services> _buildServices(String classId) async {
  final classService = ClassService();
  final studentService = StudentService();
  final seatingService = SeatingService();
  final now = DateTime(2026, 10, 1);

  await classService.addClass(
    Class(
      classId: classId,
      className: 'Grade 8 Science',
      subject: 'Science',
      schoolYear: '2026',
      term: 'Fall',
      teacherId: 'teacher-1',
      createdAt: now,
      updatedAt: now,
    ),
  );

  await studentService.addStudent(
    Student(
      studentId: '$classId-student-1',
      chineseName: '學生一',
      englishFirstName: 'Alex',
      englishLastName: 'Student',
      seatNo: '1',
      classId: classId,
      createdAt: now,
      updatedAt: now,
    ),
  );

  await seatingService.loadRoomSetups();
  await seatingService.loadLayouts(classId, studentCount: 1);
  await seatingService.addTable(
    classId,
    SeatingTableType.singleDesk,
    seatCount: 1,
  );

  final seat = seatingService.activeLayout(classId)!.seats.first;
  await seatingService.assignStudentToSeat(
    classId,
    seat.seatId,
    '$classId-student-1',
  );

  return _Services(
    classService: classService,
    studentService: studentService,
    seatingService: seatingService,
  );
}

Widget _harness(_Services services, String classId) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthService>(create: (_) => AuthService()),
      ChangeNotifierProvider<ClassService>.value(value: services.classService),
      ChangeNotifierProvider<StudentService>.value(
          value: services.studentService),
      ChangeNotifierProvider<SeatingService>.value(
          value: services.seatingService),
    ],
    child: MaterialApp(
      home: ClassroomSurface(classId: classId),
    ),
  );
}

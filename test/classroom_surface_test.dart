import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/models/class.dart';
import 'package:gradeflow/models/seating_layout.dart';
import 'package:gradeflow/models/student.dart';
import 'package:gradeflow/os/surfaces/classroom_surface.dart';
import 'package:gradeflow/components/seating/seating_canvas.dart';
import 'package:gradeflow/components/seating/student_picker_sheet.dart';
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

  Future<_Services> open(WidgetTester tester, String id,
      {double width = 1400}) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final services = await _buildServices(id);
    await tester.pumpWidget(_harness(services, id));
    await tester.pumpAndSettle();
    return services;
  }

  testWidgets(
      'tools start closed and slide from the right without resizing room',
      (tester) async {
    await open(tester, 'classroom-a');
    expect(find.text('Show tools'), findsOneWidget);
    final room = find.byType(InteractiveViewer).first;
    final before = tester.getRect(room);
    await tester.tap(find.text('Show tools'));
    await tester.pumpAndSettle();
    expect(find.text('Hide tools'), findsOneWidget);
    final panel = tester.getRect(find.text('Classroom tools'));
    expect(panel.left, greaterThan(1000));
    expect(tester.getRect(room), before);
    await tester.tap(find.byTooltip('Close tools'));
    await tester.pumpAndSettle();
    expect(find.text('Show tools'), findsOneWidget);
  });

  testWidgets('room setup uses right panel instead of old editor toolbar',
      (tester) async {
    await open(tester, 'classroom-b');
    await tester.tap(find.text('Arrange room'));
    await tester.pumpAndSettle();
    expect(find.text('Add round table'), findsOneWidget);
    expect(find.text('New room map'), findsNothing);
    expect(find.textContaining('Arrange Mode'), findsOneWidget);
    await tester.tap(find.text('Finish arranging'));
    await tester.pumpAndSettle();
    expect(find.text('Arrange room'), findsOneWidget);
  });

  testWidgets('Teach protects student placements; Arrange exposes seat assignment',
      (tester) async {
    await open(tester, 'classroom-arrange');
    var canvas = tester.widget<SeatingCanvas>(find.byType(SeatingCanvas).first);
    expect(canvas.allowSeatReassignment, isFalse);
    final seatInTeach = tester.widget<SeatWidget>(find.byType(SeatWidget).first);
    expect(seatInTeach.allowStudentDrag, isFalse);
    expect(seatInTeach.acceptDrops, isFalse);

    await tester.tap(find.text('Arrange room').first);
    await tester.pumpAndSettle();
    canvas = tester.widget<SeatingCanvas>(find.byType(SeatingCanvas).first);
    expect(canvas.allowSeatReassignment, isTrue);
    await tester.tap(find.text('Finish arranging'));
    await tester.pumpAndSettle();
    expect(tester.widget<SeatingCanvas>(find.byType(SeatingCanvas).first)
        .allowSeatReassignment, isFalse);
  });

  testWidgets('student and table picks highlight map without modifying layout',
      (tester) async {
    final services = await open(tester, 'classroom-picks');
    final before =
        services.seatingService.activeLayout('classroom-picks')!.toJson();
    await tester.tap(find.text('Pick student').first);
    await tester.pumpAndSettle();
    expect(find.byType(StudentPickerSheet), findsNothing);
    expect(
        tester
            .widgetList<SeatWidget>(find.byType(SeatWidget))
            .where((s) => s.highlighted)
            .length,
        1);
    await tester.tap(find.text('Pick table').first);
    await tester.pumpAndSettle();
    expect(
        tester
            .widgetList<TableWidget>(find.byType(TableWidget))
            .any((t) => t.highlightedTableId == t.table.tableId),
        isTrue);
    expect(services.seatingService.activeLayout('classroom-picks')!.toJson(),
        before);
  });

  testWidgets('presentation keeps premium map and hides private controls',
      (tester) async {
    await open(tester, 'classroom-c');
    await tester.tap(find.text('Present'));
    await tester.pumpAndSettle();
    expect(find.text('Exit presentation'), findsOneWidget);
    expect(find.text('Show tools'), findsNothing);
    expect(
        tester
            .widget<SeatingCanvas>(find.byType(SeatingCanvas).last)
            .premiumAppearance,
        isTrue);
    await tester.tap(find.byIcon(Icons.person).first);
    await tester.pumpAndSettle();
    expect(find.text('Add note or reminder'), findsNothing);
  });

  testWidgets('compact right panel can be closed without hiding the map',
      (tester) async {
    await open(tester, 'classroom-d', width: 700);
    await tester.tap(find.text('Show tools'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Close tools'));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsWidgets);
    expect(find.text('Show tools'), findsOneWidget);
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

import 'dart:convert';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
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

  testWidgets('restored tools preserve furniture and full-page timer returns to classroom', (tester) async {
    final services = await open(tester, 'restored-tools');
    final before = services.seatingService.activeLayout('restored-tools')!;
    await tester.tap(find.text('Random seating')); await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel')); await tester.pumpAndSettle();
    expect(services.seatingService.activeLayout('restored-tools')!.toJson(), before.toJson());
    await tester.tap(find.text('Random seating')); await tester.pumpAndSettle();
    await tester.tap(find.text('Shuffle')); await tester.pumpAndSettle();
    final after = services.seatingService.activeLayout('restored-tools')!;
    expect(after.tables.map((t) => t.toJson()), before.tables.map((t) => t.toJson()));
    expect(after.seats.map((s) => [s.seatId, s.x, s.y]), before.seats.map((s) => [s.seatId, s.x, s.y]));
    await tester.tap(find.text('Fit to screen')); await tester.pumpAndSettle();
    expect(services.seatingService.activeLayout('restored-tools')!.toJson(), after.toJson());
    await tester.tap(find.text('Full-page timer')); await tester.pumpAndSettle();
    expect(find.text('Classroom timer'), findsOneWidget);
    await tester.tap(find.text('Start 03:00')); await tester.pump(const Duration(seconds: 2));
    expect(find.textContaining('Pause'), findsOneWidget);
    await tester.tap(find.byTooltip('Reset timer')); await tester.pump();
    expect(find.text('Start 03:00'), findsOneWidget);
    await tester.tap(find.byTooltip('Close timer')); await tester.pumpAndSettle();
    expect(find.text('Full-page timer'), findsOneWidget);
    expect(services.seatingService.activeLayout('restored-tools')!.toJson(), after.toJson());
  });

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
    await tester.tap(find.byType(SeatWidget).first);
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
  testWidgets('teaching actions preserve saved data and exact framing',
      (tester) async {
    const id = 'classroom-stability';
    final services = await open(tester, id);
    await services.seatingService.updateSeatNote(id, services.seatingService.activeLayout(id)!.seats.first.seatId, note: 'SYNTHETIC PRIVATE NOTE', reminder: true);
    await tester.pumpAndSettle();
    final before = services.seatingService.activeLayout(id)!.toJson();
    final viewer =
        tester.widget<InteractiveViewer>(find.byType(InteractiveViewer).first);
    final transform = viewer.transformationController!.value.clone();
    expect(viewer.panEnabled, isFalse);
    expect(viewer.scaleEnabled, isFalse);
    expect(find.byTooltip('Fit room'), findsNothing);
    final seat = find
        .byWidgetPredicate((w) => w is SeatWidget && w.student != null)
        .first;
    final position = tester.getRect(seat);
    for (final action in [
      'Show tools',
      'Hide tools',
      'Arrange room',
      'Finish arranging'
    ]) {
      await tester.tap(find.text(action));
      await tester.pumpAndSettle();
      expect(tester.getRect(seat), position);
      expect(viewer.transformationController!.value, transform);
      expect(services.seatingService.activeLayout(id)!.toJson(), before);
    }
    await tester.tap(seat);
    await tester.pumpAndSettle();
    expect(find.text('All classroom tools'), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    expect(tester.getRect(seat), position);
    await tester.tap(find.byTooltip('Close tools'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pick student').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Present'));
    await tester.pumpAndSettle();
    expect(find.text('03:00'), findsOneWidget);
    await tester.tap(find.text('Pick student').last);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Move table'), findsNothing);
    expect(find.byIcon(Icons.sticky_note_2_outlined), findsNothing);
    expect(find.byIcon(Icons.notifications_active_outlined), findsNothing);
    expect(find.text('SYNTHETIC PRIVATE NOTE'), findsNothing);
    await tester.tap(find.text('03:00'));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 1200)));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('02:59'), findsOneWidget);
    await tester.tap(find.text('02:59'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exit presentation'));
    await tester.pumpAndSettle();
    expect(tester.getRect(seat), position);
    expect(services.seatingService.activeLayout(id)!.toJson(), before);
    await services.seatingService.loadLayouts(id);
    await tester.pumpAndSettle();
    expect(services.seatingService.activeLayout(id)!.toJson(), before);
    expect(tester.getRect(seat), position);
  });

  testWidgets('Arrange drag saves only the intended table movement',
      (tester) async {
    const id = 'classroom-arrange';
    final services = await open(tester, id);
    final before = services.seatingService.activeLayout(id)!;
    await tester.tap(find.text('Arrange room'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Close tools'));
    await tester.pumpAndSettle();
    final scale = tester
        .widget<InteractiveViewer>(find.byType(InteractiveViewer).first)
        .transformationController!
        .value
        .getMaxScaleOnAxis();
    final gesture = await tester
        .startGesture(tester.getCenter(find.byTooltip('Move table').first));
    await gesture.moveBy(const Offset(60, 30));
    await tester.pump();
    await gesture.moveBy(const Offset(40, 20));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    final after = services.seatingService.activeLayout(id)!;
    expect(
        after.tables.first.x - before.tables.first.x, closeTo(40 / scale, .01));
    expect(
        after.tables.first.y - before.tables.first.y, closeTo(20 / scale, .01));
    expect(after.seats.map((s) => s.toJson()).toList(),
        before.seats.map((s) => s.toJson()).toList());
    await services.seatingService.loadLayouts(id);
    await tester.pumpAndSettle();
    expect(services.seatingService.activeLayout(id)!.toJson(), after.toJson());
  });

  for (final size in [const Size(1440, 960), const Size(1920, 1080)]) {
    testWidgets('same fixture visual evidence ${size.width}', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      if (Platform.environment['CLASSROOM_EVIDENCE'] != null) await tester.runAsync(() async {
        final text = FontLoader('Roboto')
          ..addFont(Future.value(ByteData.sublistView(
              await File(r'C:\Windows\Fonts\segoeui.ttf').readAsBytes())));
        final icons = FontLoader('MaterialIcons')
          ..addFont(Future.value(ByteData.sublistView(await File(
                  r'C:\Users\Stuart\flutter\bin\cache\artifacts\material_fonts\MaterialIcons-Regular.otf')
              .readAsBytes())));
        await text.load();
        await icons.load();
      });
      const id = 'synthetic-review';
      final services = await _buildServices(id);
      for (var i = 2; i <= 8; i++) {
        await services.studentService.addStudent(Student(
            studentId: '$id-student-$i',
            chineseName: '合成學生',
            englishFirstName: [
              'Alex',
              'Bella',
              'Chloe',
              'Daniel',
              'Emma',
              'Finn',
              'Grace',
              'Henry'
            ][i - 1],
            englishLastName: 'Review',
            seatNo: '$i',
            classId: id,
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026)));
      }
      await services.seatingService
          .addTable(id, SeatingTableType.round, seatCount: 4);
      await services.seatingService
          .addTable(id, SeatingTableType.rectangular, seatCount: 4);
      var layout = services.seatingService.activeLayout(id)!;
      for (var i = 0; i < layout.tables.length; i++) {
        final t = layout.tables[i];
        await services.seatingService.moveTable(id, t.tableId,
            [260.0, 560.0, 920.0][i] - t.x, [220.0, 440.0, 220.0][i] - t.y);
      }
      layout = services.seatingService.activeLayout(id)!;
      for (var i = 0; i < 8; i++) {
        await services.seatingService.assignStudentToSeat(
            id, layout.seats[i].seatId, '$id-student-${i + 1}');
      }
      // Fixed identifiers and timestamps make both builds use byte-identical saved geometry.
      final saved = services.seatingService.activeLayout(id)!.toJson();
      final tables = saved['tables'] as List;
      final tableIds = <String, String>{};
      for (var i = 0; i < tables.length; i++) {
        tableIds[tables[i]['tableId'] as String] = 'review-table-$i';
        tables[i]['tableId'] = 'review-table-$i';
      }
      final seats = saved['seats'] as List;
      for (var i = 0; i < seats.length; i++) {
        seats[i]['seatId'] = 'review-seat-$i';
        seats[i]['tableId'] = tableIds[seats[i]['tableId']];
      }
      saved['layoutId'] = 'review-layout';
      saved['createdAt'] = '2026-11-08T00:00:00.000';
      saved['updatedAt'] = '2026-11-08T00:00:00.000';
      await RepositoryFactory.instance
          .saveSeatingLayouts(id, [SeatingLayout.fromJson(saved)]);
      await RepositoryFactory.instance
          .saveActiveSeatingLayoutId(id, 'review-layout');
      await services.seatingService.loadLayouts(id);
      final fixtureOutput = Platform.environment['CLASSROOM_EVIDENCE'];
      if (fixtureOutput != null) {
        await tester.runAsync(() => File('$fixtureOutput/saved-fixture.json')
            .writeAsString(jsonEncode(saved)));
      }
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
          RepaintBoundary(key: boundaryKey, child: _harness(services, id)));
      await tester.pumpAndSettle();
      final output = Platform.environment['CLASSROOM_EVIDENCE'];
      if (output != null) {
        Future<void> capture(String suffix) async {
          await tester.runAsync(() async {
            final image = await (boundaryKey.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage();
            final bytes =
                await image.toByteData(format: ui.ImageByteFormat.png);
            await File('$output/room-${size.width.toInt()}-$suffix.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }

        await capture('teach');
        await tester.tap(find.text('Show tools'));
        await tester.pumpAndSettle();
        await capture('panel');
        await tester.tap(find.byTooltip('Close tools'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Present'));
        await tester.pumpAndSettle();
        await capture('fullscreen');
      }
      expect(tester.takeException(), isNull);
    });
  }
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
      debugShowCheckedModeBanner: false,
      home: ClassroomSurface(classId: classId),
    ),
  );
}

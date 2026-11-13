import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gradeflow/components/planner/planner_teaching_workspace.dart';
import 'package:gradeflow/services/timetable_import_plan.dart';
import 'package:gradeflow/components/time_slot_timetable.dart';
import 'timetable_reliability_test.dart' show timetableGrid, timetableClasses;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final bytes = await File('assets/fonts/Roboto-Variable.ttf').readAsBytes();
    await (FontLoader('PlannerPreview')
          ..addFont(Future.value(ByteData.sublistView(bytes))))
        .load();
  });
  final classes = timetableClasses('teacher-a');
  final raw = TimetableImportPlan.fromGrid(timetableGrid()).lessons;
  final lessons = TimetableImportPlan(raw).confirmMatches(
      {for (final c in classes) c.className: c.classId}, classes, 'teacher-a');

  test(
      'double grouping is visual and requires the same confirmed class and room',
      () {
    final blocks = plannerLessonBlocks(lessons, true);
    expect(blocks.expand((b) => b), hasLength(24));
    expect(lessons, hasLength(24));
    expect(blocks.length, lessThan(24));
    expect(plannerLessonBlocks(lessons, false), hasLength(24));
    expect(
        plannerLessonBlocks([
          TimeSlotClass(
              title: 'Unlinked',
              dayOfWeek: 0,
              startMinutes: 540,
              endMinutes: 585),
          TimeSlotClass(
              title: 'Unlinked',
              dayOfWeek: 0,
              startMinutes: 590,
              endMinutes: 635),
        ], true),
        hasLength(2));
  });

  for (final size in [const Size(1440, 1000), const Size(1280, 900)]) {
    for (final brightness in Brightness.values) {
      testWidgets('Week layout, density and details at $size $brightness',
          (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final router = GoRouter(routes: [
          GoRoute(
              path: '/',
              builder: (_, __) => Scaffold(
                  body: SingleChildScrollView(
                      child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: PlannerTeachingWorkspace(
                              lessons: lessons,
                              classes: classes,
                              date: DateTime(2026, 11, 9),
                              todayView: false,
                              lunch: const PlannerLunch(720, 780),
                              periods: const [
                                (start: 480, end: 525),
                                (start: 535, end: 580),
                                (start: 590, end: 635),
                                (start: 645, end: 690),
                                (start: 780, end: 825),
                                (start: 835, end: 880),
                                (start: 890, end: 935),
                                (start: 945, end: 990)
                              ],
                              onSelectDate: (_) {},
                              onUpload: () {},
                              onManage: () {}))))),
          GoRoute(
              path: '/os/class/group-0/classroom',
              builder: (_, __) =>
                  const Scaffold(body: Text('Confirmed classroom'))),
        ]);
        final capture = GlobalKey();
        await tester.pumpWidget(RepaintBoundary(
            key: capture,
            child: MaterialApp.router(
                debugShowCheckedModeBanner: false,
                theme: ThemeData(
                    fontFamily: 'PlannerPreview',
                    brightness: brightness,
                    colorSchemeSeed: const Color(0xff177c78)),
                routerConfig: router)));
        await tester.pumpAndSettle();
        expect(find.text('Weekly timetable'), findsOneWidget);
        expect(find.textContaining('Lunch'), findsNWidgets(5));
        await tester.tap(find.text('Group doubles'));
        await tester.pumpAndSettle();
        expect(
            find.byWidgetPredicate((w) =>
                w is Material &&
                w.key is ValueKey<String> &&
                (w.key! as ValueKey<String>)
                    .value
                    .startsWith('planner-lesson-')),
            findsNWidgets(24));
        await tester.tap(find.text('Compact'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const ValueKey('planner-lesson-0-480')));
        await tester.pumpAndSettle();
        expect(find.text('Gradebook'), findsOneWidget);
        expect(find.text('Class information'), findsOneWidget);
        expect(find.textContaining('Room '), findsNothing);
        expect(tester.takeException(), isNull);
        const previewDir = String.fromEnvironment('PLANNER_PREVIEW_DIR');
        if (previewDir.isNotEmpty && size.width == 1440) {
          await tester.runAsync(() async {
            final boundary = capture.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
            final image = await boundary.toImage(pixelRatio: 1);
            final bytes =
                await image.toByteData(format: ui.ImageByteFormat.png);
            await File('$previewDir/planner-week-${brightness.name}.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.tap(find.byTooltip('Close lesson details'));
        await tester.pumpAndSettle();
        expect(find.text('Gradebook'), findsNothing);
        await tester.tap(find.byKey(const ValueKey('planner-lesson-0-480')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Classroom'));
        await tester.pumpAndSettle();
        expect(find.text('Confirmed classroom'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
        router.dispose();
      });
    }
  }

  testWidgets('Grouped period gap is not presented as active teaching',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: PlannerTeachingWorkspace(
                    lessons: lessons,
                    classes: classes,
                    date: DateTime(2026, 11, 9),
                    now: DateTime(2026, 11, 9, 8, 50),
                    todayView: true,
                    onSelectDate: (_) {},
                    onUpload: () {},
                    onManage: () {})))));
    await tester.pumpAndSettle();
    expect(find.text('In class now'), findsNothing);
    expect(find.text('Next lesson'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Open lesson details survive a parent data refresh',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final refreshed = ValueNotifier<bool>(false);
    addTearDown(refreshed.dispose);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: ValueListenableBuilder<bool>(
                    valueListenable: refreshed,
                    builder: (context, updated, child) =>
                        PlannerTeachingWorkspace(
                          lessons: [...lessons],
                          classes: classes,
                          date: DateTime(2026, 11, 9),
                          todayView: true,
                          now: DateTime(2026, 11, 9, 7),
                          onSelectDate: (_) {},
                          onUpload: () {},
                          onManage: () {},
                        ))))));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('planner-lesson-0-480')));
    await tester.pumpAndSettle();
    expect(find.text('Gradebook'), findsOneWidget);
    refreshed.value = true;
    await tester.pumpAndSettle();
    expect(find.text('Gradebook'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Close lesson details'));
    await tester.pumpAndSettle();
    expect(find.text('Gradebook'), findsNothing);
  });

  testWidgets('Today highlights an ongoing class and closes the detail sheet',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: PlannerTeachingWorkspace(
                    lessons: lessons,
                    classes: const [],
                    date: DateTime(2026, 11, 9),
                    now: DateTime(2026, 11, 9, 8, 20),
                    todayView: true,
                    onSelectDate: (_) {},
                    onUpload: () {},
                    onManage: () {})))));
    await tester.pumpAndSettle();
    expect(find.text('In class now'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('planner-lesson-0-480')));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Close lesson details'), findsOneWidget);
    await tester.tap(find.byTooltip('Close lesson details'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Close lesson details'), findsNothing);
    expect(find.text('In class now'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Today shows selected sequence and next lesson without invented room or links',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: PlannerTeachingWorkspace(
                    lessons: lessons,
                    classes: const [],
                    date: DateTime(2026, 11, 9),
                    now: DateTime(2026, 11, 9, 7),
                    todayView: true,
                    onSelectDate: (_) {},
                    onUpload: () {},
                    onManage: () {})))));
    await tester.pumpAndSettle();
    expect(find.text('Teaching today'), findsOneWidget);
    expect(find.text('Next lesson'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('planner-lesson-0-480')));
    await tester.pumpAndSettle();
    expect(find.text('Gradebook'), findsNothing);
    expect(find.textContaining('Confirm this lesson'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/repositories/grading_period_repository.dart';
import 'package:gradeflow/screens/period_gradebook_workspace.dart';
import 'package:gradeflow/services/grading_period_service.dart';
import 'package:gradeflow/services/grading_period_ui_controller.dart';
import 'package:gradeflow/services/historical_grade_export_adapter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'grading_period_test.dart' as fixture;

void main() {
  testWidgets('archived gradebook is read only and exports the frozen data',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = InMemoryGradingPeriodRepository(ownerId: 'owner');
    final service = GradingPeriodService(repo);
    await service.adoptLegacy(dataset: fixture.legacy(), periodId: 'old',
        label: 'Old period', at: fixture.at);
    final before = await service.rollover(classId: 'class', periodId: 'old',
        expectedRevision: 0, nextPeriodId: 'new', label: 'New period',
        at: fixture.at.add(const Duration(days: 1)));
    final session = GradingPeriodUiController(repo, 'class');
    addTearDown(session.dispose);
    await session.initialize();
    session.select('old');
    Uint8List? downloaded;
    String? filename;
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
      home: PeriodGradebookWorkspace(
        session: session,
        classRecord: fixture.classRecord(),
        export: (bytes, name) async { downloaded = bytes; filename = name; },
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'desktop archive layout');
    expect(find.text('Archived period · Read only'), findsOneWidget);
    expect(find.text('Export historical Excel'), findsOneWidget);
    expect(find.text('New grading period'), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(DataTable), findsOneWidget);
    await tester.tap(find.text('Export historical Excel'));
    await tester.pumpAndSettle();
    expect(filename, 'historical_class_old.xlsx');
    expect(downloaded, isNotNull);
    expect(fixture.cells(downloaded!), fixture.cells(
      HistoricalGradeExportAdapter().generateXlsx(before.periods.first,
          ownerId: 'owner', classId: 'class'),
    ));
    expect((await repo.load('class'))!.toJson(), before.toJson());
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'phone archive layout');
    expect(find.text('Archived period · Read only'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    downloaded = null;
    await tester.tap(find.text('Export historical Excel'));
    await tester.pumpAndSettle();
    expect(downloaded, isNotNull);
    expect(fixture.cells(downloaded!), fixture.cells(
      HistoricalGradeExportAdapter().generateXlsx(before.periods.first,
          ownerId: 'owner', classId: 'class'),
    ));
    expect((await repo.load('class'))!.toJson(), before.toJson());
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('active period accepts scores and switching periods preserves both datasets',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = InMemoryGradingPeriodRepository(ownerId: 'owner');
    final service = GradingPeriodService(repo);
    await service.adoptLegacy(dataset: fixture.legacy(), periodId: 'old',
        label: 'Old period', at: fixture.at);
    final before = await service.rollover(classId: 'class', periodId: 'old',
        expectedRevision: 0, nextPeriodId: 'new', label: 'New period',
        at: fixture.at.add(const Duration(days: 1)));
    final session = GradingPeriodUiController(repo, 'class');
    addTearDown(session.dispose);
    await session.initialize();
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
      home: PeriodGradebookWorkspace(
        session: session,
        classRecord: fixture.classRecord(),
        export: (_, _) async {},
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'active gradebook layout');
    expect(find.text('New grading period'), findsOneWidget);
    expect(find.text('Student scores'), findsOneWidget);
    final scoreField = find.byWidgetPredicate((widget) =>
        widget is TextField && widget.decoration?.labelText == 'Score');
    expect(scoreField, findsWidgets);
    await tester.enterText(scoreField.first, '76');
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pumpAndSettle();
    final after = (await repo.load('class'))!;
    expect(after.active.dataset.assessments, hasLength(20));
    expect(after.active.dataset.scores.singleWhere((s) =>
        s.studentId == 'one' && s.gradeItemId == 'new:quiz:1').score, 76);
    expect(after.periods.first.toJson(), before.periods.first.toJson());
    await tester.tap(find.byKey(const ValueKey('period-new')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Old period · Archived').last);
    await tester.pumpAndSettle();
    expect(find.text('Archived period · Read only'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.byKey(const ValueKey('period-old')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New period · Active').last);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(scoreField.first).controller!.text, '76');
    expect((await repo.load('class'))!.periods.first.toJson(), before.periods.first.toJson());
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}

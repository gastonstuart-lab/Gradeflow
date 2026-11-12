import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/components/gradebook/gradeflow_quick_score_stepper.dart';
import 'package:gradeflow/design_lab/gradeflow_design_lab_app.dart';

void main() {
  testWidgets('Design Lab loads standalone demo sections and switches theme',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const GradeFlowDesignLabApp());
    await tester.pump();

    expect(find.text('GradeFlow Design Lab'), findsOneWidget);
    expect(find.text('DEMO ONLY'), findsOneWidget);
    expect(find.byKey(const ValueKey('lab-nav-weather')), findsOneWidget);
    expect(find.byKey(const ValueKey('lab-nav-grading')), findsOneWidget);

    final themeBefore = Theme.of(
      tester.element(find.byKey(const ValueKey('lab-toggle-theme')))).brightness;
    await tester.tap(find.byKey(const ValueKey('lab-toggle-theme')));
    await tester.pump();
    final themeAfter = Theme.of(
      tester.element(find.byKey(const ValueKey('lab-toggle-theme')))).brightness;
    expect(themeAfter, isNot(themeBefore));

    await tester.tap(find.byKey(const ValueKey('lab-nav-weather')));
    await tester.pump();
    expect(find.text('Hourly trend'), findsWidgets);
    expect(find.byKey(const ValueKey('weather-hourly-chart')), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('lab-nav-grading')));
    await tester.pump();
    expect(find.text('Student 01'), findsOneWidget);
    expect(find.byKey(const ValueKey('lab-score-row-0')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Quick-entry stepper increments and supports typed correction',
      (tester) async {
    double? score = 91;
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: Center(child: StatefulBuilder(
        builder:(context,setState) => GradeFlowQuickScoreStepper(
          score:score,
          onChanged:(value)=>setState(()=>score=value),
        ),
      )),
    )));
    expect(find.text('91'), findsOneWidget);
    await tester.tap(find.byTooltip('Increase score'));
    await tester.pump();
    expect(find.text('92'), findsOneWidget);
    await tester.tap(find.byTooltip('Decrease score'));
    await tester.pump();
    expect(find.text('91'), findsOneWidget);
    await tester.tap(find.text('91'));
    await tester.pump();
    expect(find.byKey(const ValueKey('quick-grade-score-input')),
        findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('quick-grade-score-input')), '87.5');
    await tester.tap(find.text('Apply'));
    await tester.pump();
    expect(score, 87.5);
    expect(find.text('87.5'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Quick-entry score rejects values above maximum', (tester) async {
    double? score = 98;
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: Center(child: GradeFlowQuickScoreStepper(
        score:score,
        onChanged:(value)=>score=value,
      )),
    )));
    await tester.tap(find.text('98'));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('quick-grade-score-input')), '145');
    await tester.tap(find.text('Apply'));
    await tester.pump();
    expect(score, 98);
    expect(find.textContaining('Enter a score from 0 to'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/teaching_preview.dart';

void main() {
  testWidgets('homework, private note and continuation survive the lesson flow',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const TeachingPreview());
    await tester.tap(find.text('Start class'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Homework check'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alex'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.enterText(find.byType(TextField), 'Review food chains');
    await tester.tap(find.byTooltip('Close panel'));
    await tester.pumpAndSettle();
    expect(find.text('Done'), findsOneWidget);
    await tester.tap(find.text('Alex'));
    await tester.pumpAndSettle();
    expect(find.text('Review food chains'), findsOneWidget);
    await tester.tap(find.byTooltip('Close panel'));
    await tester.tap(find.text('Finish class'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Start with decomposers');
    await tester.tap(find.text('Finish demo lesson'));
    await tester.pumpAndSettle();
    expect(find.text('Start with decomposers'), findsOneWidget);
    await tester.tap(find.text('Reopen demo lesson'));
    await tester.pumpAndSettle();
    expect(find.text('Done'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('timer continues behind a closed panel on a narrow screen',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const TeachingPreview());
    await tester.ensureVisible(find.text('Start class'));
    await tester.tap(find.text('Start class'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Timer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start timer'));
    await tester.pump();
    await tester.tap(find.byTooltip('Close panel'));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Pause timer'), findsNothing);
    await tester.tap(find.byType(ActionChip).first);
    await tester.pump();
    expect(find.text('Pause timer'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

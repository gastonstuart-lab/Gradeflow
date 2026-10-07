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
    await tester.tap(find.widgetWithText(ChoiceChip, 'Done'));
    await tester.enterText(find.byType(TextField), 'Review food chains');
    await tester.tap(find.byTooltip('Close panel'));
    await tester.pumpAndSettle();
    expect(find.text('✓ Done'), findsOneWidget);
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
    expect(find.text('✓ Done'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('seat moves keep the same student note and homework check',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 1300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const TeachingPreview());
    await tester.tap(find.text('Start class'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Homework check'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('done-s1')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('done-s1')));
    await tester.pump();
    expect(find.textContaining('1 of 12 checked'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('student-s1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Alex note');
    await tester.tap(find.byTooltip('Close panel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Arrange seats'));
    await tester.pumpAndSettle();
    final target = tester.getCenter(find.byKey(const ValueKey('student-s2')));
    final start = tester.getCenter(find.byKey(const ValueKey('student-s1')));
    await tester.dragFrom(start, target - start);
    await tester.pumpAndSettle();
    expect(tester.getCenter(find.byKey(const ValueKey('student-s1'))), target);
    await tester.tap(find.text('Lock seats'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('student-s1')));
    await tester.pumpAndSettle();
    expect(find.text('Alex note'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Done'), findsOneWidget);
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
    await tester.tap(find.byWidgetPredicate((w) =>
        w is ActionChip &&
        w.avatar is Icon &&
        (w.avatar as Icon).icon == Icons.timer_outlined));
    await tester.pump();
    expect(find.text('Pause timer'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('chooser completes once and leaving Today cancels animation',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const TeachingPreview());
    await tester.tap(find.text('Start class'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pick student'));
    await tester.pump();
    expect(find.text('Stop chooser'), findsOneWidget);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    final selected =
        tester.widget<Text>(find.byKey(const ValueKey('chooser-result'))).data!;
    expect(selected, matches(RegExp(r'^Selected: (0[1-9]|1[0-2]) · ')));
    await tester.pump(const Duration(seconds: 4));
    expect(find.text(selected), findsOneWidget);
    await tester.tap(find.text('Pick table'));
    await tester.pump();
    await tester.tap(find.text('Today'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Return to class'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('chooser-result')), findsNothing);
    expect(find.text('01'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fullscreen timer hides classroom and preserves running state',
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
    await tester.ensureVisible(find.text('Fullscreen timer'));
    await tester.tap(find.text('Fullscreen timer'));
    await tester.pumpAndSettle();
    expect(find.text('Alex'), findsNothing);
    expect(find.text('Pause timer'), findsOneWidget);
    await tester.tap(find.text('Return to classroom'));
    await tester.pumpAndSettle();
    expect(find.text('Pause timer'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

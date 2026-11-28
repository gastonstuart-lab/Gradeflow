import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/os/surfaces/classroom_presentation_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('custom duration, full-page continuity, adjustment and reset',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: Scaffold(
      body: Center(child: ClassroomTimer()),
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Set timer duration'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Custom minutes and seconds'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), '2');
    await tester.enterText(find.byType(TextFormField).at(1), '15');
    await tester.tap(find.text('Set duration'));
    await tester.pumpAndSettle();
    expect(find.text('02:15'), findsOneWidget);
    await tester.tap(find.byTooltip('Full-page timer'));
    await tester.pumpAndSettle();
    expect(find.text('02:15'), findsOneWidget);
    await tester.tap(find.text('+30 sec'));
    await tester.pumpAndSettle();
    expect(find.text('02:45'), findsOneWidget);
    await tester.tap(find.text('−30 sec'));
    await tester.pumpAndSettle();
    expect(find.text('02:15'), findsOneWidget);
    await tester.tap(find.byTooltip('Timer settings'));
    await tester.pumpAndSettle();
    expect(find.text('Timer appearance'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Close timer'));
    await tester.pumpAndSettle();
    expect(find.text('02:15'), findsOneWidget);
    await tester.tap(find.byTooltip('Reset timer'));
    await tester.pumpAndSettle();
    expect(find.text('02:45'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

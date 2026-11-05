import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gradeflow/os/os_dock.dart';
import 'package:gradeflow/os/os_controller.dart';
import 'package:gradeflow/providers/app_providers.dart';

void main() {
  testWidgets('dock destinations respond to semantic button activation',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final semantics = tester.ensureSemantics();

    final router = GoRouter(initialLocation: '/start', routes: [
      for (final path in ['/start', '/os/home', '/os/planner', '/os/classes'])
        GoRoute(
            path: path,
            builder: (_, __) => Scaffold(
                body: Column(children: [Text('Page $path'), const OSDock()]))),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(MultiProvider(providers: [
      ChangeNotifierProvider(create: (_) => GradeFlowOSController()),
      ChangeNotifierProvider(create: (_) => ThemeModeNotifier()),
    ], child: MaterialApp.router(routerConfig: router)));
    await tester.pumpAndSettle();
    for (final entry in {
      'Planner': '/os/planner',
      'Classes': '/os/classes',
      'Home': '/os/home'
    }.entries) {
      final node = tester.getSemantics(find.byTooltip(entry.key));
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      tester.binding.performSemanticsAction(SemanticsActionEvent(
          type: SemanticsAction.tap,
          nodeId: node.id,
          viewId: tester.view.viewId));
      await tester.pumpAndSettle();
      expect(find.text('Page ${entry.value}'), findsOneWidget);
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Page /os/planner'), findsOneWidget);
    semantics.dispose();
  });
}

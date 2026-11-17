import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:gradeflow/services/teacher_appearance_controller.dart';
import 'package:gradeflow/widgets/teacher_appearance_overlay.dart';

void main() {
  testWidgets('decorative background never blocks teacher controls', (tester) async {
    final preferences = TeacherAppearanceController()..setBackground('boxes');
    final position = ValueNotifier<Offset?>(const Offset(40, 40));
    var taps = 0;
    await tester.pumpWidget(
      ChangeNotifierProvider<TeacherAppearanceController>.value(
        value: preferences,
        child: MaterialApp(
          home: Scaffold(
            body: Stack(children: [
              Positioned.fill(
                child: Center(
                  child: ElevatedButton(
                    onPressed: () => taps++,
                    child: const Text('Grade student'),
                  ),
                ),
              ),
              Positioned.fill(
                child: TeacherAppearanceOverlay(pointer: position),
              ),
            ]),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Grade student'));
    expect(taps, 1);
    position.value = const Offset(100, 100);
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    position.dispose();
    preferences.dispose();
  });

  testWidgets('standalone OS shells stay usable when appearance provider is absent',
      (tester) async {
    final position = ValueNotifier<Offset?>(null);
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Stack(children: [
          Center(child: ElevatedButton(
            onPressed: () => taps++,
            child: const Text('Open workspace'),
          )),
          Positioned.fill(
            child: TeacherAppearanceOverlay(pointer: position),
          ),
        ]),
      ),
    ));
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Open workspace'));
    expect(taps, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    position.dispose();
  });

  testWidgets('custom neon colours do not recolour buttons or grading UI',
      (tester) async {
    final preferences = TeacherAppearanceController()
      ..setBackground('boxes');
    final pointer = ValueNotifier<Offset?>(const Offset(20, 20));
    ColorScheme? renderedPalette;
    final originalPalette = ThemeData.light().colorScheme;

    await tester.pumpWidget(
      ChangeNotifierProvider<TeacherAppearanceController>.value(
        value: preferences,
        child: MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: Stack(children: [
              Positioned.fill(
                child: TeacherAppearanceOverlay(pointer: pointer),
              ),
              // Foreground components never inherit background glow colours.
              Builder(builder: (context) {
                renderedPalette = Theme.of(context).colorScheme;
                return const Column(children: [
                  ElevatedButton(onPressed: null, child: Text('Save grade')),
                  Text('Exam 95'),
                ]);
              }),
            ]),
          ),
        ),
      ),
    );
    expect(renderedPalette?.primary, originalPalette.primary);
    expect(find.text('Exam 95'), findsOneWidget);
    final originalButton = tester.widget<ElevatedButton>(
        find.byType(ElevatedButton));
    expect(originalButton.style, isNull);

    preferences.setCustomAccent(const Color(0xFFFF7700));
    pointer.value = const Offset(120, 130);
    await tester.pump();
    expect(renderedPalette?.primary, originalPalette.primary);
    expect(tester.widget<ElevatedButton>(
        find.byType(ElevatedButton)).style, originalButton.style);
    expect(find.text('Exam 95'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    pointer.dispose();
    preferences.dispose();
  });
}

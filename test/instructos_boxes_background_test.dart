import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/widgets/branding/instructos_boxes_background.dart';

void main() {

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('Background Boxes uses the correct ${mode.name} palette',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(brightness: Brightness.light),
        darkTheme: ThemeData(brightness: Brightness.dark),
        themeMode: mode,
        home: const Scaffold(
          body: InstructOSBoxesBackground(
            child: Center(child: Text('Accessible login')),
          ),
        ),
      ));
      final surface = tester.widget<DecoratedBox>(
          find.byKey(const ValueKey('instructos-boxes-base')));
      final decoration = surface.decoration as BoxDecoration;
      final gradient = decoration.gradient! as LinearGradient;
      expect(
        gradient.colors.first,
        mode == ThemeMode.dark
            ? const Color(0xFF07101D)
            : const Color(0xFFF7FBFE),
      );
      expect(find.text('Accessible login'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('boxes backdrop does not intercept child buttons or text entry',
      (tester) async {
    var tapped = false;
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InstructOSBoxesBackground(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    decoration: const InputDecoration(labelText: 'Username'),
                  ),
                  ElevatedButton(
                    onPressed: () => tapped = true,
                    child: const Text('Enter'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    // Interactive background paints on pointer changes, with no persistent
    // ticker keeping the widget test (or a logged-out screen) busy.
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enter'));
    expect(tapped, isTrue);

    await tester.enterText(find.byType(TextField), 'example');
    expect(controller.text, 'example');
    expect(tester.takeException(), isNull);
  });

  testWidgets('boxes backdrop respects reduced motion preference',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: InstructOSBoxesBackground(
              child: const Center(child: Text('Sign in')),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(InstructOSBoxesBackground), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

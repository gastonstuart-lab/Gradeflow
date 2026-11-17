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

  test('material accent shades preserve contrast in light mode', () {
    final preferences = TeacherAppearanceController();
    preferences.setAccent('cyan');
    expect(preferences.themeAccent(Brightness.light),
        const Color(0xFF0E7490));
    expect(preferences.themeAccent(Brightness.dark),
        const Color(0xFF22D3EE));
    preferences.dispose();
  });
}

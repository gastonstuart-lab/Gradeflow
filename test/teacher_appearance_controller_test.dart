import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/services/teacher_appearance_controller.dart';

void main() {
  test('appearance starts disabled visually by its minimal default', () {
    final appearance = TeacherAppearanceController();
    expect(appearance.background, 'minimal');
    expect(appearance.enabled, isTrue);
    expect(appearance.showInTeachMode, isFalse);
    expect(appearance.intensity, 0.40);
    appearance.dispose();
  });

  test('teachers can choose any RGB background glow colour', () {
    final appearance = TeacherAppearanceController();
    const lemon = Color(0xFFFFEB3B);
    appearance.setCustomAccent(lemon);
    expect(appearance.accent, 'custom');
    expect(appearance.accentColor, lemon);
    expect(TeacherAppearanceController.toHex(lemon), '#FFEB3B');
    expect(TeacherAppearanceController.fromHex('#ffeb3b'), lemon);
    expect(TeacherAppearanceController.fromHex('not a colour'), isNull);
    expect(appearance.backgroundGlowColor, lemon);
    appearance.setAccent('teal');
    expect(appearance.accent, 'teal');
    appearance.reset();
    expect(appearance.accent, 'indigo');
    appearance.dispose();
  });

  test('background options reject unknown values and can be reset', () {
    final appearance = TeacherAppearanceController();
    appearance.setBackground('boxes');
    expect(appearance.background, 'boxes');
    appearance.setBackground('not-a-background');
    expect(appearance.background, 'boxes');
    appearance.setAccent('rose');
    appearance.setIntensity(2);
    expect(appearance.intensity, 1);
    appearance.setEnabled(false);
    appearance.setShowInTeachMode(true);
    expect(appearance.showInTeachMode, isTrue);
    appearance.reset();
    expect(appearance.background, 'minimal');
    expect(appearance.accent, 'indigo');
    expect(appearance.showInTeachMode, isFalse);
    expect(appearance.enabled, isTrue);
    expect(appearance.intensity, 0.40);
    appearance.dispose();
  });
}

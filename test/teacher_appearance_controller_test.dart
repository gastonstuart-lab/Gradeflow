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
    expect(appearance.enabled, isTrue);
    expect(appearance.intensity, 0.40);
    appearance.dispose();
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/components/home/teacher_home_presentation.dart';

void main() {
  test('Home passes most ambient effect through in both themes', () {
    const darkBase = Color(0xff07131f);
    const lightBase = Color(0xffe5eff9);
    final dark = homeBackdropGradientTint(darkBase,
        dark: true, ambient: true);
    final light = homeBackdropGradientTint(lightBase,
        dark: false, ambient: true);

    // The old Home gradient was 78% opaque, visibly masking the effect.
    expect(dark.a, closeTo(0.18, 0.01));
    expect(light.a, closeTo(0.24, 0.01));
    expect(dark.a, lessThan(0.3));
    expect(light.a, lessThan(0.3));
    expect(dark.r, closeTo(darkBase.r, 0.01));
    expect(light.b, closeTo(lightBase.b, 0.01));
  });

  test('Home keeps its approved opaque gradient when effects are off', () {
    const base = Color(0xff07131f);
    expect(homeBackdropGradientTint(base, dark: true, ambient: false),
        base);
    expect(homeBackdropGradientTint(base, dark: false, ambient: false),
        base);
  });
}

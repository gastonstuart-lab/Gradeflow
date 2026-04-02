import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/components/time_slot_timetable_colors.dart';

void main() {
  test('timetable colors stay consistent for the same class title', () {
    final first = timetableColorForClassTitle('EEP (4) J1FG');
    final second = timetableColorForClassTitle('EEP (4) J1FG');

    expect(first, equals(second));
  });

  test('timetable colors normalize whitespace and case', () {
    final first = timetableColorForClassTitle('Sci (4) J2ABC');
    final second = timetableColorForClassTitle('  sci   (4)   j2abc  ');

    expect(first, equals(second));
  });

  test('different class titles usually map to different colors', () {
    final first = timetableColorForClassTitle('EEP (4) J1FG');
    final second = timetableColorForClassTitle('Sci (4) J2ABC');

    expect(first, isNot(equals(second)));
    expect(first, isA<Color>());
    expect(second, isA<Color>());
  });
}

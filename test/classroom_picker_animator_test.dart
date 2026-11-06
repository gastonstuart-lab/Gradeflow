import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/components/seating/classroom_picker_animator.dart';

void main() {
  test('animated pick previews several candidates before the final choice',
      () async {
    final picker = ClassroomPickerAnimator(random: Random(7));
    final frames = <String>[];
    const candidates = ['seat-a', 'seat-b', 'seat-c', 'seat-d'];
    final chosen = await picker.animate(
      candidateIds: candidates,
      nonRepeatingStudents: true,
      reduceMotion: false,
      onHighlight: frames.add,
    );
    expect(frames.length, 11);
    expect(frames.toSet().length, greaterThan(1));
    expect(frames.last, chosen);
    expect(candidates, contains(chosen));
  });

  test('student picks do not repeat until all students were chosen', () async {
    final picker = ClassroomPickerAnimator(random: Random(3));
    final outcomes = <String>[];
    for (var i = 0; i < 3; i++) {
      final picked = await picker.animate(
        candidateIds: const ['alex', 'bella', 'chloe'],
        nonRepeatingStudents: true,
        reduceMotion: true,
        onHighlight: (_) {},
      );
      outcomes.add(picked!);
    }
    expect(outcomes.toSet().length, 3);
    final next = await picker.animate(
      candidateIds: const ['alex', 'bella', 'chloe'],
      nonRepeatingStudents: true,
      reduceMotion: true,
      onHighlight: (_) {},
    );
    expect(outcomes, contains(next));
  });

  test('cancelled animation does not emit a final choice', () async {
    final picker = ClassroomPickerAnimator(random: Random(5));
    final frames = <String>[];
    final pending = picker.animate(
      candidateIds: const ['seat-a', 'seat-b'],
      nonRepeatingStudents: true,
      reduceMotion: false,
      onHighlight: frames.add,
    );
    await Future<void>.delayed(const Duration(milliseconds: 85));
    picker.cancel(clearStudentHistory: true);
    final chosen = await pending;
    expect(chosen, isNull);
  });

  test('reduced-motion pick highlights the winner once', () async {
    final picker = ClassroomPickerAnimator(random: Random(9));
    final frames = <String>[];
    final chosen = await picker.animate(
      candidateIds: const ['table-a', 'table-b'],
      nonRepeatingStudents: false,
      reduceMotion: true,
      onHighlight: frames.add,
    );
    expect(frames, [chosen]);
  });
}

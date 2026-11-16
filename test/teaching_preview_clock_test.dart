import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/components/teaching_preview_clock.dart';

void main() {
  testWidgets(
      'live clock rereads device time across midnight and disposes its timer',
      (tester) async {
    var now = DateTime(2026, 10, 7, 23, 59, 59);
    await tester
        .pumpWidget(MaterialApp(home: TeachingPreviewClock(now: () => now)));
    expect(find.text('23:59:59'), findsOneWidget);
    expect(find.text('Wed · 7 Oct'), findsOneWidget);
    now = DateTime(2026, 10, 8, 0, 0, 3);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('00:00:03'), findsOneWidget);
    expect(find.text('Thu · 8 Oct'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });
}

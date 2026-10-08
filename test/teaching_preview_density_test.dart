import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/components/teaching_preview_room.dart';

void main() {
  final seats = List<String?>.generate(24, (index) => 's$index');

  Future<void> showRoom(WidgetTester tester, Size size,
      {bool checking = false,
      bool groups = false,
      bool presentation = true}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TeachingPreviewRoom(
          students: {for (var i = 0; i < 24; i++) 's$i': 'Student $i'},
          seats: seats,
          homework: const {},
          checking: checking,
          groupMode: groups,
          presentation: presentation,
          selectedStudent: null,
          onStudent: (_) {},
          onDone: (_) {},
          onMove: (_, __) {},
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  for (final size in [
    const Size(1920, 1080),
    const Size(1366, 768),
    const Size(1440, 960),
  ]) {
    testWidgets('presentation keeps a compact six-table composition at $size',
        (tester) async {
      await showRoom(tester, size);
      final front = tester.getRect(find.text('TABLE 1'));
      final back = tester.getRect(find.text('TABLE 4'));
      final frontLabel = tester.getRect(find.text('Student 0'));
      // A growing viewport must not turn into an empty aisle. Relate spacing
      // to rendered content so this also catches unexpected scaling changes.
      expect(back.top - frontLabel.bottom, lessThan(front.height * 8));
      expect(back.top - front.top, greaterThan(front.height * 5));
      for (var column = 0; column < 3; column++) {
        final top = tester.getRect(find.text('TABLE ${column + 1}'));
        final bottom = tester.getRect(find.text('TABLE ${column + 4}'));
        expect(top.top, closeTo(front.top, 1));
        expect(bottom.top, closeTo(back.top, 1));
        expect(bottom.center.dx, closeTo(top.center.dx, 1));
        expect(bottom.bottom, lessThan(size.height));
      }
      // Physical side seats remain at table 1's left and table 3's right.
      expect(tester.getCenter(find.byKey(const ValueKey('seat-3'))).dx,
          lessThan(front.left));
      expect(tester.getCenter(find.byKey(const ValueKey('seat-11'))).dx,
          greaterThan(tester.getRect(find.text('TABLE 3')).right));
      for (final slot in [0, 1, 2]) {
        expect(tester.getCenter(find.byKey(ValueKey('seat-$slot'))).dy,
            greaterThan(front.bottom));
      }
      expect(
          tester
              .widget<TeachingPreviewRoom>(find.byType(TeachingPreviewRoom))
              .seats,
          seats);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'normal desktop scales the locked room and preserves seat positions',
      (tester) async {
    await showRoom(tester, const Size(1920, 1080), presentation: false);
    final front = tester.getRect(find.text('TABLE 1'));
    final back = tester.getRect(find.text('TABLE 4'));
    final name = tester.getRect(find.text('Student 0'));
    expect(name.height, greaterThan(18));
    expect(back.top - name.bottom, lessThan(120));
    for (var column = 0; column < 3; column++) {
      final top = tester.getRect(find.text('TABLE ${column + 1}'));
      final bottom = tester.getRect(find.text('TABLE ${column + 4}'));
      expect(top.top, closeTo(front.top, 1));
      expect(bottom.top, closeTo(back.top, 1));
      expect(bottom.center.dx, closeTo(top.center.dx, 1));
    }
    expect(tester.getCenter(find.byKey(const ValueKey('seat-3'))).dx,
        lessThan(front.left));
    expect(tester.getCenter(find.byKey(const ValueKey('seat-11'))).dx,
        greaterThan(tester.getRect(find.text('TABLE 3')).right));
    expect(
        tester
            .widget<TeachingPreviewRoom>(find.byType(TeachingPreviewRoom))
            .seats,
        seats);
    expect(tester.takeException(), isNull);
  });

  testWidgets('short presentation scrolls status rows without clipping seats',
      (tester) async {
    await showRoom(tester, const Size(740, 400), checking: true, groups: true);
    final scroll = find.byType(SingleChildScrollView);
    final position = tester
        .state<ScrollableState>(
            find.descendant(of: scroll, matching: find.byType(Scrollable)))
        .position;
    expect(position.maxScrollExtent, greaterThan(0));
    await tester.drag(scroll, const Offset(0, -1000));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.text('TABLE 6')).bottom, lessThan(400));
    expect(find.byKey(const ValueKey('done-s22')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

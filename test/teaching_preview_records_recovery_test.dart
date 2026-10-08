import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/teaching_preview.dart';
import 'package:gradeflow/components/teaching_preview_room.dart';

void main() {
  testWidgets(
      'material seat targets preserve notes and homework through a seat swap',
      (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const TeachingPreview());
    await tester.ensureVisible(find.text('Start class'));
    await tester.tap(find.text('Start class'));
    await tester.pumpAndSettle();
    final room = find.byType(TeachingPreviewRoom);
    final original =
        List<String?>.of(tester.widget<TeachingPreviewRoom>(room).seats);

    Future<void> select(String id) async {
      await tester.tap(find.byKey(ValueKey('student-$id')));
      await tester.pumpAndSettle();
    }

    Future<void> close() async {
      await tester.ensureVisible(find.byTooltip('Close panel'));
      await tester.tap(find.byTooltip('Close panel'));
      await tester.pumpAndSettle();
    }

    final note = find.widgetWithText(TextField, 'Private note');
    await select('s1');
    await tester.ensureVisible(note);
    await tester.enterText(note, 'Synthetic recovery note');
    final done = find.widgetWithText(ChoiceChip, 'Done');
    await tester.ensureVisible(done);
    await tester.tap(done);
    await tester.pumpAndSettle();
    await close();
    await select('s2');
    expect(tester.widget<TextField>(note).controller!.text, isEmpty);
    await close();
    await select('s1');
    expect(tester.widget<TextField>(note).controller!.text,
        'Synthetic recovery note');
    expect(tester.widget<ChoiceChip>(done).selected, isTrue);
    expect(tester.widget<TeachingPreviewRoom>(room).seats, original);
    await close();

    await tester.tap(find.widgetWithText(FilterChip, 'Arrange seats'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('student-s1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('student-s2')));
    await tester.pumpAndSettle();
    final moved = List<String?>.of(original);
    final a = original.indexOf('s1');
    final b = original.indexOf('s2');
    moved[a] = 's2';
    moved[b] = 's1';
    expect(tester.widget<TeachingPreviewRoom>(room).seats, moved);
    await tester.tap(find.widgetWithText(FilterChip, 'Lock seats'));
    await tester.pumpAndSettle();
    await select('s1');
    expect(tester.widget<TextField>(note).controller!.text,
        'Synthetic recovery note');
    expect(tester.widget<ChoiceChip>(done).selected, isTrue);
    expect(tester.widget<TeachingPreviewRoom>(room).homework['s1'], 'Done');
    expect(tester.takeException(), isNull);
  });
}

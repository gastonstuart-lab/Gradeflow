import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/theme.dart';

void main() {
  for (final theme in [lightTheme, darkTheme]) {
    testWidgets('Shared control labels retain bundled font in ${theme.brightness}',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Column(children: [
            FilledButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Open Classroom'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xff164f72),
              ),
            ),
            FilledButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.download),
              label: const Text('Export Excel'),
            ),
            OutlinedButton(onPressed: () {}, child: const Text('Planner')),
            TextButton(onPressed: () {}, child: const Text('Return')),
            ElevatedButton(onPressed: () {}, child: const Text('Save')),
          ]),
        ),
      ));

      TextStyle renderedStyle(String label) {
        final rich = find.descendant(
            of: find.text(label), matching: find.byType(RichText));
        return tester.widget<RichText>(rich).text.style!;
      }

      for (final label in [
        'Open Classroom', 'Export Excel', 'Planner', 'Return', 'Save'
      ]) {
        final style = renderedStyle(label);
        expect(style.fontFamily, appFontFamily, reason: label);
        expect(style.color, isNotNull, reason: label);
        expect(style.color!.a, greaterThan(0), reason: label);
      }
      double contrast(Color a, Color b) {
        final l1 = a.computeLuminance();
        final l2 = b.computeLuminance();
        return l1 > l2 ? (l1 + 0.05) / (l2 + 0.05) :
            (l2 + 0.05) / (l1 + 0.05);
      }
      expect(contrast(renderedStyle('Open Classroom').color!, Colors.white),
          greaterThanOrEqualTo(4.5));
      expect(contrast(renderedStyle('Export Excel').color!,
          theme.colorScheme.primary), greaterThanOrEqualTo(4.5));
      expect(tester.takeException(), isNull);
    });
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/components/roster_import_dialog.dart';
import 'package:gradeflow/services/file_import_service.dart';

ImportedStudent row({bool valid = true}) => ImportedStudent(
  studentId: 'fictional-101',
  chineseName: 'Fictional',
  englishFirstName: 'Test',
  englishLastName: 'Pupil',
  isValid: valid,
  error: valid ? null : 'Missing ID',
);

Future<void> open(
  WidgetTester tester,
  List<ImportedStudent> rows,
  Future<void> Function(List<ImportedStudent>) save, {
  ValueChanged<int?>? completed,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              final result = await showDialog<int>(
                context: context,
                barrierDismissible: false,
                builder: (_) => RosterImportDialog(rows: rows, onImport: save),
              );
              completed?.call(result);
            },
            child: const Text('Preview'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Preview'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('invalid-only import has no enabled save action', (tester) async {
    var calls = 0;
    await open(tester, [row(valid: false)], (_) async {
      calls++;
    });
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('confirm-roster-import')),
          )
          .onPressed,
      isNull,
    );
    expect(find.textContaining('Missing ID'), findsOneWidget);
    expect(calls, 0);
  });

  testWidgets(
    'pending save prevents repeated clicks, cancellation and early success',
    (tester) async {
      final pending = Completer<void>();
      var calls = 0;
      int? imported;
      await open(tester, [row()], (_) {
        calls++;
        return pending.future;
      }, completed: (count) => imported = count);
      await tester.tap(find.byKey(const ValueKey('confirm-roster-import')));
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('confirm-roster-import')),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Cancel'))
            .onPressed,
        isNull,
      );
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(
        find.byKey(const ValueKey('roster-import-preview')),
        findsOneWidget,
      );
      expect(imported, isNull);
      expect(calls, 1);
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('roster-import-preview')), findsNothing);
      expect(imported, 1);
    },
  );

  testWidgets(
    'failure retains rows and permits retry; only valid rows are passed',
    (tester) async {
      var fail = true;
      int? imported;
      final attempts = <int>[];
      await open(tester, [row(), row(valid: false)], (rows) async {
        attempts.add(rows.length);
        if (fail) throw StateError('Fictional storage failure');
      }, completed: (count) => imported = count);
      await tester.tap(find.byKey(const ValueKey('confirm-roster-import')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Fictional storage failure'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('roster-import-preview')),
        findsOneWidget,
      );
      expect(imported, isNull);
      fail = false;
      await tester.tap(find.byKey(const ValueKey('confirm-roster-import')));
      await tester.pumpAndSettle();
      expect(attempts, [1, 1]);
      expect(imported, 1);
      expect(tester.takeException(), isNull);
    },
  );
}

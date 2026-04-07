import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/components/workspace_shell.dart';

void main() {
  testWidgets('workspace snack bar renders shared feedback surface and action',
      (tester) async {
    var tapped = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return FilledButton(
                onPressed: () {
                  showWorkspaceSnackBar(
                    context,
                    message: 'Copied roster export.',
                    tone: WorkspaceFeedbackTone.success,
                    actionLabel: 'Undo',
                    onAction: () => tapped++,
                  );
                },
                child: const Text('Show'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show'));
    await tester.pump();

    expect(find.text('Saved'), findsOneWidget);
    expect(find.text('Copied roster export.'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);

    final undoButton =
        tester.widget<TextButton>(find.widgetWithText(TextButton, 'Undo'));
    undoButton.onPressed!.call();
    await tester.pump();

    expect(tapped, 1);
  });
}

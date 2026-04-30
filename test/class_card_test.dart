import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/components/class_card.dart';
import 'package:gradeflow/models/class.dart';
import 'package:gradeflow/theme.dart';

void main() {
  testWidgets('class card without schedule fits compact grid tile',
      (tester) async {
    final overflowErrors = <FlutterErrorDetails>[];
    final previousOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('overflowed')) {
        overflowErrors.add(details);
      } else {
        previousOnError?.call(details);
      }
    };
    addTearDown(() {
      FlutterError.onError = previousOnError;
    });

    final now = DateTime(2026, 4, 23);
    final classItem = Class(
      classId: 'class-1',
      className: 'EEP 3 J2FG',
      subject: 'English',
      groupNumber: '3',
      schoolYear: '2025-2026',
      term: 'Spring',
      teacherId: 'teacher-1',
      createdAt: now,
      updatedAt: now,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: lightTheme,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 296,
              height: 188,
              child: ClassCard(
                classItem: classItem,
                onTap: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(overflowErrors, isEmpty);
    expect(find.text('EEP 3 J2FG'), findsOneWidget);
    expect(find.text('Group 3'), findsOneWidget);
    expect(find.text('Schedule'), findsNothing);
  });
}

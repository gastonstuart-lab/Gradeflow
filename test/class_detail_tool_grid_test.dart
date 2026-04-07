import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/screens/class_detail_screen.dart';

void main() {
  testWidgets('class workspace tool grid renders tools and forwards taps',
      (tester) async {
    var tapCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 960,
            child: ClassWorkspaceToolGrid(
              tools: [
                ClassWorkspaceToolData(
                  icon: Icons.people_alt_outlined,
                  title: 'Roster',
                  subtitle: 'Open the class roster',
                  onTap: () => tapCount++,
                ),
                ClassWorkspaceToolData(
                  icon: Icons.event_seat_outlined,
                  title: 'Seating',
                  subtitle: 'Open seating tools',
                  onTap: () => tapCount += 10,
                ),
                ClassWorkspaceToolData(
                  icon: Icons.edit_note,
                  title: 'Gradebook',
                  subtitle: 'Open gradebook',
                  onTap: () => tapCount += 100,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('Roster'), findsOneWidget);
    expect(find.text('Seating'), findsOneWidget);
    expect(find.text('Gradebook'), findsOneWidget);

    await tester.tap(find.text('Seating'));
    await tester.pumpAndSettle();

    expect(tapCount, 10);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/components/home/teacher_home_class_rail.dart';
import 'package:gradeflow/models/class.dart';
import 'package:gradeflow/services/home_weekly_timetable_service.dart';
import 'package:gradeflow/components/time_slot_timetable.dart';

Class sample(String id, String name, String subject) => Class(
  classId: id,
  className: name,
  subject: subject,
  schoolYear: '2026',
  term: 'Fall',
  teacherId: 'synthetic-only',
  createdAt: DateTime(2026, 11, 1),
  updatedAt: DateTime(2026, 11, 1),
);

void main() {
  test('class rail uses stable subject colours instead of status colours', () {
    expect(classSubjectTone('English', 'EEP1').color,
        classSubjectTone('English', 'EEP5').color);
    expect(classSubjectTone('Science', 'J2ABC G4').color,
        classSubjectTone('Science', 'J2ABC G7').color);
    expect(classSubjectTone('Performance Arts', 'J1').color,
        isNot(classSubjectTone('English', 'EEP1').color));
  });

  testWidgets('compact rail selects saved class IDs and browses horizontally',
      (tester) async {
    final classes = [
      sample('e1', 'EEP1', 'English'),
      sample('e4', 'EEP4', 'English'),
      sample('s4', 'Science G4', 'Science'),
      sample('s7', 'Science G7', 'Science'),
      sample('pa', 'PA J1', 'Performance Arts'),
    ];
    var selected = 'e1';
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Center(child: SizedBox(
        width: 540, height: 170,
        child: StatefulBuilder(builder: (context, setState) =>
          TeacherHomeClassRail(
            classes: classes,
            selectedClassId: selected,
            studentCounts: const {'e1': 20, 's4': 18},
            onSelectClass: (id) => setState(() => selected = id),
          ),
        ),
      ))),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('home-compact-class-rail')),
        findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('home-rail-class-e4')));
    await tester.pumpAndSettle();
    expect(selected, 'e4');
    await tester.tap(find.byTooltip('Scroll classes right'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('home-rail-class-s7')));
    await tester.pumpAndSettle();
    expect(selected, 's7');
    expect(tester.takeException(), isNull);
  });

  testWidgets('timetable remains separate from roster selection', (tester) async {
    final classes = [sample('e1', 'EEP1', 'English')];
    var toggled = false;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Center(
      child: SizedBox(width: 600, height: 180, child: TeacherHomeClassRail(
        classes: classes,
        selectedClassId: 'e1',
        studentCounts: const {},
        onSelectClass: (_) {},
        timetable: const HomeWeeklyTimetable(
          name: 'synthetic.csv',
          classes: [
            TimeSlotClass(
              title: 'Unmapped School Label',
              dayOfWeek: 2,
              startMinutes: 540,
              endMinutes: 590,
            ),
          ],
        ),
        combineConsecutivePeriods: true,
        onCombineConsecutivePeriodsChanged: (value) => toggled = !value,
      )),
    ))));
    await tester.pump();
    expect(find.byKey(const ValueKey('home-rail-class-e1')), findsOneWidget);
    await tester.tap(find.byTooltip('Timetable options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Combine double periods'));
    await tester.pumpAndSettle();
    expect(toggled, isTrue);
    expect(tester.takeException(), isNull);
  });
}

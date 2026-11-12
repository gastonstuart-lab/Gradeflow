// ignore_for_file: prefer_interpolation_to_compose_strings
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gradeflow/components/time_slot_timetable.dart';
import 'package:gradeflow/models/class.dart' as school;
import 'package:gradeflow/models/grade_item.dart';
import 'package:gradeflow/models/seating_layout.dart';
import 'package:gradeflow/models/student.dart';
import 'package:gradeflow/models/student_score.dart';
import 'package:gradeflow/os/surfaces/class_directory_surface.dart';
import 'package:gradeflow/repositories/local_repository.dart';
import 'package:gradeflow/services/class_directory_insights_loader.dart';
import 'package:gradeflow/services/home_weekly_timetable_service.dart';

school.Class _class(String id, String name, String subject,
    {String teacher = 'teacher'}) {
  final now = DateTime(2026, 11, 12);
  return school.Class(
    classId: id, className: name, subject: subject,
    schoolYear: '2026-2027', term: 'Fall', teacherId: teacher,
    createdAt: now, updatedAt: now,
  );
}

Student _student(String id, String classId) {
  final now = DateTime(2026, 11, 12);
  return Student(
    studentId: id, classId: classId, chineseName: '測試',
    englishFirstName: 'Demo', englishLastName: id,
    createdAt: now, updatedAt: now,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Summary only reads this teacher and distinguishes zero from missing scores',
      () async {
    SharedPreferences.setMockInitialValues({});
    final repo = LocalRepository();
    final now = DateTime(2026, 11, 12);
    final classA = _class('a', 'EEP1-J1FG (G1)', 'General');
    final classB = _class('b', 'J2ABCScienceGroup4 (G4)', 'Science');
    final other = _class('other', 'Private', 'Science', teacher: 'another');
    await repo.saveStudents('a', [_student('s1','a'), _student('s2','a')]);
    await repo.saveStudents('b', []);
    await repo.saveSeatingLayouts('a', [
      SeatingLayout(
        layoutId: 'room-a', classId:'a', name:'Room A',
        canvasWidth: 1200, canvasHeight: 800,
        tables: const [],
        seats: [
          SeatingSeat(
            seatId:'seat-1', tableId:'table-1', x:10, y:20,
            studentId:'s1', statusColor:SeatStatusColor.none),
          SeatingSeat(
            seatId:'seat-2', tableId:'table-1', x:40, y:20,
            studentId:null, statusColor:SeatStatusColor.none),
        ],
        createdAt:now, updatedAt:now,
      ),
    ]);
    await repo.saveActiveSeatingLayoutId('a','room-a');
    await repo.saveGradeItems('a', [
      GradeItem(
        gradeItemId:'quiz-1', classId:'a', categoryId:'quiz',
        name:'Quiz 1', isActive:true, createdAt:now, updatedAt:now),
    ]);
    await repo.saveScores('a','quiz-1', [
      StudentScore(studentId:'s1',gradeItemId:'quiz-1',score:0,
        createdAt:now,updatedAt:now),
      StudentScore(studentId:'s2',gradeItemId:'quiz-1',score:null,
        createdAt:now,updatedAt:now),
    ]);
    final timetable = HomeWeeklyTimetable(name:'Mock timetable',classes: [
      TimeSlotClass(title:classA.className,dayOfWeek:3,
        startMinutes:13 * 60,endMinutes:13 * 60 + 50),
    ]);
    final snapshot = await ClassDirectoryInsightsLoader(repo).load(
      classes:[classA,classB,other],teacherId:'teacher',timetable:timetable,
      now:DateTime(2026,11,12,12),
    );
    expect(snapshot.items,hasLength(2));
    expect(snapshot.totalStudents,2);
    expect(snapshot.classesWithSeatingToFinish,1);
    expect(snapshot.missingScores,1);
    expect(snapshot.lessonsToday(DateTime(2026,11,12,12)),1);
    final a = snapshot.items.first;
    expect(a.studentCount,2);
    expect(a.seatedCount,1);
    expect(a.unseated,1);
    expect(a.enteredCells,1); // Saved zero counts as entered.
    expect(a.scoreCells,2);
    expect(a.missingScores,1);
    expect(a.nextLesson,DateTime(2026,11,12,13));
    expect(snapshot.items.last.scoreCells,0);
    expect(snapshot.items.last.completion,isNull); // No assessments ≠ 100%.
  });

  test('Timetable never assigns ambiguous or unrelated lesson labels', () {
    final a = _class('a','EEP1-J1FG (G1)','English');
    final same = _class('b','EEP1 J1FG G1','English');
    final now = DateTime(2026,11,12,10);
    final slot = TimeSlotClass(title:'EEP1 J1FG G1',dayOfWeek:3,
      startMinutes:14 * 60,endMinutes:15 * 60);
    expect(ClassDirectoryInsightsLoader.nextLessonForClass(a,[a,same],[slot],now),
        isNull);
    expect(ClassDirectoryInsightsLoader.nextLessonForClass(
      a,[a],[TimeSlotClass(title:'Unrelated',dayOfWeek:3,
        startMinutes:14 * 60,endMinutes:15 * 60)],now),isNull);
    expect(ClassDirectoryInsightsLoader.nextLessonForClass(a,[a],[slot],now),
      DateTime(2026,11,12,14));
  });

  testWidgets('Eight class cards, genuine metrics and direct quick actions',
      (tester) async {
    tester.view.physicalSize = const Size(1580, 1024);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final classes = [
      _class('1','EEP5-J3DE (G5)','General'),
      _class('2','J2ABCScienceGroup7 (G7)','Science'),
      _class('3','EEP4-J2FG (G4)','General'),
      _class('4','J2ABCScienceGroup4 (G4)','Science'),
      _class('5','EEP1-J1FG (G1)','General'),
      _class('6','J1ABCScienceGroup4 (G4)','Science'),
      _class('7','J1ABCScienceGroup7 (G7)','Science'),
      _class('8','Performance Arts J1','Performance Arts'),
    ];
    final snapshot = ClassDirectorySnapshot(hasTimetable:false,items: [
      for (final item in classes)
        ClassDirectoryInsight(classItem:item,studentCount:20,
          seatedCount:18,scoreCells:40,enteredCells:30),
    ]);
    String? navigation;
    await tester.pumpWidget(MaterialApp(
      home:ClassDirectoryDashboard(
        classes:classes,snapshot:snapshot,loading:false,
        now:DateTime(2026,11,12,12),
        onRefresh:(){}, onImport:(){}, onHome:(){},
        onClassroom:(id)=>navigation='classroom:'+id,
        onGradebook:(id)=>navigation='gradebook:'+id,
        onStudents:(id)=>navigation='students:'+id,
      ),
    ));
    await tester.pump();
    expect(find.text('Your classes'),findsOneWidget);
    expect(find.text('160'),findsOneWidget); // Eight * 20 saved students.
    for (final item in classes) {
      expect(find.byKey(ValueKey('class-card-' + item.classId)),findsOneWidget);
    }
    final first = find.byKey(const ValueKey('class-card-1'));
    await tester.tap(find.descendant(of:first,
      matching:find.text('Classroom')));
    expect(navigation,'classroom:1');
    await tester.tap(find.descendant(of:first,matching:find.text('Gradebook')));
    expect(navigation,'gradebook:1');
    await tester.tap(find.descendant(of:first,matching:find.text('Students')));
    expect(navigation,'students:1');
    expect(tester.takeException(),isNull);
  });

  testWidgets('Search/filter and class details work without school writes',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 920);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final classes = [
      _class('s','J2 Science','Science'),
      _class('e','EEP1 English','General'),
    ];
    String? addedToClass;
    await tester.pumpWidget(MaterialApp(home:ClassDirectoryDashboard(
      classes:classes,loading:false,
      snapshot:ClassDirectorySnapshot(hasTimetable:false,items:[
        ClassDirectoryInsight(classItem:classes[0],studentCount:18,
          seatedCount:16,scoreCells:20,enteredCells:10,
          studentSearchTokens:const ['alex example']),
        ClassDirectoryInsight(classItem:classes[1],studentCount:20,
          seatedCount:20,scoreCells:0,enteredCells:0),
      ]),
      onHome:(){},onImport:(){},onRefresh:(){},
      onClassroom:(_){},onGradebook:(_){},onStudents:(_){},
      onAddStudent:(id)=>addedToClass=id,
    )));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('class-filter-Science')));
    await tester.pump();
    expect(find.byKey(const ValueKey('class-card-s')),findsOneWidget);
    expect(find.byKey(const ValueKey('class-card-e')),findsNothing);
    await tester.tap(find.byKey(const ValueKey('class-filter-All')));
    await tester.pump();
    await tester.enterText(find.byKey(const ValueKey('class-search')),'alex');
    await tester.pump();
    expect(find.byKey(const ValueKey('class-card-s')),findsOneWidget);
    expect(find.byKey(const ValueKey('class-card-e')),findsNothing);
    await tester.tap(find.byKey(const ValueKey('class-card-s')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Still to seat'),findsOneWidget);
    expect(find.text('Unentered score cells'),findsWidgets);
    await tester.tap(find.byKey(const ValueKey('class-drawer-add-student')));
    await tester.pump();
    expect(addedToClass, 's');
    // Re-open to confirm the ordinary close control remains functional.
    await tester.tap(find.byKey(const ValueKey('class-card-s')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byTooltip('Close class details'));
    await tester.pump();
    expect(tester.takeException(),isNull);
  });
}

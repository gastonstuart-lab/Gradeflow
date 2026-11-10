import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gradeflow/services/home_weekly_timetable_service.dart';
import 'package:gradeflow/components/time_slot_timetable.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final grid = <List<String>>[
    ['Time', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'],
    ['09:00-09:50', 'Synthetic English', '', 'Synthetic Science', '', ''],
    ['10:00-10:50', 'Synthetic Maths', '', '', '', ''],
  ];

  test('parses existing weekday grid and keeps the planned class order', () {
    final classes = HomeWeeklyTimetableService.parseGridToTimeSlots(grid);
    expect(classes.length, 3);
    final sequence = HomeTeachingSequence.fromSchedule(
      classes,
      DateTime(2026, 11, 9, 9, 20),
    );
    expect(sequence.current?.title, 'Synthetic English');
    expect(sequence.next?.title, 'Synthetic Maths');
    expect(sequence.following?.title, 'Synthetic Science');
  });


  test('two consecutive periods are one session with original slots intact', () {
    final original = [
      TimeSlotClass(title: 'J1FG G1', dayOfWeek: 1, startMinutes: 540, endMinutes: 590),
      TimeSlotClass(title: 'J1FG G1 ', dayOfWeek: 1, startMinutes: 600, endMinutes: 650),
      TimeSlotClass(title: 'J2 Science', dayOfWeek: 1, startMinutes: 660, endMinutes: 710),
    ];
    final now = DateTime(2026, 11, 10, 9, 55); // short break inside the block
    final joined = HomeTeachingSequence.fromSchedule(original, now);
    expect(joined.current?.title, 'J1FG G1');
    expect(joined.current?.periodCount, 2);
    expect(joined.current?.startAt.hour, 9);
    expect(joined.current?.endAt.hour, 10);
    expect(joined.current?.endAt.minute, 50);
    expect(joined.next?.title, 'J2 Science');
    expect(original.length, 3); // no underlying timetable modifications
    final separate = HomeTeachingSequence.fromSchedule(
      original, now, combineConsecutivePeriods: false);
    expect(separate.current, isNull); // short break remains visible
    expect(separate.next?.title.trim(), 'J1FG G1');
    expect(separate.next?.periodCount, 1);
  });

  test('distinct classes and long breaks remain separate sessions', () {
    final original = [
      TimeSlotClass(title: 'EEP1', dayOfWeek: 1, startMinutes: 540, endMinutes: 590),
      TimeSlotClass(title: 'EEP2', dayOfWeek: 1, startMinutes: 600, endMinutes: 650),
      TimeSlotClass(title: 'EEP2', dayOfWeek: 1, startMinutes: 690, endMinutes: 740),
    ];
    final seq = HomeTeachingSequence.fromSchedule(original, DateTime(2026, 11, 10, 8, 0));
    expect(seq.next?.title, 'EEP1');
    expect(seq.next?.periodCount, 1);
    expect(seq.following?.title, 'EEP2');
    expect(seq.following?.periodCount, 1);
  });

  test('prior teacher timetable cannot leak into a different user account',
      () async {
    const service = HomeWeeklyTimetableService();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'dashboard_timetables_v1:teacher-a',
      jsonEncode([
        {
          'id': 't-1',
          'name': 'Schedule A',
          'grid': grid,
          'uploadedAt': '2026-11-09T00:00:00.000',
          'base64': '',
        }
      ]),
    );
    await prefs.setString('dashboard_selected_timetable_v1:teacher-a', 't-1');
    expect((await service.loadSelected('teacher-a'))?.name, 'Schedule A');
    expect(await service.loadSelected('teacher-b'), isNull);
  });


  test('timetable inspection never changes a saved timetable', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'dashboard_selected_timetable_v1:inspection-teacher',
      'existing-week',
    );
    final bytes = Uint8List.fromList(utf8.encode(
      'Time,Monday,Tuesday,Wednesday,Thursday,Friday\\n'
      '09:00-09:50,Synthetic English,,Synthetic Science,,\\n'
      '10:00-10:50,Synthetic Maths,,,,\\n',
    ));
    final inspected = HomeWeeklyTimetableService.inspectBytes(
      filename: 'timetable.csv',
      bytes: bytes,
    );
    expect(inspected.classes.length, 3);
    expect(
      prefs.getString('dashboard_selected_timetable_v1:inspection-teacher'),
      'existing-week',
    );
    expect(prefs.getString('dashboard_timetables_v1:inspection-teacher'), isNull);
  });

  test('valid CSV import saves the selected timetable in existing format',
      () async {
    const service = HomeWeeklyTimetableService();
    final bytes = Uint8List.fromList(utf8.encode(
      'Time,Monday,Tuesday,Wednesday,Thursday,Friday\n'
      '09:00-09:50,Synthetic English,,Synthetic Science,,\n'
      '10:00-10:50,Synthetic Maths,,,,\n',
    ));
    final imported = await service.importForTeacher(
      userId: 'teacher-c',
      filename: 'school-timetable.csv',
      bytes: bytes,
    );
    expect(imported.classes.length, 3);
    final reloaded = await service.loadSelected('teacher-c');
    expect(reloaded?.name, 'school-timetable.csv');
    expect(reloaded?.classes.length, 3);
  });

  test('invalid file cannot overwrite the selected timetable', () async {
    const service = HomeWeeklyTimetableService();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'dashboard_selected_timetable_v1:teacher-d',
      'existing-timetable',
    );
    expect(
      () => service.importForTeacher(
        userId: 'teacher-d',
        filename: 'bad.csv',
        bytes: Uint8List.fromList(utf8.encode('No,weekday,clock\n1,2,3')),
      ),
      throwsFormatException,
    );
    expect(
      prefs.getString('dashboard_selected_timetable_v1:teacher-d'),
      'existing-timetable',
    );
  });
}

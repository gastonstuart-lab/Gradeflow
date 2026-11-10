import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gradeflow/services/home_weekly_timetable_service.dart';
import 'package:gradeflow/services/file_import_service.dart';

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

  test('valid CSV import saves the selected timetable in existing format',
      () async {
    const service = HomeWeeklyTimetableService();
    final bytes = Uint8List.fromList(utf8.encode(
      'Time,Monday,Tuesday,Wednesday,Thursday,Friday\n'
      '09:00-09:50,Synthetic English,,Synthetic Science,,\n'
      '10:00-10:50,Synthetic Maths,,,,\n',
    ));
    final csvRows = FileImportService().rowsFromAnyBytes(bytes);
    // Diagnostics for real-world CSV import compatibility.
    // ignore: avoid_print
    print('Home timetable CSV rows: $csvRows');
    // ignore: avoid_print
    print('Home timetable cleaned: ${FileImportService().cleanTimetableGrid(csvRows)}');
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

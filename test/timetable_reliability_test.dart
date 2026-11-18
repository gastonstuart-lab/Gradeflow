import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gradeflow/models/class.dart' as school;
import 'package:gradeflow/services/home_weekly_timetable_service.dart';
import 'package:gradeflow/services/timetable_import_plan.dart';
import 'package:gradeflow/services/dashboard_preferences_service.dart';

List<school.Class> timetableClasses(String teacher) => List.generate(8, (i) {
      final subject = ['EEP', 'Science', 'Performance Arts'][i % 3];
      return school.Class(
          classId: 'group-$i',
          className: '$subject G${i + 1}',
          subject: subject,
          teacherId: teacher,
          schoolYear: '2026',
          term: 'Fall',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026));
    });

List<List<String>> timetableGrid({bool multiRow = false}) {
  final classes = timetableClasses('teacher-a');
  final rows = <List<String>>[
    ['School timetable'],
    ['Period', 'Time', ...TimetableImportPlan.weekdays],
  ];
  final assignments = [
    for (var i = 0; i < 8; i++) ...[i, i],
    for (var i = 0; i < 8; i++) i
  ];
  var index = 0;
  final cells = <String, String>{};
  for (var d = 0; d < 5; d++) {
    for (var p = 0; p < (d < 2 ? 6 : 4); p++) {
      cells['$d-$p'] = classes[assignments[index++]].className;
    }
  }
  for (var p = 0; p < 8; p++) {
    if (p == 4) rows.add(['Lunch', '12:00-13:00', '', '', '', '', '']);
    final start = (p < 4 ? 8 * 60 : 13 * 60) + (p < 4 ? p : p - 4) * 55;
    String clock(int v) =>
        '${(v ~/ 60).toString().padLeft(2, '0')}:${(v % 60).toString().padLeft(2, '0')}';
    final labels = List.generate(5, (d) => cells['$d-$p'] ?? '');
    rows.add([
      '${p + 1}',
      '${clock(start)}-${clock(start + 45)}',
      ...labels.map((label) => multiRow && label.isNotEmpty
          ? label.substring(0, label.lastIndexOf(' '))
          : label)
    ]);
    if (multiRow)
      rows.add([
        'Group',
        '',
        ...labels.map((label) => label.isEmpty ? '' : label.split(' ').last)
      ]);
  }
  return rows;
}

Uint8List csvBytes(List<List<String>> grid) =>
    Uint8List.fromList(utf8.encode(const ListToCsvConverter().convert(grid)));

class FailingTimetablePreferences extends DashboardPreferencesService {
  const FailingTimetablePreferences();
  @override
  Future<void> writeString(
          {required String key, required String? value}) async =>
      throw StateError('Synthetic disk failure');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('CSV, XLSX and DOCX preserve 24 individual periods and eight groups',
      () {
    for (final multiRow in [false, true]) {
      final grid = timetableGrid(multiRow: multiRow);
      final excel = Excel.createExcel();
      for (final row in grid) {
        excel['Sheet1'].appendRow(row.map(TextCellValue.new).toList());
      }
      final xml =
          '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:tbl>'
          '${grid.map((r) => '<w:tr>${r.map((c) => '<w:tc><w:p><w:r><w:t>$c</w:t></w:r></w:p></w:tc>').join()}</w:tr>').join()}'
          '</w:tbl></w:body></w:document>';
      final archive = Archive()
        ..addFile(ArchiveFile(
            'word/document.xml', utf8.encode(xml).length, utf8.encode(xml)));
      final files = {
        'csv': csvBytes(grid),
        'xlsx': Uint8List.fromList(excel.encode()!),
        'docx': Uint8List.fromList(ZipEncoder().encode(archive)!)
      };
      for (final file in files.entries) {
        final plan = HomeWeeklyTimetableService.inspectBytes(
            filename: 'school.${file.key}', bytes: file.value);
        expect(plan.classes, hasLength(24),
            reason: '${file.key} multiRow=$multiRow');
        expect(plan.classes.map((l) => l.title).toSet(), hasLength(8));
        expect(plan.classes.where((l) => l.title == 'EEP G1'), hasLength(3));
      }
    }
  });

  test(
      'invalid clocks, absent ends, headings, labels, overlaps and duplicates reject',
      () {
    final bad = <List<List<String>>>[
      [
        ['Day', 'Start', 'End', 'Class'],
        ['Saturday', '09:00', '10:00', 'EEP']
      ],
      [
        ['Day', 'Start', 'End', 'Class'],
        ['Monday', '25:00', '26:00', 'EEP']
      ],
      [
        ['Day', 'Start', 'End', 'Class'],
        ['Monday', '09:00', '', 'EEP']
      ],
      [
        ['Day', 'Start', 'End', 'Class'],
        ['Monday', '10:00', '09:00', 'EEP']
      ],
      [
        ['Day', 'Start', 'End', 'Class'],
        ['Monday', '09:00', '10:00', '']
      ],
      [
        ['Day', 'Start', 'End', 'Class'],
        ['Monday', '09:00', '10:00', 'EEP'],
        ['Monday', '09:30', '10:30', 'Science']
      ],
      [
        ['Day', 'Start', 'End', 'Class'],
        ['Monday', '09:00', '10:00', 'EEP'],
        ['Monday', '09:00', '10:00', 'EEP']
      ],
      [
        ['Time', ...TimetableImportPlan.weekdays],
        ['09:00', 'EEP', '', '', '', '']
      ],
      [
        ['Time', 'Monday', 'Monday', 'Wednesday', 'Thursday', 'Friday'],
        ['09:00-10:00', 'EEP', '', '', '', '']
      ],
    ];
    for (final grid in bad) {
      expect(() => TimetableImportPlan.fromGrid(grid), throwsFormatException);
    }
  });

  test('matching uses owned stable IDs and requires explicit ambiguous choices',
      () {
    final classes = timetableClasses('teacher-a');
    final lessons = TimetableImportPlan.fromGrid(timetableGrid()).lessons;
    final choices = {for (final c in classes) c.className: c.classId};
    final matched = TimetableImportPlan(lessons)
        .confirmMatches(choices, classes, 'teacher-a');
    expect(matched.every((l) => l.classId != null), isTrue);
    expect(
        () => TimetableImportPlan(lessons)
            .confirmMatches({}, classes, 'teacher-a'),
        throwsFormatException);
    expect(
        () => TimetableImportPlan(lessons)
            .confirmMatches(choices, classes, 'teacher-b'),
        throwsFormatException);
    final duplicate = school.Class(
        classId: 'ambiguous',
        className: classes.first.className,
        subject: 'EEP',
        teacherId: 'teacher-a',
        schoolYear: '2026',
        term: 'Fall',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026));
    expect(
        TimetableImportPlan.candidates(lessons.first, [...classes, duplicate]),
        hasLength(2));
  });

  test(
      'failed import and failed version selection preserve data, reload and isolation',
      () async {
    const service = HomeWeeklyTimetableService();
    final classes = timetableClasses('teacher-a');
    final args = {for (final c in classes) c.className: c.classId};
    final bytes = csvBytes(timetableGrid());
    await service.importForTeacher(
        userId: 'teacher-a',
        filename: 'first.csv',
        bytes: bytes,
        classMatches: args,
        availableClasses: classes);
    final before = await service.loadVersions('teacher-a');
    final firstId = before.single['id'] as String;
    const failing =
        HomeWeeklyTimetableService(preferences: FailingTimetablePreferences());
    await expectLater(
        failing.importForTeacher(
            userId: 'teacher-a',
            filename: 'failed.csv',
            bytes: bytes,
            classMatches: args,
            availableClasses: classes),
        throwsStateError);
    expect(await service.loadVersions('teacher-a'), before);
    expect((await service.loadSelected('teacher-a'))!.classes, hasLength(24));
    expect(
        (await service.loadSelected('teacher-a'))!
            .classes
            .every((l) => l.classId != null),
        isTrue);
    expect(await service.loadSelected('teacher-b'), isNull);
    await service.importForTeacher(
        userId: 'teacher-a',
        filename: 'second.csv',
        bytes: bytes,
        classMatches: args,
        availableClasses: classes);
    await expectLater(failing.changeVersion('teacher-a', versionId: firstId),
        throwsStateError);
    expect((await service.loadSelected('teacher-a'))!.name, 'second.csv');
    await service.changeVersion('teacher-a', versionId: firstId);
    expect((await service.loadSelected('teacher-a'))!.name, 'first.csv');
    await expectLater(service.changeVersion('teacher-a', versionId: 'missing'),
        throwsFormatException);
    expect(await service.loadVersions('teacher-a'), hasLength(2));
    await expectLater(
        service.importForTeacher(
            userId: 'teacher-a',
            filename: 'bad.csv',
            bytes: csvBytes([
              ['bad']
            ]),
            classMatches: args,
            availableClasses: classes),
        throwsFormatException);
    expect((await service.loadSelected('teacher-a'))!.name, 'first.csv');
  });
  test('corrected Day Start End Class ID format uses explicit Excel time cells',
      () {
    final excel = Excel.createExcel();
    excel['Sheet1'].appendRow(['Day', 'Start', 'End', 'Class', 'Class ID']
        .map(TextCellValue.new)
        .toList());
    excel['Sheet1'].appendRow([
      TextCellValue('Monday'),
      const TimeCellValue(hour: 9),
      const TimeCellValue(hour: 9, minute: 45),
      TextCellValue('EEP G1'),
      TextCellValue('group-0')
    ]);
    final parsed = HomeWeeklyTimetableService.inspectBytes(
        filename: 'corrected.xlsx', bytes: Uint8List.fromList(excel.encode()!));
    expect(parsed.classes.single.classId, 'group-0');
    expect(parsed.classes.single.startMinutes, 540);
    expect(parsed.classes.single.endMinutes, 585);
  });

  test('concurrent imports retain both versions', () async {
    const service = HomeWeeklyTimetableService();
    final classes = timetableClasses('teacher-a');
    Future<HomeWeeklyTimetable> save(String name) => service.importForTeacher(
        userId: 'teacher-a',
        filename: name,
        bytes: csvBytes(timetableGrid()),
        classMatches: {for (final c in classes) c.className: c.classId},
        availableClasses: classes);
    await Future.wait([save('one.csv'), save('two.csv')]);
    expect(await service.loadVersions('teacher-a'), hasLength(2));
    expect((await service.loadSelected('teacher-a'))!.name, 'two.csv');
  });
  test('index and Period / Time headers retain all eight groups and 24 periods',
      () {
    final indexed = timetableGrid();
    indexed[1][0] = 'index';
    final combined = <List<String>>[
      ['Period / Time', ...TimetableImportPlan.weekdays],
      for (final row in timetableGrid().skip(2)) [row[1], ...row.skip(2)],
    ];
    final reference = TimetableImportPlan.fromGrid(timetableGrid()).lessons;
    for (final grid in [indexed, combined]) {
      final lessons = TimetableImportPlan.fromGrid(grid).lessons;
      expect(lessons, hasLength(24));
      expect(lessons.map((l) => l.title).toSet(), hasLength(8));
      expect(
          lessons
              .map((l) =>
                  '${l.dayOfWeek}/${l.startMinutes}/${l.endMinutes}/${l.title}')
              .toList(),
          reference
              .map((l) =>
                  '${l.dayOfWeek}/${l.startMinutes}/${l.endMinutes}/${l.title}')
              .toList());
    }
    indexed[2][1] = '08:00';
    expect(() => TimetableImportPlan.fromGrid(indexed), throwsFormatException);
  });

  test('labelled subject/group/room rows preserve room separately', () {
    final grid = [
      ['index', 'Time', ...TimetableImportPlan.weekdays],
      ['1', '08:00-08:50', 'EEP', '', '', '', ''],
      ['', 'Group', 'G1', '', '', '', ''],
      ['', 'Room', 'A101', '', '', '', ''],
      ['2', '09:00-09:50', 'EEP', '', '', '', ''],
      ['', 'Group', 'G1', '', '', '', ''],
      ['', 'Room', 'A101', '', '', '', ''],
    ];
    final lessons = TimetableImportPlan.fromGrid(grid).lessons;
    expect(lessons, hasLength(2));
    expect(
        lessons.every((l) => l.title == 'EEP G1' && l.room == 'A101'), isTrue);
    final classes = timetableClasses('teacher-a');
    final linked = TimetableImportPlan(lessons)
        .confirmMatches({'EEP G1': 'group-0'}, classes, 'teacher-a');
    expect(linked.every((l) => l.room == 'A101'), isTrue);
    final restored = linked
        .map((l) => HomeWeeklyTimetableService.lessonFromJson(
            HomeWeeklyTimetableService.lessonToJson(l)))
        .toList();
    expect(
        restored.every((l) => l.title == 'EEP G1' && l.room == 'A101'), isTrue);
    grid[4][1] = '';
    expect(() => TimetableImportPlan.fromGrid(grid), throwsFormatException);
  });

  test('corrected long-form Room column stays separate from class label', () {
    final lesson = TimetableImportPlan.fromGrid([
      ['Day', 'Start', 'End', 'Class', 'Room'],
      ['Monday', '08:00', '08:50', 'EEP G1', 'A101'],
    ]).lessons.single;
    expect(lesson.title, 'EEP G1');
    expect(lesson.room, 'A101');
  });
}

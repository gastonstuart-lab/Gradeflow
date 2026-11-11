import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/services/school_calendar_grid_parser.dart';

void main() {
  final headers = <String>[
    'Month', 'Week', 'Sun.', 'Mon.', 'Tue.', 'Wed.', 'Thu.', 'Fri.',
    'Sat.', 'Date: Event',
  ];

  test('2026-F weekly sheet extracts every event from multiline cells', () {
    final rows = <List<String>>[
      ['Calendar for the Fall Semester, ', '', '', '', '', '', '', '', '', '2026'],
      headers,
      ['Aug', 'S.V.', '7/19', '7/20', '7/21', '7/22', '7/23',
        '7/24', '7/25', '7/23-24 J1/H1 Orientation'],
      ['', 'S.V.', '7/26', '7/27', '7/28', '7/29',
        '7/30', '7/31', '1',
        '7/27-8/14：Summer Class\n7/31：J1 English Exam\n8/14：J2 English Singing Contest'],
      ['Sep', '1', '8/30', '8/31', '1', '2', '3', '4', '5',
        '8/31：The First Day of School\n2-3: H2/3 Mock Exams\n4：Homeroom Class Time'],
      ['Oct', '5', '27', '28', '29', '30', '1', '2', '3',
        "29-10/5：J1 ESL/EEP Homework Check\n9/28：Teacher's Day Holiday"],
      ['', '7', '11', '12', '13', '14', '15', '16', '17',
        '12-16：J2 ESL/EEP Homework Check\n14-15：1st School Exams\n16：Club Time'],
      ['Dec', '18', '27', '28', '29', '30', '31', '1/1', '1/2',
        "30-31：H3 3rd School Exams\n1/1：New Year's Day"],
      ['Jan', '19', '3', '4', '5', '6', '7', '8', '9',
        '4-8：H1/H2 Final Exams\n4：J1 Final Exams\n5：J2 Final Exams'],
      ['Feb', 'W.V.', '1/31', '1', '2', '3', '4', '5', '6',
        '4-10：Chinese New Year'],
    ];

    expect(SchoolCalendarGridParser.matches(rows), isTrue);
    final entries = SchoolCalendarGridParser.parse(rows,
        filename: '2026-F Calendar.xlsx');
    expect(entries.length, 18);

    SchoolCalendarGridEvent named(String title) =>
      entries.singleWhere((event) => event.title == title);

    expect(named('J1/H1 Orientation').start, DateTime(2026, 7, 23));
    expect(named('J1/H1 Orientation').end, DateTime(2026, 7, 24));
    expect(named('Summer Class').start, DateTime(2026, 7, 27));
    expect(named('Summer Class').end, DateTime(2026, 8, 14));
    expect(named('J1 ESL/EEP Homework Check').start,
        DateTime(2026, 9, 29));
    expect(named('J1 ESL/EEP Homework Check').end,
        DateTime(2026, 10, 5));
    expect(named('J2 ESL/EEP Homework Check').end,
        DateTime(2026, 10, 16));
    expect(named("New Year's Day").start, DateTime(2027, 1, 1));
    expect(named('H1/H2 Final Exams').start, DateTime(2027, 1, 4));
    expect(named('Chinese New Year').start, DateTime(2027, 2, 4));
    expect(named('Chinese New Year').end, DateTime(2027, 2, 10));
  });

  test('ordinary Date,Event CSV stays in existing importer', () {
    expect(SchoolCalendarGridParser.matches([
      ['Date', 'Event'],
      ['2026-11-11', 'School Event'],
    ]), isFalse);
  });

  test('invalid ranges do not become normalized dates in another month', () {
    final rows = [
      headers,
      ['Nov', '10', '', '', '', '', '', '', '',
        '31：Invalid November day\n11：Valid Event'],
    ];
    final entries = SchoolCalendarGridParser.parse(rows,
        filename: '2026-F Calendar.xlsx');
    expect(entries.length, 1);
    expect(entries.single.title, 'Valid Event');
    expect(entries.single.start, DateTime(2026, 11, 11));
  });
}

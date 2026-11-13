import 'dart:io';
import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/services/home_weekly_timetable_service.dart';

// External acceptance inputs are deliberately not committed to the repository.
void main() {
  const csvPath = String.fromEnvironment('TIMETABLE_ACCEPTANCE_CSV');
  const xlsxPath = String.fromEnvironment('TIMETABLE_ACCEPTANCE_XLSX');
  for (final input in {'csv': csvPath, 'xlsx': xlsxPath}.entries) {
    test(
        'actual corrected ${input.key} has eight groups and 24 unchanged periods',
        () async {
      final source = File(csvPath);
      final rows =
          const CsvToListConverter(eol: '\n', shouldParseNumbers: false)
              .convert(utf8
                  .decode(await source.readAsBytes())
                  .replaceAll('\r\n', '\n')
                  .replaceAll('\uFEFF', ''));
      final headings = rows.first.map((c) => c.toString()).toList();
      final timeColumn = headings.indexOf('Time');
      final expected = <String>[];
      for (final row in rows.skip(1)) {
        if (row.every((c) => c.toString().trim().isEmpty)) continue;
        final times = row[timeColumn].toString().split('-');
        int minutes(String clock) {
          final parts = clock.split(':').map(int.parse).toList();
          return parts[0] * 60 + parts[1];
        }

        for (var day = 0; day < 5; day++) {
          final column = headings.indexOf(
              ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'][day]);
          final title = row[column].toString().trim();
          if (title.isNotEmpty)
            expected
                .add('$day/${minutes(times[0])}/${minutes(times[1])}/$title');
        }
      }
      final parsed = HomeWeeklyTimetableService.inspectBytes(
          filename: input.value, bytes: await File(input.value).readAsBytes());
      expect(parsed.classes, hasLength(24));
      expect(parsed.classes.map((l) => l.title).toSet(), hasLength(8));
      final actual = parsed.classes
          .map((l) =>
              '${l.dayOfWeek}/${l.startMinutes}/${l.endMinutes}/${l.title}')
          .toList();
      expect(actual..sort(), expected..sort());
    },
        skip: input.value.isEmpty || csvPath.isEmpty
            ? 'Supply original corrected acceptance files explicitly.'
            : false);
  }
}

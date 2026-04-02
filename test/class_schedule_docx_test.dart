import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/services/class_schedule_service.dart';
import 'package:gradeflow/services/file_import_service.dart';

void main() {
  test('parse class schedule from docx table bytes', () {
    final bytes = _buildDocxWithScheduleTable([
      [
        ['Title of the Book:', 'Performance Arts'],
      ],
      [
        [
          '1.Teaching Objectives',
          'Build confidence and teamwork through performance.',
        ],
        ['2. Evaluation Method', 'GPA and exams'],
        [
          'Week',
          'DATE',
          'Lesson subject and goals (Title code, pg.#)',
          'Activities',
          'Tests and Quizzes',
          'School Remarks',
          'Major Issues',
        ],
        [
          '1',
          '2/8-2/14',
          'Subject: Warm-up & Confidence',
          'Charades and movement games',
          '',
          'Lunar New Year preparation',
          'Life Education',
        ],
      ],
    ]);

    final importer = FileImportService();
    final rows = importer.rowsFromAnyBytes(bytes);
    final items = ClassScheduleService().parseFromBytes(bytes);

    expect(rows, isNotEmpty);
    expect(items, hasLength(1));
    expect(items.first.week, 1);
    expect(items.first.date, DateTime(DateTime.now().year, 2, 8));
    expect(items.first.title, contains('Warm-up & Confidence'));
  });
}

Uint8List _buildDocxWithScheduleTable(List<List<List<String>>> tables) {
  final xmlBuffer = StringBuffer()
    ..writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
    ..writeln(
      '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>',
    );

  for (final table in tables) {
    xmlBuffer.writeln('<w:tbl>');
    for (final row in table) {
      xmlBuffer.writeln('<w:tr>');
      for (final cell in row) {
        final escaped = const HtmlEscape().convert(cell);
        xmlBuffer.writeln(
          '<w:tc><w:p><w:r><w:t>$escaped</w:t></w:r></w:p></w:tc>',
        );
      }
      xmlBuffer.writeln('</w:tr>');
    }
    xmlBuffer.writeln('</w:tbl>');
  }

  xmlBuffer.writeln('<w:sectPr/></w:body></w:document>');

  final archive = Archive()
    ..addFile(
      ArchiveFile(
        'word/document.xml',
        utf8.encode(xmlBuffer.toString()).length,
        utf8.encode(xmlBuffer.toString()),
      ),
    );

  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}

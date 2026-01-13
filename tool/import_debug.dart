import 'dart:io';
import 'dart:typed_data';

import 'package:gradeflow/services/file_import_service.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln('Usage: dart run tool/import_debug.dart <path-to-csv-or-xlsx>');
    exitCode = 64;
    return;
  }

  final path = args.join(' ');
  final file = File(path);
  if (!await file.exists()) {
    stderr.writeln('File not found: $path');
    exitCode = 66;
    return;
  }

  final bytes = Uint8List.fromList(await file.readAsBytes());
  final name = file.uri.pathSegments.isNotEmpty ? file.uri.pathSegments.last : path;
  final isZip = bytes.length > 2 && bytes[0] == 0x50 && bytes[1] == 0x4B;

  final importer = FileImportService();

  stdout.writeln('File: $name');
  stdout.writeln('Bytes: ${bytes.length}');
  stdout.writeln('Looks like XLSX/ZIP: $isZip');

  if (!isZip) {
    final text = importer.decodeTextFromBytes(bytes);
    final firstLine = text.split(RegExp(r'\r?\n')).firstWhere((l) => l.trim().isNotEmpty, orElse: () => '');
    stdout.writeln(
      'Text sample (first non-empty line): ${firstLine.length > 200 ? '${firstLine.substring(0, 200)}…' : firstLine}',
    );
  }

  // Raw rows
  final rows = importer.rowsFromAnyBytes(bytes);
  stdout.writeln('Rows extracted: ${rows.length}');
  for (var i = 0; i < rows.length && i < 5; i++) {
    stdout.writeln('Row[$i]: ${rows[i].take(12).toList()}');
  }

  // Roster parse
  final roster = isZip
      ? importer.parseXlsxRoster(bytes)
      : importer.parseCSV(importer.decodeTextFromBytes(bytes));

  stdout.writeln('Roster parsed: total=${roster.length} valid=${roster.where((r) => r.isValid).length} invalid=${roster.where((r) => !r.isValid).length}');
  for (final r in roster.take(5)) {
    stdout.writeln(' - id=${r.studentId} cn=${r.chineseName} en=${r.englishFirstName} ${r.englishLastName} seat=${r.seatNo} class=${r.classCode} valid=${r.isValid} err=${r.error ?? ''}');
  }
}

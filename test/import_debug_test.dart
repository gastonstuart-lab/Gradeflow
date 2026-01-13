import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/services/file_import_service.dart';

void main() {
  test('Import samples diagnostics', () async {
    final importer = FileImportService();

    final dirPath = const String.fromEnvironment('IMPORT_DEBUG_DIR', defaultValue: 'import_samples');
    final dir = Directory(dirPath);
    if (!dir.existsSync()) {
      fail('Directory not found: ${dir.path}');
    }

    final files = dir
        .listSync()
        .whereType<File>()
        .toList()
      ..sort((a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()));

    if (files.isEmpty) {
      fail('No files found in: ${dir.path}');
    }

    for (final file in files) {
      final name = file.uri.pathSegments.isNotEmpty ? file.uri.pathSegments.last : file.path;
      final bytes = Uint8List.fromList(await file.readAsBytes());
      final isZip = bytes.length > 2 && bytes[0] == 0x50 && bytes[1] == 0x4B;

      // ignore: avoid_print
      print('\n=== $name ===');
      // ignore: avoid_print
      print('Bytes: ${bytes.length} ZIP/XLSX: $isZip');

      final rows = importer.rowsFromAnyBytes(bytes);
      // ignore: avoid_print
      print('Rows extracted: ${rows.length}');
      for (var i = 0; i < rows.length && i < 5; i++) {
        // ignore: avoid_print
        print('Row[$i]: ${rows[i].take(12).toList()}');
      }

      final roster = isZip
          ? importer.parseXlsxRoster(bytes)
          : importer.parseCSV(importer.decodeTextFromBytes(bytes));
      // ignore: avoid_print
      print('Roster parsed: total=${roster.length} valid=${roster.where((r) => r.isValid).length} invalid=${roster.where((r) => !r.isValid).length}');

      if (roster.isEmpty) {
        final diag = importer.diagnosticsForFile(bytes, filename: name);
        // ignore: avoid_print
        print('--- Diagnostics ---\n$diag');
      }
    }
  });
}

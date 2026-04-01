import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/services/file_import_service.dart';

void main() {
  test('parses school-wide roster workbook with class codes', () async {
    final file = File('import_samples/raw/2026-S Roster Junior High (0121).xlsx');
    if (!file.existsSync()) {
      // Keep test non-blocking for environments without sample files.
      return;
    }

    final bytes = Uint8List.fromList(await file.readAsBytes());
    final importer = FileImportService();
    final parsed = importer.parseXlsxRoster(bytes);
    final valid = parsed.where((p) => p.isValid).toList();

    expect(valid.length, greaterThan(200));
    expect(
      valid.where((p) => (p.classCode ?? '').trim().isNotEmpty).length,
      greaterThan(150),
    );
    expect(
      valid.where((p) => (p.studentId ?? '').trim().isNotEmpty).length,
      valid.length,
    );
  });
}

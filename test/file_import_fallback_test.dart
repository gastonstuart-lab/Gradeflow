import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/services/file_import_service.dart';

void main() {
  test('fallback-heavy XLSX roster samples still parse valid students',
      () async {
    final importer = FileImportService();
    const samples = <String>[
      'import_samples/Science_Group4_Final_Grading.xlsx',
      'import_samples/Science_Group6_Final_Grading.xlsx',
      'import_samples/THUHS – EEP3-J2FG – Grading_updated.xlsx',
    ];

    for (final path in samples) {
      final file = File(path);
      expect(file.existsSync(), isTrue, reason: 'Missing sample file: $path');

      final bytes = Uint8List.fromList(await file.readAsBytes());
      final parsed = importer.parseXlsxRoster(bytes);
      final valid = parsed.where((row) => row.isValid).toList();

      expect(valid, isNotEmpty, reason: 'No valid rows parsed for $path');
      expect(
        valid.where((row) => (row.studentId ?? '').trim().isNotEmpty),
        hasLength(valid.length),
        reason: 'Some parsed rows in $path are missing student IDs',
      );
    }
  });

  test('rowsFromAnyBytes routes DOCX tables before XLSX parsing', () async {
    final file = File('import_samples/Stuart.docx');
    if (!file.existsSync()) {
      return;
    }

    final importer = FileImportService();
    final bytes = Uint8List.fromList(await file.readAsBytes());
    final rows = importer.rowsFromAnyBytes(bytes);

    expect(rows, isNotEmpty);
    expect(rows.first.length, greaterThanOrEqualTo(3));
  });
}

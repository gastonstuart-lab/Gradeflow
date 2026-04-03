part of '../file_import_service.dart';

class ImportedClass {
  final String? className;
  final String? subject;
  final String? groupNumber;
  final String? schoolYear;
  final String? term;
  final bool isValid;
  final String? error;

  ImportedClass({
    this.className,
    this.subject,
    this.groupNumber,
    this.schoolYear,
    this.term,
    required this.isValid,
    this.error,
  });
}

extension FileImportServiceClasses on FileImportService {
  List<ImportedClass> parseClassesCsv(String csvContent) {
    try {
      final rows = _parseDelimitedText(csvContent);
      if (rows.isEmpty) return [];
      final headerRowIndex = _pickHeaderRowIndex(rows);
      if (headerRowIndex < 0 || headerRowIndex >= rows.length) return [];
      final headers = rows[headerRowIndex].map(_normalizeName).toList();

      // Be generous with header variants
      final nameIdx = _findColumnIndex(headers, [
        'class name',
        'classname',
        'name',
        'class',
        'class code',
        'classcode',
        'section',
        '??',
        '??'
      ]);
      final subjectIdx = _findColumnIndex(
          headers, ['subject', 'course', '??', 'subject name', 'coursename']);
      final groupIdx = _findColumnIndex(headers,
          ['group number', 'group', 'groupnumber', '?', 'set', 'stream']);
      final yearIdx = _findColumnIndex(headers, [
        'school year',
        'schoolyear',
        'year',
        'academic year',
        'academicyear',
        'session',
        'sy',
        '??'
      ]);
      final termIdx =
          _findColumnIndex(headers, ['term', 'semester', 'sem', '??']);
      final combinedYearTermIdx = _findColumnIndex(headers, [
        'year term',
        'school year term',
        'year/term',
        'academic year term',
        '????'
      ]);

      final out = <ImportedClass>[];
      for (int i = headerRowIndex + 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.every((c) => c.trim().isEmpty)) continue;
        String? cell(int idx) =>
            idx != -1 && idx < row.length ? row[idx].toString().trim() : null;

        String? name = cell(nameIdx);
        String? subject = cell(subjectIdx);
        final group = cell(groupIdx);
        String? year = cell(yearIdx);
        String? term = cell(termIdx);
        final combined = cell(combinedYearTermIdx);

        // If combined Year/Term exists, try to split
        if ((year == null || year.isEmpty || term == null || term.isEmpty) &&
            combined != null &&
            combined.isNotEmpty) {
          final yt = _splitYearTerm(combined);
          year ??= yt.$1;
          term ??= yt.$2;
        }

        // Fallback subject
        subject = (subject == null || subject.isEmpty) ? 'General' : subject;

        if ((name == null || name.isEmpty) ||
            (year == null || year.isEmpty) ||
            (term == null || term.isEmpty)) {
          out.add(ImportedClass(
            className: name,
            subject: subject,
            groupNumber: group,
            schoolYear: year,
            term: term,
            isValid: false,
            error: 'Class Name, Subject, School Year and Term are required',
          ));
          continue;
        }

        out.add(ImportedClass(
          className: name,
          subject: subject,
          groupNumber: group,
          schoolYear: year,
          term: term,
          isValid: true,
        ));
      }
      return out;
    } catch (e) {
      debugPrint('Failed to parse CSV classes: $e');
      return [];
    }
  }

  List<ImportedClass> parseClassesXlsx(Uint8List bytes) {
    try {
      final rows = _rowsFromExcel(bytes);
      if (rows.isEmpty) return [];
      final headerRowIndex = _pickHeaderRowIndex(rows);
      if (headerRowIndex < 0 || headerRowIndex >= rows.length) return [];
      final headers = rows[headerRowIndex].map(_normalizeName).toList();

      final nameIdx = _findColumnIndex(headers, [
        'class name',
        'classname',
        'name',
        'class',
        'class code',
        'classcode',
        'section',
        '??',
        '??'
      ]);
      final subjectIdx = _findColumnIndex(
          headers, ['subject', 'course', '??', 'subject name', 'coursename']);
      final groupIdx = _findColumnIndex(headers,
          ['group number', 'group', 'groupnumber', '?', 'set', 'stream']);
      final yearIdx = _findColumnIndex(headers, [
        'school year',
        'schoolyear',
        'year',
        'academic year',
        'academicyear',
        'session',
        'sy',
        '??'
      ]);
      final termIdx =
          _findColumnIndex(headers, ['term', 'semester', 'sem', '??']);
      final combinedYearTermIdx = _findColumnIndex(headers, [
        'year term',
        'school year term',
        'year/term',
        'academic year term',
        '????'
      ]);

      final out = <ImportedClass>[];
      for (int i = headerRowIndex + 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.every((c) => c.trim().isEmpty)) continue;
        String? cell(int idx) =>
            idx != -1 && idx < row.length ? row[idx].toString().trim() : null;

        String? name = cell(nameIdx);
        String? subject = cell(subjectIdx);
        final group = cell(groupIdx);
        String? year = cell(yearIdx);
        String? term = cell(termIdx);
        final combined = cell(combinedYearTermIdx);

        if ((year == null || year.isEmpty || term == null || term.isEmpty) &&
            combined != null &&
            combined.isNotEmpty) {
          final yt = _splitYearTerm(combined);
          year ??= yt.$1;
          term ??= yt.$2;
        }

        subject = (subject == null || subject.isEmpty) ? 'General' : subject;

        if ((name == null || name.isEmpty) ||
            (year == null || year.isEmpty) ||
            (term == null || term.isEmpty)) {
          out.add(ImportedClass(
            className: name,
            subject: subject,
            groupNumber: group,
            schoolYear: year,
            term: term,
            isValid: false,
            error: 'Class Name, Subject, School Year and Term are required',
          ));
          continue;
        }

        out.add(ImportedClass(
          className: name,
          subject: subject,
          groupNumber: group,
          schoolYear: year,
          term: term,
          isValid: true,
        ));
      }
      return out;
    } catch (e) {
      debugPrint('Failed to parse XLSX classes: $e');
      return [];
    }
  }

  /// Try to split a combined Year/Term field like:
  /// - "2024-2025 T1"
  /// - "2024/25 Term 1"
  /// - "2024-25 S2"
  /// Returns (year, term) with best-effort parsing; empty strings if unknown.
  (String, String) _splitYearTerm(String value) {
    final v = _normalizeName(value);
    String year = '';
    String term = '';

    // Year patterns
    final yearMatch = RegExp(r'(\d{4}\s*[-/]\s*\d{2,4})').firstMatch(value);
    if (yearMatch != null) {
      year = yearMatch.group(1)!.replaceAll(' ', '');
      year = year.replaceAll('/', '-');
    }

    // Term patterns: term/semester/sem/t/s + number/label
    final termMatch =
        RegExp(r'(term|semester|sem|t|s)\s*([0-9a-z]+)', caseSensitive: false)
            .firstMatch(v);
    if (termMatch != null) {
      term = (termMatch.group(1)!.toUpperCase().startsWith('S') ? 'S' : 'T') +
          termMatch.group(2)!.toUpperCase();
    }

    // Fallback: standalone numbers at end (e.g., "2024-25 1")
    if (term.isEmpty) {
      final endNum = RegExp(r'(\d+)\s*$').firstMatch(v);
      if (endNum != null) term = 'T${endNum.group(1)}';
    }

    return (year, term);
  }

  List<Class> convertToClasses(List<ImportedClass> imported, String teacherId) {
    final now = DateTime.now();
    final uuid = const Uuid();
    return imported
        .where((c) => c.isValid)
        .map((c) => Class(
              classId: uuid.v4(),
              className: c.className!,
              subject: c.subject!,
              groupNumber:
                  c.groupNumber?.isEmpty == true ? null : c.groupNumber,
              schoolYear: c.schoolYear!,
              term: c.term!,
              teacherId: teacherId,
              createdAt: now,
              updatedAt: now,
            ))
        .toList();
  }

  // --------------------
  // Helpers
  // --------------------
  // Public helper to extract tabular rows from bytes (CSV, XLSX, or DOCX).
  // Used by AI importer and schedule/timetable imports.
  List<List<String>> rowsFromAnyBytes(Uint8List bytes) {
    if (bytes.isEmpty) return const [];

    final isZip =
        bytes.length > 3 && bytes[0] == 0x50 && bytes[1] == 0x4B; // 'P''K'
    if (isZip && _zipContainsPath(bytes, 'word/document.xml')) {
      final rows = extractDocxBestTableGrid(bytes);
      if (rows.isNotEmpty) {
        return rows;
      }
    }

    return _rowsFromExcel(bytes);
  }

  bool _zipContainsPath(Uint8List bytes, String expectedPath) {
    try {
      final normalizedExpected = expectedPath.replaceAll('\\', '/');
      final archive = ZipDecoder().decodeBytes(bytes, verify: false);
      return archive.files.any(
        (file) => file.name.replaceAll('\\', '/') == normalizedExpected,
      );
    } catch (_) {
      return false;
    }
  }

  List<List<String>> _rowsFromExcel(Uint8List bytes) {
    try {
      if (bytes.isEmpty) {
        debugPrint('XLSX bytes are empty');
        return [];
      }
      debugPrint('XLSX bytes length: ${bytes.length}');

      // If file does not start with ZIP header (PK), treat as text and try delimited text directly
      final isZip =
          bytes.length > 3 && bytes[0] == 0x50 && bytes[1] == 0x4B; // 'P''K'
      if (!isZip) {
        try {
          final text = decodeTextFromBytes(bytes);
          if (text.trim().isNotEmpty) {
            // Heuristic: only treat as CSV if looks like delimited text
            final hasNewline = text.contains('\n');
            final hasSeparator =
                text.contains(',') || text.contains(';') || text.contains('\t');
            // Ratio of printable ASCII characters
            final printable = text.runes
                .where(
                    (r) => r >= 32 && r <= 126 || r == 10 || r == 13 || r == 9)
                .length;
            final ratio = printable / text.length;
            if (hasNewline && hasSeparator && ratio > 0.85) {
              debugPrint('Input not a ZIP/XLSX. Treating as CSV text.');
              return _parseDelimitedText(text);
            } else {
              debugPrint('Non-ZIP input does not resemble CSV; rejecting.');
              return [];
            }
          }
        } catch (e) {
          debugPrint('Non-ZIP text decode failed: $e');
        }
      }

      // Try excel decoding (can throw on some real-world XLSX files)
      late final Excel excel;
      try {
        excel = Excel.decodeBytes(bytes);
      } catch (e) {
        debugPrint('Excel.decodeBytes failed: $e');
        final fallback = _rowsFromXlsxZip(bytes);
        if (fallback.isNotEmpty) return fallback;
        rethrow;
      }

      // Safely read tables/sheets
      List<String> sheetNames = [];
      try {
        sheetNames = excel.tables.keys.toList();
        debugPrint('Excel tables detected: ${sheetNames.join(', ')}');
      } catch (e) {
        debugPrint('Accessing excel.tables failed: $e');
      }

      Sheet? sheet;
      String? sheetName;

      for (final key in sheetNames) {
        try {
          final s = excel.tables[key];
          if (s == null) continue;
          bool hasContent = false;
          for (final row in s.rows) {
            for (final cell in row) {
              final v = cell?.value;
              if ((v?.toString().trim().isNotEmpty ?? false)) {
                hasContent = true;
                break;
              }
            }
            if (hasContent) break;
          }
          if (hasContent) {
            sheet = s;
            sheetName = key;
            break;
          }
        } catch (e) {
          debugPrint('Error scanning sheet "$key": $e');
        }
      }

      if (sheet == null) {
        debugPrint('No non-empty sheet found in XLSX.');
        return [];
      }

      final s = sheet;
      int derivedCols = 0;
      try {
        for (final r in s.rows) {
          final len = r.length;
          if (len > derivedCols) derivedCols = len;
        }
      } catch (_) {}
      debugPrint(
          'Using sheet: ${sheetName ?? '(unknown)'} rows=${s.maxRows} cols=$derivedCols');

      final rows = <List<String>>[];
      try {
        for (final r in s.rows) {
          final rowValues = <String>[];
          try {
            for (final cell in r) {
              final v = cell?.value;
              rowValues.add(v == null ? '' : v.toString());
            }
          } catch (e) {
            debugPrint('Row iteration error: $e');
          }
          while (rowValues.isNotEmpty && rowValues.last.trim().isEmpty) {
            rowValues.removeLast();
          }
          rows.add(rowValues);
        }
      } catch (e) {
        debugPrint('Failed to traverse sheet rows: $e');
      }
      while (rows.isNotEmpty && rows.first.every((c) => c.trim().isEmpty)) {
        rows.removeAt(0);
      }
      return rows;
    } catch (e) {
      debugPrint('Failed to read XLSX bytes: $e');

      // If this is a real XLSX (ZIP), try ZIP/XML parsing before CSV fallback.
      final isZip = bytes.length > 3 && bytes[0] == 0x50 && bytes[1] == 0x4B;
      if (isZip) {
        try {
          final fallback = _rowsFromXlsxZip(bytes);
          if (fallback.isNotEmpty) return fallback;
        } catch (eZip) {
          debugPrint('XLSX ZIP/XML fallback failed: $eZip');
        }
      }

      // Fallback: Try to interpret as CSV text (some mislabeled files)
      try {
        final text = decodeTextFromBytes(bytes);
        if (text.trim().isEmpty) return [];
        // Only accept if it looks like CSV
        final hasNewline = text.contains('\n');
        final hasSeparator =
            text.contains(',') || text.contains(';') || text.contains('\t');
        final printable = text.runes
            .where((r) => r >= 32 && r <= 126 || r == 10 || r == 13 || r == 9)
            .length;
        final ratio = printable / text.length;
        if (!(hasNewline && hasSeparator && ratio > 0.85)) {
          debugPrint('CSV fallback rejected: text does not resemble CSV');
          return [];
        }
        debugPrint('Falling back to CSV parsing for XLSX input');
        return _parseDelimitedText(text);
      } catch (e2) {
        debugPrint('CSV fallback failed: $e2');
        return [];
      }
    }
  }

  List<List<String>> _rowsFromXlsxZip(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);

    String? readText(String path) {
      final f = archive.files.cast<ArchiveFile?>().firstWhere(
            (af) => af != null && af.name == path,
            orElse: () => null,
          );
      if (f == null) return null;
      final data = f.content;
      if (data is List<int>) {
        return utf8.decode(data, allowMalformed: true);
      }
      if (data is Uint8List) {
        return utf8.decode(data, allowMalformed: true);
      }
      return null;
    }

    List<String> readSharedStrings() {
      final xmlText = readText('xl/sharedStrings.xml');
      if (xmlText == null || xmlText.trim().isEmpty) return const [];
      final doc = XmlDocument.parse(xmlText);
      final out = <String>[];
      for (final si in doc.findAllElements('si')) {
        final parts = <String>[];
        for (final t in si.findAllElements('t')) {
          parts.add(t.innerText);
        }
        out.add(parts.join());
      }
      return out;
    }

    int colIndexFromCellRef(String? r) {
      if (r == null || r.isEmpty) return -1;
      final m = RegExp(r'^([A-Z]+)').firstMatch(r);
      if (m == null) return -1;
      final letters = m.group(1)!;
      int n = 0;
      for (final codeUnit in letters.codeUnits) {
        n = (n * 26) + (codeUnit - 64);
      }
      return n - 1;
    }

    final shared = readSharedStrings();

    final sheetPaths = archive.files
        .map((f) => f.name)
        .where((n) => n.startsWith('xl/worksheets/sheet') && n.endsWith('.xml'))
        .toList()
      ..sort();

    if (sheetPaths.isEmpty) return [];
    final sheetXml = readText(sheetPaths.first);
    if (sheetXml == null || sheetXml.trim().isEmpty) return [];

    final doc = XmlDocument.parse(sheetXml);
    final rowsOut = <List<String>>[];

    for (final rowEl in doc.findAllElements('row')) {
      final row = <String>[];
      int maxCol = -1;

      for (final c in rowEl.findElements('c')) {
        final rAttr = c.getAttribute('r');
        final col = colIndexFromCellRef(rAttr);
        if (col >= 0 && col > maxCol) maxCol = col;
        final t = c.getAttribute('t');

        String value = '';
        if (t == 'inlineStr') {
          final isEl = c.getElement('is');
          if (isEl != null) {
            value = isEl.findAllElements('t').map((e) => e.innerText).join();
          }
        } else {
          final vEl = c.getElement('v');
          final vText = vEl?.innerText ?? '';
          if (t == 's') {
            final idx = int.tryParse(vText);
            if (idx != null && idx >= 0 && idx < shared.length) {
              value = shared[idx];
            } else {
              value = '';
            }
          } else {
            value = vText;
          }
        }

        if (col >= 0) {
          while (row.length <= col) {
            row.add('');
          }
          row[col] = value;
        }
      }

      // Trim trailing empties
      while (row.isNotEmpty && row.last.trim().isEmpty) {
        row.removeLast();
      }
      if (row.isEmpty) continue;
      rowsOut.add(row);
    }

    while (rowsOut.isNotEmpty && rowsOut.first.every((c) => c.trim().isEmpty)) {
      rowsOut.removeAt(0);
    }

    debugPrint(
        'XLSX ZIP/XML fallback used: sheet=${sheetPaths.first} rows=${rowsOut.length}');
    return rowsOut;
  }
}

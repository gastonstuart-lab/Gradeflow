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

class _XlsxSheetDescriptor {
  final String name;
  final String path;

  const _XlsxSheetDescriptor({
    required this.name,
    required this.path,
  });
}

class _XlsxSheetRows {
  final String name;
  final String path;
  final List<List<String>> rows;

  const _XlsxSheetRows({
    required this.name,
    required this.path,
    required this.rows,
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
    final sheets = _xlsxSheetRowsFromZip(bytes);
    if (sheets.isEmpty) return [];

    final scoringSheets =
        sheets.where((sheet) => sheet.rows.length > 1).toList();
    final candidates = scoringSheets.isNotEmpty ? scoringSheets : sheets;

    _XlsxSheetRows bestSheet = candidates.first;
    var bestScore = _scoreXlsxSheetRows(bestSheet.rows);
    for (final sheet in candidates.skip(1)) {
      final score = _scoreXlsxSheetRows(sheet.rows);
      if (score > bestScore) {
        bestSheet = sheet;
        bestScore = score;
      }
    }

    debugPrint(
        'XLSX ZIP/XML fallback used: sheet=${bestSheet.path} rows=${bestSheet.rows.length}');
    return bestSheet.rows;
  }

  List<_XlsxSheetRows> _xlsxSheetRowsFromZip(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes, verify: false);

    String? readText(String path) {
      final normalizedPath = path.replaceAll('\\', '/');
      final file = archive.files.cast<ArchiveFile?>().firstWhere(
            (entry) => entry?.name.replaceAll('\\', '/') == normalizedPath,
            orElse: () => null,
          );
      if (file == null) return null;
      final data = file.content;
      if (data is Uint8List) {
        return utf8.decode(data, allowMalformed: true);
      }
      if (data is List<int>) {
        return utf8.decode(data, allowMalformed: true);
      }
      return null;
    }

    final sharedStrings = _readSharedStringsFromZip(readText);
    final descriptors = _resolveXlsxSheetDescriptors(
      archive: archive,
      readText: readText,
    );

    final sheets = <_XlsxSheetRows>[];
    for (final descriptor in descriptors) {
      final sheetXml = readText(descriptor.path);
      if (sheetXml == null || sheetXml.trim().isEmpty) continue;
      final rows = _parseWorksheetRowsFromXml(
        sheetXml,
        sharedStrings: sharedStrings,
      );
      if (rows.isEmpty) continue;
      sheets.add(
        _XlsxSheetRows(
          name: descriptor.name,
          path: descriptor.path,
          rows: rows,
        ),
      );
    }

    return sheets;
  }

  List<_XlsxSheetDescriptor> _resolveXlsxSheetDescriptors({
    required Archive archive,
    required String? Function(String path) readText,
  }) {
    final workbookXml = readText('xl/workbook.xml');
    final relsXml = readText('xl/_rels/workbook.xml.rels');

    final discovered = <_XlsxSheetDescriptor>[];
    if (workbookXml != null &&
        workbookXml.trim().isNotEmpty &&
        relsXml != null &&
        relsXml.trim().isNotEmpty) {
      final workbook = XmlDocument.parse(workbookXml);
      final rels = XmlDocument.parse(relsXml);
      final targetById = <String, String>{};

      for (final relationship in rels.findAllElements('Relationship')) {
        final id = relationship.getAttribute('Id');
        final target = relationship.getAttribute('Target');
        if (id == null || target == null || target.trim().isEmpty) continue;
        targetById[id] = target;
      }

      for (final sheet in workbook.findAllElements('sheet')) {
        final name = sheet.getAttribute('name')?.trim();
        final relAttr = sheet.attributes.cast<XmlAttribute?>().firstWhere(
          (attr) {
            final attrName = attr?.name.toString() ?? '';
            return attrName == 'r:id' || attrName == 'id';
          },
          orElse: () => null,
        );
        final relId = relAttr?.value.trim();
        final target = relId == null ? null : targetById[relId];
        if (target == null || target.trim().isEmpty) continue;

        var normalizedTarget = target.replaceAll('\\', '/');
        if (normalizedTarget.startsWith('/')) {
          normalizedTarget = normalizedTarget.substring(1);
        }
        final resolvedPath = normalizedTarget.startsWith('xl/')
            ? normalizedTarget
            : 'xl/$normalizedTarget';
        discovered.add(
          _XlsxSheetDescriptor(
            name: name == null || name.isEmpty ? resolvedPath : name,
            path: resolvedPath,
          ),
        );
      }
    }

    if (discovered.isNotEmpty) {
      return discovered;
    }

    final sheetPaths = archive.files
        .map((file) => file.name.replaceAll('\\', '/'))
        .where((name) =>
            name.startsWith('xl/worksheets/sheet') && name.endsWith('.xml'))
        .toList()
      ..sort();
    return [
      for (final sheetPath in sheetPaths)
        _XlsxSheetDescriptor(name: sheetPath, path: sheetPath),
    ];
  }

  List<String> _readSharedStringsFromZip(
      String? Function(String path) readText) {
    final xmlText = readText('xl/sharedStrings.xml');
    if (xmlText == null || xmlText.trim().isEmpty) return const [];
    final doc = XmlDocument.parse(xmlText);
    final out = <String>[];
    for (final sharedItem in doc.findAllElements('si')) {
      final parts = <String>[];
      for (final textNode in sharedItem.findAllElements('t')) {
        parts.add(textNode.innerText);
      }
      out.add(parts.join());
    }
    return out;
  }

  List<List<String>> _parseWorksheetRowsFromXml(
    String sheetXml, {
    required List<String> sharedStrings,
  }) {
    int colIndexFromCellRef(String? cellRef) {
      if (cellRef == null || cellRef.isEmpty) return -1;
      final match = RegExp(r'^([A-Z]+)').firstMatch(cellRef);
      if (match == null) return -1;
      final letters = match.group(1)!;
      var value = 0;
      for (final codeUnit in letters.codeUnits) {
        value = (value * 26) + (codeUnit - 64);
      }
      return value - 1;
    }

    final doc = XmlDocument.parse(sheetXml);
    final rowsOut = <List<String>>[];

    for (final rowEl in doc.findAllElements('row')) {
      final row = <String>[];
      for (final cell in rowEl.findElements('c')) {
        final columnIndex = colIndexFromCellRef(cell.getAttribute('r'));
        if (columnIndex < 0) continue;

        final cellType = cell.getAttribute('t');
        String value = '';
        if (cellType == 'inlineStr') {
          final inline = cell.getElement('is');
          if (inline != null) {
            value = inline
                .findAllElements('t')
                .map((node) => node.innerText)
                .join();
          }
        } else {
          final rawValue = cell.getElement('v')?.innerText ?? '';
          if (cellType == 's') {
            final idx = int.tryParse(rawValue);
            if (idx != null && idx >= 0 && idx < sharedStrings.length) {
              value = sharedStrings[idx];
            }
          } else {
            value = rawValue;
          }
        }

        while (row.length <= columnIndex) {
          row.add('');
        }
        row[columnIndex] = value;
      }

      while (row.isNotEmpty && row.last.trim().isEmpty) {
        row.removeLast();
      }
      if (row.isEmpty) continue;
      rowsOut.add(row);
    }

    while (rowsOut.isNotEmpty &&
        rowsOut.first.every((cell) => cell.trim().isEmpty)) {
      rowsOut.removeAt(0);
    }

    return rowsOut;
  }

  int _scoreXlsxSheetRows(List<List<String>> rows) {
    if (rows.isEmpty) return -1;

    final headerRowIndex = _pickHeaderRowIndex(rows);
    final header = rows[headerRowIndex].map(_normalizeName).toList();
    final recognizedHeaderCount = header.where((cell) {
      return cell.contains('student') ||
          cell.contains('name') ||
          cell.contains('class') ||
          cell.contains('seat') ||
          cell.contains('date') ||
          cell.contains('week') ||
          cell.contains('title') ||
          cell.contains('score') ||
          cell.contains('exam') ||
          cell.contains('subject') ||
          cell.contains('lesson');
    }).length;

    final nonEmptyRows =
        rows.where((row) => row.any((cell) => cell.trim().isNotEmpty)).length;
    final maxColumns = rows.fold<int>(
        0, (current, row) => row.length > current ? row.length : current);

    return (recognizedHeaderCount * 8) + (nonEmptyRows * 2) + maxColumns;
  }
}

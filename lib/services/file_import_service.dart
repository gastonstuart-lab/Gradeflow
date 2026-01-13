import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import 'package:gradeflow/models/student.dart';
import 'package:gradeflow/models/class.dart';
import 'package:uuid/uuid.dart';

class ImportedStudent {
  final String? studentId;
  final String? chineseName;
  final String? englishFirstName;
  final String? englishLastName;
  final String? seatNo;
  final String? classCode;
  final bool isValid;
  final String? error;

  ImportedStudent({
    this.studentId,
    this.chineseName,
    this.englishFirstName,
    this.englishLastName,
    this.seatNo,
    this.classCode,
    required this.isValid,
    this.error,
  });
}

class FileImportService {
  /// Best-effort decode for CSV-ish text exported from Excel.
  /// Handles UTF-8 (with/without BOM) and UTF-16LE/BE.
  String decodeTextFromBytes(Uint8List bytes) {
    if (bytes.isEmpty) return '';

    // UTF-8 BOM
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      return utf8.decode(bytes.sublist(3), allowMalformed: true);
    }

    // UTF-16 BOM
    if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
      // UTF-16LE
      return _decodeUtf16(bytes.sublist(2), littleEndian: true);
    }
    if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
      // UTF-16BE
      return _decodeUtf16(bytes.sublist(2), littleEndian: false);
    }

    // Heuristic: if many NUL bytes, it's likely UTF-16 without BOM.
    int nulCount = 0;
    final sampleLen = bytes.length.clamp(0, 512);
    for (int i = 0; i < sampleLen; i++) {
      if (bytes[i] == 0x00) nulCount++;
    }
    if (sampleLen > 0 && (nulCount / sampleLen) > 0.15) {
      // Guess endianness by where NULs appear.
      int nulEven = 0;
      int nulOdd = 0;
      for (int i = 0; i < sampleLen; i++) {
        if (bytes[i] != 0x00) continue;
        if (i.isEven) {
          nulEven++;
        } else {
          nulOdd++;
        }
      }
      final littleEndian = nulOdd > nulEven;
      return _decodeUtf16(bytes, littleEndian: littleEndian);
    }

    // Default UTF-8 with malformed allowed.
    return utf8.decode(bytes, allowMalformed: true);
  }

  /// Build a human-readable diagnostics string for troubleshooting imports.
  /// Safe to show in UI; includes only structural info (row counts, headers).
  String diagnosticsForFile(Uint8List bytes, {required String filename}) {
    final isZip = bytes.length > 3 && bytes[0] == 0x50 && bytes[1] == 0x4B;
    final lines = <String>[];
    lines.add('File: $filename');
    lines.add('Bytes: ${bytes.length}');
    lines.add('Looks like XLSX (ZIP): $isZip');

    try {
      if (!isZip) {
        final text = decodeTextFromBytes(bytes);
        final delim = _guessDelimiter(text);
        lines.add('Detected delimiter: ${delim == "\t" ? "TAB" : delim}');
        final rows = _parseDelimitedText(text);
        lines.add('Rows decoded: ${rows.length}');
        if (rows.isNotEmpty) {
          final headerIdx = _pickHeaderRowIndex(rows);
          lines.add('Header row index: $headerIdx');
          final hdr = (headerIdx >= 0 && headerIdx < rows.length)
              ? rows[headerIdx]
              : rows.first;
          lines.add('Header sample: ${hdr.take(12).toList()}');
        }
        final roster = parseCSV(text);
        lines.add(
            'Roster parse: total=${roster.length} valid=${roster.where((r) => r.isValid).length} invalid=${roster.where((r) => !r.isValid).length}');
        final firstErr = roster.firstWhere((r) => !r.isValid,
            orElse: () => ImportedStudent(isValid: true));
        if (firstErr.isValid == false)
          lines.add('First error: ${firstErr.error ?? ""}');
      } else {
        final rows = rowsFromAnyBytes(bytes);
        lines.add('Rows extracted: ${rows.length}');
        if (rows.isNotEmpty) {
          final headerIdx = _pickHeaderRowIndex(rows);
          lines.add('Header row index: $headerIdx');
          final hdr = (headerIdx >= 0 && headerIdx < rows.length)
              ? rows[headerIdx]
              : rows.first;
          lines.add('Header sample: ${hdr.take(12).toList()}');
          lines.add(
              'First data row sample: ${(rows.length > headerIdx + 1 ? rows[headerIdx + 1] : const <String>[]).take(12).toList()}');
        }
        final roster = parseXlsxRoster(bytes);
        lines.add(
            'Roster parse: total=${roster.length} valid=${roster.where((r) => r.isValid).length} invalid=${roster.where((r) => !r.isValid).length}');
        final firstErr = roster.firstWhere((r) => !r.isValid,
            orElse: () => ImportedStudent(isValid: true));
        if (firstErr.isValid == false)
          lines.add('First error: ${firstErr.error ?? ""}');
      }
    } catch (e) {
      lines.add('Diagnostics error: $e');
    }

    return lines.join('\n');
  }

  // --------------------
  // CSV: Students Roster
  // --------------------
  List<ImportedStudent> parseCSV(String csvContent) {
    try {
      final rows = _parseDelimitedText(csvContent);
      if (rows.isEmpty) return [];

      final headerRowIndex = _pickHeaderRowIndex(rows);
      if (headerRowIndex < 0 || headerRowIndex >= rows.length) return [];
      final headers = rows[headerRowIndex].map(_normalizeName).toList();

      final analysisRows = rows.sublist(headerRowIndex);

      // Use smart auto-detection
      final cols = _autoDetectColumns(headers, analysisRows);
      final studentIdIndex = cols['studentId'] ?? -1;
      final chineseNameIndex = cols['chineseName'] ?? -1;
      final firstNameIndex = cols['firstName'] ?? -1;
      final lastNameIndex = cols['lastName'] ?? -1;
      final englishNameIndex = cols['englishName'] ?? -1;
      final seatNoIndex = cols['seatNo'] ?? -1;
      final classCodeIndex = cols['classCode'] ?? -1;
      final formIndex = cols['form'] ?? -1;

      final results = <ImportedStudent>[];

      for (int i = headerRowIndex + 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.every((c) => c.trim().isEmpty)) continue;

        final studentId = studentIdIndex != -1 && studentIdIndex < row.length
            ? row[studentIdIndex].trim()
            : null;
        String? chineseName =
            chineseNameIndex != -1 && chineseNameIndex < row.length
                ? row[chineseNameIndex].trim()
                : null;
        String? firstName = firstNameIndex != -1 && firstNameIndex < row.length
            ? row[firstNameIndex].trim()
            : null;
        String? lastName = lastNameIndex != -1 && lastNameIndex < row.length
            ? row[lastNameIndex].trim()
            : null;
        // Fallback: combined English name in a single column
        if ((firstName == null || firstName.isEmpty) ||
            (lastName == null || lastName.isEmpty)) {
          final englishName =
              englishNameIndex != -1 && englishNameIndex < row.length
                  ? row[englishNameIndex].trim()
                  : null;
          if (englishName != null && englishName.isNotEmpty) {
            final parts = englishName
                .split(RegExp(r'\s+'))
                .where((p) => p.isNotEmpty)
                .toList();
            if (parts.length >= 2) {
              firstName = parts.sublist(0, parts.length - 1).join(' ');
              lastName = parts.last;
            } else {
              // Single token: duplicate to satisfy required fields
              firstName = parts.first;
              lastName = parts.first;
            }
          }
        }
        final seatNo = seatNoIndex != -1 && seatNoIndex < row.length
            ? row[seatNoIndex].trim()
            : null;
        String? classCode = classCodeIndex != -1 && classCodeIndex < row.length
            ? row[classCodeIndex].trim()
            : null;
        final form = formIndex != -1 && formIndex < row.length
            ? row[formIndex].trim()
            : null;
        if (form != null && form.isNotEmpty) {
          // If both form and class present, combine (e.g., J2 + F => J2F); if only form, use it
          if (classCode != null && classCode.isNotEmpty) {
            classCode =
                '${form.replaceAll(' ', '')}${classCode.replaceAll(' ', '')}';
          } else {
            classCode = form.replaceAll(' ', '');
          }
        }

        // Make import forgiving: accept either Chinese or English name and auto-fill the other.
        final hasEnglish = (firstName != null && firstName.isNotEmpty) &&
            (lastName != null && lastName.isNotEmpty);
        final hasChinese = chineseName != null && chineseName.isNotEmpty;
        if (!hasChinese && hasEnglish) {
          chineseName = '$firstName $lastName'.trim();
        }
        if (!hasEnglish && hasChinese) {
          firstName = chineseName;
          lastName = chineseName;
        }

        if (studentId == null || studentId.isEmpty) {
          results.add(ImportedStudent(
            studentId: studentId,
            chineseName: chineseName,
            englishFirstName: firstName,
            englishLastName: lastName,
            seatNo: seatNo,
            classCode: classCode,
            isValid: false,
            error: 'Student ID is required',
          ));
          continue;
        }

        final finalHasEnglish = (firstName != null && firstName.isNotEmpty) &&
            (lastName != null && lastName.isNotEmpty);
        final finalHasChinese = chineseName != null && chineseName.isNotEmpty;
        if (!finalHasEnglish && !finalHasChinese) {
          results.add(ImportedStudent(
            studentId: studentId,
            chineseName: chineseName,
            englishFirstName: firstName,
            englishLastName: lastName,
            seatNo: seatNo,
            classCode: classCode,
            isValid: false,
            error: 'A name is required (Chinese or English)',
          ));
          continue;
        }

        results.add(ImportedStudent(
          studentId: studentId,
          chineseName: chineseName,
          englishFirstName: firstName,
          englishLastName: lastName,
          seatNo: seatNo,
          classCode: classCode,
          isValid: true,
        ));
      }

      return results;
    } catch (e) {
      debugPrint('Failed to parse CSV: $e');
      return [];
    }
  }

  // --------------------
  // Excel (XLSX): Students Roster
  // --------------------
  List<ImportedStudent> parseXlsxRoster(Uint8List bytes) {
    try {
      final rows = _rowsFromExcel(bytes);
      if (rows.isEmpty) return [];

      final headerRowIndex = _pickHeaderRowIndex(rows);
      if (headerRowIndex < 0 || headerRowIndex >= rows.length) return [];
      final headers = rows[headerRowIndex].map(_normalizeName).toList();

      final analysisRows = rows.sublist(headerRowIndex);

      // Use smart auto-detection
      final cols = _autoDetectColumns(headers, analysisRows);
      final studentIdIndex = cols['studentId'] ?? -1;
      final chineseNameIndex = cols['chineseName'] ?? -1;
      final firstNameIndex = cols['firstName'] ?? -1;
      final lastNameIndex = cols['lastName'] ?? -1;
      final englishNameIndex = cols['englishName'] ?? -1;
      final seatNoIndex = cols['seatNo'] ?? -1;
      final classCodeIndex = cols['classCode'] ?? -1;
      final formIndex = cols['form'] ?? -1;

      final results = <ImportedStudent>[];

      for (int i = headerRowIndex + 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.every((c) => c.trim().isEmpty)) continue;
        String? _cell(int idx) =>
            idx != -1 && idx < row.length ? row[idx].toString().trim() : null;

        final studentId = _cell(studentIdIndex);
        String? chineseName = _cell(chineseNameIndex);
        String? firstName = _cell(firstNameIndex);
        String? lastName = _cell(lastNameIndex);
        // Fallback: combined English name
        if ((firstName == null || firstName.isEmpty) ||
            (lastName == null || lastName.isEmpty)) {
          final englishName = _cell(englishNameIndex);
          if (englishName != null && englishName.isNotEmpty) {
            final parts = englishName
                .split(RegExp(r'\s+'))
                .where((p) => p.isNotEmpty)
                .toList();
            if (parts.length >= 2) {
              firstName = parts.sublist(0, parts.length - 1).join(' ');
              lastName = parts.last;
            } else {
              firstName = parts.first;
              lastName = parts.first;
            }
          }
        }
        final seatNo = _cell(seatNoIndex);
        String? classCode = _cell(classCodeIndex);
        final form = _cell(formIndex);
        if (form != null && form.isNotEmpty) {
          if (classCode != null && classCode.isNotEmpty) {
            classCode =
                '${form.replaceAll(' ', '')}${classCode.replaceAll(' ', '')}';
          } else {
            classCode = form.replaceAll(' ', '');
          }
        }

        // Make import forgiving: accept either Chinese or English name and auto-fill the other.
        final hasEnglish = (firstName != null && firstName.isNotEmpty) &&
            (lastName != null && lastName.isNotEmpty);
        final hasChinese = chineseName != null && chineseName.isNotEmpty;
        if (!hasChinese && hasEnglish) {
          chineseName = '$firstName $lastName'.trim();
        }
        if (!hasEnglish && hasChinese) {
          firstName = chineseName;
          lastName = chineseName;
        }

        if (studentId == null || studentId.isEmpty) {
          results.add(ImportedStudent(
            studentId: studentId,
            chineseName: chineseName,
            englishFirstName: firstName,
            englishLastName: lastName,
            seatNo: seatNo,
            classCode: classCode,
            isValid: false,
            error: 'Student ID is required',
          ));
          continue;
        }

        final finalHasEnglish = (firstName != null && firstName.isNotEmpty) &&
            (lastName != null && lastName.isNotEmpty);
        final finalHasChinese = chineseName != null && chineseName.isNotEmpty;
        if (!finalHasEnglish && !finalHasChinese) {
          results.add(ImportedStudent(
            studentId: studentId,
            chineseName: chineseName,
            englishFirstName: firstName,
            englishLastName: lastName,
            seatNo: seatNo,
            classCode: classCode,
            isValid: false,
            error: 'A name is required (Chinese or English)',
          ));
          continue;
        }

        results.add(ImportedStudent(
          studentId: studentId,
          chineseName: chineseName,
          englishFirstName: firstName,
          englishLastName: lastName,
          seatNo: seatNo,
          classCode: classCode,
          isValid: true,
        ));
      }

      return results;
    } catch (e) {
      debugPrint('Failed to parse XLSX roster: $e');
      return [];
    }
  }

  int _findColumnIndex(List<String> headers, List<String> possibleNames) {
    final normalized = headers.map(_normalizeName).toList();
    for (var raw in possibleNames) {
      final name = _normalizeName(raw);
      // Try exact match first
      final exact = normalized.indexWhere((h) => h == name);
      if (exact != -1) return exact;
      // Then contains (for headers like "student id number")
      final contains = normalized.indexWhere((h) => h.contains(name));
      if (contains != -1) return contains;
    }
    return -1;
  }

  // Smart auto-detection: analyze actual data to find columns
  Map<String, int> _autoDetectColumns(
      List<String> headers, List<List<String>> rows) {
    final normalized = headers.map(_normalizeName).toList();
    final result = <String, int>{};

    // First try header matching
    result['studentId'] = _findColumnIndex(headers, [
      'student id',
      'studentid',
      'id',
      'student no',
      'studentno',
      'stu id',
      'stuid',
      'student number',
      '學號',
      'no',
      'number',
      '#'
    ]);
    result['chineseName'] = _findColumnIndex(headers, [
      'chinese name',
      'chinesename',
      '中文名',
      '姓名',
      'name chinese',
      'chinese',
      '中文',
      '名字'
    ]);
    result['firstName'] = _findColumnIndex(headers, [
      'first name',
      'firstname',
      'english first name',
      'given name',
      'givenname',
      'eng first name',
      'eng firstname',
      'first',
      '英文名'
    ]);
    result['lastName'] = _findColumnIndex(headers, [
      'last name',
      'lastname',
      'english last name',
      'surname',
      'family name',
      'eng last name',
      'eng lastname',
      'last',
      '姓'
    ]);
    result['englishName'] = _findColumnIndex(headers, [
      'english name',
      'englishname',
      'eng name',
      'name english',
      'name (english)',
      'eng name',
      'name'
    ]);
    result['seatNo'] = _findColumnIndex(headers,
        ['seat no', 'seatno', 'seat', 'seat number', '座號', '號', 'no.', 'num']);
    result['classCode'] = _findColumnIndex(headers, [
      'class code',
      'classcode',
      'code',
      'class',
      '班別',
      '班級',
      'class name',
      'classname',
      '班',
      'section'
    ]);
    result['form'] = _findColumnIndex(headers, [
      'form',
      'grade',
      'year level',
      'yearlevel',
      'level',
      'form class',
      '級別',
      '年級',
      'year'
    ]);

    // Data-based detection if headers failed
    if (rows.length > 1) {
      final scannedRows = (rows.length - 1).clamp(1, 20);
      // Detect student ID by pattern: usually numeric, 4-10 digits
      if (result['studentId'] == -1) {
        for (int col = 0; col < headers.length; col++) {
          int numericCount = 0;
          int validIdCount = 0;
          for (int row = 1; row <= scannedRows; row++) {
            if (col >= rows[row].length) continue;
            final val =
                col < rows[row].length ? rows[row][col].toString().trim() : '';
            if (val.isEmpty) continue;
            if (RegExp(r'^\d{4,10}$').hasMatch(val)) validIdCount++;
            if (RegExp(r'^\d+$').hasMatch(val)) numericCount++;
          }
          if (validIdCount > scannedRows * 0.5 ||
              numericCount > scannedRows * 0.6) {
            result['studentId'] = col;
            break;
          }
        }
      }

      // Detect Chinese name by Unicode range
      if (result['chineseName'] == -1) {
        for (int col = 0; col < headers.length; col++) {
          int chineseCount = 0;
          for (int row = 1; row <= scannedRows; row++) {
            if (col >= rows[row].length) continue;
            final val =
                col < rows[row].length ? rows[row][col].toString().trim() : '';
            if (val.isEmpty) continue;
            if (RegExp(r'[\u4e00-\u9fff]+').hasMatch(val)) chineseCount++;
          }
          if (chineseCount > scannedRows * 0.5) {
            result['chineseName'] = col;
            break;
          }
        }
      }

      // Detect English names by Latin characters
      if (result['englishName'] == -1 &&
          (result['firstName'] == -1 || result['lastName'] == -1)) {
        for (int col = 0; col < headers.length; col++) {
          if (col == result['studentId'] || col == result['chineseName'])
            continue;
          int englishCount = 0;
          for (int row = 1; row <= scannedRows; row++) {
            if (col >= rows[row].length) continue;
            final val =
                col < rows[row].length ? rows[row][col].toString().trim() : '';
            if (val.isEmpty) continue;
            if (RegExp(r"^[a-zA-Z\s\.\-']+$").hasMatch(val) && val.length > 1)
              englishCount++;
          }
          if (englishCount > scannedRows * 0.5) {
            result['englishName'] = col;
            break;
          }
        }
      }

      // Detect seat number: usually small integers 1-50
      if (result['seatNo'] == -1) {
        for (int col = 0; col < headers.length; col++) {
          if (col == result['studentId']) continue;
          int validSeatCount = 0;
          for (int row = 1; row <= scannedRows; row++) {
            if (col >= rows[row].length) continue;
            final val =
                col < rows[row].length ? rows[row][col].toString().trim() : '';
            if (val.isEmpty) continue;
            final num = int.tryParse(val);
            if (num != null && num >= 1 && num <= 50) validSeatCount++;
          }
          if (validSeatCount > scannedRows * 0.4) {
            result['seatNo'] = col;
            break;
          }
        }
      }
    }

    return result;
  }

  List<List<String>> _parseDelimitedText(String text) {
    if (text.trim().isEmpty) return [];
    final delimiter = _guessDelimiter(text);
    final converter = CsvToListConverter(
        fieldDelimiter: delimiter, shouldParseNumbers: false);
    final parsed = converter.convert(text);
    final rows = parsed
        .map((r) => r.map((c) => (c ?? '').toString().trim()).toList())
        .toList();
    // Trim trailing empty cells per row
    for (final r in rows) {
      while (r.isNotEmpty && r.last.trim().isEmpty) {
        r.removeLast();
      }
    }
    // Drop leading all-empty rows
    while (rows.isNotEmpty && rows.first.every((c) => c.trim().isEmpty)) {
      rows.removeAt(0);
    }
    return rows;
  }

  String _guessDelimiter(String text) {
    // Inspect first non-empty line.
    final lines = text.split(RegExp(r'\r?\n'));
    String first = '';
    for (final l in lines) {
      if (l.trim().isNotEmpty) {
        first = l;
        break;
      }
    }
    if (first.isEmpty) return ',';
    final candidates = <String>[',', '\t', ';', '|'];
    int bestCount = -1;
    String best = ',';
    for (final c in candidates) {
      final count = _countOccurrences(first, c);
      if (count > bestCount) {
        bestCount = count;
        best = c;
      }
    }
    return best;
  }

  int _countOccurrences(String s, String needle) {
    if (needle.isEmpty) return 0;
    int count = 0;
    int idx = 0;
    while (true) {
      idx = s.indexOf(needle, idx);
      if (idx == -1) return count;
      count++;
      idx += needle.length;
    }
  }

  int _pickHeaderRowIndex(List<List<String>> rows) {
    final maxScan = rows.length.clamp(1, 20);
    int bestIdx = 0;
    int bestScore = -1;

    for (int i = 0; i < maxScan; i++) {
      final row = rows[i];
      final nonEmpty = row.where((c) => c.trim().isNotEmpty).length;
      if (nonEmpty < 2) continue;

      int headerHits = 0;
      int numericCells = 0;
      for (final raw in row) {
        final v = _normalizeName(raw);
        if (v.isEmpty) continue;
        if (RegExp(r'^\d+(\.\d+)?$').hasMatch(v)) numericCells++;
        if (v.contains('student') ||
            v == 'id' ||
            v.contains('name') ||
            v.contains('class') ||
            v.contains('seat') ||
            v.contains('學號') ||
            v.contains('姓名') ||
            v.contains('班')) {
          headerHits++;
        }
      }

      // Weight header hits heavily; penalize numeric-heavy rows.
      final score = (headerHits * 5) + nonEmpty - (numericCells * 2);
      if (score > bestScore) {
        bestScore = score;
        bestIdx = i;
      }
    }

    return bestIdx;
  }

  String _decodeUtf16(Uint8List bytes, {required bool littleEndian}) {
    if (bytes.isEmpty) return '';
    final len = bytes.length - (bytes.length % 2);
    final codeUnits = <int>[];
    for (int i = 0; i < len; i += 2) {
      final lo = bytes[i];
      final hi = bytes[i + 1];
      final unit = littleEndian ? (lo | (hi << 8)) : (hi | (lo << 8));
      codeUnits.add(unit);
    }
    return String.fromCharCodes(codeUnits);
  }

  String _normalizeName(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[_\-\./\\()\[\]:]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  List<Student> convertToStudents(
      List<ImportedStudent> importedStudents, String classId) {
    final now = DateTime.now();
    return importedStudents
        .where((i) => i.isValid)
        .map((i) => Student(
              studentId: i.studentId!,
              chineseName: i.chineseName!,
              englishFirstName: i.englishFirstName!,
              englishLastName: i.englishLastName!,
              seatNo: i.seatNo,
              classCode: i.classCode,
              photoBase64: null,
              classId: classId,
              createdAt: now,
              updatedAt: now,
            ))
        .toList();
  }

  // --------------------
  // CSV: Exam Scores
  // --------------------
  Map<String, double> parseExamScores(String csvContent) {
    try {
      final rows = const CsvToListConverter().convert(csvContent);

      if (rows.isEmpty || rows.length < 2) {
        return {};
      }

      final headers = rows[0].map((h) => _normalizeName(h.toString())).toList();
      final studentIdIndex = _findColumnIndex(headers, [
        'student id',
        'studentid',
        'id',
        'student no',
        'studentno',
        'stuid',
        '學號'
      ]);
      final scoreIndex = _findColumnIndex(headers, [
        'exam score',
        'examscore',
        'score',
        'final exam',
        'finalexam',
        'exam',
        '分數',
        '成績'
      ]);

      if (studentIdIndex == -1 || scoreIndex == -1) {
        return {};
      }

      final scores = <String, double>{};

      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];

        if (studentIdIndex < row.length && scoreIndex < row.length) {
          final studentId = row[studentIdIndex]?.toString().trim();
          final scoreStr = row[scoreIndex]?.toString().trim();

          if (studentId != null && scoreStr != null) {
            final score = double.tryParse(scoreStr);
            if (score != null && score >= 0 && score <= 100) {
              scores[studentId] = score;
            }
          }
        }
      }

      return scores;
    } catch (e) {
      debugPrint('Failed to parse exam scores: $e');
      return {};
    }
  }

  // --------------------
  // Excel (XLSX): Exam Scores
  // --------------------
  Map<String, double> parseExamScoresXlsx(Uint8List bytes) {
    try {
      final rows = _rowsFromExcel(bytes);
      if (rows.isEmpty || rows.length < 2) return {};

      final headers =
          rows.first.map((h) => _normalizeName(h.toString())).toList();
      final studentIdIndex = _findColumnIndex(headers, [
        'student id',
        'studentid',
        'id',
        'student no',
        'studentno',
        'stuid',
        '學號'
      ]);
      final scoreIndex = _findColumnIndex(headers, [
        'exam score',
        'examscore',
        'score',
        'final exam',
        'finalexam',
        'exam',
        '分數',
        '成績'
      ]);
      if (studentIdIndex == -1 || scoreIndex == -1) return {};

      final scores = <String, double>{};
      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (studentIdIndex < row.length && scoreIndex < row.length) {
          final studentId = row[studentIdIndex]?.toString().trim();
          final scoreStr = row[scoreIndex]?.toString().trim();
          if (studentId != null && scoreStr != null) {
            final score = double.tryParse(scoreStr);
            if (score != null && score >= 0 && score <= 100) {
              scores[studentId] = score;
            }
          }
        }
      }
      return scores;
    } catch (e) {
      debugPrint('Failed to parse XLSX exam scores: $e');
      return {};
    }
  }

  // --------------------
  // Excel/CSV: Classes
  // --------------------
}

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
        '班別',
        '班級'
      ]);
      final subjectIdx = _findColumnIndex(
          headers, ['subject', 'course', '科目', 'subject name', 'coursename']);
      final groupIdx = _findColumnIndex(headers,
          ['group number', 'group', 'groupnumber', '組', 'set', 'stream']);
      final yearIdx = _findColumnIndex(headers, [
        'school year',
        'schoolyear',
        'year',
        'academic year',
        'academicyear',
        'session',
        'sy',
        '學年'
      ]);
      final termIdx =
          _findColumnIndex(headers, ['term', 'semester', 'sem', '學期']);
      final combinedYearTermIdx = _findColumnIndex(headers, [
        'year term',
        'school year term',
        'year/term',
        'academic year term',
        '學年學期'
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
        '班別',
        '班級'
      ]);
      final subjectIdx = _findColumnIndex(
          headers, ['subject', 'course', '科目', 'subject name', 'coursename']);
      final groupIdx = _findColumnIndex(headers,
          ['group number', 'group', 'groupnumber', '組', 'set', 'stream']);
      final yearIdx = _findColumnIndex(headers, [
        'school year',
        'schoolyear',
        'year',
        'academic year',
        'academicyear',
        'session',
        'sy',
        '學年'
      ]);
      final termIdx =
          _findColumnIndex(headers, ['term', 'semester', 'sem', '學期']);
      final combinedYearTermIdx = _findColumnIndex(headers, [
        'year term',
        'school year term',
        'year/term',
        'academic year term',
        '學年學期'
      ]);

      final out = <ImportedClass>[];
      for (int i = headerRowIndex + 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.every((c) => c.trim().isEmpty)) continue;
        String? cell(int idx) =>
            idx != -1 && idx < row.length ? row[idx]?.toString().trim() : null;

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
  // Public helper to extract tabular rows from bytes (CSV or XLSX). Used by AI importer.
  List<List<String>> rowsFromAnyBytes(Uint8List bytes) => _rowsFromExcel(bytes);

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
            if (row == null) continue;
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

      final s = sheet!;
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

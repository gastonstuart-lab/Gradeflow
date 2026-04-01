import 'dart:math' as math;

import 'package:csv/csv.dart';
import 'package:gradeflow/models/class.dart';
import 'package:gradeflow/models/seating_layout.dart';
import 'package:gradeflow/models/student.dart';
import 'package:gradeflow/models/grading_category.dart';
import 'package:excel/excel.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart' show PdfGoogleFonts;
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class ExportService {
  // Cache fonts so we only fetch once per session
  static pw.Font? _fontBase;
  static pw.Font? _fontBold;
  static bool _fontLoadAttempted = false;

  Future<void> _ensureUnicodeFonts() async {
    if (_fontBase != null && _fontBold != null) return;
    if (_fontLoadAttempted) return; // Don't retry if already failed

    _fontLoadAttempted = true;
    try {
      // Prefer Google Fonts TTFs (reliable, smaller, good CJK coverage).
      try {
        debugPrint('Attempting CJK fonts: Google Fonts (Noto Sans TC)');
        _fontBase = await PdfGoogleFonts.notoSansTCRegular();
        _fontBold = await PdfGoogleFonts.notoSansTCBold();
        debugPrint('✓ CJK fonts loaded successfully from Google Fonts (TC)');
        return;
      } catch (e) {
        debugPrint('✗ Failed Google Fonts (TC): $e');
      }

      // NOTE: The pdf package expects TrueType/OpenType font bytes.
      // Some CDNs serve WOFF2, which can appear to load but later throws:
      //   FormatException: Unexpected extension byte
      // Keep sources strictly to .ttf/.otf to avoid runtime failures.
      final sources = [
        {
          'name': 'GitHub (Noto Sans SC OTF)',
          'regular':
              'https://raw.githubusercontent.com/googlefonts/noto-cjk/main/Sans/OTF/SimplifiedChinese/NotoSansSC-Regular.otf',
          'bold':
              'https://raw.githubusercontent.com/googlefonts/noto-cjk/main/Sans/OTF/SimplifiedChinese/NotoSansSC-Bold.otf',
        },
      ];

      for (final source in sources) {
        try {
          debugPrint(
              'Attempting CJK fonts: ${source['name']} (${source['regular']})');
          final regularUrl = Uri.parse(source['regular']!);
          final boldUrl = Uri.parse(source['bold']!);

          final regRes =
              await http.get(regularUrl).timeout(const Duration(seconds: 15));
          final boldRes =
              await http.get(boldUrl).timeout(const Duration(seconds: 15));

          if (regRes.statusCode == 200 && boldRes.statusCode == 200) {
            _fontBase = pw.Font.ttf(regRes.bodyBytes.buffer.asByteData());
            _fontBold = pw.Font.ttf(boldRes.bodyBytes.buffer.asByteData());
            debugPrint(
                '✓ CJK fonts loaded successfully from ${source['name']}');
            return;
          }
        } catch (e) {
          debugPrint('✗ Failed ${source['name']}: $e');
          continue;
        }
      }

      debugPrint(
          '⚠ All font sources failed. PDFs will use fallback fonts (Chinese characters may appear as ▯).');
    } catch (e) {
      debugPrint('Failed to load CJK fonts for PDF: $e');
    }
  }

  String generateCSV(
    List<Student> students,
    List<GradingCategory> categories,
    Map<String, Map<String, double?>> studentGrades,
  ) {
    final headers = [
      'Student ID',
      'Chinese Name',
      'English Name',
      ...categories.map((c) => c.name),
      'Process Score (40%)',
      'Exam Score (60%)',
      'Final Grade',
    ];

    final rows = students.map((student) {
      final grades = studentGrades[student.studentId] ?? {};
      return [
        student.studentId,
        student.chineseName,
        student.englishFullName,
        ...categories.map((c) => _formatScore(grades[c.categoryId])),
        _formatScore(grades['processScore']),
        _formatScore(grades['examScore']),
        _formatScore(grades['finalGrade']),
      ];
    }).toList();

    return const ListToCsvConverter().convert([headers, ...rows]);
  }

  // New: XLSX bytes for class export
  Uint8List generateXlsx(
    List<Student> students,
    List<GradingCategory> categories,
    Map<String, Map<String, double?>> studentGrades,
  ) {
    final excel = Excel.createExcel();
    final sheet = excel.sheets[excel.getDefaultSheet()]!;

    final headers = [
      'Student ID',
      'Chinese Name',
      'English Name',
      ...categories.map((c) => c.name),
      'Process Score (40%)',
      'Exam Score (60%)',
      'Final Grade',
    ];

    sheet.appendRow(headers.map<CellValue?>((e) => TextCellValue(e)).toList());

    for (final student in students) {
      final grades = studentGrades[student.studentId] ?? {};
      final row = [
        student.studentId,
        student.chineseName,
        student.englishFullName,
        ...categories.map((c) => _formatScore(grades[c.categoryId])),
        _formatScore(grades['processScore']),
        _formatScore(grades['examScore']),
        _formatScore(grades['finalGrade']),
      ];
      sheet.appendRow(row.map<CellValue?>((e) => TextCellValue(e)).toList());
    }

    final bytes = excel.encode()!;
    return Uint8List.fromList(bytes);
  }

  String _formatScore(double? score) {
    if (score == null) return '';
    return score.toStringAsFixed(2);
  }

  String generateStudentReport(
    Student student,
    Map<String, double?> grades,
    List<GradingCategory> categories,
  ) {
    final buffer = StringBuffer();
    buffer.writeln('Student Report');
    buffer.writeln('=' * 50);
    buffer.writeln('Student ID: ${student.studentId}');
    buffer.writeln('Name: ${student.chineseName} (${student.englishFullName})');
    buffer.writeln('');
    buffer.writeln('Category Scores:');
    buffer.writeln('-' * 50);

    for (var category in categories) {
      final score = grades[category.categoryId];
      buffer.writeln('${category.name}: ${_formatScore(score)}');
    }

    buffer.writeln('');
    buffer.writeln('Final Calculation:');
    buffer.writeln('-' * 50);
    buffer.writeln(
        'Process Score (40%): ${_formatScore(grades['processScore'])}');
    buffer.writeln('Exam Score (60%): ${_formatScore(grades['examScore'])}');
    buffer.writeln('Final Grade: ${_formatScore(grades['finalGrade'])}');

    return buffer.toString();
  }

  // New: Student PDF report
  Future<Uint8List> generateStudentReportPdf(
    Student student,
    Map<String, double?> grades,
    List<GradingCategory> categories,
  ) async {
    await _ensureUnicodeFonts();
    final theme = (_fontBase != null && _fontBold != null)
        ? pw.ThemeData.withFont(base: _fontBase!, bold: _fontBold!)
        : pw.ThemeData.withFont(
            base: pw.Font.helvetica(), bold: pw.Font.helveticaBold());
    final doc = pw.Document(theme: theme);
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Student Report',
                    style: pw.TextStyle(
                        fontSize: 22, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 12),
                pw.Text('Student ID: ${student.studentId}'),
                pw.Text(
                    'Name: ${student.chineseName} (${student.englishFullName})'),
                pw.SizedBox(height: 16),
                pw.Text('Category Scores',
                    style: pw.TextStyle(
                        fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
                pw.Table(
                  border:
                      pw.TableBorder.all(width: 0.5, color: PdfColors.grey300),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(2),
                    1: const pw.FlexColumnWidth(1)
                  },
                  children: [
                    pw.TableRow(children: [
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('Category',
                              style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold))),
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('Score',
                              style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold))),
                    ]),
                    ...categories.map((c) => pw.TableRow(children: [
                          pw.Padding(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Text(c.name)),
                          pw.Padding(
                              padding: const pw.EdgeInsets.all(6),
                              child:
                                  pw.Text(_formatScore(grades[c.categoryId]))),
                        ])),
                  ],
                ),
                pw.SizedBox(height: 16),
                pw.Text('Final Calculation',
                    style: pw.TextStyle(
                        fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
                pw.Table(
                  border:
                      pw.TableBorder.all(width: 0.5, color: PdfColors.grey300),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(2),
                    1: const pw.FlexColumnWidth(1)
                  },
                  children: [
                    _kv('Process Score (40%)',
                        _formatScore(grades['processScore'])),
                    _kv('Exam Score (60%)', _formatScore(grades['examScore'])),
                    _kv('Final Grade', _formatScore(grades['finalGrade'])),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
    return await doc.save();
  }

  pw.TableRow _kv(String k, String v) => pw.TableRow(children: [
        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(k)),
        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(v)),
      ]);

  // New: Class PDF export (multi-page; one page per student)
  Future<Uint8List> generateClassReportPdf(
    List<Student> students,
    Map<String, Map<String, double?>> studentGrades,
    List<GradingCategory> categories,
  ) async {
    await _ensureUnicodeFonts();
    final theme = (_fontBase != null && _fontBold != null)
        ? pw.ThemeData.withFont(base: _fontBase!, bold: _fontBold!)
        : pw.ThemeData.withFont(
            base: pw.Font.helvetica(), bold: pw.Font.helveticaBold());
    final doc = pw.Document(theme: theme);

    if (students.isEmpty) {
      // Always return a valid PDF with a friendly message instead of empty bytes
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (context) => pw.Center(
            child: pw.Text('No students found for this class',
                style:
                    pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          ),
        ),
      );
      return await doc.save();
    }

    for (final student in students) {
      final grades = studentGrades[student.studentId] ?? const {};
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (context) => pw.Padding(
            padding: const pw.EdgeInsets.all(24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Class Report',
                        style: pw.TextStyle(
                            fontSize: 22, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Student ID: ${student.studentId}',
                        style: const pw.TextStyle(fontSize: 12)),
                  ],
                ),
                pw.SizedBox(height: 6),
                pw.Text('${student.chineseName} (${student.englishFullName})',
                    style: const pw.TextStyle(fontSize: 14)),
                pw.SizedBox(height: 16),
                pw.Text('Category Scores',
                    style: pw.TextStyle(
                        fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
                pw.Table(
                  border:
                      pw.TableBorder.all(width: 0.5, color: PdfColors.grey300),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(2),
                    1: const pw.FlexColumnWidth(1)
                  },
                  children: [
                    pw.TableRow(children: [
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('Category',
                              style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold))),
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('Score',
                              style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold))),
                    ]),
                    ...categories.map((c) => pw.TableRow(children: [
                          pw.Padding(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Text(c.name)),
                          pw.Padding(
                              padding: const pw.EdgeInsets.all(6),
                              child:
                                  pw.Text(_formatScore(grades[c.categoryId]))),
                        ])),
                  ],
                ),
                pw.SizedBox(height: 16),
                pw.Text('Final Calculation',
                    style: pw.TextStyle(
                        fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
                pw.Table(
                  border:
                      pw.TableBorder.all(width: 0.5, color: PdfColors.grey300),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(2),
                    1: const pw.FlexColumnWidth(1)
                  },
                  children: [
                    _kv('Process Score (40%)',
                        _formatScore(grades['processScore'])),
                    _kv('Exam Score (60%)', _formatScore(grades['examScore'])),
                    _kv('Final Grade', _formatScore(grades['finalGrade'])),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }
    return await doc.save();
  }

  // New: Compact one-page (landscape) class table with all students and their scores
  Future<Uint8List> generateClassScoresTablePdf(
    List<Student> students,
    List<GradingCategory> categories,
    Map<String, Map<String, double?>> studentGrades,
  ) async {
    await _ensureUnicodeFonts();
    final theme = (_fontBase != null && _fontBold != null)
        ? pw.ThemeData.withFont(base: _fontBase!, bold: _fontBold!)
        : pw.ThemeData.withFont(
            base: pw.Font.helvetica(), bold: pw.Font.helveticaBold());
    final doc = pw.Document(theme: theme);

    // Build header labels
    final headers = <String>[
      'Student ID',
      'Chinese Name',
      'English Name',
      ...categories.map((c) => c.name),
      'Process (40%)',
      'Exam (60%)',
      'Final',
    ];

    // Helper to cell
    pw.Widget cell(String text, {bool bold = false}) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 4),
          child: pw.Text(text,
              style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight:
                      bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        );

    // Table rows
    final rows = <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFEFEFEF)),
        children: headers.map((h) => cell(h, bold: true)).toList(),
      ),
      ...students.map((s) {
        final g = studentGrades[s.studentId] ?? const {};
        final values = <String>[
          s.studentId,
          s.chineseName,
          s.englishFullName,
          ...categories.map((c) => _formatScore(g[c.categoryId])),
          _formatScore(g['processScore']),
          _formatScore(g['examScore']),
          _formatScore(g['finalGrade']),
        ];
        return pw.TableRow(children: values.map((v) => cell(v)).toList());
      }),
    ];

    // Column widths: ID narrow, names wider, categories flexible equally
    final widths = <int, pw.TableColumnWidth>{
      0: const pw.FlexColumnWidth(1),
      1: const pw.FlexColumnWidth(2),
      2: const pw.FlexColumnWidth(3),
    };
    for (int i = 3; i < headers.length; i++) {
      widths[i] = const pw.FlexColumnWidth(1);
    }

    // Estimate table width in points to compute a safe scale factor (no NaN/Inf)
    // A4 landscape total width is ~842pt. We set page margin to 12pt on each side.
    final portraitHeight = PdfPageFormat.a4.height; // ~842pt
    final landscapeWidth = portraitHeight; // 842pt when landscape
    const horizontalMargin = 24.0; // 12pt left + 12pt right
    final availableWidth = landscapeWidth - horizontalMargin;

    // Heuristic per-column base width (pt)
    const idW = 60.0;
    const zhNameW = 100.0;
    const enNameW = 140.0;
    const scoreW = 56.0; // categories + process/exam/final

    final estimatedWidth =
        idW + zhNameW + enNameW + (scoreW * (categories.length + 3));
    double scale = availableWidth / (estimatedWidth <= 0 ? 1 : estimatedWidth);
    if (!scale.isFinite || scale <= 0) scale = 1.0;
    if (scale > 1.0) scale = 1.0; // never upscale

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(12),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Class Scores (All Students)',
                    style: pw.TextStyle(
                        fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.Text('Landscape - Total: ${students.length}',
                    style: const pw.TextStyle(fontSize: 9)),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Expanded(
              child: pw.Transform.scale(
                scale: scale,
                child: pw.Container(
                  decoration: pw.BoxDecoration(
                      border:
                          pw.Border.all(color: PdfColors.grey300, width: 0.5)),
                  child: pw.Table(
                    border: pw.TableBorder.symmetric(
                      inside: const pw.BorderSide(
                          color: PdfColors.grey300, width: 0.25),
                      outside: const pw.BorderSide(
                          color: PdfColors.grey300, width: 0.5),
                    ),
                    columnWidths: widths,
                    defaultVerticalAlignment:
                        pw.TableCellVerticalAlignment.middle,
                    children: rows,
                  ),
                ),
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text('Auto-scaled to fit on one landscape page',
                  style: const pw.TextStyle(
                      fontSize: 8, color: PdfColors.grey700)),
            ),
          ],
        ),
      ),
    );

    return await doc.save();
  }

  Future<Uint8List> generateSubstitutePacketPdf({
    required Class classItem,
    required List<Student> students,
    required SeatingLayout layout,
  }) async {
    await _ensureUnicodeFonts();
    final theme = (_fontBase != null && _fontBold != null)
        ? pw.ThemeData.withFont(base: _fontBase!, bold: _fontBold!)
        : pw.ThemeData.withFont(
            base: pw.Font.helvetica(), bold: pw.Font.helveticaBold());
    final doc = pw.Document(theme: theme);

    final generatedAt = DateTime.now();
    final studentsById = {
      for (final student in students) student.studentId: student
    };
    final assignedIds = layout.seats
        .where((seat) => seat.studentId != null && seat.studentId!.isNotEmpty)
        .map((seat) => seat.studentId!)
        .toSet();
    final roster = List<Student>.from(students)
      ..sort(_compareStudentsForRoster);
    final unassignedCount = students.length - assignedIds.length;

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Text(
              'Substitute Handout',
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              '${classItem.className} | ${classItem.subject} | ${classItem.schoolYear} ${classItem.term}',
              style: const pw.TextStyle(fontSize: 12),
            ),
            pw.SizedBox(height: 12),
            pw.Row(
              children: [
                _summaryCard('Students', '${students.length}'),
                pw.SizedBox(width: 8),
                _summaryCard('Placed', '${assignedIds.length}'),
                pw.SizedBox(width: 8),
                _summaryCard('Unplaced', '$unassignedCount'),
                pw.SizedBox(width: 8),
                _summaryCard('Layout', layout.name),
              ],
            ),
            pw.SizedBox(height: 12),
            pw.Expanded(
              child: pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: const PdfColor.fromInt(0xFFF8FAFD),
                  borderRadius: pw.BorderRadius.circular(16),
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    pw.Text(
                      'Current Seating Plan',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    _frontMarker(),
                    pw.SizedBox(height: 12),
                    pw.Expanded(
                      child: _buildSeatingDiagram(layout, studentsById),
                    ),
                  ],
                ),
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'Generated ${_formatTimestamp(generatedAt)}',
                style:
                    const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
              ),
            ),
          ],
        ),
      ),
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Text(
            'Class Roster',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Use with the seating diagram on the previous page.',
            style: const pw.TextStyle(fontSize: 11),
          ),
          if (unassignedCount > 0) ...[
            pw.SizedBox(height: 10),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: const PdfColor.fromInt(0xFFFFF3CD),
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(
                  color: const PdfColor.fromInt(0xFFE0B84F),
                ),
              ),
              child: pw.Text(
                '$unassignedCount student${unassignedCount == 1 ? '' : 's'} ${unassignedCount == 1 ? 'is' : 'are'} not yet placed on the current layout.',
                style: const pw.TextStyle(fontSize: 10),
              ),
            ),
          ],
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: const [
              'Seat No',
              'Chinese Name',
              'English Name',
              'Student ID',
              'On Plan',
            ],
            data: roster
                .map((student) => [
                      student.seatNo ?? '',
                      student.chineseName,
                      student.englishFullName,
                      student.studentId,
                      assignedIds.contains(student.studentId) ? 'Yes' : 'No',
                    ])
                .toList(),
            headerStyle: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
            ),
            cellStyle: const pw.TextStyle(fontSize: 10),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFE8EEF8),
            ),
            oddRowDecoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFF8FAFD),
            ),
            cellAlignments: const {
              0: pw.Alignment.center,
              4: pw.Alignment.center,
            },
            columnWidths: const {
              0: pw.FixedColumnWidth(54),
              1: pw.FlexColumnWidth(2),
              2: pw.FlexColumnWidth(2),
              3: pw.FlexColumnWidth(1.6),
              4: pw.FixedColumnWidth(56),
            },
            border: pw.TableBorder.all(
              color: PdfColors.grey400,
              width: 0.5,
            ),
          ),
          pw.SizedBox(height: 18),
          pw.Text(
            'Notes',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Container(
            height: 90,
            decoration: pw.BoxDecoration(
              borderRadius: pw.BorderRadius.circular(10),
              border: pw.Border.all(color: PdfColors.grey400),
            ),
          ),
        ],
      ),
    );

    return doc.save();
  }

  pw.Widget _summaryCard(String label, String value) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: pw.BoxDecoration(
          color: const PdfColor.fromInt(0xFFF4F7FB),
          borderRadius: pw.BorderRadius.circular(12),
          border: pw.Border.all(color: PdfColors.grey300),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              label,
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              value,
              maxLines: 2,
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _frontMarker() {
    const accent = PdfColor.fromInt(0xFFB695D7);
    return pw.Row(
      children: [
        pw.Expanded(child: pw.Container(height: 2, color: accent)),
        pw.SizedBox(width: 12),
        pw.Text(
          'Front',
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: accent,
          ),
        ),
        pw.SizedBox(width: 12),
        pw.Expanded(child: pw.Container(height: 2, color: accent)),
      ],
    );
  }

  pw.Widget _buildSeatingDiagram(
    SeatingLayout layout,
    Map<String, Student> studentsById,
  ) {
    if (layout.tables.isEmpty && layout.seats.isEmpty) {
      return pw.Center(
        child: pw.Text(
          'No tables or seats have been added to this layout yet.',
          style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
          textAlign: pw.TextAlign.center,
        ),
      );
    }

    const maxWidth = 700.0;
    const maxHeight = 250.0;
    final scale = math.min(
      maxWidth / layout.canvasWidth,
      maxHeight / layout.canvasHeight,
    );
    final diagramWidth = layout.canvasWidth * scale;
    final diagramHeight = layout.canvasHeight * scale;
    final tablesById = {
      for (final table in layout.tables) table.tableId: table
    };

    final sortedSeats = List<SeatingSeat>.from(layout.seats)
      ..sort((a, b) {
        final aTable = tablesById[a.tableId];
        final bTable = tablesById[b.tableId];
        final aY = (aTable?.y ?? 0) + a.y;
        final bY = (bTable?.y ?? 0) + b.y;
        final yCompare = aY.compareTo(bY);
        if (yCompare != 0) return yCompare;
        final aX = (aTable?.x ?? 0) + a.x;
        final bX = (bTable?.x ?? 0) + b.x;
        return aX.compareTo(bX);
      });

    return pw.Center(
      child: pw.Container(
        width: diagramWidth + 24,
        height: diagramHeight + 24,
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: const PdfColor.fromInt(0xFFFFF3D8),
          borderRadius: pw.BorderRadius.circular(16),
          border: pw.Border.all(color: PdfColors.grey500, width: 1),
        ),
        child: pw.SizedBox(
          width: diagramWidth,
          height: diagramHeight,
          child: pw.Stack(
            children: [
              for (final table in layout.tables)
                _buildTableDiagramWidget(table, scale),
              for (final seat in sortedSeats)
                _buildSeatDiagramWidget(
                  seat,
                  table: tablesById[seat.tableId],
                  student: seat.studentId == null
                      ? null
                      : studentsById[seat.studentId],
                  scale: scale,
                ),
            ],
          ),
        ),
      ),
    );
  }

  pw.Widget _buildTableDiagramWidget(SeatingTable table, double scale) {
    final label = _tableLabel(table);
    final width = table.width * scale;
    final height = table.height * scale;
    final radius = table.type == SeatingTableType.round
        ? math.min(width, height) / 2
        : 10.0;

    return pw.Positioned(
      left: (table.x - table.width / 2) * scale,
      top: (table.y - table.height / 2) * scale,
      child: pw.Container(
        width: width,
        height: height,
        alignment: pw.Alignment.center,
        padding: const pw.EdgeInsets.all(4),
        decoration: pw.BoxDecoration(
          color: table.type == SeatingTableType.teacherDesk
              ? const PdfColor.fromInt(0xFFE7D8F7)
              : const PdfColor.fromInt(0xFFE8F0FB),
          borderRadius: pw.BorderRadius.circular(radius),
          border: pw.Border.all(color: PdfColors.grey600, width: 1),
        ),
        child: pw.Text(
          label,
          maxLines: 2,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            fontSize: math.max(6, math.min(11, height * 0.18)),
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ),
    );
  }

  pw.Widget _buildSeatDiagramWidget(
    SeatingSeat seat, {
    required SeatingTable? table,
    required Student? student,
    required double scale,
  }) {
    if (table == null) return pw.SizedBox();

    final seatSize = math.max(22.0, 44.0 * scale);
    final label = student == null
        ? ''
        : (student.englishFirstName.trim().isNotEmpty
            ? student.englishFirstName.trim()
            : student.chineseName.trim());

    return pw.Positioned(
      left: (table.x + seat.x) * scale - seatSize / 2,
      top: (table.y + seat.y) * scale - seatSize / 2,
      child: pw.Container(
        width: seatSize,
        height: seatSize,
        alignment: pw.Alignment.center,
        padding: const pw.EdgeInsets.all(3),
        decoration: pw.BoxDecoration(
          color: student == null
              ? const PdfColor.fromInt(0xFFFDF8ED)
              : const PdfColor.fromInt(0xFFFFF2B8),
          borderRadius: pw.BorderRadius.circular(seatSize / 2),
          border: pw.Border.all(color: _seatStatusPdfColor(seat.statusColor)),
        ),
        child: pw.Text(
          label,
          maxLines: 2,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            fontSize: math.max(5, math.min(8, seatSize * 0.24)),
            fontWeight:
                student == null ? pw.FontWeight.normal : pw.FontWeight.bold,
          ),
        ),
      ),
    );
  }

  PdfColor _seatStatusPdfColor(SeatStatusColor status) {
    switch (status) {
      case SeatStatusColor.green:
        return const PdfColor.fromInt(0xFF2E7D32);
      case SeatStatusColor.yellow:
        return const PdfColor.fromInt(0xFFF9A825);
      case SeatStatusColor.red:
        return const PdfColor.fromInt(0xFFC62828);
      case SeatStatusColor.blue:
        return const PdfColor.fromInt(0xFF1565C0);
      case SeatStatusColor.none:
        return const PdfColor.fromInt(0xFF6B7280);
    }
  }

  String _tableLabel(SeatingTable table) {
    if (table.label.trim().isNotEmpty) return table.label.trim();
    switch (table.type) {
      case SeatingTableType.round:
        return 'Round table';
      case SeatingTableType.square:
        return 'Square table';
      case SeatingTableType.singleDesk:
        return 'Desk';
      case SeatingTableType.teacherDesk:
        return 'Teacher desk';
      case SeatingTableType.rectangular:
        return 'Table';
      case SeatingTableType.pairedRect:
        return 'Paired tables';
      case SeatingTableType.longDouble:
        return 'Long tables';
    }
  }

  int _compareStudentsForRoster(Student a, Student b) {
    final seatA = int.tryParse((a.seatNo ?? '').trim());
    final seatB = int.tryParse((b.seatNo ?? '').trim());
    if (seatA != null && seatB != null) {
      final compare = seatA.compareTo(seatB);
      if (compare != 0) return compare;
    } else if (seatA != null) {
      return -1;
    } else if (seatB != null) {
      return 1;
    } else {
      final seatCompare = (a.seatNo ?? '')
          .toLowerCase()
          .compareTo((b.seatNo ?? '').toLowerCase());
      if (seatCompare != 0) return seatCompare;
    }

    return a.englishFullName.toLowerCase().compareTo(
          b.englishFullName.toLowerCase(),
        );
  }

  String _formatTimestamp(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '${value.year}-$month-$day $hour:$minute';
  }
}

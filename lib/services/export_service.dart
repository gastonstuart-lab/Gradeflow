import 'package:csv/csv.dart';
import 'package:gradeflow/models/student.dart';
import 'package:gradeflow/models/grading_category.dart';
import 'package:excel/excel.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
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
}

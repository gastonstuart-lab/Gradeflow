import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gradeflow/services/student_service.dart';
import 'package:gradeflow/services/grading_category_service.dart';
import 'package:gradeflow/services/grade_item_service.dart';
import 'package:gradeflow/services/student_score_service.dart';
import 'package:gradeflow/services/final_exam_service.dart';
import 'package:gradeflow/services/calculation_service.dart';
import 'package:gradeflow/services/export_service.dart';
import 'package:gradeflow/theme.dart';
import 'package:gradeflow/components/animated_glow_border.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:convert';
import 'dart:typed_data';
import 'package:gradeflow/services/class_service.dart';
import 'package:gradeflow/services/auth_service.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:go_router/go_router.dart';
import 'package:gradeflow/nav.dart';
import 'package:gradeflow/components/pdf_web_viewer.dart';

class ExportScreen extends StatefulWidget {
  final String classId;

  const ExportScreen({super.key, required this.classId});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

enum _ExportScope { perStudent, perClass, classDetails, allClasses }

enum _ExportFormat { csv, xlsx, pdf }

enum _IssueType { missingExamScore, invalidCategoryWeights }

class _Issue {
  final _IssueType type;
  final String message;
  final String? studentId;
  const _Issue({required this.type, required this.message, this.studentId});
}

class _ExportScreenState extends State<ExportScreen> {
  final CalculationService _calcService = CalculationService();
  final ExportService _exportService = ExportService();
  bool _isCalculating = false;
  Map<String, Map<String, double?>> _studentGrades = {};
  List<_Issue> _issues = [];

  _ExportScope _scope = _ExportScope.perClass;
  _ExportFormat _format = _ExportFormat.csv;
  String? _selectedStudentId;
  bool _pdfClassAsTable =
      true; // When exporting class as PDF, use one-page table layout

  @override
  void initState() {
    super.initState();
    _calculateGrades();
  }

  Future<void> _calculateGrades() async {
    setState(() => _isCalculating = true);

    final studentService = context.read<StudentService>();
    final categoryService = context.read<GradingCategoryService>();
    final gradeItemService = context.read<GradeItemService>();
    final scoreService = context.read<StudentScoreService>();
    final examService = context.read<FinalExamService>();

    await studentService.loadStudents(widget.classId);
    await categoryService.loadCategories(widget.classId);
    await gradeItemService.loadGradeItems(widget.classId);

    final studentIds = studentService.students.map((s) => s.studentId).toList();
    final gradeItemIds =
        gradeItemService.gradeItems.map((g) => g.gradeItemId).toList();

    await scoreService.loadScores(widget.classId, gradeItemIds);
    await examService.loadExams(widget.classId, studentIds);

    final grades = <String, Map<String, double?>>{};
    final issues = <_Issue>[];

    final isWeightValid = categoryService.isWeightValid(widget.classId);
    if (!isWeightValid) {
      issues.add(const _Issue(
          type: _IssueType.invalidCategoryWeights,
          message: 'Category weights must total 100%'));
    }

    for (var student in studentService.students) {
      final exam = examService.getExam(student.studentId);
      if (exam?.examScore == null) {
        issues.add(_Issue(
          type: _IssueType.missingExamScore,
          message: '${student.chineseName}: Missing exam score',
          studentId: student.studentId,
        ));
      }

      grades[student.studentId] = _calcService.calculateStudentGrades(
        student.studentId,
        categoryService.categories,
        gradeItemService.gradeItems,
        scoreService.scores,
        exam,
      );
    }

    setState(() {
      _studentGrades = grades;
      _issues = issues;
      _isCalculating = false;
      _selectedStudentId ??= studentService.students.isNotEmpty
          ? studentService.students.first.studentId
          : null;
    });
  }

  Future<void> _preview() async {
    switch (_scope) {
      case _ExportScope.perStudent:
        return _previewPerStudent();
      case _ExportScope.perClass:
        return _previewPerClass();
      case _ExportScope.classDetails:
        return _previewClassDetails();
      case _ExportScope.allClasses:
        return _previewAllClasses();
    }
  }

  Future<void> _previewPerClass() async {
    final studentService = context.read<StudentService>();
    final categoryService = context.read<GradingCategoryService>();

    if (_format == _ExportFormat.csv) {
      final csv = _exportService.generateCSV(
        studentService.students,
        categoryService.categories,
        _studentGrades,
      );
      await _showCsvPreview(csv,
          title: 'Class CSV Preview', filename: 'grades_${widget.classId}.csv');
    } else if (_format == _ExportFormat.pdf) {
      // Show loading dialog
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Generating PDF Preview...'),
                  SizedBox(height: 8),
                  Text(
                    'Loading Chinese fonts (first time only)',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      try {
        final layout = _pdfClassAsTable ? 'table_landscape' : 'per_student';
        debugPrint(
            'Starting PDF preview build (perClass). layout=$layout students=${studentService.students.length}');
        final bytes = _pdfClassAsTable
            ? await _exportService.generateClassScoresTablePdf(
                studentService.students,
                categoryService.categories,
                _studentGrades,
              )
            : await _exportService.generateClassReportPdf(
                studentService.students,
                _studentGrades,
                categoryService.categories,
              );

        if (mounted) Navigator.of(context).pop(); // Close loading dialog

        final title = _pdfClassAsTable
            ? 'Class PDF Preview (One-page table, landscape)'
            : 'Class PDF Preview (Per-student pages)';
        await _showPdfPreview(bytes,
            title: title, filename: 'grades_${widget.classId}.pdf');
      } catch (e) {
        if (mounted) Navigator.of(context).pop();
        debugPrint('PerClass PDF preview failed: $e');
        _showError('Preview failed: $e');
      }
    } else {
      _showError('XLSX preview not supported. Choose CSV or PDF to preview.');
    }
  }

  Future<void> _previewPerStudent() async {
    final studentService = context.read<StudentService>();
    final categoryService = context.read<GradingCategoryService>();
    final student = studentService.students.firstWhere(
        (s) => s.studentId == _selectedStudentId,
        orElse: () => studentService.students.first);
    final grades = _studentGrades[student.studentId] ?? {};

    if (_format == _ExportFormat.csv) {
      final csv = _exportService.generateCSV(
          [student], categoryService.categories, {student.studentId: grades});
      await _showCsvPreview(csv,
          title: 'Student CSV Preview',
          filename: 'report_${student.studentId}.csv');
    } else if (_format == _ExportFormat.pdf) {
      final bytes = await _exportService.generateStudentReportPdf(
          student, grades, categoryService.categories);
      await _showPdfPreview(bytes,
          title: 'Student PDF Preview',
          filename: 'report_${student.studentId}.pdf');
    } else {
      _showError('XLSX preview not supported. Choose CSV or PDF to preview.');
    }
  }

  Future<void> _previewClassDetails() async {
    final studentService = context.read<StudentService>();
    final categoryService = context.read<GradingCategoryService>();
    // Always PDF for class details
    final bytes = await _exportService.generateClassReportPdf(
      studentService.students,
      _studentGrades,
      categoryService.categories,
    );
    await _showPdfPreview(bytes,
        title: 'Class Details PDF Preview (Per-student pages)',
        filename: 'class_details_${widget.classId}.pdf');
  }

  Future<void> _previewAllClasses() async {
    if (_format != _ExportFormat.csv) {
      _showError('Only CSV preview is supported for All Classes.');
      return;
    }

    final auth = context.read<AuthService>();
    final classService = context.read<ClassService>();
    final studentService = context.read<StudentService>();
    final categoryService = context.read<GradingCategoryService>();
    final gradeItemService = context.read<GradeItemService>();
    final scoreService = context.read<StudentScoreService>();
    final examService = context.read<FinalExamService>();

    final user = auth.currentUser;
    if (user == null) return _showError('Please sign in again');

    await classService.loadClasses(user.userId);

    final allRows = <List<String>>[];
    final headers = <String>[
      'Class',
      'Subject',
      'School Year',
      'Term',
      'Student ID',
      'Chinese Name',
      'English Name'
    ];

    for (final c in classService.classes) {
      await studentService.loadStudents(c.classId);
      await categoryService.loadCategories(c.classId);
      await gradeItemService.loadGradeItems(c.classId);
      final gradeItemIds =
          gradeItemService.gradeItems.map((g) => g.gradeItemId).toList();
      await scoreService.loadScores(c.classId, gradeItemIds);
      final studentIds =
          studentService.students.map((s) => s.studentId).toList();
      await examService.loadExams(widget.classId, studentIds);

      final catNames = categoryService.categories.map((e) => e.name).toList();
      final finalsHeaders = [
        'Process Score (40%)',
        'Exam Score (60%)',
        'Final Grade'
      ];
      for (final h in [...catNames, ...finalsHeaders]) {
        if (!headers.contains(h)) headers.add(h);
      }
      for (final s in studentService.students) {
        final grades = _calcService.calculateStudentGrades(
          s.studentId,
          categoryService.categories,
          gradeItemService.gradeItems,
          scoreService.scores,
          examService.getExam(s.studentId),
        );
        final row = <String>[
          c.className,
          c.subject,
          c.schoolYear,
          c.term,
          s.studentId,
          s.chineseName,
          s.englishFullName
        ];
        for (final h in headers.skip(7)) {
          if (h == 'Process Score (40%)') {
            row.add(_formatCell(grades['processScore']));
          } else if (h == 'Exam Score (60%)')
            row.add(_formatCell(grades['examScore']));
          else if (h == 'Final Grade')
            row.add(_formatCell(grades['finalGrade']));
          else {
            final cat = categoryService.categories.firstWhere(
              (e) => e.name == h,
              orElse: () => categoryService.categories.isNotEmpty
                  ? categoryService.categories.first
                  : (throw Exception('No categories')),
            );
            final v = grades[cat.categoryId];
            row.add(_formatCell(v));
          }
        }
        allRows.add(row);
      }
    }

    final csv = const ListToCsvConverter().convert([headers, ...allRows]);
    await _showCsvPreview(csv,
        title: 'All Classes CSV Preview', filename: 'grades_all_classes.csv');
  }

  Future<void> _showCsvPreview(String csv,
      {required String title, required String filename}) async {
    final rows = const CsvToListConverter().convert(csv);
    final head = rows.isNotEmpty
        ? rows.first.map((e) => e?.toString() ?? '').toList()
        : <String>[];
    final data = rows.length > 1 ? rows.sublist(1) : <List<dynamic>>[];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
      builder: (ctx) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.9,
            child: Padding(
              padding: AppSpacing.paddingLg,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                          child: Text(title,
                              style: ctx.textStyles.titleLarge?.semiBold)),
                      OutlinedButton.icon(
                        onPressed: () =>
                            _downloadTextWeb(csv, filename, 'text/csv'),
                        icon: const Icon(Icons.download),
                        label: const Text('Download CSV'),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      OutlinedButton.icon(
                        onPressed: () => _copyToClipboard(csv),
                        icon: const Icon(Icons.copy_all),
                        label: const Text('Copy CSV'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 600),
                          child: SingleChildScrollView(
                            child: DataTable(
                              columns: head
                                  .map((h) => DataColumn(
                                      label: Text(h,
                                          style: ctx.textStyles.labelSmall
                                              ?.semiBold)))
                                  .toList(),
                              rows: data
                                  .take(50)
                                  .map((r) => DataRow(
                                      cells: r
                                          .map((c) => DataCell(Text(
                                              '${c ?? ''}',
                                              softWrap: false)))
                                          .toList()))
                                  .toList(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showPdfPreview(Uint8List bytes,
      {required String title, required String filename}) async {
    if (!kIsWeb) {
      _showError('PDF preview is only supported on web.');
      return;
    }

    // Log the byte length to help diagnose empty/invalid PDFs
    debugPrint('PDF preview for $filename -> ${bytes.length} bytes');

    final isEmpty = bytes
        .isEmpty; // Only treat truly empty as error; tiny PDFs are still valid

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
      builder: (ctx) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.9,
            child: Padding(
              padding: AppSpacing.paddingLg,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                          child: Text(title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: ctx.textStyles.titleLarge?.semiBold)),
                      OutlinedButton.icon(
                        onPressed: () => _downloadBytesWeb(
                            bytes, filename, 'application/pdf'),
                        icon: const Icon(Icons.download),
                        label: const Text('Download PDF'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: isEmpty
                          ? Container(
                              color: Theme.of(ctx).colorScheme.error,
                              alignment: Alignment.center,
                              child: Text(
                                'Unable to display the document\nFix issues above, then try again.',
                                textAlign: TextAlign.center,
                                style: ctx.textStyles.titleSmall?.semiBold
                                    .withColor(
                                        Theme.of(ctx).colorScheme.onError),
                              ),
                            )
                          : PdfWebViewer(bytes: bytes),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _export() async {
    switch (_scope) {
      case _ExportScope.perStudent:
        return _exportPerStudent();
      case _ExportScope.perClass:
        return _exportPerClass();
      case _ExportScope.classDetails:
        return _exportClassDetails();
      case _ExportScope.allClasses:
        return _exportAllClasses();
    }
  }

  Future<void> _exportPerClass() async {
    final studentService = context.read<StudentService>();
    final categoryService = context.read<GradingCategoryService>();

    if (_issues.isNotEmpty) {
      final confirm = await _confirmExportWithIssues();
      if (confirm != true) return;
    }

    if (_format == _ExportFormat.csv) {
      final csv = _exportService.generateCSV(
        studentService.students,
        categoryService.categories,
        _studentGrades,
      );
      final ok = await _downloadTextWeb(
          csv, 'grades_${widget.classId}.csv', 'text/csv');
      ok
          ? _showSuccess('CSV downloaded')
          : _showError(
              'Download blocked or failed. Please allow downloads and try again.');
    } else if (_format == _ExportFormat.xlsx) {
      final bytes = _exportService.generateXlsx(
        studentService.students,
        categoryService.categories,
        _studentGrades,
      );
      final ok = await _downloadBytesWeb(bytes, 'grades_${widget.classId}.xlsx',
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      ok
          ? _showSuccess('XLSX downloaded')
          : _showError(
              'Download blocked or failed. Please allow downloads and try again.');
    } else {
      // Show loading dialog for PDF generation
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Generating PDF...'),
                  SizedBox(height: 8),
                  Text(
                    'Loading Chinese fonts (first time only)',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      try {
        final bytes = _pdfClassAsTable
            ? await _exportService.generateClassScoresTablePdf(
                studentService.students,
                categoryService.categories,
                _studentGrades,
              )
            : await _exportService.generateClassReportPdf(
                studentService.students,
                _studentGrades,
                categoryService.categories,
              );

        if (mounted) Navigator.of(context).pop(); // Close loading dialog

        final title = _pdfClassAsTable
            ? 'Class PDF Preview (One-page table, landscape)'
            : 'Class PDF Preview (Per-student pages)';
        await _showPdfPreview(bytes,
            title: title, filename: 'grades_${widget.classId}.pdf');
        _showSuccess('PDF generated successfully!');
      } catch (e) {
        if (mounted) Navigator.of(context).pop(); // Close loading dialog
        _showError('PDF generation failed: $e');
      }
    }
  }

  Future<void> _exportPerStudent() async {
    final studentService = context.read<StudentService>();
    final categoryService = context.read<GradingCategoryService>();
    final student = studentService.students.firstWhere(
        (s) => s.studentId == _selectedStudentId,
        orElse: () => studentService.students.first);
    final grades = _studentGrades[student.studentId] ?? {};

    if (_format == _ExportFormat.csv) {
      // Single-row CSV for the student
      final csv = _exportService.generateCSV(
          [student], categoryService.categories, {student.studentId: grades});
      final ok = await _downloadTextWeb(
          csv, 'report_${student.studentId}.csv', 'text/csv');
      ok
          ? _showSuccess('CSV downloaded')
          : _showError(
              'Download blocked or failed. Please allow downloads and try again.');
    } else if (_format == _ExportFormat.xlsx) {
      final bytes = _exportService.generateXlsx(
          [student], categoryService.categories, {student.studentId: grades});
      final ok = await _downloadBytesWeb(
          bytes,
          'report_${student.studentId}.xlsx',
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      ok
          ? _showSuccess('XLSX downloaded')
          : _showError(
              'Download blocked or failed. Please allow downloads and try again.');
    } else if (_format == _ExportFormat.pdf) {
      // Show loading dialog
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Generating PDF...'),
                  SizedBox(height: 8),
                  Text(
                    'Loading Chinese fonts (first time only)',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      try {
        final bytes = await _exportService.generateStudentReportPdf(
            student, grades, categoryService.categories);
        if (mounted) Navigator.of(context).pop(); // Close loading dialog

        final ok = await _downloadBytesWeb(
            bytes, 'report_${student.studentId}.pdf', 'application/pdf');
        ok
            ? _showSuccess('PDF downloaded successfully!')
            : _showError(
                'Download blocked or failed. Please allow downloads and try again.');
      } catch (e) {
        if (mounted) Navigator.of(context).pop();
        _showError('PDF generation failed: $e');
      }
    }
  }

  Future<void> _exportClassDetails() async {
    final studentService = context.read<StudentService>();
    final categoryService = context.read<GradingCategoryService>();

    if (_issues.isNotEmpty) {
      final confirm = await _confirmExportWithIssues();
      if (confirm != true) return;
    }

    final bytes = await _exportService.generateClassReportPdf(
      studentService.students,
      _studentGrades,
      categoryService.categories,
    );
    await _showPdfPreview(bytes,
        title: 'Class Details PDF Preview (Per-student pages)',
        filename: 'class_details_${widget.classId}.pdf');
  }

  Future<void> _exportAllClasses() async {
    final auth = context.read<AuthService>();
    final classService = context.read<ClassService>();
    final studentService = context.read<StudentService>();
    final categoryService = context.read<GradingCategoryService>();
    final gradeItemService = context.read<GradeItemService>();
    final scoreService = context.read<StudentScoreService>();
    final examService = context.read<FinalExamService>();

    final user = auth.currentUser;
    if (user == null) return _showError('Please sign in again');

    await classService.loadClasses(user.userId);

    final allRows = <List<String>>[];
    final headers = <String>[
      'Class',
      'Subject',
      'School Year',
      'Term',
      'Student ID',
      'Chinese Name',
      'English Name'
    ];
    // Determine max columns dynamically per class later for CSV; for XLSX we can write per class rows uniform to a superset

    // Build per-class and accumulate
    for (final c in classService.classes) {
      await studentService.loadStudents(c.classId);
      await categoryService.loadCategories(c.classId);
      await gradeItemService.loadGradeItems(c.classId);
      final gradeItemIds =
          gradeItemService.gradeItems.map((g) => g.gradeItemId).toList();
      await scoreService.loadScores(c.classId, gradeItemIds);
      final studentIds =
          studentService.students.map((s) => s.studentId).toList();
      await examService.loadExams(widget.classId, studentIds);

      // ensure category name headers present
      final catNames = categoryService.categories.map((e) => e.name).toList();
      // Extend headers once with categories and finals if not already
      final finalsHeaders = [
        'Process Score (40%)',
        'Exam Score (60%)',
        'Final Grade'
      ];
      final needed = [...catNames, ...finalsHeaders];
      for (final h in needed) {
        if (!headers.contains(h)) headers.add(h);
      }

      for (final s in studentService.students) {
        final grades = _calcService.calculateStudentGrades(
          s.studentId,
          categoryService.categories,
          gradeItemService.gradeItems,
          scoreService.scores,
          examService.getExam(s.studentId),
        );
        final row = <String>[
          c.className,
          c.subject,
          c.schoolYear,
          c.term,
          s.studentId,
          s.chineseName,
          s.englishFullName,
        ];
        // Fill category columns in order of headers
        for (final h in headers.skip(7)) {
          if (h == 'Process Score (40%)') {
            row.add(_formatCell(grades['processScore']));
          } else if (h == 'Exam Score (60%)') {
            row.add(_formatCell(grades['examScore']));
          } else if (h == 'Final Grade') {
            row.add(_formatCell(grades['finalGrade']));
          } else {
            // Try to find matching category by name
            final cat = categoryService.categories.firstWhere(
              (e) => e.name == h,
              orElse: () => categoryService.categories.isNotEmpty
                  ? categoryService.categories.first
                  : (throw Exception('No categories')),
            );
            final v = grades[cat.categoryId];
            row.add(_formatCell(v));
          }
        }
        allRows.add(row);
      }
    }

    if (_format == _ExportFormat.csv) {
      final csv = const ListToCsvConverter().convert([headers, ...allRows]);
      final ok =
          await _downloadTextWeb(csv, 'grades_all_classes.csv', 'text/csv');
      ok
          ? _showSuccess('CSV downloaded')
          : _showError(
              'Download blocked or failed. Try "Open in New Tab" or copy CSV.');
    } else if (_format == _ExportFormat.xlsx) {
      final excel = Excel.createExcel();
      final sheet = excel.sheets[excel.getDefaultSheet()]!;
      sheet
          .appendRow(headers.map<CellValue?>((e) => TextCellValue(e)).toList());
      for (final r in allRows) {
        final padded = [...r];
        while (padded.length < headers.length) {
          padded.add('');
        }
        sheet.appendRow(
            padded.map<CellValue?>((e) => TextCellValue(e)).toList());
      }
      final bytes = Uint8List.fromList(excel.encode()!);
      final ok = await _downloadBytesWeb(bytes, 'grades_all_classes.xlsx',
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      ok
          ? _showSuccess('XLSX downloaded')
          : _showError(
              'Download blocked or failed. Please allow downloads and try again.');
    } else {
      _showError('All-classes PDF not available. Choose CSV/XLSX.');
    }
  }

  String _formatCell(double? v) => v == null ? '' : v.toStringAsFixed(2);

  void _handleIssueTap(_Issue issue) {
    switch (issue.type) {
      case _IssueType.missingExamScore:
        final sid = issue.studentId;
        final qp = sid != null ? '?highlightStudentId=$sid' : '';
        context.push('${AppRoutes.classDetail}/${widget.classId}/exams$qp');
        break;
      case _IssueType.invalidCategoryWeights:
        context.push('${AppRoutes.classDetail}/${widget.classId}/categories');
        break;
    }
  }

  Future<bool?> _confirmExportWithIssues() => showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Export with Missing Data?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('The following issues were found:'),
              const SizedBox(height: AppSpacing.sm),
              ..._issues.take(5).map((it) =>
                  Text('• ${it.message}', style: context.textStyles.bodySmall)),
              if (_issues.length > 5)
                Text('... and ${_issues.length - 5} more',
                    style: context.textStyles.bodySmall),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Export Anyway')),
          ],
        ),
      );

  Future<bool> _downloadTextWeb(String text, String filename, String mime,
      {bool openInNewTab = false}) async {
    final bytes = utf8.encode(text);
    return _downloadBytesWeb(Uint8List.fromList(bytes), filename, mime,
        openInNewTab: openInNewTab);
  }

  Future<bool> _downloadBytesWeb(Uint8List bytes, String filename, String mime,
      {bool openInNewTab = false}) async {
    if (!kIsWeb) {
      _showError('Export is only supported on web');
      return false;
    }
    if (bytes.isEmpty) {
      debugPrint('Export bytes empty for $filename; aborting download.');
      return false;
    }
    try {
      debugPrint(
          'Preparing download for $filename (${bytes.length} bytes, mime=$mime).');
      final blob = html.Blob([bytes], mime);
      final url = html.Url.createObjectUrlFromBlob(blob);

      // Use a hidden anchor to trigger a download. Must be in DOM, clicked directly in user gesture context.
      final anchor = html.AnchorElement(href: url)
        ..style.display = 'none'
        ..download = filename;
      anchor.setAttribute('download', filename);
      html.document.body!.children.add(anchor);
      anchor.click();
      anchor.remove();

      // Delay revoke to ensure download completes (Chrome/Firefox/Safari need this).
      await Future.delayed(const Duration(seconds: 1));
      html.Url.revokeObjectUrl(url);
      debugPrint('Download triggered successfully for $filename');
      return true;
    } catch (e) {
      debugPrint('Export download failed for $filename: $e');
      return false;
    }
  }

  Future<void> _copyToClipboard(String text) async {
    if (!kIsWeb) {
      _showError('Copy is only available on web.');
      return;
    }
    try {
      // Prefer async clipboard API
      // ignore: undefined_prefixed_name
      await html.window.navigator.clipboard?.writeText(text);
      _showSuccess('CSV copied to clipboard');
    } catch (e) {
      debugPrint('Clipboard write failed: $e');
      _showError('Copy failed. Select and copy manually from the preview.');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(message),
          backgroundColor: Theme.of(context).colorScheme.error),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final studentService = context.watch<StudentService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Export Grades'),
      ),
      body: _isCalculating
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: AppSpacing.paddingLg,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_issues.isNotEmpty) ...[
                    Container(
                      padding: AppSpacing.paddingMd,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.warning,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onErrorContainer),
                              const SizedBox(width: AppSpacing.sm),
                              Text(
                                'Issues Found',
                                style: context.textStyles.titleMedium?.semiBold
                                    .withColor(
                                  Theme.of(context)
                                      .colorScheme
                                      .onErrorContainer,
                                ),
                              ),
                              const Spacer(),
                              TextButton.icon(
                                onPressed: _calculateGrades,
                                icon: const Icon(Icons.refresh, size: 18),
                                label: const Text('Recheck'),
                                style: TextButton.styleFrom(
                                    foregroundColor: Theme.of(context)
                                        .colorScheme
                                        .onErrorContainer),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          ..._issues.take(10).map((issue) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: InkWell(
                                  onTap: () => _handleIssueTap(issue),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.touch_app, size: 16),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          issue.message,
                                          style: TextStyle(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onErrorContainer,
                                              decoration:
                                                  TextDecoration.underline),
                                          softWrap: true,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )),
                          if (_issues.length > 10)
                            Text(
                              '... and ${_issues.length - 10} more issues',
                              style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onErrorContainer),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  AnimatedGlowBorder(
                    child: Card(
                      child: Padding(
                        padding: AppSpacing.paddingLg,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Export Options',
                                style: context.textStyles.titleLarge?.semiBold),
                            const SizedBox(height: AppSpacing.md),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                DropdownButton<_ExportScope>(
                                  value: _scope,
                                  onChanged: (v) =>
                                      setState(() => _scope = v ?? _scope),
                                  items: const [
                                    DropdownMenuItem(
                                        value: _ExportScope.perStudent,
                                        child: Text('Per Student')),
                                    DropdownMenuItem(
                                        value: _ExportScope.perClass,
                                        child: Text('Per Class (table)')),
                                    DropdownMenuItem(
                                        value: _ExportScope.classDetails,
                                        child: Text(
                                            'Class Details (per-student)')),
                                    DropdownMenuItem(
                                        value: _ExportScope.allClasses,
                                        child: Text('All Classes')),
                                  ],
                                ),
                                DropdownButton<_ExportFormat>(
                                  value: _format,
                                  onChanged: (v) =>
                                      setState(() => _format = v ?? _format),
                                  items: const [
                                    DropdownMenuItem(
                                        value: _ExportFormat.csv,
                                        child: Text('CSV (Spreadsheet)')),
                                    DropdownMenuItem(
                                        value: _ExportFormat.xlsx,
                                        child: Text('XLSX (Excel)')),
                                    DropdownMenuItem(
                                        value: _ExportFormat.pdf,
                                        child: Text('PDF (Report)')),
                                  ],
                                ),
                                if (_scope == _ExportScope.perStudent)
                                  DropdownButton<String>(
                                    value: _selectedStudentId,
                                    onChanged: (v) =>
                                        setState(() => _selectedStudentId = v),
                                    items: studentService.students
                                        .map((s) => DropdownMenuItem(
                                            value: s.studentId,
                                            child: Text(
                                                '${s.chineseName} (${s.englishFullName})')))
                                        .toList(),
                                  ),
                                if (_scope == _ExportScope.perClass &&
                                    _format == _ExportFormat.pdf)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.picture_as_pdf,
                                          size: 18),
                                      const SizedBox(width: 8),
                                      Text('PDF Layout:',
                                          style: context.textStyles.labelSmall),
                                      const SizedBox(width: 8),
                                      ChoiceChip(
                                        label: const Text(
                                            'One-page table (landscape)'),
                                        selected: _pdfClassAsTable,
                                        onSelected: (v) => setState(
                                            () => _pdfClassAsTable = true),
                                      ),
                                      const SizedBox(width: 6),
                                      ChoiceChip(
                                        label: const Text('Per-student pages'),
                                        selected: !_pdfClassAsTable,
                                        onSelected: (v) => setState(
                                            () => _pdfClassAsTable = false),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Builder(builder: (ctx) {
                              final canExport =
                                  studentService.students.isNotEmpty &&
                                      (_scope != _ExportScope.perStudent ||
                                          _selectedStudentId != null);
                              return FilledButton.icon(
                                onPressed: canExport ? _export : null,
                                icon: const Icon(Icons.download),
                                label: Text(_scope == _ExportScope.classDetails
                                    ? 'Export (PDF)'
                                    : 'Export'),
                              );
                            }),
                            const SizedBox(height: AppSpacing.sm),
                            Builder(builder: (ctx) {
                              final canPreview =
                                  studentService.students.isNotEmpty &&
                                      (_scope != _ExportScope.perStudent ||
                                          _selectedStudentId != null);
                              return OutlinedButton.icon(
                                onPressed: canPreview ? _preview : null,
                                icon: const Icon(Icons.visibility),
                                label: Text(_scope == _ExportScope.classDetails
                                    ? 'Preview (PDF)'
                                    : 'Preview'),
                              );
                            }),
                            if (_scope == _ExportScope.classDetails)
                              Padding(
                                padding:
                                    const EdgeInsets.only(top: AppSpacing.xs),
                                child: Text(
                                  'Class Details creates a per-student PDF (one page per student).',
                                  style: context.textStyles.bodySmall
                                      ?.withColor(Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant),
                                ),
                              ),
                            if (studentService.students.isEmpty)
                              Padding(
                                padding:
                                    const EdgeInsets.only(top: AppSpacing.xs),
                                child: Text(
                                  'No students found in this class. Add students first.',
                                  style: context.textStyles.bodySmall
                                      ?.withColor(Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

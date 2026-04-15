import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gradeflow/components/tool_first_app_surface.dart';
import 'package:gradeflow/components/workspace_shell.dart';
import 'package:gradeflow/models/class.dart';
import 'package:gradeflow/models/final_exam.dart';
import 'package:gradeflow/models/grade_item.dart';
import 'package:gradeflow/models/grading_category.dart';
import 'package:gradeflow/models/student.dart';
import 'package:gradeflow/models/student_score.dart';
import 'package:gradeflow/repositories/repository_factory.dart';
import 'package:gradeflow/services/student_service.dart';
import 'package:gradeflow/services/grading_category_service.dart';
import 'package:gradeflow/services/grade_item_service.dart';
import 'package:gradeflow/services/student_score_service.dart';
import 'package:gradeflow/services/final_exam_service.dart';
import 'package:gradeflow/services/calculation_service.dart';
import 'package:gradeflow/services/export_service.dart';
import 'package:gradeflow/theme.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'dart:typed_data';
import 'package:gradeflow/platform/browser_file_actions.dart';
import 'package:gradeflow/services/class_service.dart';
import 'package:gradeflow/services/auth_service.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart' hide Border;
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

class _ToolbarDropdown<T> extends StatelessWidget {
  const _ToolbarDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.28),
        ),
        color: theme.colorScheme.surface.withValues(alpha: 0.16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: context.textStyles.labelSmall?.withColor(
              theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              onChanged: onChanged,
              items: items,
            ),
          ),
        ],
      ),
    );
  }
}

class _AllClassesExportSnapshot {
  final Class classItem;
  final List<Student> students;
  final List<GradingCategory> categories;
  final List<GradeItem> gradeItems;
  final List<StudentScore> scores;
  final List<FinalExam> exams;

  const _AllClassesExportSnapshot({
    required this.classItem,
    required this.students,
    required this.categories,
    required this.gradeItems,
    required this.scores,
    required this.exams,
  });
}

class _AllClassesExportDataset {
  final List<String> headers;
  final List<List<String>> rows;
  final int classCount;
  final int studentCount;

  const _AllClassesExportDataset({
    required this.headers,
    required this.rows,
    required this.classCount,
    required this.studentCount,
  });
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
  bool _progressVisible = false;

  @override
  void initState() {
    super.initState();
    _calculateGrades();
  }

  void _showFeedback(
    String message, {
    WorkspaceFeedbackTone tone = WorkspaceFeedbackTone.info,
    String? title,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 4),
  }) {
    if (!mounted) return;
    showWorkspaceSnackBar(
      context,
      message: message,
      tone: tone,
      title: title,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
    );
  }

  void _showBlockingProgress({
    required String title,
    String? subtitle,
  }) {
    if (!mounted || _progressVisible) return;
    _progressVisible = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => WorkspaceProgressDialog(
        title: title,
        subtitle: subtitle,
      ),
    ).whenComplete(() {
      _progressVisible = false;
    });
  }

  void _dismissBlockingProgress() {
    if (!mounted || !_progressVisible) return;
    Navigator.of(context, rootNavigator: true).pop();
  }

  String _scopeLabel(_ExportScope scope) {
    switch (scope) {
      case _ExportScope.perStudent:
        return 'Per student';
      case _ExportScope.perClass:
        return 'Per class';
      case _ExportScope.classDetails:
        return 'Class details';
      case _ExportScope.allClasses:
        return 'All classes';
    }
  }

  String _formatLabel(_ExportFormat format) {
    switch (format) {
      case _ExportFormat.csv:
        return 'CSV';
      case _ExportFormat.xlsx:
        return 'XLSX';
      case _ExportFormat.pdf:
        return 'PDF';
    }
  }

  bool _canPreview({
    required int studentCount,
    required int classCount,
  }) {
    switch (_scope) {
      case _ExportScope.perStudent:
        return studentCount > 0 && _selectedStudentId != null;
      case _ExportScope.perClass:
        return studentCount > 0 && _format != _ExportFormat.xlsx;
      case _ExportScope.classDetails:
        return studentCount > 0;
      case _ExportScope.allClasses:
        return classCount > 0 && _format == _ExportFormat.csv;
    }
  }

  bool _canExport({
    required int studentCount,
    required int classCount,
  }) {
    switch (_scope) {
      case _ExportScope.perStudent:
        return studentCount > 0 && _selectedStudentId != null;
      case _ExportScope.perClass:
      case _ExportScope.classDetails:
        return studentCount > 0;
      case _ExportScope.allClasses:
        return classCount > 0 && _format != _ExportFormat.pdf;
    }
  }

  String _reportTitle() {
    switch (_scope) {
      case _ExportScope.perStudent:
        return 'Student report';
      case _ExportScope.perClass:
        return 'Class export';
      case _ExportScope.classDetails:
        return 'Class details packet';
      case _ExportScope.allClasses:
        return 'All-classes export';
    }
  }

  String _reportSubtitle({
    required String className,
    required int classCount,
  }) {
    switch (_scope) {
      case _ExportScope.perStudent:
        return 'Prepare a single student handoff or archive from $className.';
      case _ExportScope.perClass:
        return 'Keep the full class report aligned to the current grading context.';
      case _ExportScope.classDetails:
        return 'Generate the more detailed per-student packet for this class.';
      case _ExportScope.allClasses:
        return classCount == 0
            ? 'Review every active class in one export set.'
            : 'Combine $classCount active class reports without leaving the current export workspace.';
    }
  }

  Future<_AllClassesExportDataset> _buildAllClassesExportDataset() async {
    final auth = context.read<AuthService>();
    final classService = context.read<ClassService>();
    final user = auth.currentUser;
    if (user == null) {
      throw StateError('Please sign in again');
    }

    await classService.loadClasses(user.userId);
    final classes = classService.classes;
    final repo = RepositoryFactory.instance;
    final categoryHeaders = <String>[];
    final seenCategoryNames = <String>{};
    final snapshots = <_AllClassesExportSnapshot>[];
    var totalStudents = 0;

    for (final classItem in classes) {
      final students = await repo.loadStudents(classItem.classId);
      final categories = (await repo.loadCategories(classItem.classId))
          .where((category) => category.isActive)
          .toList();
      final gradeItems = (await repo.loadGradeItems(classItem.classId))
          .where((item) => item.isActive)
          .toList();
      final scores = <StudentScore>[];
      for (final item in gradeItems) {
        scores.addAll(await repo.loadScores(classItem.classId, item.gradeItemId));
      }
      final studentIds = students.map((student) => student.studentId).toSet();
      final exams = (await repo.loadExams(classItem.classId))
          .where((exam) => studentIds.contains(exam.studentId))
          .toList();

      for (final category in categories) {
        if (seenCategoryNames.add(category.name)) {
          categoryHeaders.add(category.name);
        }
      }

      totalStudents += students.length;
      snapshots.add(
        _AllClassesExportSnapshot(
          classItem: classItem,
          students: students,
          categories: categories,
          gradeItems: gradeItems,
          scores: scores,
          exams: exams,
        ),
      );
    }

    final headers = <String>[
      'Class',
      'Subject',
      'School Year',
      'Term',
      'Student ID',
      'Chinese Name',
      'English Name',
      ...categoryHeaders,
      'Process Score (40%)',
      'Exam Score (60%)',
      'Final Grade',
    ];

    final rows = <List<String>>[];
    for (final snapshot in snapshots) {
      final categoryIdByName = <String, String>{
        for (final category in snapshot.categories) category.name: category.categoryId,
      };
      final examByStudentId = <String, FinalExam>{
        for (final exam in snapshot.exams) exam.studentId: exam,
      };

      for (final student in snapshot.students) {
        final grades = _calcService.calculateStudentGrades(
          student.studentId,
          snapshot.categories,
          snapshot.gradeItems,
          snapshot.scores,
          examByStudentId[student.studentId],
        );

        final row = <String>[
          snapshot.classItem.className,
          snapshot.classItem.subject,
          snapshot.classItem.schoolYear,
          snapshot.classItem.term,
          student.studentId,
          student.chineseName,
          student.englishFullName,
        ];

        for (final categoryName in categoryHeaders) {
          final categoryId = categoryIdByName[categoryName];
          row.add(categoryId == null ? '' : _formatCell(grades[categoryId]));
        }

        row.add(_formatCell(grades['processScore']));
        row.add(_formatCell(grades['examScore']));
        row.add(_formatCell(grades['finalGrade']));
        rows.add(row);
      }
    }

    return _AllClassesExportDataset(
      headers: headers,
      rows: rows,
      classCount: snapshots.length,
      studentCount: totalStudents,
    );
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
      _showBlockingProgress(
        title: 'Generating class preview',
        subtitle: 'Loading report fonts and building the PDF.',
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

        _dismissBlockingProgress();

        final title = _pdfClassAsTable
            ? 'Class PDF Preview (One-page table, landscape)'
            : 'Class PDF Preview (Per-student pages)';
        await _showPdfPreview(bytes,
            title: title, filename: 'grades_${widget.classId}.pdf');
      } catch (e) {
        _dismissBlockingProgress();
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
      _showBlockingProgress(
        title: 'Generating student preview',
        subtitle: 'Loading the report packet for ${student.chineseName}.',
      );
      try {
        final bytes = await _exportService.generateStudentReportPdf(
            student, grades, categoryService.categories);
        _dismissBlockingProgress();
        await _showPdfPreview(bytes,
            title: 'Student PDF Preview',
            filename: 'report_${student.studentId}.pdf');
      } catch (e) {
        _dismissBlockingProgress();
        _showError('Preview failed: $e');
      }
    } else {
      _showError('XLSX preview not supported. Choose CSV or PDF to preview.');
    }
  }

  Future<void> _previewClassDetails() async {
    final studentService = context.read<StudentService>();
    final categoryService = context.read<GradingCategoryService>();
    _showBlockingProgress(
      title: 'Generating class packet preview',
      subtitle: 'Preparing the per-student report packet.',
    );
    try {
      final bytes = await _exportService.generateClassReportPdf(
        studentService.students,
        _studentGrades,
        categoryService.categories,
      );
      _dismissBlockingProgress();
      await _showPdfPreview(bytes,
          title: 'Class Details PDF Preview (Per-student pages)',
          filename: 'class_details_${widget.classId}.pdf');
    } catch (e) {
      _dismissBlockingProgress();
      _showError('Preview failed: $e');
    }
  }

  Future<void> _previewAllClasses() async {
    if (_format != _ExportFormat.csv) {
      _showFeedback(
        'Only CSV preview is available for the all-classes view.',
        tone: WorkspaceFeedbackTone.warning,
        title: 'Preview unavailable',
      );
      return;
    }

    try {
      _showBlockingProgress(
        title: 'Preparing all classes preview',
        subtitle: 'Collecting each class snapshot for review.',
      );
      final dataset = await _buildAllClassesExportDataset();
      _dismissBlockingProgress();
      final csv =
          const ListToCsvConverter().convert([dataset.headers, ...dataset.rows]);
      await _showCsvPreview(csv,
          title: 'All Classes CSV Preview', filename: 'grades_all_classes.csv');
    } catch (e) {
      _dismissBlockingProgress();
      _showError('Preview failed: $e');
    }
  }

  Future<void> _showCsvPreview(String csv,
      {required String title, required String filename}) async {
    final horizontalController = ScrollController();
    final verticalController = ScrollController();
    final rows = const CsvToListConverter().convert(csv);
    final head = rows.isNotEmpty
        ? rows.first.map((e) => e?.toString() ?? '').toList()
        : <String>[];
    final data = rows.length > 1 ? rows.sublist(1) : <List<dynamic>>[];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return FractionallySizedBox(
          heightFactor: 0.92,
          child: WorkspaceSheetScaffold(
            title: title,
            subtitle:
                'Review the spreadsheet layout before downloading or copying it.',
            icon: Icons.table_chart_outlined,
            bodyCanExpand: true,
            headerAction: IconButton(
              onPressed: () => Navigator.of(ctx).pop(),
              icon: const Icon(Icons.close),
              tooltip: 'Close',
              style: WorkspaceButtonStyles.icon(ctx),
            ),
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _downloadText(csv, filename, 'text/csv'),
                      icon: const Icon(Icons.download),
                      label: const Text('Download CSV'),
                      style: WorkspaceButtonStyles.outlined(ctx),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _copyToClipboard(csv),
                      icon: const Icon(Icons.copy_all),
                      label: const Text('Copy CSV'),
                      style: WorkspaceButtonStyles.outlined(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: WorkspaceSpacing.md),
                Expanded(
                  child: WorkspaceSurfaceCard(
                    radius: WorkspaceRadius.card,
                    padding: const EdgeInsets.all(12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(WorkspaceRadius.card),
                      child: Scrollbar(
                        controller: horizontalController,
                        thumbVisibility: true,
                        scrollbarOrientation: ScrollbarOrientation.bottom,
                        child: SingleChildScrollView(
                          controller: horizontalController,
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: 600),
                            child: Scrollbar(
                              controller: verticalController,
                              thumbVisibility: true,
                              child: SingleChildScrollView(
                                controller: verticalController,
                                child: DataTable(
                                  columns: head
                                      .map(
                                        (header) => DataColumn(
                                          label: Text(
                                            header,
                                            style: ctx
                                                .textStyles.labelSmall?.semiBold,
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  rows: data
                                      .take(50)
                                      .map(
                                        (row) => DataRow(
                                          cells: row
                                              .map(
                                                (cell) => DataCell(
                                                  Text(
                                                    '${cell ?? ''}',
                                                    softWrap: false,
                                                  ),
                                                ),
                                              )
                                              .toList(),
                                        ),
                                      )
                                      .toList(),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
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

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return FractionallySizedBox(
          heightFactor: 0.92,
          child: WorkspaceSheetScaffold(
            title: title,
            subtitle: 'Preview the report before downloading it.',
            icon: Icons.picture_as_pdf_outlined,
            bodyCanExpand: true,
            headerAction: IconButton(
              onPressed: () => Navigator.of(ctx).pop(),
              icon: const Icon(Icons.close),
              tooltip: 'Close',
              style: WorkspaceButtonStyles.icon(ctx),
            ),
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        _downloadBytes(bytes, filename, 'application/pdf'),
                    icon: const Icon(Icons.download),
                    label: const Text('Download PDF'),
                    style: WorkspaceButtonStyles.outlined(ctx),
                  ),
                ),
                const SizedBox(height: WorkspaceSpacing.md),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(WorkspaceRadius.card),
                    child: isEmpty
                        ? WorkspaceInlineState(
                            icon: Icons.error_outline_rounded,
                            title: 'Unable to display this document',
                            subtitle:
                                'Fix the report issues above, then generate the preview again.',
                          )
                        : PdfWebViewer(bytes: bytes),
                  ),
                ),
              ],
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
      final ok = await _downloadText(
          csv, 'grades_${widget.classId}.csv', 'text/csv');
      ok
          ? _showSuccess('Class CSV downloaded')
          : _showError(
              'Download blocked or failed. Please allow downloads and try again.');
    } else if (_format == _ExportFormat.xlsx) {
      final bytes = _exportService.generateXlsx(
        studentService.students,
        categoryService.categories,
        _studentGrades,
      );
      final ok = await _downloadBytes(bytes, 'grades_${widget.classId}.xlsx',
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      ok
          ? _showSuccess('Class XLSX downloaded')
          : _showError(
              'Download blocked or failed. Please allow downloads and try again.');
    } else {
      _showBlockingProgress(
        title: 'Generating class report',
        subtitle: 'Building the PDF report for the current class.',
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

        _dismissBlockingProgress();

        final title = _pdfClassAsTable
            ? 'Class PDF Preview (One-page table, landscape)'
            : 'Class PDF Preview (Per-student pages)';
        await _showPdfPreview(bytes,
            title: title, filename: 'grades_${widget.classId}.pdf');
        _showSuccess('Class PDF ready to review');
      } catch (e) {
        _dismissBlockingProgress();
        _showError('PDF generation failed: $e');
      }
    }
  }

  Future<void> _exportPerStudent() async {
    if (_issues.isNotEmpty) {
      final confirm = await _confirmExportWithIssues();
      if (confirm != true) return;
    }

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
      final ok = await _downloadText(
          csv, 'report_${student.studentId}.csv', 'text/csv');
      ok
          ? _showSuccess('Student CSV downloaded')
          : _showError(
              'Download blocked or failed. Please allow downloads and try again.');
    } else if (_format == _ExportFormat.xlsx) {
      final bytes = _exportService.generateXlsx(
          [student], categoryService.categories, {student.studentId: grades});
      final ok = await _downloadBytes(
          bytes,
          'report_${student.studentId}.xlsx',
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      ok
          ? _showSuccess('Student XLSX downloaded')
          : _showError(
              'Download blocked or failed. Please allow downloads and try again.');
    } else if (_format == _ExportFormat.pdf) {
      _showBlockingProgress(
        title: 'Generating student report',
        subtitle: 'Preparing the PDF handoff for ${student.chineseName}.',
      );

      try {
        final bytes = await _exportService.generateStudentReportPdf(
            student, grades, categoryService.categories);
        _dismissBlockingProgress();

        final ok = await _downloadBytes(
            bytes, 'report_${student.studentId}.pdf', 'application/pdf');
        ok
            ? _showSuccess('Student PDF downloaded')
            : _showError(
                'Download blocked or failed. Please allow downloads and try again.');
      } catch (e) {
        _dismissBlockingProgress();
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

    _showBlockingProgress(
      title: 'Generating class details packet',
      subtitle: 'Building the per-student PDF report.',
    );

    try {
      final bytes = await _exportService.generateClassReportPdf(
        studentService.students,
        _studentGrades,
        categoryService.categories,
      );
      _dismissBlockingProgress();
      await _showPdfPreview(bytes,
          title: 'Class Details PDF Preview (Per-student pages)',
          filename: 'class_details_${widget.classId}.pdf');
      _showSuccess('Class details packet ready to review');
    } catch (e) {
      _dismissBlockingProgress();
      _showError('PDF generation failed: $e');
    }
  }

  Future<void> _exportAllClasses() async {
    try {
      _showBlockingProgress(
        title: 'Preparing all classes export',
        subtitle: 'Collecting students, categories, scores, and exams.',
      );
      final dataset = await _buildAllClassesExportDataset();
      _dismissBlockingProgress();

      if (_format == _ExportFormat.csv) {
        final csv =
            const ListToCsvConverter().convert([dataset.headers, ...dataset.rows]);
        final ok =
            await _downloadText(csv, 'grades_all_classes.csv', 'text/csv');
        ok
            ? _showSuccess(
                'All-classes CSV downloaded for ${dataset.classCount} classes')
            : _showError(
                'Download blocked or failed. Try "Open in New Tab" or copy CSV.');
      } else if (_format == _ExportFormat.xlsx) {
        final excel = Excel.createExcel();
        final sheet = excel.sheets[excel.getDefaultSheet()]!;
        sheet.appendRow(
          dataset.headers.map<CellValue?>((value) => TextCellValue(value)).toList(),
        );
        for (final row in dataset.rows) {
          sheet.appendRow(
            row.map<CellValue?>((value) => TextCellValue(value)).toList(),
          );
        }
        final encoded = excel.encode();
        if (encoded == null) {
          throw StateError('Could not encode the Excel workbook.');
        }
        final ok = await _downloadBytes(
          Uint8List.fromList(encoded),
          'grades_all_classes.xlsx',
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        );
        ok
            ? _showSuccess(
                'All-classes XLSX downloaded for ${dataset.classCount} classes')
            : _showError(
                'Download blocked or failed. Please allow downloads and try again.');
      } else {
        _showError('All-classes PDF not available. Choose CSV or XLSX.');
      }
    } catch (e) {
      _dismissBlockingProgress();
      _showError('All-classes export failed: $e');
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
        builder: (dialogContext) => WorkspaceDialogScaffold(
          title: 'Export with issues?',
          subtitle:
              'Some score or weighting checks still need attention. You can continue, or jump back to fix them first.',
          icon: Icons.warning_amber_rounded,
          maxWidth: 560,
          body: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ..._issues.take(5).map(
                    (issue) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.error_outline_rounded,
                            size: 18,
                            color: Theme.of(dialogContext).colorScheme.error,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              issue.message,
                              style: dialogContext.textStyles.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              if (_issues.length > 5)
                Text(
                  '${_issues.length - 5} more issue${_issues.length - 5 == 1 ? '' : 's'} remain hidden here.',
                  style: WorkspaceTypography.metadata(dialogContext),
                ),
            ],
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              style: WorkspaceButtonStyles.outlined(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: WorkspaceButtonStyles.filled(dialogContext),
              child: const Text('Export anyway'),
            ),
          ],
        ),
      );

  Future<bool> _downloadText(
    String text,
    String filename,
    String mime,
  ) async {
    if (!kIsWeb) {
      _showError('Export is only supported on web');
      return false;
    }

    return downloadBrowserText(text, filename, mime);
  }

  Future<bool> _downloadBytes(
    Uint8List bytes,
    String filename,
    String mime,
  ) async {
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
      final triggered = await downloadBrowserBytes(bytes, filename, mime);
      if (triggered) {
        debugPrint('Download triggered successfully for $filename');
      }
      return triggered;
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
      final copied = await copyBrowserText(text);
      if (!copied) {
        throw StateError('Clipboard write was not available.');
      }
      _showSuccess('CSV copied to clipboard');
    } catch (e) {
      debugPrint('Clipboard write failed: $e');
      _showError('Copy failed. Select and copy manually from the preview.');
    }
  }

  void _showError(String message) => _showFeedback(
        message,
        tone: WorkspaceFeedbackTone.error,
        title: 'Export error',
      );

  void _showSuccess(String message) => _showFeedback(
        message,
        tone: WorkspaceFeedbackTone.success,
      );

  List<_ExportFormat> _availableFormatsForScope(_ExportScope scope) {
    switch (scope) {
      case _ExportScope.perStudent:
      case _ExportScope.perClass:
        return const [
          _ExportFormat.csv,
          _ExportFormat.xlsx,
          _ExportFormat.pdf,
        ];
      case _ExportScope.classDetails:
        return const [_ExportFormat.pdf];
      case _ExportScope.allClasses:
        return const [_ExportFormat.csv, _ExportFormat.xlsx];
    }
  }

  void _updateScope(_ExportScope scope) {
    final formats = _availableFormatsForScope(scope);
    setState(() {
      _scope = scope;
      if (!formats.contains(_format)) {
        _format = formats.first;
      }
    });
  }

  Student? _selectedStudent(List<Student> students) {
    for (final student in students) {
      if (student.studentId == _selectedStudentId) {
        return student;
      }
    }
    return students.isEmpty ? null : students.first;
  }

  String _previewActionLabel() {
    if (_scope == _ExportScope.classDetails) {
      return 'Preview PDF';
    }
    return 'Preview ${_formatLabel(_format)}';
  }

  String _exportActionLabel() {
    if (_scope == _ExportScope.classDetails) {
      return 'Open PDF packet';
    }
    return 'Export ${_formatLabel(_format)}';
  }

  String _previewSummary() {
    switch (_scope) {
      case _ExportScope.perStudent:
        return _format == _ExportFormat.pdf
            ? 'Open the single-student PDF in a preview sheet before downloading.'
            : _format == _ExportFormat.csv
                ? 'Review the single-student spreadsheet layout before download.'
                : 'Spreadsheet preview is not available for XLSX.';
      case _ExportScope.perClass:
        return _format == _ExportFormat.pdf
            ? 'Open the class PDF in a review sheet before download.'
            : _format == _ExportFormat.csv
                ? 'Preview the full class table before downloading.'
                : 'Spreadsheet preview is not available for XLSX.';
      case _ExportScope.classDetails:
        return 'Preview the per-student packet before sharing or archiving it.';
      case _ExportScope.allClasses:
        return _format == _ExportFormat.csv
            ? 'Preview the combined roster export as a spreadsheet.'
            : 'All-classes preview is limited to CSV to keep large exports trustworthy.';
    }
  }

  String _deliverySummary() {
    switch (_scope) {
      case _ExportScope.perStudent:
        return 'Browser download for one student report in the selected format.';
      case _ExportScope.perClass:
        return _format == _ExportFormat.pdf
            ? 'Build a class PDF, then review it before downloading.'
            : 'Download the class export directly from the browser.';
      case _ExportScope.classDetails:
        return 'Build and review the detailed per-student packet before download.';
      case _ExportScope.allClasses:
        return 'Build one combined multi-class export without mutating the current class workspace.';
    }
  }

  Widget _buildContextStrip(
    BuildContext context, {
    required String className,
    required String classContextLine,
    required int studentCount,
    required int classCount,
    required Student? selectedStudent,
  }) {
    final statusAccent = _issues.isEmpty
        ? Theme.of(context).colorScheme.primary
        : const Color(0xFFDAA85E);
    return WorkspaceContextBar(
      title: className,
      subtitle: classContextLine,
      leading: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          WorkspaceContextPill(
            icon: Icons.summarize_outlined,
            label: 'Scope',
            value: _scopeLabel(_scope),
            emphasized: true,
          ),
          WorkspaceContextPill(
            icon: Icons.insert_drive_file_outlined,
            label: 'Format',
            value: _formatLabel(_format),
          ),
          WorkspaceContextPill(
            icon: _scope == _ExportScope.allClasses
                ? Icons.apartment_outlined
                : Icons.people_alt_outlined,
            label: _scope == _ExportScope.allClasses ? 'Coverage' : 'Roster',
            value: _scope == _ExportScope.allClasses
                ? (classCount > 0 ? '$classCount classes' : 'Across classes')
                : '$studentCount students',
          ),
          if (selectedStudent != null && _scope == _ExportScope.perStudent)
            WorkspaceContextPill(
              icon: Icons.person_outline_rounded,
              label: 'Student',
              value: selectedStudent.chineseName,
            ),
        ],
      ),
      trailing: WorkspaceContextPill(
        icon: _issues.isEmpty
            ? Icons.verified_outlined
            : Icons.warning_amber_rounded,
        label: _issues.isEmpty ? 'Status' : 'Issues',
        value: _issues.isEmpty ? 'Ready' : '${_issues.length} flagged',
        accent: statusAccent,
        emphasized: true,
      ),
    );
  }

  Widget _buildToolbar(
    BuildContext context, {
    required List<Student> students,
    required bool canPreview,
    required bool canExport,
  }) {
    final formats = _availableFormatsForScope(_scope);
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 220,
          child: _ToolbarDropdown<_ExportScope>(
            label: 'Report scope',
            value: _scope,
            items: const [
              DropdownMenuItem(
                value: _ExportScope.perStudent,
                child: Text('Per student'),
              ),
              DropdownMenuItem(
                value: _ExportScope.perClass,
                child: Text('Per class'),
              ),
              DropdownMenuItem(
                value: _ExportScope.classDetails,
                child: Text('Class details packet'),
              ),
              DropdownMenuItem(
                value: _ExportScope.allClasses,
                child: Text('All classes'),
              ),
            ],
            onChanged: (value) {
              if (value == null) return;
              _updateScope(value);
            },
          ),
        ),
        SizedBox(
          width: 220,
          child: _ToolbarDropdown<_ExportFormat>(
            label: 'Output format',
            value: _format,
            items: formats
                .map(
                  (format) => DropdownMenuItem<_ExportFormat>(
                    value: format,
                    child: Text(_formatLabel(format)),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() => _format = value);
            },
          ),
        ),
        if (_scope == _ExportScope.perStudent)
          SizedBox(
            width: 280,
            child: _ToolbarDropdown<String>(
              label: 'Student',
              value: _selectedStudentId,
              items: students
                  .map(
                    (student) => DropdownMenuItem<String>(
                      value: student.studentId,
                      child: Text(
                        '${student.chineseName} (${student.englishFullName})',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: students.isEmpty
                  ? null
                  : (value) => setState(() => _selectedStudentId = value),
            ),
          ),
        if (_scope == _ExportScope.perClass && _format == _ExportFormat.pdf)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .outline
                    .withValues(alpha: 0.28),
              ),
              color:
                  Theme.of(context).colorScheme.surface.withValues(alpha: 0.16),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'PDF layout',
                  style: context.textStyles.labelSmall?.semiBold,
                ),
                ChoiceChip(
                  label: const Text('One-page table'),
                  selected: _pdfClassAsTable,
                  onSelected: (_) => setState(() => _pdfClassAsTable = true),
                ),
                ChoiceChip(
                  label: const Text('Per-student pages'),
                  selected: !_pdfClassAsTable,
                  onSelected: (_) => setState(() => _pdfClassAsTable = false),
                ),
              ],
            ),
          ),
        OutlinedButton.icon(
          onPressed: canPreview ? _preview : null,
          icon: const Icon(Icons.visibility_outlined),
          label: Text(_previewActionLabel()),
          style: WorkspaceButtonStyles.outlined(context),
        ),
        FilledButton.icon(
          onPressed: canExport ? _export : null,
          icon: const Icon(Icons.download_outlined),
          label: Text(_exportActionLabel()),
          style: WorkspaceButtonStyles.filled(context),
        ),
      ],
    );
  }

  Widget _buildIssueCard(BuildContext context) {
    return WorkspaceSurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WorkspaceSectionHeader(
            title: 'Data issues to review',
            subtitle:
                'These checks affect report trust. Tap an item to jump to the source before exporting.',
            action: OutlinedButton.icon(
              onPressed: _calculateGrades,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Recheck'),
              style: WorkspaceButtonStyles.outlined(context, compact: true),
            ),
          ),
          const SizedBox(height: WorkspaceSpacing.md),
          ..._issues.take(10).map(
                (issue) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: WorkspaceSurfaceCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    radius: WorkspaceRadius.context,
                    onTap: () => _handleIssueTap(issue),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          issue.type == _IssueType.invalidCategoryWeights
                              ? Icons.rule_rounded
                              : Icons.assignment_late_outlined,
                          size: 18,
                          color: const Color(0xFFDAA85E),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            issue.message,
                            style: context.textStyles.bodyMedium,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Icon(
                          Icons.open_in_new_rounded,
                          size: 16,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          if (_issues.length > 10)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '${_issues.length - 10} more issue${_issues.length - 10 == 1 ? '' : 's'} remain hidden here.',
                style: WorkspaceTypography.metadata(context),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
            ),
            child: Icon(
              icon,
              size: 18,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: context.textStyles.labelLarge?.semiBold,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: WorkspaceTypography.metadata(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context, {
    required int studentCount,
    required int classCount,
    required Student? selectedStudent,
    required bool canPreview,
    required bool canExport,
  }) {
    final readyForAction = _issues.isEmpty;
    return WorkspaceSurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const WorkspaceSectionHeader(
            title: 'Report readiness',
            subtitle:
                'This pass keeps the report context visible before you preview or download anything.',
          ),
          const SizedBox(height: WorkspaceSpacing.md),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              WorkspaceContextPill(
                icon: Icons.assignment_outlined,
                label: 'Report',
                value: _reportTitle(),
                emphasized: true,
              ),
              WorkspaceContextPill(
                icon: Icons.visibility_outlined,
                label: 'Preview',
                value: canPreview ? 'Available' : 'Limited',
              ),
              WorkspaceContextPill(
                icon: Icons.download_outlined,
                label: 'Export',
                value: canExport ? 'Ready' : 'Blocked',
              ),
              if (selectedStudent != null && _scope == _ExportScope.perStudent)
                WorkspaceContextPill(
                  icon: Icons.badge_outlined,
                  label: 'Student ID',
                  value: selectedStudent.studentId,
                ),
            ],
          ),
          const SizedBox(height: WorkspaceSpacing.lg),
          _buildSummaryRow(
            context,
            icon: Icons.visibility_outlined,
            label: 'Preview flow',
            value: _previewSummary(),
          ),
          _buildSummaryRow(
            context,
            icon: Icons.download_outlined,
            label: 'Delivery',
            value: _deliverySummary(),
          ),
          _buildSummaryRow(
            context,
            icon: readyForAction
                ? Icons.verified_outlined
                : Icons.warning_amber_rounded,
            label: 'Trust check',
            value: readyForAction
                ? 'No blocking data issues were found in the current class review.'
                : 'Missing exam scores or invalid category weights are still visible before export.',
          ),
          if (_scope == _ExportScope.allClasses)
            _buildSummaryRow(
              context,
              icon: Icons.checklist_rtl_outlined,
              label: 'All-classes logic',
              value:
                  'This export now builds from repository snapshots per class so exam rows and category columns stay matched to the correct class.',
            ),
          if (_scope == _ExportScope.classDetails)
            const WorkspaceInlineState(
              icon: Icons.picture_as_pdf_outlined,
              title: 'Packet mode stays PDF only',
              subtitle:
                  'Class details always generates the detailed per-student packet to avoid mixed expectations.',
            ),
          if (_scope == _ExportScope.allClasses && _format == _ExportFormat.xlsx)
            const WorkspaceInlineState(
              icon: Icons.table_chart_outlined,
              title: 'Preview is CSV only for all classes',
              subtitle:
                  'Use CSV preview to validate the combined layout, then download XLSX if you need an Excel workbook.',
            ),
          if ((_scope == _ExportScope.perStudent ||
                  _scope == _ExportScope.perClass) &&
              _format == _ExportFormat.xlsx)
            const WorkspaceInlineState(
              icon: Icons.info_outline_rounded,
              title: 'Spreadsheet preview is limited',
              subtitle:
                  'CSV and PDF can be previewed here. XLSX downloads directly from the browser.',
            ),
          if (_scope == _ExportScope.allClasses)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Current workspace shows $classCount class${classCount == 1 ? '' : 'es'} and $studentCount student${studentCount == 1 ? '' : 's'} in the active class.',
                style: WorkspaceTypography.metadata(context),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final studentService = context.watch<StudentService>();
    final classService = context.watch<ClassService>();
    final classItem = classService.getClassById(widget.classId);
    final className = classItem?.className ?? 'Class';
    final studentCount = studentService.students.length;
    final knownClassCount = classService.classes.length;
    final classCount = knownClassCount > 0 ? knownClassCount : 1;
    final selectedStudent = _selectedStudent(studentService.students);
    final classContextParts = <String>[
      if (classItem?.subject.trim().isNotEmpty ?? false) classItem!.subject,
      if (classItem?.schoolYear.trim().isNotEmpty ?? false)
        classItem!.schoolYear,
      if (classItem?.term.trim().isNotEmpty ?? false) classItem!.term,
      '$studentCount student${studentCount == 1 ? '' : 's'}',
    ];
    final classContextLine = classContextParts.isEmpty
        ? 'Current class context'
        : classContextParts.join(' / ');
    final previewEnabled =
        !_isCalculating && _canPreview(studentCount: studentCount, classCount: classCount);
    final exportEnabled =
        !_isCalculating && _canExport(studentCount: studentCount, classCount: classCount);

    Widget workspace;
    if (_isCalculating) {
      workspace = const WorkspaceLoadingState(
        title: 'Checking report data',
        subtitle: 'Calculating grades and reviewing export readiness.',
      );
    } else if (_scope != _ExportScope.allClasses && studentCount == 0) {
      workspace = WorkspaceEmptyState(
        icon: Icons.group_outlined,
        title: 'No students in this class yet',
        subtitle:
            'Add students to this roster before generating student or class reports.',
        actions: [
          FilledButton.icon(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Back to class'),
            style: WorkspaceButtonStyles.filled(context),
          ),
        ],
      );
    } else {
      workspace = SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: WorkspaceSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_issues.isNotEmpty) ...[
              _buildIssueCard(context),
              const SizedBox(height: WorkspaceSpacing.md),
            ],
            _buildSummaryCard(
              context,
              studentCount: studentCount,
              classCount: classCount,
              selectedStudent: selectedStudent,
              canPreview: previewEnabled,
              canExport: exportEnabled,
            ),
          ],
        ),
      );
    }

    return ToolFirstAppSurface(
      title: _reportTitle(),
      eyebrow: 'Student Reporting',
      subtitle: _reportSubtitle(className: className, classCount: classCount),
      leading: IconButton(
        onPressed: () => context.pop(),
        tooltip: 'Back',
        style: WorkspaceButtonStyles.icon(context),
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      trailing: [
        IconButton(
          onPressed: _calculateGrades,
          tooltip: 'Refresh checks',
          style: WorkspaceButtonStyles.icon(context),
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      contextStrip: _buildContextStrip(
        context,
        className: className,
        classContextLine: classContextLine,
        studentCount: studentCount,
        classCount: classCount,
        selectedStudent: selectedStudent,
      ),
      toolbar: _buildToolbar(
        context,
        students: studentService.students,
        canPreview: previewEnabled,
        canExport: exportEnabled,
      ),
      workspace: workspace,
    );
  }
}

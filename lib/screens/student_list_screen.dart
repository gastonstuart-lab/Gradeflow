import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:gradeflow/components/workspace_shell.dart';
import 'package:gradeflow/services/auth_service.dart';
import 'package:gradeflow/services/student_service.dart';
import 'package:gradeflow/services/class_service.dart';
import 'package:gradeflow/services/grade_item_service.dart';
import 'package:gradeflow/theme.dart';
import 'package:gradeflow/services/file_import_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:gradeflow/models/student.dart';
import 'dart:convert';
import 'package:gradeflow/services/student_score_service.dart';
import 'package:gradeflow/services/final_exam_service.dart';
import 'package:gradeflow/services/student_trash_service.dart';
import 'package:gradeflow/models/deleted_student_entry.dart';
import 'package:flutter/services.dart';
import 'package:gradeflow/services/ai_import_service.dart';
import 'package:gradeflow/openai/openai_config.dart';
import 'package:gradeflow/nav.dart';

enum _SortBy { studentId, seat, chinese, english }

class StudentListScreen extends StatefulWidget {
  final String classId;

  const StudentListScreen({super.key, required this.classId});

  @override
  State<StudentListScreen> createState() => _StudentListScreenState();
}

class _StudentListScreenState extends State<StudentListScreen> {
  final FileImportService _importService = FileImportService();
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  _SortBy _sortBy = _SortBy.studentId;
  bool _ascending = true;
  bool _selectionMode = false;
  final Set<String> _selectedStudentIds = {};

  void _goToClassWorkspace() {
    context.go('${AppRoutes.osClass}/${widget.classId}');
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadStudents());
  }

  Future<void> _ensureClassContextLoaded() async {
    final classService = context.read<ClassService>();
    if (classService.getClassById(widget.classId) != null) return;

    final user = context.read<AuthService>().currentUser;
    if (user != null) {
      await classService.loadClasses(user.userId);
    }
  }

  Future<void> _loadStudents() async {
    await _ensureClassContextLoaded();
    await context.read<StudentService>().loadStudents(widget.classId);
  }

  Future<void> _showImportDialog() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'xlsx'],
      withData: true,
    );

    if (result != null && result.files.single.bytes != null && mounted) {
      final fileName = result.files.single.name;
      final bytes = result.files.single.bytes!;

      // First, detect what type of file this is
      final detection =
          _importService.detectFileType(bytes, filename: fileName);

      // If it's not a roster, show helpful message
      if (detection.type != ImportFileType.roster &&
          detection.type != ImportFileType.unknown) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Row(children: [
              Icon(Icons.info_outline,
                  color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              const Text('Wrong import location'),
            ]),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(detection.message,
                    style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lightbulb_outline,
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(detection.suggestion,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer,
                                )),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Got it'),
              ),
            ],
          ),
        );
        return;
      }

      final fileNameLower = fileName.toLowerCase();
      final imported = fileNameLower.endsWith('.xlsx')
          ? _importService.parseXlsxRoster(bytes)
          : _importService.parseCSV(_importService.decodeTextFromBytes(bytes));

      // Fallback: some ".xlsx" files are actually CSV; try CSV if XLSX yields nothing
      var parsed = (imported.isEmpty && fileNameLower.endsWith('.xlsx'))
          ? _importService.parseCSV(_importService.decodeTextFromBytes(bytes))
          : imported;

      if (parsed.isEmpty) {
        final diag = _importService.diagnosticsForFile(bytes,
            filename: result.files.single.name);
        final action = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Could not read this file'),
            content: SizedBox(
              width: 640,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                      'Tip: Re-export as CSV (UTF-8) or try the CSV version of the same file.'),
                  const SizedBox(height: 12),
                  Text('Diagnostics:',
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SingleChildScrollView(
                      child: Text(diag,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(fontFamily: 'monospace')),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, 'close'),
                  child: const Text('Close')),
              TextButton(
                onPressed: OpenAIConfig.isConfigured
                    ? () => Navigator.pop(ctx, 'ai')
                    : null,
                child: const Text('Analyze with AI'),
              ),
              TextButton(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: diag));
                  if (ctx.mounted) Navigator.pop(ctx, 'close');
                  _showSuccess('Copied diagnostics to clipboard');
                },
                child: const Text('Copy diagnostics'),
              ),
            ],
          ),
        );

        if (!mounted || action != 'ai') return;

        // Use AI to parse the roster
        final rows = _importService.rowsFromAnyBytes(bytes);

        // Show AI analysis dialog with AiAnalyzeImportDialog pattern
        final aiOutput = await showDialog<AiImportOutput>(
          context: context,
          builder: (ctx) {
            // Wrap inferFromRows to return proper format
            return FutureBuilder<AiImportOutput?>(
              future: AiImportService()
                  .inferFromRows(rows, filename: result.files.single.name),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const AlertDialog(
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(height: 8),
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Analyzing student roster with AI…'),
                      ],
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return AlertDialog(
                    title: const Text('AI Analysis Failed'),
                    content: Text(snapshot.error.toString()),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Close'),
                      ),
                    ],
                  );
                }

                final aiOutput = snapshot.data;
                if (aiOutput == null) {
                  return AlertDialog(
                    title: const Text('No Results'),
                    content: const Text('AI did not return any data.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Close'),
                      ),
                    ],
                  );
                }

                // Convert to ImportedStudent list
                final aiStudents = <ImportedStudent>[];
                for (final entry in aiOutput.byClass.entries) {
                  aiStudents.addAll(entry.value);
                }

                final valid = aiStudents.where((s) => s.isValid).toList();
                final invalid = aiStudents.where((s) => !s.isValid).toList();

                return AlertDialog(
                  title: const Text('AI Analysis Complete'),
                  content: SizedBox(
                    width: 600,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.check_circle,
                                color: Theme.of(context).colorScheme.primary,
                                size: 20),
                            const SizedBox(width: 8),
                            Text('Valid students: ${valid.length}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                        if (invalid.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.warning,
                                  color: Theme.of(context).colorScheme.error,
                                  size: 20),
                              const SizedBox(width: 8),
                              Text('Issues: ${invalid.length}',
                                  style: TextStyle(
                                      color:
                                          Theme.of(context).colorScheme.error,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ],
                        if (valid.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          const Divider(),
                          const SizedBox(height: 8),
                          const Text('Sample (first 3):',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          ...valid.take(3).map((s) => Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  children: [
                                    const Icon(Icons.person, size: 16),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        "${s.chineseName} (${s.englishFirstName} ${s.englishLastName})${s.seatNo != null ? '  • Seat ${s.seatNo}' : ''}",
                                        style: const TextStyle(fontSize: 13),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              )),
                        ],
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: valid.isEmpty
                          ? null
                          : () => Navigator.pop(ctx, aiOutput),
                      child: const Text('Import students'),
                    ),
                  ],
                );
              },
            );
          },
        );

        if (!mounted || aiOutput == null) return;

        // Convert AI output to ImportedStudent list
        final aiStudents = <ImportedStudent>[];
        for (final entry in aiOutput.byClass.entries) {
          aiStudents.addAll(entry.value);
        }

        if (aiStudents.isEmpty) {
          _showError('AI did not return any students.');
          return;
        }

        // Replace parsed with AI result and continue with normal flow
        parsed = aiStudents;
      }

      final valid = parsed.where((s) => s.isValid).toList();
      final invalid = parsed.where((s) => !s.isValid).toList();

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              const Text('Import Preview'),
              const Spacer(),
              if (valid.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${valid.length} ready',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
            ],
          ),
          content: SizedBox(
            width: 600,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.check_circle,
                        color: Theme.of(context).colorScheme.primary, size: 20),
                    const SizedBox(width: 8),
                    Text('Valid students: ${valid.length}',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
                if (invalid.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.warning,
                          color: Theme.of(context).colorScheme.error, size: 20),
                      const SizedBox(width: 8),
                      Text('Invalid students: ${invalid.length}',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
                if (valid.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  const Divider(),
                  const SizedBox(height: AppSpacing.sm),
                  Text('Sample (first 3):',
                      style: context.textStyles.labelLarge),
                  const SizedBox(height: 8),
                  ...valid.take(3).map((s) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            const Icon(Icons.person, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "${s.chineseName} (${s.englishFirstName} ${s.englishLastName})${s.seatNo != null ? '  • Seat ${s.seatNo}' : ''}",
                                style: context.textStyles.bodySmall,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
                if (invalid.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  const Divider(),
                  const SizedBox(height: AppSpacing.sm),
                  Text('Errors:',
                      style: context.textStyles.labelLarge?.copyWith(
                          color: Theme.of(context).colorScheme.error)),
                  const SizedBox(height: 8),
                  ...invalid.take(5).map((s) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('• ${s.error}',
                            style: context.textStyles.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.error)),
                      )),
                  if (invalid.length > 5)
                    Text('... and ${invalid.length - 5} more errors',
                        style: context.textStyles.bodySmall),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            if (valid.isNotEmpty)
              FilledButton(
                onPressed: () async {
                  final nav = Navigator.of(context);
                  final students =
                      _importService.convertToStudents(valid, widget.classId);
                  await context.read<StudentService>().addStudents(students);
                  if (!mounted) return;
                  nav.pop();
                  _showSuccess(
                      'Imported ${students.length} Student${students.length == 1 ? '' : 's'}');
                },
                child: Text(
                    'Import ${valid.length} Student${valid.length == 1 ? '' : 's'}'),
              ),
          ],
        ),
      );
    }
  }

  Future<void> _showPasteImportDialog() async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Paste Roster'),
        content: SizedBox(
          width: 600,
          child: TextField(
            controller: controller,
            maxLines: 12,
            decoration: const InputDecoration(
              hintText:
                  'Paste rows here (headers in first row). Use tabs or commas between columns.',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Preview')),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      final raw = controller.text.trim();
      if (raw.isEmpty) return;
      // Normalize to CSV string: if tabs present, replace with commas
      final csvLike = raw.contains('\t') ? raw.replaceAll('\t', ',') : raw;
      final imported = _importService.parseCSV(csvLike);
      if (imported.isEmpty) {
        _showError('Nothing detected. Make sure the first row has headers.');
        return;
      }
      final valid = imported.where((s) => s.isValid).toList();
      final invalid = imported.where((s) => !s.isValid).toList();
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Import Preview'),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Valid students: ${valid.length}'),
                Text('Invalid students: ${invalid.length}',
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
                if (invalid.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text('Errors:', style: context.textStyles.titleSmall),
                  ...invalid.take(3).map((s) => Text('• ${s.error}',
                      style: context.textStyles.bodySmall)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final students =
                    _importService.convertToStudents(valid, widget.classId);
                await context.read<StudentService>().addStudents(students);
                if (context.mounted) {
                  Navigator.pop(context);
                  _showSuccess('Imported ${students.length} students');
                }
              },
              child: const Text('Import Valid Students'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _showAddStudentDialog() async {
    final studentIdController = TextEditingController();
    final chineseNameController = TextEditingController();
    final firstNameController = TextEditingController();
    final lastNameController = TextEditingController();
    final seatNoController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Student'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: studentIdController,
                  decoration: const InputDecoration(labelText: 'Student ID *')),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                  controller: chineseNameController,
                  decoration:
                      const InputDecoration(labelText: 'Chinese Name *')),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                  controller: firstNameController,
                  decoration:
                      const InputDecoration(labelText: 'English First Name *')),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                  controller: lastNameController,
                  decoration:
                      const InputDecoration(labelText: 'English Last Name *')),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                  controller: seatNoController,
                  decoration: const InputDecoration(labelText: 'Seat Number')),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Add')),
        ],
      ),
    );

    if (result == true && mounted) {
      if (studentIdController.text.isEmpty ||
          chineseNameController.text.isEmpty ||
          firstNameController.text.isEmpty ||
          lastNameController.text.isEmpty) {
        _showError('Please fill in all required fields');
        return;
      }

      final now = DateTime.now();
      final student = Student(
        studentId: studentIdController.text,
        chineseName: chineseNameController.text,
        englishFirstName: firstNameController.text,
        englishLastName: lastNameController.text,
        seatNo: seatNoController.text.isEmpty ? null : seatNoController.text,
        photoBase64: null,
        classId: widget.classId,
        createdAt: now,
        updatedAt: now,
      );

      await context.read<StudentService>().addStudent(student);

      // Default all non-exam grade items to full marks for the new student.
      final gradeItemSvc = context.read<GradeItemService>();
      if (gradeItemSvc.gradeItems.isEmpty) {
        await gradeItemSvc.loadGradeItems(widget.classId);
      }
      final scoreSvc = context.read<StudentScoreService>();
      for (final item in gradeItemSvc.gradeItems) {
        await scoreSvc.ensureDefaultScoresForGradeItem(
          widget.classId,
          item.gradeItemId,
          [student.studentId],
          item.maxScore,
        );
      }

      _showSuccess('Student added successfully');
    }
  }

  Future<void> _showEditStudentDialog(Student student) async {
    final chineseNameController =
        TextEditingController(text: student.chineseName);
    final firstNameController =
        TextEditingController(text: student.englishFirstName);
    final lastNameController =
        TextEditingController(text: student.englishLastName);
    final seatNoController = TextEditingController(text: student.seatNo ?? '');
    final classCodeController =
        TextEditingController(text: student.classCode ?? '');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Student'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  enabled: false,
                  decoration: const InputDecoration(labelText: 'Student ID'),
                  controller: TextEditingController(text: student.studentId)),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                  controller: chineseNameController,
                  decoration:
                      const InputDecoration(labelText: 'Chinese Name *')),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                  controller: firstNameController,
                  decoration:
                      const InputDecoration(labelText: 'English First Name *')),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                  controller: lastNameController,
                  decoration:
                      const InputDecoration(labelText: 'English Last Name *')),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                  controller: seatNoController,
                  decoration: const InputDecoration(labelText: 'Seat Number')),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                  controller: classCodeController,
                  decoration: const InputDecoration(labelText: 'Class Code')),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Update')),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      if (chineseNameController.text.isEmpty ||
          firstNameController.text.isEmpty ||
          lastNameController.text.isEmpty) {
        _showError('Please fill in all required fields');
        return;
      }
      final updated = student.copyWith(
        chineseName: chineseNameController.text.trim(),
        englishFirstName: firstNameController.text.trim(),
        englishLastName: lastNameController.text.trim(),
        seatNo: seatNoController.text.trim().isEmpty
            ? null
            : seatNoController.text.trim(),
        classCode: classCodeController.text.trim().isEmpty
            ? null
            : classCodeController.text.trim(),
        updatedAt: DateTime.now(),
      );
      await context.read<StudentService>().updateStudent(updated);
      _showSuccess('Student updated');
    }
  }

  Future<void> _confirmBatchDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete selected students?'),
        content: Text(
            'This will move ${_selectedStudentIds.length} student(s) to the Restore Bin. You can restore them later if needed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final studentSvc = context.read<StudentService>();
    final gradeItemSvc = context.read<GradeItemService>();
    final scoreSvc = context.read<StudentScoreService>();
    final examSvc = context.read<FinalExamService>();
    final trashSvc = context.read<StudentTrashService>();

    if (gradeItemSvc.gradeItems.isEmpty) {
      await gradeItemSvc.loadGradeItems(widget.classId);
    }
    final gradeItemIds =
        gradeItemSvc.gradeItems.map((g) => g.gradeItemId).toList();

    for (final studentId in _selectedStudentIds) {
      // Find the student; if not found, skip
      late final Student student;
      try {
        student =
            studentSvc.students.firstWhere((s) => s.studentId == studentId);
      } catch (_) {
        continue;
      }

      // Backup related data, then remove
      final removedScores = await scoreSvc.removeAndReturnScoresForStudent(
          widget.classId, studentId, gradeItemIds);
      final removedExam = await examSvc.removeAndReturnExamForStudent(
          widget.classId, studentId);

      final entry = DeletedStudentEntry(
        student: student,
        scores: removedScores,
        exam: removedExam,
        deletedAt: DateTime.now(),
        reason: 'Batch delete from roster',
      );

      await trashSvc.addToTrash(entry);
      await studentSvc.deleteStudent(studentId);
    }

    setState(() {
      _selectedStudentIds.clear();
      _selectionMode = false;
    });

    _showSuccess('Students moved to Restore Bin');
  }

  Future<void> _confirmDeleteStudent(Student student) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Student'),
        content: Text(
            'Remove ${student.chineseName} (${student.englishFullName}) from this class? This will also clear their scores and exam entry.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      final sid = student.studentId;
      final studentSvc = context.read<StudentService>();
      final gradeItemSvc = context.read<GradeItemService>();
      final scoreSvc = context.read<StudentScoreService>();
      final examSvc = context.read<FinalExamService>();
      final trashSvc = context.read<StudentTrashService>();

      if (gradeItemSvc.gradeItems.isEmpty) {
        await gradeItemSvc.loadGradeItems(widget.classId);
      }
      final gradeItemIds =
          gradeItemSvc.gradeItems.map((g) => g.gradeItemId).toList();

      // Backup related data, then remove
      final removedScores = await scoreSvc.removeAndReturnScoresForStudent(
          widget.classId, sid, gradeItemIds);
      final removedExam =
          await examSvc.removeAndReturnExamForStudent(widget.classId, sid);
      await studentSvc.deleteStudent(sid);

      // Save to Restore Bin
      await trashSvc.addToTrash(DeletedStudentEntry(
        student: student,
        scores: removedScores,
        exam: removedExam,
        deletedAt: DateTime.now(),
        reason: 'Manual delete from roster',
      ));

      if (!context.mounted) return;
      _showFeedback(
        'Removed ${student.chineseName} (${student.englishFullName})',
        tone: WorkspaceFeedbackTone.warning,
        actionLabel: 'Undo',
        duration: const Duration(seconds: 6),
        onAction: () async {
          try {
            await studentSvc.addStudent(student);
            if (removedScores.isNotEmpty) {
              await scoreSvc.restoreScoresForStudent(
                  widget.classId, removedScores);
            }
            if (removedExam != null) {
              await examSvc.restoreExam(widget.classId, removedExam);
            }
            await trashSvc.removeFromTrash(sid);
            if (mounted) _showSuccess('Student restored');
          } catch (e) {
            debugPrint('Failed to undo student removal: $e');
            if (mounted) _showError('Could not undo removal');
          }
        },
      );
    }
  }

  void _showError(String message) => _showFeedback(
        message,
        tone: WorkspaceFeedbackTone.error,
        title: 'Roster issue',
      );

  void _showSuccess(String message) => _showFeedback(
        message,
        tone: WorkspaceFeedbackTone.success,
      );

  int _compareStudents(Student left, Student right) {
    int cmp;
    switch (_sortBy) {
      case _SortBy.studentId:
        cmp = _compareStudentIds(left, right);
        break;
      case _SortBy.seat:
        cmp = _compareSeatNumbers(left.seatNo, right.seatNo);
        if (cmp == 0) {
          cmp = _compareStudentIds(left, right);
        }
        break;
      case _SortBy.chinese:
        cmp = left.chineseName
            .toLowerCase()
            .compareTo(right.chineseName.toLowerCase());
        if (cmp == 0) {
          cmp = _compareStudentIds(left, right);
        }
        break;
      case _SortBy.english:
        cmp = left.englishFullName
            .toLowerCase()
            .compareTo(right.englishFullName.toLowerCase());
        if (cmp == 0) {
          cmp = _compareStudentIds(left, right);
        }
        break;
    }

    return _ascending ? cmp : -cmp;
  }

  int _compareStudentIds(Student left, Student right) {
    final idCompare = _naturalCompare(
      left.studentId.toLowerCase(),
      right.studentId.toLowerCase(),
    );
    if (idCompare != 0) return idCompare;

    final chineseCompare = left.chineseName
        .toLowerCase()
        .compareTo(right.chineseName.toLowerCase());
    if (chineseCompare != 0) return chineseCompare;

    return left.englishFullName
        .toLowerCase()
        .compareTo(right.englishFullName.toLowerCase());
  }

  int _compareSeatNumbers(String? leftSeat, String? rightSeat) {
    final leftValue = leftSeat?.trim() ?? '';
    final rightValue = rightSeat?.trim() ?? '';
    if (leftValue.isEmpty && rightValue.isEmpty) return 0;
    if (leftValue.isEmpty) return 1;
    if (rightValue.isEmpty) return -1;
    return _naturalCompare(leftValue.toLowerCase(), rightValue.toLowerCase());
  }

  int _naturalCompare(String left, String right) {
    final leftParts = RegExp(r'\d+|\D+')
        .allMatches(left)
        .map((match) => match.group(0)!)
        .toList();
    final rightParts = RegExp(r'\d+|\D+')
        .allMatches(right)
        .map((match) => match.group(0)!)
        .toList();
    final limit = leftParts.length < rightParts.length
        ? leftParts.length
        : rightParts.length;

    for (int i = 0; i < limit; i++) {
      final leftPart = leftParts[i];
      final rightPart = rightParts[i];
      final leftNumber = int.tryParse(leftPart);
      final rightNumber = int.tryParse(rightPart);
      final compare = leftNumber != null && rightNumber != null
          ? leftNumber.compareTo(rightNumber)
          : leftPart.compareTo(rightPart);
      if (compare != 0) return compare;
    }

    return leftParts.length.compareTo(rightParts.length);
  }

  String _sortLabel() {
    switch (_sortBy) {
      case _SortBy.studentId:
        return 'Student ID';
      case _SortBy.seat:
        return 'Seat';
      case _SortBy.chinese:
        return 'Chinese';
      case _SortBy.english:
        return 'English';
    }
  }

  Widget _buildContextBar(
    BuildContext context, {
    required String className,
    required String classContextLine,
    required int rosterCount,
    required int visibleCount,
  }) {
    return WorkspaceContextBar(
      title: className,
      subtitle: classContextLine,
      leading: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          WorkspaceContextPill(
            icon: Icons.people_alt_outlined,
            label: 'Roster',
            value: '$rosterCount students',
            emphasized: true,
          ),
          WorkspaceContextPill(
            icon: Icons.filter_list_outlined,
            label: 'Visible',
            value: '$visibleCount shown',
          ),
          WorkspaceContextPill(
            icon: Icons.sort_outlined,
            label: 'Sort',
            value: '${_sortLabel()} ${_ascending ? 'up' : 'down'}',
          ),
        ],
      ),
      trailing: WorkspaceContextPill(
        icon: _selectionMode ? Icons.checklist_rtl : Icons.person_add_alt_1,
        label: _selectionMode ? 'Selection' : 'Mode',
        value: _selectionMode
            ? '${_selectedStudentIds.length} selected'
            : 'Browse',
        accent: _selectionMode
            ? const Color(0xFFDAA85E)
            : Theme.of(context).colorScheme.primary,
        emphasized: true,
      ),
    );
  }

  Widget _buildRosterToolbar(BuildContext context) {
    return WorkspaceSurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const WorkspaceSectionHeader(
            title: 'Roster controls',
            subtitle:
                'Search, sort, and scan the current class roster without leaving the workspace shell.',
          ),
          const SizedBox(height: WorkspaceSpacing.md),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    hintText: 'Search by name, ID, seat, or class code',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _query = '');
                            },
                          ),
                  ),
                ),
              ),
              const SizedBox(width: WorkspaceSpacing.sm),
              PopupMenuButton<String>(
                tooltip: 'Sort',
                icon: const Icon(Icons.sort),
                onSelected: (value) {
                  setState(() {
                    if (value == 'studentId') _sortBy = _SortBy.studentId;
                    if (value == 'seat') _sortBy = _SortBy.seat;
                    if (value == 'chinese') _sortBy = _SortBy.chinese;
                    if (value == 'english') _sortBy = _SortBy.english;
                  });
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'studentId',
                    child: Text('Student ID'),
                  ),
                  PopupMenuItem(
                    value: 'seat',
                    child: Text('Seat number'),
                  ),
                  PopupMenuItem(
                    value: 'chinese',
                    child: Text('Chinese name'),
                  ),
                  PopupMenuItem(
                    value: 'english',
                    child: Text('English name'),
                  ),
                ],
              ),
              IconButton(
                tooltip: _ascending ? 'Ascending' : 'Descending',
                onPressed: () => setState(() => _ascending = !_ascending),
                style: WorkspaceButtonStyles.icon(context),
                icon: Icon(
                  _ascending
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStudentRow(
    BuildContext context, {
    required Student student,
    required bool isSelected,
  }) {
    final metadataParts = <String>['ID: ${student.studentId}'];
    if (student.seatNo?.isNotEmpty ?? false) {
      metadataParts.add('Seat: ${student.seatNo}');
    }
    if (student.classCode?.isNotEmpty ?? false) {
      metadataParts.add('Class: ${student.classCode}');
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: WorkspaceSpacing.sm),
      child: WorkspaceSurfaceCard(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        onTap: _selectionMode
            ? () => setState(() {
                  if (isSelected) {
                    _selectedStudentIds.remove(student.studentId);
                  } else {
                    _selectedStudentIds.add(student.studentId);
                  }
                })
            : () => context
                .push('/class/${widget.classId}/student/${student.studentId}'),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_selectionMode)
              Checkbox(
                value: isSelected,
                onChanged: (checked) => setState(() {
                  if (checked == true) {
                    _selectedStudentIds.add(student.studentId);
                  } else {
                    _selectedStudentIds.remove(student.studentId);
                  }
                }),
              )
            else
              _StudentAvatar(
                photoBase64: student.photoBase64,
                fallbackLetter: student.englishFirstName[0],
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student.chineseName,
                    style: context.textStyles.titleMedium?.semiBold,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    student.englishFullName,
                    style: WorkspaceTypography.metadata(context),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    metadataParts.join(' / '),
                    style: context.textStyles.labelSmall?.withColor(
                      Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (!_selectionMode)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PopupMenuButton<String>(
                    tooltip: 'More',
                    onSelected: (value) {
                      if (value == 'edit') {
                        _showEditStudentDialog(student);
                      }
                      if (value == 'delete') {
                        _confirmDeleteStudent(student);
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'edit',
                        child: Text('Edit'),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete'),
                      ),
                    ],
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final studentService = context.watch<StudentService>();
    final classService = context.watch<ClassService>();
    final classItem = classService.getClassById(widget.classId);

    List<Student> list = List.of(studentService.students);
    if (_query.trim().isNotEmpty) {
      final q = _query.toLowerCase();
      list = list
          .where((s) =>
              s.chineseName.toLowerCase().contains(q) ||
              s.englishFullName.toLowerCase().contains(q) ||
              s.studentId.toLowerCase().contains(q) ||
              (s.seatNo?.toLowerCase().contains(q) ?? false) ||
              (s.classCode?.toLowerCase().contains(q) ?? false))
          .toList();
    }
    list.sort(_compareStudents);

    final rosterCount = studentService.students.length;
    final classContextParts = <String>[
      if (classItem?.subject.trim().isNotEmpty ?? false) classItem!.subject,
      if (classItem?.schoolYear.trim().isNotEmpty ?? false)
        classItem!.schoolYear,
      if (classItem?.term.trim().isNotEmpty ?? false) classItem!.term,
      '$rosterCount student${rosterCount == 1 ? '' : 's'}',
    ];
    final classContextLine = classContextParts.isEmpty
        ? 'Current class context'
        : classContextParts.join(' / ');

    return WorkspaceScaffold(
      title: _selectionMode
          ? '${_selectedStudentIds.length} selected'
          : 'Students',
      subtitle: _selectionMode
          ? 'Bulk actions for the current roster selection'
          : 'Roster for ${classItem?.className ?? 'this class'}',
      eyebrow: 'Class Roster',
      contextBar: _buildContextBar(
        context,
        className: classItem?.className ?? 'Class',
        classContextLine: classContextLine,
        rosterCount: rosterCount,
        visibleCount: list.length,
      ),
      leadingActions: [
        IconButton(
          icon: Icon(_selectionMode ? Icons.close : Icons.arrow_back_rounded),
          tooltip: _selectionMode
              ? 'Exit selection mode'
              : 'Back to class workspace',
          style: WorkspaceButtonStyles.icon(context),
          onPressed: () {
            if (_selectionMode) {
              setState(() {
                _selectionMode = false;
                _selectedStudentIds.clear();
              });
              return;
            }
            _goToClassWorkspace();
          },
        ),
      ],
      trailingActions: _selectionMode
          ? [
              IconButton(
                icon: const Icon(Icons.select_all),
                tooltip: _selectedStudentIds.length == list.length
                    ? 'Deselect all'
                    : 'Select all',
                style: WorkspaceButtonStyles.icon(context),
                onPressed: () => setState(() {
                  if (_selectedStudentIds.length == list.length) {
                    _selectedStudentIds.clear();
                  } else {
                    _selectedStudentIds.addAll(list.map((s) => s.studentId));
                  }
                }),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Delete selected',
                style: WorkspaceButtonStyles.icon(context),
                onPressed:
                    _selectedStudentIds.isEmpty ? null : _confirmBatchDelete,
              ),
            ]
          : [
              IconButton(
                icon: const Icon(Icons.checklist),
                tooltip: 'Select multiple',
                style: WorkspaceButtonStyles.icon(context),
                onPressed: () => setState(() => _selectionMode = true),
              ),
              IconButton(
                icon: const Icon(Icons.upload_file),
                tooltip: 'Import from CSV or Excel',
                style: WorkspaceButtonStyles.icon(context),
                onPressed: _showImportDialog,
              ),
              IconButton(
                icon: const Icon(Icons.paste),
                tooltip: 'Paste from spreadsheet',
                style: WorkspaceButtonStyles.icon(context),
                onPressed: _showPasteImportDialog,
              ),
              IconButton(
                icon: const Icon(Icons.restore_from_trash),
                tooltip: 'Restore Bin',
                style: WorkspaceButtonStyles.icon(context),
                onPressed: () =>
                    context.push('/class/${widget.classId}/students/trash'),
              ),
            ],
      floatingActionButton:
          studentService.students.isNotEmpty && !_selectionMode
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: FloatingActionButton(
                    onPressed: _showAddStudentDialog,
                    child: const Icon(Icons.add),
                  ),
                )
              : null,
      child: studentService.isLoading
          ? const WorkspaceLoadingState(
              title: 'Loading roster',
              subtitle: 'Bringing the current class roster into view.',
            )
          : studentService.students.isEmpty
              ? WorkspaceEmptyState(
                  icon: Icons.people_outline_rounded,
                  title: 'No students yet',
                  subtitle:
                      'Add students manually or import a roster to start building this class workspace.',
                  actions: [
                    FilledButton.icon(
                      onPressed: _showAddStudentDialog,
                      icon: const Icon(Icons.add),
                      label: const Text('Add student'),
                      style: WorkspaceButtonStyles.filled(context),
                    ),
                  ],
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: WorkspaceSpacing.md),
                  itemCount: list.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Padding(
                        padding:
                            const EdgeInsets.only(bottom: WorkspaceSpacing.sm),
                        child: _buildRosterToolbar(context),
                      );
                    }
                    final student = list[index - 1];
                    final isSelected =
                        _selectedStudentIds.contains(student.studentId);
                    return _buildStudentRow(
                      context,
                      student: student,
                      isSelected: isSelected,
                    );
                  },
                ),
    );
  }
}

class _StudentAvatar extends StatelessWidget {
  final String? photoBase64;
  final String fallbackLetter;
  const _StudentAvatar(
      {required this.photoBase64, required this.fallbackLetter});

  @override
  Widget build(BuildContext context) {
    if (photoBase64 != null && photoBase64!.isNotEmpty) {
      try {
        return CircleAvatar(
            backgroundImage:
                MemoryImage(const Base64Decoder().convert(photoBase64!)));
      } catch (_) {
        // ignore and fall back to letter
      }
    }
    return CircleAvatar(
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      child: Text(fallbackLetter,
          style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimaryContainer)),
    );
  }
}

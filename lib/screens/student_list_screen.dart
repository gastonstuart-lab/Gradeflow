import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:gradeflow/services/student_service.dart';
import 'package:gradeflow/services/class_service.dart';
import 'package:gradeflow/services/grade_item_service.dart';
import 'package:gradeflow/theme.dart';
import 'package:gradeflow/components/animated_glow_border.dart';
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

enum _SortBy { seat, chinese, english }

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
  _SortBy _sortBy = _SortBy.seat;
  bool _ascending = true;
  bool _selectionMode = false;
  final Set<String> _selectedStudentIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadStudents());
  }

  Future<void> _loadStudents() async {
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
      final detection = _importService.detectFileType(bytes, filename: fileName);
      
      // If it's not a roster, show helpful message
      if (detection.type != ImportFileType.roster && detection.type != ImportFileType.unknown) {
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
                        color: Theme.of(context).colorScheme.onPrimaryContainer),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(detection.suggestion,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
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
        
        // Show loading dialog
        if (!mounted) return;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => const AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Analyzing with AI…'),
              ],
            ),
          ),
        );
        
        AiImportOutput? aiResult;
        try {
          aiResult = await AiImportService().inferFromRows(rows, filename: result.files.single.name);
        } catch (e) {
          if (mounted) Navigator.pop(context); // Close loading dialog
          _showError('AI analysis failed: $e');
          return;
        }
        
        if (mounted) Navigator.pop(context); // Close loading dialog
        if (!mounted || aiResult == null) return;
        
        // Convert AI output to ImportedStudent list
        final aiStudents = <ImportedStudent>[];
        for (final entry in aiResult.byClass.entries) {
          aiStudents.addAll(entry.value);
        }
        
        if (aiStudents.isEmpty) {
          _showError('AI did not return any students.');
          return;
        }
        
        // Show AI result for confirmation
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('AI Analysis Complete'),
            content: Text('AI found ${aiStudents.where((s) => s.isValid).length} valid students. Import them?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Import'),
              ),
            ],
          ),
        );
        
        if (!mounted || confirm != true) return;
        
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

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Students moved to Restore Bin')),
      );
    }
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

      // Offer UNDO
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Removed ${student.chineseName} (${student.englishFullName})'),
          action: SnackBarAction(
            label: 'UNDO',
            onPressed: () async {
              try {
                await studentSvc.addStudent(student);
                if (removedScores.isNotEmpty) {
                  await scoreSvc.restoreScoresForStudent(
                      widget.classId, removedScores);
                }
                if (removedExam != null) {
                  await examSvc.restoreExam(widget.classId, removedExam);
                }
                // Also remove from bin since user undid it
                await trashSvc.removeFromTrash(sid);
                if (mounted) _showSuccess('Student restored');
              } catch (e) {
                debugPrint('Failed to undo student removal: $e');
                if (mounted) _showError('Could not undo removal');
              }
            },
          ),
          duration: const Duration(seconds: 6),
        ),
      );
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final studentService = context.watch<StudentService>();
    final classService = context.watch<ClassService>();
    final classItem = classService.getClassById(widget.classId);

    // Apply search + sort
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
    int seatAsInt(String? v) =>
        int.tryParse(v ?? '') ?? 1 << 30; // push empties to end
    list.sort((a, b) {
      int cmp;
      switch (_sortBy) {
        case _SortBy.seat:
          cmp = seatAsInt(a.seatNo).compareTo(seatAsInt(b.seatNo));
          break;
        case _SortBy.chinese:
          cmp = a.chineseName
              .toLowerCase()
              .compareTo(b.chineseName.toLowerCase());
          break;
        case _SortBy.english:
          cmp = a.englishFullName
              .toLowerCase()
              .compareTo(b.englishFullName.toLowerCase());
          break;
      }
      return _ascending ? cmp : -cmp;
    });

    return Scaffold(
      appBar: AppBar(
        title: _selectionMode
            ? Text('${_selectedStudentIds.length} selected')
            : Text('Students - ${classItem?.className ?? ""}'),
        leading: _selectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() {
                  _selectionMode = false;
                  _selectedStudentIds.clear();
                }),
              )
            : null,
        actions: _selectionMode
            ? [
                IconButton(
                  icon: const Icon(Icons.select_all),
                  onPressed: () => setState(() {
                    if (_selectedStudentIds.length == list.length) {
                      _selectedStudentIds.clear();
                    } else {
                      _selectedStudentIds.addAll(list.map((s) => s.studentId));
                    }
                  }),
                  tooltip: _selectedStudentIds.length == list.length
                      ? 'Deselect all'
                      : 'Select all',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed:
                      _selectedStudentIds.isEmpty ? null : _confirmBatchDelete,
                  tooltip: 'Delete selected',
                ),
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.checklist),
                  onPressed: () => setState(() => _selectionMode = true),
                  tooltip: 'Select multiple',
                ),
                IconButton(
                  icon: const Icon(Icons.upload_file),
                  onPressed: _showImportDialog,
                  tooltip: 'Import from CSV or Excel',
                ),
                IconButton(
                  icon: const Icon(Icons.paste),
                  onPressed: _showPasteImportDialog,
                  tooltip: 'Paste from spreadsheet',
                ),
                IconButton(
                  icon: const Icon(Icons.restore_from_trash),
                  onPressed: () =>
                      context.push('/class/${widget.classId}/students/trash'),
                  tooltip: 'Restore Bin',
                ),
              ],
      ),
      body: studentService.isLoading
          ? const Center(child: CircularProgressIndicator())
          : studentService.students.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline,
                          size: 64,
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant),
                      const SizedBox(height: AppSpacing.md),
                      Text('No students yet',
                          style: context.textStyles.titleLarge),
                      const SizedBox(height: AppSpacing.sm),
                      Text('Add students manually or import from CSV/Excel',
                          style: context.textStyles.bodyMedium),
                      const SizedBox(height: AppSpacing.lg),
                      FilledButton.icon(
                        onPressed: _showAddStudentDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Student'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: AppSpacing.paddingMd,
                  itemCount: list.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: Padding(
                          padding: AppSpacing.paddingMd,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Expanded(
                                  child: TextField(
                                    controller: _searchCtrl,
                                    onChanged: (v) =>
                                        setState(() => _query = v),
                                    decoration: InputDecoration(
                                      hintText:
                                          'Search by name, ID, seat, class...',
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
                                const SizedBox(width: AppSpacing.sm),
                                PopupMenuButton<String>(
                                  tooltip: 'Sort',
                                  icon: const Icon(Icons.sort),
                                  onSelected: (v) {
                                    setState(() {
                                      if (v == 'seat') _sortBy = _SortBy.seat;
                                      if (v == 'chinese') {
                                        _sortBy = _SortBy.chinese;
                                      }
                                      if (v == 'english') {
                                        _sortBy = _SortBy.english;
                                      }
                                    });
                                  },
                                  itemBuilder: (context) => const [
                                    PopupMenuItem(
                                        value: 'seat',
                                        child: Text('Seat number')),
                                    PopupMenuItem(
                                        value: 'chinese',
                                        child: Text('Chinese name')),
                                    PopupMenuItem(
                                        value: 'english',
                                        child: Text('English name')),
                                  ],
                                ),
                                IconButton(
                                  tooltip:
                                      _ascending ? 'Ascending' : 'Descending',
                                  onPressed: () =>
                                      setState(() => _ascending = !_ascending),
                                  icon: Icon(_ascending
                                      ? Icons.arrow_upward
                                      : Icons.arrow_downward),
                                ),
                              ]),
                            ],
                          ),
                        ),
                      );
                    }
                    final student = list[index - 1];
                    final isSelected =
                        _selectedStudentIds.contains(student.studentId);
                    return AnimatedGlowBorder(
                      child: Card(
                        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: ListTile(
                          leading: _selectionMode
                              ? Checkbox(
                                  value: isSelected,
                                  onChanged: (checked) => setState(() {
                                    if (checked == true) {
                                      _selectedStudentIds
                                          .add(student.studentId);
                                    } else {
                                      _selectedStudentIds
                                          .remove(student.studentId);
                                    }
                                  }),
                                )
                              : _StudentAvatar(
                                  photoBase64: student.photoBase64,
                                  fallbackLetter: student.englishFirstName[0]),
                          title: Text(
                              '${student.chineseName} (${student.englishFullName})'),
                          subtitle: Text(
                              'ID: ${student.studentId}${student.seatNo != null ? " • Seat: ${student.seatNo}" : ""}${student.classCode != null ? " • Class: ${student.classCode}" : ""}'),
                          trailing: _selectionMode
                              ? null
                              : Row(
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
                                      itemBuilder: (context) => [
                                        const PopupMenuItem(
                                            value: 'edit',
                                            child: ListTile(
                                                leading: Icon(Icons.edit),
                                                title: Text('Edit'))),
                                        const PopupMenuItem(
                                            value: 'delete',
                                            child: ListTile(
                                                leading:
                                                    Icon(Icons.delete_outline),
                                                title: Text('Delete'))),
                                      ],
                                    ),
                                    const Icon(Icons.chevron_right),
                                  ],
                                ),
                          onTap: _selectionMode
                              ? () => setState(() {
                                    if (isSelected) {
                                      _selectedStudentIds
                                          .remove(student.studentId);
                                    } else {
                                      _selectedStudentIds
                                          .add(student.studentId);
                                    }
                                  })
                              : () => context.push(
                                  '/class/${widget.classId}/student/${student.studentId}'),
                        ),
                      ),
                    );
                  },
                ),
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

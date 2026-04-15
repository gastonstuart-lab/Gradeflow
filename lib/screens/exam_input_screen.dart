import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:gradeflow/components/tool_first_app_surface.dart';
import 'package:gradeflow/components/workspace_shell.dart';
import 'package:gradeflow/services/student_service.dart';
import 'package:gradeflow/services/final_exam_service.dart';
import 'package:gradeflow/services/file_import_service.dart';
import 'package:gradeflow/services/drive_import_service.dart';
import 'package:gradeflow/services/google_auth_service.dart';
import 'package:gradeflow/services/google_drive_service.dart';
import 'package:gradeflow/models/final_exam.dart';
import 'package:gradeflow/models/student.dart';
import 'package:gradeflow/theme.dart';
import 'package:gradeflow/services/class_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:gradeflow/components/drive_file_picker_dialog.dart';
import 'package:gradeflow/components/ai_analyze_import_dialog.dart';
import 'package:gradeflow/openai/openai_config.dart';
import 'package:gradeflow/services/ai_import_service.dart';
import 'package:gradeflow/services/auth_service.dart';
import 'dart:async';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

enum _ImportSource { local, driveLink, driveBrowse }

class _PickedExamBytes {
  final String filename;
  final Uint8List bytes;
  const _PickedExamBytes({required this.filename, required this.bytes});
}

class ExamInputScreen extends StatefulWidget {
  final String classId;
  final String? highlightStudentId;

  const ExamInputScreen(
      {super.key, required this.classId, this.highlightStudentId});

  @override
  State<ExamInputScreen> createState() => _ExamInputScreenState();
}

class _ExamInputScreenState extends State<ExamInputScreen> {
  final Map<String, TextEditingController> _controllers = {};
  final FileImportService _importService = FileImportService();
  final DriveImportService _driveImportService = DriveImportService();
  final GoogleDriveService _googleDriveService = GoogleDriveService();
  String? _driveAccessToken;
  bool _driveSigningIn = false;
  final Map<String, GlobalKey> _itemKeys = {};
  bool _didScrollToHighlight = false;
  final Map<String, Timer> _saveDebouncers = {};
  bool _hydratingData = true;

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

  void _showPersistentMessage(String message) {
    _showFeedback(
      message,
      title: 'Google Sign-In',
      duration: const Duration(seconds: 12),
      actionLabel: 'Details',
      onAction: () {
        showDialog<void>(
          context: context,
          builder: (ctx) => WorkspaceDialogScaffold(
            title: 'Google Sign-In',
            subtitle:
                'Drive import uses your Google account when a file requires access.',
            icon: Icons.login_rounded,
            maxWidth: 560,
            body: SelectableText(message),
            actions: [
              OutlinedButton(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: message));
                  if (ctx.mounted) Navigator.pop(ctx);
                  _showFeedback(
                    'Sign-in details copied',
                    tone: WorkspaceFeedbackTone.success,
                  );
                },
                style: WorkspaceButtonStyles.outlined(ctx),
                child: const Text('Copy'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                style: WorkspaceButtonStyles.filled(ctx),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _ensureClassContextLoaded() async {
    final classService = context.read<ClassService>();
    if (classService.getClassById(widget.classId) != null) return;

    final user = context.read<AuthService>().currentUser;
    if (user != null) {
      await classService.loadClasses(user.userId);
    }
  }

  Future<void> _loadData() async {
    if (mounted) {
      setState(() => _hydratingData = true);
    }

    try {
      await _ensureClassContextLoaded();
      final studentService = context.read<StudentService>();
      await studentService.loadStudents(widget.classId);

      final studentIds = studentService.students.map((s) => s.studentId).toList();
      await context
          .read<FinalExamService>()
          .loadExams(widget.classId, studentIds);
    } finally {
      if (mounted) {
        setState(() => _hydratingData = false);
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _scrollToHighlightIfNeeded());
      }
    }
  }

  Future<int> _flushAllPendingSaves() async {
    // Cancel queued debounced saves and synthesize a single batch
    for (final entry in _saveDebouncers.entries) {
      entry.value.cancel();
    }
    _saveDebouncers.clear();

    if (!mounted) return 0;
    final studentService = context.read<StudentService>();
    final examService = context.read<FinalExamService>();

    // Compute only the changes, comparing against current service state
    final Map<String, double?> changes = {};
    for (final s in studentService.students) {
      final text = _controllers[s.studentId]?.text ?? '';
      final val = text.isEmpty ? null : double.tryParse(text);
      final existing = examService.getExam(s.studentId)?.examScore;

      // Only record when actually different and valid
      if (val == null) {
        if (existing != null) changes[s.studentId] = null;
      } else if (val >= 0 && val <= 100) {
        if (existing == null || (existing - val).abs() > 1e-9) {
          changes[s.studentId] = val;
        }
      }
    }

    final saved = await examService.upsertManyExams(widget.classId, changes);
    return saved;
  }

  void _restorePersistedExamValue(String studentId) {
    final existing = context.read<FinalExamService>().getExam(studentId)?.examScore;
    final controller = _controllers[studentId];
    if (controller == null) return;
    final restored = existing == null ? '' : existing.toStringAsFixed(0);
    if (controller.text == restored) return;
    controller.value = controller.value.copyWith(
      text: restored,
      selection: TextSelection.collapsed(offset: restored.length),
      composing: TextRange.empty,
    );
  }

  void _scheduleSave(String studentId) {
    _saveDebouncers[studentId]?.cancel();
    _saveDebouncers[studentId] =
        Timer(const Duration(milliseconds: 500), () async {
      if (!mounted) return;
      final text = _controllers[studentId]?.text ?? '';
      final val = double.tryParse(text);
      if (text.isEmpty) {
        await _updateExam(studentId, null);
      } else if (val != null && val >= 0 && val <= 100) {
        await _updateExam(studentId, val);
      }
    });
  }

  void _scrollToHighlightIfNeeded() {
    if (_didScrollToHighlight) return;
    final sid = widget.highlightStudentId;
    if (sid == null) return;
    final key = _itemKeys[sid];
    final ctx = key?.currentContext;
    if (ctx != null) {
      _didScrollToHighlight = true;
      Scrollable.ensureVisible(ctx,
          duration: const Duration(milliseconds: 500), curve: Curves.easeOut);
      _showFeedback(
        'Jumped to the student with a missing exam score.',
        tone: WorkspaceFeedbackTone.info,
      );
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    for (final t in _saveDebouncers.values) {
      t.cancel();
    }
    super.dispose();
  }

  Future<String?> _ensureDriveAccessToken() async {
    setState(() {
      _driveSigningIn = true;
    });
    final result = await GoogleAuthService().ensureAccessTokenDetailed();
    final token = result.accessToken;
    if (!mounted) return token;
    setState(() {
      _driveSigningIn = false;
      _driveAccessToken = token;
    });
    _showPersistentMessage(result.userMessage());
    return token;
  }

  Future<_PickedExamBytes?> _pickLocalExamBytes() async {
    final picked = await FilePicker.platform.pickFiles(
        withData: true,
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'csv']);
    if (picked == null || picked.files.single.bytes == null) return null;
    return _PickedExamBytes(
        filename: picked.files.single.name, bytes: picked.files.single.bytes!);
  }

  Future<_PickedExamBytes?> _pickExamBytesFromLink() async {
    final controller = TextEditingController();
    bool useAuth = true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Import exam scores from link'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                    labelText: 'Link (Google Drive or direct URL)',
                    hintText: 'Paste CSV/XLSX link'),
              ),
              const SizedBox(height: AppSpacing.sm),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Use Google Sign-In for private Drive links'),
                value: useAuth,
                onChanged: (v) => setState(() => useAuth = v ?? true),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Import')),
          ],
        ),
      ),
    );
    if (confirmed != true) return null;

    final raw = controller.text.trim();
    if (raw.isEmpty) {
      _showError('Please paste a link.');
      return null;
    }

    Map<String, String>? headers;
    if (useAuth) {
      final token = _driveAccessToken ?? await _ensureDriveAccessToken();
      if (token == null || token.isEmpty) return null;
      headers = {'Authorization': 'Bearer $token'};
    }

    final direct = _driveImportService.driveDirectDownloadUrl(raw) ?? raw;
    final uri = Uri.tryParse(direct);
    if (uri == null) {
      _showError('Invalid link.');
      return null;
    }

    try {
      final resp = await http.get(uri, headers: headers);
      if (!mounted) return null;
      if (resp.statusCode >= 400) {
        _showError('Download failed (${resp.statusCode}).');
        return null;
      }
      final filename =
          uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'drive_file';
      return _PickedExamBytes(filename: filename, bytes: resp.bodyBytes);
    } catch (e) {
      if (!mounted) return null;
      _showError('Error downloading: $e');
      return null;
    }
  }

  Future<_PickedExamBytes?> _pickExamBytesFromDriveBrowse() async {
    final token = _driveAccessToken ?? await _ensureDriveAccessToken();
    if (token == null || token.isEmpty || !mounted) return null;

    final picked = await showDialog<DriveFile?>(
      context: context,
      builder: (ctx) => DriveFilePickerDialog(
        driveService: _googleDriveService,
        allowedExtensions: const ['xlsx', 'csv'],
        title: 'Browse Google Drive (Exam Scores)',
      ),
    );
    if (picked == null) return null;

    try {
      final bytes = await _googleDriveService.downloadFileBytesFor(
        picked,
        preferredExportMimeType: GoogleDriveService.exportXlsxMimeType,
      );
      return _PickedExamBytes(filename: picked.name, bytes: bytes);
    } catch (e) {
      if (mounted) {
        _showPersistentMessage('Drive download failed. $e');
      }
      return null;
    }
  }

  Future<_PickedExamBytes?> _pickExamBytesUnified() async {
    final source = await showDialog<_ImportSource?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import Exam Scores'),
        content: const Text('Choose a source to import.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, _ImportSource.local),
              child: const Text('Local file')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, _ImportSource.driveLink),
              child: const Text('From Google Drive link')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, _ImportSource.driveBrowse),
              child: const Text('Browse Google Drive')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Cancel')),
        ],
      ),
    );
    if (source == null) return null;
    if (source == _ImportSource.local) return _pickLocalExamBytes();
    if (source == _ImportSource.driveBrowse) {
      return _pickExamBytesFromDriveBrowse();
    }
    return _pickExamBytesFromLink();
  }

  Future<void> _updateExam(String studentId, double? score) async {
    final now = DateTime.now();
    final exam = FinalExam(
      studentId: studentId,
      examScore: score,
      createdAt: now,
      updatedAt: now,
    );

    await context.read<FinalExamService>().updateExam(widget.classId, exam);
  }

  Future<void> _showImportDialog() async {
    final picked = await _pickExamBytesUnified();
    if (picked == null || !mounted) return;

    final name = picked.filename.toLowerCase();
    final bytes = picked.bytes;
    Map<String, double> examScores = const {};
    Object? parseError;
    try {
      examScores = name.endsWith('.xlsx')
          ? _importService.parseExamScoresXlsx(bytes)
          : _importService.parseExamScores(String.fromCharCodes(bytes));
    } catch (e) {
      parseError = e;
      examScores = const {};
    }

    if (examScores.isEmpty) {
      final action = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Could not parse exam scores'),
          content: Text(
            parseError == null
                ? 'No exam scores were detected in "${picked.filename}".'
                : 'Gradeflow could not read "${picked.filename}".\n\nError: $parseError',
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
          ],
        ),
      );
      if (!mounted || action != 'ai') return;

      if (!OpenAIConfig.isConfigured) {
        _showError(
            'AI is not configured. Set OPENAI_PROXY_ENDPOINT and OPENAI_PROXY_API_KEY.');
        return;
      }

      final rows = _importService.rowsFromAnyBytes(bytes);
      final jsonObj = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (ctx) => AiAnalyzeImportDialog(
          title: 'Analyze exam scores',
          filename: picked.filename,
          analyze: () => AiImportService()
              .analyzeExamScoresFromRows(rows, filename: picked.filename),
          confirmLabel: 'Use these scores',
        ),
      );
      if (!mounted || jsonObj == null) return;

      final extracted = <String, double>{};
      final rawScores = jsonObj['scores'];
      if (rawScores is List) {
        for (final e in rawScores) {
          if (e is Map) {
            final sid = (e['studentId'] ?? '').toString().trim();
            final raw = e['score'];
            final score = raw is num
                ? raw.toDouble()
                : double.tryParse(raw?.toString() ?? '');
            if (sid.isNotEmpty && score != null) {
              extracted[sid] = score;
            }
          }
        }
      }

      if (extracted.isEmpty) {
        _showError('AI did not return any usable exam scores.');
        return;
      }

      examScores = extracted;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import Exam Scores'),
        content: Text('Found ${examScores.length} exam scores. Import?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Import')),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await context
          .read<FinalExamService>()
          .bulkUpdateExams(widget.classId, examScores);
      _showSuccess('Imported ${examScores.length} exam scores');
      await _loadData();
    }
  }

  void _showError(String message) => _showFeedback(
        message,
        tone: WorkspaceFeedbackTone.error,
        title: 'Exam score issue',
      );

  void _showSuccess(String message) => _showFeedback(
        message,
        tone: WorkspaceFeedbackTone.success,
      );

  Future<void> _handleExit() async {
    try {
      final saved = await _flushAllPendingSaves()
          .timeout(const Duration(milliseconds: 1200));
      if (saved > 0 && mounted) {
        _showSuccess('Saved $saved changes');
      }
    } on TimeoutException {
      _showFeedback(
        'Saving in background...',
        tone: WorkspaceFeedbackTone.info,
      );
      unawaited(_flushAllPendingSaves());
    }
  }

  Future<void> _commitExamScore(
    String studentId, {
    bool showSuccessMessage = false,
    bool showValidationMessage = false,
  }) async {
    final value = _controllers[studentId]?.text.trim() ?? '';
    final scoreValue = double.tryParse(value);
    if (scoreValue != null && scoreValue >= 0 && scoreValue <= 100) {
      await _updateExam(studentId, scoreValue);
      if (showSuccessMessage) {
        _showSuccess('Exam score updated');
      }
      return;
    }
    if (value.isEmpty) {
      await _updateExam(studentId, null);
      if (showSuccessMessage) {
        _showSuccess('Exam score cleared');
      }
      return;
    }
    _restorePersistedExamValue(studentId);
    if (showSuccessMessage || showValidationMessage) {
      _showError('Invalid score (must be 0-100). Restored the previous value.');
    }
  }

  Widget _buildContextStrip(
    BuildContext context, {
    required String className,
    required String classContextLine,
    required int studentCount,
  }) {
    return WorkspaceContextBar(
      title: className,
      subtitle: classContextLine,
      leading: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          const WorkspaceContextPill(
            icon: Icons.auto_graph_outlined,
            label: 'Process',
            value: '40%',
          ),
          const WorkspaceContextPill(
            icon: Icons.fact_check_outlined,
            label: 'Final exam',
            value: '60%',
            emphasized: true,
          ),
          WorkspaceContextPill(
            icon: Icons.people_alt_outlined,
            label: 'Roster',
            value: '$studentCount students',
          ),
          const WorkspaceContextPill(
            icon: Icons.sync_outlined,
            label: 'Autosave',
            value: '500 ms',
          ),
        ],
      ),
      trailing: WorkspaceContextPill(
        icon: _driveAccessToken == null
            ? Icons.cloud_queue_outlined
            : Icons.cloud_done_outlined,
        label: 'Drive',
        value: _driveAccessToken == null ? 'Optional' : 'Connected',
        accent: _driveAccessToken == null
            ? const Color(0xFFDAA85E)
            : Theme.of(context).colorScheme.primary,
        emphasized: true,
      ),
    );
  }

  Widget _buildExamRow(
    BuildContext context, {
    required Student student,
    required bool isHighlight,
    required TextEditingController controller,
    required GlobalKey key,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: WorkspaceSpacing.sm),
      child: WorkspaceSurfaceCard(
        key: key,
        padding: EdgeInsets.zero,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(WorkspaceRadius.cardCompact),
            color: isHighlight
                ? theme.colorScheme.primary.withValues(alpha: 0.08)
                : Colors.transparent,
          ),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 760;
              final info = Column(
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
                    student.seatNo?.isNotEmpty == true
                        ? 'ID ${student.studentId} / Seat ${student.seatNo}'
                        : 'ID ${student.studentId}',
                    style: context.textStyles.labelSmall?.withColor(
                      theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              );
              final input = SizedBox(
                width: narrow ? double.infinity : 128,
                child: Focus(
                  onFocusChange: (hasFocus) {
                    if (!hasFocus) {
                      _commitExamScore(
                        student.studentId,
                        showValidationMessage: true,
                      );
                    }
                  },
                  child: TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      labelText: 'Exam score',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
                    ],
                    onChanged: (_) => _scheduleSave(student.studentId),
                    onSubmitted: (_) => _commitExamScore(
                      student.studentId,
                      showSuccessMessage: true,
                    ),
                    onTapOutside: (_) => _commitExamScore(
                      student.studentId,
                      showValidationMessage: true,
                    ),
                  ),
                ),
              );

              if (narrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    info,
                    const SizedBox(height: WorkspaceSpacing.md),
                    input,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: info),
                  const SizedBox(width: WorkspaceSpacing.md),
                  input,
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final studentService = context.watch<StudentService>();
    final examService = context.watch<FinalExamService>();
    final classItem = context.watch<ClassService>().getClassById(widget.classId);
    final className = classItem?.className ?? 'Class';
    final studentCount = studentService.students.length;
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleExit();
        if (!context.mounted) return;
        Navigator.of(context).pop(result);
      },
      child: ToolFirstAppSurface(
        title: 'Final Exam Scores',
        eyebrow: 'Student Reporting',
        subtitle:
            'Capture the 60% exam score without leaving the active class context.',
        leading: IconButton(
          onPressed: () async {
            await _handleExit();
            if (!context.mounted) return;
            context.pop();
          },
          tooltip: 'Back',
          style: WorkspaceButtonStyles.icon(context),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        contextStrip: _buildContextStrip(
          context,
          className: className,
          classContextLine: classContextLine,
          studentCount: studentCount,
        ),
        toolbar: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
              onPressed: _driveSigningIn ? null : _ensureDriveAccessToken,
              icon: _driveSigningIn
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    )
                  : const Icon(Icons.login_rounded),
              label: Text(
                _driveAccessToken == null ? 'Connect Drive' : 'Drive connected',
              ),
              style: WorkspaceButtonStyles.outlined(context),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                final saved = await _flushAllPendingSaves();
                if (saved > 0 && context.mounted) {
                  _showSuccess('Saved $saved changes');
                }
              },
              icon: const Icon(Icons.save_outlined),
              label: const Text('Save all'),
              style: WorkspaceButtonStyles.outlined(context),
            ),
            FilledButton.icon(
              onPressed: _showImportDialog,
              icon: const Icon(Icons.upload_file_outlined),
              label: const Text('Import scores'),
              style: WorkspaceButtonStyles.filled(context),
            ),
          ],
        ),
        workspace: (_hydratingData || studentService.isLoading)
            ? const WorkspaceLoadingState(
                title: 'Loading exam scores',
                subtitle: 'Bringing the roster and final exam entries into view.',
              )
            : studentService.students.isEmpty
                ? const WorkspaceEmptyState(
                    icon: Icons.fact_check_outlined,
                    title: 'No students in this class',
                    subtitle:
                        'Add students before entering final exam scores or importing a score sheet.',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: WorkspaceSpacing.md),
                    itemCount: studentService.students.length,
                    itemBuilder: (context, index) {
                      final student = studentService.students[index];
                      final exam = examService.getExam(student.studentId);

                      if (!_controllers.containsKey(student.studentId)) {
                        _controllers[student.studentId] = TextEditingController(
                          text: exam?.examScore?.toStringAsFixed(0) ?? '',
                        );
                      }
                      final key = _itemKeys.putIfAbsent(
                        student.studentId,
                        () => GlobalKey(),
                      );
                      final isHighlight =
                          widget.highlightStudentId == student.studentId;

                      return _buildExamRow(
                        context,
                        student: student,
                        isHighlight: isHighlight,
                        controller: _controllers[student.studentId]!,
                        key: key,
                      );
                    },
                  ),
      ),
    );
  }
}

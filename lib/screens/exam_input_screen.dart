import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:gradeflow/services/student_service.dart';
import 'package:gradeflow/services/final_exam_service.dart';
import 'package:gradeflow/services/file_import_service.dart';
import 'package:gradeflow/services/drive_import_service.dart';
import 'package:gradeflow/services/google_auth_service.dart';
import 'package:gradeflow/services/google_drive_service.dart';
import 'package:gradeflow/models/final_exam.dart';
import 'package:gradeflow/theme.dart';
import 'package:file_picker/file_picker.dart';
import 'package:gradeflow/components/animated_glow_border.dart';
import 'package:gradeflow/components/drive_file_picker_dialog.dart';
import 'dart:async';
import 'dart:typed_data';
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
  bool _hasPendingSaves = false;

  void _showPersistentMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 12),
        content: Text(message),
        action: SnackBarAction(
          label: 'Details',
          onPressed: () {
            showDialog<void>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Google Sign-In'),
                content: SelectableText(message),
                actions: [
                  TextButton(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: message));
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: const Text('Copy'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Close'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final studentService = context.read<StudentService>();
    await studentService.loadStudents(widget.classId);

    final studentIds = studentService.students.map((s) => s.studentId).toList();
    await context.read<FinalExamService>().loadExams(studentIds);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _scrollToHighlightIfNeeded());
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

    final saved = await examService.upsertManyExams(changes);
    _hasPendingSaves = false;
    return saved;
  }

  void _scheduleSave(String studentId) {
    _hasPendingSaves = true;
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Jumped to student with missing exam score')));
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
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please paste a link')));
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
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Invalid link')));
      return null;
    }

    try {
      final resp = await http.get(uri, headers: headers);
      if (resp.statusCode >= 400) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Download failed (${resp.statusCode})')));
        return null;
      }
      final filename =
          uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'drive_file';
      return _PickedExamBytes(filename: filename, bytes: resp.bodyBytes);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error downloading: $e')));
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
    if (source == _ImportSource.driveBrowse)
      return _pickExamBytesFromDriveBrowse();
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

    await context.read<FinalExamService>().updateExam(exam);
  }

  Future<void> _showImportDialog() async {
    final picked = await _pickExamBytesUnified();
    if (picked == null || !mounted) return;

    final name = picked.filename.toLowerCase();
    final bytes = picked.bytes;
    final examScores = name.endsWith('.xlsx')
        ? _importService.parseExamScoresXlsx(bytes)
        : _importService.parseExamScores(String.fromCharCodes(bytes));

    if (examScores.isEmpty) {
      _showError('Failed to parse file');
      return;
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
      await context.read<FinalExamService>().bulkUpdateExams(examScores);
      _showSuccess('Imported ${examScores.length} exam scores');
      await _loadData();
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
    final examService = context.watch<FinalExamService>();

    return WillPopScope(
      onWillPop: () async {
        // Prevent getting stuck on slow storage by timing out
        try {
          final saved = await _flushAllPendingSaves()
              .timeout(const Duration(milliseconds: 1200));
          if (saved > 0 && mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text('Saved $saved changes')));
          }
        } on TimeoutException {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Saving in background…')));
          }
          // Fire and forget in background
          unawaited(_flushAllPendingSaves());
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              try {
                final saved = await _flushAllPendingSaves()
                    .timeout(const Duration(milliseconds: 1200));
                if (saved > 0 && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Saved $saved changes')));
                }
              } on TimeoutException {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Saving in background…')));
                }
                unawaited(_flushAllPendingSaves());
              } finally {
                if (mounted) context.pop();
              }
            },
          ),
          title: const Text('Final Exam Scores'),
          actions: [
            IconButton(
              icon: _driveSigningIn
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Theme.of(context).colorScheme.onSurface),
                    )
                  : const Icon(Icons.login),
              tooltip: _driveAccessToken == null
                  ? 'Sign in with Google (Drive)'
                  : 'Google Drive connected',
              onPressed: _driveSigningIn ? null : _ensureDriveAccessToken,
            ),
            IconButton(
              icon: const Icon(Icons.save),
              tooltip: 'Save all',
              onPressed: () async {
                final saved = await _flushAllPendingSaves();
                if (saved > 0 && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Saved $saved changes')));
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.upload_file),
              onPressed: _showImportDialog,
              tooltip: 'Import from CSV or Excel',
            ),
          ],
        ),
        body: Column(
          children: [
            Container(
              padding: AppSpacing.paddingLg,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      'Final Exam = 60% of total grade\nOther categories = 40% of total grade',
                      style: context.textStyles.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: studentService.students.isEmpty
                  ? const Center(child: Text('No students in this class'))
                  : ListView.builder(
                      padding: AppSpacing.paddingMd,
                      itemCount: studentService.students.length,
                      itemBuilder: (context, index) {
                        final student = studentService.students[index];
                        final exam = examService.getExam(student.studentId);

                        if (!_controllers.containsKey(student.studentId)) {
                          _controllers[student.studentId] =
                              TextEditingController(
                            text: exam?.examScore?.toStringAsFixed(0) ?? '',
                          );
                        }
                        final key = _itemKeys.putIfAbsent(
                            student.studentId, () => GlobalKey());
                        final isHighlight =
                            widget.highlightStudentId == student.studentId;

                        return AnimatedGlowBorder(
                          child: Card(
                            key: key,
                            margin:
                                const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              decoration: BoxDecoration(
                                // Replace thick border with a subtle highlight background to avoid double outline
                                color: isHighlight
                                    ? Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withValues(alpha: 0.06)
                                    : null,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.md),
                              ),
                              child: Padding(
                                padding: AppSpacing.paddingMd,
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(student.chineseName,
                                              style: context
                                                  .textStyles.titleMedium),
                                          Text(student.englishFullName,
                                              style:
                                                  context.textStyles.bodySmall),
                                        ],
                                      ),
                                    ),
                                    SizedBox(
                                      width: 100,
                                      child: Focus(
                                        onFocusChange: (hasFocus) {
                                          if (!hasFocus) {
                                            final value =
                                                _controllers[student.studentId]!
                                                    .text;
                                            final scoreValue =
                                                double.tryParse(value);
                                            if (scoreValue != null &&
                                                scoreValue >= 0 &&
                                                scoreValue <= 100) {
                                              _updateExam(student.studentId,
                                                  scoreValue);
                                            } else if (value.isEmpty) {
                                              _updateExam(
                                                  student.studentId, null);
                                            }
                                          }
                                        },
                                        child: TextField(
                                          controller:
                                              _controllers[student.studentId],
                                          decoration: const InputDecoration(
                                            labelText: 'Exam Score',
                                            border: OutlineInputBorder(),
                                            isDense: true,
                                          ),
                                          keyboardType: TextInputType.number,
                                          inputFormatters: [
                                            FilteringTextInputFormatter.allow(
                                                RegExp(r'^\d*\.?\d*'))
                                          ],
                                          onChanged: (_) =>
                                              _scheduleSave(student.studentId),
                                          onSubmitted: (value) {
                                            final scoreValue =
                                                double.tryParse(value);
                                            if (scoreValue != null &&
                                                scoreValue >= 0 &&
                                                scoreValue <= 100) {
                                              _updateExam(student.studentId,
                                                  scoreValue);
                                              _showSuccess(
                                                  'Exam score updated');
                                            } else if (value.isEmpty) {
                                              _updateExam(
                                                  student.studentId, null);
                                            } else {
                                              _showError(
                                                  'Invalid score (must be 0-100)');
                                            }
                                          },
                                          onTapOutside: (_) {
                                            final value =
                                                _controllers[student.studentId]!
                                                    .text;
                                            final scoreValue =
                                                double.tryParse(value);
                                            if (scoreValue != null &&
                                                scoreValue >= 0 &&
                                                scoreValue <= 100) {
                                              _updateExam(student.studentId,
                                                  scoreValue);
                                            } else if (value.isEmpty) {
                                              _updateExam(
                                                  student.studentId, null);
                                            }
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

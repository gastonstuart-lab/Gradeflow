import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:gradeflow/services/auth_service.dart';
import 'package:gradeflow/services/class_service.dart';
import 'package:gradeflow/services/demo_data_service.dart';
import 'package:gradeflow/services/final_exam_service.dart';
import 'package:gradeflow/services/grade_item_service.dart';
import 'package:gradeflow/services/student_service.dart';
import 'package:gradeflow/services/grading_category_service.dart';
import 'package:gradeflow/services/student_score_service.dart';
import 'package:http/http.dart' as http;
import 'package:gradeflow/theme.dart';
import 'package:gradeflow/providers/app_providers.dart';
import 'package:gradeflow/components/class_card.dart';
import 'package:gradeflow/components/workspace_shell.dart';
import 'package:uuid/uuid.dart';
import 'package:file_picker/file_picker.dart';
import 'package:gradeflow/services/file_import_service.dart';
import 'package:gradeflow/services/drive_import_service.dart';
import 'package:gradeflow/services/google_auth_service.dart';
import 'package:gradeflow/services/google_drive_service.dart';
import 'package:gradeflow/components/drive_file_picker_dialog.dart';
import 'package:gradeflow/components/pilot_feedback_dialog.dart';
import 'package:gradeflow/models/class.dart';
import 'package:gradeflow/nav.dart';
import 'package:gradeflow/models/deleted_class_entry.dart';
import 'package:gradeflow/services/class_trash_service.dart';
import 'package:gradeflow/services/ai_import_service.dart';
import 'package:gradeflow/openai/openai_config.dart';
import 'package:gradeflow/components/ai_analyze_import_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum _ImportSource { local, driveLink, driveBrowse }

class _PickedBytes {
  final String filename;
  final Uint8List bytes;
  const _PickedBytes({required this.filename, required this.bytes});
}

class ClassListScreen extends StatefulWidget {
  const ClassListScreen({super.key});

  @override
  State<ClassListScreen> createState() => _ClassListScreenState();
}

class _ClassListScreenState extends State<ClassListScreen> {
  final FileImportService _importService = FileImportService();
  final DriveImportService _driveImportService = DriveImportService();
  String? _driveAccessToken;
  bool _driveSigningIn = false;
  bool _showArchived = false;
  List<String> _activeClassOrder = [];

  String _currentTeacherName() =>
      context.read<AuthService>().currentUser?.fullName ?? '';

  String _extractGroupDigits(String input) {
    final t = input.trim();
    if (t.isEmpty) return '';
    final direct = RegExp(r'^\d+$').firstMatch(t);
    if (direct != null) return t;
    final m =
        RegExp(r'(?:group|grp|g|set)\s*[-_ ]*\s*(\d+)', caseSensitive: false)
            .firstMatch(t);
    return m?.group(1) ?? '';
  }

  String _guessGroupFromFilename(String filename) {
    final lower = filename.toLowerCase();
    final m =
        RegExp(r'(?:group|grp|g|set)\s*[-_ ]*\s*(\d+)', caseSensitive: false)
            .firstMatch(lower);
    return m?.group(1) ?? '';
  }

  String _guessSubjectFromFilename(String filename) {
    final lower = filename.toLowerCase();
    if (lower.contains('eng')) return 'English';
    if (lower.contains('sci')) return 'Science';
    if (lower.contains('math')) return 'Mathematics';
    if (lower.contains('hist')) return 'History';
    if (lower.contains('geog')) return 'Geography';
    if (lower.contains('chin')) return 'Chinese';
    if (lower.contains('phys')) return 'Physics';
    if (lower.contains('chem')) return 'Chemistry';
    if (lower.contains('bio')) return 'Biology';
    if (lower.contains('art')) return 'Art';
    if (lower.contains('music')) return 'Music';
    if (lower.contains('pe') || lower.contains('phys ed')) {
      return 'Physical Education';
    }
    return 'General';
  }

  String _guessTermFromFilename(String filename) {
    final lower = filename.toLowerCase();
    if (lower.contains('fall') || lower.contains('autumn')) return 'Fall';
    if (lower.contains('spring')) return 'Spring';
    if (lower.contains('summer')) return 'Summer';
    if (lower.contains('winter')) return 'Winter';
    // Default to current month heuristic
    final now = DateTime.now();
    if (now.month >= 8 && now.month <= 12) return 'Fall';
    if (now.month >= 1 && now.month <= 5) return 'Spring';
    return 'Fall';
  }

  String _applyGroupSuffixToClassName(String className, String groupDigits) {
    final g = _extractGroupDigits(groupDigits);
    if (g.isEmpty) return className;
    if (RegExp(r'\(g\d+\)\s*$', caseSensitive: false).hasMatch(className)) {
      return className;
    }
    return '${className.trim()} (G$g)';
  }

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

  Future<String?> _ensureDriveAccessToken() async {
    setState(() {
      _driveSigningIn = true;
    });
    final result =
        await context.read<GoogleAuthService>().ensureAccessTokenDetailed();
    final token = result.accessToken;
    if (!mounted) return token;
    setState(() {
      _driveSigningIn = false;
      _driveAccessToken = token;
    });

    _showPersistentMessage(result.userMessage());
    return token;
  }

  Future<_PickedBytes?> _pickBytesLocal(
      {required List<String> extensions}) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: extensions,
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return null;
    return _PickedBytes(
        filename: result.files.single.name, bytes: result.files.single.bytes!);
  }

  Future<_PickedBytes?> _pickBytesFromLink(
      {required List<String> extensions, bool useDriveAuth = false}) async {
    final link = await _promptForLink(useDriveAuthDefault: useDriveAuth);
    if (link == null) return null;

    Map<String, String>? headers;
    if (useDriveAuth) {
      final token = _driveAccessToken ?? await _ensureDriveAccessToken();
      if (token == null || token.isEmpty) return null;
      headers = {'Authorization': 'Bearer $token'};
    }

    final direct = _driveImportService.driveDirectDownloadUrl(link) ?? link;
    final uri = Uri.tryParse(direct);
    if (uri == null) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Invalid link')));
      }
      return null;
    }

    try {
      final resp = await http.get(uri, headers: headers);
      if (resp.statusCode >= 400) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Download failed (${resp.statusCode})')));
        }
        return null;
      }
      final filename =
          uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'drive_file';
      return _PickedBytes(filename: filename, bytes: resp.bodyBytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error downloading: $e')));
      }
      return null;
    }
  }

  Future<_PickedBytes?> _pickBytesFromDriveBrowse(
      {required List<String> extensions}) async {
    final token = _driveAccessToken ?? await _ensureDriveAccessToken();
    if (token == null || token.isEmpty || !mounted) return null;
    final driveService = context.read<GoogleDriveService>();

    final picked = await showDialog<DriveFile?>(
      context: context,
      builder: (ctx) => DriveFilePickerDialog(
        driveService: driveService,
        allowedExtensions: extensions,
      ),
    );

    if (picked == null) return null;

    try {
      final bytes = await driveService.downloadFileBytesFor(
        picked,
        preferredExportMimeType: GoogleDriveService.exportXlsxMimeType,
      );
      return _PickedBytes(filename: picked.name, bytes: bytes);
    } catch (e) {
      if (mounted) {
        _showPersistentMessage('Drive download failed. $e');
      }
      return null;
    }
  }

  Future<String?> _promptForLink({bool useDriveAuthDefault = false}) async {
    final controller = TextEditingController();
    bool useAuth = useDriveAuthDefault;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Import from link'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Link (Google Drive or direct URL)',
                  hintText: 'Paste a CSV/XLSX link',
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Use Google Sign-In for private Drive links'),
                value: useAuth,
                onChanged: (v) => setState(() => useAuth = v ?? false),
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
    if (useAuth) {
      await _ensureDriveAccessToken();
      if (!mounted) return null;
    }
    return raw;
  }

  Future<_PickedBytes?> _pickBytesUnified(
      {required List<String> extensions, required String title}) async {
    final source = await showDialog<_ImportSource?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
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
    if (source == _ImportSource.local) {
      return _pickBytesLocal(extensions: extensions);
    }
    if (source == _ImportSource.driveBrowse) {
      return _pickBytesFromDriveBrowse(extensions: extensions);
    }
    return _pickBytesFromLink(extensions: extensions, useDriveAuth: true);
  }

  Map<String, List<ImportedStudent>> _applyGroupToClassMap(
      Map<String, List<ImportedStudent>> input, String groupDigits) {
    final g = _extractGroupDigits(groupDigits);
    if (g.isEmpty) return input;
    final Map<String, List<ImportedStudent>> out = {};
    for (final e in input.entries) {
      final k = _applyGroupSuffixToClassName(e.key, g);
      out.putIfAbsent(k, () => <ImportedStudent>[]).addAll(e.value);
    }
    return out;
  }

  bool _looksLikeRoster(List<ImportedStudent> roster) {
    if (roster.isEmpty) return false;
    int withId = 0;
    int withName = 0;
    int withSeat = 0;
    for (final r in roster) {
      if ((r.studentId ?? '').trim().isNotEmpty) withId++;
      if ((r.seatNo ?? '').trim().isNotEmpty) withSeat++;
      final hasChinese = (r.chineseName ?? '').trim().isNotEmpty;
      final hasEnglish = (r.englishFirstName ?? '').trim().isNotEmpty &&
          (r.englishLastName ?? '').trim().isNotEmpty;
      if (hasChinese || hasEnglish) withName++;
    }
    // Strong signal: multiple IDs present.
    if (withId >= 3) return true;
    // Weaker signal: many names plus some seat numbers / enough rows.
    return withName >= 5 && (withSeat >= 3 || roster.length >= 10);
  }

  Future<bool> _guardImportTypeForClassScreen({
    required Uint8List bytes,
    required String filename,
  }) async {
    final detection = _importService.detectFileType(bytes, filename: filename);
    if (detection.type == ImportFileType.roster ||
        detection.type == ImportFileType.unknown) {
      return true;
    }

    if (!mounted) return false;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Wrong import destination'),
        content: Text(
          '${detection.message}\n\nThis screen imports classes/students only.\n\n${detection.suggestion}',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    return false;
  }

  Future<void> _importRosterIntoSingleClass({
    required List<ImportedStudent> parsed,
    required String filename,
    required Uint8List bytes,
  }) async {
    final valid = parsed.where((s) => s.isValid).toList();
    final invalid = parsed.where((s) => !s.isValid).toList();

    if (valid.isEmpty) {
      await _showImportDiagnosticsDialog(
        title: 'Roster detected but no valid students',
        filename: filename,
        bytes: bytes,
        hint:
            'This file looks like a roster, but required fields are missing (usually Student ID). Please include StudentID/學號 and retry.',
      );
      return;
    }

    final auth = context.read<AuthService>();
    final classService = context.read<ClassService>();
    final studentService = context.read<StudentService>();
    final catService = context.read<GradingCategoryService>();

    final existingClasses = List<Class>.from(classService.classes);
    existingClasses.sort((a, b) =>
        a.className.toLowerCase().compareTo(b.className.toLowerCase()));

    String? selectedClassId =
        existingClasses.isNotEmpty ? existingClasses.first.classId : null;
    bool createNew = existingClasses.isEmpty;
    final classNameCtrl = TextEditingController();
    final subjectCtrl =
        TextEditingController(text: _guessSubjectFromFilename(filename));
    final yearCtrl = TextEditingController(text: '2024-2025');
    String selectedTerm = _guessTermFromFilename(filename);

    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Import Roster (Single Class)'),
          content: SizedBox(
            width: 560,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Valid students: ${valid.length}'),
                Text('Invalid/ignored rows: ${invalid.length}',
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
                const SizedBox(height: AppSpacing.md),
                const Text(
                    'No class column was found. Choose where to import these students:'),
                const SizedBox(height: AppSpacing.sm),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Create a new class'),
                  value: createNew,
                  onChanged: (v) => setState(() => createNew = v),
                ),
                if (!createNew) ...[
                  DropdownButtonFormField<String>(
                    initialValue: selectedClassId,
                    isExpanded: true,
                    decoration:
                        const InputDecoration(labelText: 'Target class'),
                    items: existingClasses
                        .map((c) => DropdownMenuItem<String>(
                            value: c.classId, child: Text(c.className)))
                        .toList(),
                    onChanged: (v) => setState(() => selectedClassId = v),
                  ),
                ] else ...[
                  TextField(
                      controller: classNameCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Class Name')),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                      controller: subjectCtrl,
                      decoration: const InputDecoration(labelText: 'Subject')),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                      controller: yearCtrl,
                      decoration:
                          const InputDecoration(labelText: 'School Year')),
                  const SizedBox(height: AppSpacing.sm),
                  DropdownButtonFormField<String>(
                    initialValue: selectedTerm,
                    decoration: const InputDecoration(labelText: 'Term'),
                    items: const [
                      DropdownMenuItem(value: 'Fall', child: Text('Fall')),
                      DropdownMenuItem(value: 'Spring', child: Text('Spring')),
                      DropdownMenuItem(value: 'Summer', child: Text('Summer')),
                      DropdownMenuItem(value: 'Winter', child: Text('Winter')),
                    ],
                    onChanged: (v) =>
                        setState(() => selectedTerm = v ?? 'Fall'),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Import')),
          ],
        ),
      ),
    );

    if (proceed != true || !mounted) return;

    Class? target;
    if (createNew) {
      final name = classNameCtrl.text.trim();
      if (name.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('Class name is required'),
            backgroundColor: Theme.of(context).colorScheme.error));
        return;
      }
      final now = DateTime.now();
      target = Class(
        classId: const Uuid().v4(),
        className: name,
        subject: subjectCtrl.text.trim().isEmpty
            ? 'General'
            : subjectCtrl.text.trim(),
        groupNumber: null,
        schoolYear:
            yearCtrl.text.trim().isEmpty ? '2024-2025' : yearCtrl.text.trim(),
        term: selectedTerm,
        teacherId: auth.currentUser!.userId,
        createdAt: now,
        updatedAt: now,
      );
      await classService.addClass(target);
      await catService.seedDefaultCategories(target.classId);
    } else {
      target = existingClasses.firstWhere((c) => c.classId == selectedClassId,
          orElse: () => existingClasses.first);
    }

    await studentService.loadStudents(target.classId);
    final existingIds = studentService.students.map((s) => s.studentId).toSet();
    final students = _importService
        .convertToStudents(valid, target.classId)
        .where((s) => !existingIds.contains(s.studentId))
        .toList();
    if (students.isNotEmpty) {
      await studentService.addStudents(students);
    }

    await classService.loadClasses(auth.currentUser!.userId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'Imported ${students.length} students into ${target.className}')));
  }

  Future<void> _importRostersToClassesFromBytes({
    required Uint8List bytes,
    required String filename,
  }) async {
    final nameLower = filename.toLowerCase();
    final imported = nameLower.endsWith('.xlsx')
        ? _importService.parseXlsxRoster(bytes,
            teacherName: _currentTeacherName())
        : _importService.parseCSV(_importService.decodeTextFromBytes(bytes));

    final parsed = (imported.isEmpty && nameLower.endsWith('.xlsx'))
        ? _importService.parseCSV(_importService.decodeTextFromBytes(bytes))
        : imported;

    if (parsed.isEmpty) {
      debugPrint('Import Rosters: parser returned 0 rows for $nameLower');
      await _showImportDiagnosticsDialog(
        title: 'Could not read roster file',
        filename: filename,
        bytes: bytes,
        hint:
            'Tip: ensure there is a Class column (or similar) and export as CSV (UTF-8) if possible.',
      );
      return;
    }

    final valid = parsed
        .where((i) =>
            i.isValid && (i.classCode != null && i.classCode!.isNotEmpty))
        .toList();
    final invalid = parsed
        .where(
            (i) => !i.isValid || (i.classCode == null || i.classCode!.isEmpty))
        .toList();

    // Group by class code
    final Map<String, List<ImportedStudent>> byClass = {};
    for (final s in valid) {
      final code = s.classCode!.trim();
      byClass.putIfAbsent(code, () => []).add(s);
    }

    if (byClass.isEmpty) {
      await _showImportDiagnosticsDialog(
        title: 'No class codes found',
        filename: filename,
        bytes: bytes,
        hint:
            'This file has student rows but no usable class codes. Add a Class/ClassCode column (or similar) and retry.',
      );
      return;
    }

    final auth = context.read<AuthService>();
    final classService = context.read<ClassService>();
    final teacherFullName = auth.currentUser?.fullName ?? '';
    final teacherMatchedCodes =
        _importService.inferClassCodesForTeacherFromRoster(
      bytes,
      teacherFullName,
    );

    // Determine which classes already exist (match by className == ClassCode for this teacher)
    final existingByName = {
      for (final c in classService.classes) c.className.toLowerCase(): c
    };
    final guessedPrefix = _guessPrefixFromKeys(byClass.keys);

    final subjectCtrl =
        TextEditingController(text: _guessSubjectFromFilename(filename));
    final yearCtrl = TextEditingController(text: '2024-2025');
    String selectedTerm = _guessTermFromFilename(filename);

    final prefixCtrl = TextEditingController(text: guessedPrefix);
    final groupCtrl =
        TextEditingController(text: _guessGroupFromFilename(filename));
    bool combineSections = false;
    Map<String, List<ImportedStudent>> previewMap =
        _applyGroupToClassMap(byClass, groupCtrl.text);
    final existingClassKeys = existingByName.keys.toSet();
    Set<String> selectedClassKeys = {};

    bool _keyMatchesTeacherCode(String key) {
      final upper = key.replaceAll(' ', '').toUpperCase();
      for (final code in teacherMatchedCodes) {
        final c = code.replaceAll(' ', '').toUpperCase();
        if (upper == c || upper.startsWith(c) || c.startsWith(upper)) {
          return true;
        }
      }
      return false;
    }

    void ensureDefaultSelection() {
      if (previewMap.isEmpty) {
        selectedClassKeys = {};
        return;
      }
      final matchesTeacher =
          previewMap.keys.where((k) => _keyMatchesTeacherCode(k)).toSet();
      if (matchesTeacher.isNotEmpty) {
        if (selectedClassKeys.isEmpty) {
          selectedClassKeys = matchesTeacher;
          return;
        }
        selectedClassKeys =
            selectedClassKeys.where((k) => previewMap.containsKey(k)).toSet();
        if (selectedClassKeys.isEmpty) {
          selectedClassKeys = matchesTeacher;
        }
        return;
      }
      final matchesExisting = previewMap.keys
          .where((k) => existingClassKeys.contains(k.toLowerCase()))
          .toSet();
      if (selectedClassKeys.isEmpty) {
        selectedClassKeys = matchesExisting.isNotEmpty
            ? matchesExisting
            : previewMap.keys.toSet();
        return;
      }
      selectedClassKeys =
          selectedClassKeys.where((k) => previewMap.containsKey(k)).toSet();
      if (selectedClassKeys.isEmpty) {
        selectedClassKeys = matchesExisting.isNotEmpty
            ? matchesExisting
            : previewMap.keys.toSet();
      }
    }

    ensureDefaultSelection();
    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Import Rosters to Classes'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Valid rows: ${valid.length}'),
                Text('Invalid rows: ${invalid.length}',
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
                const SizedBox(height: AppSpacing.md),
                Text('Classes detected: ${previewMap.length}'),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => setState(
                          () => selectedClassKeys = previewMap.keys.toSet()),
                      child: const Text('Select all'),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    TextButton(
                      onPressed: () => setState(() {
                        selectedClassKeys = teacherMatchedCodes.isNotEmpty
                            ? previewMap.keys
                                .where((k) => _keyMatchesTeacherCode(k))
                                .toSet()
                            : previewMap.keys
                                .where((k) =>
                                    existingClassKeys.contains(k.toLowerCase()))
                                .toSet();
                        if (selectedClassKeys.isEmpty) {
                          selectedClassKeys = previewMap.keys.toSet();
                        }
                      }),
                      child: Text(teacherMatchedCodes.isNotEmpty
                          ? 'Select mine'
                          : 'Select existing'),
                    ),
                  ],
                ),
                if (teacherMatchedCodes.isNotEmpty) ...[
                  Text(
                    'Auto-detected teacher match for ${teacherMatchedCodes.length} class code(s): ${teacherMatchedCodes.take(8).join(', ')}',
                    style: context.textStyles.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 180),
                  child: ListView(
                    shrinkWrap: true,
                    children: previewMap.entries.map((e) {
                      final key = e.key;
                      final count = e.value.length;
                      final exists =
                          existingClassKeys.contains(key.toLowerCase());
                      return CheckboxListTile(
                        dense: true,
                        value: selectedClassKeys.contains(key),
                        onChanged: (v) => setState(() {
                          if (v == true) {
                            selectedClassKeys.add(key);
                          } else {
                            selectedClassKeys.remove(key);
                          }
                        }),
                        title: Text(key),
                        subtitle: Text(
                            '$count student${count == 1 ? '' : 's'} • ${exists ? 'existing class' : 'new class'}'),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Combine letter sections with same prefix'),
                  subtitle: const Text('Example: J2F + J2G => J2FG'),
                  value: combineSections,
                  onChanged: (v) {
                    setState(() {
                      combineSections = v;
                      final base = _mergeSections(byClass,
                          enabled: combineSections,
                          userPrefix: prefixCtrl.text.trim());
                      previewMap = _applyGroupToClassMap(base, groupCtrl.text);
                      ensureDefaultSelection();
                    });
                  },
                ),
                TextField(
                  controller: prefixCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Prefix (optional, e.g., J2)'),
                  onChanged: (_) {
                    if (!combineSections) return;
                    setState(() {
                      final base = _mergeSections(byClass,
                          enabled: combineSections,
                          userPrefix: prefixCtrl.text.trim());
                      previewMap = _applyGroupToClassMap(base, groupCtrl.text);
                      ensureDefaultSelection();
                    });
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: groupCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Group (optional, e.g., 4 or 6)'),
                  onChanged: (_) {
                    setState(() {
                      final base = _mergeSections(byClass,
                          enabled: combineSections,
                          userPrefix: prefixCtrl.text.trim());
                      previewMap = _applyGroupToClassMap(base, groupCtrl.text);
                      ensureDefaultSelection();
                    });
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                Text('New class settings (applies to all new classes):',
                    style: context.textStyles.titleSmall),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                    controller: subjectCtrl,
                    decoration: const InputDecoration(labelText: 'Subject')),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                    controller: yearCtrl,
                    decoration:
                        const InputDecoration(labelText: 'School Year')),
                const SizedBox(height: AppSpacing.sm),
                DropdownButtonFormField<String>(
                  initialValue: selectedTerm,
                  decoration: const InputDecoration(labelText: 'Term'),
                  items: const [
                    DropdownMenuItem(value: 'Fall', child: Text('Fall')),
                    DropdownMenuItem(value: 'Spring', child: Text('Spring')),
                    DropdownMenuItem(value: 'Summer', child: Text('Summer')),
                    DropdownMenuItem(value: 'Winter', child: Text('Winter')),
                  ],
                  onChanged: (v) => setState(() => selectedTerm = v ?? 'Fall'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Import')),
          ],
        ),
      ),
    );

    if (proceed != true || !mounted) return;

    // Apply combine if selected
    final baseMap = combineSections
        ? _mergeSections(byClass,
            enabled: true, userPrefix: prefixCtrl.text.trim())
        : byClass;
    final effectiveMapAll = _applyGroupToClassMap(baseMap, groupCtrl.text);
    final effectiveMap = <String, List<ImportedStudent>>{};
    for (final e in effectiveMapAll.entries) {
      if (selectedClassKeys.contains(e.key)) {
        effectiveMap[e.key] = e.value;
      }
    }
    if (effectiveMap.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No target classes selected for import'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      return;
    }
    final newClassCount = effectiveMap.keys
        .where((k) => !existingByName.containsKey(k.toLowerCase()))
        .length;
    final selectedRows =
        effectiveMap.values.fold<int>(0, (sum, list) => sum + list.length);
    final confirmWrite = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm roster import'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Target classes: ${effectiveMap.length}'),
              Text('Student rows selected: $selectedRows'),
              Text('New classes to create: $newClassCount'),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Preview:',
                style: Theme.of(ctx).textTheme.titleSmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 180),
                child: ListView(
                  shrinkWrap: true,
                  children: effectiveMap.entries.take(20).map((e) {
                    final count = e.value.length;
                    final willCreate =
                        !existingByName.containsKey(e.key.toLowerCase());
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(e.key),
                      subtitle: Text(
                          '$count student${count == 1 ? '' : 's'} • ${willCreate ? 'create class' : 'existing class'}'),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm import'),
          ),
        ],
      ),
    );
    if (confirmWrite != true || !mounted) return;

    final groupDigits = _extractGroupDigits(groupCtrl.text);

    // Create any missing classes
    final now = DateTime.now();
    final toCreate = <Class>[];
    final toCreateKeys = effectiveMap.keys
        .where((k) => !existingByName.containsKey(k.toLowerCase()))
        .toList();
    for (final code in toCreateKeys) {
      toCreate.add(Class(
        classId: const Uuid().v4(),
        className: code,
        subject: subjectCtrl.text.isEmpty ? 'General' : subjectCtrl.text.trim(),
        groupNumber: groupDigits.isEmpty ? null : groupDigits,
        schoolYear: yearCtrl.text.isEmpty ? '2024-2025' : yearCtrl.text.trim(),
        term: selectedTerm,
        teacherId: auth.currentUser!.userId,
        createdAt: now,
        updatedAt: now,
      ));
    }

    final catService = context.read<GradingCategoryService>();
    final studentService = context.read<StudentService>();
    int addedStudents = 0;
    int touchedClasses = 0;

    for (final c in toCreate) {
      await classService.addClass(c);
      await catService.seedDefaultCategories(c.classId);
      existingByName[c.className.toLowerCase()] = c;
    }

    // For each class code group, add students to the class
    for (final entry in effectiveMap.entries) {
      final code = entry.key.toLowerCase();
      final targetClass = existingByName[code];
      if (targetClass == null) continue;

      // Avoid duplicates: load existing students and filter new list
      await studentService.loadStudents(targetClass.classId);
      final existingIds =
          studentService.students.map((s) => s.studentId).toSet();

      final students = _importService
          .convertToStudents(entry.value, targetClass.classId)
          .where((s) => !existingIds.contains(s.studentId))
          .toList();
      if (students.isNotEmpty) {
        await studentService.addStudents(students);
        touchedClasses++;
        addedStudents += students.length;
      }
    }

    await classService.loadClasses(auth.currentUser!.userId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'Imported $addedStudents students into $touchedClasses class${touchedClasses == 1 ? '' : 'es'}')));
  }

  Future<String?> _showImportDiagnosticsDialog({
    required String title,
    required String filename,
    required Uint8List bytes,
    String? hint,
  }) async {
    if (!mounted) return null;
    final diagnostics =
        _importService.diagnosticsForFile(bytes, filename: filename);

    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: SelectableText(
              [
                if (hint != null && hint.trim().isNotEmpty) hint.trim(),
                diagnostics,
              ].join('\n\n'),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: diagnostics));
              Navigator.pop(context, 'close');
              ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(content: Text('Diagnostics copied')));
            },
            child: const Text('Copy diagnostics'),
          ),
          TextButton(
            onPressed: OpenAIConfig.isConfigured
                ? () => Navigator.pop(context, 'ai')
                : null,
            child: const Text('Analyze with AI'),
          ),
          FilledButton(
              onPressed: () => Navigator.pop(context, 'close'),
              child: const Text('Close')),
        ],
      ),
    );
  }

  // Combine section letters into a single class key (e.g., J2F + J2G => J2FG)
  Map<String, List<ImportedStudent>> _mergeSections(
      Map<String, List<ImportedStudent>> input,
      {required bool enabled,
      String? userPrefix}) {
    if (!enabled) return input;
    final Map<String, List<ImportedStudent>> byBase = {};
    final Map<String, Set<String>> suffixesByBase = {};
    String normalize(String s) => s.replaceAll(' ', '');

    for (final entry in input.entries) {
      final codeRaw = normalize(entry.key);
      final reg = RegExp(r'^([A-Za-z]*\d+)([A-Za-z]+)$');
      String base;
      String suffix;
      final m = reg.firstMatch(codeRaw);
      if (m != null) {
        base = m.group(1)!;
        suffix = m.group(2)!;
      } else if (RegExp(r'^[A-Za-z]+$').hasMatch(codeRaw) &&
          (userPrefix != null && userPrefix.trim().isNotEmpty)) {
        base = normalize(userPrefix);
        suffix = codeRaw;
      } else {
        base = codeRaw;
        suffix = '';
      }
      byBase.putIfAbsent(base, () => []);
      byBase[base]!.addAll(entry.value);
      suffixesByBase.putIfAbsent(base, () => <String>{});
      if (suffix.isNotEmpty) suffixesByBase[base]!.addAll(suffix.split(''));
    }

    final Map<String, List<ImportedStudent>> merged = {};
    for (final base in byBase.keys) {
      final suffixes = suffixesByBase[base] ?? {};
      if (suffixes.length > 1) {
        final letters = suffixes.toList()..sort();
        merged['$base${letters.join()}'] = byBase[base]!;
      } else {
        if (suffixes.isEmpty && input.containsKey(base)) {
          merged[base] = input[base]!;
        } else {
          merged[base + (suffixes.isEmpty ? '' : suffixes.first)] =
              byBase[base]!;
        }
      }
    }
    return merged;
  }

  String _guessPrefixFromKeys(Iterable<String> keys) {
    final reg = RegExp(r'^([A-Za-z]*\d+)');
    final prefixes = <String>{};
    for (final k in keys) {
      final m = reg.firstMatch(k.replaceAll(' ', ''));
      if (m != null) prefixes.add(m.group(1)!);
    }
    if (prefixes.length == 1) return prefixes.first;
    return '';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  String _classOrderKey(String teacherId) => 'class_order_$teacherId';

  Future<void> _loadClassOrder(String teacherId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(_classOrderKey(teacherId)) ?? const [];
      if (!mounted) return;
      setState(() => _activeClassOrder = List<String>.from(saved));
    } catch (e) {
      debugPrint('Failed to load class order: $e');
    }
  }

  Future<void> _saveClassOrder(String teacherId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_classOrderKey(teacherId), _activeClassOrder);
    } catch (e) {
      debugPrint('Failed to save class order: $e');
    }
  }

  List<Class> _orderedActiveClasses(List<Class> active) {
    final activeById = {for (final c in active) c.classId: c};
    final cleanedOrder = _activeClassOrder
        .where((id) => activeById.containsKey(id))
        .toList(growable: true);
    final missing = active
        .where((c) => !cleanedOrder.contains(c.classId))
        .toList()
      ..sort((a, b) =>
          a.className.toLowerCase().compareTo(b.className.toLowerCase()));
    cleanedOrder.addAll(missing.map((c) => c.classId));

    if (!listEquals(cleanedOrder, _activeClassOrder)) {
      _activeClassOrder = cleanedOrder;
      final teacherId = context.read<AuthService>().currentUser?.userId;
      if (teacherId != null && teacherId.isNotEmpty) {
        unawaited(_saveClassOrder(teacherId));
      }
    }

    final orderIndex = <String, int>{
      for (int i = 0; i < cleanedOrder.length; i++) cleanedOrder[i]: i
    };
    final ordered = List<Class>.from(active);
    ordered.sort((a, b) {
      final ai = orderIndex[a.classId] ?? 1 << 20;
      final bi = orderIndex[b.classId] ?? 1 << 20;
      return ai.compareTo(bi);
    });
    return ordered;
  }

  Future<void> _reorderActiveClasses(
      int oldIndex, int newIndex, List<Class> orderedActive) async {
    if (newIndex > oldIndex) newIndex -= 1;
    final ids = orderedActive.map((e) => e.classId).toList(growable: true);
    if (oldIndex < 0 ||
        oldIndex >= ids.length ||
        newIndex < 0 ||
        newIndex >= ids.length) {
      return;
    }
    final moved = ids.removeAt(oldIndex);
    ids.insert(newIndex, moved);
    setState(() => _activeClassOrder = ids);

    final teacherId = context.read<AuthService>().currentUser?.userId;
    if (teacherId != null && teacherId.isNotEmpty) {
      await _saveClassOrder(teacherId);
    }
  }

  Future<void> _showEditClassDialog(Class classItem) async {
    final nameController = TextEditingController(text: classItem.className);
    final subjectController = TextEditingController(text: classItem.subject);
    final groupController =
        TextEditingController(text: classItem.groupNumber ?? '');
    final yearController = TextEditingController(text: classItem.schoolYear);
    final termController = TextEditingController(text: classItem.term);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Class'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Class Name')),
              const SizedBox(height: AppSpacing.md),
              TextField(
                  controller: subjectController,
                  decoration: const InputDecoration(labelText: 'Subject')),
              const SizedBox(height: AppSpacing.md),
              TextField(
                  controller: groupController,
                  decoration: const InputDecoration(labelText: 'Group Number')),
              const SizedBox(height: AppSpacing.md),
              TextField(
                  controller: yearController,
                  decoration: const InputDecoration(labelText: 'School Year')),
              const SizedBox(height: AppSpacing.md),
              TextField(
                  controller: termController,
                  decoration: const InputDecoration(labelText: 'Term')),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save')),
        ],
      ),
    );

    if (result == true && mounted) {
      final updated = classItem.copyWith(
        className: nameController.text.trim().isEmpty
            ? classItem.className
            : nameController.text.trim(),
        subject: subjectController.text.trim().isEmpty
            ? classItem.subject
            : subjectController.text.trim(),
        groupNumber: groupController.text.trim().isEmpty
            ? null
            : groupController.text.trim(),
        schoolYear: yearController.text.trim().isEmpty
            ? classItem.schoolYear
            : yearController.text.trim(),
        term: termController.text.trim().isEmpty
            ? classItem.term
            : termController.text.trim(),
        updatedAt: DateTime.now(),
      );
      await context.read<ClassService>().updateClass(updated);
    }
  }

  String _nextSchoolYear(String value) {
    final trimmed = value.trim();
    final range = RegExp(r'^(\d{4})\s*[-/]\s*(\d{2,4})$').firstMatch(trimmed);
    if (range != null) {
      final start = int.tryParse(range.group(1)!);
      final endRaw = range.group(2)!;
      if (start != null) {
        final normalizedEnd = endRaw.length == 2
            ? int.tryParse('${start.toString().substring(0, 2)}$endRaw')
            : int.tryParse(endRaw);
        if (normalizedEnd != null) {
          return '${start + 1}-${normalizedEnd + 1}';
        }
      }
    }
    final single = RegExp(r'^(\d{4})$').firstMatch(trimmed);
    if (single != null) {
      final year = int.tryParse(single.group(1)!);
      if (year != null) return '${year + 1}-${year + 2}';
    }
    return trimmed;
  }

  String _nextTerm(String term) {
    final t = term.trim().toLowerCase();
    if (t == 'fall' || t == 'autumn') return 'Spring';
    if (t == 'spring') return 'Fall';
    if (t == 'summer') return 'Fall';
    if (t == 'winter') return 'Spring';
    return term;
  }

  Future<void> _showStartNewSemesterDialog(Class classItem) async {
    final nameController = TextEditingController(text: classItem.className);
    final subjectController = TextEditingController(text: classItem.subject);
    final groupController =
        TextEditingController(text: classItem.groupNumber ?? '');
    final yearController =
        TextEditingController(text: _nextSchoolYear(classItem.schoolYear));
    final termController =
        TextEditingController(text: _nextTerm(classItem.term));
    bool archiveCurrent = !classItem.isArchived;
    bool copyStudents = true;

    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Start New Semester'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Class Name'),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: subjectController,
                  decoration: const InputDecoration(labelText: 'Subject'),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: groupController,
                  decoration: const InputDecoration(labelText: 'Group Number'),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: yearController,
                  decoration: const InputDecoration(labelText: 'School Year'),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: termController,
                  decoration: const InputDecoration(labelText: 'Term'),
                ),
                const SizedBox(height: AppSpacing.sm),
                CheckboxListTile(
                  value: archiveCurrent,
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Archive current class'),
                  onChanged: classItem.isArchived
                      ? null
                      : (v) => setDialogState(() => archiveCurrent = v ?? true),
                ),
                CheckboxListTile(
                  value: copyStudents,
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Copy students into new semester class'),
                  subtitle: const Text(
                      'Grades and assessments are not copied. You can edit roster after creation.'),
                  onChanged: (v) =>
                      setDialogState(() => copyStudents = v ?? true),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Create New Semester Class'),
            ),
          ],
        ),
      ),
    );

    if (proceed != true || !mounted) return;

    final auth = context.read<AuthService>();
    final user = auth.currentUser;
    if (user == null) return;

    final className = nameController.text.trim();
    final subject = subjectController.text.trim();
    final schoolYear = yearController.text.trim();
    final term = termController.text.trim();
    if (className.isEmpty ||
        subject.isEmpty ||
        schoolYear.isEmpty ||
        term.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Class Name, Subject, School Year, and Term are required.')),
      );
      return;
    }

    final now = DateTime.now();
    final newClass = Class(
      classId: const Uuid().v4(),
      className: className,
      subject: subject,
      groupNumber: groupController.text.trim().isEmpty
          ? null
          : groupController.text.trim(),
      schoolYear: schoolYear,
      term: term,
      teacherId: user.userId,
      createdAt: now,
      updatedAt: now,
      syllabus: classItem.syllabus,
    );

    final classService = context.read<ClassService>();
    final studentService = context.read<StudentService>();
    final catService = context.read<GradingCategoryService>();
    if (archiveCurrent && !classItem.isArchived) {
      await classService.archiveClass(classItem.classId);
    }
    await classService.addClass(newClass);
    await catService.seedDefaultCategories(newClass.classId);
    if (copyStudents) {
      await studentService.loadStudents(classItem.classId);
      final oldStudents = List.of(studentService.students);
      final copied = oldStudents
          .map((s) => s.copyWith(
                classId: newClass.classId,
                createdAt: now,
                updatedAt: now,
              ))
          .toList();
      await studentService.loadStudents(newClass.classId);
      if (copied.isNotEmpty) {
        await studentService.addStudents(copied);
      }
    }
    await classService.loadClasses(user.userId);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('New semester class created.')),
    );
  }

  Future<void> _moveClassToBin(Class classItem) async {
    final auth = context.read<AuthService>();
    final classService = context.read<ClassService>();
    final trashService = context.read<ClassTrashService>();

    try {
      await trashService.addToTrash(
          DeletedClassEntry(classItem: classItem, deletedAt: DateTime.now()));
      await classService.deleteClass(classItem.classId);
      await classService.loadClasses(auth.currentUser!.userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Moved to recycle bin')));
      }
    } catch (e) {
      debugPrint('Move to bin failed for class ${classItem.classId}: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: const Text('Failed to move to bin. Please try again.'),
              backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    }
  }

  Future<void> _loadData() async {
    final authService = context.read<AuthService>();
    final classService = context.read<ClassService>();

    final user = authService.currentUser;
    if (user == null) return;

    await _loadClassOrder(user.userId);

    if (DemoDataService.isDemoUser(user)) {
      await DemoDataService.ensureDemoWorkspace(
        teacherId: user.userId,
        classService: classService,
        studentService: context.read<StudentService>(),
        categoryService: context.read<GradingCategoryService>(),
        gradeItemService: context.read<GradeItemService>(),
        scoreService: context.read<StudentScoreService>(),
        examService: context.read<FinalExamService>(),
      );
      if (!mounted) return;
      return;
    }

    await classService.loadClasses(user.userId);
  }

  Future<void> _showCreateClassDialog() async {
    final nameController = TextEditingController();
    final subjectController = TextEditingController();
    final yearController = TextEditingController(text: '2024-2025');
    final termController = TextEditingController(text: 'Fall');
    final groupController = TextEditingController();

    ClassSyllabus? pickedSyllabus;
    String? pickedSyllabusFilename;
    String? pickedSyllabusError;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('Create New Class'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                      labelText: 'Class Name', hintText: 'e.g., Grade 10A'),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: subjectController,
                  decoration: const InputDecoration(
                      labelText: 'Subject', hintText: 'e.g., Mathematics'),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: groupController,
                  decoration: const InputDecoration(
                      labelText: 'Group Number', hintText: 'e.g., A or 1'),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: yearController,
                  decoration: const InputDecoration(labelText: 'School Year'),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: termController,
                  decoration: const InputDecoration(labelText: 'Term'),
                ),
                const SizedBox(height: AppSpacing.lg),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Schedule / syllabus (optional)',
                      style: context.textStyles.titleSmall?.semiBold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        pickedSyllabusFilename == null
                            ? 'No schedule uploaded'
                            : pickedSyllabusFilename!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.textStyles.bodyMedium?.withColor(
                            Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Upload'),
                      onPressed: () async {
                        final result = await FilePicker.platform.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: const ['xlsx', 'csv'],
                          withData: true,
                        );
                        if (result == null ||
                            result.files.single.bytes == null) {
                          return;
                        }
                        final bytes = result.files.single.bytes!;
                        final filename = result.files.single.name;
                        final parsed =
                            _importService.parseClassSyllabusFromBytes(
                          bytes,
                          filename: filename,
                        );
                        setLocalState(() {
                          pickedSyllabusFilename = filename;
                          pickedSyllabus = parsed;
                          pickedSyllabusError = parsed == null
                              ? 'Could not detect a Week/Date/Lesson Content table.'
                              : null;
                        });
                      },
                    ),
                  ],
                ),
                if (pickedSyllabusError != null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      pickedSyllabusError!,
                      style: context.textStyles.bodySmall
                          ?.withColor(Theme.of(context).colorScheme.error),
                    ),
                  ),
                ]
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );

    if (!mounted) return;

    if (result == true) {
      final authService = context.read<AuthService>();
      final now = DateTime.now();
      final newClass = Class(
        classId: const Uuid().v4(),
        className: nameController.text,
        subject: subjectController.text,
        groupNumber: groupController.text.isEmpty ? null : groupController.text,
        schoolYear: yearController.text,
        term: termController.text,
        teacherId: authService.currentUser!.userId,
        createdAt: now,
        updatedAt: now,
        syllabus: pickedSyllabus,
      );

      debugPrint(
          'Create Class: ${newClass.className} for teacher=${authService.currentUser!.userId}');
      final classService = context.read<ClassService>();
      final catService = context.read<GradingCategoryService>();
      await classService.addClass(newClass);
      await catService.seedDefaultCategories(newClass.classId);
      if (!mounted) return;
      // Force refresh to ensure the grid reflects the new class immediately
      await classService.loadClasses(authService.currentUser!.userId);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Class created')));
    }
  }

  Future<void> _showImportClassesDialog() async {
    final picked = await _pickBytesUnified(
        extensions: const ['xlsx', 'csv'],
        title: 'Import from Google Drive or local file');
    if (picked == null || !mounted) return;

    final name = picked.filename.toLowerCase();
    final filename = picked.filename;
    final bytes = picked.bytes;
    if (!await _guardImportTypeForClassScreen(
      bytes: bytes,
      filename: filename,
    )) {
      return;
    }

    // First: detect roster files (even if missing ClassCode) to avoid treating student names as class names.
    List<ImportedStudent> rosterParsed = const [];
    try {
      rosterParsed = name.endsWith('.xlsx')
          ? _importService.parseXlsxRoster(bytes,
              teacherName: _currentTeacherName())
          : _importService.parseCSV(_importService.decodeTextFromBytes(bytes));
      if (rosterParsed.isEmpty && name.endsWith('.xlsx')) {
        rosterParsed =
            _importService.parseCSV(_importService.decodeTextFromBytes(bytes));
      }
    } catch (_) {
      rosterParsed = const [];
    }

    if (_looksLikeRoster(rosterParsed)) {
      final rosterValidWithClass = rosterParsed
          .where((r) => r.isValid && (r.classCode?.trim().isNotEmpty ?? false))
          .length;
      if (rosterValidWithClass > 0) {
        await _importRostersToClassesFromBytes(
            bytes: bytes, filename: filename);
        return;
      }
      await _importRosterIntoSingleClass(
          parsed: rosterParsed, filename: filename, bytes: bytes);
      return;
    }
    final imported = name.endsWith('.xlsx')
        ? _importService.parseClassesXlsx(bytes)
        : _importService
            .parseClassesCsv(_importService.decodeTextFromBytes(bytes));

    var parsed = (imported.isEmpty && name.endsWith('.xlsx'))
        ? _importService
            .parseClassesCsv(_importService.decodeTextFromBytes(bytes))
        : imported;

    if (parsed.isEmpty) {
      debugPrint('Import: class parser returned 0 items for $name');

      // If the file looks like a roster, import classes + students from it directly.
      try {
        final roster = name.endsWith('.xlsx')
            ? _importService.parseXlsxRoster(bytes,
                teacherName: _currentTeacherName())
            : _importService
                .parseCSV(_importService.decodeTextFromBytes(bytes));
        final rosterValid = roster
            .where(
                (r) => r.isValid && (r.classCode?.trim().isNotEmpty ?? false))
            .length;
        if (rosterValid > 0) {
          await _importRostersToClassesFromBytes(
              bytes: bytes, filename: filename);
          return;
        }
      } catch (_) {
        // ignore; fall through to diagnostics
      }

      final action = await _showImportDiagnosticsDialog(
        title: 'Could not read this file',
        filename: filename,
        bytes: bytes,
        hint: 'Tip: Export as CSV (UTF-8) and retry.',
      );

      if (!mounted || action != 'ai') return;

      // Use AI to parse classes
      final rows = _importService.rowsFromAnyBytes(bytes);
      final aiResult = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (ctx) => AiAnalyzeImportDialog(
          title: 'Analyze class list with AI',
          filename: filename,
          analyze: () => AiImportService()
              .analyzeClassesFromRows(rows, filename: filename),
          confirmLabel: 'Use these classes',
        ),
      );

      if (!mounted || aiResult == null) return;

      // Convert AI output to ImportedClass list
      final aiClasses = <ImportedClass>[];
      final rawClasses = aiResult['classes'];
      if (rawClasses is List) {
        for (final c in rawClasses) {
          if (c is Map) {
            final className = (c['className'] ?? '').toString().trim();
            if (className.isNotEmpty) {
              aiClasses.add(ImportedClass(
                className: className,
                subject: (c['subject'] ?? '').toString().trim(),
                schoolYear: (c['schoolYear'] ?? '').toString().trim(),
                term: (c['term'] ?? '').toString().trim(),
                isValid: true,
              ));
            }
          }
        }
      }

      if (aiClasses.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('AI did not return any classes.')));
        return;
      }

      // Replace parsed with AI result and continue with normal flow
      parsed = aiClasses;
    }

    final valid = parsed.where((i) => i.isValid).toList();
    final invalid = parsed.where((i) => !i.isValid).toList();

    // If we have 0 valid classes, attempt roster parsing (best-effort) before treating rows as classes.
    if (valid.isEmpty) {
      try {
        final roster = name.endsWith('.xlsx')
            ? _importService.parseXlsxRoster(bytes,
                teacherName: _currentTeacherName())
            : _importService
                .parseCSV(_importService.decodeTextFromBytes(bytes));
        if (_looksLikeRoster(roster)) {
          final rosterValidWithClass = roster
              .where(
                  (r) => r.isValid && (r.classCode?.trim().isNotEmpty ?? false))
              .length;
          if (rosterValidWithClass > 0) {
            await _importRostersToClassesFromBytes(
                bytes: bytes, filename: filename);
            return;
          }
          await _importRosterIntoSingleClass(
              parsed: roster, filename: filename, bytes: bytes);
          return;
        }
      } catch (_) {
        // ignore; proceed with class error dialog
      }

      // If we have class names but missing metadata, prompt for defaults and import anyway.
      final candidates = invalid
          .where((c) => (c.className ?? '').trim().isNotEmpty)
          .map((c) => c.className!.trim())
          .toSet()
          .toList()
        ..sort();

      if (candidates.isNotEmpty) {
        final subjectCtrl = TextEditingController(text: 'General');
        final yearCtrl = TextEditingController(text: '2025-2026');
        final termCtrl = TextEditingController(text: 'Spring');

        final proceedDefaults = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Import Classes (Missing details)'),
            content: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      'Found ${candidates.length} class name${candidates.length == 1 ? '' : 's'} but the file is missing School Year and/or Term.'),
                  const SizedBox(height: AppSpacing.sm),
                  Text('Choose defaults to apply to all imported classes:',
                      style: context.textStyles.titleSmall),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                      controller: subjectCtrl,
                      decoration: const InputDecoration(labelText: 'Subject')),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                      controller: yearCtrl,
                      decoration:
                          const InputDecoration(labelText: 'School Year')),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                      controller: termCtrl,
                      decoration: const InputDecoration(labelText: 'Term')),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                      'Examples: ${candidates.take(3).join(', ')}${candidates.length > 3 ? ', …' : ''}',
                      style: context.textStyles.bodySmall),
                ],
              ),
            ),
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

        if (!mounted) return;
        if (proceedDefaults == true) {
          final auth = context.read<AuthService>();
          final classService = context.read<ClassService>();
          final catService = context.read<GradingCategoryService>();
          final now = DateTime.now();
          final existingByName = {
            for (final c in classService.classes) c.className.toLowerCase(): c
          };

          int created = 0;
          for (final name in candidates) {
            if (existingByName.containsKey(name.toLowerCase())) continue;
            final newClass = Class(
              classId: const Uuid().v4(),
              className: name,
              subject: subjectCtrl.text.trim().isEmpty
                  ? 'General'
                  : subjectCtrl.text.trim(),
              groupNumber: null,
              schoolYear: yearCtrl.text.trim().isEmpty
                  ? '2025-2026'
                  : yearCtrl.text.trim(),
              term: termCtrl.text.trim().isEmpty
                  ? 'Spring'
                  : termCtrl.text.trim(),
              teacherId: auth.currentUser!.userId,
              createdAt: now,
              updatedAt: now,
            );
            await classService.addClass(newClass);
            await catService.seedDefaultCategories(newClass.classId);
            created++;
          }

          await classService.loadClasses(auth.currentUser!.userId);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content:
                  Text('Imported $created class${created == 1 ? '' : 'es'}')));
          return;
        }
      }
    }

    final auth = context.read<AuthService>();
    final classService = context.read<ClassService>();
    final catService = context.read<GradingCategoryService>();
    final messenger = ScaffoldMessenger.of(context);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Import Classes'),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Valid classes: ${valid.length}'),
              Text('Invalid classes: ${invalid.length}',
                  style: TextStyle(
                      color: Theme.of(dialogContext).colorScheme.error)),
              if (invalid.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Text('Errors (first 3):',
                    style: dialogContext.textStyles.titleSmall),
                ...invalid.take(3).map((e) => Text('• ${e.error}',
                    style: dialogContext.textStyles.bodySmall)),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Import')),
        ],
      ),
    );

    if (!mounted) return;
    if (confirm != true) return;

    final classes =
        _importService.convertToClasses(valid, auth.currentUser!.userId);
    for (final c in classes) {
      await classService.addClass(c);
      await catService.seedDefaultCategories(c.classId);
    }
    await classService.loadClasses(auth.currentUser!.userId);
    if (!mounted) return;
    messenger.showSnackBar(
        SnackBar(content: Text('Imported ${classes.length} classes')));
  }

  // Note: there is no separate "Import Rosters" entrypoint; the Import action auto-detects roster files.

  Widget _buildClassTile({
    required Class classItem,
    required bool archived,
    Widget? dragHandle,
  }) {
    return Stack(
      children: [
        ClassCard(
          classItem: classItem,
          onTap: () => context.push('/class/${classItem.classId}'),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (dragHandle != null)
                Padding(
                  padding: const EdgeInsets.only(right: 2),
                  child: dragHandle,
                ),
              Material(
                color: Colors.transparent,
                child: PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                  onSelected: (value) async {
                    if (value == 'archive') {
                      await context
                          .read<ClassService>()
                          .archiveClass(classItem.classId);
                    } else if (value == 'unarchive') {
                      await context
                          .read<ClassService>()
                          .unarchiveClass(classItem.classId);
                    } else if (value == 'edit') {
                      await _showEditClassDialog(classItem);
                    } else if (value == 'rollover') {
                      await _showStartNewSemesterDialog(classItem);
                    } else if (value == 'delete') {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Move to recycle bin?'),
                          content: const Text(
                              'You can restore it later from the Class Recycle Bin.'),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel')),
                            FilledButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Move')),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await _moveClassToBin(classItem);
                      }
                    }
                  },
                  itemBuilder: (ctx) {
                    if (archived) {
                      return const [
                        PopupMenuItem(
                            value: 'rollover',
                            child: Text('Start New Semester')),
                        PopupMenuItem(
                            value: 'unarchive', child: Text('Unarchive')),
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ];
                    }
                    return const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(
                          value: 'rollover',
                          child: Text('Archive + New Semester')),
                      PopupMenuItem(value: 'archive', child: Text('Archive')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ];
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCollectionToolbar(ClassService classService) {
    final theme = Theme.of(context);
    final count = _showArchived
        ? classService.archivedClasses.length
        : classService.activeClasses.length;
    final summary = _showArchived
        ? '$count archived class${count == 1 ? '' : 'es'} kept ready for rollover, restore, and reporting.'
        : '$count active class${count == 1 ? '' : 'es'} ready to open, act on, and reorder around your teaching day.';
    final canReorder = !_showArchived && classService.activeClasses.length > 1;
    final importReady = _driveAccessToken != null;

    Widget statusPill({
      required IconData icon,
      required String label,
      Color? accent,
    }) {
      final resolvedAccent = accent ?? theme.colorScheme.primary;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: resolvedAccent.withValues(alpha: 0.10),
          border: Border.all(
            color: resolvedAccent.withValues(alpha: 0.18),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: resolvedAccent),
            const SizedBox(width: 6),
            Text(
              label,
              style: context.textStyles.labelMedium?.copyWith(
                color: resolvedAccent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    final filterGroup = Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.32),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.24),
        ),
      ),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          ChoiceChip(
            label: const Text('Active'),
            selected: !_showArchived,
            onSelected: (_) => setState(() => _showArchived = false),
          ),
          ChoiceChip(
            label: const Text('Archived'),
            selected: _showArchived,
            onSelected: (_) => setState(() => _showArchived = true),
          ),
        ],
      ),
    );

    final status = Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        statusPill(
          icon: _showArchived ? Icons.inventory_2_outlined : Icons.class_rounded,
          label: '$count ${_showArchived ? 'archived' : 'active'}',
          accent: _showArchived
              ? theme.colorScheme.secondary
              : theme.colorScheme.primary,
        ),
        statusPill(
          icon: importReady
              ? Icons.cloud_done_outlined
              : Icons.file_upload_outlined,
          label: importReady ? 'Drive connected' : 'Local import ready',
          accent: importReady
              ? theme.colorScheme.tertiary
              : theme.colorScheme.primary,
        ),
        if (canReorder)
          statusPill(
            icon: Icons.drag_indicator_rounded,
            label: 'Drag to reorder',
            accent: theme.colorScheme.onSurfaceVariant,
          ),
      ],
    );

    return WorkspaceContextBar(
      subtitle: summary,
      leading: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          filterGroup,
          status,
        ],
      ),
      trailing: Wrap(
        spacing: 10,
        runSpacing: 10,
        alignment: WrapAlignment.end,
        children: [
          FilledButton.icon(
            onPressed: _showCreateClassDialog,
            icon: const Icon(Icons.add),
            label: const Text('Create Class'),
          ),
          OutlinedButton.icon(
            onPressed: _showImportClassesDialog,
            icon: const Icon(Icons.upload_file_outlined),
            label: const Text('Import'),
          ),
        ],
      ),
    );
  }

  Widget _buildCollectionShell(ClassService classService) {
    final showing = _showArchived
        ? classService.archivedClasses
        : classService.activeClasses;

    Widget content;
    if (classService.isLoading) {
      content = const Center(child: CircularProgressIndicator());
    } else if (showing.isEmpty) {
      content = WorkspaceEmptyState(
        icon:
            _showArchived ? Icons.inventory_2_outlined : Icons.school_outlined,
        title: _showArchived ? 'No archived classes yet' : 'No classes yet',
        subtitle: _showArchived
            ? 'Archived classes and semester rollovers will appear here when you need them.'
            : 'Create your first class or import rosters from Excel, CSV, or Drive to start building your workspace.',
        actions: _showArchived
            ? [
                OutlinedButton.icon(
                  onPressed: () => setState(() => _showArchived = false),
                  icon: const Icon(Icons.class_rounded),
                  label: const Text('View active classes'),
                ),
              ]
            : [
                FilledButton.icon(
                  onPressed: _showCreateClassDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Create Class'),
                ),
                OutlinedButton.icon(
                  onPressed: _showImportClassesDialog,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Import'),
                ),
              ],
      );
    } else if (_showArchived) {
      content = GridView.builder(
        padding: EdgeInsets.zero,
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 380,
          childAspectRatio: 1.22,
          crossAxisSpacing: AppSpacing.md,
          mainAxisSpacing: AppSpacing.md,
        ),
        itemCount: classService.archivedClasses.length,
        itemBuilder: (context, index) {
          final classItem = classService.archivedClasses[index];
          return _buildClassTile(
            classItem: classItem,
            archived: true,
          );
        },
      );
    } else {
      content = Builder(
        builder: (context) {
          final orderedActive =
              _orderedActiveClasses(classService.activeClasses);
          return ReorderableListView.builder(
            padding: EdgeInsets.zero,
            itemCount: orderedActive.length,
            onReorder: (oldIndex, newIndex) =>
                _reorderActiveClasses(oldIndex, newIndex, orderedActive),
            proxyDecorator: (child, index, animation) => Material(
              elevation: 6,
              color: Colors.transparent,
              child: child,
            ),
            buildDefaultDragHandles: false,
            itemBuilder: (context, index) {
              final classItem = orderedActive[index];
              return Padding(
                key: ValueKey(classItem.classId),
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: SizedBox(
                  height: 228,
                  child: _buildClassTile(
                    classItem: classItem,
                    archived: false,
                    dragHandle: ReorderableDragStartListener(
                      index: index,
                      child: Icon(
                        Icons.drag_indicator_rounded,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
    }

    return content;
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final classService = context.watch<ClassService>();
    final themeModeNotifier = context.watch<ThemeModeNotifier>();
    return WorkspaceScaffold(
      eyebrow: 'Teacher Workspace',
      title: 'Classes workspace',
      subtitle:
          'Manage rosters, imports, class lifecycle, and semester rollover from one place that feels ready for daily use.',
      trailingActions: [
        TextButton.icon(
          onPressed: _driveSigningIn ? null : _ensureDriveAccessToken,
          icon: _driveSigningIn
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                )
              : Icon(
                  _driveAccessToken == null
                      ? Icons.login
                      : Icons.cloud_done_outlined,
                ),
          label:
              Text(_driveAccessToken == null ? 'Connect Drive' : 'Drive ready'),
        ),
        OutlinedButton.icon(
          onPressed: () => context.push(AppRoutes.classTrash),
          icon: const Icon(Icons.restore_from_trash_outlined),
          label: const Text('Recycle bin'),
        ),
        const PilotFeedbackIconButton(
          initialArea: 'Classes',
          initialRoute: '/classes',
        ),
        IconButton(
          tooltip: 'Toggle theme',
          icon: Icon(
            themeModeNotifier.themeMode == ThemeMode.light
                ? Icons.dark_mode
                : Icons.light_mode,
          ),
          onPressed: () => themeModeNotifier.toggleTheme(),
        ),
        IconButton(
          tooltip: 'Log out',
          icon: const Icon(Icons.logout),
          onPressed: () async {
            await context.read<GoogleAuthService>().signOut();
            await authService.logout();
            if (context.mounted) context.go('/');
          },
        ),
      ],
      contextBar: _buildCollectionToolbar(classService),
      child: _buildCollectionShell(classService),
    );
  }
}

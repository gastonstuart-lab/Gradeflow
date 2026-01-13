import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:typed_data';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:gradeflow/services/auth_service.dart';
import 'package:gradeflow/services/class_service.dart';
import 'package:gradeflow/services/student_service.dart';
import 'package:gradeflow/services/grading_category_service.dart';
import 'package:http/http.dart' as http;
import 'package:gradeflow/theme.dart';
import 'package:gradeflow/components/school_banner.dart';
import 'package:gradeflow/providers/app_providers.dart';
import 'package:gradeflow/components/class_card.dart';
import 'package:uuid/uuid.dart';
import 'package:file_picker/file_picker.dart';
import 'package:gradeflow/services/file_import_service.dart';
import 'package:gradeflow/services/drive_import_service.dart';
import 'package:gradeflow/services/google_auth_service.dart';
import 'package:gradeflow/services/google_drive_service.dart';
import 'package:gradeflow/components/drive_file_picker_dialog.dart';
import 'package:gradeflow/models/class.dart';
import 'package:gradeflow/nav.dart';
import 'package:gradeflow/models/deleted_class_entry.dart';
import 'package:gradeflow/services/class_trash_service.dart';

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
  final GoogleDriveService _googleDriveService = GoogleDriveService();
  String? _driveAccessToken;
  bool _driveSigningIn = false;
  bool _showArchived = false;

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
    if (lower.contains('pe') || lower.contains('phys ed'))
      return 'Physical Education';
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
    if (RegExp(r'\(g\d+\)\s*$', caseSensitive: false).hasMatch(className))
      return className;
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

    final picked = await showDialog<DriveFile?>(
      context: context,
      builder: (ctx) => DriveFilePickerDialog(
        driveService: _googleDriveService,
        allowedExtensions: extensions,
      ),
    );

    if (picked == null) return null;

    try {
      final bytes = await _googleDriveService.downloadFileBytesFor(
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
                    value: selectedClassId,
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
                    value: selectedTerm,
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
        ? _importService.parseXlsxRoster(bytes)
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
                  value: selectedTerm,
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
    final effectiveMap = _applyGroupToClassMap(baseMap, groupCtrl.text);
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
      }
    }

    await classService.loadClasses(auth.currentUser!.userId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'Imported ${valid.length} students across ${effectiveMap.length} classes')));
  }

  Future<void> _showImportDiagnosticsDialog({
    required String title,
    required String filename,
    required Uint8List bytes,
    String? hint,
  }) async {
    if (!mounted) return;
    final diagnostics =
        _importService.diagnosticsForFile(bytes, filename: filename);

    await showDialog<void>(
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
              Navigator.pop(context);
              ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(content: Text('Diagnostics copied')));
            },
            child: const Text('Copy diagnostics'),
          ),
          FilledButton(
              onPressed: () => Navigator.pop(context),
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

    if (authService.currentUser != null) {
      await classService.loadClasses(authService.currentUser!.userId);
      if (!mounted) return;

      if (classService.classes.isEmpty) {
        await classService.seedDemoClasses(authService.currentUser!.userId);
        if (!mounted) return;
        await classService.loadClasses(authService.currentUser!.userId);
        if (!mounted) return;

        final studentService = context.read<StudentService>();
        final catService = context.read<GradingCategoryService>();

        for (var classItem in classService.classes) {
          await studentService.seedDemoStudents(classItem.classId);
          await catService.seedDefaultCategories(classItem.classId);
        }
      }
    }
  }

  Future<void> _showCreateClassDialog() async {
    final nameController = TextEditingController();
    final subjectController = TextEditingController();
    final yearController = TextEditingController(text: '2024-2025');
    final termController = TextEditingController(text: 'Fall');
    final groupController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
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

    // First: detect roster files (even if missing ClassCode) to avoid treating student names as class names.
    List<ImportedStudent> rosterParsed = const [];
    try {
      rosterParsed = name.endsWith('.xlsx')
          ? _importService.parseXlsxRoster(bytes)
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

    final parsed = (imported.isEmpty && name.endsWith('.xlsx'))
        ? _importService
            .parseClassesCsv(_importService.decodeTextFromBytes(bytes))
        : imported;

    if (parsed.isEmpty) {
      debugPrint('Import: class parser returned 0 items for $name');

      // If the file looks like a roster, import classes + students from it directly.
      try {
        final roster = name.endsWith('.xlsx')
            ? _importService.parseXlsxRoster(bytes)
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

      await _showImportDiagnosticsDialog(
        title: 'Could not read this file',
        filename: filename,
        bytes: bytes,
        hint: 'Tip: Export as CSV (UTF-8) and retry.',
      );
      return;
    }

    final valid = parsed.where((i) => i.isValid).toList();
    final invalid = parsed.where((i) => !i.isValid).toList();

    // If we have 0 valid classes, attempt roster parsing (best-effort) before treating rows as classes.
    if (valid.isEmpty) {
      try {
        final roster = name.endsWith('.xlsx')
            ? _importService.parseXlsxRoster(bytes)
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

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final classService = context.watch<ClassService>();
    final themeModeNotifier = context.watch<ThemeModeNotifier>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Classes'),
        leading: IconButton(
          icon: const Icon(Icons.dashboard_outlined),
          tooltip: 'Dashboard',
          onPressed: () => context.go(AppRoutes.dashboard),
        ),
        actions: [
          IconButton(
            icon: _driveSigningIn
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  )
                : const Icon(Icons.login),
            tooltip: _driveAccessToken == null
                ? 'Sign in with Google (Drive)'
                : 'Google Drive connected',
            onPressed: _driveSigningIn ? null : _ensureDriveAccessToken,
          ),
          IconButton(
            icon: const Icon(Icons.upload_file),
            onPressed: _showImportClassesDialog,
            tooltip: 'Import (Classes + Students)',
          ),
          IconButton(
            icon: const Icon(Icons.restore_from_trash_outlined),
            onPressed: () => context.push(AppRoutes.classTrash),
            tooltip: 'Class Recycle Bin',
          ),
          IconButton(
            icon: Icon(themeModeNotifier.themeMode == ThemeMode.light
                ? Icons.dark_mode
                : Icons.light_mode),
            onPressed: () => themeModeNotifier.toggleTheme(),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await context.read<GoogleAuthService>().signOut();
              await authService.logout();
              if (context.mounted) context.go('/');
            },
          ),
        ],
        bottom: const SchoolBannerBar(height: 56),
      ),
      body: classService.isLoading
          ? const Center(child: CircularProgressIndicator())
          : (!_showArchived
                      ? classService.activeClasses
                      : classService.archivedClasses)
                  .isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.school_outlined,
                          size: 64,
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                          _showArchived
                              ? 'No archived classes'
                              : 'No classes yet',
                          style: context.textStyles.titleLarge),
                      const SizedBox(height: AppSpacing.sm),
                      if (!_showArchived)
                        Text('Create your first class or import from Excel/CSV',
                            style: context.textStyles.bodyMedium),
                      const SizedBox(height: AppSpacing.lg),
                      if (!_showArchived)
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          alignment: WrapAlignment.center,
                          children: [
                            FilledButton.icon(
                              onPressed: _showCreateClassDialog,
                              icon: const Icon(Icons.add),
                              label: const Text('Create Class'),
                            ),
                            TextButton.icon(
                              onPressed: _showImportClassesDialog,
                              icon: const Icon(Icons.upload_file),
                              label: const Text('Import'),
                            ),
                          ],
                        ),
                    ],
                  ),
                )
              : Padding(
                  padding: AppSpacing.paddingMd,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          ChoiceChip(
                            label: const Text('Active'),
                            selected: !_showArchived,
                            onSelected: (v) =>
                                setState(() => _showArchived = false),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          ChoiceChip(
                            label: const Text('Archived'),
                            selected: _showArchived,
                            onSelected: (v) =>
                                setState(() => _showArchived = true),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          TextButton.icon(
                            onPressed: _showImportClassesDialog,
                            icon: Icon(Icons.upload_file,
                                color: Theme.of(context).colorScheme.primary),
                            label: const Text('Import'),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Expanded(
                        child: GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 400,
                            childAspectRatio: 1.5,
                            crossAxisSpacing: AppSpacing.md,
                            mainAxisSpacing: AppSpacing.md,
                          ),
                          itemCount: (!_showArchived
                                  ? classService.activeClasses
                                  : classService.archivedClasses)
                              .length,
                          itemBuilder: (context, index) {
                            final list = !_showArchived
                                ? classService.activeClasses
                                : classService.archivedClasses;
                            final classItem = list[index];
                            return Stack(
                              children: [
                                ClassCard(
                                  classItem: classItem,
                                  onTap: () => context
                                      .push('/class/${classItem.classId}'),
                                ),
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: Material(
                                    color: Colors.transparent,
                                    child: PopupMenuButton<String>(
                                      icon: Icon(Icons.more_vert,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant),
                                      onSelected: (value) async {
                                        if (value == 'archive') {
                                          await context
                                              .read<ClassService>()
                                              .archiveClass(classItem.classId);
                                        } else if (value == 'unarchive') {
                                          await context
                                              .read<ClassService>()
                                              .unarchiveClass(
                                                  classItem.classId);
                                        } else if (value == 'edit') {
                                          await _showEditClassDialog(classItem);
                                        } else if (value == 'delete') {
                                          final confirm =
                                              await showDialog<bool>(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              title: const Text(
                                                  'Move to recycle bin?'),
                                              content: const Text(
                                                  'You can restore it later from the Class Recycle Bin.'),
                                              actions: [
                                                TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                            ctx, false),
                                                    child:
                                                        const Text('Cancel')),
                                                FilledButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                            ctx, true),
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
                                        if (_showArchived) {
                                          return [
                                            const PopupMenuItem(
                                                value: 'unarchive',
                                                child: Text('Unarchive')),
                                            const PopupMenuItem(
                                                value: 'edit',
                                                child: Text('Edit')),
                                            const PopupMenuItem(
                                                value: 'delete',
                                                child: Text('Delete')),
                                          ];
                                        } else {
                                          return [
                                            const PopupMenuItem(
                                                value: 'edit',
                                                child: Text('Edit')),
                                            const PopupMenuItem(
                                                value: 'archive',
                                                child: Text('Archive')),
                                            const PopupMenuItem(
                                                value: 'delete',
                                                child: Text('Delete')),
                                          ];
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
      floatingActionButton: classService.classes.isNotEmpty
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FloatingActionButton.extended(
                  heroTag: 'newClassFab',
                  onPressed: _showCreateClassDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('New Class'),
                ),
              ],
            )
          : null,
    );
  }
}

import 'dart:async';
import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:gradeflow/components/drive_file_picker_dialog.dart';
import 'package:gradeflow/components/workspace_shell.dart';
import 'package:gradeflow/models/class.dart';
import 'package:gradeflow/models/class_schedule_item.dart';
import 'package:gradeflow/nav.dart';
import 'package:gradeflow/os/os_palette.dart';
import 'package:gradeflow/services/auth_service.dart';
import 'package:gradeflow/services/class_schedule_service.dart';
import 'package:gradeflow/services/class_service.dart';
import 'package:gradeflow/services/dashboard_preferences_service.dart';
import 'package:gradeflow/services/file_import_service.dart';
import 'package:gradeflow/services/google_auth_service.dart';
import 'package:gradeflow/services/google_drive_service.dart';
import 'package:gradeflow/theme.dart';

enum _InboxSource {
  computer,
  drive,
}

enum _InboxDestination {
  classSchedule,
  schoolCalendar,
}

class SchoolDataInboxScreen extends StatefulWidget {
  const SchoolDataInboxScreen({super.key});

  @override
  State<SchoolDataInboxScreen> createState() => _SchoolDataInboxScreenState();
}

class _SchoolDataInboxScreenState extends State<SchoolDataInboxScreen> {
  static const String _remindersPrefsBaseKey = 'dashboard_reminders_v1';
  static const String _legacyRemindersPrefsKey = 'dashboard_reminders';
  static const String _remindersMigrationFlagKey =
      'dashboard_reminders_migrated_v1';

  final DashboardPreferencesService _dashboardPreferencesService =
      const DashboardPreferencesService();
  final ClassScheduleService _classScheduleService = ClassScheduleService();
  bool _busy = false;
  _InboxSource _source = _InboxSource.computer;

  String? _storageUserId(AuthService auth) {
    if (!auth.isInitialized || auth.isLoading) return null;
    return auth.currentUser?.userId ?? 'local';
  }

  Future<void> _runImport(_InboxDestination destination) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final picked = await _pickInboxFile(destination);
      if (picked == null || !mounted) return;
      switch (destination) {
        case _InboxDestination.classSchedule:
          await _importClassSchedule(picked);
        case _InboxDestination.schoolCalendar:
          await _importSchoolCalendar(picked);
      }
    } catch (e) {
      debugPrint('School Data Inbox import failed: $e');
      if (mounted) {
        _showFeedback(
          'Import failed: $e',
          tone: WorkspaceFeedbackTone.error,
          title: 'Inbox import',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _chooseSourceAndRun(_InboxSource source) async {
    if (_busy) return;
    setState(() => _source = source);
    final destination = await _chooseImportDestination();
    if (destination == null || !mounted) return;
    await _runImport(destination);
  }

  Future<_InboxDestination?> _chooseImportDestination() {
    return showDialog<_InboxDestination>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('What are you importing?'),
        content: const Text(
          'Choose the current supported import type. InstructOS will still detect the file and show a preview before saving.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(
              ctx,
              _InboxDestination.schoolCalendar,
            ),
            icon: const Icon(Icons.calendar_month_rounded),
            label: const Text('School calendar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(
              ctx,
              _InboxDestination.classSchedule,
            ),
            icon: const Icon(Icons.event_note_rounded),
            label: const Text('Class schedule'),
          ),
        ],
      ),
    );
  }

  Future<_InboxPickedFile?> _pickInboxFile(
    _InboxDestination destination,
  ) async {
    switch (_source) {
      case _InboxSource.computer:
        final picked = await FilePicker.platform.pickFiles(
          withData: true,
          type: FileType.custom,
          allowedExtensions: _allowedExtensions(destination),
        );
        final file = picked?.files.single;
        final bytes = file?.bytes;
        if (file == null || bytes == null) return null;
        return _InboxPickedFile(name: file.name, bytes: bytes);
      case _InboxSource.drive:
        if (!await _ensureDriveReady()) return null;
        final drive = context.read<GoogleDriveService>();
        final picked = await showDialog<DriveFile>(
          context: context,
          builder: (ctx) => DriveFilePickerDialog(
            driveService: drive,
            allowedExtensions: _allowedExtensions(destination),
            title: _driveTitle(destination),
          ),
        );
        if (picked == null) return null;
        final bytes = await drive.downloadFileBytesFor(
          picked,
          preferredExportMimeType: GoogleDriveService.exportXlsxMimeType,
        );
        return _InboxPickedFile(name: picked.name, bytes: bytes);
    }
  }

  List<String> _allowedExtensions(_InboxDestination destination) {
    switch (destination) {
      case _InboxDestination.classSchedule:
        return const ['xlsx', 'csv', 'docx'];
      case _InboxDestination.schoolCalendar:
        return const ['xlsx', 'csv', 'ics'];
    }
  }

  String _driveTitle(_InboxDestination destination) {
    switch (destination) {
      case _InboxDestination.classSchedule:
        return 'Import class schedule from Google Drive';
      case _InboxDestination.schoolCalendar:
        return 'Import school calendar from Google Drive';
    }
  }

  Future<bool> _ensureDriveReady() async {
    final result = await context
        .read<GoogleAuthService>()
        .ensureAccessTokenDetailed(interactive: true);
    if (!mounted) return result.ok;
    if (!result.ok) {
      _showFeedback(
        result.userMessage(),
        tone: WorkspaceFeedbackTone.warning,
        title: 'Drive sign-in',
      );
      return false;
    }
    return true;
  }

  Future<void> _importClassSchedule(_InboxPickedFile file) async {
    if (!await _enforceImportType(
      bytes: file.bytes,
      filename: file.name,
      allowed: {ImportFileType.calendar, ImportFileType.timetable},
      destinationLabel: 'Class schedule',
    )) {
      return;
    }

    final classItem = await _chooseClass();
    if (classItem == null || !mounted) return;

    final items = _classScheduleService.parseFromBytes(file.bytes);
    if (items.isEmpty) {
      await _showImportProblem(
        title: 'No schedule detected',
        message:
            'Could not detect schedule rows in "${file.name}". Try a CSV, Excel, or Word table with clear date/title or week/topic columns.',
      );
      return;
    }

    final confirmed = await _confirmClassScheduleImport(
      classItem: classItem,
      file: file,
      items: items,
    );
    if (confirmed != true || !mounted) return;

    final userId = _storageUserId(context.read<AuthService>());
    if (userId == null) return;
    await _classScheduleService.save(
      classItem.classId,
      items,
      userId: userId,
    );
    _showFeedback(
      'Saved ${items.length} schedule item${items.length == 1 ? '' : 's'} for ${classItem.className}.',
      tone: WorkspaceFeedbackTone.success,
      title: 'Class schedule imported',
    );
  }

  Future<void> _importSchoolCalendar(_InboxPickedFile file) async {
    if (!await _enforceImportType(
      bytes: file.bytes,
      filename: file.name,
      allowed: {ImportFileType.calendar},
      destinationLabel: 'School calendar',
    )) {
      return;
    }

    final result = parseSchoolCalendarInboxImport(
      file.bytes,
      filename: file.name,
    );
    if (result.events.isEmpty) {
      await _showImportProblem(
        title: 'No calendar events detected',
        message:
            'Could not detect school calendar events in "${file.name}". Try a CSV, Excel, or ICS file with dates and event titles.',
      );
      return;
    }

    final confirmed = await _confirmSchoolCalendarImport(
      file: file,
      result: result,
    );
    if (confirmed != true || !mounted) return;

    final userId = _storageUserId(context.read<AuthService>());
    if (userId == null) return;
    await _appendCalendarEvents(userId: userId, events: result.events);
    _showFeedback(
      'Added ${result.events.length} calendar event${result.events.length == 1 ? '' : 's'} to Planner.',
      tone: WorkspaceFeedbackTone.success,
      title: 'School calendar imported',
    );
  }

  Future<void> _appendCalendarEvents({
    required String userId,
    required List<SchoolCalendarInboxEvent> events,
  }) async {
    final scopedKey = _dashboardPreferencesService.scopedKey(
      baseKey: _remindersPrefsBaseKey,
      userId: userId,
    );
    final existing = await _dashboardPreferencesService.readScopedJsonList(
      scopedKey: scopedKey,
      legacyKey: _legacyRemindersPrefsKey,
      migrationFlagKey: _remindersMigrationFlagKey,
    );
    final next = <Object?>[
      ...existing,
      for (final event in events)
        {
          'text': event.title,
          'timestamp': event.date.toIso8601String(),
          'done': false,
          'classIds': const <String>[],
        },
    ];
    await _dashboardPreferencesService.writeJsonList(
      key: scopedKey,
      items: next,
    );
  }

  Future<Class?> _chooseClass() async {
    final auth = context.read<AuthService>();
    final classService = context.read<ClassService>();
    final user = auth.currentUser;
    if (user != null && classService.activeClasses.isEmpty) {
      await classService.loadClasses(user.userId);
    }
    if (!mounted) return null;
    final classes = classService.activeClasses;
    if (classes.isEmpty) {
      await _showImportProblem(
        title: 'No class available',
        message: 'Create or restore a class before importing a class schedule.',
      );
      return null;
    }
    if (classes.length == 1) return classes.first;
    return showDialog<Class>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Choose class'),
        children: [
          for (final classItem in classes)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, classItem),
              child: Text(classItem.className),
            ),
        ],
      ),
    );
  }

  Future<bool> _enforceImportType({
    required Uint8List bytes,
    required String filename,
    required Set<ImportFileType> allowed,
    required String destinationLabel,
  }) async {
    final detection =
        FileImportService().detectFileType(bytes, filename: filename);
    if (allowed.contains(detection.type) ||
        detection.type == ImportFileType.unknown) {
      return true;
    }
    await _showImportProblem(
      title: 'Wrong import destination',
      message:
          '${detection.message}\n\nThis import is for $destinationLabel.\n\n${detection.suggestion}',
    );
    return false;
  }

  Future<bool?> _confirmClassScheduleImport({
    required Class classItem,
    required _InboxPickedFile file,
    required List<ClassScheduleItem> items,
  }) {
    final dateItems = items.where((i) => i.date != null).toList();
    DateTime? start;
    DateTime? end;
    if (dateItems.isNotEmpty) {
      start =
          dateItems.map((e) => e.date!).reduce((a, b) => a.isBefore(b) ? a : b);
      end =
          dateItems.map((e) => e.date!).reduce((a, b) => a.isAfter(b) ? a : b);
    }

    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import class schedule'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Class: ${classItem.className}'),
                Text('File: ${file.name}'),
                const SizedBox(height: WorkspaceSpacing.sm),
                Text('Items found: ${items.length}'),
                if (start != null && end != null)
                  Text(
                      'Date range: ${_formatDate(start)} - ${_formatDate(end)}'),
                const SizedBox(height: WorkspaceSpacing.md),
                Text(
                  'Preview',
                  style: context.textStyles.titleSmall?.semiBold,
                ),
                const SizedBox(height: WorkspaceSpacing.xs),
                for (final item in items.take(6))
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: item.details.isEmpty
                        ? null
                        : Text(
                            item.details.values.take(2).join(' - '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                    leading: Text(_scheduleWhen(item)),
                  ),
              ],
            ),
          ),
        ),
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
  }

  Future<bool?> _confirmSchoolCalendarImport({
    required _InboxPickedFile file,
    required SchoolCalendarInboxImport result,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import school calendar'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('File: ${file.name}'),
                Text('Events found: ${result.events.length}'),
                const SizedBox(height: WorkspaceSpacing.md),
                Text(
                  'Preview',
                  style: context.textStyles.titleSmall?.semiBold,
                ),
                const SizedBox(height: WorkspaceSpacing.xs),
                for (final event in result.events.take(8))
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Text(_formatDate(event.date)),
                    title: Text(
                      event.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: event.details == null
                        ? null
                        : Text(
                            event.details!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                  ),
              ],
            ),
          ),
        ),
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
  }

  Future<void> _showImportProblem({
    required String title,
    required String message,
  }) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SelectableText(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showFeedback(
    String message, {
    WorkspaceFeedbackTone tone = WorkspaceFeedbackTone.info,
    String? title,
  }) {
    if (!mounted) return;
    showWorkspaceSnackBar(
      context,
      message: message,
      tone: tone,
      title: title,
    );
  }

  String _scheduleWhen(ClassScheduleItem item) {
    if (item.date != null) return _formatDate(item.date!);
    if (item.week != null) return 'W${item.week}';
    return '';
  }

  String _formatDate(DateTime value) {
    final y = value.year.toString().padLeft(4, '0');
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final userId = _storageUserId(auth);
    final dark = context.isDark;

    return Scaffold(
      backgroundColor: OSColors.appBackground(dark),
      body: SafeArea(
        bottom: false,
        child: userId == null
            ? const WorkspaceLoadingState(
                title: 'Restoring workspace',
                subtitle: 'Preparing the School Data Inbox.',
              )
            : CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 172),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate.fixed([
                        _KnowledgeHubHeader(
                          busy: _busy,
                          onBack: () => context.go(AppRoutes.osHome),
                        ),
                        const SizedBox(height: 28),
                        _KnowledgeHubContent(
                          busy: _busy,
                          onUploadFromComputer: _busy
                              ? null
                              : () => _chooseSourceAndRun(
                                    _InboxSource.computer,
                                  ),
                          onUploadFromDrive: _busy
                              ? null
                              : () => _chooseSourceAndRun(
                                    _InboxSource.drive,
                                  ),
                        ),
                        const SizedBox(height: 24),
                        const _InboxPermissionBanner(),
                      ]),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

@visibleForTesting
SchoolCalendarInboxImport parseSchoolCalendarInboxImport(
  Uint8List bytes, {
  required String filename,
}) {
  final service = FileImportService();
  final lowerName = filename.toLowerCase();
  if (lowerName.endsWith('.ics')) {
    final events = service
        .parseIcs(bytes)
        .where((event) => event.summary.trim().isNotEmpty)
        .map(
          (event) => SchoolCalendarInboxEvent(
            title: event.summary.trim(),
            date: event.start,
            details: event.location?.trim().isEmpty ?? true
                ? null
                : event.location!.trim(),
          ),
        )
        .toList();
    return SchoolCalendarInboxImport(events: events);
  }

  final rows = _rowsFromInboxBytes(bytes, filename: filename);
  if (rows.isEmpty) return const SchoolCalendarInboxImport(events: []);
  final headerRowIndex = _pickLikelyCalendarHeaderRow(rows);
  final header = rows[headerRowIndex].map(_normalizeCalendarToken).toList();
  final dateIdx = _findHeaderIndex(header, ['date', 'day']);
  final titleIdx = _findHeaderIndex(
    header,
    ['title', 'event', 'subject', 'description', 'task', 'content'],
  );
  final detailsIdx = _findHeaderIndex(
    header,
    ['details', 'detail', 'notes', 'note', 'remarks', 'memo', 'location'],
  );
  final timeIdx = _findHeaderIndex(header, ['time', 'start', 'start time']);
  final yearGuess = _inferYearFromFilename(filename) ?? DateTime.now().year;

  if (dateIdx != -1 && titleIdx != -1) {
    final events = <SchoolCalendarInboxEvent>[];
    for (var i = headerRowIndex + 1; i < rows.length; i++) {
      final row = rows[i];
      String cell(int index) =>
          index != -1 && index < row.length ? row[index].trim() : '';
      final dateValue = cell(dateIdx);
      final title = cell(titleIdx);
      if (dateValue.isEmpty || title.isEmpty) continue;
      var date = _parseDateFlexible(dateValue);
      if (date == null) continue;
      final time = _parseTimeFlexible(cell(timeIdx));
      if (time != null) {
        date =
            DateTime(date.year, date.month, date.day, time.hour, time.minute);
      }
      final details = cell(detailsIdx);
      events.add(
        SchoolCalendarInboxEvent(
          title: title,
          date: date,
          details: details.isEmpty ? null : details,
        ),
      );
    }
    if (events.isNotEmpty || !filename.toLowerCase().endsWith('.csv')) {
      return SchoolCalendarInboxImport(events: events);
    }
    return SchoolCalendarInboxImport(
      events: _parseSimpleCsvCalendar(bytes),
    );
  }

  final monthIdx = _findMonthColumn(rows, headerRowIndex, header);
  final eventIdx = _findEventColumn(rows, headerRowIndex, header);
  if (monthIdx == -1 || eventIdx == -1) {
    return const SchoolCalendarInboxImport(events: []);
  }

  var lastMonthToken = '';
  final events = <SchoolCalendarInboxEvent>[];
  for (var i = headerRowIndex + 1; i < rows.length; i++) {
    final row = rows[i];
    String cell(int index) =>
        index != -1 && index < row.length ? row[index].trim() : '';
    final monthToken = cell(monthIdx);
    if (monthToken.isNotEmpty) lastMonthToken = monthToken;
    final eventCell = cell(eventIdx);
    if (eventCell.isEmpty) continue;
    final monthNumber = _monthFromToken(lastMonthToken);
    final pieces = eventCell
        .split(RegExp(r'\r?\n'))
        .expand((line) => line.split(RegExp(r'\s{2,}')))
        .map((piece) => piece.trim())
        .where((piece) => piece.isNotEmpty);
    for (final piece in pieces) {
      final parsed = _parseDateEventPiece(
        piece,
        year: yearGuess,
        month: monthNumber,
      );
      if (parsed != null) events.add(parsed);
    }
  }
  return SchoolCalendarInboxImport(events: events);
}

List<SchoolCalendarInboxEvent> _parseSimpleCsvCalendar(Uint8List bytes) {
  final text = utf8.decode(bytes, allowMalformed: true);
  final lines = const LineSplitter()
      .convert(text)
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList(growable: false);
  if (lines.length < 2) return const [];
  final header = lines.first
      .split(',')
      .map(_normalizeCalendarToken)
      .toList(growable: false);
  final dateIdx = _findHeaderIndex(header, ['date', 'day']);
  final titleIdx = _findHeaderIndex(header, ['title', 'event']);
  final detailsIdx = _findHeaderIndex(header, ['details', 'notes', 'location']);
  if (dateIdx == -1 || titleIdx == -1) return const [];
  final events = <SchoolCalendarInboxEvent>[];
  for (final line in lines.skip(1)) {
    final cells = line.split(',').map((cell) => cell.trim()).toList();
    if (dateIdx >= cells.length || titleIdx >= cells.length) continue;
    final date = _parseDateFlexible(cells[dateIdx]);
    final title = cells[titleIdx];
    if (date == null || title.isEmpty) continue;
    final details =
        detailsIdx != -1 && detailsIdx < cells.length ? cells[detailsIdx] : '';
    events.add(
      SchoolCalendarInboxEvent(
        title: title,
        date: date,
        details: details.isEmpty ? null : details,
      ),
    );
  }
  return events;
}

List<List<String>> _rowsFromInboxBytes(
  Uint8List bytes, {
  required String filename,
}) {
  if (filename.toLowerCase().endsWith('.csv')) {
    final text = utf8.decode(bytes, allowMalformed: true);
    return const CsvToListConverter()
        .convert(text)
        .map(
          (row) => row
              .map((cell) => cell?.toString().trim() ?? '')
              .toList(growable: false),
        )
        .toList(growable: false);
  }
  return FileImportService().rowsFromAnyBytes(bytes);
}

class SchoolCalendarInboxImport {
  const SchoolCalendarInboxImport({required this.events});

  final List<SchoolCalendarInboxEvent> events;
}

class SchoolCalendarInboxEvent {
  const SchoolCalendarInboxEvent({
    required this.title,
    required this.date,
    this.details,
  });

  final String title;
  final DateTime date;
  final String? details;
}

class _InboxPickedFile {
  const _InboxPickedFile({
    required this.name,
    required this.bytes,
  });

  final String name;
  final Uint8List bytes;
}

class _KnowledgeHubHeader extends StatelessWidget {
  const _KnowledgeHubHeader({
    required this.busy,
    required this.onBack,
  });

  final bool busy;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 640;
        final titleStyle = (compact
                ? context.textStyles.headlineLarge
                : context.textStyles.displaySmall)
            ?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
          height: 1.08,
        );
        final title = Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                'School Knowledge Hub',
                style: titleStyle,
              ),
            ),
            const SizedBox(width: WorkspaceSpacing.sm),
            Icon(
              Icons.auto_awesome_rounded,
              color: Theme.of(context).colorScheme.primary,
              size: compact ? 24 : 28,
            ),
          ],
        );
        final subtitle = Text(
          'Upload and connect school data to power smarter insights, planning, and support.',
          style: (compact
                  ? context.textStyles.bodyLarge
                  : context.textStyles.titleMedium)
              ?.copyWith(
            color: OSColors.textSecondary(dark),
            height: 1.35,
            fontWeight: FontWeight.w500,
          ),
        );
        final leading = IconButton(
          tooltip: 'Back home',
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
          style: WorkspaceButtonStyles.icon(context),
        );
        final status = busy
            ? const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator.adaptive(),
              )
            : const _SecurePrivatePill();

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  leading,
                  const Spacer(),
                  status,
                ],
              ),
              const SizedBox(height: WorkspaceSpacing.md),
              title,
              const SizedBox(height: WorkspaceSpacing.md),
              subtitle,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            leading,
            const SizedBox(width: WorkspaceSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  title,
                  const SizedBox(height: WorkspaceSpacing.xs),
                  subtitle,
                ],
              ),
            ),
            const SizedBox(width: WorkspaceSpacing.md),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: status,
            ),
          ],
        );
      },
    );
  }
}

class _KnowledgeHubContent extends StatelessWidget {
  const _KnowledgeHubContent({
    required this.busy,
    required this.onUploadFromComputer,
    required this.onUploadFromDrive,
  });

  final bool busy;
  final VoidCallback? onUploadFromComputer;
  final VoidCallback? onUploadFromDrive;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 980;
        final main = _AddSchoolDataCard(
          busy: busy,
          onUploadFromComputer: onUploadFromComputer,
          onUploadFromDrive: onUploadFromDrive,
        );
        final side = const Column(
          children: [
            _InboxPreviewCard(),
            SizedBox(height: WorkspaceSpacing.lg),
            _SchoolSharedFolderCard(),
          ],
        );

        if (!desktop) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              main,
              const SizedBox(height: WorkspaceSpacing.lg),
              side,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 7, child: main),
            const SizedBox(width: 22),
            Expanded(flex: 5, child: side),
          ],
        );
      },
    );
  }
}

class _AddSchoolDataCard extends StatelessWidget {
  const _AddSchoolDataCard({
    required this.busy,
    required this.onUploadFromComputer,
    required this.onUploadFromDrive,
  });

  final bool busy;
  final VoidCallback? onUploadFromComputer;
  final VoidCallback? onUploadFromDrive;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    return _HubGlassCard(
      borderColor: accent.withValues(alpha: dark ? 0.44 : 0.30),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 560;
              final header = Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HubIconBadge(
                    icon: Icons.cloud_upload_outlined,
                    accent: accent,
                    large: true,
                  ),
                  const SizedBox(width: WorkspaceSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add school data',
                          style: context.textStyles.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0,
                          ),
                        ),
                        const SizedBox(height: WorkspaceSpacing.xs),
                        Text(
                          'Choose a source to get started. InstructOS will detect what it likely is, show a preview, and you confirm before anything is imported.',
                          style: context.textStyles.bodyMedium?.copyWith(
                            color: OSColors.textSecondary(dark),
                            height: 1.42,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
              final reassurance = Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.verified_user_outlined,
                    size: 18,
                    color: OSColors.textSecondary(dark),
                  ),
                  const SizedBox(width: WorkspaceSpacing.xs),
                  Flexible(
                    child: Text(
                      'Nothing is saved until you review and confirm.',
                      style: context.textStyles.bodySmall?.copyWith(
                        color: OSColors.textSecondary(dark),
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              );
              if (narrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    header,
                    const SizedBox(height: WorkspaceSpacing.md),
                    reassurance,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: header),
                  const SizedBox(width: WorkspaceSpacing.lg),
                  SizedBox(width: 156, child: reassurance),
                ],
              );
            },
          ),
          const SizedBox(height: 34),
          _SourceCardsGrid(
            busy: busy,
            onUploadFromComputer: onUploadFromComputer,
            onUploadFromDrive: onUploadFromDrive,
          ),
          const SizedBox(height: 28),
          Divider(
            height: 1,
            color: Theme.of(context).colorScheme.outline.withValues(
                  alpha: dark ? 0.22 : 0.18,
                ),
          ),
          const SizedBox(height: WorkspaceSpacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                size: 18,
                color: accent,
              ),
              const SizedBox(width: WorkspaceSpacing.sm),
              Expanded(
                child: Text(
                  "We'll detect what it is, show a preview, and you confirm what to import.",
                  style: context.textStyles.bodyMedium?.copyWith(
                    color: OSColors.textSecondary(dark),
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SourceCardsGrid extends StatelessWidget {
  const _SourceCardsGrid({
    required this.busy,
    required this.onUploadFromComputer,
    required this.onUploadFromDrive,
  });

  final bool busy;
  final VoidCallback? onUploadFromComputer;
  final VoidCallback? onUploadFromDrive;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 720 ? 3 : (width >= 460 ? 2 : 1);
        final cards = [
          _SourceOptionCard(
            icon: Icons.desktop_windows_rounded,
            title: 'Upload from computer',
            subtitle: 'Upload CSV, Excel, Word, or ICS files up to 250 MB.',
            buttonLabel: 'Choose file',
            accent: Theme.of(context).colorScheme.primary,
            emphasized: true,
            onPressed: onUploadFromComputer,
            busy: busy,
          ),
          _SourceOptionCard(
            icon: Icons.change_history_rounded,
            title: 'Choose from Google Drive',
            subtitle: 'Browse and select files from your Drive.',
            buttonLabel: 'Choose from Drive',
            accent: OSColors.green,
            onPressed: onUploadFromDrive,
          ),
          _SourceOptionCard(
            icon: Icons.upload_rounded,
            title: 'Drag & drop files',
            subtitle: 'Drag files here to upload from your computer.',
            buttonLabel: 'Browse files',
            accent: OSColors.cyan,
            onPressed: onUploadFromComputer,
          ),
        ];

        if (columns == 1) {
          return Column(
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                cards[i],
                if (i != cards.length - 1)
                  const SizedBox(height: WorkspaceSpacing.md),
              ],
            ],
          );
        }

        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: WorkspaceSpacing.md,
          mainAxisSpacing: WorkspaceSpacing.md,
          childAspectRatio: columns == 3 ? 0.78 : 1.04,
          children: cards,
        );
      },
    );
  }
}

class _SourceOptionCard extends StatelessWidget {
  const _SourceOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.accent,
    required this.onPressed,
    this.emphasized = false,
    this.busy = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final Color accent;
  final VoidCallback? onPressed;
  final bool emphasized;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final theme = Theme.of(context);
    final compact = MediaQuery.sizeOf(context).width < 520;
    final buttonStyle = emphasized
        ? FilledButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: Colors.white,
            disabledForegroundColor: Colors.white.withValues(alpha: 0.55),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          )
        : WorkspaceButtonStyles.outlined(context);
    final button = SizedBox(
      width: double.infinity,
      child: emphasized
          ? FilledButton(
              onPressed: onPressed,
              style: buttonStyle,
              child: busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(buttonLabel),
            )
          : OutlinedButton(
              onPressed: onPressed,
              style: buttonStyle,
              child: Text(buttonLabel),
            ),
    );

    final body = compact
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HubIconBadge(
                icon: icon,
                accent: accent,
                filled: emphasized,
              ),
              const SizedBox(width: WorkspaceSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: context.textStyles.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                        height: 1.22,
                      ),
                    ),
                    const SizedBox(height: WorkspaceSpacing.xs),
                    Text(
                      subtitle,
                      style: context.textStyles.bodySmall?.copyWith(
                        color: OSColors.textSecondary(dark),
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: WorkspaceSpacing.md),
                    button,
                  ],
                ),
              ),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _HubIconBadge(
                icon: icon,
                accent: accent,
                large: true,
                filled: emphasized,
              ),
              const SizedBox(height: 24),
              Text(
                title,
                textAlign: TextAlign.center,
                style: context.textStyles.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                  height: 1.22,
                ),
              ),
              const SizedBox(height: WorkspaceSpacing.md),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: context.textStyles.bodySmall?.copyWith(
                  color: OSColors.textSecondary(dark),
                  height: 1.42,
                ),
              ),
              const SizedBox(height: WorkspaceSpacing.md),
              button,
            ],
          );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Color.lerp(
          theme.colorScheme.surface,
          accent,
          dark ? 0.10 : 0.06,
        )!
            .withValues(alpha: dark ? 0.52 : 0.74),
        border: Border.all(
          color: accent.withValues(alpha: dark ? 0.30 : 0.22),
        ),
      ),
      child: Padding(
        padding: compact
            ? const EdgeInsets.all(14)
            : const EdgeInsets.fromLTRB(18, 22, 18, 18),
        child: body,
      ),
    );
  }
}

class _InboxPreviewCard extends StatelessWidget {
  const _InboxPreviewCard();

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return _HubGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _HubIconBadge(
                icon: Icons.visibility_outlined,
                accent: OSColors.indigo,
                large: true,
                filled: true,
              ),
              const SizedBox(width: WorkspaceSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Preview',
                      style: context.textStyles.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: WorkspaceSpacing.xxs),
                    Text(
                      'See a quick preview before you confirm.',
                      style: context.textStyles.bodyMedium?.copyWith(
                        color: OSColors.textSecondary(dark),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: WorkspaceSpacing.lg),
          const _PreviewEmptyState(),
          const SizedBox(height: WorkspaceSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withValues(
                    alpha: dark ? 0.34 : 0.62,
                  ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withValues(
                      alpha: 0.14,
                    ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.verified_user_outlined,
                  size: 18,
                  color: OSColors.textSecondary(dark),
                ),
                const SizedBox(width: WorkspaceSpacing.sm),
                Expanded(
                  child: Text(
                    'Nothing is saved until you review and confirm.',
                    style: context.textStyles.bodySmall?.copyWith(
                      color: OSColors.textSecondary(dark),
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewEmptyState extends StatelessWidget {
  const _PreviewEmptyState();

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final line = Theme.of(context).colorScheme.outline.withValues(
          alpha: dark ? 0.16 : 0.22,
        );
    return Container(
      height: 178,
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: line),
        color: OSColors.surface(dark).withValues(alpha: dark ? 0.30 : 0.54),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _PreviewGridPainter(line),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.description_outlined,
                  size: 42,
                  color: OSColors.textSecondary(dark),
                ),
                const SizedBox(height: WorkspaceSpacing.sm),
                Text(
                  'Choose a file to preview',
                  style: context.textStyles.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: WorkspaceSpacing.xs),
                Text(
                  'A preview of your data will appear here.',
                  style: context.textStyles.bodySmall?.copyWith(
                    color: OSColors.textSecondary(dark),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SchoolSharedFolderCard extends StatelessWidget {
  const _SchoolSharedFolderCard();

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return _HubGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _HubIconBadge(
                icon: Icons.folder_shared_outlined,
                accent: OSColors.blue,
              ),
              const SizedBox(width: WorkspaceSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'School shared folder',
                      style: context.textStyles.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: WorkspaceSpacing.xs),
                    Text(
                      'Access approved shared resources like calendars, quizzes, worksheets, rosters, and teaching docs.',
                      style: context.textStyles.bodyMedium?.copyWith(
                        color: OSColors.textSecondary(dark),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: WorkspaceSpacing.sm),
              const _ComingSoonBadge(),
            ],
          ),
          const SizedBox(height: WorkspaceSpacing.md),
          const Wrap(
            spacing: WorkspaceSpacing.xs,
            runSpacing: WorkspaceSpacing.xs,
            children: [
              _ResourceChip(label: 'Calendars'),
              _ResourceChip(label: 'Quizzes'),
              _ResourceChip(label: 'Worksheets'),
              _ResourceChip(label: 'Rosters'),
              _ResourceChip(label: 'Teaching docs'),
            ],
          ),
          const SizedBox(height: WorkspaceSpacing.md),
          Divider(
            height: 1,
            color: Theme.of(context).colorScheme.outline.withValues(
                  alpha: dark ? 0.20 : 0.16,
                ),
          ),
          const SizedBox(height: WorkspaceSpacing.sm),
          Row(
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 16,
                color: OSColors.textMuted(dark),
              ),
              const SizedBox(width: WorkspaceSpacing.xs),
              Expanded(
                child: Text(
                  'Visible only after your school approves access.',
                  style: context.textStyles.bodySmall?.copyWith(
                    color: OSColors.textMuted(dark),
                    height: 1.32,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InboxPermissionBanner extends StatelessWidget {
  const _InboxPermissionBanner();

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return _HubGlassCard(
      radius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      child: Row(
        children: [
          Icon(
            Icons.auto_awesome_rounded,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: WorkspaceSpacing.md),
          Expanded(
            child: Text(
              'Ask InstructOS can later search approved school folders — only with permission.',
              style: context.textStyles.bodyMedium?.copyWith(
                color: OSColors.textSecondary(dark),
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: WorkspaceSpacing.md),
          OutlinedButton(
            onPressed: null,
            style: WorkspaceButtonStyles.outlined(context),
            child: const Text('Learn more'),
          ),
        ],
      ),
    );
  }
}

class _HubGlassCard extends StatelessWidget {
  const _HubGlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 22,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = context.isDark;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        color: theme.colorScheme.surface.withValues(
          alpha: dark ? 0.48 : 0.78,
        ),
        border: Border.all(
          color: borderColor ??
              theme.colorScheme.outline.withValues(alpha: dark ? 0.26 : 0.20),
        ),
        boxShadow: WorkspaceChrome.panelShadow(context, emphasis: 0.74),
      ),
      child: child,
    );
  }
}

class _HubIconBadge extends StatelessWidget {
  const _HubIconBadge({
    required this.icon,
    required this.accent,
    this.large = false,
    this.filled = false,
  });

  final IconData icon;
  final Color accent;
  final bool large;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final size = large ? 64.0 : 42.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(large ? 16 : 12),
        color: accent.withValues(alpha: filled ? 0.24 : 0.14),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Icon(
        icon,
        color: accent,
        size: large ? 32 : 22,
      ),
    );
  }
}

class _SecurePrivatePill extends StatelessWidget {
  const _SecurePrivatePill();

  @override
  Widget build(BuildContext context) {
    return _SmallOutlinedPill(
      icon: Icons.lock_outline_rounded,
      label: 'Secure & private',
      accent: Theme.of(context).colorScheme.primary,
    );
  }
}

class _ComingSoonBadge extends StatelessWidget {
  const _ComingSoonBadge();

  @override
  Widget build(BuildContext context) {
    return _SmallOutlinedPill(
      label: 'Coming soon',
      accent: Theme.of(context).colorScheme.primary,
      dense: true,
    );
  }
}

class _SmallOutlinedPill extends StatelessWidget {
  const _SmallOutlinedPill({
    required this.label,
    required this.accent,
    this.icon,
    this.dense = false,
  });

  final String label;
  final Color accent;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 10 : 14,
        vertical: dense ? 7 : 10,
      ),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(dense ? 12 : 14),
        border: Border.all(color: accent.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 17, color: accent),
            const SizedBox(width: WorkspaceSpacing.xs),
          ],
          Text(
            label,
            style: context.textStyles.labelMedium?.copyWith(
              color: accent,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResourceChip extends StatelessWidget {
  const _ResourceChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(
              alpha: dark ? 0.38 : 0.60,
            ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.18),
        ),
      ),
      child: Text(
        label,
        style: context.textStyles.labelMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PreviewGridPainter extends CustomPainter {
  const _PreviewGridPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const cols = 4;
    const rows = 8;
    for (var i = 1; i < cols; i++) {
      final x = size.width * i / cols;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var i = 1; i < rows; i++) {
      final y = size.height * i / rows;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PreviewGridPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

int _pickLikelyCalendarHeaderRow(List<List<String>> rows) {
  var bestIndex = 0;
  var bestScore = -1;
  for (var i = 0; i < rows.length && i < 12; i++) {
    final normalized = rows[i].map(_normalizeCalendarToken).toList();
    var score = 0;
    for (final token in normalized) {
      if (token == 'date' ||
          token == 'day' ||
          token == 'event' ||
          token == 'title' ||
          token == 'month' ||
          token == 'week' ||
          token.contains('date event')) {
        score++;
      }
    }
    if (score > bestScore) {
      bestScore = score;
      bestIndex = i;
    }
  }
  return bestIndex;
}

String _normalizeCalendarToken(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9:]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

int _findHeaderIndex(List<String> header, List<String> keys) {
  for (var i = 0; i < header.length; i++) {
    final value = header[i];
    for (final key in keys) {
      if (value == key || value.contains(key)) return i;
    }
  }
  return -1;
}

int _findMonthColumn(
  List<List<String>> rows,
  int headerRowIndex,
  List<String> header,
) {
  final explicit = _findHeaderIndex(header, ['month']);
  if (explicit != -1) return explicit;
  var bestIndex = -1;
  var bestHits = 0;
  final sampleEnd =
      rows.length < headerRowIndex + 13 ? rows.length : headerRowIndex + 13;
  final maxCols = rows.fold<int>(
    0,
    (max, row) => row.length > max ? row.length : max,
  );
  for (var col = 0; col < maxCols; col++) {
    var hits = 0;
    for (var rowIndex = headerRowIndex + 1; rowIndex < sampleEnd; rowIndex++) {
      final row = rows[rowIndex];
      if (col >= row.length) continue;
      if (_monthFromToken(row[col]) != null) hits++;
    }
    if (hits > bestHits) {
      bestHits = hits;
      bestIndex = col;
    }
  }
  return bestHits > 0 ? bestIndex : -1;
}

int _findEventColumn(
  List<List<String>> rows,
  int headerRowIndex,
  List<String> header,
) {
  final explicit = _findHeaderIndex(
    header,
    ['date: event', 'date event', 'event', 'events'],
  );
  if (explicit != -1) return explicit;
  if (rows.length <= headerRowIndex + 1) return -1;
  final sampleEnd =
      rows.length < headerRowIndex + 9 ? rows.length : headerRowIndex + 9;
  var bestIndex = -1;
  var bestScore = 0;
  for (var col = 0; col < header.length; col++) {
    var score = 0;
    for (var rowIndex = headerRowIndex + 1; rowIndex < sampleEnd; rowIndex++) {
      final row = rows[rowIndex];
      if (col >= row.length) continue;
      final value = row[col].trim();
      if (value.isEmpty) continue;
      if (value.contains(':')) score += 2;
      if (value.contains('\n')) score += 1;
      if (RegExp(r'\d{1,2}\s*-\s*\d{1,2}').hasMatch(value)) score += 1;
    }
    if (score > bestScore) {
      bestScore = score;
      bestIndex = col;
    }
  }
  return bestScore >= 3 ? bestIndex : -1;
}

SchoolCalendarInboxEvent? _parseDateEventPiece(
  String piece, {
  required int year,
  required int? month,
}) {
  var token = '';
  var title = '';
  final colon = RegExp(r'^(.+?)\s*[:]\s*(.+)$').firstMatch(piece);
  if (colon != null) {
    token = colon.group(1)!.trim();
    title = colon.group(2)!.trim();
  } else {
    final leadDate =
        RegExp(r'^(\d{1,2}(?:\s*-\s*\d{1,2})?)\s+(.+)$').firstMatch(piece);
    if (leadDate == null) return null;
    token = leadDate.group(1)!.trim();
    title = leadDate.group(2)!.trim();
  }
  if (title.isEmpty) return null;
  final date = _parseSchoolCalendarDateToken(token, year: year, month: month);
  if (date == null) return null;
  return SchoolCalendarInboxEvent(title: title, date: date);
}

DateTime? _parseSchoolCalendarDateToken(
  String token, {
  required int year,
  required int? month,
}) {
  var value = token.trim();
  if (value.isEmpty) return null;
  value = value.split('-').first.trim();
  value = value.split('/').first.trim();
  final day = int.tryParse(value.replaceAll(RegExp(r'[^0-9]'), ''));
  if (day == null || day < 1 || day > 31 || month == null) return null;
  return DateTime(year, month, day);
}

DateTime? _parseDateFlexible(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return null;
  final iso = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$').firstMatch(value);
  if (iso != null) {
    final year = int.tryParse(iso.group(1)!);
    final month = int.tryParse(iso.group(2)!);
    final day = int.tryParse(iso.group(3)!);
    return _validDate(year: year, month: month, day: day);
  }
  final parts =
      RegExp(r'^(\d{1,2})[/-](\d{1,2})(?:[/-](\d{2,4}))?$').firstMatch(value);
  if (parts != null) {
    final first = int.tryParse(parts.group(1)!);
    final second = int.tryParse(parts.group(2)!);
    var year = int.tryParse(parts.group(3) ?? '') ?? DateTime.now().year;
    if (year < 100) year += 2000;
    if (first == null || second == null) return null;
    if (first > 12 && second <= 12) {
      return _validDate(year: year, month: second, day: first);
    }
    if (second > 12 && first <= 12) {
      return _validDate(year: year, month: first, day: second);
    }
    if (first <= 12 && second <= 12) {
      return _validDate(year: year, month: second, day: first);
    }
  }
  return null;
}

DateTime? _validDate({
  required int? year,
  required int? month,
  required int? day,
}) {
  if (year == null || month == null || day == null) return null;
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  final value = DateTime(year, month, day);
  if (value.year != year || value.month != month || value.day != day) {
    return null;
  }
  return value;
}

TimeOfDay? _parseTimeFlexible(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return null;
  final match = RegExp(r'^(\d{1,2})(?::(\d{2}))?\s*(am|pm)?$')
      .firstMatch(value.toLowerCase());
  if (match == null) return null;
  var hour = int.tryParse(match.group(1)!);
  final minute = int.tryParse(match.group(2) ?? '0');
  final meridiem = match.group(3);
  if (hour == null || minute == null || minute > 59) return null;
  if (meridiem == 'pm' && hour < 12) hour += 12;
  if (meridiem == 'am' && hour == 12) hour = 0;
  if (hour > 23) return null;
  return TimeOfDay(hour: hour, minute: minute);
}

int? _inferYearFromFilename(String filename) {
  final match = RegExp(r'(\d{4})').firstMatch(filename.trim());
  if (match == null) return null;
  return int.tryParse(match.group(1)!);
}

int? _monthFromToken(String token) {
  final normalized = token
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  const months = {
    'jan': 1,
    'january': 1,
    'feb': 2,
    'february': 2,
    'mar': 3,
    'march': 3,
    'apr': 4,
    'april': 4,
    'may': 5,
    'jun': 6,
    'june': 6,
    'jul': 7,
    'july': 7,
    'aug': 8,
    'august': 8,
    'sep': 9,
    'sept': 9,
    'september': 9,
    'oct': 10,
    'october': 10,
    'nov': 11,
    'november': 11,
    'dec': 12,
    'december': 12,
  };
  return months[normalized];
}

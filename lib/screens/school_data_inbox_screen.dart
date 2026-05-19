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
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate.fixed([
                        _InboxHeader(
                          busy: _busy,
                          source: _source,
                          onSourceChanged: _busy
                              ? null
                              : (source) => setState(() => _source = source),
                          onBack: () => context.go(AppRoutes.osHome),
                        ),
                        const SizedBox(height: WorkspaceSpacing.lg),
                        _InboxSectionHeader(
                          title: 'Sources',
                          subtitle: 'Choose where the file is coming from.',
                        ),
                        const SizedBox(height: WorkspaceSpacing.sm),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final narrow = constraints.maxWidth < 720;
                            return _InboxResponsiveGrid(
                              narrow: narrow,
                              children: [
                                _InboxActionCard(
                                  title: 'Upload from computer',
                                  subtitle:
                                      'Pick a CSV, Excel, Word, or ICS file.',
                                  icon: Icons.upload_file_rounded,
                                  selected: _source == _InboxSource.computer,
                                  enabled: !_busy,
                                  onTap: () => setState(
                                      () => _source = _InboxSource.computer),
                                ),
                                _InboxActionCard(
                                  title: 'Import from Google Drive',
                                  subtitle:
                                      'Browse recent files, folders, and Sheets.',
                                  icon: Icons.drive_folder_upload_rounded,
                                  selected: _source == _InboxSource.drive,
                                  enabled: !_busy,
                                  onTap: () => setState(
                                      () => _source = _InboxSource.drive),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: WorkspaceSpacing.xl),
                        _InboxSectionHeader(
                          title: 'Import types',
                          subtitle:
                              'This first slice imports class schedules and school calendars. Other data types are staged here for review.',
                        ),
                        const SizedBox(height: WorkspaceSpacing.sm),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final narrow = constraints.maxWidth < 840;
                            return _InboxResponsiveGrid(
                              narrow: narrow,
                              children: [
                                _InboxActionCard(
                                  title: 'Class schedule',
                                  subtitle:
                                      'Preview lesson rows, choose a class, then save.',
                                  icon: Icons.event_note_rounded,
                                  enabled: !_busy,
                                  onTap: () => _runImport(
                                    _InboxDestination.classSchedule,
                                  ),
                                ),
                                _InboxActionCard(
                                  title: 'School calendar',
                                  subtitle:
                                      'Preview events, then add them to Planner.',
                                  icon: Icons.calendar_month_rounded,
                                  enabled: !_busy,
                                  onTap: () => _runImport(
                                    _InboxDestination.schoolCalendar,
                                  ),
                                ),
                                const _InboxActionCard(
                                  title: 'Teacher timetable',
                                  subtitle:
                                      'Timetable review will land in a later slice.',
                                  icon: Icons.table_chart_rounded,
                                  enabled: false,
                                ),
                                const _InboxActionCard(
                                  title: 'Roster',
                                  subtitle:
                                      'Roster review is visible here, import comes next.',
                                  icon: Icons.groups_rounded,
                                  enabled: false,
                                ),
                                const _InboxActionCard(
                                  title: 'Scores',
                                  subtitle:
                                      'Score imports stay disabled until mapping is added.',
                                  icon: Icons.stacked_bar_chart_rounded,
                                  enabled: false,
                                ),
                                const _InboxActionCard(
                                  title: 'Recent imports',
                                  subtitle:
                                      'Import history and undo controls are coming soon.',
                                  icon: Icons.history_rounded,
                                  enabled: false,
                                ),
                              ],
                            );
                          },
                        ),
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

class _InboxHeader extends StatelessWidget {
  const _InboxHeader({
    required this.busy,
    required this.source,
    required this.onSourceChanged,
    required this.onBack,
  });

  final bool busy;
  final _InboxSource source;
  final ValueChanged<_InboxSource>? onSourceChanged;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return WorkspaceSurfaceCard(
      radius: 8,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Back home',
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded),
                style: WorkspaceButtonStyles.icon(context),
              ),
              const SizedBox(width: WorkspaceSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'School Data Inbox',
                      style: WorkspaceTypography.pageTitle(context),
                    ),
                    const SizedBox(height: WorkspaceSpacing.xxs),
                    Text(
                      'Upload, connect, review, and route school data from one place.',
                      style: WorkspaceTypography.pageSubtitle(context),
                    ),
                  ],
                ),
              ),
              if (busy) const CircularProgressIndicator.adaptive(),
            ],
          ),
          const SizedBox(height: WorkspaceSpacing.md),
          Wrap(
            spacing: WorkspaceSpacing.sm,
            runSpacing: WorkspaceSpacing.sm,
            children: [
              ChoiceChip(
                label: const Text('Computer'),
                selected: source == _InboxSource.computer,
                onSelected: onSourceChanged == null
                    ? null
                    : (_) => onSourceChanged!(_InboxSource.computer),
              ),
              ChoiceChip(
                label: const Text('Google Drive'),
                selected: source == _InboxSource.drive,
                onSelected: onSourceChanged == null
                    ? null
                    : (_) => onSourceChanged!(_InboxSource.drive),
              ),
            ],
          ),
          const SizedBox(height: WorkspaceSpacing.sm),
          Text(
            'Every writing import stops for preview and confirmation.',
            style: TextStyle(color: OSColors.textSecondary(dark)),
          ),
        ],
      ),
    );
  }
}

class _InboxSectionHeader extends StatelessWidget {
  const _InboxSectionHeader({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return WorkspaceSectionHeader(title: title, subtitle: subtitle);
  }
}

class _InboxResponsiveGrid extends StatelessWidget {
  const _InboxResponsiveGrid({
    required this.narrow,
    required this.children,
  });

  final bool narrow;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (narrow) {
      return Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1)
              const SizedBox(height: WorkspaceSpacing.sm),
          ],
        ],
      );
    }

    return GridView.count(
      crossAxisCount: children.length <= 2 ? 2 : 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: WorkspaceSpacing.sm,
      mainAxisSpacing: WorkspaceSpacing.sm,
      childAspectRatio: children.length <= 2 ? 3.2 : 2.2,
      children: children,
    );
  }
}

class _InboxActionCard extends StatelessWidget {
  const _InboxActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.onTap,
    this.enabled = true,
    this.selected = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final bool enabled;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = context.isDark;
    final accent = selected ? theme.colorScheme.primary : OSColors.cyan;
    return WorkspaceSurfaceCard(
      radius: 8,
      padding: EdgeInsets.zero,
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: enabled ? 0.16 : 0.07),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: accent.withValues(alpha: enabled ? 0.26 : 0.12),
                ),
              ),
              child: Icon(
                icon,
                color: enabled ? accent : OSColors.textMuted(dark),
              ),
            ),
            const SizedBox(width: WorkspaceSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.textStyles.titleSmall?.semiBold,
                        ),
                      ),
                      if (!enabled)
                        const _InboxStatusPill(label: 'Coming next')
                      else if (selected)
                        const _InboxStatusPill(label: 'Selected'),
                    ],
                  ),
                  const SizedBox(height: WorkspaceSpacing.xs),
                  Text(
                    subtitle,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: context.textStyles.bodySmall?.withColor(
                      enabled
                          ? OSColors.textSecondary(dark)
                          : OSColors.textMuted(dark),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InboxStatusPill extends StatelessWidget {
  const _InboxStatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: context.textStyles.labelSmall,
      ),
    );
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

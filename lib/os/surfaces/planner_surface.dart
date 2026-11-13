import 'package:gradeflow/components/planner/planner_teaching_workspace.dart';
import 'package:gradeflow/components/time_slot_timetable.dart';
import 'package:gradeflow/services/timetable_import_plan.dart';
import 'package:gradeflow/components/timetable_import_dialog.dart';
import 'package:gradeflow/services/home_weekly_timetable_service.dart';
/// GradeFlow OS - Planner Surface
///
/// Teacher-wide calendar, reminders, timetable, and school-wide planning.
/// This surface keeps compatibility with the legacy dashboard preference keys
/// while making /os/planner the visible planning destination.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:gradeflow/components/workspace_shell.dart';
import 'package:gradeflow/nav.dart';
import 'package:gradeflow/os/os_palette.dart';
import 'package:gradeflow/services/auth_service.dart';
import 'package:gradeflow/services/class_service.dart';
import 'package:gradeflow/services/communication_service.dart';
import 'package:gradeflow/services/dashboard_preferences_service.dart';
import 'package:gradeflow/services/file_import_service.dart';
import 'package:gradeflow/services/school_calendar_grid_parser.dart';
import 'package:gradeflow/components/planner/planner_date_math.dart';
import 'package:gradeflow/services/global_system_shell_service.dart';
import 'package:gradeflow/theme.dart';

class PlannerSurface extends StatefulWidget {
  const PlannerSurface({super.key, this.initialDate});
  final DateTime? initialDate;

  @override
  State<PlannerSurface> createState() => _PlannerSurfaceState();
}

enum _PlannerDisplayMode { today, week, month, agenda, tasks }

class _PlannerSurfaceState extends State<PlannerSurface> {
  static const String _remindersPrefsBaseKey = 'dashboard_reminders_v1';
  static const String _legacyRemindersPrefsKey = 'dashboard_reminders';
  static const String _remindersMigrationFlagKey =
      'dashboard_reminders_migrated_v1';
  static const String _timetablesPrefsBaseKey = 'dashboard_timetables_v1';
  static const String _selectedTimetablePrefsBaseKey =
      'dashboard_selected_timetable_v1';

  final DashboardPreferencesService _preferences =
      const DashboardPreferencesService();
  final TextEditingController _reminderCtrl = TextEditingController();

  String? _loadedUserId;
  bool _planningLoading = false;
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _selectedDate = PlannerDateMath.day(DateTime.now());
  _PlannerDisplayMode _displayMode = _PlannerDisplayMode.week;
  List<_PlannerReminder> _reminders = const <_PlannerReminder>[];
  List<_PlannerTimetable> _timetables = const <_PlannerTimetable>[];
  String? _selectedTimetableId;

  @override
  void initState() {
    super.initState();
    _applyInitialDate();
  }

  void _applyInitialDate() {
    final date = widget.initialDate;
    if (date != null) {
      _selectedDate = DateUtils.dateOnly(date);
      _focusedMonth = DateTime(date.year, date.month);
    }
  }

  @override
  void didUpdateWidget(covariant PlannerSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialDate != widget.initialDate) _applyInitialDate();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = Provider.of<AuthService>(context);
    final userId = _plannerStorageUserId(auth);
    if (userId == null) {
      _planningLoading = true;
      return;
    }
    if (_loadedUserId == userId) return;
    _loadedUserId = userId;
    _planningLoading = true;
    unawaited(_loadPlannerState(userId));
  }

  @override
  void dispose() {
    _reminderCtrl.dispose();
    super.dispose();
  }

  String? _plannerStorageUserId(AuthService auth) {
    if (!auth.isInitialized || auth.isLoading) return null;
    return auth.currentUser?.userId;
  }

  Future<void> _loadPlannerState(String userId) async {
    try {
      final reminders = await _loadReminders(userId);
      final timetableState = await _loadTimetables(userId);
      if (!mounted || _loadedUserId != userId) return;
      setState(() {
        _reminders = reminders;
        _timetables = timetableState.timetables;
        _selectedTimetableId = timetableState.selectedTimetableId;
        _planningLoading = false;
      });
    } catch (e) {
      debugPrint('Failed to load planner state: $e');
      if (!mounted || _loadedUserId != userId) return;
      setState(() {
        _planningLoading = false;
      });
    }
  }

  Future<List<_PlannerReminder>> _loadReminders(String userId) async {
    final scopedKey = _preferences.scopedKey(
      baseKey: _remindersPrefsBaseKey,
      userId: userId,
    );
    final rawList = await _preferences.readScopedJsonList(
      scopedKey: scopedKey,
      legacyKey: _legacyRemindersPrefsKey,
      migrationFlagKey: _remindersMigrationFlagKey,
    );

    final reminders = <_PlannerReminder>[];
    for (final rawItem in rawList.whereType<Map>()) {
      final item = Map<String, dynamic>.from(rawItem);
      final text = (item['text'] ?? '').toString().trim();
      if (text.isEmpty) continue;
      final classIds = (item['classIds'] as List?)
              ?.map((value) => value?.toString() ?? '')
              .where((value) => value.trim().isNotEmpty)
              .toList() ??
          const <String>[];
      reminders.add(
        _PlannerReminder(
          text: text,
          timestamp: DateTime.tryParse((item['timestamp'] ?? '').toString()) ??
              DateTime.now(),
          done: (item['done'] as bool?) ?? false,
          classIds: classIds,
          endDate: DateTime.tryParse((item['endDate'] ?? '').toString()),
          kind: (item['kind'] ?? 'legacy').toString(),
        ),
      );
    }
    reminders.sort((left, right) => left.timestamp.compareTo(right.timestamp));
    return reminders;
  }

  Future<_PlannerTimetableState> _loadTimetables(String userId) async {
    final timetableKey = _preferences.scopedKey(
      baseKey: _timetablesPrefsBaseKey,
      userId: userId,
    );
    final selectedKey = _preferences.scopedKey(
      baseKey: _selectedTimetablePrefsBaseKey,
      userId: userId,
    );
    final raw = await _preferences.readScopedString(scopedKey: timetableKey);
    var selectedId = await _preferences.readScopedString(scopedKey: selectedKey);

    final timetables = <_PlannerTimetable>[];
    if (raw != null && raw.trim().isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        for (final entry in decoded.whereType<Map>()) {
          if (entry['selected'] == true) selectedId = entry['id']?.toString();
          final timetable =
              _PlannerTimetable.fromJson(Map<String, dynamic>.from(entry));
          if (timetable.id.trim().isEmpty || timetable.name.trim().isEmpty) {
            continue;
          }
          timetables.add(timetable);
        }
      }
    }
    timetables.sort(
      (left, right) => right.uploadedAt.compareTo(left.uploadedAt),
    );

    final selectedTimetableId =
        timetables.any((item) => item.id == selectedId) ? selectedId : null;
    return _PlannerTimetableState(
      timetables: timetables,
      selectedTimetableId: selectedTimetableId,
    );
  }

  String? _remindersPrefsKey() {
    final userId = _loadedUserId;
    if (userId == null) return null;
    return _preferences.scopedKey(
      baseKey: _remindersPrefsBaseKey,
      userId: userId,
    );
  }

  Future<void> _saveReminders() async {
    try {
      final key = _remindersPrefsKey();
      if (key == null) return;
      await _preferences.writeJsonList(
        key: key,
        items: _reminders
            .map(
              (reminder) => {
                'text': reminder.text,
                'timestamp': reminder.timestamp.toIso8601String(),
                'endDate': reminder.endDate?.toIso8601String(),
                'kind': reminder.kind,
                'done': reminder.done,
                'classIds':
                    reminder.classIds.isEmpty ? null : reminder.classIds,
              },
            )
            .toList(),
      );
      await _refreshShellSnapshotOnly();
    } catch (e) {
      debugPrint('Failed to save planner reminders: $e');
      _showPlannerFeedback(
        'Could not save the reminder change.',
        tone: WorkspaceFeedbackTone.error,
      );
    }
  }

  Future<void> _changeTimetableVersion(String versionId, {bool delete = false}) async {
    final userId = _plannerStorageUserId(context.read<AuthService>());
    if (userId == null || userId != _loadedUserId) return;
    try {
      await const HomeWeeklyTimetableService().changeVersion(userId, versionId: versionId, delete: delete);
      if (!mounted || _plannerStorageUserId(context.read<AuthService>()) != userId) return;
      await _loadPlannerState(userId);
    } catch (e) {
      if (mounted) _showPlannerFeedback('Timetable change was not saved: $e', tone: WorkspaceFeedbackTone.error);
    }
  }

  Future<void> _refreshShellSnapshotOnly() async {
    if (!mounted) return;
    final auth = context.read<AuthService>();
    await context.read<GlobalSystemShellController>().refreshWorkspaceSnapshot(
          auth,
        );
  }

  Future<void> _refreshSnapshot() async {
    final auth = context.read<AuthService>();
    setState(() => _planningLoading = true);
    await context.read<GlobalSystemShellController>().refreshWorkspaceSnapshot(
          auth,
        );
    final userId = _plannerStorageUserId(auth);
    if (userId == null) return;
    if (!mounted) return;
    await _loadPlannerState(userId);
  }

  void _showPlannerFeedback(
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

  Future<void> _addReminderForSelectedDate() async {
    final text = _reminderCtrl.text.trim();
    final selected = _selectedDate;
    if (text.isEmpty || selected == null) return;
    final reminder = _PlannerReminder(
      text: text,
      timestamp: DateTime(selected.year, selected.month, selected.day),
      kind: 'task',
    );
    setState(() {
      _reminders = [..._reminders, reminder]
        ..sort((left, right) => left.timestamp.compareTo(right.timestamp));
      _reminderCtrl.clear();
    });
    await _saveReminders();
  }

  Future<void> _toggleReminder(
    _PlannerReminder reminder,
    bool done,
  ) async {
    setState(() => reminder.done = done);
    await _saveReminders();
  }

  Future<void> _deleteReminder(_PlannerReminder reminder) async {
    setState(() {
      _reminders = _reminders.where((item) => item != reminder).toList();
    });
    await _saveReminders();
  }

  Future<void> _importCalendarFile() async {
    try {
      final picked = await FilePicker.platform.pickFiles(
        withData: true,
        type: FileType.custom,
        allowedExtensions: const ['xlsx', 'csv'],
      );
      if (picked == null || picked.files.single.bytes == null) return;

      final bytes = picked.files.single.bytes!;
      final filename = picked.files.single.name;
      final imported = _parseCalendarReminders(bytes, filename);
      if (imported.isEmpty) {
        _showPlannerFeedback(
          'No calendar events were found in that file.',
          tone: WorkspaceFeedbackTone.warning,
        );
        return;
      }

      // Avoid duplicate calendar imports and preserve prior completion state.
      final known = _reminders.map(_calendarImportKey).toSet();
      final added = <_PlannerReminder>[];
      for (final event in imported) {
        if (known.add(_calendarImportKey(event))) added.add(event);
      }
      if (added.isEmpty) {
        _showPlannerFeedback(
          'All ${imported.length} calendar events are already in Planner.',
          tone: WorkspaceFeedbackTone.info,
          title: 'No duplicates added',
        );
        return;
      }
      // Confirm the detected event count before touching existing reminders.
      // Import is additive and the teacher can cancel without making changes.
      final approved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Import school calendar?'),
          content: SizedBox(
            width: 520,
            height: 320,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Found ${imported.length} events in $filename. '
                  '${added.length} are new; '
                  '${imported.length - added.length} already exist.',
                ),
                const SizedBox(height: 8),
                const Text(
                  'This adds school events to Planner. It will not replace '
                  'your existing reminders, classes, or completed items.',
                ),
                const Divider(height: 22),
                const Text('First events',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Expanded(
                  child: ListView.builder(
                    itemCount: added.length < 12 ? added.length : 12,
                    itemBuilder: (_, index) {
                      final event = added[index];
                      final date = _formatDate(event.timestamp);
                      final range = event.endDate == null
                          ? date
                          : '$date – ${_formatDate(event.endDate!)}';
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(event.text),
                        subtitle: Text(range),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text('Import ${added.length} events'),
            ),
          ],
        ),
      );
      if (!mounted || approved != true) return;
      setState(() {
        _reminders = [..._reminders, ...added]
          ..sort((left, right) => left.timestamp.compareTo(right.timestamp));
      });
      await _saveReminders();
      _showPlannerFeedback(
        'Imported ${added.length} new event${added.length == 1 ? '' : 's'}'
        ' (${imported.length - added.length} already present).',
        tone: WorkspaceFeedbackTone.success,
        title: 'Calendar updated',
      );
    } catch (e) {
      debugPrint('Planner calendar import failed: $e');
      _showPlannerFeedback(
        'Calendar import failed. Use a CSV or Excel file with date and event columns.',
        tone: WorkspaceFeedbackTone.error,
      );
    }
  }

  List<_PlannerReminder> _parseCalendarReminders(
    Uint8List bytes,
    String filename,
  ) {
    final rows = FileImportService().rowsFromAnyBytes(bytes);
    if (rows.isEmpty) return const <_PlannerReminder>[];

    // The school calendar is a weekly grid with many dated events per cell.
    // Never parse its "Date: Event" column as both a date and a title.
    if (SchoolCalendarGridParser.matches(rows)) {
      return SchoolCalendarGridParser.parse(rows, filename: filename)
          .map((event) => _PlannerReminder(
                text: event.title,
                timestamp: event.start,
                endDate: event.end.isAfter(event.start) ? event.end : null,
                kind: 'school_event',
              ))
          .toList();
    }

    final headerRowIndex = _pickLikelyCalendarHeaderRow(rows);
    final header = rows[headerRowIndex].map(_normalize).toList();
    final dateIdx = _findHeaderIndex(header, [
      'date',
      'day',
      '\u65e5\u671f',
    ]);
    final titleIdx = _findHeaderIndex(header, [
      'title',
      'event',
      'subject',
      'description',
      'task',
      '\u5167\u5bb9',
      '\u4e8b\u9805',
    ]);
    final detailsIdx = _findHeaderIndex(header, [
      'details',
      'detail',
      'notes',
      'note',
      'remarks',
      'memo',
      'location',
      'room',
      'place',
    ]);
    final timeIdx = _findHeaderIndex(header, [
      'time',
      'start',
      'start time',
    ]);
    final yearGuess = _inferYearFromFilename(filename) ?? DateTime.now().year;

    if (dateIdx == -1 || titleIdx == -1) {
      return _parseMonthGridCalendar(rows, headerRowIndex, header, yearGuess);
    }

    final reminders = <_PlannerReminder>[];
    for (int i = headerRowIndex + 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty) continue;
      String getCell(int idx) =>
          (idx != -1 && idx < row.length ? row[idx].toString() : '').trim();
      final dateStr = getCell(dateIdx);
      final title = getCell(titleIdx);
      if (dateStr.isEmpty || title.isEmpty) continue;
      final details = getCell(detailsIdx);
      final displayTitle = details.isEmpty ? title : '$title - $details';
      DateTime? timestamp = _parseDateFlexible(dateStr);
      if (timestamp == null) continue;
      if (timeIdx != -1) {
        final time = _parseTimeFlexible(getCell(timeIdx));
        if (time != null) {
          timestamp = DateTime(
            timestamp.year,
            timestamp.month,
            timestamp.day,
            time.hour,
            time.minute,
          );
        }
      }
      reminders.add(
        _PlannerReminder(
          text: displayTitle,
          timestamp: timestamp,
          kind: 'school_event',
        ),
      );
    }
    return reminders;
  }

  List<_PlannerReminder> _parseMonthGridCalendar(
    List<List<String>> rows,
    int headerRowIndex,
    List<String> header,
    int yearGuess,
  ) {
    var monthIdx = _findHeaderIndex(header, ['month']);
    var dateEventIdx = _findHeaderIndex(
      header,
      ['date event', 'date event', 'event', 'events'],
    );

    if (monthIdx == -1) {
      int bestIdx = -1;
      int bestHits = 0;
      final sampleEnd =
          rows.length < headerRowIndex + 13 ? rows.length : headerRowIndex + 13;
      final maxCols = rows.fold<int>(
        0,
        (max, row) => row.length > max ? row.length : max,
      );
      for (int c = 0; c < maxCols; c++) {
        int hits = 0;
        for (int r = headerRowIndex + 1; r < sampleEnd; r++) {
          final row = rows[r];
          if (c >= row.length) continue;
          if (_monthFromToken(row[c]) != null) hits++;
        }
        if (hits > bestHits) {
          bestHits = hits;
          bestIdx = c;
        }
      }
      if (bestHits > 0) monthIdx = bestIdx;
    }

    if (dateEventIdx == -1 && rows.length > headerRowIndex + 1) {
      final sampleStart = headerRowIndex + 1;
      final sampleEnd =
          sampleStart + 8 < rows.length ? sampleStart + 8 : rows.length;
      int bestIdx = -1;
      int bestScore = 0;
      for (int c = 0; c < header.length; c++) {
        int score = 0;
        for (int r = sampleStart; r < sampleEnd; r++) {
          final row = rows[r];
          if (c >= row.length) continue;
          final value = row[c].toString().trim();
          if (value.isEmpty) continue;
          if (value.contains(':') || value.contains('\uFF1A')) score += 2;
          if (value.contains('\n')) score += 1;
          if (RegExp(r'\d{1,2}\s*-\s*\d{1,2}').hasMatch(value)) score += 1;
        }
        if (score > bestScore) {
          bestScore = score;
          bestIdx = c;
        }
      }
      if (bestScore >= 3) dateEventIdx = bestIdx;
    }

    if (monthIdx == -1 || dateEventIdx == -1) {
      return const <_PlannerReminder>[];
    }

    final reminders = <_PlannerReminder>[];
    String lastMonthToken = '';
    for (int i = headerRowIndex + 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty) continue;

      String cellAt(int idx) =>
          (idx != -1 && idx < row.length ? row[idx].toString() : '').trim();
      final monthToken = cellAt(monthIdx);
      if (monthToken.isNotEmpty) lastMonthToken = monthToken;

      final eventCell = cellAt(dateEventIdx);
      if (eventCell.isEmpty) continue;

      final monthNumber = _monthFromToken(lastMonthToken);
      final pieces = eventCell
          .split(RegExp(r'\r?\n'))
          .expand((line) => line.split(RegExp(r'\s{2,}')))
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList();

      for (final piece in pieces) {
        String token = '';
        String title = '';

        final colon = RegExp(r'^(.+?)\s*[:\uFF1A]\s*(.+)$').firstMatch(piece);
        if (colon != null) {
          token = colon.group(1)!.trim();
          title = colon.group(2)!.trim();
        } else {
          final leadDate = RegExp(
            r'^(\d{1,2}(?:\s*-\s*\d{1,2}(?:\s*/\s*\d{1,2})?)?)\s+(.+)$',
          ).firstMatch(piece);
          if (leadDate == null) continue;
          token = leadDate.group(1)!.trim();
          title = leadDate.group(2)!.trim();
        }

        if (title.isEmpty) continue;
        final timestamp = _parseSchoolCalendarDateToken(
          token,
          year: yearGuess,
          month: monthNumber,
        );
        if (timestamp == null) continue;
        reminders.add(_PlannerReminder(
          text: title,
          timestamp: timestamp,
          kind: 'school_event',
        ));
      }
    }
    return reminders;
  }

  Future<void> _pickAndUploadTimetable() async {
    try {
      final picked = await FilePicker.platform.pickFiles(
        withData: true,
        type: FileType.custom,
        allowedExtensions: const ['xlsx', 'csv', 'docx'],
      );
      if (picked == null || picked.files.single.bytes == null) return;
      await _saveTimetableFromBytes(
        picked.files.single.bytes!,
        picked.files.single.name,
        picked.files.single.extension,
      );
    } catch (e) {
      debugPrint('Planner timetable upload failed: $e');
      _showPlannerFeedback(
        'Timetable was not imported: $e',
        tone: WorkspaceFeedbackTone.error,
      );
    }
  }

  Future<void> _saveTimetableFromBytes(
    Uint8List bytes,
    String name,
    String? extension,
  ) async {
    final userId = _plannerStorageUserId(context.read<AuthService>());
    if (userId == null) throw StateError('Sign in before importing a timetable.');
    final saved = await confirmTimetableImport(context, filename: name, bytes: bytes);
    if (saved == null || !mounted || _plannerStorageUserId(context.read<AuthService>()) != userId) return;
    await _loadPlannerState(userId);
    _showPlannerFeedback('Saved ${saved.classes.length} individual periods on this device.',
      tone: WorkspaceFeedbackTone.success, title: 'Timetable saved locally');
  }

  Future<void> _selectTimetable(_PlannerTimetable timetable) async {
    if (timetable.lessons == null) {
      try {
        await _saveTimetableFromBytes(base64Decode(timetable.base64), timetable.name, timetable.mimeType);
      } catch (e) {
        if (mounted) _showPlannerFeedback('Review or reimport this older timetable before selecting it: $e', tone: WorkspaceFeedbackTone.error);
      }
      return;
    }
    await _changeTimetableVersion(timetable.id);
  }

  Future<void> _deleteTimetable(_PlannerTimetable timetable) async {
    await _changeTimetableVersion(timetable.id, delete: true);
  }

  Future<void> _showTimetableManagementDialog() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: const Text('Manage timetables'),
            content: SizedBox(
              width: 560,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.icon(
                      onPressed: () async {
                        await _pickAndUploadTimetable();
                        if (dialogContext.mounted) setDialogState(() {});
                      },
                      icon: const Icon(Icons.upload_file_outlined),
                      label: const Text('Upload timetable'),
                      style: WorkspaceButtonStyles.filled(context),
                    ),
                  ),
                  const SizedBox(height: WorkspaceSpacing.md),
                  if (_timetables.isEmpty)
                    const WorkspaceInlineState(
                      icon: Icons.table_chart_outlined,
                      title: 'No timetables stored',
                      subtitle:
                          'Upload a CSV, Excel, or Word timetable table from Planner.',
                    )
                  else
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 360),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _timetables.length,
                        itemBuilder: (context, index) {
                          final timetable = _timetables[index];
                          final selected = timetable.id == _selectedTimetableId;
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              selected
                                  ? Icons.check_circle_rounded
                                  : Icons.table_chart_outlined,
                              color: selected
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                            ),
                            title: Text(
                              timetable.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              'Uploaded ${_formatDate(timetable.uploadedAt)}',
                            ),
                            onTap: () async {
                              await _selectTimetable(timetable);
                              if (dialogContext.mounted) setDialogState(() {});
                            },
                            trailing: IconButton(
                              tooltip: 'Delete timetable',
                              icon: const Icon(Icons.delete_outline_rounded),
                              onPressed: () async {
                                final confirmed = await showDialog<bool>(
                                  context: dialogContext,
                                  builder: (confirmContext) => AlertDialog(
                                    title: const Text('Delete timetable'),
                                    content: Text(
                                      'Delete "${timetable.name}" from Planner?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(
                                          confirmContext,
                                          false,
                                        ),
                                        child: const Text('Cancel'),
                                      ),
                                      FilledButton(
                                        onPressed: () => Navigator.pop(
                                          confirmContext,
                                          true,
                                        ),
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed != true) return;
                                await _deleteTimetable(timetable);
                                if (dialogContext.mounted) {
                                  setDialogState(() {});
                                }
                              },
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // All entries belong to the signed-in teacher's user-scoped Planner.
    // Keep class-linked items available in the filtered calendar as well.
    final calendarEntries = [..._reminders]
      ..sort((left, right) => left.timestamp.compareTo(right.timestamp));
    final today = PlannerDateMath.day(DateTime.now());
    final endOfComingUp = today.add(const Duration(days: 29));
    final comingUp = calendarEntries.where((reminder) =>
        (reminder.kind == 'school_event' || !reminder.done) &&
        PlannerDateMath.intersects(reminder.timestamp, reminder.endDate,
            today, endOfComingUp)).toList();
    final selectedTimetable = _planningLoading || _selectedTimetableId == null
        ? null
        : _timetables
            .where((item) => item.id == _selectedTimetableId)
            .firstOrNull;
    final classes = context.watch<ClassService>().activeClasses;
    final shellSnapshot =
        context.watch<GlobalSystemShellController>().workspaceSnapshot;
    final totalStudents = shellSnapshot?.totalStudents ?? 0;
    final unread = context.watch<CommunicationService>().totalUnreadCount;

    return _PlannerDashboardView(
      loading: _planningLoading,
      classesCount: classes.length,
      totalStudents: totalStudents,
      unread: unread,
      pendingReminders: comingUp,
      allReminders: calendarEntries,
      displayMode: _displayMode,
      onChangeDisplayMode: (mode) => setState(() => _displayMode = mode),
      onShiftWeek: (weeks) => setState(() {
        final anchor = _selectedDate ?? PlannerDateMath.day(DateTime.now());
        final next = PlannerDateMath.shiftWeek(anchor, weeks);
        _selectedDate = next;
        _focusedMonth = DateTime(next.year, next.month);
      }),
      onGoToday: () => setState(() {
        final today = PlannerDateMath.day(DateTime.now());
        _selectedDate = today;
        _focusedMonth = DateTime(today.year, today.month);
      }),
      timetables: _timetables,
      selectedTimetable: selectedTimetable,
      focusedMonth: _focusedMonth,
      selectedDate: _selectedDate,
      reminderController: _reminderCtrl,
      onRefresh: _refreshSnapshot,
      onPreviousMonth: () => setState(
        () => _focusedMonth = DateTime(
          _focusedMonth.year,
          _focusedMonth.month - 1,
        ),
      ),
      onNextMonth: () => setState(
        () => _focusedMonth = DateTime(
          _focusedMonth.year,
          _focusedMonth.month + 1,
        ),
      ),
      onSelectDate: (date) => setState(() {
        _selectedDate = PlannerDateMath.day(date);
        _focusedMonth = DateTime(date.year, date.month);
      }),
      onClearSelectedDate: () => setState(() => _selectedDate = null),
      onAddReminder: _addReminderForSelectedDate,
      onToggleReminder: _toggleReminder,
      onDeleteReminder: _deleteReminder,
      onImportCalendar: _importCalendarFile,
      onUploadTimetable: _pickAndUploadTimetable,
      onManageTimetables: _showTimetableManagementDialog,
    );
  }
}

class _PlannerDashboardView extends StatelessWidget {
  const _PlannerDashboardView({
    required this.loading,
    required this.classesCount,
    required this.totalStudents,
    required this.unread,
    required this.pendingReminders,
    required this.allReminders,
    required this.displayMode,
    required this.onChangeDisplayMode,
    required this.onShiftWeek,
    required this.onGoToday,
    required this.timetables,
    required this.selectedTimetable,
    required this.focusedMonth,
    required this.selectedDate,
    required this.reminderController,
    required this.onRefresh,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onSelectDate,
    required this.onClearSelectedDate,
    required this.onAddReminder,
    required this.onToggleReminder,
    required this.onDeleteReminder,
    required this.onImportCalendar,
    required this.onUploadTimetable,
    required this.onManageTimetables,
  });

  final bool loading;
  final int classesCount;
  final int totalStudents;
  final int unread;
  final List<_PlannerReminder> pendingReminders;
  final List<_PlannerReminder> allReminders;
  final _PlannerDisplayMode displayMode;
  final ValueChanged<_PlannerDisplayMode> onChangeDisplayMode;
  final ValueChanged<int> onShiftWeek;
  final VoidCallback onGoToday;
  final List<_PlannerTimetable> timetables;
  final _PlannerTimetable? selectedTimetable;
  final DateTime focusedMonth;
  final DateTime? selectedDate;
  final TextEditingController reminderController;
  final VoidCallback onRefresh;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final ValueChanged<DateTime> onSelectDate;
  final VoidCallback onClearSelectedDate;
  final VoidCallback onAddReminder;
  final void Function(_PlannerReminder reminder, bool done) onToggleReminder;
  final ValueChanged<_PlannerReminder> onDeleteReminder;
  final VoidCallback onImportCalendar;
  final VoidCallback onUploadTimetable;
  final VoidCallback onManageTimetables;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final user = context.watch<AuthService>().currentUser;
    final name = (user?.fullName.trim().isNotEmpty ?? false)
        ? user!.fullName.trim()
        : 'Teacher';
    final now = DateTime.now();
    final chosenDay = selectedDate ?? PlannerDateMath.day(now);

    final lessons = <TimeSlotClass>[];
    PlannerLunch? lunch;
    final periods = <({int start, int end})>[];
    try {
      if (selectedTimetable?.lessons != null) {
        lessons.addAll(selectedTimetable!.lessons!.map((v) => HomeWeeklyTimetableService.lessonFromJson(Map<String, dynamic>.from(v as Map))));
      } else if (selectedTimetable?.grid != null) {
        lessons.addAll(HomeWeeklyTimetableService.parseGridToTimeSlots(selectedTimetable!.grid!));
      }
      for (final row in selectedTimetable?.grid ?? <List<String>>[]) {
        final times = RegExp(r'\d{1,2}:\d{2}').allMatches(row.join(' ')).map((m) => m[0]!).toList();
        if (times.length != 2) continue;
        final start = TimetableImportPlan.clock(times[0]);
        final end = TimetableImportPlan.clock(times[1]);
        if (end <= start) continue;
        if (RegExp(r'\blunch\b|午餐|午休', caseSensitive: false).hasMatch(row.join(' '))) {
          lunch = PlannerLunch(start, end);
        } else {
          periods.add((start: start, end: end));
        }
      }
    } on FormatException { /* Keep older incomplete timetables available for reimport. */ }
    final teaching = PlannerTeachingWorkspace(lessons: lessons,
      classes: context.read<ClassService>().activeClasses.where((c) => c.teacherId == user?.userId).toList(),
      date: chosenDay, todayView: displayMode == _PlannerDisplayMode.today, lunch: lunch, periods: periods,
      onSelectDate: (day) { onSelectDate(day); onChangeDisplayMode(_PlannerDisplayMode.today); },
      onUpload: onUploadTimetable, onManage: onManageTimetables);
    final calendar = switch (displayMode) {
      _PlannerDisplayMode.today => const SizedBox.shrink(),
      _PlannerDisplayMode.week => _PlannerWeekCard(
          selectedDate: chosenDay,
          reminders: allReminders,
          onSelectDate: onSelectDate,
          onShiftWeek: onShiftWeek,
        ),
      _PlannerDisplayMode.month => _PlannerCalendarCard(
          reminders: allReminders,
          focusedMonth: focusedMonth,
          selectedDate: selectedDate,
          reminderController: reminderController,
          onPreviousMonth: onPreviousMonth,
          onNextMonth: onNextMonth,
          onSelectDate: onSelectDate,
          onClearSelectedDate: onGoToday,
          onAddReminder: onAddReminder,
          onToggleReminder: onToggleReminder,
          onDeleteReminder: onDeleteReminder,
        ),
      _PlannerDisplayMode.agenda => _PlannerAgendaCard(
          reminders: pendingReminders,
          selectedDate: chosenDay,
          onSelectDate: onSelectDate,
        ),
      _PlannerDisplayMode.tasks => _PlannerTasksCard(
          reminders: allReminders,
          onToggleReminder: onToggleReminder,
          onSelectDate: onSelectDate,
        ),
    };
    final reminders = _PlannerReminderCard(
        reminders: pendingReminders,
        onSelectDate: onSelectDate,
        onImportCalendar: onImportCalendar,
        onToggleReminder: onToggleReminder,
        onDeleteReminder: onDeleteReminder);
    final dayDetail = _PlannerCard(
        child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _PlannerCardHeader(title: 'Selected day'),
        const SizedBox(height: 12),
        _SelectedDayEditor(
          selectedDate: chosenDay,
          reminders: allReminders,
          reminderController: reminderController,
          onClearSelectedDate: onGoToday,
          onAddReminder: onAddReminder,
          onToggleReminder: onToggleReminder,
          onDeleteReminder: onDeleteReminder,
        ),
      ],
    ));
    final rightRail = Column(children: [
      if (displayMode != _PlannerDisplayMode.month) ...[
        dayDetail,
        const SizedBox(height: 16),
      ],
      reminders,
    ]);

    return Theme(
        data: Theme.of(context),
        child: Scaffold(
          backgroundColor:
              dark ? const Color(0xff07131f) : const Color(0xfff0f5fa),
          body: SafeArea(
              child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 100),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _PlannerTopBar(
                            name: name,
                            dateLabel: _formatLongPlannerDate(now),
                            onRefresh: onRefresh),
                        if (loading)
                          const LinearProgressIndicator(minHeight: 2),
                        const SizedBox(height: 16),
                        _PlannerDisplaySwitch(
                          mode: displayMode,
                          onChange: onChangeDisplayMode,
                          onGoToday: onGoToday,
                        ),
                        const SizedBox(height: 8),
                        if (displayMode == _PlannerDisplayMode.week) Text('Selected: ${_formatDate(chosenDay)}'),
                        TextButton.icon(onPressed: onImportCalendar, icon: const Icon(Icons.calendar_month_outlined), label: const Text('Import calendar')),
                        const SizedBox(height: 16),
                        if (displayMode == _PlannerDisplayMode.week || displayMode == _PlannerDisplayMode.today) ...[
                          teaching,
                          const SizedBox(height: 16),
                        ],
                        if (displayMode == _PlannerDisplayMode.today) dayDetail
                        else if (displayMode == _PlannerDisplayMode.week) ...[
                          // Keep upcoming reminders visible without restoring
                          // the old permanent multi-column dashboard.
                          if (pendingReminders.isNotEmpty) ...[
                            reminders,
                            const SizedBox(height: 12),
                          ],
                          // If no timetable is imported, the calendar is still
                          // immediately usable. Once lessons exist, this is
                          // secondary to the full-width teaching grid.
                          ExpansionTile(
                            key: ValueKey('planner-week-calendar-${lessons.isEmpty ? 'empty' : 'loaded'}'),
                            initiallyExpanded: lessons.isEmpty,
                            title: const Text('Week dates & school events'),
                            subtitle: const Text('Open the week calendar'),
                            children: [calendar],
                          ),
                        ]
                        else LayoutBuilder(
                            builder: (context, size) => size.maxWidth >= 900
                                ? Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(flex: 6, child: calendar),
                                      const SizedBox(width: 18),
                                      Expanded(flex: 5, child: rightRail),
                                    ])
                                : Column(children: [
                                    calendar,
                                    const SizedBox(height: 16),
                                    rightRail,
                                  ])),
                      ]))),
        ));
  }
}

class _PlannerDisplaySwitch extends StatelessWidget {
  const _PlannerDisplaySwitch({
    required this.mode,
    required this.onChange,
    required this.onGoToday,
  });

  final _PlannerDisplayMode mode;
  final ValueChanged<_PlannerDisplayMode> onChange;
  final VoidCallback onGoToday;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      key: const ValueKey('planner-view-picker'),
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final entry in const [
          (_PlannerDisplayMode.today, 'Today'),
          (_PlannerDisplayMode.week, 'Week'),
          (_PlannerDisplayMode.month, 'Month'),
          (_PlannerDisplayMode.agenda, 'Agenda'),
          (_PlannerDisplayMode.tasks, 'Tasks'),
        ])
          ChoiceChip(
            key: ValueKey('planner-view-${entry.$2.toLowerCase()}'),
            label: Text(entry.$2),
            selected: mode == entry.$1,
            onSelected: (_) => onChange(entry.$1),
          ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: () { onGoToday(); onChange(_PlannerDisplayMode.today); },
          icon: const Icon(Icons.today_outlined, size: 18),
          label: const Text('Go to today'),
        ),
      ],
    );
  }
}

/// The default teaching calendar: a 7-day strip with real event counts,
/// previewing the first school event or task for each day.
class _PlannerWeekCard extends StatelessWidget {
  const _PlannerWeekCard({
    required this.selectedDate,
    required this.reminders,
    required this.onSelectDate,
    required this.onShiftWeek,
  });

  final DateTime selectedDate;
  final List<_PlannerReminder> reminders;
  final ValueChanged<DateTime> onSelectDate;
  final ValueChanged<int> onShiftWeek;

  @override
  Widget build(BuildContext context) {
    final start = PlannerDateMath.weekStart(selectedDate);
    final end = start.add(const Duration(days: 6));
    final dark = context.isDark;
    final theme = Theme.of(context);
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return _PlannerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PlannerCardHeader(title: 'Calendar'),
          const SizedBox(height: 10),
          Row(
            children: [
              IconButton(
                key: const ValueKey('planner-previous-week'),
                tooltip: 'Previous week',
                onPressed: () => onShiftWeek(-1),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Column(children: [
                  Text(
                    '${_monthName(selectedDate.month)} ${selectedDate.year}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '${_formatDate(start)} – ${_formatDate(end)}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: OSColors.textSecondary(dark),
                    ),
                  ),
                ]),
              ),
              IconButton(
                key: const ValueKey('planner-next-week'),
                tooltip: 'Next week',
                onPressed: () => onShiftWeek(1),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int index = 0; index < 7; index++) ...[
                if (index > 0) const SizedBox(width: 4),
                Expanded(
                  child: Builder(builder: (context) {
                    final date = start.add(Duration(days: index));
                    final entries = reminders.where((item) =>
                        item.occursOn(date) &&
                        (item.kind == 'school_event' || !item.done)).toList();
                    final chosen = PlannerDateMath.isSameDay(date, selectedDate);
                    final today = PlannerDateMath.isSameDay(date, DateTime.now());
                    return InkWell(
                      key: ValueKey('planner-week-date-${_formatDate(date)}'),
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => onSelectDate(date),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 128),
                        padding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 3),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: chosen
                              ? theme.colorScheme.primaryContainer
                              : dark
                                  ? const Color(0xFF19293B)
                                  : const Color(0xFFF1F6FC),
                          border: Border.all(
                            color: chosen
                                ? theme.colorScheme.primary
                                : today
                                    ? theme.colorScheme.primary.withValues(alpha: .5)
                                    : theme.colorScheme.outline.withValues(alpha: .12),
                          ),
                        ),
                        child: Column(children: [
                          Text(
                            days[index],
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${date.day}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (entries.isNotEmpty) ...[
                            Container(
                              key: ValueKey('planner-week-count-${_formatDate(date)}'),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(alpha: .12),
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Text(
                                '${entries.length}',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              entries.first.text,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontSize: 9.5,
                                color: OSColors.textSecondary(dark),
                              ),
                            ),
                          ] else
                            Text(
                              '—',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: OSColors.textSecondary(dark),
                              ),
                            ),
                        ]),
                      ),
                    );
                  }),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Choose a day to see school events and tasks alongside this week.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: OSColors.textSecondary(dark),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlannerAgendaCard extends StatelessWidget {
  const _PlannerAgendaCard({
    required this.reminders,
    required this.selectedDate,
    required this.onSelectDate,
  });

  final List<_PlannerReminder> reminders;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onSelectDate;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final items = [...reminders]..sort((a, b) =>
        a.timestamp.compareTo(b.timestamp));
    return _PlannerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PlannerCardHeader(title: 'Agenda'),
          const SizedBox(height: 4),
          Text(
            'Upcoming school events and tasks · next 30 days',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: OSColors.textSecondary(dark),
            ),
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            const Text('Nothing scheduled in the next 30 days.')
          else
            for (final reminder in items.take(32))
              _PlannerDatedItem(
                reminder: reminder,
                onTap: () => onSelectDate(reminder.timestamp),
                selected: PlannerDateMath.isSameDay(
                    reminder.timestamp, selectedDate),
              ),
          if (items.length > 32)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                '${items.length - 32} more entries. Choose dates in Month view.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}

class _PlannerTasksCard extends StatelessWidget {
  const _PlannerTasksCard({
    required this.reminders,
    required this.onToggleReminder,
    required this.onSelectDate,
  });

  final List<_PlannerReminder> reminders;
  final void Function(_PlannerReminder reminder, bool done) onToggleReminder;
  final ValueChanged<DateTime> onSelectDate;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final tasks = reminders
        .where((item) => item.kind == 'task' && !item.done)
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return _PlannerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PlannerCardHeader(title: 'My tasks'),
          const SizedBox(height: 4),
          Text(
            'Unfinished to-dos · imported school events stay in Calendar',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: OSColors.textSecondary(dark),
            ),
          ),
          const SizedBox(height: 12),
          if (tasks.isEmpty)
            const Text('No unfinished tasks. Select a day to add one.')
          else
            for (final task in tasks.take(30))
              _PlannerDatedItem(
                reminder: task,
                onTap: () => onSelectDate(task.timestamp),
                trailing: Checkbox(
                  value: task.done,
                  onChanged: (checked) =>
                      onToggleReminder(task, checked ?? false),
                ),
              ),
          if (tasks.length > 30)
            Text(
              '${tasks.length - 30} further tasks remain. Select a date to review them.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }
}

class _PlannerDatedItem extends StatelessWidget {
  const _PlannerDatedItem({
    required this.reminder,
    required this.onTap,
    this.selected = false,
    this.trailing,
  });

  final _PlannerReminder reminder;
  final VoidCallback onTap;
  final bool selected;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final kind = reminder.kind;
    final (color, icon, label) = switch (kind) {
      'school_event' => (const Color(0xff158a9c), Icons.school_outlined, 'School event'),
      'task' => (const Color(0xffb47d2b), Icons.task_alt_outlined, 'Task'),
      _ => (const Color(0xff798b9b), Icons.event_note_outlined, 'Other date'),
    };
    final dark = context.isDark;
    final end = reminder.endDate;
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Material(
        color: selected
            ? Theme.of(context).colorScheme.primaryContainer
            : dark
                ? const Color(0xFF1A2837)
                : const Color(0xFFF4F8FC),
        borderRadius: BorderRadius.circular(14),
        child: ListTile(
          dense: true,
          onTap: onTap,
          leading: CircleAvatar(
            radius: 18,
            backgroundColor: color.withValues(alpha: .13),
            child: Icon(icon, color: color, size: 17),
          ),
          title: Text(
            reminder.text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: Text(
            '$label · ${_formatDate(reminder.timestamp)}'
            '${end == null ? '' : ' – ${_formatDate(end)}'}',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: OSColors.textSecondary(dark),
            ),
          ),
          trailing: trailing ?? const Icon(Icons.chevron_right_rounded),
        ),
      ),
    );
  }
}

class _PlannerTopBar extends StatelessWidget {
  const _PlannerTopBar({
    required this.name,
    required this.dateLabel,
    required this.onRefresh,
  });

  final String name;
  final String dateLabel;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xff173b63), Color(0xff187f79)]),
          borderRadius: BorderRadius.circular(24)),
      child: Row(children: [
        IconButton(
            tooltip: 'Back to Home',
            onPressed: () => context.go(AppRoutes.osHome),
            icon: const Icon(Icons.arrow_back, color: Colors.white)),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Planner',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800)),
          Text('$dateLabel · $name',
              style: const TextStyle(color: Colors.white70))
        ])),
        IconButton(
            tooltip: 'Refresh planner',
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white))
      ]),
    );
  }
}

class _PlannerReminderCard extends StatelessWidget {
  const _PlannerReminderCard({
    required this.reminders,
    required this.onImportCalendar,
    required this.onSelectDate,
    required this.onToggleReminder,
    required this.onDeleteReminder,
  });

  final List<_PlannerReminder> reminders;
  final VoidCallback onImportCalendar;
  final ValueChanged<DateTime> onSelectDate;
  final void Function(_PlannerReminder reminder, bool done) onToggleReminder;
  final ValueChanged<_PlannerReminder> onDeleteReminder;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final visible = reminders.take(4).toList();
    return _PlannerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PlannerCardHeader(
            title: 'Coming up',
            actionLabel: 'Import',
            onAction: onImportCalendar,
          ),
          const SizedBox(height: 4),
          Text(
            'Next 30 days · full list in Agenda',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: OSColors.textSecondary(dark),
            ),
          ),
          const SizedBox(height: 12),
          if (visible.isEmpty)
            Text(
              'No upcoming entries. Import your school calendar or add a task.',
              style: TextStyle(
                color: OSColors.textSecondary(dark),
                height: 1.45,
              ),
            )
          else
            for (final reminder in visible) ...[
              if (reminder.kind == 'task')
                _PlannerReminderTile(
                  reminder: reminder,
                  onToggle: onToggleReminder,
                  onDelete: onDeleteReminder,
                )
              else
                _PlannerDatedItem(
                  reminder: reminder,
                  onTap: () => onSelectDate(reminder.timestamp),
                ),
              if (reminder != visible.last) const SizedBox(height: 9),
            ],
        ],
      ),
    );
  }
}

class _PlannerReminderTile extends StatelessWidget {
  const _PlannerReminderTile({
    required this.reminder,
    required this.onToggle,
    required this.onDelete,
  });

  final _PlannerReminder reminder;
  final void Function(_PlannerReminder reminder, bool done) onToggle;
  final ValueChanged<_PlannerReminder> onDelete;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: dark
            ? Colors.white.withValues(alpha: 0.04)
            : const Color(0xFFF5F7FF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Checkbox(
            value: reminder.done,
            onChanged: (value) => onToggle(reminder, value ?? false),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reminder.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: OSColors.text(dark),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _formatDate(reminder.timestamp),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: OSColors.textSecondary(dark),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Delete reminder',
            onPressed: () => onDelete(reminder),
            icon: const Icon(Icons.more_vert_rounded),
          ),
        ],
      ),
    );
  }
}

class _PlannerCalendarCard extends StatelessWidget {
  const _PlannerCalendarCard({
    required this.reminders,
    required this.focusedMonth,
    required this.selectedDate,
    required this.reminderController,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onSelectDate,
    required this.onClearSelectedDate,
    required this.onAddReminder,
    required this.onToggleReminder,
    required this.onDeleteReminder,
  });

  final List<_PlannerReminder> reminders;
  final DateTime focusedMonth;
  final DateTime? selectedDate;
  final TextEditingController reminderController;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final ValueChanged<DateTime> onSelectDate;
  final VoidCallback onClearSelectedDate;
  final VoidCallback onAddReminder;
  final void Function(_PlannerReminder reminder, bool done) onToggleReminder;
  final ValueChanged<_PlannerReminder> onDeleteReminder;

  @override
  Widget build(BuildContext context) {
    return _PlannerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PlannerCardHeader(title: 'Calendar'),
          const SizedBox(height: 12),
          _MonthGrid(
            focusedMonth: focusedMonth,
            selectedDate: selectedDate,
            reminders: reminders,
            onPreviousMonth: onPreviousMonth,
            onNextMonth: onNextMonth,
            onSelectDate: onSelectDate,
          ),
          const SizedBox(height: 12),
          _SelectedDayEditor(
            selectedDate: selectedDate,
            reminders: reminders,
            reminderController: reminderController,
            onClearSelectedDate: onClearSelectedDate,
            onAddReminder: onAddReminder,
            onToggleReminder: onToggleReminder,
            onDeleteReminder: onDeleteReminder,
          ),
        ],
      ),
    );
  }
}

class _PlannerCardHeader extends StatelessWidget {
  const _PlannerCardHeader({
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: OSColors.text(dark),
            ),
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(
            onPressed: onAction,
            child: Text(actionLabel!),
          ),
      ],
    );
  }
}

class _PlannerCard extends StatelessWidget {
  const _PlannerCard({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: dark
            ? const Color(0xFF111827).withValues(alpha: 0.88)
            : Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: dark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.white.withValues(alpha: 0.86),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.18 : 0.055),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: child,
    );
  }
}

String _formatLongPlannerDate(DateTime now) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  const weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  return '${months[now.month - 1]} ${now.day}, ${weekdays[now.weekday - 1]}';
}

class _PlannerReminder {
  _PlannerReminder({
    required this.text,
    required this.timestamp,
    this.done = false,
    this.classIds = const <String>[],
    this.endDate,
    this.kind = 'legacy',
  });

  final String text;
  final DateTime timestamp;
  /// Inclusive last date for a multi-day school-calendar event.
  final DateTime? endDate;
  /// New imported events and personal tasks remain distinct. Existing records
  /// without a kind retain the neutral 'legacy' category (no data migration).
  final String kind;
  bool done;
  final List<String> classIds;

  bool get isSchoolWide => classIds.isEmpty;

  bool occursOn(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    final start = DateTime(timestamp.year, timestamp.month, timestamp.day);
    final last = endDate ?? timestamp;
    final end = DateTime(last.year, last.month, last.day);
    return !day.isBefore(start) && !day.isAfter(end);
  }
}

class _PlannerTimetableState {
  const _PlannerTimetableState({
    required this.timetables,
    required this.selectedTimetableId,
  });

  final List<_PlannerTimetable> timetables;
  final String? selectedTimetableId;
}

class _PlannerTimetable {
  const _PlannerTimetable({
    required this.id,
    required this.name,
    required this.base64,
    required this.uploadedAt,
    this.mimeType,
    this.grid,
    this.lessons,
  });

  final String id;
  final String name;
  final String base64;
  final String? mimeType;
  final DateTime uploadedAt;
  final List<List<String>>? grid;
  final List<dynamic>? lessons;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'base64': base64,
        'mimeType': mimeType,
        'grid': grid,
        'lessons': lessons,
        'uploadedAt': uploadedAt.toIso8601String(),
      };

  factory _PlannerTimetable.fromJson(Map<String, dynamic> json) {
    return _PlannerTimetable(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      base64: (json['base64'] ?? '').toString(),
      mimeType: json['mimeType']?.toString(),
      lessons: json['lessons'] as List<dynamic>?,
      grid: (json['grid'] is List)
          ? (json['grid'] as List)
              .map(
                (row) =>
                    (row as List?)
                        ?.map((cell) => cell?.toString() ?? '')
                        .toList() ??
                    const <String>[],
              )
              .toList()
          : null,
      uploadedAt: DateTime.tryParse((json['uploadedAt'] ?? '').toString()) ??
          DateTime.now(),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.focusedMonth,
    required this.selectedDate,
    required this.reminders,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onSelectDate,
  });

  final DateTime focusedMonth;
  final DateTime? selectedDate;
  final List<_PlannerReminder> reminders;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final ValueChanged<DateTime> onSelectDate;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final firstDay = DateTime(focusedMonth.year, focusedMonth.month);
    final leadingEmpty = firstDay.weekday - 1;
    final daysInMonth =
        DateTime(focusedMonth.year, focusedMonth.month + 1, 0).day;
    final rows = ((leadingEmpty + daysInMonth) / 7).ceil();

    return Column(
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Previous month',
              onPressed: onPreviousMonth,
              icon: const Icon(Icons.chevron_left_rounded),
              style: WorkspaceButtonStyles.icon(context),
            ),
            Expanded(
              child: Text(
                '${_monthName(focusedMonth.month)} ${focusedMonth.year}',
                textAlign: TextAlign.center,
                style: context.textStyles.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Next month',
              onPressed: onNextMonth,
              icon: const Icon(Icons.chevron_right_rounded),
              style: WorkspaceButtonStyles.icon(context),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: const [
            _WeekdayLabel('Mon'),
            _WeekdayLabel('Tue'),
            _WeekdayLabel('Wed'),
            _WeekdayLabel('Thu'),
            _WeekdayLabel('Fri'),
            _WeekdayLabel('Sat'),
            _WeekdayLabel('Sun'),
          ],
        ),
        const SizedBox(height: 8),
        for (int row = 0; row < rows; row++) ...[
          Row(
            children: [
              for (int col = 0; col < 7; col++)
                Expanded(
                  child: _MonthDayCell(
                    dayNumber: (row * 7 + col) - leadingEmpty + 1,
                    daysInMonth: daysInMonth,
                    focusedMonth: focusedMonth,
                    today: today,
                    selectedDate: selectedDate,
                    reminders: reminders,
                    onSelectDate: onSelectDate,
                  ),
                ),
            ],
          ),
          if (row != rows - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _WeekdayLabel extends StatelessWidget {
  const _WeekdayLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Text(
          label,
          style: WorkspaceTypography.metadata(context)?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _MonthDayCell extends StatelessWidget {
  const _MonthDayCell({
    required this.dayNumber,
    required this.daysInMonth,
    required this.focusedMonth,
    required this.today,
    required this.selectedDate,
    required this.reminders,
    required this.onSelectDate,
  });

  final int dayNumber;
  final int daysInMonth;
  final DateTime focusedMonth;
  final DateTime today;
  final DateTime? selectedDate;
  final List<_PlannerReminder> reminders;
  final ValueChanged<DateTime> onSelectDate;

  @override
  Widget build(BuildContext context) {
    if (dayNumber < 1 || dayNumber > daysInMonth) {
      return const SizedBox(height: 44);
    }

    final date = DateTime(focusedMonth.year, focusedMonth.month, dayNumber);
    final isToday = _isSameDate(today, date);
    final isSelected = selectedDate != null && _isSameDate(selectedDate!, date);
    final hasItems = reminders.any((reminder) =>
        reminder.occursOn(date) &&
        (reminder.kind == 'school_event' || !reminder.done));
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => onSelectDate(date),
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            color: isSelected || isToday
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.72)
                : theme.colorScheme.surface.withValues(alpha: 0.28),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isToday || isSelected
                  ? theme.colorScheme.primary.withValues(alpha: 0.46)
                  : theme.colorScheme.outline.withValues(alpha: 0.14),
            ),
          ),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$dayNumber',
                  style: context.textStyles.bodyMedium?.copyWith(
                    fontWeight: isToday || isSelected ? FontWeight.w800 : null,
                  ),
                ),
                if (hasItems) ...[
                  const SizedBox(width: 5),
                  Icon(
                    Icons.circle,
                    size: 7,
                    color: theme.colorScheme.primary,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectedDayEditor extends StatelessWidget {
  const _SelectedDayEditor({
    required this.selectedDate,
    required this.reminders,
    required this.reminderController,
    required this.onClearSelectedDate,
    required this.onAddReminder,
    required this.onToggleReminder,
    required this.onDeleteReminder,
  });

  final DateTime? selectedDate;
  final List<_PlannerReminder> reminders;
  final TextEditingController reminderController;
  final VoidCallback onClearSelectedDate;
  final VoidCallback onAddReminder;
  final void Function(_PlannerReminder reminder, bool done) onToggleReminder;
  final ValueChanged<_PlannerReminder> onDeleteReminder;

  @override
  Widget build(BuildContext context) {
    final selected = selectedDate;
    if (selected == null) {
      return Text(
        'Select a day to add to-dos or review school-wide events.',
        style: WorkspaceTypography.metadata(context),
      );
    }
    final items = reminders.where((r) => r.occursOn(selected)).toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final school = items.where((item) => item.kind == 'school_event').toList();
    final tasks = items.where((item) => item.kind == 'task').toList();
    final legacy = items.where((item) =>
        item.kind != 'task' && item.kind != 'school_event').toList();
    final dark = context.isDark;

    Widget section(String title, List<_PlannerReminder> entries, IconData icon,
        Color accent) {
      if (entries.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: accent, size: 17),
              const SizedBox(width: 7),
              Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800)),
              const SizedBox(width: 6),
              Text('${entries.length}', style: Theme.of(context).textTheme.labelSmall),
            ]),
            const SizedBox(height: 6),
            for (final entry in entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Container(
                  decoration: BoxDecoration(
                    color: dark ? const Color(0xFF1B2938) : const Color(0xFFF3F7FB),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 9, vertical: 1),
                    title: Text(
                      entry.text,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        decoration: entry.done && entry.kind != 'school_event'
                            ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    subtitle: Text(entry.endDate != null
                        ? '${_formatDate(entry.timestamp)} – ${_formatDate(entry.endDate!)}'
                        : _formatDate(entry.timestamp)),
                    trailing: entry.kind == 'school_event'
                        ? const Tooltip(
                            message: 'School calendar event',
                            child: Icon(Icons.calendar_today_outlined, size: 18))
                        : Row(mainAxisSize: MainAxisSize.min, children: [
                            Checkbox(
                              value: entry.done,
                              onChanged: (value) =>
                                  onToggleReminder(entry, value ?? false),
                            ),
                            IconButton(
                              tooltip: 'Delete reminder',
                              icon: const Icon(Icons.delete_outline_rounded),
                              onPressed: () => onDeleteReminder(entry),
                            ),
                          ]),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
            child: Text(
              'Selected: ${_formatDate(selected)}',
              style: context.textStyles.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: onClearSelectedDate,
            icon: const Icon(Icons.today_rounded, size: 16),
            label: const Text('Today'),
            style: WorkspaceButtonStyles.text(context),
          ),
        ]),
        const SizedBox(height: 10),
        TextField(
          controller: reminderController,
          decoration: InputDecoration(
            labelText: 'Add a to-do for this day',
            hintText: 'Prepare lesson, mark papers, follow up...',
            suffixIcon: IconButton(
              tooltip: 'Add task',
              onPressed: onAddReminder,
              icon: const Icon(Icons.add_circle_outline_rounded),
            ),
          ),
          onSubmitted: (_) => onAddReminder(),
        ),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Text('No events or tasks on this day.',
                style: WorkspaceTypography.metadata(context)),
          )
        else ...[
          section('School events', school, Icons.school_outlined,
              const Color(0xff158a9c)),
          section('My tasks', tasks, Icons.task_alt_outlined,
              const Color(0xffb47d2b)),
          section('Other dated entries', legacy, Icons.event_note_outlined,
              const Color(0xff798b9b)),
        ],
      ],
    );
  }
}

int _pickLikelyCalendarHeaderRow(List<List<String>> rows) {
  if (rows.isEmpty) return 0;
  final limit = rows.length < 12 ? rows.length : 12;
  int bestIndex = 0;
  int bestScore = -1;

  const keywords = <String>[
    'date',
    'day',
    'title',
    'event',
    'month',
    'week',
    'time',
    'details',
    'notes',
    '\u65e5\u671f',
    '\u4e8b\u9805',
    '\u5167\u5bb9',
    '\u6708',
    '\u9031',
  ];
  const weekdayTokens = <String>{
    'sun',
    'mon',
    'tue',
    'wed',
    'thu',
    'fri',
    'sat',
  };

  for (int i = 0; i < limit; i++) {
    final normalized =
        rows[i].map(_normalize).where((value) => value.isNotEmpty).toList();
    if (normalized.length < 2) continue;

    int score = 0;
    for (final cell in normalized) {
      for (final keyword in keywords) {
        final normalizedKeyword = _normalize(keyword);
        if (cell == normalizedKeyword || cell.contains(normalizedKeyword)) {
          score++;
          break;
        }
      }
    }

    final weekdayCount = normalized.where((cell) {
      final compact = cell.replaceAll(' ', '');
      return weekdayTokens.contains(compact);
    }).length;
    if (normalized.contains('week') && weekdayCount >= 5) score += 8;
    if (normalized.contains('month')) score += 3;

    if (score > bestScore) {
      bestScore = score;
      bestIndex = i;
    }
  }

  return bestScore >= 1 ? bestIndex : 0;
}

String _normalize(String value) => value
    .toLowerCase()
    .replaceAll(RegExp(r'[_\-\./\\()\[\]:]'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

int _findHeaderIndex(List<String> headers, List<String> options) {
  for (final raw in options) {
    final normalized = _normalize(raw);
    final exact = headers.indexWhere((header) => header == normalized);
    if (exact != -1) return exact;
    final contains =
        headers.indexWhere((header) => header.contains(normalized));
    if (contains != -1) return contains;
  }
  return -1;
}

int? _inferYearFromFilename(String filename) {
  final match = RegExp(r'^(\d{4})').firstMatch(filename.trim());
  if (match == null) return null;
  return int.tryParse(match.group(1)!);
}

int? _monthFromToken(String token) {
  final normalized = token
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (normalized.isEmpty) return null;
  const map = {
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
  for (final entry in map.entries) {
    if (normalized == entry.key || normalized.startsWith('${entry.key} ')) {
      return entry.value;
    }
  }
  return null;
}

DateTime? _parseSchoolCalendarDateToken(
  String token, {
  required int year,
  int? month,
}) {
  var value = token.trim();
  if (value.isEmpty) return null;
  value = value.replaceAll(RegExp(r'[\(\uFF08].*?[\)\uFF09]'), '').trim();
  value = value
      .replaceAll(
        RegExp(r'\b(mon|tue|wed|thu|fri|sat|sun)\b', caseSensitive: false),
        '',
      )
      .trim();

  final monthDay = RegExp(
    r'^(\d{1,2})\s*/\s*(\d{1,2})(?:\s*-\s*(\d{1,2})\s*/\s*(\d{1,2}))?$',
  ).firstMatch(value);
  if (monthDay != null) {
    final parsedMonth = int.tryParse(monthDay.group(1)!);
    final parsedDay = int.tryParse(monthDay.group(2)!);
    if (parsedMonth != null && parsedDay != null) {
      return DateTime(year, parsedMonth, parsedDay);
    }
  }

  final dayRange = RegExp(r'^(\d{1,2})\s*-\s*(\d{1,2})$').firstMatch(value);
  if (dayRange != null && month != null) {
    final day = int.tryParse(dayRange.group(1)!);
    if (day != null) return DateTime(year, month, day);
  }

  final crossMonthRange =
      RegExp(r'^(\d{1,2})\s*-\s*(\d{1,2})\s*/\s*(\d{1,2})$').firstMatch(value);
  if (crossMonthRange != null) {
    final day = int.tryParse(crossMonthRange.group(1)!);
    final secondMonth = int.tryParse(crossMonthRange.group(2)!);
    final resolvedMonth = month ?? secondMonth;
    if (day != null && resolvedMonth != null) {
      return DateTime(year, resolvedMonth, day);
    }
  }

  final dayOnly = int.tryParse(value);
  if (dayOnly != null && month != null) {
    return DateTime(year, month, dayOnly);
  }

  return _parseDateFlexible(value);
}

DateTime? _parseDateFlexible(String input) {
  if (input.trim().isEmpty) return null;
  final iso = DateTime.tryParse(input);
  if (iso != null) return DateTime(iso.year, iso.month, iso.day);

  final match =
      RegExp(r'^(\d{1,2})[\-/](\d{1,2})[\-/](\d{2,4})').firstMatch(input);
  if (match != null) {
    final first = int.tryParse(match.group(1)!);
    final second = int.tryParse(match.group(2)!);
    final rawYear = int.tryParse(match.group(3)!);
    if (first != null && second != null && rawYear != null) {
      final year = rawYear < 100 ? 2000 + rawYear : rawYear;
      if (first > 12) return DateTime(year, second, first);
      return DateTime(year, first, second);
    }
  }

  final numeric = double.tryParse(input);
  if (numeric != null) {
    final epoch = DateTime(1899, 12, 30);
    return epoch.add(Duration(days: numeric.floor()));
  }
  return null;
}

TimeOfDay? _parseTimeFlexible(String input) {
  if (input.trim().isEmpty) return null;
  final value = input.trim().toLowerCase();
  final match = RegExp(r'^(\d{1,2}):(\d{2})\s*(am|pm)?').firstMatch(value);
  if (match != null) {
    int hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    final period = match.group(3);
    if (period == 'pm' && hour < 12) hour += 12;
    if (period == 'am' && hour == 12) hour = 0;
    return TimeOfDay(
      hour: hour.clamp(0, 23),
      minute: minute.clamp(0, 59),
    );
  }

  final numeric = int.tryParse(value);
  if (numeric != null) {
    return TimeOfDay(
      hour: (numeric ~/ 100).clamp(0, 23),
      minute: (numeric % 100).clamp(0, 59),
    );
  }
  return null;
}

String _calendarImportKey(_PlannerReminder item) =>
    '${_formatDate(item.timestamp)}|'
    '${item.text.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ')}';

bool _isSameDate(DateTime left, DateTime right) =>
    left.year == right.year &&
    left.month == right.month &&
    left.day == right.day;

String _formatDate(DateTime date) =>
    '${date.year}-${_two(date.month)}-${_two(date.day)}';

String _two(int value) => value.toString().padLeft(2, '0');

String _monthName(int month) {
  const names = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  if (month < 1 || month > 12) return '';
  return names[month - 1];
}

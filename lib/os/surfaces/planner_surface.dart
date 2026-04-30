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
import 'package:gradeflow/services/global_system_shell_service.dart';
import 'package:gradeflow/theme.dart';

class PlannerSurface extends StatefulWidget {
  const PlannerSurface({super.key});

  @override
  State<PlannerSurface> createState() => _PlannerSurfaceState();
}

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
  DateTime? _selectedDate;
  List<_PlannerReminder> _reminders = const <_PlannerReminder>[];
  List<_PlannerTimetable> _timetables = const <_PlannerTimetable>[];
  String? _selectedTimetableId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final userId = context.read<AuthService>().currentUser?.userId ?? 'local';
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
    final selectedId =
        await _preferences.readScopedString(scopedKey: selectedKey);

    final timetables = <_PlannerTimetable>[];
    if (raw != null && raw.trim().isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        for (final entry in decoded.whereType<Map>()) {
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

  String _remindersPrefsKey() => _preferences.scopedKey(
        baseKey: _remindersPrefsBaseKey,
        userId: _loadedUserId ?? 'local',
      );

  String _timetablePrefsKey() => _preferences.scopedKey(
        baseKey: _timetablesPrefsBaseKey,
        userId: _loadedUserId ?? 'local',
      );

  String _selectedTimetablePrefsKey() => _preferences.scopedKey(
        baseKey: _selectedTimetablePrefsBaseKey,
        userId: _loadedUserId ?? 'local',
      );

  Future<void> _saveReminders() async {
    try {
      await _preferences.writeJsonList(
        key: _remindersPrefsKey(),
        items: _reminders
            .map(
              (reminder) => {
                'text': reminder.text,
                'timestamp': reminder.timestamp.toIso8601String(),
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

  Future<void> _saveTimetables() async {
    try {
      await _preferences.writeString(
        key: _timetablePrefsKey(),
        value: jsonEncode(_timetables.map((item) => item.toJson()).toList()),
      );
      await _preferences.writeString(
        key: _selectedTimetablePrefsKey(),
        value: _selectedTimetableId,
      );
    } catch (e) {
      debugPrint('Failed to save planner timetables: $e');
      _showPlannerFeedback(
        'Could not save the timetable change.',
        tone: WorkspaceFeedbackTone.error,
      );
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
    final userId = auth.currentUser?.userId ?? 'local';
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

      setState(() {
        _reminders = [..._reminders, ...imported]
          ..sort((left, right) => left.timestamp.compareTo(right.timestamp));
      });
      await _saveReminders();
      _showPlannerFeedback(
        'Imported ${imported.length} calendar event${imported.length == 1 ? '' : 's'}.',
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
        _PlannerReminder(text: displayTitle, timestamp: timestamp),
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
        reminders.add(_PlannerReminder(text: title, timestamp: timestamp));
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
        'Timetable upload failed. Use a CSV, Excel, or Word timetable table.',
        tone: WorkspaceFeedbackTone.error,
      );
    }
  }

  Future<void> _saveTimetableFromBytes(
    Uint8List bytes,
    String name,
    String? extension,
  ) async {
    final ext = (extension ?? (name.contains('.') ? name.split('.').last : ''))
        .toLowerCase();
    List<List<String>> grid;
    if (ext == 'docx') {
      final rawGrid = FileImportService().extractDocxBestTableGrid(bytes);
      grid = FileImportService().cleanTimetableGrid(rawGrid);
    } else {
      final rows = FileImportService().rowsFromAnyBytes(bytes);
      grid = FileImportService().cleanTimetableGrid(rows);
    }

    final hasCells =
        grid.any((row) => row.any((cell) => cell.trim().isNotEmpty));
    if (grid.isEmpty || !hasCells) {
      throw const FormatException('No timetable table found.');
    }

    final timetable = _PlannerTimetable(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      base64: base64Encode(bytes),
      mimeType: ext.isEmpty ? null : ext,
      uploadedAt: DateTime.now(),
      grid: grid,
    );

    setState(() {
      _timetables = [timetable, ..._timetables];
      _selectedTimetableId = timetable.id;
    });
    await _saveTimetables();
    _showPlannerFeedback(
      'Timetable "$name" uploaded.',
      tone: WorkspaceFeedbackTone.success,
      title: 'Timetable ready',
    );
  }

  Future<void> _selectTimetable(_PlannerTimetable timetable) async {
    setState(() => _selectedTimetableId = timetable.id);
    await _saveTimetables();
  }

  Future<void> _deleteTimetable(_PlannerTimetable timetable) async {
    setState(() {
      _timetables =
          _timetables.where((item) => item.id != timetable.id).toList();
      if (_selectedTimetableId == timetable.id) {
        _selectedTimetableId =
            _timetables.isEmpty ? null : _timetables.first.id;
      }
    });
    await _saveTimetables();
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
    final schoolWideReminders = _reminders
        .where((reminder) => reminder.isSchoolWide)
        .toList()
      ..sort((left, right) => left.timestamp.compareTo(right.timestamp));
    final pendingSchoolWide =
        schoolWideReminders.where((reminder) => !reminder.done).toList();
    final selectedTimetable = _selectedTimetableId == null
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
      pendingReminders: pendingSchoolWide,
      allReminders: schoolWideReminders,
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
      onSelectDate: (date) => setState(() => _selectedDate = date),
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

    return Scaffold(
      backgroundColor: OSColors.bg(dark),
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final desktop = constraints.maxWidth >= 1120;
              final content = SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 104),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _PlannerTopBar(
                      name: name,
                      dateLabel: _formatLongPlannerDate(now),
                      onRefresh: onRefresh,
                    ),
                    if (loading) ...[
                      const SizedBox(height: 12),
                      const LinearProgressIndicator(minHeight: 3),
                    ],
                    const SizedBox(height: 26),
                    _PlannerOverviewRow(
                      totalStudents: totalStudents,
                      classesCount: classesCount,
                      remindersCount: pendingReminders.length,
                      timetablesCount: timetables.length,
                    ),
                    const SizedBox(height: 22),
                    if (desktop)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 6,
                            child: _PlannerReminderCard(
                              reminders: pendingReminders,
                              onImportCalendar: onImportCalendar,
                              onToggleReminder: onToggleReminder,
                              onDeleteReminder: onDeleteReminder,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 5,
                            child: _PlannerCalendarCard(
                              reminders: allReminders,
                              focusedMonth: focusedMonth,
                              selectedDate: selectedDate,
                              reminderController: reminderController,
                              onPreviousMonth: onPreviousMonth,
                              onNextMonth: onNextMonth,
                              onSelectDate: onSelectDate,
                              onClearSelectedDate: onClearSelectedDate,
                              onAddReminder: onAddReminder,
                              onToggleReminder: onToggleReminder,
                              onDeleteReminder: onDeleteReminder,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 5,
                            child: _PlannerWeeklyTimetableCard(
                              selectedTimetable: selectedTimetable,
                              timetables: timetables,
                              onUpload: onUploadTimetable,
                              onManage: onManageTimetables,
                            ),
                          ),
                        ],
                      )
                    else ...[
                      _PlannerReminderCard(
                        reminders: pendingReminders,
                        onImportCalendar: onImportCalendar,
                        onToggleReminder: onToggleReminder,
                        onDeleteReminder: onDeleteReminder,
                      ),
                      const SizedBox(height: 16),
                      _PlannerCalendarCard(
                        reminders: allReminders,
                        focusedMonth: focusedMonth,
                        selectedDate: selectedDate,
                        reminderController: reminderController,
                        onPreviousMonth: onPreviousMonth,
                        onNextMonth: onNextMonth,
                        onSelectDate: onSelectDate,
                        onClearSelectedDate: onClearSelectedDate,
                        onAddReminder: onAddReminder,
                        onToggleReminder: onToggleReminder,
                        onDeleteReminder: onDeleteReminder,
                      ),
                      const SizedBox(height: 16),
                      _PlannerWeeklyTimetableCard(
                        selectedTimetable: selectedTimetable,
                        timetables: timetables,
                        onUpload: onUploadTimetable,
                        onManage: onManageTimetables,
                      ),
                    ],
                  ],
                ),
              );

              if (!desktop) return content;

              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(width: 250, child: _PlannerSidebar()),
                  const SizedBox(width: 24),
                  Expanded(child: content),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PlannerSidebar extends StatelessWidget {
  const _PlannerSidebar();

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return _PlannerCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PlannerNavButton(
            icon: Icons.grid_view_rounded,
            label: 'Planner',
            selected: true,
            onTap: () {},
          ),
          _PlannerNavButton(
            icon: Icons.class_rounded,
            label: 'Classrooms',
            onTap: () => context.go(AppRoutes.classes),
          ),
          _PlannerNavButton(
            icon: Icons.people_alt_outlined,
            label: 'Students',
            onTap: () => context.go(AppRoutes.classes),
          ),
          _PlannerNavButton(
            icon: Icons.calendar_month_rounded,
            label: 'Calendar',
            onTap: () {},
          ),
          _PlannerNavButton(
            icon: Icons.table_chart_outlined,
            label: 'Timetable',
            onTap: () {},
          ),
          const Spacer(),
          Text(
            'GradeFlow OS',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 20,
              color: OSColors.text(dark),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlannerNavButton extends StatelessWidget {
  const _PlannerNavButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: selected
                ? OSColors.blue.withValues(alpha: dark ? 0.22 : 0.13)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: selected ? OSColors.blue : OSColors.textSecondary(dark),
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: selected
                      ? OSColors.text(dark)
                      : OSColors.textSecondary(dark),
                ),
              ),
            ],
          ),
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
    final dark = context.isDark;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome back, $name',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: OSColors.text(dark),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                dateLabel,
                style: TextStyle(
                  fontSize: 14,
                  color: OSColors.textSecondary(dark),
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Refresh planner',
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh_rounded),
        ),
        IconButton(
          tooltip: 'Search',
          onPressed: () {},
          icon: const Icon(Icons.search_rounded),
        ),
        IconButton(
          tooltip: 'Settings',
          onPressed: () {},
          icon: const Icon(Icons.settings_outlined),
        ),
      ],
    );
  }
}

class _PlannerOverviewRow extends StatelessWidget {
  const _PlannerOverviewRow({
    required this.totalStudents,
    required this.classesCount,
    required this.remindersCount,
    required this.timetablesCount,
  });

  final int totalStudents;
  final int classesCount;
  final int remindersCount;
  final int timetablesCount;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900 ? 4 : 2;
        final gap = 14.0;
        final width = (constraints.maxWidth - (gap * (columns - 1))) / columns;
        final cards = [
          _PlannerMetricData(
            title: 'No of Students',
            value: totalStudents == 0 ? '--' : '$totalStudents',
            icon: Icons.people_alt_rounded,
            accent: OSColors.indigo,
            tint: const Color(0xFFEDEBFF),
          ),
          _PlannerMetricData(
            title: 'No of Classes',
            value: '$classesCount',
            icon: Icons.class_rounded,
            accent: OSColors.blue,
            tint: const Color(0xFFE9F3FB),
          ),
          _PlannerMetricData(
            title: 'Open reminders',
            value: '$remindersCount',
            icon: Icons.event_note_rounded,
            accent: OSColors.coral,
            tint: const Color(0xFFFFEFEC),
          ),
          _PlannerMetricData(
            title: 'Timetables',
            value: '$timetablesCount',
            icon: Icons.table_chart_rounded,
            accent: OSColors.green,
            tint: const Color(0xFFEAF8F0),
          ),
        ];
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final card in cards)
              SizedBox(width: width, child: _PlannerMetricCard(data: card)),
          ],
        );
      },
    );
  }
}

class _PlannerMetricData {
  const _PlannerMetricData({
    required this.title,
    required this.value,
    required this.icon,
    required this.accent,
    required this.tint,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color accent;
  final Color tint;
}

class _PlannerMetricCard extends StatelessWidget {
  const _PlannerMetricCard({required this.data});

  final _PlannerMetricData data;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return _PlannerCard(
      padding: const EdgeInsets.all(18),
      tint: dark ? null : data.tint,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: data.accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(data.icon, size: 18, color: data.accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  data.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: OSColors.text(dark),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            data.value,
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              color: OSColors.text(dark),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 84,
            height: 3,
            decoration: BoxDecoration(
              color: data.accent,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlannerReminderCard extends StatelessWidget {
  const _PlannerReminderCard({
    required this.reminders,
    required this.onImportCalendar,
    required this.onToggleReminder,
    required this.onDeleteReminder,
  });

  final List<_PlannerReminder> reminders;
  final VoidCallback onImportCalendar;
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
            title: 'Messages',
            actionLabel: 'Import',
            onAction: onImportCalendar,
          ),
          const SizedBox(height: 14),
          if (visible.isEmpty)
            Text(
              'No open planning messages. Import school events or select a day on the calendar.',
              style: TextStyle(
                color: OSColors.textSecondary(dark),
                height: 1.45,
              ),
            )
          else
            for (final reminder in visible) ...[
              _PlannerReminderTile(
                reminder: reminder,
                onToggle: onToggleReminder,
                onDelete: onDeleteReminder,
              ),
              if (reminder != visible.last) const SizedBox(height: 10),
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

class _PlannerWeeklyTimetableCard extends StatelessWidget {
  const _PlannerWeeklyTimetableCard({
    required this.selectedTimetable,
    required this.timetables,
    required this.onUpload,
    required this.onManage,
  });

  final _PlannerTimetable? selectedTimetable;
  final List<_PlannerTimetable> timetables;
  final VoidCallback onUpload;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final rows = _previewTimetableRows(selectedTimetable?.grid);
    final dark = context.isDark;
    return _PlannerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PlannerCardHeader(
            title: 'Weekly Timetable',
            actionLabel: timetables.isEmpty ? 'Upload' : 'Manage',
            onAction: timetables.isEmpty ? onUpload : onManage,
          ),
          const SizedBox(height: 16),
          if (rows.isEmpty)
            Text(
              'Upload a timetable to show the next teaching blocks here.',
              style: TextStyle(
                color: OSColors.textSecondary(dark),
                height: 1.45,
              ),
            )
          else
            for (final row in rows) ...[
              _TimetableListRow(time: row.$1, title: row.$2, detail: row.$3),
              if (row != rows.last) const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }

  List<(String, String, String)> _previewTimetableRows(
      List<List<String>>? grid) {
    if (grid == null || grid.isEmpty) return const [];
    final rows = <(String, String, String)>[];
    for (final row in grid.skip(1)) {
      final cells = row
          .map((cell) => cell.trim())
          .where((cell) => cell.isNotEmpty)
          .toList();
      if (cells.length < 2) continue;
      rows.add((
        cells.first,
        cells.length > 1 ? cells[1] : 'Class',
        cells.skip(2).take(2).join(' - ')
      ));
      if (rows.length == 4) break;
    }
    return rows;
  }
}

class _TimetableListRow extends StatelessWidget {
  const _TimetableListRow({
    required this.time,
    required this.title,
    required this.detail,
  });

  final String time;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: dark
            ? Colors.white.withValues(alpha: 0.04)
            : const Color(0xFFF3F5FF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: dark
                  ? Colors.white.withValues(alpha: 0.06)
                  : const Color(0xFFE8EBFA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              time,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: OSColors.text(dark),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: OSColors.text(dark),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  detail.isEmpty ? 'Planning block' : detail,
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
          Icon(Icons.link_rounded, size: 18, color: OSColors.blue),
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
    this.padding = const EdgeInsets.all(20),
    this.tint,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: dark
            ? const Color(0xFF111827).withValues(alpha: 0.88)
            : (tint ?? Colors.white)
                .withValues(alpha: tint == null ? 0.92 : 0.76),
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
  });

  final String text;
  final DateTime timestamp;
  bool done;
  final List<String> classIds;

  bool get isSchoolWide => classIds.isEmpty;
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
  });

  final String id;
  final String name;
  final String base64;
  final String? mimeType;
  final DateTime uploadedAt;
  final List<List<String>>? grid;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'base64': base64,
        'mimeType': mimeType,
        'grid': grid,
        'uploadedAt': uploadedAt.toIso8601String(),
      };

  factory _PlannerTimetable.fromJson(Map<String, dynamic> json) {
    return _PlannerTimetable(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      base64: (json['base64'] ?? '').toString(),
      mimeType: json['mimeType']?.toString(),
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
    final hasItems = reminders.any(
        (reminder) => _isSameDate(reminder.timestamp, date) && !reminder.done);
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

    final items = reminders
        .where((reminder) => _isSameDate(reminder.timestamp, selected))
        .toList()
      ..sort((left, right) => left.timestamp.compareTo(right.timestamp));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
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
              icon: const Icon(Icons.close_rounded),
              label: const Text('Clear'),
              style: WorkspaceButtonStyles.text(context),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: reminderController,
                decoration: const InputDecoration(
                  labelText: 'Add a reminder',
                  hintText: 'Meeting, deadline, school event...',
                ),
                onSubmitted: (_) => onAddReminder(),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: onAddReminder,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add'),
              style: WorkspaceButtonStyles.filled(context),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (items.isEmpty)
          Text(
            'No items for this day.',
            style: WorkspaceTypography.metadata(context),
          )
        else
          for (final reminder in items)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Checkbox(
                value: reminder.done,
                onChanged: (value) =>
                    onToggleReminder(reminder, value ?? false),
              ),
              title: Text(
                reminder.text,
                overflow: TextOverflow.ellipsis,
                style: reminder.done
                    ? context.textStyles.bodyMedium?.copyWith(
                        decoration: TextDecoration.lineThrough,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      )
                    : context.textStyles.bodyMedium,
              ),
              trailing: IconButton(
                tooltip: 'Delete reminder',
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: () => onDeleteReminder(reminder),
              ),
            ),
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

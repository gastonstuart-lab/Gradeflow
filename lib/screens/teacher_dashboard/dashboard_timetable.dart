// ignore_for_file: invalid_use_of_protected_member, library_private_types_in_public_api

part of '../teacher_dashboard_screen.dart';

extension TeacherDashboardTimetableActions on _TeacherDashboardScreenState {
  Future<void> _openTimetableDialog() async {
    // If user has a selected timetable, open it directly
    if (_selectedTimetableId != null) {
      final timetable = _timetables.firstWhere(
        (t) => t.id == _selectedTimetableId,
        orElse: () => _timetables.first,
      );
      if (timetable.grid != null && timetable.grid!.isNotEmpty) {
        await _openTimetableViewer(timetable);
        return;
      }
    }

    // Otherwise show management/upload dialog
    await _showTimetableManagementDialog();
  }

  Future<void> _showTimetableManagementDialog() async {
    final theme = Theme.of(context);
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) {
          final currentSelectedId = _selectedTimetableId;
          Future<void> saveTimetableFromBytes(
              Uint8List bytes, String name, String? mimeType) async {
            final id = DateTime.now().microsecondsSinceEpoch.toString();
            List<List<String>>? grid;
            final ext = (mimeType ?? '').toLowerCase();
            if (ext == 'docx') {
              try {
                final rawGrid =
                    FileImportService().extractDocxBestTableGrid(bytes);
                grid = FileImportService().cleanTimetableGrid(rawGrid);
              } catch (e) {
                if (context.mounted) {
                  _showDashboardFeedback(
                    'Could not parse the DOCX timetable: $e',
                    tone: WorkspaceFeedbackTone.error,
                  );
                }
              }
            } else if (ext == 'xlsx' || ext == 'csv') {
              try {
                final rows = FileImportService().rowsFromAnyBytes(bytes);
                if (rows.isNotEmpty) {
                  grid = FileImportService().cleanTimetableGrid(rows);
                }
              } catch (e) {
                if (context.mounted) {
                  _showDashboardFeedback(
                    'Could not parse the timetable table: $e',
                    tone: WorkspaceFeedbackTone.error,
                  );
                }
              }
            }

            final timetable = _Timetable(
              id: id,
              name: name,
              base64: base64Encode(bytes),
              mimeType: mimeType,
              uploadedAt: DateTime.now(),
              grid: grid,
            );

            if (!mounted) return;
            setState(() {
              _timetables.add(timetable);
              _selectedTimetableId = id;
            });
            await _saveTimetables();
            if (!mounted) return;
            setLocalState(() {});
            if (context.mounted) {
              _showDashboardFeedback(
                'Timetable "$name" uploaded.',
                tone: WorkspaceFeedbackTone.success,
                title: 'Timetable ready',
              );
            }
          }

          return AlertDialog(
            title: const Text('Timetable Management'),
            content: SizedBox(
              width: 560,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Upload section - always visible
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer
                          .withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.upload_file,
                                color: theme.colorScheme.primary, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Upload New Timetable',
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Upload from local file or Google Drive',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton.icon(
                              icon: const Icon(Icons.add),
                              label: const Text('Choose File'),
                              onPressed: () async {
                                final picked =
                                    await FilePicker.platform.pickFiles(
                                  withData: true,
                                  type: FileType.custom,
                                  allowedExtensions: [
                                    'xlsx',
                                    'csv',
                                    'pdf',
                                    'png',
                                    'jpg',
                                    'jpeg',
                                    'docx'
                                  ],
                                );
                                if (picked == null ||
                                    picked.files.single.bytes == null) {
                                  return;
                                }
                                final bytes = picked.files.single.bytes!;
                                final name = picked.files.single.name;
                                final mimeType = picked.files.single.extension;
                                await saveTimetableFromBytes(
                                    bytes, name, mimeType);
                              },
                            ),
                            OutlinedButton.icon(
                              icon: const Icon(
                                  Icons.drive_folder_upload_outlined),
                              label: const Text('Google Drive'),
                              onPressed: () async {
                                try {
                                  if (!await _ensureDriveReady()) return;
                                  final drive =
                                      context.read<GoogleDriveService>();
                                  final picked = await showDialog<DriveFile>(
                                    context: context,
                                    builder: (ctx) => DriveFilePickerDialog(
                                      driveService: drive,
                                      allowedExtensions: const [
                                        'xlsx',
                                        'csv',
                                        'docx'
                                      ],
                                      title:
                                          'Import timetable from Google Drive',
                                    ),
                                  );
                                  if (picked == null) return;
                                  final bytes =
                                      await drive.downloadFileBytesFor(
                                    picked,
                                    preferredExportMimeType:
                                        GoogleDriveService.exportXlsxMimeType,
                                  );
                                  final ext = picked.name.contains('.')
                                      ? picked.name.split('.').last
                                      : null;
                                  await saveTimetableFromBytes(
                                      bytes, picked.name, ext);
                                } catch (e) {
                                  if (!context.mounted) return;
                                  _showDashboardFeedback(
                                    'Drive timetable import failed: $e',
                                    tone: WorkspaceFeedbackTone.error,
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (_timetables.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 12),
                    Text(
                      'My Timetables',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _timetables.length,
                        itemBuilder: (context, index) {
                          final t = _timetables[index];
                          final isSelected = t.id == currentSelectedId;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? theme.colorScheme.primaryContainer
                                      .withValues(alpha: 0.4)
                                  : theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected
                                    ? theme.colorScheme.primary
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              leading: Icon(
                                isSelected
                                    ? Icons.check_circle
                                    : Icons.table_chart_outlined,
                                color: isSelected
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                              title: Text(
                                t.name,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                              subtitle: Text(
                                'Uploaded ${_formatDate(t.uploadedAt)}${t.mimeType == null ? '' : ' • ${t.mimeType}'}',
                                style: theme.textTheme.bodySmall,
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (t.grid != null)
                                    IconButton(
                                      icon: const Icon(Icons.visibility),
                                      tooltip: 'View/Edit',
                                      onPressed: () async {
                                        Navigator.pop(ctx);
                                        await _openTimetableViewer(t);
                                      },
                                    ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    tooltip: 'Delete',
                                    onPressed: () async {
                                      final confirm = await showDialog<bool>(
                                        context: ctx,
                                        builder: (ctx2) => AlertDialog(
                                          title: const Text('Delete Timetable'),
                                          content: Text(
                                              'Are you sure you want to delete "${t.name}"?'),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx2, false),
                                              child: const Text('Cancel'),
                                            ),
                                            FilledButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx2, true),
                                              child: const Text('Delete'),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirm == true) {
                                        setState(() {
                                          _timetables.removeAt(index);
                                          if (_selectedTimetableId == t.id) {
                                            _selectedTimetableId = null;
                                          }
                                        });
                                        await _saveTimetables();
                                        setLocalState(() {});
                                      }
                                    },
                                  ),
                                ],
                              ),
                              onTap: () {
                                setState(() => _selectedTimetableId = t.id);
                                unawaited(_saveTimetables());
                                setLocalState(() {});
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }

  List<TimeSlotClass> _parseGridToTimeSlots(List<List<String>> grid) {
    final slots = <TimeSlotClass>[];
    if (grid.isEmpty) return slots;

    final dayMap = {
      'mon': 0,
      'monday': 0,
      'm': 0,
      'tue': 1,
      'tuesday': 1,
      'tu': 1,
      'wed': 2,
      'wednesday': 2,
      'w': 2,
      'thu': 3,
      'thursday': 3,
      'th': 3,
      'fri': 4,
      'friday': 4,
      'f': 4,
      '\u4e00': 0,
      '\u661f\u671f\u4e00': 0,
      '\u9031\u4e00': 0,
      '\u4e8c': 1,
      '\u661f\u671f\u4e8c': 1,
      '\u9031\u4e8c': 1,
      '\u4e09': 2,
      '\u661f\u671f\u4e09': 2,
      '\u9031\u4e09': 2,
      '\u56db': 3,
      '\u661f\u671f\u56db': 3,
      '\u9031\u56db': 3,
      '\u4e94': 4,
      '\u661f\u671f\u4e94': 4,
      '\u9031\u4e94': 4,
    };

    String normalizeCell(String value) =>
        value.toLowerCase().replaceAll('\u00a0', ' ').trim();

    ({int? start, int? end}) parseTimeRange(String value) {
      final match = RegExp(
        r'(\d{1,2})\s*:\s*(\d{2})(?:\s*(?:-|~)\s*(\d{1,2})\s*:\s*(\d{2}))?',
      ).firstMatch(value.replaceAll('\u00a0', ' ').trim());
      if (match == null) {
        return (start: null, end: null);
      }

      final startH = int.tryParse(match.group(1) ?? '');
      final startM = int.tryParse(match.group(2) ?? '');
      if (startH == null || startM == null) {
        return (start: null, end: null);
      }

      final start = startH * 60 + startM;
      final endH = int.tryParse(match.group(3) ?? '');
      final endM = int.tryParse(match.group(4) ?? '');
      final end = endH != null && endM != null ? (endH * 60 + endM) : null;
      return (start: start, end: end);
    }

    Map<int, int> headerDays = {};
    int headerRowIndex = -1;
    final headerScanLimit = grid.length < 4 ? grid.length : 4;
    for (int r = 0; r < headerScanLimit; r++) {
      final row = grid[r];
      final rowDays = <int, int>{};
      for (int c = 0; c < row.length; c++) {
        final norm = normalizeCell(row[c]);
        final day = dayMap[norm];
        if (day != null) {
          rowDays[c] = day;
        }
      }
      if (rowDays.length >= 3) {
        headerDays = rowDays;
        headerRowIndex = r;
        break;
      }
    }

    if (headerDays.isEmpty || headerRowIndex == -1) return slots;

    bool rowHasClassData(List<String> row) {
      for (final col in headerDays.keys) {
        if (col < row.length && row[col].trim().isNotEmpty) {
          return true;
        }
      }
      return false;
    }

    final maxCols = grid.fold<int>(
      0,
      (max, row) => row.length > max ? row.length : max,
    );
    int timeColumn = 0;
    int timeMatchCount = -1;
    for (int c = 0; c < maxCols; c++) {
      if (headerDays.containsKey(c)) continue;
      int matches = 0;
      for (int r = headerRowIndex + 1; r < grid.length; r++) {
        if (c >= grid[r].length) continue;
        if (parseTimeRange(grid[r][c]).start != null) {
          matches++;
        }
      }
      if (matches > timeMatchCount) {
        timeMatchCount = matches;
        timeColumn = c;
      }
    }

    int inferEndMinutes(int rowIndex, int startMinutes) {
      for (int r = rowIndex + 1; r < grid.length; r++) {
        final row = grid[r];
        if (timeColumn >= row.length) {
          if (rowHasClassData(row)) break;
          continue;
        }

        final candidate = parseTimeRange(row[timeColumn]).start;
        if (candidate != null && candidate > startMinutes) {
          return candidate;
        }
      }
      return startMinutes + 50;
    }

    for (int r = headerRowIndex + 1; r < grid.length; r++) {
      final row = grid[r];
      if (row.isEmpty || !rowHasClassData(row)) continue;
      if (timeColumn >= row.length) continue;

      final timeRange = parseTimeRange(row[timeColumn]);
      final startMin = timeRange.start;
      if (startMin == null) continue;
      final inferredEnd = timeRange.end ?? inferEndMinutes(r, startMin);
      final endMin = inferredEnd > startMin ? inferredEnd : startMin + 50;

      for (final entry in headerDays.entries) {
        final c = entry.key;
        if (c >= row.length) continue;
        final className = row[c].trim();
        if (className.isEmpty) continue;
        slots.add(TimeSlotClass(
          title: className,
          dayOfWeek: entry.value,
          startMinutes: startMin,
          endMinutes: endMin,
        ));
      }
    }

    return slots;
  }

  Future<void> _openTimetableViewer(_Timetable timetable) async {
    final initialGrid = timetable.grid;
    if (initialGrid == null || initialGrid.isEmpty) {
      if (!mounted) return;
      _showDashboardFeedback(
        'This timetable has no readable table grid yet.',
        tone: WorkspaceFeedbackTone.warning,
      );
      return;
    }

    // Build controllers for editing.
    final controllers = <List<TextEditingController>>[];
    for (final row in initialGrid) {
      controllers
          .add(row.map((cell) => TextEditingController(text: cell)).toList());
    }

    // Parse grid to time slots for visual display
    final timeSlots = _parseGridToTimeSlots(initialGrid);
    bool showVisual = timeSlots.isNotEmpty;

    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        child: Container(
          width: MediaQuery.of(ctx).size.width * 0.9,
          height: MediaQuery.of(ctx).size.height * 0.85,
          constraints: const BoxConstraints(maxWidth: 1200),
          child: StatefulBuilder(
            builder: (ctx, setLocalState) {
              final rows = controllers.length;
              final cols = controllers.isEmpty
                  ? 0
                  : controllers
                      .map((r) => r.length)
                      .reduce((a, b) => a > b ? a : b);

              Widget cellField(int r, int c) {
                // Bounds check to prevent IndexError
                if (r >= controllers.length || c >= controllers[r].length) {
                  return const SizedBox.shrink();
                }
                final isHeader = r == 0;
                final isFirstCol = c == 0;
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isHeader
                        ? Theme.of(ctx)
                            .colorScheme
                            .primaryContainer
                            .withValues(alpha: 0.6)
                        : isFirstCol
                            ? Theme.of(ctx).colorScheme.surfaceContainerHighest
                            : null,
                    border: Border(
                      right: BorderSide(
                        color: Theme.of(ctx)
                            .colorScheme
                            .outlineVariant
                            .withValues(alpha: 0.5),
                        width: 1,
                      ),
                      bottom: BorderSide(
                        color: Theme.of(ctx)
                            .colorScheme
                            .outlineVariant
                            .withValues(alpha: 0.5),
                        width: 1,
                      ),
                    ),
                  ),
                  child: TextField(
                    controller: controllers[r][c],
                    maxLines: isFirstCol ? 1 : 3,
                    minLines: 1,
                    textAlign: isHeader || isFirstCol
                        ? TextAlign.center
                        : TextAlign.center,
                    style: isHeader
                        ? Theme.of(ctx).textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color:
                                  Theme.of(ctx).colorScheme.onPrimaryContainer,
                              fontSize: 13,
                            )
                        : isFirstCol
                            ? Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                )
                            : Theme.of(ctx).textTheme.bodySmall?.copyWith(
                                  fontSize: 11,
                                  height: 1.3,
                                ),
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: isHeader
                          ? 'Day'
                          : isFirstCol
                              ? 'Time'
                              : 'Class',
                      hintStyle: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                            color: Theme.of(ctx)
                                .colorScheme
                                .onSurfaceVariant
                                .withValues(alpha: 0.3),
                            fontSize: 10,
                          ),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                );
              }

              return Column(
                children: [
                  // Header with toggle
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                      border: Border(
                        bottom: BorderSide(
                          color: Theme.of(ctx).colorScheme.outlineVariant,
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          showVisual ? Icons.grid_on : Icons.table_chart,
                          color: Theme.of(ctx).colorScheme.primary,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                timetable.name,
                                style: Theme.of(ctx)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                showVisual
                                    ? 'Visual timetable preview'
                                    : 'Edit cells to update your timetable',
                                style:
                                    Theme.of(ctx).textTheme.bodySmall?.copyWith(
                                          color: Theme.of(ctx)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                              ),
                            ],
                          ),
                        ),
                        if (timeSlots.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: SegmentedButton<bool>(
                              segments: const [
                                ButtonSegment(
                                    label: Text('Visual'), value: true),
                                ButtonSegment(
                                    label: Text('Edit'), value: false),
                              ],
                              selected: {showVisual},
                              onSelectionChanged: (newSelection) {
                                setLocalState(() {
                                  showVisual = newSelection.first;
                                });
                              },
                            ),
                          ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                          tooltip: 'Close',
                        ),
                      ],
                    ),
                  ),
                  // Content area
                  Expanded(
                    child: showVisual
                        ? SingleChildScrollView(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: SizedBox(
                                height: 500,
                                child: TimeSlotTimetable(
                                  classes: timeSlots,
                                  weekStart: DateTime.now(),
                                ),
                              ),
                            ),
                          )
                        : Container(
                            color: Theme.of(ctx).colorScheme.surface,
                            padding: const EdgeInsets.all(20),
                            child: Card(
                              elevation: 2,
                              clipBehavior: Clip.antiAlias,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minWidth:
                                        MediaQuery.of(ctx).size.width * 0.8,
                                  ),
                                  child: SingleChildScrollView(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        // Header row with day names
                                        if (cols > 1)
                                          IntrinsicHeight(
                                            child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.stretch,
                                              children: [
                                                for (var c = 0; c < cols; c++)
                                                  SizedBox(
                                                    width: c == 0 ? 100 : 180,
                                                    child: Container(
                                                      decoration: BoxDecoration(
                                                        color: Theme.of(ctx)
                                                            .colorScheme
                                                            .surfaceContainerHighest,
                                                        border: Border.all(
                                                          color: Theme.of(ctx)
                                                              .colorScheme
                                                              .outlineVariant,
                                                        ),
                                                      ),
                                                      padding:
                                                          const EdgeInsets.all(
                                                              8),
                                                      child: Center(
                                                        child: Text(
                                                          c == 0
                                                              ? 'Time'
                                                              : _getDayName(
                                                                  c - 1),
                                                          style: Theme.of(ctx)
                                                              .textTheme
                                                              .labelSmall
                                                              ?.copyWith(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        for (var r = 0; r < rows; r++)
                                          IntrinsicHeight(
                                            child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.stretch,
                                              children: [
                                                for (var c = 0; c < cols; c++)
                                                  SizedBox(
                                                    width: c == 0 ? 100 : 180,
                                                    child: cellField(r, c),
                                                  ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                  ),
                  // Actions
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                      border: Border(
                        top: BorderSide(
                          color: Theme.of(ctx).colorScheme.outlineVariant,
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 16,
                              color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${controllers.length} rows × ${controllers.isEmpty ? 0 : controllers.map((r) => r.length).reduce((a, b) => a > b ? a : b)} columns',
                              style:
                                  Theme.of(ctx).textTheme.bodySmall?.copyWith(
                                        color: Theme.of(ctx)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                            ),
                          ],
                        ),
                        Wrap(
                          spacing: 6,
                          alignment: WrapAlignment.end,
                          children: [
                            OutlinedButton.icon(
                              icon: const Icon(Icons.settings, size: 18),
                              label: const Text('Manage'),
                              onPressed: () async {
                                Navigator.pop(ctx);
                                await _showTimetableManagementDialog();
                              },
                            ),
                            TextButton.icon(
                              icon: const Icon(Icons.close, size: 18),
                              label: const Text('Cancel'),
                              onPressed: () => Navigator.pop(ctx),
                            ),
                            FilledButton.icon(
                              icon: const Icon(Icons.save, size: 18),
                              label: const Text('Save'),
                              onPressed: () async {
                                final newGrid = <List<String>>[];
                                for (final rowCtrls in controllers) {
                                  newGrid.add(
                                      rowCtrls.map((c) => c.text).toList());
                                }
                                if (!mounted) return;
                                setState(() {
                                  final idx = _timetables
                                      .indexWhere((t) => t.id == timetable.id);
                                  if (idx != -1) {
                                    _timetables[idx] = _Timetable(
                                      id: _timetables[idx].id,
                                      name: _timetables[idx].name,
                                      base64: _timetables[idx].base64,
                                      mimeType: _timetables[idx].mimeType,
                                      uploadedAt: _timetables[idx].uploadedAt,
                                      grid: newGrid,
                                    );
                                  }
                                });
                                await _saveTimetables();
                                if (ctx.mounted) Navigator.pop(ctx);
                                if (context.mounted) {
                                  _showDashboardFeedback(
                                    'Timetable saved successfully.',
                                    tone: WorkspaceFeedbackTone.success,
                                    title: 'Saved',
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );

    for (final rowCtrls in controllers) {
      for (final c in rowCtrls) {
        c.dispose();
      }
    }
  }

  String _weekdayLabel(DateTime d) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[(d.weekday + 6) % 7];
  }

  String _getDayName(int columnIndex) {
    const names = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    if (columnIndex >= 0 && columnIndex < names.length) {
      return names[columnIndex];
    }
    return 'Day ${columnIndex + 1}';
  }

  bool _isSameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
  String _monthYearLabel(DateTime d) => '${_monthName(d.month)} ${d.year}';
  String _monthName(int m) {
    const names = [
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
      'December'
    ];
    return names[m - 1];
  }

  String _formatDate(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';
  String _formatTime(DateTime d) =>
      '${_two(d.hour)}:${_two(d.minute)}:${_two(d.second)}';
  String _two(int v) => v.toString().padLeft(2, '0');
  String _shortMonthDay(DateTime d) =>
      '${_monthName(d.month).substring(0, 3)} ${d.day}';

  // Show HH:MM only when a specific time is set; hide when all-day (00:00)
  String _formatHourMinute(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';
  String _optionalTimeInline(DateTime d) =>
      (d.hour == 0 && d.minute == 0 && d.second == 0)
          ? ''
          : '  ${_formatHourMinute(d)}';
}

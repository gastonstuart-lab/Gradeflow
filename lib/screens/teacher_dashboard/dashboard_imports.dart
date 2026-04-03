// ignore_for_file: invalid_use_of_protected_member, library_private_types_in_public_api

part of '../teacher_dashboard_screen.dart';

extension TeacherDashboardImportActions on _TeacherDashboardScreenState {
  Future<bool> _ensureDriveReady() async {
    final result = await context
        .read<GoogleAuthService>()
        .ensureAccessTokenDetailed(interactive: true);
    if (!mounted) return result.ok;
    if (!result.ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.userMessage())),
      );
      return false;
    }
    return true;
  }

  Future<void> _loadClassSchedule(String classId) async {
    if (_scheduleByClass.containsKey(classId)) return;
    try {
      final items = await _classScheduleService.load(classId);
      if (!mounted) return;
      setState(() => _scheduleByClass[classId] = items);
    } catch (e) {
      debugPrint('Failed to load schedule for class=$classId: $e');
    }
  }

  Future<void> _saveClassSchedule(
      String classId, List<ClassScheduleItem> items) async {
    await _classScheduleService.save(classId, items);
    if (!mounted) return;
    setState(() => _scheduleByClass[classId] = items);
  }

  Future<void> _importClassSchedule() async {
    if (_selectedClassId == null) return;
    if (_scheduleBusy) return;

    setState(() => _scheduleBusy = true);
    try {
      final picked = await FilePicker.platform.pickFiles(
        withData: true,
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'csv'],
      );
      if (picked == null || picked.files.single.bytes == null || !mounted) {
        setState(() => _scheduleBusy = false);
        return;
      }

      final bytes = picked.files.single.bytes!;
      final filename = picked.files.single.name;
      await _importClassScheduleFromBytes(bytes, filename);
    } catch (e) {
      debugPrint('Import class schedule failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to import class schedule')));
      }
    } finally {
      if (mounted) setState(() => _scheduleBusy = false);
    }
  }

  Future<void> _importClassScheduleFromDrive() async {
    if (_selectedClassId == null) return;
    if (_scheduleBusy) return;

    setState(() => _scheduleBusy = true);
    try {
      if (!await _ensureDriveReady()) return;
      final drive = context.read<GoogleDriveService>();
      final picked = await showDialog<DriveFile>(
        context: context,
        builder: (ctx) => DriveFilePickerDialog(
          driveService: drive,
          allowedExtensions: const ['xlsx', 'csv', 'docx'],
          title: 'Import class schedule from Google Drive',
        ),
      );
      if (picked == null) return;

      final bytes = await drive.downloadFileBytesFor(
        picked,
        preferredExportMimeType: GoogleDriveService.exportXlsxMimeType,
      );
      await _importClassScheduleFromBytes(bytes, picked.name);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Drive schedule import failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _scheduleBusy = false);
    }
  }

  Future<void> _importClassScheduleFromBytes(
      Uint8List bytes, String filename) async {
    if (!await _enforceImportType(
      bytes: bytes,
      filename: filename,
      allowed: {ImportFileType.calendar},
      destinationLabel: 'Class schedule',
    )) {
      return;
    }

    var items = _classScheduleService.parseFromBytes(bytes);
    if (items.isEmpty && OpenAIConfig.isConfigured) {
      final aiOutput = await AiImportService()
          .analyzeScheduleFromBytes(bytes, filename: filename);
      if (aiOutput != null && aiOutput.items.isNotEmpty) {
        items = aiOutput.items;
      }
    }

    if (items.isEmpty) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('No schedule detected'),
          content: Text(
            'Could not detect schedule items in "$filename". Try CSV/XLSX export with clear Date/Title or Week/Topic columns.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            )
          ],
        ),
      );
      return;
    }

    final dateItems = items.where((i) => i.date != null).toList();
    DateTime? start;
    DateTime? end;
    if (dateItems.isNotEmpty) {
      start =
          dateItems.map((e) => e.date!).reduce((a, b) => a.isBefore(b) ? a : b);
      end =
          dateItems.map((e) => e.date!).reduce((a, b) => a.isAfter(b) ? a : b);
    }

    if (!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import class schedule'),
        content: SizedBox(
          width: 560,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('File: $filename',
                  style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Items found: ${items.length}',
                        style: Theme.of(context).textTheme.bodySmall),
                    if (start != null && end != null)
                      Text(
                        'Date range: ${_formatDate(start)} -> ${_formatDate(end)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text('Preview (first 6):',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 6),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: items.take(6).map((i) {
                      final when = i.date != null
                          ? _formatDate(i.date!)
                          : (i.week != null ? 'Week ${i.week}' : '');
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(i.title,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: i.details.isEmpty
                            ? null
                            : Text(
                                i.details.values.take(2).join(' • '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                        leading: when.isEmpty
                            ? null
                            : Text(when,
                                style: Theme.of(context).textTheme.labelMedium),
                      );
                    }).toList(),
                  ),
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
            child: const Text('Import'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await _saveClassSchedule(_selectedClassId!, items);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved schedule (${items.length} items)')),
        );
      }
    }
  }
}

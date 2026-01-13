import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:gradeflow/services/google_drive_service.dart';
import 'package:gradeflow/theme.dart';

class DriveFilePickerDialog extends StatefulWidget {
  const DriveFilePickerDialog({
    super.key,
    required this.driveService,
    required this.allowedExtensions,
    this.title = 'Browse Google Drive',
  });

  final GoogleDriveService driveService;
  final List<String> allowedExtensions;
  final String title;

  @override
  State<DriveFilePickerDialog> createState() => _DriveFilePickerDialogState();
}

class _DriveFilePickerDialogState extends State<DriveFilePickerDialog> {
  bool _loading = true;
  String? _error;
  List<DriveFile> _files = const [];

  final List<_DriveFolder> _stack = [_DriveFolder(id: 'root', name: 'My Drive')];

  @override
  void initState() {
    super.initState();
    _load();
  }

  bool _matchesExtension(String name) {
    final lower = name.toLowerCase();
    for (final ext in widget.allowedExtensions) {
      final e = ext.toLowerCase();
      if (lower.endsWith('.$e')) return true;
    }
    return false;
  }

  bool _isGoogleSheet(DriveFile f) =>
      f.mimeType == GoogleDriveService.googleSheetMimeType;

  bool _isFolder(DriveFile f) => f.mimeType == GoogleDriveService.folderMimeType;

  _DriveFolder get _currentFolder => _stack.last;

  bool get _canGoUp => _stack.length > 1;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final files = await widget.driveService
          .listFolder(folderId: _currentFolder.id, interactiveAuth: false);
      final filtered = files.where((f) {
        if (_isFolder(f)) return true;
        return _matchesExtension(f.name) || _isGoogleSheet(f);
      }).toList();
      setState(() {
        _files = filtered;
      });
    } catch (e) {
      setState(() {
        _error = '$e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _signInAndReload() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Trigger interactive sign-in from a user gesture.
      await widget.driveService.listRecentFiles(pageSize: 1, interactiveAuth: true);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
    await _load();
  }

  void _openFolder(DriveFile folder) {
    _stack.add(_DriveFolder(id: folder.id, name: folder.name));
    _load();
  }

  void _goUp() {
    if (!_canGoUp) return;
    _stack.removeLast();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('yyyy-MM-dd HH:mm');

    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 560,
        height: 420,
        child: Column(
          children: [
            Row(children: [
              IconButton(
                tooltip: 'Up',
                onPressed: _loading || !_canGoUp ? null : _goUp,
                icon: const Icon(Icons.arrow_upward),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _currentFolder.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textStyles.titleSmall?.semiBold,
                ),
              ),
            ]),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _error!.contains('not_signed_in')
                                  ? 'Sign in to browse Google Drive.'
                                  : 'Failed to load Drive files.',
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.error),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Expanded(
                                child: SingleChildScrollView(
                                    child: SelectableText(_error!))),
                            const SizedBox(height: AppSpacing.sm),
                            Row(children: [
                              FilledButton.icon(
                                onPressed: _signInAndReload,
                                icon: const Icon(Icons.login),
                                label: const Text('Sign in'),
                              ),
                            ]),
                          ],
                        )
                      : _files.isEmpty
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('No matching files found.',
                                    style: context.textStyles.titleSmall),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  'Looking for: ${widget.allowedExtensions.map((e) => '.$e').join(', ')}',
                                  style: context.textStyles.bodySmall,
                                ),
                                const SizedBox(height: AppSpacing.md),
                                const Expanded(
                                  child: Center(
                                    child: Text(
                                        'Try uploading a CSV/XLSX to Drive, then Refresh.'),
                                  ),
                                ),
                              ],
                            )
                          : ListView.separated(
                              itemCount: _files.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (ctx, i) {
                                final f = _files[i];
                                final subtitleParts = <String>[];
                                if (_isFolder(f)) {
                                  subtitleParts.add('Folder');
                                } else if (_isGoogleSheet(f)) {
                                  subtitleParts.add('Google Sheet');
                                }
                                if (f.modifiedTime != null) {
                                  subtitleParts.add(
                                      'Modified ${df.format(f.modifiedTime!.toLocal())}');
                                }
                                if (!_isFolder(f) && f.size != null) {
                                  subtitleParts.add('${f.size} bytes');
                                }

                                return ListTile(
                                  leading: Icon(_isFolder(f)
                                      ? Icons.folder_outlined
                                      : _isGoogleSheet(f)
                                          ? Icons.grid_on_outlined
                                          : Icons.insert_drive_file_outlined),
                                  title: Text(f.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                  subtitle: subtitleParts.isEmpty
                                      ? null
                                      : Text(subtitleParts.join(' • '),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis),
                                  onTap: () {
                                    if (_isFolder(f)) {
                                      _openFolder(f);
                                      return;
                                    }
                                    Navigator.pop(ctx, f);
                                  },
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : _load,
          child: const Text('Refresh'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _DriveFolder {
  final String id;
  final String name;
  const _DriveFolder({required this.id, required this.name});
}

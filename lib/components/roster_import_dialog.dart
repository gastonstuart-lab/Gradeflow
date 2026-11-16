import 'package:flutter/material.dart';
import 'package:gradeflow/services/file_import_service.dart';

/// Shared by file and pasted rosters; a completed write is the only success.
class RosterImportDialog extends StatefulWidget {
  const RosterImportDialog({super.key, required this.rows, required this.onImport});

  final List<ImportedStudent> rows;
  final Future<void> Function(List<ImportedStudent>) onImport;

  @override
  State<RosterImportDialog> createState() => _RosterImportDialogState();
}

class _RosterImportDialogState extends State<RosterImportDialog> {
  bool _saving = false;
  String? _error;

  Future<void> _save(List<ImportedStudent> valid) async {
    if (_saving || valid.isEmpty) return;
    setState(() { _saving = true; _error = null; });
    try {
      await widget.onImport(valid);
      if (mounted && ModalRoute.of(context)?.isCurrent == true) {
        Navigator.of(context).pop(valid.length);
      }
    } catch (error) {
      if (mounted) setState(() {
        _saving = false;
        _error = 'Import was not completed. $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final valid = widget.rows.where((s) => s.isValid).toList();
    final invalid = widget.rows.where((s) => !s.isValid).toList();
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        key: const ValueKey('roster-import-preview'),
        title: const Text('Import Preview'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Valid students: ${valid.length}'),
                if (invalid.isNotEmpty) Text('Invalid students: ${invalid.length}'),
                const SizedBox(height: 12),
                const Text('Adds students to this class. Existing students are not replaced. Duplicate IDs must be removed before importing.'),
                if (valid.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('Sample (first 3):'),
                  for (final student in valid.take(3)) Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('${student.studentId} · ${student.chineseName ?? ''} (${student.englishFirstName ?? ''} ${student.englishLastName ?? ''})'),
                  ),
                ],
                if (invalid.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('Rows that will not be imported:'),
                  for (final student in invalid.take(5)) Text('• ${student.error ?? 'Invalid row'}'),
                  if (invalid.length > 5) Text('… and ${invalid.length - 5} more invalid rows'),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Semantics(liveRegion: true, child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
                ],
                if (_saving) const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Text('Saving roster… Keep this window open.'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: _saving ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(
            key: const ValueKey('confirm-roster-import'),
            onPressed: _saving || valid.isEmpty ? null : () => _save(valid),
            child: Text(_saving ? 'Saving…' : 'Import ${valid.length} student${valid.length == 1 ? '' : 's'}'),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

/// Keep the teacher's form available until a class is durably saved.
class ClassCreationDialog extends StatefulWidget {
  const ClassCreationDialog(
      {super.key, required this.content, required this.onCreate});
  final Widget content;
  final Future<void> Function() onCreate;
  @override
  State<ClassCreationDialog> createState() => _ClassCreationDialogState();
}

class _ClassCreationDialogState extends State<ClassCreationDialog> {
  bool _saving = false;
  String? _error;
  Future<void> _create() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onCreate();
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted)
        setState(() {
          _saving = false;
          _error =
              'Class creation did not complete. Your entries are kept here. Check your connection and try again.';
        });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !_saving,
        child: AlertDialog(
          title: const Text('Create New Class'),
          content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
            AbsorbPointer(absorbing: _saving, child: widget.content),
            if (_error != null)
              Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Semantics(
                      liveRegion: true,
                      child: Text(_error!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)))),
            if (_saving)
              const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text('Saving class.')),
          ])),
          actions: [
            TextButton(
                onPressed:
                    _saving ? null : () => Navigator.of(context).pop(false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: _saving ? null : _create,
                child: Text(_saving ? 'Saving.' : 'Create')),
          ],
        ),
      );
}


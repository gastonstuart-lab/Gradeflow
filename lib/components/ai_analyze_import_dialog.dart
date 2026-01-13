import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AiAnalyzeImportDialog extends StatefulWidget {
  const AiAnalyzeImportDialog({
    super.key,
    required this.title,
    required this.filename,
    required this.analyze,
    this.confirmLabel = 'Use this',
    this.hint,
  });

  final String title;
  final String filename;
  final Future<Map<String, dynamic>> Function() analyze;
  final String confirmLabel;
  final String? hint;

  @override
  State<AiAnalyzeImportDialog> createState() => _AiAnalyzeImportDialogState();
}

class _AiAnalyzeImportDialogState extends State<AiAnalyzeImportDialog> {
  late final Future<Map<String, dynamic>> _future = widget.analyze();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 640,
        child: FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: 8),
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Analyzing with AI…'),
                ],
              );
            }

            if (snapshot.hasError) {
              return SingleChildScrollView(
                child: SelectableText(
                  'AI analysis failed.\n\nFile: ${widget.filename}\n\nError: ${snapshot.error}',
                ),
              );
            }

            final result = snapshot.data ?? const <String, dynamic>{};
            final pretty = const JsonEncoder.withIndent('  ').convert(result);

            return SingleChildScrollView(
              child: SelectableText(
                [
                  if (widget.hint != null && widget.hint!.trim().isNotEmpty)
                    widget.hint!.trim(),
                  'File: ${widget.filename}',
                  '',
                  pretty,
                ].join('\n'),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            try {
              final result = await _future;
              final pretty = const JsonEncoder.withIndent('  ').convert(result);
              await Clipboard.setData(ClipboardData(text: pretty));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('Copied')));
            } catch (_) {
              // If AI failed, do nothing.
            }
          },
          child: const Text('Copy'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            try {
              final result = await _future;
              if (!context.mounted) return;
              Navigator.pop(context, result);
            } catch (_) {
              // keep dialog open to show error
              setState(() {});
            }
          },
          child: Text(widget.confirmLabel),
        )
      ],
    );
  }
}

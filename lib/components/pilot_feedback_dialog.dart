import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gradeflow/config/gradeflow_product_config.dart';
import 'package:gradeflow/services/auth_service.dart';
import 'package:gradeflow/services/pilot_feedback_service.dart';
import 'package:provider/provider.dart';

const List<String> _pilotFeedbackCategories = [
  'Bug',
  'Confusing',
  'Slow / awkward',
  'Missing feature',
  'Positive note',
];

Future<void> showPilotFeedbackDialog(
  BuildContext context, {
  String initialArea = 'General',
  String initialRoute = '',
}) async {
  final service = context.read<PilotFeedbackService>();
  final auth = context.read<AuthService>();
  final summaryController = TextEditingController();
  final detailsController = TextEditingController();
  final areaController = TextEditingController(text: initialArea);
  var selectedCategory = _pilotFeedbackCategories.first;

  final submitted = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Pilot feedback'),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final category in _pilotFeedbackCategories)
                          DropdownMenuItem(
                            value: category,
                            child: Text(category),
                          ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() => selectedCategory = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: areaController,
                      decoration: const InputDecoration(
                        labelText: 'Area',
                        hintText: 'Seating, Gradebook, Classes, Export...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: summaryController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Short summary',
                        hintText: 'What felt wrong, unclear, or great?',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: detailsController,
                      minLines: 4,
                      maxLines: 7,
                      decoration: const InputDecoration(
                        labelText: 'Details',
                        hintText:
                            'What were you trying to do, what happened, and what did you expect instead?',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'When you submit, ${GradeFlowProductConfig.appName} saves the feedback and copies a ready-to-share report to your clipboard.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  if (summaryController.text.trim().isEmpty ||
                      detailsController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Add a short summary and a little detail first.',
                        ),
                      ),
                    );
                    return;
                  }
                  Navigator.of(dialogContext).pop(true);
                },
                child: const Text('Save feedback'),
              ),
            ],
          );
        },
      );
    },
  );

  if (submitted != true) return;

  final entry = await service.addEntry(
    category: selectedCategory,
    area: areaController.text,
    summary: summaryController.text,
    details: detailsController.text,
    route: initialRoute,
  );
  final report = service.buildReportText(
    entry,
    teacherName: auth.currentUser?.fullName,
  );
  await Clipboard.setData(ClipboardData(text: report));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Pilot feedback saved and copied to the clipboard.'),
    ),
  );
}

class PilotFeedbackIconButton extends StatelessWidget {
  final String initialArea;
  final String initialRoute;

  const PilotFeedbackIconButton({
    super.key,
    required this.initialArea,
    required this.initialRoute,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.rate_review_outlined),
      onPressed: () => showPilotFeedbackDialog(
        context,
        initialArea: initialArea,
        initialRoute: initialRoute,
      ),
    );
  }
}

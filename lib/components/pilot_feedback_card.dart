import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gradeflow/components/pilot_feedback_dialog.dart';
import 'package:gradeflow/services/auth_service.dart';
import 'package:gradeflow/services/pilot_feedback_service.dart';
import 'package:provider/provider.dart';

class PilotFeedbackCard extends StatelessWidget {
  final String initialArea;
  final String initialRoute;

  const PilotFeedbackCard({
    super.key,
    required this.initialArea,
    required this.initialRoute,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<PilotFeedbackService>(
      builder: (context, service, _) {
        if (service.guideDismissed) return const SizedBox.shrink();

        final latestEntry =
            service.entries.isEmpty ? null : service.entries.first;
        final teacherName = context.read<AuthService>().currentUser?.fullName;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.18),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.science_outlined,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Teacher pilot',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer,
                          ),
                    ),
                  ),
                  TextButton(
                    onPressed: service.dismissGuide,
                    child: const Text('Hide guide'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Try the app like you normally would, then capture what felt confusing, slow, missing, or especially good.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
              ),
              const SizedBox(height: 12),
              const _PilotGuideLine(
                text:
                    'Test real teacher flows: classes, gradebook, seating, and export.',
              ),
              const _PilotGuideLine(
                text:
                    'When something feels awkward, send one short note right away.',
              ),
              const _PilotGuideLine(
                text:
                    'GradeFlow copies a ready-to-share report for you automatically.',
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed: () => showPilotFeedbackDialog(
                      context,
                      initialArea: initialArea,
                      initialRoute: initialRoute,
                    ),
                    icon: const Icon(Icons.rate_review_outlined),
                    label: const Text('Send feedback'),
                  ),
                  OutlinedButton.icon(
                    onPressed: latestEntry == null
                        ? null
                        : () async {
                            final report = service.buildReportText(
                              latestEntry,
                              teacherName: teacherName,
                            );
                            await Clipboard.setData(
                                ClipboardData(text: report));
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Latest pilot report copied.'),
                              ),
                            );
                          },
                    icon: const Icon(Icons.content_copy_outlined),
                    label: Text(
                      latestEntry == null
                          ? 'No feedback yet'
                          : 'Copy latest report',
                    ),
                  ),
                ],
              ),
              if (service.entries.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  '${service.entries.length} feedback note${service.entries.length == 1 ? '' : 's'} saved for this pilot.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _PilotGuideLine extends StatelessWidget {
  final String text;

  const _PilotGuideLine({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Icon(
              Icons.check_circle_outline,
              size: 16,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

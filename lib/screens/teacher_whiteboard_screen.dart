import 'package:flutter/material.dart';
import 'package:gradeflow/components/animated_page_background.dart';
import 'package:gradeflow/components/teacher_whiteboard.dart';

class TeacherWhiteboardScreen extends StatelessWidget {
  final TeacherWhiteboardController? controller;

  const TeacherWhiteboardScreen({
    super.key,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: AnimatedPageBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    color: theme.colorScheme.surface.withValues(alpha: 0.74),
                    border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 0.36),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                color: theme.colorScheme.primary
                                    .withValues(alpha: 0.10),
                                border: Border.all(
                                  color: theme.colorScheme.primary
                                      .withValues(alpha: 0.18),
                                ),
                              ),
                              child: Text(
                                'Classroom Studio',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Quick Whiteboard',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'A focused annotation surface for explaining, sketching, and teaching live inside the studio shell.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: TeacherWhiteboardWorkspace(
                    controller: controller,
                    title: 'Teacher whiteboard',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

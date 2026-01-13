import 'package:flutter/material.dart';
import 'package:gradeflow/models/class.dart';
import 'package:gradeflow/theme.dart';
import 'package:gradeflow/components/animated_glow_border.dart';

class ClassCard extends StatelessWidget {
  final Class classItem;
  final VoidCallback onTap;

  const ClassCard({super.key, required this.classItem, required this.onTap});

  void _showSyllabusDialog(BuildContext context) {
    final s = classItem.syllabus;
    if (s == null || s.entries.isEmpty) return;
    showDialog<void>(
      context: context,
      builder: (ctx) {
        String? lastSection;
        return AlertDialog(
          title: Text('${classItem.className} • Schedule'),
          content: SizedBox(
            width: 720,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (s.sourceFilename != null && s.sourceFilename!.isNotEmpty)
                    Text('Source: ${s.sourceFilename!}',
                        style: Theme.of(ctx).textTheme.bodySmall),
                  if (s.headerLines.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color:
                            Theme.of(ctx).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SelectableText(
                        s.headerLines.join('\n'),
                        style: Theme.of(ctx)
                            .textTheme
                            .bodySmall
                            ?.copyWith(fontFamily: 'monospace'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  ...s.entries.map((e) {
                    final widgets = <Widget>[];
                    if (e.section != null &&
                        e.section!.trim().isNotEmpty &&
                        e.section != lastSection) {
                      lastSection = e.section;
                      widgets.addAll([
                        const SizedBox(height: 10),
                        Text(e.section!,
                            style: Theme.of(ctx).textTheme.titleSmall),
                        const SizedBox(height: 6),
                      ]);
                    }
                    widgets.add(Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: Theme.of(ctx)
                                .colorScheme
                                .outlineVariant),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Week ${e.week}${e.dateRange.isEmpty ? '' : ' • ${e.dateRange}'}',
                            style: Theme.of(ctx).textTheme.titleSmall,
                          ),
                          if (e.lessonContent.trim().isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(e.lessonContent,
                                style: Theme.of(ctx).textTheme.bodyMedium),
                          ],
                          if ((e.dateEvents ?? '').trim().isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text('Events',
                                style: Theme.of(ctx)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(
                                        color: Theme.of(ctx)
                                            .colorScheme
                                            .onSurfaceVariant)),
                            const SizedBox(height: 4),
                            Text(e.dateEvents!,
                                style: Theme.of(ctx)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                        color: Theme.of(ctx)
                                            .colorScheme
                                            .onSurfaceVariant)),
                          ],
                        ],
                      ),
                    ));
                    return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: widgets);
                  })
                ],
              ),
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedGlowBorder(
      borderWidth: 2,
      radius: AppRadius.lg,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: AppSpacing.paddingLg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Icon(
                        Icons.class_outlined,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            classItem.className,
                            style: context.textStyles.titleLarge?.semiBold,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            classItem.subject,
                            style: context.textStyles.bodyMedium?.withColor(
                              Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      '${classItem.schoolYear} • ${classItem.term}',
                      style: context.textStyles.bodySmall?.withColor(
                        Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                if (classItem.syllabus != null &&
                    classItem.syllabus!.entries.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => _showSyllabusDialog(context),
                      icon: const Icon(Icons.menu_book_outlined, size: 18),
                      label: const Text('View schedule'),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Icon(Icons.arrow_forward, size: 20, color: Theme.of(context).colorScheme.primary),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

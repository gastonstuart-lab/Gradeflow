import 'package:flutter/material.dart';
import 'package:gradeflow/components/workspace_shell.dart';
import 'package:gradeflow/models/class.dart';
import 'package:gradeflow/theme.dart';

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
                    Text(
                      'Source: ${s.sourceFilename!}',
                      style: Theme.of(ctx).textTheme.bodySmall,
                    ),
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
                        Text(
                          e.section!,
                          style: Theme.of(ctx).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 6),
                      ]);
                    }
                    widgets.add(
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Theme.of(ctx).colorScheme.outlineVariant,
                          ),
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
                              Text(
                                e.lessonContent,
                                style: Theme.of(ctx).textTheme.bodyMedium,
                              ),
                            ],
                            if ((e.dateEvents ?? '').trim().isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Events',
                                style: Theme.of(ctx)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(
                                      color: Theme.of(ctx)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                e.dateEvents!,
                                style:
                                    Theme.of(ctx).textTheme.bodySmall?.copyWith(
                                          color: Theme.of(ctx)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: widgets,
                    );
                  }),
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
    final theme = Theme.of(context);
    final hasSyllabusSchedule =
        classItem.syllabus != null && classItem.syllabus!.entries.isNotEmpty;

    return WorkspaceSurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      radius: 18,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.28),
                  ),
                ),
                child: Icon(
                  Icons.class_outlined,
                  color: theme.colorScheme.primary,
                  size: 21,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      classItem.className,
                      style: context.textStyles.titleMedium?.semiBold,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      classItem.subject,
                      style: context.textStyles.bodyMedium?.withColor(
                        theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: classItem.isArchived
                      ? theme.colorScheme.secondary.withValues(alpha: 0.16)
                      : theme.colorScheme.tertiary.withValues(alpha: 0.16),
                ),
                child: Text(
                  classItem.isArchived ? 'Archived' : 'Active',
                  style: context.textStyles.labelSmall?.copyWith(
                    color: classItem.isArchived
                        ? theme.colorScheme.secondary
                        : theme.colorScheme.tertiary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ClassMetaChip(
                icon: Icons.calendar_today_outlined,
                label: classItem.schoolYear,
              ),
              _ClassMetaChip(
                icon: Icons.timeline_outlined,
                label: classItem.term,
              ),
              if ((classItem.groupNumber ?? '').trim().isNotEmpty)
                _ClassMetaChip(
                  icon: Icons.groups_2_outlined,
                  label: 'Group ${classItem.groupNumber!.trim()}',
                ),
            ],
          ),
          if (hasSyllabusSchedule) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _showSyllabusDialog(context),
                icon: const Icon(Icons.menu_book_outlined, size: 18),
                label: const Text('Schedule'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ClassMetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ClassMetaChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.22),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: context.textStyles.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

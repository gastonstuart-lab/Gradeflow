import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:gradeflow/config/gradeflow_product_config.dart';
import 'package:gradeflow/models/class.dart';
import 'package:gradeflow/nav.dart';
import 'package:gradeflow/os/os_palette.dart';
import 'package:gradeflow/services/teacher_workspace_snapshot_service.dart';

/// The calm integration layer on InstructOS Home.
///
/// This widget does not own class, grade, student, IED, or Science data.
/// It only gives the teacher a clear front door into the systems that already
/// own those jobs.
class TeacherHomeIntegrationPanel extends StatelessWidget {
  const TeacherHomeIntegrationPanel({
    super.key,
    required this.primaryClass,
    required this.classes,
    required this.primaryReminder,
    this.onOpenClassroom,
    this.onOpenPlanner,
    this.onOpenGrades,
    this.onOpenStudents,
    this.onOpenIedStudio,
    this.onOpenScience,
  });

  final Class? primaryClass;
  final List<Class> classes;
  final TeacherWorkspaceReminderSnapshot? primaryReminder;

  final VoidCallback? onOpenClassroom;
  final VoidCallback? onOpenPlanner;
  final VoidCallback? onOpenGrades;
  final VoidCallback? onOpenStudents;
  final VoidCallback? onOpenIedStudio;
  final VoidCallback? onOpenScience;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final classItem = primaryClass;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _IntegrationHeader(
            hasClass: classItem != null,
            className: classItem?.className,
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 760;
              final teaching = _TeachingContextCard(
                classItem: classItem,
                onOpenClassroom: () => _openClassroom(context),
                onOpenPlanner: () => _openPlanner(context),
              );
              final reminder = _ReminderCard(
                reminder: primaryReminder,
                onOpenPlanner: () => _openPlanner(context),
              );

              if (!wide) {
                return Column(
                  children: [
                    teaching,
                    const SizedBox(height: 12),
                    reminder,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: teaching),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: reminder),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Text(
            'Where do you want to go?',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: OSColors.text(dark),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'One Home. The existing systems stay responsible for the jobs they already do well.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.35,
              color: OSColors.textSecondary(dark),
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 820
                  ? 3
                  : constraints.maxWidth >= 520
                      ? 2
                      : 1;
              final itemWidth = columns == 1
                  ? constraints.maxWidth
                  : (constraints.maxWidth - ((columns - 1) * 10)) / columns;

              final destinations = [
                _DestinationSpec(
                  title: 'Classroom',
                  subtitle: classItem == null
                      ? 'Choose a class and enter live teaching.'
                      : 'Open the live class for ${classItem.className}.',
                  icon: Icons.meeting_room_rounded,
                  accent: OSColors.cyan,
                  onTap: () => _openClassroom(context),
                ),
                _DestinationSpec(
                  title: 'Planner',
                  subtitle: 'Timetable, reminders, and class planning.',
                  icon: Icons.calendar_month_rounded,
                  accent: OSColors.blue,
                  onTap: () => _openPlanner(context),
                ),
                _DestinationSpec(
                  title: 'Grades',
                  subtitle: classItem == null
                      ? 'Choose a class to open its Gradebook.'
                      : 'Open ${classItem.className} Gradebook.',
                  icon: Icons.menu_book_rounded,
                  accent: OSColors.coral,
                  onTap: () => _openGrades(context),
                ),
                _DestinationSpec(
                  title: 'Students',
                  subtitle: classItem == null
                      ? 'Choose a class to open student records.'
                      : 'Open ${classItem.className} student records.',
                  icon: Icons.people_alt_rounded,
                  accent: OSColors.green,
                  onTap: () => _openStudents(context),
                ),
                _DestinationSpec(
                  title: 'IED Studio',
                  subtitle: 'Departments, hubs, publishing, and shared content.',
                  icon: Icons.hub_rounded,
                  accent: OSColors.indigo,
                  onTap: () => _openIedStudio(context),
                  external: true,
                ),
                _DestinationSpec(
                  title: 'Science',
                  subtitle: 'Courses, lessons, and teaching resources.',
                  icon: Icons.science_rounded,
                  accent: OSColors.cyan,
                  onTap: () => _openScience(context),
                  external: true,
                ),
              ];

              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final destination in destinations)
                    SizedBox(
                      width: itemWidth,
                      child: _DestinationCard(spec: destination),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          _ClassStrip(classes: classes),
        ],
      ),
    );
  }

  void _openClassroom(BuildContext context) {
    if (onOpenClassroom != null) {
      onOpenClassroom!();
      return;
    }
    final classItem = primaryClass;
    context.go(
      classItem == null
          ? AppRoutes.classes
          : AppRoutes.osClassroom(classItem.classId),
    );
  }

  void _openPlanner(BuildContext context) {
    if (onOpenPlanner != null) {
      onOpenPlanner!();
      return;
    }
    context.go(AppRoutes.osPlanner);
  }

  void _openGrades(BuildContext context) {
    if (onOpenGrades != null) {
      onOpenGrades!();
      return;
    }
    final classItem = primaryClass;
    context.go(
      classItem == null
          ? AppRoutes.classes
          : AppRoutes.osClassGradebook(classItem.classId),
    );
  }

  void _openStudents(BuildContext context) {
    if (onOpenStudents != null) {
      onOpenStudents!();
      return;
    }
    final classItem = primaryClass;
    context.go(
      classItem == null
          ? AppRoutes.classes
          : AppRoutes.osClassStudents(classItem.classId),
    );
  }

  void _openIedStudio(BuildContext context) {
    if (onOpenIedStudio != null) {
      onOpenIedStudio!();
      return;
    }
    _launchConnectedDestination(
      context,
      GradeFlowProductConfig.iedStudioUrl,
      label: 'IED Studio',
    );
  }

  void _openScience(BuildContext context) {
    if (onOpenScience != null) {
      onOpenScience!();
      return;
    }
    _launchConnectedDestination(
      context,
      GradeFlowProductConfig.scienceLessonsUrl,
      label: 'Science',
    );
  }

  Future<void> _launchConnectedDestination(
    BuildContext context,
    String url, {
    required String label,
  }) async {
    final uri = Uri.parse(url);
    final opened = await launchUrl(uri, mode: LaunchMode.platformDefault);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$label could not be opened.')),
      );
    }
  }
}

class _IntegrationHeader extends StatelessWidget {
  const _IntegrationHeader({
    required this.hasClass,
    required this.className,
  });

  final bool hasClass;
  final String? className;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: OSColors.blue.withValues(alpha: dark ? 0.18 : 0.12),
            borderRadius: BorderRadius.circular(OSRadius.md),
            border: Border.all(
              color: OSColors.blue.withValues(alpha: 0.22),
            ),
          ),
          child: const Icon(
            Icons.space_dashboard_rounded,
            color: OSColors.blue,
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TEACHER HOME',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: OSColors.blue,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                hasClass
                    ? 'Ready for ${className ?? 'class'}'
                    : 'Choose your teaching direction',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: OSColors.text(dark),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TeachingContextCard extends StatelessWidget {
  const _TeachingContextCard({
    required this.classItem,
    required this.onOpenClassroom,
    required this.onOpenPlanner,
  });

  final Class? classItem;
  final VoidCallback onOpenClassroom;
  final VoidCallback onOpenPlanner;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final item = classItem;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: OSColors.elevatedPanelSurface(dark).withValues(alpha: 0.90),
        borderRadius: OSRadius.lgBr,
        border: Border.all(color: OSColors.panelBorder(dark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TEACHING CONTEXT',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
              color: OSColors.cyan,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item?.className ?? 'No class selected',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: OSColors.text(dark),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item == null
                ? 'Open your classes to choose the teaching context.'
                : '${item.subject} · ${item.term} · ${item.schoolYear}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.35,
              color: OSColors.textSecondary(dark),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: onOpenClassroom,
                icon: const Icon(Icons.meeting_room_rounded, size: 18),
                label: Text(item == null ? 'Choose class' : 'Open Classroom'),
              ),
              OutlinedButton.icon(
                onPressed: onOpenPlanner,
                icon: const Icon(Icons.schedule_rounded, size: 18),
                label: const Text('Check Planner'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Home is not guessing a next-class time. Planner remains the source for timetable context until that link is reliable.',
            style: TextStyle(
              fontSize: 10.5,
              height: 1.3,
              color: OSColors.textMuted(dark),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({
    required this.reminder,
    required this.onOpenPlanner,
  });

  final TeacherWorkspaceReminderSnapshot? reminder;
  final VoidCallback onOpenPlanner;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final item = reminder;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: OSColors.panelSurface(dark).withValues(alpha: 0.90),
        borderRadius: OSRadius.lgBr,
        border: Border.all(color: OSColors.panelBorder(dark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.notifications_active_outlined,
                size: 19,
                color: OSColors.amber,
              ),
              const SizedBox(width: 8),
              Text(
                'ATTENTION',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                  color: OSColors.amber,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            item?.text ?? 'No pending reminder',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              height: 1.25,
              fontWeight: FontWeight.w800,
              color: OSColors.text(dark),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item == null
                ? 'Planner is clear right now.'
                : _formatReminderDate(item.timestamp),
            style: TextStyle(
              fontSize: 11.5,
              color: OSColors.textSecondary(dark),
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: onOpenPlanner,
            icon: const Icon(Icons.arrow_forward_rounded, size: 17),
            label: const Text('Open Planner'),
          ),
        ],
      ),
    );
  }

  String _formatReminderDate(DateTime timestamp) {
    final local = timestamp.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final suffix = local.hour >= 12 ? 'PM' : 'AM';
    return '${local.month}/${local.day} · $hour:$minute $suffix';
  }
}

class _DestinationSpec {
  const _DestinationSpec({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onTap,
    this.external = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;
  final bool external;
}

class _DestinationCard extends StatelessWidget {
  const _DestinationCard({required this.spec});

  final _DestinationSpec spec;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return InkWell(
      onTap: spec.onTap,
      borderRadius: OSRadius.mdBr,
      child: Container(
        constraints: const BoxConstraints(minHeight: 118),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: OSColors.panelSurface(dark).withValues(alpha: 0.82),
          borderRadius: OSRadius.mdBr,
          border: Border.all(
            color: spec.accent.withValues(alpha: dark ? 0.20 : 0.14),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: spec.accent.withValues(alpha: dark ? 0.16 : 0.10),
                borderRadius: OSRadius.smBr,
              ),
              child: Icon(spec.icon, size: 20, color: spec.accent),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          spec.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: OSColors.text(dark),
                          ),
                        ),
                      ),
                      Icon(
                        spec.external
                            ? Icons.open_in_new_rounded
                            : Icons.chevron_right_rounded,
                        size: 17,
                        color: OSColors.textMuted(dark),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    spec.subtitle,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.3,
                      color: OSColors.textSecondary(dark),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClassStrip extends StatelessWidget {
  const _ClassStrip({required this.classes});

  final List<Class> classes;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final visible = classes.take(4).toList();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: OSColors.panelSurface(dark).withValues(alpha: 0.68),
        borderRadius: OSRadius.lgBr,
        border: Border.all(color: OSColors.panelBorder(dark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Classes',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: OSColors.text(dark),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            classes.isEmpty
                ? 'No active classes are loaded.'
                : 'Open a class workspace without pretending these are today’s classes.',
            style: TextStyle(
              fontSize: 11.5,
              color: OSColors.textSecondary(dark),
            ),
          ),
          if (visible.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in visible)
                  ActionChip(
                    avatar: const Icon(Icons.class_outlined, size: 16),
                    label: Text(item.className),
                    onPressed: () =>
                        context.go(AppRoutes.osClassWorkspace(item.classId)),
                  ),
                if (classes.length > visible.length)
                  ActionChip(
                    avatar: const Icon(Icons.more_horiz_rounded, size: 16),
                    label: Text('${classes.length - visible.length} more'),
                    onPressed: () => context.go(AppRoutes.classes),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

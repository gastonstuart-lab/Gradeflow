import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:gradeflow/components/workspace_shell.dart';
import 'package:gradeflow/config/gradeflow_product_config.dart';
import 'package:gradeflow/nav.dart';
import 'package:gradeflow/providers/app_providers.dart';
import 'package:gradeflow/repositories/repository_factory.dart';
import 'package:gradeflow/services/auth_service.dart';
import 'package:gradeflow/services/class_trash_service.dart';
import 'package:gradeflow/services/communication_service.dart';
import 'package:gradeflow/services/google_auth_service.dart';
import 'package:gradeflow/services/teacher_workspace_snapshot_service.dart';
import 'package:gradeflow/theme.dart';
import 'package:gradeflow/models/communication_models.dart';

class AdminWorkspaceScreen extends StatefulWidget {
  const AdminWorkspaceScreen({super.key});

  @override
  State<AdminWorkspaceScreen> createState() => _AdminWorkspaceScreenState();
}

class _AdminWorkspaceScreenState extends State<AdminWorkspaceScreen> {
  final TeacherWorkspaceSnapshotService _snapshotService =
      const TeacherWorkspaceSnapshotService();

  bool _loading = true;
  String? _error;
  TeacherWorkspaceSnapshot? _workspaceSnapshot;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
    });
  }

  Future<void> _load() async {
    final auth = context.read<AuthService>();
    final user = auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'You need to sign in before opening admin workflows.';
      });
      return;
    }

    try {
      final workspace = await _snapshotService.loadForUser(user);
      await context.read<ClassTrashService>().loadTrash(teacherId: user.userId);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = null;
        _workspaceSnapshot = workspace;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _logout() async {
    await context.read<GoogleAuthService>().signOut();
    await context.read<AuthService>().logout();
    if (!mounted) return;
    context.go(AppRoutes.home);
  }

  Future<void> _showAdminAlertComposer(BuildContext context) async {
    final controller = TextEditingController();
    var severity = CommunicationAlertSeverity.attention;
    var submitting = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Post admin alert'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: controller,
                      minLines: 3,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        labelText: 'Alert message',
                        hintText:
                            'Share a school-wide notice or operational update',
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<CommunicationAlertSeverity>(
                      initialValue: severity,
                      decoration: const InputDecoration(
                        labelText: 'Severity',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: CommunicationAlertSeverity.info,
                          child: Text('Info'),
                        ),
                        DropdownMenuItem(
                          value: CommunicationAlertSeverity.attention,
                          child: Text('Attention'),
                        ),
                        DropdownMenuItem(
                          value: CommunicationAlertSeverity.urgent,
                          child: Text('Urgent'),
                        ),
                      ],
                      onChanged: submitting
                          ? null
                          : (value) {
                              if (value == null) return;
                              setDialogState(() {
                                severity = value;
                              });
                            },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      submitting ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  onPressed: submitting
                      ? null
                      : () async {
                          final text = controller.text.trim();
                          if (text.isEmpty) return;
                          setDialogState(() {
                            submitting = true;
                          });
                          await this
                              .context
                              .read<CommunicationService>()
                              .postAdminAlert(
                                text,
                                severity: severity,
                              );
                          if (!mounted) return;
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            const SnackBar(
                              content: Text('Admin alert posted'),
                            ),
                          );
                        },
                  icon: submitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.campaign_outlined),
                  label: const Text('Post alert'),
                ),
              ],
            );
          },
        );
      },
    );
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = context.watch<ThemeModeNotifier>().themeMode;
    final classTrash = context.watch<ClassTrashService>();
    final communicationService = context.watch<CommunicationService>();
    final workspace = _workspaceSnapshot;

    return WorkspaceScaffold(
      eyebrow: 'Admin edition',
      title: 'School operations workspace',
      subtitle:
          'Shared-school oversight, lifecycle management, and communication readiness now live in one operational workspace.',
      leadingActions: [
        WorkspaceNavButton(
          icon: Icons.dashboard_outlined,
          label: 'Dashboard',
          onPressed: () => context.go(AppRoutes.dashboard),
        ),
        WorkspaceNavButton(
          icon: Icons.forum_outlined,
          label: 'Communication',
          onPressed: () => context.go(AppRoutes.communication),
        ),
        WorkspaceNavButton(
          icon: Icons.admin_panel_settings_outlined,
          label: 'Admin',
          onPressed: () {},
          selected: true,
        ),
      ],
      trailingActions: [
        IconButton(
          tooltip: themeMode == ThemeMode.dark
              ? 'Switch app theme'
              : 'Switch app theme',
          onPressed: () => context.read<ThemeModeNotifier>().toggleTheme(),
          icon: Icon(
            themeMode == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode,
          ),
        ),
        IconButton(
          tooltip: 'Log out',
          onPressed: _logout,
          icon: const Icon(Icons.logout),
        ),
      ],
      metrics: workspace == null
          ? const []
          : [
              WorkspaceMetricData(
                label: 'Active classes',
                value: workspace.activeClasses.length.toString(),
                detail:
                    '${workspace.totalStudents} students in live teaching spaces',
                icon: Icons.class_outlined,
              ),
              WorkspaceMetricData(
                label: 'Archived classes',
                value: workspace.archivedClasses.length.toString(),
                detail: 'Semester rollover and reporting history',
                icon: Icons.inventory_2_outlined,
              ),
              WorkspaceMetricData(
                label: 'Recycle bin',
                value: classTrash.trash.length.toString(),
                detail: 'Recoverable classes currently in trash',
                icon: Icons.delete_outline_rounded,
              ),
              WorkspaceMetricData(
                label: 'Source of truth',
                value: RepositoryFactory.sourceOfTruthLabel,
                detail: RepositoryFactory.sourceOfTruthDescription,
                icon: RepositoryFactory.isUsingFirestore
                    ? Icons.cloud_done_outlined
                    : Icons.offline_bolt_outlined,
              ),
            ],
      headerActions: [
        OutlinedButton.icon(
          onPressed: () => _showAdminAlertComposer(context),
          icon: const Icon(Icons.campaign_outlined),
          label: const Text('Post alert'),
        ),
        FilledButton.icon(
          onPressed: () => context.go(AppRoutes.classTrash),
          icon: const Icon(Icons.delete_outline_rounded),
          label: const Text('Open recycle bin'),
        ),
        OutlinedButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Refresh'),
        ),
      ],
      child: _buildBody(
        context,
        deletedClassCount: classTrash.trash.length,
        communicationService: communicationService,
      ),
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required int deletedClassCount,
    required CommunicationService communicationService,
  }) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return WorkspaceEmptyState(
        icon: Icons.admin_panel_settings_outlined,
        title: 'Admin workspace is not available',
        subtitle: _error!,
        actions: [
          FilledButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
          ),
        ],
      );
    }

    final workspace = _workspaceSnapshot!;
    final user = workspace.user;
    final schoolName =
        GradeFlowProductConfig.resolvedSchoolName(user.schoolName);

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WorkspaceSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const WorkspaceSectionHeader(
                  title: 'Operational Readiness',
                  subtitle:
                      'The core academic workflow, deleted-item lifecycle, and communication rollout are now visible in one place.',
                ),
                const SizedBox(height: 16),
                _AdminStatusRow(
                  icon: Icons.school_outlined,
                  title: schoolName,
                  subtitle:
                      '${workspace.activeClasses.length} active classes, ${workspace.archivedClasses.length} archived, and ${workspace.pendingReminders.length} pending reminders in the teacher workspace.',
                ),
                const SizedBox(height: 12),
                _AdminStatusRow(
                  icon: RepositoryFactory.isUsingFirestore
                      ? Icons.cloud_done_outlined
                      : Icons.cloud_off_outlined,
                  title: RepositoryFactory.sourceOfTruthLabel,
                  subtitle: RepositoryFactory.sourceOfTruthDescription,
                ),
                const SizedBox(height: 12),
                _AdminStatusRow(
                  icon: Icons.delete_sweep_outlined,
                  title: deletedClassCount == 0
                      ? 'Recycle bin is clear'
                      : '$deletedClassCount class${deletedClassCount == 1 ? '' : 'es'} in recycle bin',
                  subtitle:
                      'Deleted classes stay recoverable through a clear admin workflow.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          WorkspaceSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const WorkspaceSectionHeader(
                  title: 'Recent Admin Alerts',
                  subtitle:
                      'School-wide notices posted here now feed the shared communication workspace.',
                ),
                const SizedBox(height: 16),
                if (communicationService.adminAlertMessages.isEmpty)
                  _AdminStatusRow(
                    icon: Icons.campaign_outlined,
                    title: 'No live admin alerts yet',
                    subtitle:
                        'Use “Post alert” to publish a real notice into the shared staff communication rail.',
                  )
                else
                  Column(
                    children: [
                      for (final alert in communicationService
                          .adminAlertMessages.reversed
                          .take(4))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _AdminStatusRow(
                            icon: _alertIcon(alert.severity),
                            title: alert.text,
                            subtitle:
                                '${alert.authorName} • ${_alertTimeLabel(alert.createdAt)}',
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          WorkspaceSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const WorkspaceSectionHeader(
                  title: 'What Works Today',
                  subtitle:
                      'These are the connected school operations already available in the current app.',
                ),
                const SizedBox(height: 16),
                const Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _AdminCapabilityCard(
                      title: 'Class lifecycle',
                      subtitle:
                          'Create, archive, restore, and delete classes with a visible recovery path.',
                      icon: Icons.inventory_2_outlined,
                    ),
                    _AdminCapabilityCard(
                      title: 'Teacher workspace health',
                      subtitle:
                          'Dashboard, planning, classes, seating, grading, and export flows now connect coherently.',
                      icon: Icons.dashboard_customize_outlined,
                    ),
                    _AdminCapabilityCard(
                      title: 'Communication foundation',
                      subtitle:
                          'Admin notices, staff communication, and school-wide workflows now have a clear home to grow from.',
                      icon: Icons.forum_outlined,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          WorkspaceSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                WorkspaceSectionHeader(
                  title: 'Best Next Ops Move',
                  subtitle:
                      'The biggest remaining jump is turning the connected communication surfaces into true shared school workflows.',
                ),
                SizedBox(height: 16),
                _AdminStatusRow(
                  icon: Icons.hub_outlined,
                  title: 'Build the shared communication repository',
                  subtitle:
                      'Next milestone: shared memberships, channels, admin alerts, unread counts, and attachments.',
                ),
                SizedBox(height: 12),
                _AdminStatusRow(
                  icon: Icons.verified_user_outlined,
                  title: 'Add role-aware access',
                  subtitle:
                      'Admin, department lead, and teacher roles should shape visibility once live communication is turned on.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _alertIcon(CommunicationAlertSeverity severity) {
    switch (severity) {
      case CommunicationAlertSeverity.info:
        return Icons.campaign_outlined;
      case CommunicationAlertSeverity.attention:
        return Icons.notification_important_outlined;
      case CommunicationAlertSeverity.urgent:
        return Icons.priority_high_rounded;
    }
  }

  String _alertTimeLabel(DateTime createdAt) {
    final hour = createdAt.hour == 0
        ? 12
        : (createdAt.hour > 12 ? createdAt.hour - 12 : createdAt.hour);
    final minute = createdAt.minute.toString().padLeft(2, '0');
    final period = createdAt.hour >= 12 ? 'PM' : 'AM';
    return '${createdAt.month}/${createdAt.day} • $hour:$minute $period';
  }
}

class _AdminStatusRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _AdminStatusRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color:
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.14),
          ),
          child: Icon(icon, color: Theme.of(context).colorScheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: context.textStyles.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: context.textStyles.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AdminCapabilityCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _AdminCapabilityCard({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      child: WorkspaceSurfaceCard(
        padding: const EdgeInsets.all(16),
        radius: 20,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: Theme.of(context)
                    .colorScheme
                    .secondary
                    .withValues(alpha: 0.14),
              ),
              child: Icon(icon, color: Theme.of(context).colorScheme.secondary),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: context.textStyles.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: context.textStyles.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

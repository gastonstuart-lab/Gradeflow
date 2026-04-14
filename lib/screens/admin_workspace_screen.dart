import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:gradeflow/components/workspace_shell.dart';
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

  void _showFeedback(
    String message, {
    WorkspaceFeedbackTone tone = WorkspaceFeedbackTone.info,
    String? title,
  }) {
    if (!mounted) return;
    showWorkspaceSnackBar(
      context,
      message: message,
      tone: tone,
      title: title,
    );
  }

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
            return WorkspaceDialogScaffold(
              title: 'Post admin alert',
              subtitle:
                  'Publish a school-wide notice into the shared staff communication rail.',
              icon: Icons.campaign_outlined,
              body: SizedBox(
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
                    const SizedBox(height: 12),
                    DropdownButtonFormField<CommunicationAlertSeverity>(
                      value: severity,
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
                  style: WorkspaceButtonStyles.text(dialogContext),
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
                          _showFeedback(
                            'Admin alert posted.',
                            tone: WorkspaceFeedbackTone.success,
                            title: 'Alert sent',
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
                  style: WorkspaceButtonStyles.filled(dialogContext),
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
          'Shared-school oversight, lifecycle management, and communication readiness in one operational workspace.',
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
          style: WorkspaceButtonStyles.outlined(context),
        ),
        FilledButton.icon(
          onPressed: () => context.go(AppRoutes.classTrash),
          icon: const Icon(Icons.delete_outline_rounded),
          label: const Text('Open recycle bin'),
          style: WorkspaceButtonStyles.filled(context),
        ),
        OutlinedButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Refresh'),
          style: WorkspaceButtonStyles.outlined(context),
        ),
      ],
      child: _buildBody(
        context,
        communicationService: communicationService,
      ),
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required CommunicationService communicationService,
  }) {
    if (_loading) {
      return const WorkspaceLoadingState(
        title: 'Loading admin workspace',
        subtitle: 'Syncing school operations, alerts, and lifecycle controls.',
      );
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
            style: WorkspaceButtonStyles.filled(context),
          ),
        ],
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WorkspaceSurfaceCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const WorkspaceSectionHeader(
                  title: 'Recent Admin Alerts',
                  subtitle:
                      'School-wide notices posted here feed the shared communication workspace.',
                ),
                const SizedBox(height: 14),
                if (communicationService.adminAlertMessages.isEmpty)
                  _AdminStatusRow(
                    icon: Icons.campaign_outlined,
                    title: 'No live admin alerts yet',
                    subtitle:
                        'Use "Post alert" to publish a school notice into the shared staff rail.',
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
                                '${alert.authorName} - ${_alertTimeLabel(alert.createdAt)}',
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          WorkspaceSurfaceCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const WorkspaceSectionHeader(
                  title: 'Connected Operations',
                  subtitle:
                      'These school operations are already connected inside the current workspace.',
                ),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final tileWidth = constraints.maxWidth >= 1180
                        ? (constraints.maxWidth - 24) / 3
                        : constraints.maxWidth >= 760
                            ? (constraints.maxWidth - 12) / 2
                            : constraints.maxWidth;

                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: tileWidth,
                          child: const _AdminCapabilityCard(
                            title: 'Class lifecycle',
                            subtitle:
                                'Create, archive, restore, and delete classes with a visible recovery path.',
                            icon: Icons.inventory_2_outlined,
                          ),
                        ),
                        SizedBox(
                          width: tileWidth,
                          child: const _AdminCapabilityCard(
                            title: 'Teacher workspace health',
                            subtitle:
                                'Dashboard, planning, classes, seating, grading, and export flows stay connected.',
                            icon: Icons.dashboard_customize_outlined,
                          ),
                        ),
                        SizedBox(
                          width: tileWidth,
                          child: const _AdminCapabilityCard(
                            title: 'Communication foundation',
                            subtitle:
                                'Admin notices, shared staff channels, and school groups now have a real home.',
                            icon: Icons.forum_outlined,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          WorkspaceSurfaceCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                WorkspaceSectionHeader(
                  title: 'Best Next Ops Move',
                  subtitle:
                      'The next quality jump is turning connected communication surfaces into shared school workflows.',
                ),
                SizedBox(height: 14),
                _AdminStatusRow(
                  icon: Icons.hub_outlined,
                  title: 'Finish the shared communication layer',
                  subtitle:
                      'Next milestone: shared memberships, attachments, and stronger group controls on top of the live channel system.',
                ),
                SizedBox(height: 12),
                _AdminStatusRow(
                  icon: Icons.verified_user_outlined,
                  title: 'Add role-aware access',
                  subtitle:
                      'Admin, department lead, and teacher roles should shape visibility once live communication is enabled.',
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
    return '${createdAt.month}/${createdAt.day} - $hour:$minute $period';
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
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color:
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.14),
          ),
          child: Icon(
            icon,
            size: 18,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.textStyles.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.textStyles.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.35,
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
    return WorkspaceSurfaceCard(
      padding: const EdgeInsets.all(14),
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Theme.of(context)
                  .colorScheme
                  .secondary
                  .withValues(alpha: 0.14),
            ),
            child: Icon(
              icon,
              size: 18,
              color: Theme.of(context).colorScheme.secondary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.textStyles.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: context.textStyles.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

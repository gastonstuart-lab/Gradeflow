import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:gradeflow/components/command_surface.dart';
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
      header: _buildAdminHeader(
        context,
        workspace: workspace,
        trashCount: classTrash.trash.length,
      ),
      eyebrow: 'Support surface',
      title: 'School support',
      subtitle:
          'Recovery, alerts, and connected environment health for the wider teacher OS.',
      leadingActions: const [],
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
      contextBar: _buildAdminSupportStrip(
        context,
        workspace: workspace,
        trashCount: classTrash.trash.length,
      ),
      child: _buildBody(
        context,
        communicationService: communicationService,
      ),
    );
  }

  Widget _buildAdminHeader(
    BuildContext context, {
    required TeacherWorkspaceSnapshot? workspace,
    required int trashCount,
  }) {
    return CommandHeader(
      eyebrow: 'Support surface',
      title: 'School support',
      subtitle:
          'Recovery, alerts, and connected environment health for the wider teacher OS.',
      leading: IconButton(
        tooltip: 'Back to OS home',
        onPressed: () => context.go(AppRoutes.osHome),
        icon: const Icon(Icons.arrow_back_rounded),
        style: WorkspaceButtonStyles.icon(context),
      ),
      primaryAction: FilledButton.icon(
        onPressed: () => context.go(AppRoutes.classTrash),
        icon: const Icon(Icons.delete_outline_rounded),
        label: const Text('Open recycle bin'),
        style: WorkspaceButtonStyles.filled(context),
      ),
      contextPills: [
        WorkspaceContextPill(
          icon: Icons.class_outlined,
          label: 'Active classes',
          value: workspace == null ? '--' : '${workspace.activeClasses.length}',
          emphasized: workspace != null && workspace.activeClasses.isNotEmpty,
        ),
        WorkspaceContextPill(
          icon: Icons.inventory_2_outlined,
          label: 'Archived',
          value:
              workspace == null ? '--' : '${workspace.archivedClasses.length}',
          accent: Theme.of(context).colorScheme.secondary,
        ),
        WorkspaceContextPill(
          icon: Icons.delete_outline_rounded,
          label: 'Recycle bin',
          value: '$trashCount',
          accent: Theme.of(context).colorScheme.tertiary,
          emphasized: trashCount > 0,
        ),
        WorkspaceContextPill(
          icon: RepositoryFactory.isUsingFirestore
              ? Icons.cloud_done_outlined
              : Icons.offline_bolt_outlined,
          label: 'Source',
          value: RepositoryFactory.sourceOfTruthLabel,
          accent: RepositoryFactory.isUsingFirestore
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.secondary,
        ),
      ],
      pulseTone: CommandPulseTone.attention,
      pulseLabel: 'Recovery and support alerts live',
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required CommunicationService communicationService,
  }) {
    if (_loading) {
      return const WorkspaceLoadingState(
        title: 'Loading school support',
        subtitle: 'Syncing alerts, recovery controls, and environment health.',
      );
    }

    if (_error != null) {
      return WorkspaceEmptyState(
        icon: Icons.admin_panel_settings_outlined,
        title: 'School support is not available',
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
          CommandSurfaceCard(
            surfaceType: SurfaceType.tool,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const WorkspaceSectionHeader(
                  title: 'Shared alerts',
                  subtitle:
                      'School-wide notices posted here feed the shared staff communication lane.',
                ),
                const SizedBox(height: 14),
                if (communicationService.adminAlertMessages.isEmpty)
                  _AdminStatusRow(
                    icon: Icons.campaign_outlined,
                    title: 'No school-wide alerts yet',
                    subtitle:
                        'Use "Post alert" to publish a notice into the shared staff communication lane.',
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
                            accent: _alertAccent(context, alert.severity),
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
          CommandSurfaceCard(
            surfaceType: SurfaceType.tool,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const WorkspaceSectionHeader(
                  title: 'Connected support lanes',
                  subtitle:
                      'These secondary systems are already connected inside the teacher OS.',
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
                            title: 'Class lifecycle & recovery',
                            subtitle:
                                'Archive, restore, and retire classes with a visible recovery path.',
                            icon: Icons.inventory_2_outlined,
                          ),
                        ),
                        SizedBox(
                          width: tileWidth,
                          child: const _AdminCapabilityCard(
                            title: 'Teacher OS health',
                            subtitle:
                                'Planning hub, class workspaces, and support surfaces stay connected.',
                            icon: Icons.dashboard_customize_outlined,
                          ),
                        ),
                        SizedBox(
                          width: tileWidth,
                          child: const _AdminCapabilityCard(
                            title: 'Staff communication layer',
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
          CommandSurfaceCard(
            surfaceType: SurfaceType.whisper,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                WorkspaceSectionHeader(
                  title: 'Support posture',
                  subtitle:
                      'The core support lane is live, with the next tightening step centered on permissions and shared communication depth.',
                ),
                SizedBox(height: 14),
                _AdminStatusRow(
                  icon: Icons.hub_outlined,
                  title: 'Shared communication is now anchored',
                  subtitle:
                      'Alerts and staff channels now sit inside a dedicated support surface instead of scattered admin utilities.',
                ),
                SizedBox(height: 12),
                _AdminStatusRow(
                  icon: Icons.verified_user_outlined,
                  title: 'Role-aware access is the next quality gate',
                  subtitle:
                      'Admin, department lead, and teacher roles should shape visibility as shared communication continues to mature.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminSupportStrip(
    BuildContext context, {
    required TeacherWorkspaceSnapshot? workspace,
    required int trashCount,
  }) {
    return CommandSurfaceCard(
      surfaceType: SurfaceType.whisper,
      padding: const EdgeInsets.all(14),
      actions: [
        OutlinedButton.icon(
          onPressed: () => _showAdminAlertComposer(context),
          icon: const Icon(Icons.campaign_outlined),
          label: const Text('Post alert'),
          style: WorkspaceButtonStyles.outlined(context, compact: true),
        ),
        OutlinedButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Refresh'),
          style: WorkspaceButtonStyles.outlined(context, compact: true),
        ),
      ],
      header: const WorkspaceSectionHeader(
        title: 'School support lane',
        subtitle:
            'Keep recovery, environment health, and staff alerts visible here without competing with live class work.',
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _AdminSummaryChip(
            icon: Icons.class_outlined,
            label: 'Active classes',
            value:
                workspace == null ? '--' : '${workspace.activeClasses.length}',
          ),
          _AdminSummaryChip(
            icon: Icons.inventory_2_outlined,
            label: 'Archived',
            value: workspace == null
                ? '--'
                : '${workspace.archivedClasses.length}',
            accent: Theme.of(context).colorScheme.secondary,
          ),
          _AdminSummaryChip(
            icon: Icons.delete_outline_rounded,
            label: 'Recycle bin',
            value: '$trashCount',
            accent: Theme.of(context).colorScheme.tertiary,
            emphasized: trashCount > 0,
          ),
          _AdminSummaryChip(
            icon: RepositoryFactory.isUsingFirestore
                ? Icons.cloud_done_outlined
                : Icons.offline_bolt_outlined,
            label: 'Source',
            value: RepositoryFactory.sourceOfTruthLabel,
            accent: RepositoryFactory.isUsingFirestore
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.secondary,
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

  Color _alertAccent(
    BuildContext context,
    CommunicationAlertSeverity severity,
  ) {
    switch (severity) {
      case CommunicationAlertSeverity.info:
        return Theme.of(context).colorScheme.primary;
      case CommunicationAlertSeverity.attention:
        return Theme.of(context).colorScheme.tertiary;
      case CommunicationAlertSeverity.urgent:
        return Theme.of(context).colorScheme.error;
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
  final Color? accent;

  const _AdminStatusRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedAccent = accent ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            resolvedAccent.withValues(alpha: 0.10),
            Theme.of(context).colorScheme.surface.withValues(alpha: 0.14),
          ],
        ),
        border: Border.all(
          color: resolvedAccent.withValues(alpha: 0.16),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: resolvedAccent.withValues(alpha: 0.14),
            ),
            child: Icon(
              icon,
              size: 18,
              color: resolvedAccent,
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
      ),
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
    final accent = Theme.of(context).colorScheme.secondary;
    return CommandSurfaceCard(
      surfaceType: SurfaceType.tool,
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
              color: accent.withValues(alpha: 0.14),
            ),
            child: Icon(
              icon,
              size: 18,
              color: accent,
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

class _AdminSummaryChip extends StatelessWidget {
  const _AdminSummaryChip({
    required this.icon,
    required this.label,
    required this.value,
    this.accent,
    this.emphasized = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? accent;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final resolvedAccent = accent ?? Theme.of(context).colorScheme.primary;
    return WorkspaceContextPill(
      icon: icon,
      label: label,
      value: value,
      accent: resolvedAccent,
      emphasized: emphasized,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:gradeflow/components/workspace_shell.dart';
import 'package:gradeflow/models/communication_models.dart';
import 'package:gradeflow/nav.dart';
import 'package:gradeflow/providers/app_providers.dart';
import 'package:gradeflow/repositories/repository_factory.dart';
import 'package:gradeflow/services/auth_service.dart';
import 'package:gradeflow/services/communication_service.dart';
import 'package:gradeflow/services/google_auth_service.dart';
import 'package:gradeflow/services/teacher_workspace_snapshot_service.dart';
import 'package:gradeflow/theme.dart';

class CommunicationHubScreen extends StatefulWidget {
  const CommunicationHubScreen({super.key});

  @override
  State<CommunicationHubScreen> createState() => _CommunicationHubScreenState();
}

class _CommunicationHubScreenState extends State<CommunicationHubScreen> {
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
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    final auth = context.read<AuthService>();
    final user = auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'You need to sign in before opening staff communication.';
      });
      return;
    }

    try {
      final workspace = await _snapshotService.loadForUser(user);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = null;
        _workspaceSnapshot = workspace;
      });
      if (!mounted) return;
      await context.read<CommunicationService>().load();
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

  Future<void> _showCreateGroupDialog(BuildContext context) async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    var kind = CommunicationChannelKind.department;
    var submitting = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Create staff group'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Group name',
                        hintText:
                            'English team, Grade 8 support, Shared resources',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: descriptionController,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Purpose',
                        hintText:
                            'Explain what this group is for so teachers know when to use it.',
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<CommunicationChannelKind>(
                      initialValue: kind,
                      decoration:
                          const InputDecoration(labelText: 'Group type'),
                      items: const [
                        DropdownMenuItem(
                          value: CommunicationChannelKind.department,
                          child: Text('Department space'),
                        ),
                        DropdownMenuItem(
                          value: CommunicationChannelKind.gradeTeam,
                          child: Text('Team group'),
                        ),
                        DropdownMenuItem(
                          value: CommunicationChannelKind.sharedFiles,
                          child: Text('Shared resources'),
                        ),
                      ],
                      onChanged: submitting
                          ? null
                          : (value) {
                              if (value == null) return;
                              setDialogState(() {
                                kind = value;
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
                          final service =
                              this.context.read<CommunicationService>();
                          setDialogState(() {
                            submitting = true;
                          });
                          final created = await service.createChannel(
                            name: nameController.text,
                            description: descriptionController.text,
                            kind: kind,
                          );
                          if (!mounted) return;
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(
                              content: Text(
                                created
                                    ? 'Staff group created'
                                    : 'Could not create that group yet',
                              ),
                            ),
                          );
                        },
                  icon: submitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_circle_outline_rounded),
                  label: const Text('Create group'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    descriptionController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final workspace = _workspaceSnapshot;
    final communicationService = context.watch<CommunicationService>();
    final themeMode = context.watch<ThemeModeNotifier>().themeMode;

    return WorkspaceScaffold(
      eyebrow: 'Communication edition',
      title: 'Communication hub',
      subtitle:
          'Staff coordination, admin alerts, and shared-school updates stay together in one calm workspace.',
      trailingActions: [
        IconButton(
          tooltip: 'Switch app theme',
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
                label: 'Unread',
                value: communicationService.totalUnreadCount.toString(),
                detail: 'Channels waiting for your attention right now',
                icon: Icons.mark_chat_unread_outlined,
                accent: Theme.of(context).colorScheme.primary,
              ),
              WorkspaceMetricData(
                label: 'Staff lanes',
                value: communicationService.channelCount.toString(),
                detail: 'Admin, staff, team, and shared-resource channels',
                icon: Icons.groups_rounded,
              ),
              WorkspaceMetricData(
                label: 'Active classes',
                value: workspace.activeClasses.length.toString(),
                detail:
                    '${workspace.totalStudents} students across live classes',
                icon: Icons.class_outlined,
              ),
              WorkspaceMetricData(
                label: 'Sync mode',
                value: RepositoryFactory.sourceOfTruthLabel,
                detail: RepositoryFactory.sourceOfTruthDescription,
                icon: RepositoryFactory.isUsingFirestore
                    ? Icons.cloud_done_outlined
                    : Icons.offline_bolt_outlined,
              ),
            ],
      headerActions: [
        OutlinedButton.icon(
          onPressed: () => _showCreateGroupDialog(context),
          icon: const Icon(Icons.add_circle_outline_rounded),
          label: const Text('New group'),
        ),
        FilledButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Refresh'),
        ),
      ],
      child: _buildBody(context, communicationService),
    );
  }

  Widget _buildBody(
    BuildContext context,
    CommunicationService communicationService,
  ) {
    if (_loading ||
        (communicationService.isLoading && _workspaceSnapshot == null)) {
      return const Center(child: CircularProgressIndicator());
    }

    final activeError = _error ?? communicationService.error;
    if (activeError != null) {
      return WorkspaceEmptyState(
        icon: Icons.forum_outlined,
        title: 'Communication is not ready yet',
        subtitle: activeError,
        actions: [
          FilledButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
          ),
          OutlinedButton.icon(
            onPressed: () => context.go(AppRoutes.dashboard),
            icon: const Icon(Icons.dashboard_outlined),
            label: const Text('Back to dashboard'),
          ),
        ],
      );
    }

    final workspace = _workspaceSnapshot!;
    final adminAlerts = communicationService.adminAlertMessages.reversed
        .take(4)
        .toList(growable: false);

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
                  title: 'Admin Alerts',
                  subtitle:
                      'School-wide notices, deadlines, and urgent operational changes stay visible here first.',
                ),
                const SizedBox(height: 16),
                if (adminAlerts.isEmpty)
                  _CommunicationInfoBanner(
                    icon: Icons.campaign_outlined,
                    title: RepositoryFactory.isUsingFirestore
                        ? 'No active school-wide alerts'
                        : 'Turn on cloud sync for shared staff alerts',
                    subtitle: RepositoryFactory.isUsingFirestore
                        ? 'Announcements will appear here as soon as they are posted from the admin workspace.'
                        : 'This workspace is ready locally now. Shared alerts become real school communication once cloud sync is enabled.',
                  )
                else
                  Column(
                    children: [
                      for (final alert in adminAlerts)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _CommunicationListTile(
                            icon: _severityIcon(alert.severity),
                            accent: _severityColor(context, alert.severity),
                            title: alert.text,
                            subtitle:
                                '${alert.authorName} - ${_messageTimeLabel(alert.createdAt)}',
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
                  title: 'Teacher Channels',
                  subtitle:
                      'All-staff, teaching-team, and custom staff groups now work as real destinations with messages behind them.',
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final channel in communicationService.channels)
                      SizedBox(
                        width: 290,
                        child: _CommunicationChannelCard(
                          channel: channel,
                          cloudReady: RepositoryFactory.isUsingFirestore,
                          unreadCount:
                              communicationService.unreadCountForChannel(
                            channel.channelId,
                          ),
                          selected:
                              communicationService.selectedChannel?.channelId ==
                                  channel.channelId,
                          onTap: () => communicationService
                              .selectChannel(channel.channelId),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                _CommunicationThreadPanel(
                  currentUserId: workspace.user.userId,
                  channel: communicationService.selectedChannel,
                  messages: communicationService.selectedMessages,
                  sending: communicationService.isSending,
                  onSend: communicationService.sendMessage,
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
                  title: 'Connected Workflow',
                  subtitle:
                      'Communication now shares the same teacher context as the rest of the app instead of sitting beside it as a disconnected panel.',
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: 320,
                      child: _CommunicationListTile(
                        icon: Icons.folder_shared_outlined,
                        accent: Theme.of(context).colorScheme.primary,
                        title: 'Shared files and pinned resources',
                        subtitle:
                            'Channel structure is now ready for attachment and file-sharing support in the next communication pass.',
                      ),
                    ),
                    SizedBox(
                      width: 320,
                      child: _CommunicationListTile(
                        icon: Icons.schedule_send_outlined,
                        accent: Theme.of(context).colorScheme.tertiary,
                        title:
                            '${workspace.pendingReminders.length} planning items',
                        subtitle:
                            'Personal planning already feeds the daily coordination picture for the teacher workspace.',
                      ),
                    ),
                    SizedBox(
                      width: 320,
                      child: _CommunicationListTile(
                        icon: Icons.school_outlined,
                        accent: Theme.of(context).colorScheme.secondary,
                        title:
                            '${workspace.activeClasses.length} teaching spaces linked',
                        subtitle:
                            'Teaching workflow and school coordination now reference the same workspace state.',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _messageTimeLabel(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    return '${timestamp.month}/${timestamp.day}';
  }

  IconData _severityIcon(CommunicationAlertSeverity severity) {
    switch (severity) {
      case CommunicationAlertSeverity.urgent:
        return Icons.priority_high_rounded;
      case CommunicationAlertSeverity.attention:
        return Icons.notification_important_outlined;
      case CommunicationAlertSeverity.info:
        return Icons.campaign_outlined;
    }
  }

  Color _severityColor(
    BuildContext context,
    CommunicationAlertSeverity severity,
  ) {
    switch (severity) {
      case CommunicationAlertSeverity.urgent:
        return Theme.of(context).colorScheme.error;
      case CommunicationAlertSeverity.attention:
        return const Color(0xFFE3A23B);
      case CommunicationAlertSeverity.info:
        return Theme.of(context).colorScheme.primary;
    }
  }
}

class _CommunicationChannelCard extends StatelessWidget {
  final CommunicationChannelRecord channel;
  final bool cloudReady;
  final int unreadCount;
  final bool selected;
  final VoidCallback onTap;

  const _CommunicationChannelCard({
    required this.channel,
    required this.cloudReady,
    required this.unreadCount,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = _accentForKind(context, channel.kind);
    return WorkspaceSurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: accent.withValues(alpha: 0.16),
                ),
                child: Icon(_iconForKind(channel.kind), color: accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  channel.name,
                  style: context.textStyles.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (unreadCount > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: accent.withValues(alpha: 0.18),
                  ),
                  child: Text(
                    '$unreadCount new',
                    style: context.textStyles.labelSmall?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              else if (selected)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: accent.withValues(alpha: 0.18),
                  ),
                  child: Text(
                    'Selected',
                    style: context.textStyles.labelSmall?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '${channel.memberCount} participants',
            style: context.textStyles.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            channel.lastMessagePreview?.trim().isNotEmpty ?? false
                ? '${channel.lastSenderName ?? channel.name}: ${channel.lastMessagePreview}'
                : channel.description,
            style: context.textStyles.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          Text(
            channel.readOnly
                ? 'Posted from Admin workspace'
                : cloudReady
                    ? 'Live for shared staff messaging'
                    : 'Works locally now and can expand to live school sync',
            style: context.textStyles.labelMedium?.copyWith(
              color: accent,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForKind(CommunicationChannelKind kind) {
    switch (kind) {
      case CommunicationChannelKind.adminAlerts:
        return Icons.campaign_outlined;
      case CommunicationChannelKind.staffRoom:
        return Icons.groups_rounded;
      case CommunicationChannelKind.department:
        return Icons.forum_outlined;
      case CommunicationChannelKind.gradeTeam:
        return Icons.hub_outlined;
      case CommunicationChannelKind.direct:
        return Icons.chat_bubble_outline_rounded;
      case CommunicationChannelKind.sharedFiles:
        return Icons.folder_shared_outlined;
    }
  }

  Color _accentForKind(BuildContext context, CommunicationChannelKind kind) {
    switch (kind) {
      case CommunicationChannelKind.adminAlerts:
        return Theme.of(context).colorScheme.error;
      case CommunicationChannelKind.staffRoom:
        return Theme.of(context).colorScheme.primary;
      case CommunicationChannelKind.department:
        return Theme.of(context).colorScheme.tertiary;
      case CommunicationChannelKind.gradeTeam:
        return const Color(0xFF9A7BFF);
      case CommunicationChannelKind.direct:
        return const Color(0xFF52B788);
      case CommunicationChannelKind.sharedFiles:
        return const Color(0xFFE08F3E);
    }
  }
}

class _CommunicationInfoBanner extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _CommunicationInfoBanner({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return WorkspaceSurfaceCard(
      padding: const EdgeInsets.all(16),
      radius: 20,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.14),
            ),
            child: Icon(icon, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
        ],
      ),
    );
  }
}

class _CommunicationListTile extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;

  const _CommunicationListTile({
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.35),
        ),
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.34),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: accent.withValues(alpha: 0.16),
            ),
            child: Icon(icon, color: accent, size: 20),
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
      ),
    );
  }
}

class _CommunicationThreadPanel extends StatefulWidget {
  final String currentUserId;
  final CommunicationChannelRecord? channel;
  final List<CommunicationMessage> messages;
  final bool sending;
  final Future<void> Function(String text) onSend;

  const _CommunicationThreadPanel({
    required this.currentUserId,
    required this.channel,
    required this.messages,
    required this.sending,
    required this.onSend,
  });

  @override
  State<_CommunicationThreadPanel> createState() =>
      _CommunicationThreadPanelState();
}

class _CommunicationThreadPanelState extends State<_CommunicationThreadPanel> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleSend() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      return;
    }
    _controller.clear();
    await widget.onSend(text);
  }

  @override
  Widget build(BuildContext context) {
    final channel = widget.channel;
    if (channel == null) {
      return const _CommunicationInfoBanner(
        icon: Icons.chat_bubble_outline_rounded,
        title: 'Choose a channel',
        subtitle:
            'Select a staff lane above to review messages and start the conversation.',
      );
    }

    return WorkspaceSurfaceCard(
      padding: const EdgeInsets.all(18),
      radius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WorkspaceSectionHeader(
            title: channel.name,
            subtitle: channel.description,
          ),
          const SizedBox(height: 16),
          Container(
            height: 320,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .outline
                    .withValues(alpha: 0.28),
              ),
              color:
                  Theme.of(context).colorScheme.surface.withValues(alpha: 0.22),
            ),
            child: widget.messages.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        channel.readOnly
                            ? 'Admin alerts posted from the Admin workspace will appear here.'
                            : 'No messages yet. Start the first conversation for this channel.',
                        style: context.textStyles.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemBuilder: (context, index) {
                      final message = widget.messages[index];
                      final ownMessage =
                          message.authorId == widget.currentUserId;
                      return Align(
                        alignment: ownMessage
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 560),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              color: ownMessage
                                  ? Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withValues(alpha: 0.18)
                                  : Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest
                                      .withValues(alpha: 0.34),
                              border: Border.all(
                                color: ownMessage
                                    ? Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withValues(alpha: 0.32)
                                    : Theme.of(context)
                                        .colorScheme
                                        .outline
                                        .withValues(alpha: 0.22),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          message.authorName,
                                          style: context.textStyles.labelLarge
                                              ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(999),
                                          color: _roleAccent(
                                            context,
                                            message.authorRole,
                                          ).withValues(alpha: 0.14),
                                        ),
                                        child: Text(
                                          _roleLabel(message.authorRole),
                                          style: context.textStyles.labelSmall
                                              ?.copyWith(
                                            color: _roleAccent(
                                              context,
                                              message.authorRole,
                                            ),
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    message.text,
                                    style:
                                        context.textStyles.bodyMedium?.copyWith(
                                      height: 1.45,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _threadTimeLabel(message.createdAt),
                                    style:
                                        context.textStyles.labelSmall?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemCount: widget.messages.length,
                  ),
          ),
          const SizedBox(height: 14),
          if (channel.readOnly)
            const _CommunicationInfoBanner(
              icon: Icons.campaign_outlined,
              title: 'Admin alerts are posted from the Admin workspace',
              subtitle:
                  'Use the Admin area to publish school-wide notices, deadlines, and urgent updates into this channel.',
            )
          else
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _handleSend(),
                    decoration: const InputDecoration(
                      hintText: 'Write a message to this channel',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: widget.sending ? null : _handleSend,
                  icon: widget.sending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                  label: const Text('Send'),
                ),
              ],
            ),
        ],
      ),
    );
  }

  String _threadTimeLabel(DateTime createdAt) {
    final hour = createdAt.hour == 0
        ? 12
        : (createdAt.hour > 12 ? createdAt.hour - 12 : createdAt.hour);
    final minute = createdAt.minute.toString().padLeft(2, '0');
    final period = createdAt.hour >= 12 ? 'PM' : 'AM';
    return '${createdAt.month}/${createdAt.day} - $hour:$minute $period';
  }

  String _roleLabel(CommunicationRole role) {
    switch (role) {
      case CommunicationRole.admin:
        return 'Admin';
      case CommunicationRole.departmentLead:
        return 'Lead';
      case CommunicationRole.teacher:
        return 'Teacher';
    }
  }

  Color _roleAccent(BuildContext context, CommunicationRole role) {
    switch (role) {
      case CommunicationRole.admin:
        return Theme.of(context).colorScheme.error;
      case CommunicationRole.departmentLead:
        return Theme.of(context).colorScheme.tertiary;
      case CommunicationRole.teacher:
        return Theme.of(context).colorScheme.primary;
    }
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:gradeflow/components/command_surface.dart';
import 'package:gradeflow/components/tool_first_app_surface.dart';
import 'package:gradeflow/components/workspace_shell.dart';
import 'package:gradeflow/models/communication_models.dart';
import 'package:gradeflow/nav.dart';
import 'package:gradeflow/services/auth_service.dart';
import 'package:gradeflow/services/communication_service.dart';
import 'package:gradeflow/theme.dart';

class CommunicationHubScreen extends StatefulWidget {
  const CommunicationHubScreen({super.key});

  @override
  State<CommunicationHubScreen> createState() => _CommunicationHubScreenState();
}

class _CommunicationHubScreenState extends State<CommunicationHubScreen> {
  bool _loading = true;
  String? _error;

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
      if (!mounted) return;
      await context.read<CommunicationService>().load();
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
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
            return WorkspaceDialogScaffold(
              title: 'Create staff group',
              subtitle:
                  'Open a shared staff space for planning, team updates, or shared resources.',
              icon: Icons.add_circle_outline_rounded,
              body: SizedBox(
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
                        hintText: 'English team, Grade 8 support',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Purpose',
                        hintText: 'Explain what this group is for',
                      ),
                    ),
                    const SizedBox(height: 12),
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
                  style: WorkspaceButtonStyles.text(dialogContext),
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
                          _showMessage(
                            created
                                ? 'Staff group created.'
                                : 'Could not create that group yet.',
                            tone: created
                                ? WorkspaceFeedbackTone.success
                                : WorkspaceFeedbackTone.error,
                            title:
                                created ? 'Group created' : 'Group not saved',
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
                  style: WorkspaceButtonStyles.filled(dialogContext),
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

  void _showMessage(
    String message, {
    WorkspaceFeedbackTone tone = WorkspaceFeedbackTone.info,
    String? title,
  }) {
    showWorkspaceSnackBar(
      context,
      message: message,
      tone: tone,
      title: title,
    );
  }

  @override
  Widget build(BuildContext context) {
    final communicationService = context.watch<CommunicationService>();

    return ToolFirstAppSurface(
      header: _buildMessagesHeader(context, communicationService),
      eyebrow: 'Support surface',
      title: 'Messages',
      subtitle:
          'Staff coordination, admin notices, and shared updates in one secondary support space.',
      contextStrip: _MessagesContextBar(
        unreadCount: communicationService.totalUnreadCount,
        channelCount: communicationService.channelCount,
        activityCount: communicationService.activityCount,
        onRefresh: _load,
      ),
      workspace: _buildSplitViewWorkspace(context, communicationService),
    );
  }

  Widget _buildMessagesHeader(
    BuildContext context,
    CommunicationService communicationService,
  ) {
    return CommandHeader(
      eyebrow: 'Support surface',
      title: 'Messages',
      subtitle:
          'Staff coordination, admin notices, and shared updates in one secondary support space.',
      leading: IconButton(
        onPressed: () => context.go(AppRoutes.osHome),
        icon: const Icon(Icons.arrow_back_rounded),
        tooltip: 'Back to OS home',
        style: WorkspaceButtonStyles.icon(context),
      ),
      primaryAction: FilledButton.icon(
        onPressed: () => _showCreateGroupDialog(context),
        icon: const Icon(Icons.add_circle_outline_rounded),
        label: const Text('Create group'),
        style: WorkspaceButtonStyles.filled(context),
      ),
      contextPills: [
        WorkspaceContextPill(
          icon: Icons.mark_chat_unread_outlined,
          label: 'Unread',
          value: communicationService.totalUnreadCount.toString(),
          emphasized: communicationService.totalUnreadCount > 0,
        ),
        WorkspaceContextPill(
          icon: Icons.forum_outlined,
          label: 'Channels',
          value: communicationService.channelCount.toString(),
        ),
        WorkspaceContextPill(
          icon: Icons.bolt_outlined,
          label: 'Today',
          value: '${communicationService.activityCount} active',
          accent: Theme.of(context).colorScheme.tertiary,
        ),
      ],
      pulseTone: CommandPulseTone.calm,
      pulseLabel: 'Shared staff coordination live',
    );
  }

  Widget _buildSplitViewWorkspace(
    BuildContext context,
    CommunicationService communicationService,
  ) {
    if (_loading || communicationService.isLoading) {
      return const WorkspaceLoadingState(
        title: 'Loading messages',
        subtitle:
            'Syncing staff channels, alerts, and recent conversation context.',
      );
    }

    final activeError = _error ?? communicationService.error;
    if (activeError != null) {
      return WorkspaceEmptyState(
        icon: Icons.forum_outlined,
        title: 'Messages are not ready',
        subtitle: activeError,
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final hasSplitView = constraints.maxWidth >= 900;

        final threadList = _buildThreadList(context, communicationService);
        final threadPanel = _buildThreadPanel(context, communicationService);

        if (!hasSplitView) {
          final selected = communicationService.selectedChannel != null;
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              children: [
                if (!selected)
                  Expanded(child: threadList)
                else ...[
                  SizedBox(height: 220, child: threadList),
                  const SizedBox(height: 12),
                  Expanded(child: threadPanel),
                ],
              ],
            ),
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 332,
              child: threadList,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: threadPanel,
            ),
          ],
        );
      },
    );
  }

  Widget _buildThreadList(
    BuildContext context,
    CommunicationService communicationService,
  ) {
    return CommandSurfaceCard(
      surfaceType: SurfaceType.tool,
      padding: const EdgeInsets.all(14),
      radius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WorkspaceSectionHeader(
            title: 'Staff channels',
            subtitle:
                'Monitor shared alerts, staff coordination, and team spaces from one support lane.',
            action: TextButton.icon(
              onPressed: () => _showCreateGroupDialog(context),
              icon: const Icon(Icons.add_circle_outline_rounded),
              label: const Text('New group'),
              style: WorkspaceButtonStyles.text(context, compact: true),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: communicationService.channels.isEmpty
                ? Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 280),
                      child: WorkspaceInlineState(
                        icon: Icons.forum_outlined,
                        title: 'No staff groups yet',
                        subtitle:
                            'Create a shared channel to begin staff coordination or publish updates.',
                        action: FilledButton.icon(
                          onPressed: () => _showCreateGroupDialog(context),
                          icon: const Icon(Icons.add_circle_outline_rounded),
                          label: const Text('Create group'),
                          style: WorkspaceButtonStyles.filled(context),
                        ),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: communicationService.channels.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final channel = communicationService.channels[index];
                      return _CommunicationChannelCard(
                        channel: channel,
                        unreadCount: communicationService.unreadCountForChannel(
                          channel.channelId,
                        ),
                        selected:
                            communicationService.selectedChannel?.channelId ==
                                channel.channelId,
                        onTap: () => communicationService
                            .selectChannel(channel.channelId),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildThreadPanel(
    BuildContext context,
    CommunicationService communicationService,
  ) {
    final channel = communicationService.selectedChannel;
    if (channel == null) {
      return CommandSurfaceCard(
        surfaceType: SurfaceType.stage,
        padding: EdgeInsets.all(16),
        radius: 22,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 320),
            child: WorkspaceInlineState(
              icon: Icons.chat_bubble_outline_rounded,
              title: 'Select a channel',
              subtitle:
                  'Choose a staff space to review updates, alerts, and recent messages.',
            ),
          ),
        ),
      );
    }

    return _CommunicationThreadPanel(
      currentUserId: context.read<AuthService>().currentUser?.userId ?? '',
      channel: channel,
      messages: communicationService.selectedMessages,
      sending: communicationService.isSending,
      onSend: communicationService.sendMessage,
      onRefresh: _load,
    );
  }
}

class _MessagesContextBar extends StatelessWidget {
  final int unreadCount;
  final int channelCount;
  final int activityCount;
  final VoidCallback onRefresh;

  const _MessagesContextBar({
    required this.unreadCount,
    required this.channelCount,
    required this.activityCount,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final summary =
        '$unreadCount unread across $channelCount channels • $activityCount active today';
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 760;
        final copy = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Shared staff communication',
              style: context.textStyles.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.1,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              summary,
              style: context.textStyles.bodySmall?.copyWith(
                color: WorkspaceChrome.mutedText(context),
                height: 1.35,
              ),
            ),
          ],
        );
        final refresh = OutlinedButton.icon(
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Refresh'),
          style: WorkspaceButtonStyles.outlined(context, compact: true),
        );

        if (narrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              copy,
              const SizedBox(height: 10),
              refresh,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: copy),
            const SizedBox(width: 12),
            refresh,
          ],
        );
      },
    );
  }
}

class _CommunicationMetaPill extends StatelessWidget {
  const _CommunicationMetaPill({
    required this.label,
    required this.accent,
    this.icon,
  });

  final String label;
  final Color accent;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: accent.withValues(alpha: 0.12),
        border: Border.all(
          color: accent.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: accent),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: context.textStyles.labelSmall?.copyWith(
              color: accent,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.18,
            ),
          ),
        ],
      ),
    );
  }
}

class _CommunicationChannelCard extends StatelessWidget {
  final CommunicationChannelRecord channel;
  final int unreadCount;
  final bool selected;
  final VoidCallback onTap;

  const _CommunicationChannelCard({
    required this.channel,
    required this.unreadCount,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = _accentForKind(context, channel.kind);
    final footerLabel = channel.readOnly
        ? 'Read only'
        : '${channel.memberCount} member${channel.memberCount == 1 ? '' : 's'}';
    final preview = (channel.lastMessagePreview?.trim().isNotEmpty ?? false)
        ? channel.lastMessagePreview!.trim()
        : (channel.description.trim().isNotEmpty
            ? channel.description.trim()
            : 'Shared updates stay visible here.');
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        hoverColor: accent.withValues(alpha: 0.06),
        focusColor: accent.withValues(alpha: 0.06),
        highlightColor: accent.withValues(alpha: 0.12),
        splashColor: accent.withValues(alpha: 0.14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                selected
                    ? accent.withValues(alpha: 0.16)
                    : theme.colorScheme.surface.withValues(alpha: 0.34),
                selected
                    ? accent.withValues(alpha: 0.08)
                    : theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.18),
              ],
            ),
            border: Border.all(
              color: selected
                  ? accent.withValues(alpha: 0.34)
                  : theme.colorScheme.outline.withValues(alpha: 0.18),
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: accent.withValues(alpha: 0.16),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.20),
                      ),
                    ),
                    child: Icon(_iconForKind(channel.kind),
                        color: accent, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          channel.name,
                          style: context.textStyles.labelLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _channelKindLabel(channel.kind),
                          style: context.textStyles.labelSmall?.copyWith(
                            color: accent,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.18,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (unreadCount > 0)
                    _CommunicationMetaPill(
                      label: '$unreadCount new',
                      accent: accent,
                      icon: Icons.mark_chat_unread_outlined,
                    )
                  else if (selected)
                    _CommunicationMetaPill(
                      label: 'Open',
                      accent: accent,
                      icon: Icons.check_circle_rounded,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                preview,
                style: context.textStyles.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    footerLabel,
                    style: context.textStyles.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  if (selected)
                    Text(
                      'Selected lane',
                      style: context.textStyles.labelSmall?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
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

  String _channelKindLabel(CommunicationChannelKind kind) {
    switch (kind) {
      case CommunicationChannelKind.adminAlerts:
        return 'Admin alerts';
      case CommunicationChannelKind.staffRoom:
        return 'Staff room';
      case CommunicationChannelKind.department:
        return 'Department';
      case CommunicationChannelKind.gradeTeam:
        return 'Grade team';
      case CommunicationChannelKind.direct:
        return 'Direct';
      case CommunicationChannelKind.sharedFiles:
        return 'Shared files';
    }
  }
}

class _CommunicationThreadPanel extends StatefulWidget {
  final String currentUserId;
  final CommunicationChannelRecord? channel;
  final List<CommunicationMessage> messages;
  final bool sending;
  final Future<void> Function(String text) onSend;
  final VoidCallback onRefresh;

  const _CommunicationThreadPanel({
    required this.currentUserId,
    required this.channel,
    required this.messages,
    required this.sending,
    required this.onSend,
    required this.onRefresh,
  });

  @override
  State<_CommunicationThreadPanel> createState() =>
      _CommunicationThreadPanelState();
}

class _CommunicationThreadPanelState extends State<_CommunicationThreadPanel> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _composerFocusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _composerFocusNode.dispose();
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

  void _focusComposer() {
    if (!mounted) return;
    _composerFocusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final channel = widget.channel;
    if (channel == null) {
      return CommandSurfaceCard(
        surfaceType: SurfaceType.stage,
        padding: EdgeInsets.all(16),
        radius: 22,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 320),
            child: WorkspaceInlineState(
              icon: Icons.chat_bubble_outline_rounded,
              title: 'Choose a channel',
              subtitle:
                  'Pick a staff space to review updates and conversation history.',
            ),
          ),
        ),
      );
    }

    final accent = _channelAccent(context, channel.kind);

    return CommandSurfaceCard(
      surfaceType: SurfaceType.stage,
      padding: EdgeInsets.zero,
      radius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 15, 16, 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accent.withValues(alpha: 0.08),
                  Theme.of(context).colorScheme.surface.withValues(alpha: 0.06),
                ],
              ),
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context)
                      .colorScheme
                      .outline
                      .withValues(alpha: 0.12),
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: accent.withValues(alpha: 0.16),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.22),
                        ),
                      ),
                      child: Icon(
                        _iconForKind(channel.kind),
                        size: 20,
                        color: accent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            channel.name,
                            style: context.textStyles.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            channel.description.trim().isNotEmpty
                                ? channel.description
                                : 'Shared staff updates with ${channel.memberCount} participants.',
                            style: context.textStyles.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              height: 1.35,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _CommunicationMetaPill(
                      label: _channelKindLabel(channel.kind),
                      accent: accent,
                      icon: _iconForKind(channel.kind),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    WorkspaceContextPill(
                      icon: Icons.people_alt_outlined,
                      label: 'Members',
                      value: '${channel.memberCount}',
                      accent: accent,
                    ),
                    WorkspaceContextPill(
                      icon: channel.readOnly
                          ? Icons.lock_outline_rounded
                          : Icons.edit_outlined,
                      label: 'Posting',
                      value: channel.readOnly ? 'Read only' : 'Open',
                      accent: channel.readOnly
                          ? Theme.of(context).colorScheme.error
                          : Theme.of(context).colorScheme.primary,
                    ),
                    _CommunicationMetaPill(
                      label:
                          channel.readOnly ? 'Broadcast lane' : 'Reply ready',
                      accent: channel.readOnly
                          ? Theme.of(context).colorScheme.error
                          : accent,
                      icon: channel.readOnly
                          ? Icons.campaign_outlined
                          : Icons.reply_rounded,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (!channel.readOnly)
                      OutlinedButton.icon(
                        onPressed: _focusComposer,
                        icon: const Icon(Icons.reply_rounded),
                        label: const Text('Write update'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: accent,
                          side: BorderSide(
                            color: accent.withValues(alpha: 0.24),
                          ),
                        ),
                      ),
                    OutlinedButton.icon(
                      onPressed: widget.onRefresh,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Refresh'),
                      style: WorkspaceButtonStyles.outlined(
                        context,
                        compact: true,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: widget.messages.isEmpty
                ? Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 320),
                      child: WorkspaceInlineState(
                        icon: channel.readOnly
                            ? Icons.campaign_outlined
                            : Icons.chat_bubble_outline_rounded,
                        title: channel.readOnly
                            ? 'Admin alerts appear here'
                            : 'No messages yet',
                        subtitle: channel.readOnly
                            ? 'School-wide notices will collect here as they are posted.'
                            : 'This shared space is ready for the first update.',
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(14),
                    itemCount: widget.messages.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final message = widget.messages[index];
                      final ownMessage =
                          message.authorId == widget.currentUserId;
                      return Align(
                        alignment: ownMessage
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 520),
                          child: _buildMessageBubble(
                            context,
                            message,
                            ownMessage: ownMessage,
                            accent: accent,
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (!channel.readOnly)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context)
                        .colorScheme
                        .outline
                        .withValues(alpha: 0.12),
                  ),
                ),
              ),
              child: _buildComposer(
                context,
                accent: accent,
                channel: channel,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(
    BuildContext context,
    CommunicationMessage message, {
    required bool ownMessage,
    required Color accent,
  }) {
    final bubbleAccent =
        ownMessage ? accent : _roleAccent(context, message.authorRole);
    final theme = Theme.of(context);
    final bubbleRadius = BorderRadius.only(
      topLeft: const Radius.circular(20),
      topRight: const Radius.circular(20),
      bottomLeft: Radius.circular(ownMessage ? 20 : 8),
      bottomRight: Radius.circular(ownMessage ? 8 : 20),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: bubbleRadius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: ownMessage
              ? [
                  bubbleAccent.withValues(alpha: 0.20),
                  bubbleAccent.withValues(alpha: 0.10),
                ]
              : [
                  theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.44),
                  bubbleAccent.withValues(alpha: 0.08),
                ],
        ),
        border: Border.all(
          color: ownMessage
              ? bubbleAccent.withValues(alpha: 0.28)
              : bubbleAccent.withValues(alpha: 0.16),
        ),
        boxShadow: [
          BoxShadow(
            color: bubbleAccent.withValues(alpha: ownMessage ? 0.10 : 0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 11, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    message.authorName,
                    style: context.textStyles.labelMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                _CommunicationMetaPill(
                  label: _roleLabel(message.authorRole),
                  accent: _roleAccent(context, message.authorRole),
                ),
                const SizedBox(width: 8),
                Text(
                  _messageTimeLabel(message.createdAt),
                  style: context.textStyles.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              message.text,
              style: context.textStyles.bodySmall?.copyWith(
                height: 1.48,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComposer(
    BuildContext context, {
    required Color accent,
    required CommunicationChannelRecord channel,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _CommunicationMetaPill(
              label: 'Posting open',
              accent: accent,
              icon: Icons.edit_outlined,
            ),
            Text(
              'Updates stay inside ${channel.name}.',
              style: context.textStyles.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.colorScheme.surface.withValues(alpha: 0.46),
                accent.withValues(alpha: 0.08),
              ],
            ),
            border: Border.all(
              color: accent.withValues(alpha: 0.18),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: accent.withValues(alpha: 0.14),
                ),
                child: Icon(
                  Icons.mode_comment_outlined,
                  size: 18,
                  color: accent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _composerFocusNode,
                  decoration: InputDecoration(
                    hintText: 'Write an update for ${channel.name}...',
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  textInputAction: TextInputAction.send,
                  onSubmitted: widget.sending ? null : (_) => _handleSend(),
                  enabled: !widget.sending,
                  minLines: 1,
                  maxLines: 4,
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: widget.sending ? null : _handleSend,
                icon: widget.sending
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(
                            theme.colorScheme.onPrimary,
                          ),
                        ),
                      )
                    : const Icon(Icons.send_rounded),
                label: const Text('Send'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _messageTimeLabel(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    if (difference.inMinutes < 1) return 'just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    return '${timestamp.month}/${timestamp.day}';
  }

  Color _roleAccent(BuildContext context, CommunicationRole role) {
    switch (role) {
      case CommunicationRole.admin:
        return Theme.of(context).colorScheme.error;
      case CommunicationRole.departmentLead:
        return Theme.of(context).colorScheme.primary;
      case CommunicationRole.teacher:
        return Theme.of(context).colorScheme.tertiary;
    }
  }

  String _roleLabel(CommunicationRole role) {
    switch (role) {
      case CommunicationRole.admin:
        return 'Admin';
      case CommunicationRole.departmentLead:
        return 'Department Lead';
      case CommunicationRole.teacher:
        return 'Teacher';
    }
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

  Color _channelAccent(BuildContext context, CommunicationChannelKind kind) {
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

  String _channelKindLabel(CommunicationChannelKind kind) {
    switch (kind) {
      case CommunicationChannelKind.adminAlerts:
        return 'Admin alerts';
      case CommunicationChannelKind.staffRoom:
        return 'Staff room';
      case CommunicationChannelKind.department:
        return 'Department';
      case CommunicationChannelKind.gradeTeam:
        return 'Grade team';
      case CommunicationChannelKind.direct:
        return 'Direct';
      case CommunicationChannelKind.sharedFiles:
        return 'Shared files';
    }
  }
}

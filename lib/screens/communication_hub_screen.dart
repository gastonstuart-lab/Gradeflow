import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:gradeflow/components/tool_first_app_surface.dart';
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
                      value: kind,
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
                          _showMessage(
                            created
                                ? 'Staff group created.'
                                : 'Could not create that group yet.',
                            isError: !created,
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

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final communicationService = context.watch<CommunicationService>();

    return ToolFirstAppSurface(
      title: 'Messages',
      subtitle: 'Staff coordination and school updates',
      leading: IconButton(
        onPressed: () => context.go(AppRoutes.dashboard),
        icon: const Icon(Icons.arrow_back_rounded),
        tooltip: 'Back to dashboard',
      ),
      trailing: [
        IconButton(
          tooltip: 'Compose new group',
          icon: const Icon(Icons.add_circle_outline_rounded),
          onPressed: () => _showCreateGroupDialog(context),
        ),
        IconButton(
          tooltip: 'Refresh messages',
          icon: const Icon(Icons.refresh_rounded),
          onPressed: _load,
        ),
      ],
      contextStrip: _CompactMessagesContextStrip(
        unreadCount: communicationService.totalUnreadCount,
        channelCount: communicationService.channelCount,
        filterMode: 'All',
      ),
      toolbar: _CompactMessagesToolbar(
        onCompose: () => _showCreateGroupDialog(context),
        onRefresh: _load,
      ),
      workspace: _buildSplitViewWorkspace(context, communicationService),
    );
  }

  Widget _buildSplitViewWorkspace(
    BuildContext context,
    CommunicationService communicationService,
  ) {
    if (_loading || communicationService.isLoading) {
      return const Center(
        child: SizedBox(
          width: 200,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading messages…'),
            ],
          ),
        ),
      );
    }

    final activeError = _error ?? communicationService.error;
    if (activeError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.forum_outlined,
                  size: 64,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(height: 16),
              Text('Messages not ready',
                  style: context.textStyles.titleLarge),
              const SizedBox(height: 8),
              Text(activeError, style: context.textStyles.bodyMedium),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final hasSplitView = constraints.maxWidth >= 900;

        final threadList = _buildThreadList(context, communicationService);
        final threadPanel =
            _buildThreadPanel(context, communicationService);

        if (!hasSplitView) {
          // Mobile/narrow: show list OR detail, not both
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: communicationService.selectedChannel == null
                ? threadList
                : threadPanel,
          );
        }

        // Desktop/wide: split view
        return Row(
          children: [
            // Left panel: thread list (narrow)
            SizedBox(
              width: 300,
              child: threadList,
            ),
            const SizedBox(width: 12),
            // Right panel: thread detail (expanding)
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
    if (communicationService.channels.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.forum_outlined,
                  size: 48,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(height: 12),
              Text('No channels yet',
                  style: context.textStyles.bodyMedium),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => _showCreateGroupDialog(context),
                icon: const Icon(Icons.add),
                label: const Text('Create group'),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context)
              .colorScheme
              .outline
              .withValues(alpha: 0.24),
        ),
        color: Theme.of(context)
            .colorScheme
            .surface
            .withValues(alpha: 0.3),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.all(8),
        itemCount: communicationService.channels.length,
        separatorBuilder: (_, __) => const SizedBox(height: 4),
        itemBuilder: (context, index) {
          final channel = communicationService.channels[index];
          return _CommunicationChannelCard(
            channel: channel,
            unreadCount: communicationService.unreadCountForChannel(
              channel.channelId,
            ),
            selected: communicationService.selectedChannel?.channelId ==
                channel.channelId,
            onTap: () =>
                communicationService.selectChannel(channel.channelId),
          );
        },
      ),
    );
  }

  Widget _buildThreadPanel(
    BuildContext context,
    CommunicationService communicationService,
  ) {
    final channel = communicationService.selectedChannel;
    if (channel == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.chat_bubble_outline_rounded,
                  size: 48,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(height: 12),
              Text('Select a channel',
                  style: context.textStyles.bodyMedium),
            ],
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
    );
  }
}

class _CompactMessagesContextStrip extends StatelessWidget {
  final int unreadCount;
  final int channelCount;
  final String filterMode;

  const _CompactMessagesContextStrip({
    required this.unreadCount,
    required this.channelCount,
    required this.filterMode,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _ContextChip(
            icon: Icons.mark_chat_unread_outlined,
            label: 'Unread',
            value: unreadCount.toString(),
          ),
          const SizedBox(width: 8),
          _ContextChip(
            icon: Icons.forum_outlined,
            label: 'Channels',
            value: channelCount.toString(),
          ),
          const SizedBox(width: 8),
          _ContextChip(
            icon: Icons.filter_list,
            label: 'View',
            value: filterMode,
          ),
        ],
      ),
    );
  }
}

class _ContextChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ContextChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: scheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            '$label: $value',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactMessagesToolbar extends StatelessWidget {
  final VoidCallback onCompose;
  final VoidCallback onRefresh;

  const _CompactMessagesToolbar({
    required this.onCompose,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          Tooltip(
            message: 'Create new group',
            child: IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded),
              onPressed: onCompose,
            ),
          ),
          Tooltip(
            message: 'Refresh messages',
            child: IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: onRefresh,
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: selected
                ? accent.withValues(alpha: 0.14)
                : theme.colorScheme.surface.withValues(alpha: 0.22),
            border: Border.all(
              color: selected
                  ? accent.withValues(alpha: 0.34)
                  : theme.colorScheme.outline.withValues(alpha: 0.18),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: accent.withValues(alpha: 0.16),
                    ),
                    child: Icon(_iconForKind(channel.kind),
                        color: accent, size: 16),
                  ),
                  const SizedBox(width: 8),
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
                        if (unreadCount > 0)
                          Text(
                            '$unreadCount unread',
                            style:
                                context.textStyles.labelSmall?.copyWith(
                              color: accent,
                              fontWeight: FontWeight.w700,
                            ),
                          )
                        else if (selected)
                          Icon(Icons.check_circle_rounded,
                              size: 14, color: accent),
                      ],
                    ),
                  ),
                ],
              ),
              if (channel.lastMessagePreview?.isNotEmpty ?? false)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    channel.lastMessagePreview ?? '',
                    style: context.textStyles.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
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
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.chat_bubble_outline_rounded,
                  size: 48,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(height: 12),
              Text('Choose a channel',
                  style: context.textStyles.bodyMedium),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context)
              .colorScheme
              .outline
              .withValues(alpha: 0.24),
        ),
        color: Theme.of(context)
            .colorScheme
            .surface
            .withValues(alpha: 0.3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thread header (channel name + info)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
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
                Text(
                  channel.name,
                  style: context.textStyles.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (channel.description.trim().isNotEmpty)
                  Text(
                    channel.description,
                    style: context.textStyles.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                else
                  Text(
                    '${channel.memberCount} participants',
                    style: context.textStyles.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),

          // Messages list (expanding)
          Expanded(
            child: widget.messages.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        channel.readOnly
                            ? 'Admin alerts will appear here.'
                            : 'No messages yet. Start the conversation!',
                        style: context.textStyles.bodyMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(14),
                    itemCount: widget.messages.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final message = widget.messages[index];
                      final ownMessage =
                          message.authorId == widget.currentUserId;
                      return Align(
                        alignment: ownMessage
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 500),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
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
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          message.authorName,
                                          style: context
                                              .textStyles.labelSmall
                                              ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
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
                                          style: context
                                              .textStyles.labelSmall
                                              ?.copyWith(
                                            color: _roleAccent(
                                              context,
                                              message.authorRole,
                                            ),
                                            fontWeight: FontWeight.w600,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    message.text,
                                    style: context.textStyles.bodySmall
                                        ?.copyWith(
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _messageTimeLabel(message.createdAt),
                                    style: context.textStyles.labelSmall
                                        ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
            ),

          // Send input (fixed at bottom)
          if (!channel.readOnly)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: 'Send a message…',
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      enabled: !widget.sending,
                      minLines: 1,
                      maxLines: 3,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: widget.sending
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(
                                Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          )
                        : const Icon(Icons.send_rounded),
                    onPressed: widget.sending ? null : _handleSend,
                    tooltip: 'Send message',
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
}

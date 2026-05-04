import 'package:flutter/material.dart';
import 'package:gradeflow/components/workspace_shell.dart';
import 'package:gradeflow/models/seating_layout.dart';
import 'package:gradeflow/services/seating_service.dart';
import 'package:gradeflow/theme.dart';

class SeatingToolbar extends StatelessWidget {
  final List<SeatingLayout> layouts;
  final String? activeLayoutId;
  final bool designMode;
  final VoidCallback onToggleDesignMode;
  final ValueChanged<String> onSelectLayout;
  final VoidCallback onAddLayout;
  final VoidCallback onDuplicateLayout;
  final ValueChanged<SeatingTemplateType> onApplyTemplate;
  final VoidCallback onAddRectTable;
  final VoidCallback onAddSquareTable;
  final VoidCallback onAddDesk;
  final VoidCallback onAddTeacherDesk;
  final VoidCallback onRenameLayout;
  final VoidCallback onClearRoom;
  final VoidCallback onDeleteLayout;
  final VoidCallback onRoomSettings;
  final VoidCallback onAutoAssign;
  final VoidCallback onShuffleSeating;
  final VoidCallback onClearAssignments;
  final VoidCallback onPickStudent;
  final VoidCallback onFullScreen;
  final bool showFullScreenButton;
  final VoidCallback? onOpenRoomSetups;
  final VoidCallback? onPreviewPdf;
  final VoidCallback? onPrint;
  final VoidCallback? onDownload;
  final bool webMode;

  const SeatingToolbar({
    super.key,
    required this.layouts,
    required this.activeLayoutId,
    required this.designMode,
    required this.onToggleDesignMode,
    required this.onSelectLayout,
    required this.onAddLayout,
    required this.onDuplicateLayout,
    required this.onApplyTemplate,
    required this.onAddRectTable,
    required this.onAddSquareTable,
    required this.onAddDesk,
    required this.onAddTeacherDesk,
    required this.onRenameLayout,
    required this.onClearRoom,
    required this.onDeleteLayout,
    required this.onRoomSettings,
    required this.onAutoAssign,
    required this.onShuffleSeating,
    required this.onClearAssignments,
    required this.onPickStudent,
    required this.onFullScreen,
    this.showFullScreenButton = true,
    this.onOpenRoomSetups,
    this.onPreviewPdf,
    this.onPrint,
    this.onDownload,
    this.webMode = true,
  });

  @override
  Widget build(BuildContext context) {
    final active = layouts.firstWhere(
      (l) => l.layoutId == activeLayoutId,
      orElse: () => layouts.isEmpty ? _emptyLayout : layouts.first,
    );

    return SizedBox(
      height: 42,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            SizedBox(
              width: 200,
              child: DropdownButtonFormField<String>(
                key: ValueKey(active.layoutId),
                initialValue: active.layoutId.isEmpty ? null : active.layoutId,
                isExpanded: true,
                decoration: _seatingToolbarFieldDecoration(context),
                items: [
                  for (final layout in layouts)
                    DropdownMenuItem(
                      value: layout.layoutId,
                      child: Text(
                        layout.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                selectedItemBuilder: (context) => [
                  for (final layout in layouts)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        layout.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) onSelectLayout(value);
                },
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: onAddLayout,
              icon: const Icon(Icons.add),
              label: const Text('New layout'),
              style: WorkspaceButtonStyles.filled(context, compact: true),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: onDuplicateLayout,
              icon: const Icon(Icons.copy),
              label: const Text('Duplicate'),
              style: WorkspaceButtonStyles.outlined(context, compact: true),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<_LayoutAction>(
              onSelected: (value) {
                switch (value) {
                  case _LayoutAction.rename:
                    onRenameLayout();
                    break;
                  case _LayoutAction.clearRoom:
                    onClearRoom();
                    break;
                  case _LayoutAction.delete:
                    onDeleteLayout();
                    break;
                  case _LayoutAction.roomSettings:
                    onRoomSettings();
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: _LayoutAction.rename,
                  child: Text('Rename layout'),
                ),
                const PopupMenuItem(
                  value: _LayoutAction.roomSettings,
                  child: Text('Room size'),
                ),
                const PopupMenuItem(
                  value: _LayoutAction.clearRoom,
                  child: Text('Clear room'),
                ),
                PopupMenuItem(
                  value: _LayoutAction.delete,
                  enabled: layouts.length > 1,
                  child: Text(
                    layouts.length > 1
                        ? 'Delete layout'
                        : 'Delete layout (keep at least one)',
                  ),
                ),
              ],
              child: const _ToolbarMenuButton(
                icon: Icons.settings_outlined,
                label: 'Layout',
              ),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<SeatingTemplateType>(
              onSelected: onApplyTemplate,
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: SeatingTemplateType.rows,
                  child: Text('Rows layout'),
                ),
                PopupMenuItem(
                  value: SeatingTemplateType.groups,
                  child: Text('Group tables'),
                ),
                PopupMenuItem(
                  value: SeatingTemplateType.exam,
                  child: Text('Exam layout'),
                ),
                PopupMenuItem(
                  value: SeatingTemplateType.currentClassroom,
                  child: Text('Current classroom'),
                ),
              ],
              child: const _ToolbarMenuButton(
                icon: Icons.auto_fix_high_outlined,
                label: 'Templates',
              ),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<_AssignmentAction>(
              onSelected: (value) {
                switch (value) {
                  case _AssignmentAction.autoAssign:
                    onAutoAssign();
                    break;
                  case _AssignmentAction.shuffleSeating:
                    onShuffleSeating();
                    break;
                  case _AssignmentAction.clearAssignments:
                    onClearAssignments();
                    break;
                  case _AssignmentAction.pickStudent:
                    onPickStudent();
                    break;
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: _AssignmentAction.autoAssign,
                  child: Text('Auto-fill from roster'),
                ),
                PopupMenuItem(
                  value: _AssignmentAction.shuffleSeating,
                  child: Text('Shuffle seating'),
                ),
                PopupMenuItem(
                  value: _AssignmentAction.pickStudent,
                  child: Text('Pick a student'),
                ),
                PopupMenuDivider(),
                PopupMenuItem(
                  value: _AssignmentAction.clearAssignments,
                  child: Text('Clear student placements'),
                ),
              ],
              child: const _ToolbarMenuButton(
                icon: Icons.people_alt_outlined,
                label: 'Roster Actions',
              ),
            ),
            const SizedBox(width: 8),
            FilterChip(
              avatar: const Icon(Icons.draw_outlined, size: 18),
              label: const Text('Edit room'),
              selected: designMode,
              onSelected: (_) => onToggleDesignMode(),
              selectedColor:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.14),
              checkmarkColor: Theme.of(context).colorScheme.primary,
              side: BorderSide(
                color: designMode
                    ? Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.36)
                    : WorkspaceChrome.panelBorderColor(context, emphasis: 0.9),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            if (designMode) ...[
              const SizedBox(width: 8),
              PopupMenuButton<_FurnitureAction>(
                onSelected: (value) {
                  switch (value) {
                    case _FurnitureAction.rectTable:
                      onAddRectTable();
                      break;
                    case _FurnitureAction.squareTable:
                      onAddSquareTable();
                      break;
                    case _FurnitureAction.desk:
                      onAddDesk();
                      break;
                    case _FurnitureAction.teacherDesk:
                      onAddTeacherDesk();
                      break;
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: _FurnitureAction.rectTable,
                    child: Text('Rect table'),
                  ),
                  PopupMenuItem(
                    value: _FurnitureAction.squareTable,
                    child: Text('Square table'),
                  ),
                  PopupMenuItem(
                    value: _FurnitureAction.desk,
                    child: Text('Desk'),
                  ),
                  PopupMenuItem(
                    value: _FurnitureAction.teacherDesk,
                    child: Text('Teacher desk'),
                  ),
                ],
                child: const _ToolbarMenuButton(
                  icon: Icons.add_home_work_outlined,
                  label: 'Add furniture',
                ),
              ),
            ],
            if (onOpenRoomSetups != null) ...[
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: onOpenRoomSetups,
                icon: const Icon(Icons.meeting_room_outlined),
                label: const Text('Room setups'),
                style: WorkspaceButtonStyles.outlined(context, compact: true),
              ),
            ],
            if (onPreviewPdf != null) ...[
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: onPreviewPdf,
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: Text(webMode ? 'Preview PDF' : 'Build PDF'),
                style: WorkspaceButtonStyles.outlined(context, compact: true),
              ),
            ],
            if (onPrint != null) ...[
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: onPrint,
                icon: const Icon(Icons.print_outlined),
                label: const Text('Print'),
                style: WorkspaceButtonStyles.outlined(context, compact: true),
              ),
            ],
            if (onDownload != null) ...[
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: onDownload,
                icon: Icon(
                    webMode ? Icons.download_outlined : Icons.share_outlined),
                label: Text(webMode ? 'Download' : 'Share PDF'),
                style: WorkspaceButtonStyles.outlined(context, compact: true),
              ),
            ],
            if (showFullScreenButton) ...[
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: onFullScreen,
                icon: const Icon(Icons.fullscreen),
                label: const Text('Full screen'),
                style: WorkspaceButtonStyles.filled(context, compact: true),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

final _emptyLayout = SeatingLayout(
  layoutId: '',
  classId: '',
  name: '',
  canvasWidth: 1200,
  canvasHeight: 800,
  tables: [],
  seats: [],
  createdAt: DateTime.fromMillisecondsSinceEpoch(0),
  updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
);

InputDecoration _seatingToolbarFieldDecoration(BuildContext context) {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;
  final borderRadius = BorderRadius.circular(8);
  final baseBorder = OutlineInputBorder(
    borderRadius: borderRadius,
    borderSide: BorderSide(
      color: theme.colorScheme.outline.withValues(alpha: isDark ? 0.30 : 0.22),
    ),
  );

  return InputDecoration(
    labelText: 'Layout',
    prefixIcon: const Icon(Icons.layers_outlined, size: 18),
    prefixIconConstraints: const BoxConstraints(minWidth: 36),
    isDense: true,
    filled: true,
    fillColor: theme.colorScheme.surface.withValues(
      alpha: isDark ? 0.22 : 0.54,
    ),
    border: baseBorder,
    enabledBorder: baseBorder,
    focusedBorder: OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(
        color: theme.colorScheme.primary.withValues(alpha: 0.62),
        width: 1.2,
      ),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
  );
}

class _ToolbarMenuButton extends StatelessWidget {
  final IconData icon;
  final String label;
  const _ToolbarMenuButton({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = theme.colorScheme.onSurface.withValues(alpha: 0.88);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.14),
        border: Border.all(
          color: WorkspaceChrome.panelBorderColor(context, emphasis: 0.92),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 18, color: fg),
        const SizedBox(width: 6),
        Text(label,
            style: context.textStyles.labelLarge?.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
            )),
      ]),
    );
  }
}

enum _LayoutAction { rename, roomSettings, clearRoom, delete }

enum _AssignmentAction {
  autoAssign,
  shuffleSeating,
  clearAssignments,
  pickStudent,
}

enum _FurnitureAction { rectTable, squareTable, desk, teacherDesk }

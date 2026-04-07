import 'package:flutter/material.dart';
import 'package:gradeflow/components/animated_page_background.dart';
import 'package:gradeflow/theme.dart';

class WorkspaceMetricData {
  final String label;
  final String value;
  final String detail;
  final IconData icon;
  final Color? accent;

  const WorkspaceMetricData({
    required this.label,
    required this.value,
    required this.detail,
    required this.icon,
    this.accent,
  });
}

enum WorkspaceFeedbackTone {
  info,
  success,
  warning,
  error,
}

ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showWorkspaceSnackBar(
  BuildContext context, {
  required String message,
  WorkspaceFeedbackTone tone = WorkspaceFeedbackTone.info,
  String? title,
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(seconds: 4),
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  return messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      backgroundColor: Colors.transparent,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: EdgeInsets.zero,
      duration: duration,
      content: _WorkspaceFeedbackBanner(
        message: message,
        tone: tone,
        title: title,
        actionLabel: actionLabel,
        onAction: onAction,
      ),
    ),
  );
}

Future<DateTime?> showWorkspaceDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  DateTime? currentDate,
  DatePickerEntryMode initialEntryMode = DatePickerEntryMode.calendarOnly,
  DatePickerMode initialDatePickerMode = DatePickerMode.day,
  SelectableDayPredicate? selectableDayPredicate,
  String? helpText,
  String? cancelText,
  String? confirmText,
}) {
  final baseTheme = Theme.of(context);
  final accent = baseTheme.colorScheme.primary;

  return showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: firstDate,
    lastDate: lastDate,
    currentDate: currentDate,
    initialEntryMode: initialEntryMode,
    initialDatePickerMode: initialDatePickerMode,
    selectableDayPredicate: selectableDayPredicate,
    helpText: helpText,
    cancelText: cancelText,
    confirmText: confirmText,
    builder: (dialogContext, child) {
      final dialogTheme = baseTheme.copyWith(
        datePickerTheme: baseTheme.datePickerTheme.copyWith(
          backgroundColor: baseTheme.colorScheme.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: baseTheme.colorScheme.outline.withValues(alpha: 0.22),
            ),
          ),
          headerBackgroundColor: baseTheme.colorScheme.surfaceContainerHighest,
          headerForegroundColor: baseTheme.colorScheme.onSurface,
          todayBorder: BorderSide(
            color: accent.withValues(alpha: 0.42),
          ),
          cancelButtonStyle: WorkspaceButtonStyles.text(
            dialogContext,
            compact: true,
          ),
          confirmButtonStyle: WorkspaceButtonStyles.filled(
            dialogContext,
            compact: true,
          ),
          dayOverlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return accent.withValues(alpha: 0.14);
            }
            if (states.contains(WidgetState.pressed) ||
                states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.focused)) {
              return accent.withValues(alpha: 0.08);
            }
            return null;
          }),
          yearOverlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return accent.withValues(alpha: 0.16);
            }
            if (states.contains(WidgetState.pressed) ||
                states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.focused)) {
              return accent.withValues(alpha: 0.08);
            }
            return null;
          }),
        ),
      );

      return Theme(
        data: dialogTheme,
        child: child ?? const SizedBox.shrink(),
      );
    },
  );
}

class WorkspaceScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? eyebrow;
  final List<Widget> leadingActions;
  final List<Widget> trailingActions;
  final List<Widget> headerActions;
  final List<WorkspaceMetricData> metrics;
  final Widget? contextBar;
  final Widget child;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final double maxContentWidth;

  const WorkspaceScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.eyebrow,
    this.leadingActions = const [],
    this.trailingActions = const [],
    this.headerActions = const [],
    this.metrics = const [],
    this.contextBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.maxContentWidth = 1440,
  });

  @override
  Widget build(BuildContext context) {
    final defaultContextBar = headerActions.isEmpty && metrics.isEmpty
        ? null
        : _WorkspaceDefaultContextBar(
            actions: headerActions,
            metrics: metrics,
          );

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      body: AnimatedPageBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxContentWidth),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (leadingActions.isNotEmpty || trailingActions.isNotEmpty)
                      _WorkspaceTopBar(
                        leadingActions: leadingActions,
                        trailingActions: trailingActions,
                      ),
                    if (leadingActions.isNotEmpty || trailingActions.isNotEmpty)
                      const SizedBox(height: 12),
                    WorkspaceSurfaceCard(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (eyebrow != null &&
                              eyebrow!.trim().isNotEmpty) ...[
                            Text(
                              eyebrow!.toUpperCase(),
                              style: context.textStyles.labelMedium?.copyWith(
                                letterSpacing: 1.1,
                                color: _workspaceMuted(context),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                          _WorkspaceHeaderCopy(
                            title: title,
                            subtitle: subtitle,
                          ),
                        ],
                      ),
                    ),
                    if (defaultContextBar != null || contextBar != null)
                      const SizedBox(height: 10),
                    if (defaultContextBar != null) defaultContextBar,
                    if (defaultContextBar != null && contextBar != null)
                      const SizedBox(height: 10),
                    if (contextBar != null) contextBar!,
                    const SizedBox(height: 14),
                    Expanded(child: child),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class WorkspaceSurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;

  const WorkspaceSurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 22,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surface = theme.colorScheme.surface;
    final elevated = theme.colorScheme.surfaceContainerHighest;
    final border = theme.colorScheme.outline.withValues(
      alpha: isDark ? 0.56 : 0.32,
    );

    final body = Padding(
      padding: padding,
      child: child,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(surface, elevated, isDark ? 0.48 : 0.24)!,
            Color.lerp(
              surface,
              theme.colorScheme.primary,
              isDark ? 0.04 : 0.018,
            )!,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(
              alpha: isDark ? 0.16 : 0.05,
            ),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: onTap == null
              ? body
              : InkWell(
                  onTap: onTap,
                  hoverColor: _workspaceInteractiveOverlay(context),
                  focusColor: _workspaceInteractiveOverlay(context),
                  highlightColor:
                      _workspaceInteractiveOverlay(context, emphasis: 0.08),
                  splashColor:
                      _workspaceInteractiveOverlay(context, emphasis: 0.1),
                  child: body,
                ),
        ),
      ),
    );
  }
}

class WorkspaceNavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool selected;

  const WorkspaceNavButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = selected
        ? Colors.white
        : theme.colorScheme.onSurface.withValues(alpha: 0.84);

    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: foreground,
        backgroundColor: selected
            ? theme.colorScheme.primary.withValues(alpha: 0.22)
            : theme.colorScheme.surface.withValues(alpha: 0.24),
        side: BorderSide(
          color: selected
              ? theme.colorScheme.primary.withValues(alpha: 0.42)
              : theme.colorScheme.outline.withValues(alpha: 0.42),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

class WorkspaceButtonStyles {
  const WorkspaceButtonStyles._();

  static ButtonStyle outlined(
    BuildContext context, {
    bool compact = false,
  }) {
    final theme = Theme.of(context);
    return OutlinedButton.styleFrom(
      foregroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.88),
      backgroundColor: theme.colorScheme.surface.withValues(alpha: 0.14),
      disabledForegroundColor:
          theme.colorScheme.onSurface.withValues(alpha: 0.38),
      disabledBackgroundColor:
          theme.colorScheme.surface.withValues(alpha: 0.08),
      overlayColor: theme.colorScheme.primary.withValues(alpha: 0.06),
      visualDensity: VisualDensity.compact,
      minimumSize: Size(0, compact ? 36 : 40),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 14,
        vertical: compact ? 9 : 10,
      ),
      iconSize: 18,
      textStyle: context.textStyles.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      side: BorderSide(
        color: theme.colorScheme.outline.withValues(alpha: 0.32),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
    );
  }

  static ButtonStyle filled(
    BuildContext context, {
    bool compact = false,
  }) {
    final theme = Theme.of(context);
    return FilledButton.styleFrom(
      disabledForegroundColor:
          theme.colorScheme.onSurface.withValues(alpha: 0.38),
      disabledBackgroundColor:
          theme.colorScheme.onSurface.withValues(alpha: 0.08),
      overlayColor: theme.colorScheme.onPrimary.withValues(alpha: 0.08),
      visualDensity: VisualDensity.compact,
      minimumSize: Size(0, compact ? 36 : 40),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 14,
        vertical: compact ? 9 : 10,
      ),
      iconSize: 18,
      textStyle: context.textStyles.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
    );
  }

  static ButtonStyle tonal(
    BuildContext context, {
    bool compact = false,
  }) {
    final theme = Theme.of(context);
    return FilledButton.styleFrom(
      foregroundColor: theme.colorScheme.onSecondaryContainer,
      backgroundColor:
          theme.colorScheme.secondaryContainer.withValues(alpha: 0.72),
      disabledForegroundColor:
          theme.colorScheme.onSurface.withValues(alpha: 0.38),
      disabledBackgroundColor:
          theme.colorScheme.onSurface.withValues(alpha: 0.08),
      overlayColor: theme.colorScheme.onSecondaryContainer.withValues(
        alpha: 0.08,
      ),
      visualDensity: VisualDensity.compact,
      minimumSize: Size(0, compact ? 36 : 40),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 14,
        vertical: compact ? 9 : 10,
      ),
      iconSize: 18,
      textStyle: context.textStyles.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
    );
  }

  static ButtonStyle text(
    BuildContext context, {
    bool compact = false,
  }) {
    final theme = Theme.of(context);
    return TextButton.styleFrom(
      foregroundColor: theme.colorScheme.primary,
      overlayColor: theme.colorScheme.primary.withValues(alpha: 0.06),
      visualDensity: VisualDensity.compact,
      minimumSize: Size(0, compact ? 34 : 38),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 8 : 9,
      ),
      iconSize: 18,
      textStyle: context.textStyles.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  static ButtonStyle icon(
    BuildContext context, {
    bool compact = false,
  }) {
    final theme = Theme.of(context);
    return IconButton.styleFrom(
      foregroundColor: theme.colorScheme.onSurfaceVariant,
      backgroundColor: theme.colorScheme.surface.withValues(alpha: 0.14),
      disabledForegroundColor:
          theme.colorScheme.onSurface.withValues(alpha: 0.38),
      disabledBackgroundColor:
          theme.colorScheme.surface.withValues(alpha: 0.08),
      hoverColor: theme.colorScheme.primary.withValues(alpha: 0.06),
      highlightColor: theme.colorScheme.primary.withValues(alpha: 0.08),
      padding: EdgeInsets.all(compact ? 8 : 10),
      minimumSize: Size.square(compact ? 34 : 38),
      iconSize: 18,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.22),
        ),
      ),
    );
  }
}

class WorkspaceSectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? action;
  final int? subtitleMaxLines;

  const WorkspaceSectionHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.action,
    this.subtitleMaxLines = 2,
  });

  @override
  Widget build(BuildContext context) {
    final titleStyle = context.textStyles.titleMedium?.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: -0.1,
    );
    final subtitleStyle = context.textStyles.bodySmall?.copyWith(
      color: _workspaceMuted(context),
      height: 1.32,
    );
    final subtitleWidget = Text(
      subtitle,
      style: subtitleStyle,
      maxLines: subtitleMaxLines,
      overflow: subtitleMaxLines == null
          ? TextOverflow.visible
          : TextOverflow.ellipsis,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 900;
        if (narrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: titleStyle,
              ),
              const SizedBox(height: 4),
              subtitleWidget,
              if (action != null) ...[
                const SizedBox(height: 10),
                action!,
              ],
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: titleStyle,
                  ),
                  const SizedBox(height: 4),
                  subtitleWidget,
                ],
              ),
            ),
            if (action != null) ...[
              const SizedBox(width: 10),
              action!,
            ],
          ],
        );
      },
    );
  }
}

class WorkspaceEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> actions;

  const WorkspaceEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: WorkspaceSurfaceCard(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.16),
                ),
                child: Icon(
                  icon,
                  size: 30,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: context.textStyles.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: context.textStyles.bodySmall?.copyWith(
                  color: _workspaceMuted(context),
                  height: 1.35,
                ),
                textAlign: TextAlign.center,
              ),
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: actions,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class WorkspaceLoadingState extends StatelessWidget {
  final String title;
  final String subtitle;
  final double maxWidth;

  const WorkspaceLoadingState({
    super.key,
    required this.title,
    required this.subtitle,
    this.maxWidth = 360,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: WorkspaceSurfaceCard(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.6),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: context.textStyles.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: context.textStyles.bodySmall?.copyWith(
                  color: _workspaceMuted(context),
                  height: 1.35,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class WorkspaceInlineState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  const WorkspaceInlineState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: theme.colorScheme.surface.withValues(alpha: 0.18),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: theme.colorScheme.primary.withValues(alpha: 0.14),
            ),
            child: Icon(icon, size: 20, color: theme.colorScheme.primary),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: context.textStyles.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: context.textStyles.bodySmall?.copyWith(
              color: _workspaceMuted(context),
              height: 1.35,
            ),
            textAlign: TextAlign.center,
          ),
          if (action != null) ...[
            const SizedBox(height: 12),
            action!,
          ],
        ],
      ),
    );
  }
}

class WorkspaceDialogScaffold extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget body;
  final List<Widget> actions;
  final Widget? headerAction;
  final IconData? icon;
  final double maxWidth;
  final double? maxHeight;
  final bool bodyCanExpand;

  const WorkspaceDialogScaffold({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.actions = const [],
    this.headerAction,
    this.icon,
    this.maxWidth = 480,
    this.maxHeight,
    this.bodyCanExpand = false,
  });

  @override
  Widget build(BuildContext context) {
    final header = _WorkspaceTransientHeader(
      title: title,
      subtitle: subtitle,
      icon: icon,
      action: headerAction,
    );

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: maxHeight ?? double.infinity,
        ),
        child: WorkspaceSurfaceCard(
          radius: 24,
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize:
                maxHeight == null ? MainAxisSize.min : MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              const SizedBox(height: 14),
              if (bodyCanExpand) Flexible(child: body) else body,
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.only(top: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: Theme.of(context)
                            .colorScheme
                            .outline
                            .withValues(alpha: 0.18),
                      ),
                    ),
                  ),
                  child: OverflowBar(
                    spacing: 8,
                    overflowSpacing: 8,
                    alignment: MainAxisAlignment.end,
                    overflowAlignment: OverflowBarAlignment.end,
                    children: actions,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class WorkspaceSheetScaffold extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget body;
  final Widget? headerAction;
  final Widget? footer;
  final IconData? icon;
  final bool bodyCanExpand;
  final double maxWidth;

  const WorkspaceSheetScaffold({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.headerAction,
    this.footer,
    this.icon,
    this.bodyCanExpand = false,
    this.maxWidth = 1120,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: WorkspaceSurfaceCard(
              radius: 28,
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
              child: Column(
                mainAxisSize:
                    bodyCanExpand ? MainAxisSize.max : MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: Theme.of(context)
                            .colorScheme
                            .outlineVariant
                            .withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _WorkspaceTransientHeader(
                    title: title,
                    subtitle: subtitle,
                    icon: icon,
                    action: headerAction,
                  ),
                  const SizedBox(height: 14),
                  if (bodyCanExpand) Expanded(child: body) else body,
                  if (footer != null) ...[
                    const SizedBox(height: 14),
                    footer!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class WorkspaceProgressDialog extends StatelessWidget {
  final String title;
  final String? subtitle;

  const WorkspaceProgressDialog({
    super.key,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return WorkspaceDialogScaffold(
      title: title,
      subtitle: subtitle,
      maxWidth: 340,
      body: const SizedBox(
        height: 56,
        child: Center(
          child: SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
        ),
      ),
    );
  }
}

class WorkspaceContextBar extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;
  final double radius;

  const WorkspaceContextBar({
    super.key,
    this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    this.radius = 18,
  });

  @override
  Widget build(BuildContext context) {
    final hasCopy = (title?.trim().isNotEmpty ?? false) ||
        (subtitle?.trim().isNotEmpty ?? false);

    Widget? copy;
    if (hasCopy) {
      copy = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title?.trim().isNotEmpty ?? false)
            Text(
              title!,
              style: context.textStyles.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          if ((title?.trim().isNotEmpty ?? false) &&
              (subtitle?.trim().isNotEmpty ?? false))
            const SizedBox(height: 3),
          if (subtitle?.trim().isNotEmpty ?? false)
            Text(
              subtitle!,
              style: context.textStyles.bodySmall?.copyWith(
                color: _workspaceMuted(context),
                height: 1.32,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      );
    }

    return WorkspaceSurfaceCard(
      padding: padding,
      radius: radius,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 920;
          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (copy != null) copy,
                if (copy != null && leading != null) const SizedBox(height: 8),
                if (leading != null) leading!,
                if ((copy != null || leading != null) && trailing != null)
                  const SizedBox(height: 8),
                if (trailing != null) trailing!,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (copy != null)
                Expanded(
                  child: copy,
                ),
              if (copy != null && leading != null) const SizedBox(width: 10),
              if (leading != null)
                Flexible(
                  flex: copy != null ? 3 : 1,
                  child: leading!,
                ),
              if ((copy != null || leading != null) && trailing != null)
                const SizedBox(width: 10),
              if (trailing != null)
                Flexible(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: trailing!,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _WorkspaceTopBar extends StatelessWidget {
  final List<Widget> leadingActions;
  final List<Widget> trailingActions;

  const _WorkspaceTopBar({
    required this.leadingActions,
    required this.trailingActions,
  });

  @override
  Widget build(BuildContext context) {
    final hasLeading = leadingActions.isNotEmpty;
    final hasTrailing = trailingActions.isNotEmpty;

    if (hasLeading != hasTrailing) {
      final actions = hasLeading ? leadingActions : trailingActions;
      return Align(
        alignment: hasLeading ? Alignment.centerLeft : Alignment.centerRight,
        child: WorkspaceSurfaceCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          radius: 18,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: hasLeading ? WrapAlignment.start : WrapAlignment.end,
            children: actions,
          ),
        ),
      );
    }

    return WorkspaceSurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      radius: 19,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 980;
          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (leadingActions.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: leadingActions,
                  ),
                if (trailingActions.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: trailingActions,
                  ),
                ],
              ],
            );
          }

          return Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: leadingActions,
                ),
              ),
              if (trailingActions.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: trailingActions,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _WorkspaceHeaderCopy extends StatelessWidget {
  final String title;
  final String subtitle;

  const _WorkspaceHeaderCopy({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            style: context.textStyles.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: context.textStyles.bodyMedium?.copyWith(
            color: _workspaceMuted(context),
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _WorkspaceDefaultContextBar extends StatelessWidget {
  final List<Widget> actions;
  final List<WorkspaceMetricData> metrics;

  const _WorkspaceDefaultContextBar({
    required this.actions,
    required this.metrics,
  });

  @override
  Widget build(BuildContext context) {
    return WorkspaceContextBar(
      leading: metrics.isEmpty
          ? null
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final metric in metrics)
                  _WorkspaceMetricPill(metric: metric),
              ],
            ),
      trailing: actions.isEmpty
          ? null
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: actions,
            ),
    );
  }
}

class _WorkspaceMetricPill extends StatelessWidget {
  final WorkspaceMetricData metric;

  const _WorkspaceMetricPill({
    required this.metric,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = metric.accent ?? theme.colorScheme.primary;

    final pill = Container(
      constraints: const BoxConstraints(minWidth: 124),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        color: theme.colorScheme.surface.withValues(alpha: 0.22),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: accent.withValues(alpha: 0.14),
              border: Border.all(color: accent.withValues(alpha: 0.22)),
            ),
            child: Icon(metric.icon, color: accent, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  metric.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textStyles.labelSmall?.copyWith(
                    color: _workspaceMuted(context),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  metric.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textStyles.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (metric.detail.trim().isEmpty) {
      return pill;
    }

    return Tooltip(
      message: metric.detail,
      child: pill,
    );
  }
}

class _WorkspaceTransientHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? action;

  const _WorkspaceTransientHeader({
    required this.title,
    this.subtitle,
    this.icon,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final hasSubtitle = subtitle?.trim().isNotEmpty ?? false;
    final copy = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
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
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: context.textStyles.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.1,
                ),
              ),
              if (hasSubtitle) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: context.textStyles.bodySmall?.copyWith(
                    color: _workspaceMuted(context),
                    height: 1.35,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = action != null && constraints.maxWidth < 700;
        if (narrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              copy,
              const SizedBox(height: 10),
              action!,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: copy),
            if (action != null) ...[
              const SizedBox(width: 10),
              action!,
            ],
          ],
        );
      },
    );
  }
}

class _WorkspaceFeedbackBanner extends StatelessWidget {
  final String message;
  final WorkspaceFeedbackTone tone;
  final String? title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _WorkspaceFeedbackBanner({
    required this.message,
    required this.tone,
    this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = _workspaceFeedbackAccent(theme, tone);
    final heading = title ?? _workspaceFeedbackTitle(tone);
    final hasAction = actionLabel != null &&
        actionLabel!.trim().isNotEmpty &&
        onAction != null;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Color.lerp(theme.colorScheme.surface, accent, 0.1)!,
        border: Border.all(color: accent.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(11),
                color: accent.withValues(alpha: 0.14),
              ),
              child: Icon(
                _workspaceFeedbackIcon(tone),
                size: 18,
                color: accent,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    heading,
                    style: context.textStyles.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    message,
                    style: context.textStyles.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.34,
                    ),
                  ),
                ],
              ),
            ),
            if (hasAction) ...[
              const SizedBox(width: 8),
              TextButton(
                onPressed: onAction,
                style: WorkspaceButtonStyles.text(context, compact: true),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Color _workspaceInteractiveOverlay(
  BuildContext context, {
  double emphasis = 0.06,
}) =>
    Theme.of(context).colorScheme.primary.withValues(alpha: emphasis);

Color _workspaceMuted(BuildContext context) =>
    Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.9);

Color _workspaceFeedbackAccent(ThemeData theme, WorkspaceFeedbackTone tone) {
  switch (tone) {
    case WorkspaceFeedbackTone.success:
      return Colors.green.shade600;
    case WorkspaceFeedbackTone.warning:
      return Colors.amber.shade700;
    case WorkspaceFeedbackTone.error:
      return theme.colorScheme.error;
    case WorkspaceFeedbackTone.info:
      return theme.colorScheme.primary;
  }
}

IconData _workspaceFeedbackIcon(WorkspaceFeedbackTone tone) {
  switch (tone) {
    case WorkspaceFeedbackTone.success:
      return Icons.check_circle_outline_rounded;
    case WorkspaceFeedbackTone.warning:
      return Icons.warning_amber_rounded;
    case WorkspaceFeedbackTone.error:
      return Icons.error_outline_rounded;
    case WorkspaceFeedbackTone.info:
      return Icons.info_outline_rounded;
  }
}

String _workspaceFeedbackTitle(WorkspaceFeedbackTone tone) {
  switch (tone) {
    case WorkspaceFeedbackTone.success:
      return 'Saved';
    case WorkspaceFeedbackTone.warning:
      return 'Check this';
    case WorkspaceFeedbackTone.error:
      return 'Something went wrong';
    case WorkspaceFeedbackTone.info:
      return 'Update';
  }
}

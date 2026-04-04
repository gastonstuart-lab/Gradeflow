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
    this.maxContentWidth = 1480,
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
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (leadingActions.isNotEmpty || trailingActions.isNotEmpty)
                      _WorkspaceTopBar(
                        leadingActions: leadingActions,
                        trailingActions: trailingActions,
                      ),
                    if (leadingActions.isNotEmpty || trailingActions.isNotEmpty)
                      const SizedBox(height: 14),
                    WorkspaceSurfaceCard(
                      padding: const EdgeInsets.all(20),
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
                      const SizedBox(height: 12),
                    if (defaultContextBar != null) defaultContextBar,
                    if (defaultContextBar != null && contextBar != null)
                      const SizedBox(height: 12),
                    if (contextBar != null) contextBar!,
                    const SizedBox(height: 16),
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
    this.padding = const EdgeInsets.all(20),
    this.radius = 24,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surface = theme.colorScheme.surface;
    final elevated = theme.colorScheme.surfaceContainerHighest;
    final border = theme.colorScheme.outline.withValues(
      alpha: isDark ? 0.68 : 0.42,
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
            Color.lerp(surface, elevated, isDark ? 0.62 : 0.35)!,
            Color.lerp(
                surface, theme.colorScheme.primary, isDark ? 0.06 : 0.03)!,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(
              alpha: isDark ? 0.22 : 0.07,
            ),
            blurRadius: 24,
            offset: const Offset(0, 14),
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

class WorkspaceSectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? action;

  const WorkspaceSectionHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 900;
        if (narrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: context.textStyles.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: context.textStyles.bodySmall?.copyWith(
                  color: _workspaceMuted(context),
                ),
              ),
              if (action != null) ...[
                const SizedBox(height: 12),
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
                    style: context.textStyles.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: context.textStyles.bodySmall?.copyWith(
                      color: _workspaceMuted(context),
                    ),
                  ),
                ],
              ),
            ),
            if (action != null) ...[
              const SizedBox(width: 12),
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
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.16),
                ),
                child: Icon(
                  icon,
                  size: 36,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                style: context.textStyles.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: context.textStyles.bodyMedium?.copyWith(
                  color: _workspaceMuted(context),
                ),
                textAlign: TextAlign.center,
              ),
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
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
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
              ),
            ),
          if ((title?.trim().isNotEmpty ?? false) &&
              (subtitle?.trim().isNotEmpty ?? false))
            const SizedBox(height: 4),
          if (subtitle?.trim().isNotEmpty ?? false)
            Text(
              subtitle!,
              style: context.textStyles.bodySmall?.copyWith(
                color: _workspaceMuted(context),
                height: 1.35,
              ),
            ),
        ],
      );
    }

    return WorkspaceSurfaceCard(
      padding: padding,
      radius: radius,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 980;
          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (copy != null) copy,
                if (copy != null && leading != null) const SizedBox(height: 10),
                if (leading != null) leading!,
                if ((copy != null || leading != null) && trailing != null)
                  const SizedBox(height: 10),
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
              if (copy != null && leading != null) const SizedBox(width: 12),
              if (leading != null)
                Flexible(
                  flex: copy != null ? 3 : 1,
                  child: leading!,
                ),
              if ((copy != null || leading != null) && trailing != null)
                const SizedBox(width: 12),
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          radius: 18,
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: hasLeading
                ? WrapAlignment.start
                : WrapAlignment.end,
            children: actions,
          ),
        ),
      );
    }

    return WorkspaceSurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      radius: 20,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 980;
          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (leadingActions.isNotEmpty)
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: leadingActions,
                  ),
                if (trailingActions.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
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
                  spacing: 10,
                  runSpacing: 10,
                  children: leadingActions,
                ),
              ),
              if (trailingActions.isNotEmpty)
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
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
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final metric in metrics)
                  _WorkspaceMetricPill(metric: metric),
              ],
            ),
      trailing: actions.isEmpty
          ? null
          : Wrap(
              spacing: 10,
              runSpacing: 10,
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
      constraints: const BoxConstraints(minWidth: 144),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: theme.colorScheme.surface.withValues(alpha: 0.26),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: accent.withValues(alpha: 0.16),
              border: Border.all(color: accent.withValues(alpha: 0.26)),
            ),
            child: Icon(metric.icon, color: accent, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  metric.label,
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

Color _workspaceMuted(BuildContext context) =>
    Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.9);

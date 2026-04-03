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
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.maxContentWidth = 1480,
  });

  @override
  Widget build(BuildContext context) {
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
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (leadingActions.isNotEmpty || trailingActions.isNotEmpty)
                      _WorkspaceTopBar(
                        leadingActions: leadingActions,
                        trailingActions: trailingActions,
                      ),
                    if (leadingActions.isNotEmpty || trailingActions.isNotEmpty)
                      const SizedBox(height: 18),
                    WorkspaceSurfaceCard(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (eyebrow != null && eyebrow!.trim().isNotEmpty) ...[
                            Text(
                              eyebrow!.toUpperCase(),
                              style: context.textStyles.labelMedium?.copyWith(
                                letterSpacing: 1.1,
                                color: _workspaceMuted(context),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final narrow = constraints.maxWidth < 920;
                              if (narrow) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _WorkspaceHeaderCopy(
                                      title: title,
                                      subtitle: subtitle,
                                    ),
                                    if (headerActions.isNotEmpty) ...[
                                      const SizedBox(height: 18),
                                      Wrap(
                                        spacing: 10,
                                        runSpacing: 10,
                                        children: headerActions,
                                      ),
                                    ],
                                  ],
                                );
                              }

                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: _WorkspaceHeaderCopy(
                                      title: title,
                                      subtitle: subtitle,
                                    ),
                                  ),
                                  if (headerActions.isNotEmpty) ...[
                                    const SizedBox(width: 18),
                                    Wrap(
                                      spacing: 10,
                                      runSpacing: 10,
                                      alignment: WrapAlignment.end,
                                      children: headerActions,
                                    ),
                                  ],
                                ],
                              );
                            },
                          ),
                          if (metrics.isNotEmpty) ...[
                            const SizedBox(height: 22),
                            Wrap(
                              spacing: 14,
                              runSpacing: 14,
                              children: [
                                for (final metric in metrics)
                                  SizedBox(
                                    width: 220,
                                    child: _WorkspaceMetricTile(metric: metric),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
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
            Color.lerp(surface, theme.colorScheme.primary, isDark ? 0.06 : 0.03)!,
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
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.16),
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

class _WorkspaceTopBar extends StatelessWidget {
  final List<Widget> leadingActions;
  final List<Widget> trailingActions;

  const _WorkspaceTopBar({
    required this.leadingActions,
    required this.trailingActions,
  });

  @override
  Widget build(BuildContext context) {
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
        Text(
          title,
          style: context.textStyles.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: context.textStyles.bodyMedium?.copyWith(
            color: _workspaceMuted(context),
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _WorkspaceMetricTile extends StatelessWidget {
  final WorkspaceMetricData metric;

  const _WorkspaceMetricTile({
    required this.metric,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = metric.accent ?? theme.colorScheme.primary;

    return WorkspaceSurfaceCard(
      padding: const EdgeInsets.all(16),
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  metric.label,
                  style: context.textStyles.labelLarge?.copyWith(
                    color: _workspaceMuted(context),
                  ),
                ),
              ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: accent.withValues(alpha: 0.18),
                  border: Border.all(color: accent.withValues(alpha: 0.32)),
                ),
                child: Icon(metric.icon, color: accent, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            metric.value,
            style: context.textStyles.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            metric.detail,
            style: context.textStyles.bodySmall?.copyWith(
              color: _workspaceMuted(context),
            ),
          ),
        ],
      ),
    );
  }
}

Color _workspaceMuted(BuildContext context) =>
    Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.9);

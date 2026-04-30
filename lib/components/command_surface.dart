import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:gradeflow/components/workspace_shell.dart';
import 'package:gradeflow/os/os_palette.dart';
import 'package:gradeflow/theme.dart';

enum SurfaceType {
  stage,
  tool,
  whisper,
}

enum CommandPulseTone {
  calm,
  attention,
}

enum GradeFlowPanelVariant {
  stage,
  tool,
  whisper,
}

class GradeFlowPanel extends StatelessWidget {
  const GradeFlowPanel({
    super.key,
    required this.variant,
    required this.child,
    this.header,
    this.actions = const [],
    this.onTap,
    this.padding,
    this.radius,
    this.contentSpacing,
    this.expandChild = false,
  });

  final GradeFlowPanelVariant variant;
  final Widget child;
  final Widget? header;
  final List<Widget> actions;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final double? radius;
  final double? contentSpacing;
  final bool expandChild;

  @override
  Widget build(BuildContext context) {
    return CommandSurfaceCard(
      surfaceType: switch (variant) {
        GradeFlowPanelVariant.stage => SurfaceType.stage,
        GradeFlowPanelVariant.tool => SurfaceType.tool,
        GradeFlowPanelVariant.whisper => SurfaceType.whisper,
      },
      header: header,
      actions: actions,
      onTap: onTap,
      padding: padding,
      radius: radius,
      contentSpacing: contentSpacing,
      expandChild: expandChild,
      child: child,
    );
  }
}

class GradeFlowSectionHeader extends StatelessWidget {
  const GradeFlowSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: WorkspaceTypography.sectionTitle(context),
              ),
              if ((subtitle ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: WorkspaceTypography.metadata(context),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 12),
          trailing!,
        ],
      ],
    );
  }
}

class GradeFlowMetricPill extends StatelessWidget {
  const GradeFlowMetricPill({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.accent,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final tone = accent ?? OSColors.info;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: OSColors.panelSurface(dark).withValues(alpha: dark ? 0.54 : 0.84),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: OSColors.panelBorder(dark).withValues(alpha: dark ? 0.75 : 0.8),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 14,
              color: tone,
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: WorkspaceTypography.pillLabel(context),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: WorkspaceTypography.pillValue(
              context,
              color: OSColors.textPrimary(dark),
            ),
          ),
        ],
      ),
    );
  }
}

class GradeFlowActionChip extends StatelessWidget {
  const GradeFlowActionChip({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.emphasized = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final style = emphasized
        ? WorkspaceButtonStyles.filled(context, compact: true)
        : WorkspaceButtonStyles.tonal(context, compact: true);

    return ElevatedButton.icon(
      onPressed: onPressed,
      style: style,
      icon: Icon(icon ?? Icons.bolt_rounded, size: 16),
      label: Text(label),
    );
  }
}

class CommandSurfaceCard extends StatefulWidget {
  const CommandSurfaceCard({
    super.key,
    required this.surfaceType,
    required this.child,
    this.header,
    this.actions = const [],
    this.onTap,
    this.padding,
    this.radius,
    this.contentSpacing,
    this.expandChild = false,
  });

  final SurfaceType surfaceType;
  final Widget child;
  final Widget? header;
  final List<Widget> actions;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final double? radius;
  final double? contentSpacing;
  final bool expandChild;

  @override
  State<CommandSurfaceCard> createState() => _CommandSurfaceCardState();
}

class _CommandSurfaceCardState extends State<CommandSurfaceCard> {
  bool _hovered = false;
  bool _pressed = false;

  void _setHovered(bool value) {
    if (!mounted || _hovered == value || widget.onTap == null) return;
    setState(() => _hovered = value);
  }

  void _setPressed(bool value) {
    if (!mounted || _pressed == value || widget.onTap == null) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final spec = _resolveCommandSurfaceSpec(
      context,
      widget.surfaceType,
      hovered: _hovered,
      pressed: _pressed,
    );
    final radius = widget.radius ?? spec.radius;
    final hasTopRow = widget.header != null || widget.actions.isNotEmpty;
    final spacing = widget.contentSpacing ?? spec.contentSpacing;

    final contentChild =
        widget.expandChild ? Expanded(child: widget.child) : widget.child;
    final body = Padding(
      padding: widget.padding ?? spec.padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasTopRow)
            LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < 760;
                final actionWrap = Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: widget.actions,
                );

                if (narrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.header != null) widget.header!,
                      if (widget.actions.isNotEmpty) ...[
                        SizedBox(height: spacing),
                        actionWrap,
                      ],
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.header != null) Expanded(child: widget.header!),
                    if (widget.header != null && widget.actions.isNotEmpty)
                      const SizedBox(width: 12),
                    if (widget.actions.isNotEmpty) Flexible(child: actionWrap),
                  ],
                );
              },
            ),
          if (hasTopRow) SizedBox(height: spacing),
          contentChild,
        ],
      ),
    );

    Widget decoratedChild = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: spec.borderColor),
        gradient: spec.gradient,
        color: spec.fillColor,
      ),
      child: Stack(
        children: [
          if (spec.topHighlightAlpha > 0)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Container(
                  height: 1,
                  color: Colors.white.withValues(alpha: spec.topHighlightAlpha),
                ),
              ),
            ),
          Material(
            type: MaterialType.transparency,
            child: widget.onTap == null
                ? body
                : InkWell(
                    onTap: widget.onTap,
                    onTapDown: (_) => _setPressed(true),
                    onTapUp: (_) => _setPressed(false),
                    onTapCancel: () => _setPressed(false),
                    onHover: _setHovered,
                    hoverColor: spec.overlayColor,
                    focusColor: spec.overlayColor,
                    highlightColor: spec.overlayColor.withValues(alpha: 0.18),
                    splashColor: spec.overlayColor.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(radius),
                    child: body,
                  ),
          ),
        ],
      ),
    );

    if (spec.blur > 0) {
      decoratedChild = BackdropFilter(
        filter: ui.ImageFilter.blur(
          sigmaX: spec.blur,
          sigmaY: spec.blur,
        ),
        child: decoratedChild,
      );
    }

    return MouseRegion(
      onEnter: (_) => _setHovered(true),
      onExit: (_) {
        _setHovered(false);
        _setPressed(false);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        transformAlignment: Alignment.center,
        transform: Matrix4.identity()
          ..translateByDouble(0, spec.translateY, 0, 1)
          ..scaleByDouble(spec.scale, spec.scale, 1, 1),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: spec.shadows,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: decoratedChild,
        ),
      ),
    );
  }
}

class CommandHeader extends StatelessWidget {
  const CommandHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.contextPills,
    this.eyebrow = 'Class workspace',
    this.leading,
    this.primaryAction,
    this.pulseTone = CommandPulseTone.calm,
    this.pulseLabel,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final Widget? leading;
  final Widget? primaryAction;
  final List<Widget> contextPills;
  final CommandPulseTone pulseTone;
  final String? pulseLabel;

  @override
  Widget build(BuildContext context) {
    final pulseColor = _pulseColor(context, pulseTone);

    return CommandSurfaceCard(
      surfaceType: SurfaceType.stage,
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 980;
          final titleBlock = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow.toUpperCase(),
                style: WorkspaceTypography.eyebrow(context),
              ),
              const SizedBox(height: WorkspaceSpacing.xs),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.textStyles.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: WorkspaceTypography.pageSubtitle(context),
              ),
            ],
          );

          final topRow = narrow
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (leading != null) ...[
                          leading!,
                          const SizedBox(width: WorkspaceSpacing.lg),
                        ],
                        Expanded(child: titleBlock),
                      ],
                    ),
                    if (primaryAction != null) ...[
                      const SizedBox(height: WorkspaceSpacing.lg),
                      primaryAction!,
                    ],
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (leading != null) ...[
                      leading!,
                      const SizedBox(width: WorkspaceSpacing.lg),
                    ],
                    Expanded(child: titleBlock),
                    if (primaryAction != null) ...[
                      const SizedBox(width: WorkspaceSpacing.lg),
                      primaryAction!,
                    ],
                  ],
                );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              topRow,
              const SizedBox(height: WorkspaceSpacing.xl),
              if ((pulseLabel ?? '').trim().isNotEmpty) ...[
                Text(
                  pulseLabel!.toUpperCase(),
                  style: context.textStyles.labelSmall?.copyWith(
                    color: pulseColor.withValues(alpha: 0.84),
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.9,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              _CommandPulseLine(
                color: pulseColor,
              ),
              if (contextPills.isNotEmpty) ...[
                const SizedBox(height: WorkspaceSpacing.lg),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: contextPills,
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  static Color _pulseColor(BuildContext context, CommandPulseTone tone) {
    switch (tone) {
      case CommandPulseTone.calm:
        return OSColors.info;
      case CommandPulseTone.attention:
        return OSColors.attention;
    }
  }
}

class _CommandPulseLine extends StatelessWidget {
  const _CommandPulseLine({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          height: 4,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color:
                Theme.of(context).colorScheme.outline.withValues(alpha: 0.16),
          ),
        ),
        Container(
          height: 4,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: LinearGradient(
              colors: [
                color.withValues(alpha: 0.64),
                color.withValues(alpha: 0.24),
                color.withValues(alpha: 0.03),
              ],
              stops: const [0.0, 0.48, 1.0],
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.10),
                blurRadius: 12,
                offset: const Offset(0, 0),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CommandSurfaceSpec {
  const _CommandSurfaceSpec({
    required this.padding,
    required this.radius,
    required this.blur,
    required this.fillColor,
    required this.gradient,
    required this.borderColor,
    required this.shadows,
    required this.overlayColor,
    required this.topHighlightAlpha,
    required this.translateY,
    required this.scale,
    required this.contentSpacing,
  });

  final EdgeInsetsGeometry padding;
  final double radius;
  final double blur;
  final Color fillColor;
  final Gradient? gradient;
  final Color borderColor;
  final List<BoxShadow> shadows;
  final Color overlayColor;
  final double topHighlightAlpha;
  final double translateY;
  final double scale;
  final double contentSpacing;
}

_CommandSurfaceSpec _resolveCommandSurfaceSpec(
  BuildContext context,
  SurfaceType type, {
  required bool hovered,
  required bool pressed,
}) {
  final theme = Theme.of(context);
  final isDark = context.isDark;
  final primary = theme.colorScheme.primary;
  final surface = OSColors.panelSurface(isDark);
  final elevated = OSColors.elevatedPanelSurface(isDark);

  switch (type) {
    case SurfaceType.stage:
      return _CommandSurfaceSpec(
        padding: const EdgeInsets.all(24),
        radius: 30,
        blur: 16,
        fillColor: surface.withValues(alpha: isDark ? 0.58 : 0.88),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(
              surface.withValues(alpha: isDark ? 0.62 : 0.92),
              elevated.withValues(alpha: isDark ? 0.54 : 0.84),
              0.46,
            )!,
            Color.lerp(
              surface.withValues(alpha: isDark ? 0.60 : 0.90),
              primary.withValues(alpha: isDark ? 0.18 : 0.10),
              0.28,
            )!,
            surface.withValues(alpha: isDark ? 0.56 : 0.84),
          ],
          stops: const [0.0, 0.52, 1.0],
        ),
        borderColor: WorkspaceChrome.panelBorderColor(context, emphasis: 1.2),
        shadows: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(
              alpha: isDark ? 0.26 : 0.10,
            ),
            blurRadius: hovered ? 34 : 28,
            offset: Offset(0, hovered ? 22 : 18),
          ),
          BoxShadow(
            color: primary.withValues(alpha: isDark ? 0.12 : 0.06),
            blurRadius: hovered ? 18 : 14,
            offset: const Offset(0, 6),
          ),
        ],
        overlayColor: primary.withValues(alpha: 0.08),
        topHighlightAlpha: isDark ? 0.10 : 0.68,
        translateY: pressed
            ? -1
            : hovered
                ? -3
                : 0,
        scale: pressed ? 0.996 : 1,
        contentSpacing: 18,
      );
    case SurfaceType.tool:
      return _CommandSurfaceSpec(
        padding: const EdgeInsets.all(18),
        radius: 24,
        blur: 10,
        fillColor: surface.withValues(alpha: isDark ? 0.46 : 0.78),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(
              surface.withValues(alpha: isDark ? 0.48 : 0.82),
              elevated.withValues(alpha: isDark ? 0.40 : 0.72),
              0.24,
            )!,
            Color.lerp(
              surface.withValues(alpha: isDark ? 0.44 : 0.78),
              primary.withValues(alpha: isDark ? 0.10 : 0.05),
              0.20,
            )!,
            surface.withValues(alpha: isDark ? 0.42 : 0.72),
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
        borderColor: WorkspaceChrome.panelBorderColor(context, emphasis: 0.94),
        shadows: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(
              alpha: isDark ? 0.17 : 0.07,
            ),
            blurRadius: hovered ? 24 : 20,
            offset: Offset(0, hovered ? 16 : 12),
          ),
        ],
        overlayColor: primary.withValues(alpha: 0.07),
        topHighlightAlpha: isDark ? 0.07 : 0.52,
        translateY: pressed
            ? -1
            : hovered
                ? -2
                : 0,
        scale: pressed ? 0.994 : 1,
        contentSpacing: 14,
      );
    case SurfaceType.whisper:
      return _CommandSurfaceSpec(
        padding: const EdgeInsets.all(14),
        radius: 20,
        blur: 0,
        fillColor: Color.lerp(
          surface.withValues(alpha: isDark ? 0.26 : 0.62),
          elevated.withValues(alpha: isDark ? 0.16 : 0.38),
          0.22,
        )!,
        gradient: null,
        borderColor: WorkspaceChrome.panelBorderColor(context, emphasis: 0.66),
        shadows: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(
              alpha: isDark ? 0.08 : 0.025,
            ),
            blurRadius: hovered ? 12 : 8,
            offset: Offset(0, hovered ? 8 : 5),
          ),
        ],
        overlayColor: primary.withValues(alpha: 0.05),
        topHighlightAlpha: 0,
        translateY: pressed
            ? 0
            : hovered
                ? -1
                : 0,
        scale: pressed ? 0.998 : 1,
        contentSpacing: 12,
      );
  }
}

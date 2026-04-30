import 'package:flutter/material.dart';
import 'package:gradeflow/components/animated_page_background.dart';
import 'package:gradeflow/components/command_surface.dart';
import 'package:gradeflow/components/workspace_shell.dart';

class ToolFirstAppSurface extends StatelessWidget {
  const ToolFirstAppSurface({
    super.key,
    required this.title,
    this.eyebrow,
    this.subtitle,
    this.leading,
    this.trailing = const [],
    this.contextStrip,
    this.toolbar,
    required this.workspace,
    this.bottomWorkspacePadding = 0,
    this.header,
  });

  final String title;
  final String? eyebrow;
  final String? subtitle;
  final Widget? leading;
  final List<Widget> trailing;
  final Widget? contextStrip;
  final Widget? toolbar;
  final Widget workspace;
  final double bottomWorkspacePadding;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedPageBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1680),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: WorkspaceShellFrame(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
                  radius: WorkspaceRadius.shellCompact,
                  child: Column(
                    children: [
                      header ??
                          WorkspaceSurfaceCard(
                            radius: WorkspaceRadius.context,
                            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                            child: _CompactAppBar(
                              eyebrow: eyebrow,
                              title: title,
                              subtitle: subtitle,
                              leading: leading,
                              trailing: trailing,
                            ),
                          ),
                      if (contextStrip != null) ...[
                        const SizedBox(height: WorkspaceSpacing.xs),
                        _SurfaceBand(child: contextStrip!),
                      ],
                      if (toolbar != null) ...[
                        const SizedBox(height: WorkspaceSpacing.xs),
                        _SurfaceBand(child: toolbar!),
                      ],
                      const SizedBox(height: WorkspaceSpacing.xs),
                      Expanded(
                        child: Padding(
                          padding:
                              EdgeInsets.only(bottom: bottomWorkspacePadding),
                          child: workspace,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactAppBar extends StatelessWidget {
  const _CompactAppBar({
    this.eyebrow,
    required this.title,
    required this.subtitle,
    this.leading,
    this.trailing = const [],
  });

  final String? eyebrow;
  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 980;
        final verticalTitleBlock = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if ((eyebrow ?? '').trim().isNotEmpty) ...[
              Text(
                eyebrow!.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: WorkspaceTypography.eyebrow(context),
              ),
              const SizedBox(height: 6),
            ],
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: WorkspaceTypography.pageTitle(
                context,
                compact: true,
              ),
            ),
            if ((subtitle ?? '').isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                subtitle!,
                maxLines: narrow ? 2 : 1,
                overflow: TextOverflow.ellipsis,
                style: WorkspaceTypography.pageSubtitle(
                  context,
                  compact: true,
                ),
              ),
            ],
          ],
        );
        final horizontalTitleBlock = Row(
          children: [
            if ((eyebrow ?? '').trim().isNotEmpty) ...[
              Text(
                eyebrow!.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: WorkspaceTypography.eyebrow(context),
              ),
              const SizedBox(width: WorkspaceSpacing.sm),
            ],
            Flexible(
              flex: 2,
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: WorkspaceTypography.pageTitle(
                  context,
                  compact: true,
                ),
              ),
            ),
            if ((subtitle ?? '').isNotEmpty) ...[
              const SizedBox(width: WorkspaceSpacing.sm),
              Flexible(
                child: Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: WorkspaceTypography.pageSubtitle(
                    context,
                    compact: true,
                  ),
                ),
              ),
            ],
          ],
        );

        final actionWrap = Wrap(
          alignment: WrapAlignment.end,
          runAlignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: WorkspaceSpacing.xs,
          runSpacing: 6,
          children: trailing,
        );

        if (narrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (leading != null) ...[
                    leading!,
                    const SizedBox(width: WorkspaceSpacing.md),
                  ],
                  Expanded(child: verticalTitleBlock),
                ],
              ),
              if (trailing.isNotEmpty) ...[
                const SizedBox(height: WorkspaceSpacing.md),
                actionWrap,
              ],
            ],
          );
        }

        return Row(
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: WorkspaceSpacing.sm),
            ],
            Expanded(child: horizontalTitleBlock),
            if (trailing.isNotEmpty) ...[
              const SizedBox(width: WorkspaceSpacing.sm),
              Flexible(child: actionWrap),
            ],
          ],
        );
      },
    );
  }
}

class _SurfaceBand extends StatelessWidget {
  const _SurfaceBand({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CommandSurfaceCard(
      surfaceType: SurfaceType.whisper,
      radius: WorkspaceRadius.context,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: child,
    );
  }
}

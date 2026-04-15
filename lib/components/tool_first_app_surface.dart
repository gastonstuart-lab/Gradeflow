import 'package:flutter/material.dart';
import 'package:gradeflow/components/animated_page_background.dart';
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
    this.bottomWorkspacePadding = 92,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedPageBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1480),
              child: Padding(
                padding: WorkspaceSpacing.shellMargin,
                child: WorkspaceShellFrame(
                  padding: WorkspaceSpacing.shellPaddingTight,
                  radius: WorkspaceRadius.shell,
                  child: Column(
                    children: [
                      WorkspaceSurfaceCard(
                        radius: WorkspaceRadius.feature,
                        padding: WorkspaceSpacing.headerPadding,
                        child: _CompactAppBar(
                          eyebrow: eyebrow,
                          title: title,
                          subtitle: subtitle,
                          leading: leading,
                          trailing: trailing,
                        ),
                      ),
                      if (contextStrip != null) ...[
                        const SizedBox(height: WorkspaceSpacing.sm),
                        _SurfaceBand(child: contextStrip!),
                      ],
                      if (toolbar != null) ...[
                        const SizedBox(height: WorkspaceSpacing.sm),
                        _SurfaceBand(child: toolbar!),
                      ],
                      const SizedBox(height: WorkspaceSpacing.lg),
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
        final titleBlock = Column(
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
                  Expanded(child: titleBlock),
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
              const SizedBox(width: WorkspaceSpacing.md),
            ],
            Expanded(child: titleBlock),
            if (trailing.isNotEmpty) ...[
              const SizedBox(width: WorkspaceSpacing.md),
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
    return WorkspaceSurfaceCard(
      radius: WorkspaceRadius.band,
      padding: WorkspaceSpacing.bandPadding,
      child: child,
    );
  }
}

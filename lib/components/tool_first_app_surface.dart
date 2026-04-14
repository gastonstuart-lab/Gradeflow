import 'package:flutter/material.dart';
import 'package:gradeflow/components/animated_page_background.dart';
import 'package:gradeflow/components/workspace_shell.dart';

class ToolFirstAppSurface extends StatelessWidget {
  const ToolFirstAppSurface({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing = const [],
    this.contextStrip,
    this.toolbar,
    required this.workspace,
    this.bottomWorkspacePadding = 92,
  });

  final String title;
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
              constraints: const BoxConstraints(maxWidth: 1440),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Column(
                  children: [
                    WorkspaceSurfaceCard(
                      radius: 20,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: _CompactAppBar(
                        title: title,
                        subtitle: subtitle,
                        leading: leading,
                        trailing: trailing,
                      ),
                    ),
                    if (contextStrip != null) ...[
                      const SizedBox(height: 8),
                      _SurfaceBand(child: contextStrip!),
                    ],
                    if (toolbar != null) ...[
                      const SizedBox(height: 8),
                      _SurfaceBand(child: toolbar!),
                    ],
                    const SizedBox(height: 10),
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
    );
  }
}

class _CompactAppBar extends StatelessWidget {
  const _CompactAppBar({
    required this.title,
    required this.subtitle,
    this.leading,
    this.trailing = const [],
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return _SurfaceBand(
      child: Row(
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if ((subtitle ?? '').isNotEmpty)
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          if (trailing.isNotEmpty) ...[
            const SizedBox(width: 10),
            Flexible(
              child: Wrap(
                alignment: WrapAlignment.end,
                runAlignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: trailing,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SurfaceBand extends StatelessWidget {
  const _SurfaceBand({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return WorkspaceSurfaceCard(
      radius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: child,
    );
  }
}

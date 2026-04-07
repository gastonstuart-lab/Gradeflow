/// GradeFlow OS — App Launcher
///
/// [OSLauncher] is the full-screen app grid overlay triggered by the
/// "All Apps" dock button or by pressing the apps button.
///
/// It shows all registered [OSApp] items in a grid grouped by category.
/// Tapping an app navigates to it (or prompts for class context if needed).
library os_launcher;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:gradeflow/os/os_app_model.dart';
import 'package:gradeflow/os/os_controller.dart';
import 'package:gradeflow/os/os_palette.dart';
import 'package:gradeflow/nav.dart';

class OSLauncher extends StatelessWidget {
  const OSLauncher({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final mq = MediaQuery.of(context);
    final isPhone = mq.size.shortestSide < 600;
    final controller = context.watch<GradeFlowOSController>();

    final apps = controller.isInTeachMode
        ? OSAppRegistry.teachModeApps
        : OSAppRegistry.launcherApps;

    final categories = _groupByCategory(apps);

    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: Container(
            margin: EdgeInsets.fromLTRB(
              isPhone ? 0 : 24,
              isPhone ? 0 : 20,
              isPhone ? 0 : 24,
              isPhone ? 0 : 20,
            ),
            constraints: const BoxConstraints(maxWidth: 640),
            decoration: BoxDecoration(
              color: OSColors.surface(dark),
              borderRadius:
                  isPhone ? BorderRadius.zero : OSRadius.xlBr,
              border: Border.all(
                color: OSColors.border(dark),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _LauncherHeader(onClose: onClose),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final entry in categories.entries) ...[
                          _CategoryHeader(name: _categoryLabel(entry.key)),
                          const SizedBox(height: 8),
                          _AppGrid(
                            apps: entry.value,
                            onTap: (app) => _launchApp(
                              context,
                              app: app,
                              controller: controller,
                              onClose: onClose,
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Map<OSAppCategory, List<OSApp>> _groupByCategory(List<OSApp> apps) {
    final map = <OSAppCategory, List<OSApp>>{};
    for (final app in apps) {
      map.putIfAbsent(app.category, () => []).add(app);
    }
    return map;
  }

  String _categoryLabel(OSAppCategory cat) {
    switch (cat) {
      case OSAppCategory.core:
        return 'Core';
      case OSAppCategory.classroom:
        return 'Classroom';
      case OSAppCategory.gradebook:
        return 'Gradebook';
      case OSAppCategory.communication:
        return 'Communication';
      case OSAppCategory.productivity:
        return 'Productivity';
      case OSAppCategory.system:
        return 'System';
    }
  }

  void _launchApp(
    BuildContext context, {
    required OSApp app,
    required GradeFlowOSController controller,
    required VoidCallback onClose,
  }) {
    onClose();
    if (app.id == OSAppId.assistant) {
      controller.openAssistant();
      return;
    }
    final route = app.route;
    if (route == null) {
      // Needs class context — go to classes list first
      context.go(AppRoutes.classes);
      return;
    }
    context.go(route);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PRIVATE WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _LauncherHeader extends StatelessWidget {
  const _LauncherHeader({required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
      child: Row(
        children: [
          Icon(
            Icons.apps_rounded,
            size: 20,
            color: OSColors.textSecondary(dark),
          ),
          const SizedBox(width: 10),
          Text(
            'All Apps',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: OSColors.text(dark),
              letterSpacing: -0.2,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded),
            iconSize: 20,
            color: OSColors.textSecondary(dark),
            style: IconButton.styleFrom(
              minimumSize: const Size(36, 36),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 2),
      child: Text(
        name.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: OSColors.textMuted(dark),
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _AppGrid extends StatelessWidget {
  const _AppGrid({required this.apps, required this.onTap});
  final List<OSApp> apps;
  final ValueChanged<OSApp> onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: apps.map((a) => _AppTile(app: a, onTap: () => onTap(a))).toList(),
    );
  }
}

class _AppTile extends StatefulWidget {
  const _AppTile({required this.app, required this.onTap});
  final OSApp app;
  final VoidCallback onTap;

  @override
  State<_AppTile> createState() => _AppTileState();
}

class _AppTileState extends State<_AppTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final app = widget.app;
    final color = app.color ?? OSColors.blue;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: OSMotion.fast,
          width: 80,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            color: _hover
                ? OSColors.blue.withValues(alpha: 0.06)
                : Colors.transparent,
            borderRadius: OSRadius.lgBr,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: OSSpacing.appIconSize,
                height: OSSpacing.appIconSize,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(OSSpacing.appIconRadius),
                  border: Border.all(
                    color: color.withValues(alpha: 0.25),
                    width: 1,
                  ),
                ),
                child: Icon(app.icon, color: color, size: 26),
              ),
              const SizedBox(height: 6),
              Text(
                app.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: OSColors.textSecondary(dark),
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

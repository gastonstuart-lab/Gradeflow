/// GradeFlow OS — Dock
///
/// [OSDock] is the always-present pill-shaped launcher bar at the bottom of
/// every OS surface.  It shows pinned app shortcuts and an "All Apps" launcher
/// trigger.
///
/// Adapts between phone (compact, fewer items) and tablet/desktop (full) layouts.

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:gradeflow/components/workspace_shell.dart';
import 'package:gradeflow/os/os_controller.dart';
import 'package:gradeflow/os/os_palette.dart';
import 'package:gradeflow/nav.dart';
import 'package:gradeflow/providers/app_providers.dart';

class OSDock extends StatelessWidget {
  const OSDock({super.key, this.teachMode = false});

  final bool teachMode;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<GradeFlowOSController>();
    final themeMode = context.watch<ThemeModeNotifier>().themeMode;
    final dark = context.isDark;
    final mq = MediaQuery.of(context);
    final isPhone = mq.size.shortestSide < 600;
    final isTeach = controller.isInTeachMode;

    final items = _buildDockItems(
      context,
      controller: controller,
      themeMode: themeMode,
      isTeach: isTeach,
      isPhone: isPhone,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: OSRadius.pillBr,
        boxShadow: WorkspaceChrome.panelShadow(
          context,
          emphasis: dark ? 1.55 : 1.2,
        ),
      ),
      child: ClipRRect(
        borderRadius: OSRadius.pillBr,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(
            sigmaX: WorkspaceChrome.shellBlur,
            sigmaY: WorkspaceChrome.shellBlur,
          ),
          child: Container(
            height: OSSpacing.dockHeight,
            decoration: BoxDecoration(
              borderRadius: OSRadius.pillBr,
              border: Border.all(
                color: WorkspaceChrome.panelBorderColor(
                  context,
                  emphasis: dark ? 0.24 : 0.30,
                ),
                width: 1,
              ),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: dark
                    ? [
                        OSColors.dock(dark).withValues(alpha: 0.90),
                        const Color(0xCC101926),
                      ]
                    : [
                        Colors.white.withValues(alpha: 0.92),
                        const Color(0xDDEFF4FB),
                      ],
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Container(
                      height: 1,
                      color: WorkspaceChrome.glassHighlight(
                        context,
                        shell: true,
                      ),
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(width: 12),
                    for (int i = 0; i < items.length; i++) ...[
                      if (i > 0)
                        _DockDivider(dark: dark, items: items, index: i),
                      _DockItem(data: items[i]),
                    ],
                    const SizedBox(width: 12),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<_DockItemData> _buildDockItems(
    BuildContext context, {
    required GradeFlowOSController controller,
    required ThemeMode themeMode,
    required bool isTeach,
    required bool isPhone,
  }) {
    final currentSurface = controller.activeSurface;

    if (isTeach) {
      return [
        _DockItemData(
          icon: Icons.home_rounded,
          label: 'Home',
          isActive: false,
          onTap: () => context.go(AppRoutes.osHome),
        ),
        _DockItemData(
          icon: Icons.draw_rounded,
          label: 'Whiteboard',
          isActive: true,
          onTap: () {},
        ),
        _DockItemData(
          icon: Icons.timer_outlined,
          label: 'Timer',
          onTap: () {},
        ),
        _DockItemData(
          icon: Icons.login_rounded,
          label: 'Exit',
          isActive: false,
          onTap: () => context.go(AppRoutes.osHome),
        ),
      ];
    }

    final baseItems = <_DockItemData>[
      _DockItemData(
        icon: Icons.home_rounded,
        label: 'Home',
        isActive: currentSurface == OSSurface.home,
        onTap: () => context.go(AppRoutes.osHome),
      ),
      _DockItemData(
        icon: Icons.calendar_month_rounded,
        label: 'Planner',
        isActive: currentSurface == OSSurface.planner,
        onTap: () => context.go(AppRoutes.osPlanner),
      ),
      _DockItemData(
        icon: Icons.class_rounded,
        label: 'Classes',
        isActive: currentSurface == OSSurface.classWorkspace,
        onTap: () => context.go(AppRoutes.classes),
      ),
      _DockItemData(
        icon: themeMode == ThemeMode.light
            ? Icons.dark_mode_rounded
            : Icons.light_mode_rounded,
        label: 'Theme',
        onTap: () => context.read<ThemeModeNotifier>().toggleTheme(),
      ),
    ];

    // Add All Apps button on non-phone
    final moreItems = isPhone
        ? baseItems
        : [
            ...baseItems,
            _DockItemData(
              icon: Icons.grid_view_rounded,
              label: 'All Apps',
              onTap: controller.openLauncher,
            ),
          ];

    return moreItems;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PRIVATE TYPES
// ─────────────────────────────────────────────────────────────────────────────

class _DockItemData {
  _DockItemData({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;
}

class _DockDivider extends StatelessWidget {
  const _DockDivider({
    required this.dark,
    required this.items,
    required this.index,
  });

  final bool dark;
  final List<_DockItemData> items;
  final int index;

  @override
  Widget build(BuildContext context) {
    // Only show vertical divider before "All Apps"
    final isBeforeLast =
        index == items.length - 1 && items.last.label == 'All Apps';
    if (!isBeforeLast) return const SizedBox.shrink();

    return Container(
      width: 1,
      height: 32,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: dark
          ? Colors.white.withValues(alpha: 0.1)
          : Colors.black.withValues(alpha: 0.08),
    );
  }
}

class _DockItem extends StatefulWidget {
  const _DockItem({required this.data});
  final _DockItemData data;

  @override
  State<_DockItem> createState() => _DockItemState();
}

class _DockItemState extends State<_DockItem>
    with SingleTickerProviderStateMixin {
  bool _hovered = false;
  late final AnimationController _ac = AnimationController(
    vsync: this,
    duration: OSMotion.fast,
    value: 0,
  );
  late final Animation<double> _scale = CurvedAnimation(
    parent: _ac,
    curve: Curves.easeOutCubic,
  );

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final d = widget.data;
    final hovered = _hovered && !d.isActive;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: (_) {
          _ac.forward();
        },
        onTapUp: (_) {
          _ac.reverse();
          d.onTap();
        },
        onTapCancel: () {
          _ac.reverse();
        },
        child: AnimatedBuilder(
          animation: _scale,
          builder: (_, child) => Transform.scale(
            scale: 1.0 - _scale.value * 0.08,
            child: child,
          ),
          child: Tooltip(
            message: d.label,
            preferBelow: false,
            child: SizedBox(
              width: OSSpacing.dockItemSize,
              height: OSSpacing.dockHeight,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (d.isActive)
                    Positioned(
                      bottom: 7,
                      child: Container(
                        width: 18,
                        height: 3,
                        decoration: BoxDecoration(
                          color: OSColors.blue,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  AnimatedContainer(
                    duration: OSMotion.fast,
                    curve: OSMotion.ease,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: d.isActive
                          ? OSColors.blue.withValues(alpha: dark ? 0.18 : 0.14)
                          : hovered
                              ? (dark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.white.withValues(alpha: 0.74))
                              : (dark
                                  ? Colors.white.withValues(alpha: 0.03)
                                  : Colors.white.withValues(alpha: 0.52)),
                      borderRadius: OSRadius.lgBr,
                      border: Border.all(
                        color: d.isActive
                            ? OSColors.blue.withValues(alpha: 0.28)
                            : hovered
                                ? WorkspaceChrome.panelBorderColor(
                                    context,
                                    emphasis: dark ? 0.34 : 0.42,
                                  )
                                : (dark
                                    ? Colors.white.withValues(alpha: 0.06)
                                    : Colors.black.withValues(alpha: 0.05)),
                      ),
                      boxShadow: d.isActive || hovered
                          ? [
                              BoxShadow(
                                color:
                                    (d.isActive ? OSColors.blue : Colors.black)
                                        .withValues(
                                  alpha:
                                      d.isActive ? 0.18 : (dark ? 0.10 : 0.06),
                                ),
                                blurRadius: 14,
                                offset: const Offset(0, 6),
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(
                      d.icon,
                      size: 24,
                      color: d.isActive
                          ? OSColors.blue
                          : hovered
                              ? OSColors.text(dark)
                              : OSColors.textSecondary(dark),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

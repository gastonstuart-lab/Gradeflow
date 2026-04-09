/// GradeFlow OS — Dock
///
/// [OSDock] is the always-present pill-shaped launcher bar at the bottom of
/// every OS surface.  It shows pinned app shortcuts and an "All Apps" launcher
/// trigger.
///
/// Adapts between phone (compact, fewer items) and tablet/desktop (full) layouts.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:gradeflow/os/os_controller.dart';
import 'package:gradeflow/os/os_palette.dart';
import 'package:gradeflow/nav.dart';
import 'package:gradeflow/services/communication_service.dart';

class OSDock extends StatelessWidget {
  const OSDock({super.key, this.teachMode = false});

  final bool teachMode;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<GradeFlowOSController>();
    final communication = context.watch<CommunicationService>();
    final dark = context.isDark;
    final mq = MediaQuery.of(context);
    final isPhone = mq.size.shortestSide < 600;
    final isTeach = controller.isInTeachMode;

    final items = _buildDockItems(
      context,
      controller: controller,
      communication: communication,
      isTeach: isTeach,
      isPhone: isPhone,
    );

    return PhysicalModel(
      color: Colors.transparent,
      borderRadius: OSRadius.pillBr,
      elevation: 24,
      shadowColor: Colors.black.withValues(alpha: 0.35),
      child: Container(
        height: OSSpacing.dockHeight,
        decoration: BoxDecoration(
          color: OSColors.dock(dark),
          borderRadius: OSRadius.pillBr,
          border: Border.all(
            color: dark
                ? Colors.white.withValues(alpha: 0.07)
                : Colors.black.withValues(alpha: 0.06),
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: OSRadius.pillBr,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 12),
              for (int i = 0; i < items.length; i++) ...[
                if (i > 0) _DockDivider(dark: dark, items: items, index: i),
                _DockItem(data: items[i]),
              ],
              const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }

  List<_DockItemData> _buildDockItems(
    BuildContext context, {
    required GradeFlowOSController controller,
    required CommunicationService communication,
    required bool isTeach,
    required bool isPhone,
  }) {
    final currentSurface = controller.activeSurface;
    final unread = communication.totalUnreadCount;

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
        icon: Icons.class_rounded,
        label: 'Classes',
        isActive: currentSurface == OSSurface.classWorkspace,
        onTap: () => context.go(AppRoutes.classes),
      ),
      _DockItemData(
        icon: Icons.draw_rounded,
        label: 'Studio',
        onTap: () => context.push(AppRoutes.whiteboard),
      ),
      _DockItemData(
        icon: Icons.forum_rounded,
        label: 'Messages',
        badge: unread > 0 ? '$unread' : null,
        onTap: () => context.go(AppRoutes.communication),
      ),
      _DockItemData(
        icon: Icons.cast_for_education_rounded,
        label: 'Teach',
        isActive: currentSurface == OSSurface.teach,
        onTap: () => context.go(AppRoutes.osTeach),
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
    this.badge,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;
  final String? badge;
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

    return GestureDetector(
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
                // Active indicator
                if (d.isActive)
                  Positioned(
                    bottom: 6,
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: OSColors.blue,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                // Icon
                AnimatedContainer(
                  duration: OSMotion.fast,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: d.isActive
                        ? OSColors.blue.withValues(alpha: 0.15)
                        : Colors.transparent,
                    borderRadius: OSRadius.lgBr,
                  ),
                  child: Icon(
                    d.icon,
                    size: 24,
                    color: d.isActive
                        ? OSColors.blue
                        : OSColors.textSecondary(dark),
                  ),
                ),
                // Badge
                if (d.badge != null)
                  Positioned(
                    top: 8,
                    right: 6,
                    child: _DockBadge(text: d.badge!),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DockBadge extends StatelessWidget {
  const _DockBadge({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 16),
      height: 16,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: OSColors.urgent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}

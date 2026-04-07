/// GradeFlow OS — Shell
///
/// [GradeFlowOSShell] is the master shell widget that wraps the three OS
/// surfaces (Home, Class, Teach) and any future OS-routed screen.
///
/// It is a [Stack] with:
///   1. Routed content (injected via [child])
///   2. [OSDock] — always-present bottom dock
///   3. [OSNotificationShade] — pull-down overlay
///   4. [OSLauncher] — full-screen app launcher overlay
///   5. [OSAssistantPanel] — AI entry slide-up panel
///   6. [OSIdleScreen] — full-screen idle / lock overlay
///
/// Routes that use this shell:
///   /os/home   → HomeSurface
///   /os/class/:classId → ClassSurface
///   /os/teach  → TeachSurface
library gradeflow_os_shell;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:gradeflow/nav.dart';
import 'package:gradeflow/os/os_controller.dart';
import 'package:gradeflow/os/os_palette.dart';
import 'package:gradeflow/os/os_dock.dart';
import 'package:gradeflow/os/os_launcher.dart';
import 'package:gradeflow/os/os_notification_shade.dart';
import 'package:gradeflow/os/os_assistant.dart';
import 'package:gradeflow/os/os_idle_screen.dart';

class GradeFlowOSShell extends StatefulWidget {
  const GradeFlowOSShell({
    super.key,
    required this.child,
    this.teachMode = false,
  });

  final Widget child;

  /// When true, the dock is hidden and teach-mode chrome is applied.
  final bool teachMode;

  @override
  State<GradeFlowOSShell> createState() => _GradeFlowOSShellState();
}

class _GradeFlowOSShellState extends State<GradeFlowOSShell> {
  static const double _swipeCommitDistance = 78;
  static const double _swipeCommitVelocity = 640;

  double _dragDx = 0;
  bool _dragging = false;

  bool _canSwipeNavigate(GradeFlowOSController controller) {
    return !controller.launcherOpen &&
        !controller.shadeOpen &&
        !controller.assistantOpen &&
        !controller.idleActive;
  }

  void _onHorizontalDragStart(GradeFlowOSController controller) {
    if (!_canSwipeNavigate(controller)) return;
    setState(() {
      _dragging = true;
      _dragDx = 0;
    });
  }

  void _onHorizontalDragUpdate(
    DragUpdateDetails details,
    GradeFlowOSController controller,
    double width,
  ) {
    if (!_dragging || !_canSwipeNavigate(controller)) return;
    final maxTravel = width * 0.36;
    setState(() {
      _dragDx = (_dragDx + details.delta.dx).clamp(-maxTravel, maxTravel);
    });
  }

  void _onHorizontalDragEnd(
    BuildContext context,
    DragEndDetails details,
    GradeFlowOSController controller,
  ) {
    if (!_dragging) return;
    final velocity = details.primaryVelocity ?? 0;
    final shouldCommit =
        _dragDx.abs() >= _swipeCommitDistance || velocity.abs() >= _swipeCommitVelocity;
    final step = _dragDx < 0 ? 1 : -1;
    final target = shouldCommit ? controller.adjacentSurface(step) : null;

    setState(() {
      _dragging = false;
      _dragDx = 0;
    });

    if (target == null) return;
    final route = _routeForSurface(controller, target);
    if (route != null && context.mounted) {
      context.go(route);
    }
  }

  String? _routeForSurface(GradeFlowOSController controller, OSSurface surface) {
    switch (surface) {
      case OSSurface.home:
        return AppRoutes.osHome;
      case OSSurface.classWorkspace:
        final classId = controller.activeClassId;
        if ((classId ?? '').isEmpty) return null;
        return '${AppRoutes.osClass}/$classId';
      case OSSurface.teach:
        return AppRoutes.osTeach;
      case OSSurface.other:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<GradeFlowOSController>();
    final mq = MediaQuery.of(context);
    final isPhone = mq.size.shortestSide < 600;

    // Reserve space for dock so content is not obscured.
    final dockReserve = widget.teachMode
      ? 0.0
      : OSSpacing.dockHeight + OSSpacing.dockBottomMargin + 8;

    final adjustedMQ = mq.copyWith(
      padding: mq.padding.copyWith(
        bottom: mq.padding.bottom + dockReserve,
      ),
    );
    final dragProgress = (_dragDx.abs() / (mq.size.width * 0.8)).clamp(0.0, 1.0);
    final surfaceOpacity = 1.0 - (dragProgress * 0.18);

    return Listener(
      onPointerDown: (_) => controller.registerActivity(),
      child: MediaQuery(
        data: adjustedMQ,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragStart: (_) => _onHorizontalDragStart(controller),
          onHorizontalDragUpdate: (details) =>
              _onHorizontalDragUpdate(details, controller, mq.size.width),
          onHorizontalDragEnd: (details) =>
              _onHorizontalDragEnd(context, details, controller),
          child: Stack(
            children: [
            // ── 1. Surface content ─────────────────────────────────────────
            Positioned.fill(
              child: Transform.translate(
                offset: Offset(_dragDx, 0),
                child: AnimatedOpacity(
                  duration: _dragging ? Duration.zero : OSMotion.fast,
                  opacity: surfaceOpacity,
                  child: PageStorage(
                    bucket: controller.pageStorageBucket,
                    child: widget.child,
                  ),
                ),
              ),
            ),

            // ── 2. Dock ────────────────────────────────────────────────────
            if (!widget.teachMode)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: OSSpacing.dockBottomMargin,
                      left: isPhone ? 12 : 24,
                      right: isPhone ? 12 : 24,
                    ),
                    child: Center(
                      child: OSDock(teachMode: widget.teachMode),
                    ),
                  ),
                ),
              ),

            // ── 3. Notification shade backdrop ─────────────────────────────
            if (controller.shadeOpen)
              Positioned.fill(
                child: GestureDetector(
                  onTap: controller.closeShade,
                  onVerticalDragEnd: (details) {
                    final velocity = details.primaryVelocity ?? 0;
                    if (velocity < -320) controller.closeShade();
                  },
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: OSMotion.fast,
                    color: Colors.black.withValues(alpha: 0.32),
                  ),
                ),
              ),

            // ── 4. Notification shade ──────────────────────────────────────
            AnimatedSlide(
              duration: OSMotion.overlayIn,
              curve: OSMotion.ease,
              offset: controller.shadeOpen
                  ? Offset.zero
                  : const Offset(0.0, -1.0),
              child: AnimatedOpacity(
                duration: OSMotion.fast,
                opacity: controller.shadeOpen ? 1.0 : 0.0,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isPhone ? double.infinity : 480,
                    ),
                    child: SafeArea(
                      bottom: false,
                      child: OSNotificationShade(
                        onDismiss: controller.closeShade,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── 5. Launcher backdrop ───────────────────────────────────────
            if (controller.launcherOpen)
              Positioned.fill(
                child: GestureDetector(
                  onTap: controller.closeLauncher,
                  onVerticalDragEnd: (details) {
                    final velocity = details.primaryVelocity ?? 0;
                    if (velocity > 340) controller.closeLauncher();
                  },
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: OSMotion.fast,
                    color: Colors.black.withValues(alpha: 0.50),
                  ),
                ),
              ),

            // ── 6. Launcher ────────────────────────────────────────────────
            if (controller.launcherOpen)
              Positioned.fill(
                child: OSLauncher(onClose: controller.closeLauncher),
              ),

            // ── 7. Assistant backdrop ──────────────────────────────────────
            if (controller.assistantOpen)
              Positioned.fill(
                child: GestureDetector(
                  onTap: controller.closeAssistant,
                  onVerticalDragEnd: (details) {
                    final velocity = details.primaryVelocity ?? 0;
                    if (velocity > 320) controller.closeAssistant();
                  },
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: OSMotion.fast,
                    color: Colors.black.withValues(alpha: 0.32),
                  ),
                ),
              ),

            // ── 8. Assistant panel ─────────────────────────────────────────
            AnimatedSlide(
              duration: OSMotion.overlayIn,
              curve: OSMotion.ease,
              offset: controller.assistantOpen
                  ? Offset.zero
                  : const Offset(0.0, 1.0),
              child: AnimatedOpacity(
                duration: OSMotion.fast,
                opacity: controller.assistantOpen ? 1.0 : 0.0,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isPhone ? double.infinity : 560,
                    ),
                    child: SafeArea(
                      top: false,
                      child: Material(
                        type: MaterialType.transparency,
                        child: OSAssistantPanel(
                          onClose: controller.closeAssistant,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── 9. Idle / Lock screen ──────────────────────────────────────
            AnimatedOpacity(
              duration: OSMotion.slow,
              opacity: controller.idleActive ? 1.0 : 0.0,
              child: IgnorePointer(
                ignoring: !controller.idleActive,
                child: OSIdleScreen(
                  onDismiss: controller.dismissIdle,
                ),
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }
}

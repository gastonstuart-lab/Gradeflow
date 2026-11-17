/// GradeFlow OS - Shell
///
/// [GradeFlowOSShell] wraps OS surfaces and legacy routed pages with the
/// shared dock and overlay chrome.

import 'package:flutter/foundation.dart';
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
import 'package:gradeflow/widgets/teacher_appearance_overlay.dart';
import 'package:gradeflow/widgets/teacher_account_menu.dart';

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
  final ValueNotifier<Offset?> _ambientPointer = ValueNotifier<Offset?>(null);

  @override
  void dispose() {
    _ambientPointer.dispose();
    super.dispose();
  }
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

  bool _enableSwipeNavigation() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return true;
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return false;
    }
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
    final shouldCommit = _dragDx.abs() >= _swipeCommitDistance ||
        velocity.abs() >= _swipeCommitVelocity;
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

  String? _routeForSurface(
    GradeFlowOSController controller,
    OSSurface surface,
  ) {
    switch (surface) {
      case OSSurface.home:
        return AppRoutes.osHome;
      case OSSurface.planner:
        return AppRoutes.osPlanner;
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

    // Home owns its scrolling bottom inset, so its background can continue
    // beneath the floating dock instead of ending in a solid footer stripe.
    // Planner, Classroom and all other routes retain their dock reservation.
    final homeBehindFloatingDock =
        !widget.teachMode && controller.activeSurface == OSSurface.home;
    final dockReserve = widget.teachMode
        ? 0.0
        : OSSpacing.dockHeight + OSSpacing.dockBottomMargin;

    // Keep the top-right account button in its own OS chrome strip.
    // Without reserving this height it can cover Gradebook's Export Excel
    // button (caught by authenticated emulator browser acceptance).
    // Home already places the menu within its approved integrated header.
    // Only legacy/detail surfaces (including Native Gradebook) need a new
    // top strip: Home, approved Planner and Classroom retain their tested
    // full-height geometry. Avoid narrowing the classroom drawing canvas.
    // Gradebook, class lists, exam screens and class setup all have their
    // own first-row actions. A floating avatar can overlap Export Excel or
    // Add Student even while painting in a small top-right area.
    // Reserve chrome space for those routes, not for the actual draggable
    // classroom canvas (where changing height could disrupt the layout).
    final currentPath = GoRouter.maybeOf(context)
            ?.routeInformationProvider.value.uri.path ?? '';
    final classroomCanvas = currentPath.endsWith('/classroom') ||
        currentPath.endsWith('/seating');
    final needsAccountBar = controller.activeSurface == OSSurface.other ||
        (controller.activeSurface == OSSurface.classWorkspace &&
            !classroomCanvas);
    final accountBarReserve = !widget.teachMode && needsAccountBar
        ? (isPhone ? 56.0 : 64.0)
        : 0.0;

    final adjustedMQ = mq.copyWith(
      padding: mq.padding.copyWith(
        bottom: mq.padding.bottom,
      ),
    );
    final dragProgress =
        (_dragDx.abs() / (mq.size.width * 0.8)).clamp(0.0, 1.0);
    final surfaceOpacity = 1.0 - (dragProgress * 0.18);
    final swipeNavigationEnabled = _enableSwipeNavigation();

    final shellStack = Stack(
      children: [
        Positioned.fill(
          top: accountBarReserve,
          bottom: homeBehindFloatingDock ? 0 : dockReserve,
          child: Transform.translate(
            offset: Offset(_dragDx, 0),
            child: AnimatedOpacity(
              duration: _dragging ? Duration.zero : OSMotion.fast,
              opacity: surfaceOpacity,
              child: MediaQuery(
                data: adjustedMQ,
                child: PageStorage(
                  bucket: controller.pageStorageBucket,
                  child: widget.child,
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: TeacherAppearanceOverlay(
            pointer: _ambientPointer,
            teachMode: widget.teachMode,
            attenuation: widget.teachMode
                ? 0.18
                : switch (controller.activeSurface) {
                    OSSurface.home => 1.0,
                    OSSurface.planner => 0.75,
                    OSSurface.classWorkspace => 0.50,
                    OSSurface.teach => 0.18,
                    OSSurface.other => 0.60,
                  },
          ),
        ),
        // Home has a dedicated spot beside Weather in its approved header.
        // Other pages reserve a slim top OS chrome strip so the menu never
        // sits over Export Excel, Planner actions or classroom controls.
        if (!widget.teachMode && controller.activeSurface != OSSurface.home)
          Positioned(
            top: mq.padding.top + 8,
            right: isPhone ? 8 : 18,
            child: const Material(
              type: MaterialType.transparency,
              child: TeacherAccountMenu(),
            ),
          ),
        if (!widget.teachMode)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Padding(
              padding: EdgeInsets.only(
                bottom: mq.padding.bottom + OSSpacing.dockBottomMargin,
                left: isPhone ? 12 : 24,
                right: isPhone ? 12 : 24,
              ),
              child: Center(
                child: OSDock(teachMode: widget.teachMode),
              ),
            ),
          ),
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
        IgnorePointer(
          ignoring: !controller.shadeOpen,
          child: AnimatedSlide(
            duration: OSMotion.overlayIn,
            curve: OSMotion.ease,
            offset:
                controller.shadeOpen ? Offset.zero : const Offset(0.0, -1.0),
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
        ),
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
        if (controller.launcherOpen)
          Positioned.fill(
            child: OSLauncher(onClose: controller.closeLauncher),
          ),
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
        IgnorePointer(
          ignoring: !controller.assistantOpen,
          child: AnimatedSlide(
            duration: OSMotion.overlayIn,
            curve: OSMotion.ease,
            offset:
                controller.assistantOpen ? Offset.zero : const Offset(0.0, 1.0),
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
        ),
        AnimatedOpacity(
          duration: OSMotion.slow,
          opacity: controller.idleActive ? 1.0 : 0.0,
          child: IgnorePointer(
            ignoring: !controller.idleActive,
            child: ExcludeSemantics(excluding: !controller.idleActive, child: OSIdleScreen(
              onDismiss: controller.dismissIdle,
            )),
          ),
        ),
      ],
    );

    // Other routed surfaces stop above the dock; Home paints through to the
    // bottom. This fallback still protects the unused part of other routes.
    return ColoredBox(
      color: widget.teachMode
          ? OSColors.teachBg
          : OSColors.appBackground(Theme.of(context).brightness == Brightness.dark),
      child: Listener(
      onPointerHover: (event) => _ambientPointer.value = event.localPosition,
      onPointerMove: (event) => _ambientPointer.value = event.localPosition,
      onPointerDown: (event) {
        _ambientPointer.value = event.localPosition;
        controller.registerActivity();
      },
      child: swipeNavigationEnabled
          ? GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragStart: (_) => _onHorizontalDragStart(controller),
              onHorizontalDragUpdate: (details) =>
                  _onHorizontalDragUpdate(details, controller, mq.size.width),
              onHorizontalDragEnd: (details) =>
                  _onHorizontalDragEnd(context, details, controller),
              child: shellStack,
            )
          : shellStack,
      ),
    );
  }
}

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

    // Home owns an inset scroll view with enough bottom padding to bring
    // its final cards ABOVE the dock. Let its painted background fill the
    // actual viewport instead of leaving a full-width blank footer.
    //
    // Other routed surfaces retain their established protected content area.
    // An opaque hit-test shield below covers the Home dock's footprint:
    // empty pill separators must never activate a Home shortcut behind it.
    final homeWithDock = !widget.teachMode &&
        controller.activeSurface == OSSurface.home;
    final dockBottomMargin = isPhone
        ? OSSpacing.phoneDockBottomMargin
        : OSSpacing.dockBottomMargin;
    final dockHeight = isPhone ? OSSpacing.phoneDockHeight : OSSpacing.dockHeight;
    final dockReserve = widget.teachMode || homeWithDock
        ? 0.0
        : dockHeight + dockBottomMargin;

    // The account/settings menu lives only in the approved Home header.
    // Other screens preserve their own controls and full working area; users
    // return Home via the dock to change personalisation or sign out.

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
        // The painter is a background layer, painted BEFORE all routed UI.
        // It cannot tint or cover grading cells, buttons, cards, text or menus.
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
        Positioned.fill(
          top: 0,
          bottom: dockReserve,
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
        if (homeWithDock)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: dockHeight + dockBottomMargin + mq.padding.bottom,
            // Only the last dock-sized strip blocks pointer events: the
            // page paints through it, but cards behind the floating pill
            // cannot steal taps from the real dock, even at its separators.
            // The Home scroll view has its own bottom inset so nothing is
            // stranded behind the shield after scrolling.
            child: const AbsorbPointer(
              absorbing: true,
              child: SizedBox.expand(),
            ),
          ),
        if (!widget.teachMode)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Padding(
              padding: EdgeInsets.only(
                bottom: mq.padding.bottom + dockBottomMargin,
                left: isPhone ? 12 : 24,
                right: isPhone ? 12 : 24,
              ),
              child: Center(
                // The floating pill is one gesture target, including
                // separators and padding between its launchers. An opaque
                // Listener alone can receive pointer events without winning
                // Flutter's tap gesture arena against a Home card beneath it.
                // Consume taps on empty dock space; nested launcher taps win
                // normally and are the only accessible actions.
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  excludeFromSemantics: true,
                  onTap: () {},
                  child: OSDock(teachMode: widget.teachMode),
                ),
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

    // The wallpaper and Home backdrop fill the viewport; content can
    // always scroll above the floating dock, with its hit zone protected.
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

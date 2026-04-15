/// GradeFlow OS — OS Controller
///
/// [GradeFlowOSController] is the central state machine for the OS shell.
/// It tracks overlay states (idle, launcher, notification shade, assistant),
/// home page index, selected class, and teach-mode flag.
///
/// Navigation between surfaces still happens through go_router; this
/// controller manages purely the OS chrome on top of routed content.

import 'dart:async';
import 'package:flutter/widgets.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SURFACE ENUM
// ─────────────────────────────────────────────────────────────────────────────

enum OSSurface {
  /// Teacher's personal home workspace.
  home,

  /// Focused single-class workspace.
  classWorkspace,

  /// Classroom-safe projection / teaching mode.
  teach,

  /// Any other routed screen (existing app).
  other,
}

// ─────────────────────────────────────────────────────────────────────────────
// CONTROLLER
// ─────────────────────────────────────────────────────────────────────────────

class GradeFlowOSController extends ChangeNotifier {
  GradeFlowOSController();

  final PageStorageBucket pageStorageBucket = PageStorageBucket();

  // ── OS surface ────────────────────────────────────────────────────────────

  OSSurface _activeSurface = OSSurface.home;
  String? _activeClassId;

  OSSurface get activeSurface => _activeSurface;
  String? get activeClassId => _activeClassId;

  void setSurface(OSSurface surface, {String? classId}) {
    final nextClassId = surface == OSSurface.teach && classId == null
        ? _activeClassId
        : classId;
    if (_activeSurface == surface && _activeClassId == nextClassId) return;
    _activeSurface = surface;
    _activeClassId = nextClassId;
    _closeAllOverlays();
    notifyListeners();
  }

  List<OSSurface> get swipeSurfaceSequence {
    if ((_activeClassId ?? '').isNotEmpty) {
      return const [
        OSSurface.home,
        OSSurface.classWorkspace,
        OSSurface.teach,
      ];
    }
    return const [
      OSSurface.home,
      OSSurface.teach,
    ];
  }

  OSSurface? adjacentSurface(int step) {
    if (step == 0) return null;
    final sequence = swipeSurfaceSequence;
    final index = sequence.indexOf(_activeSurface);
    if (index < 0) return null;
    final targetIndex = index + step;
    if (targetIndex < 0 || targetIndex >= sequence.length) {
      return null;
    }
    return sequence[targetIndex];
  }

  // ── Home page index (PageView within HomeSurface) ─────────────────────────

  int _homePageIndex = 0;
  int get homePageIndex => _homePageIndex;

  void setHomePageIndex(int index) {
    if (_homePageIndex == index) return;
    _homePageIndex = index;
    notifyListeners();
  }

  // ── Launcher ──────────────────────────────────────────────────────────────

  bool _launcherOpen = false;
  bool get launcherOpen => _launcherOpen;

  void openLauncher() {
    _launcherOpen = true;
    _shadeOpen = false;
    _assistantOpen = false;
    notifyListeners();
  }

  void closeLauncher() {
    if (!_launcherOpen) return;
    _launcherOpen = false;
    notifyListeners();
  }

  void toggleLauncher() {
    if (_launcherOpen) {
      closeLauncher();
    } else {
      openLauncher();
    }
  }

  // ── Notification Shade ────────────────────────────────────────────────────

  bool _shadeOpen = false;
  bool get shadeOpen => _shadeOpen;

  void openShade() {
    _shadeOpen = true;
    _launcherOpen = false;
    _assistantOpen = false;
    notifyListeners();
  }

  void closeShade() {
    if (!_shadeOpen) return;
    _shadeOpen = false;
    notifyListeners();
  }

  void toggleShade() {
    if (_shadeOpen) {
      closeShade();
    } else {
      openShade();
    }
  }

  // ── AI Assistant ──────────────────────────────────────────────────────────

  bool _assistantOpen = false;
  bool get assistantOpen => _assistantOpen;

  void openAssistant() {
    _assistantOpen = true;
    _launcherOpen = false;
    _shadeOpen = false;
    notifyListeners();
  }

  void closeAssistant() {
    if (!_assistantOpen) return;
    _assistantOpen = false;
    notifyListeners();
  }

  void toggleAssistant() {
    if (_assistantOpen) {
      closeAssistant();
    } else {
      openAssistant();
    }
  }

  // ── Idle / Lock Screen ────────────────────────────────────────────────────

  bool _idleActive = false;
  bool get idleActive => _idleActive;

  Timer? _idleTimer;

  /// Idle timeout in minutes (0 = never auto-idle).
  int _idleTimeoutMinutes = 5;
  int get idleTimeoutMinutes => _idleTimeoutMinutes;

  void setIdleTimeout(int minutes) {
    _idleTimeoutMinutes = minutes;
    _resetIdleTimer();
  }

  void triggerIdle() {
    _idleActive = true;
    _idleTimer?.cancel();
    notifyListeners();
  }

  void dismissIdle() {
    if (!_idleActive) return;
    _idleActive = false;
    _resetIdleTimer();
    notifyListeners();
  }

  /// Call this whenever the user interacts with the OS.
  void registerActivity() {
    if (_idleActive) return; // already idle — wait for explicit dismiss
    _resetIdleTimer();
  }

  void _resetIdleTimer() {
    _idleTimer?.cancel();
    if (_idleTimeoutMinutes <= 0) return;
    _idleTimer = Timer(Duration(minutes: _idleTimeoutMinutes), () {
      if (!_idleActive) triggerIdle();
    });
  }

  // ── Teach mode ────────────────────────────────────────────────────────────

  bool get isInTeachMode => _activeSurface == OSSurface.teach;

  // ── Private helpers ───────────────────────────────────────────────────────

  void _closeAllOverlays() {
    _launcherOpen = false;
    _shadeOpen = false;
    _assistantOpen = false;
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _idleTimer?.cancel();
    super.dispose();
  }
}

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:gradeflow/models/user.dart';
import 'package:gradeflow/services/auth_service.dart';
import 'package:gradeflow/services/dashboard_preferences_service.dart';
import 'package:gradeflow/services/teacher_workspace_snapshot_service.dart';

enum GlobalSystemUtility {
  dashboard,
  classes,
  studio,
  messages,
  admin,
}

class GlobalSystemShellController extends ChangeNotifier {
  static const String _dismissedNotificationsPrefsKey =
      'global_shell_dismissed_notifications_v1';

  GlobalSystemShellController({
    DashboardPreferencesService dashboardPreferencesService =
        const DashboardPreferencesService(),
    TeacherWorkspaceSnapshotService snapshotService =
        const TeacherWorkspaceSnapshotService(),
  })  : _dashboardPreferencesService = dashboardPreferencesService,
        _snapshotService = snapshotService;

  final DashboardPreferencesService _dashboardPreferencesService;
  final TeacherWorkspaceSnapshotService _snapshotService;

  String? _currentUserId;
  String? _currentLocation;
  String? _lastNonStudioLocation;
  bool _attentionOpen = false;
  bool _workspaceLoading = false;
  TeacherWorkspaceSnapshot? _workspaceSnapshot;
  Set<String> _dismissedNotificationIds = const <String>{};

  bool get attentionOpen => _attentionOpen;
  bool get isWorkspaceLoading => _workspaceLoading;
  TeacherWorkspaceSnapshot? get workspaceSnapshot => _workspaceSnapshot;
  String? get currentLocation => _currentLocation;
  String? get lastNonStudioLocation => _lastNonStudioLocation;

  GlobalSystemUtility? get activeUtility {
    if (_attentionOpen) {
      return null;
    }
    return utilityForLocation(_currentLocation);
  }

  Future<void> syncAuth(AuthService auth) async {
    final user = auth.currentUser;
    final nextUserId = user?.userId;
    if (_currentUserId == nextUserId) {
      return;
    }

    _currentUserId = nextUserId;
    _dismissedNotificationIds = const <String>{};
    _workspaceSnapshot = null;
    _workspaceLoading = false;
    _attentionOpen = false;
    notifyListeners();

    if (user == null) {
      return;
    }

    await _hydrateForUser(user);
  }

  void updateLocation(String location) {
    if (_currentLocation == location) {
      return;
    }

    final previousLocation = _currentLocation;
    _currentLocation = location;
    _attentionOpen = false;
    if (!_isStudioLocation(location)) {
      _lastNonStudioLocation = location;
    } else if (previousLocation != null &&
        !_isStudioLocation(previousLocation)) {
      _lastNonStudioLocation = previousLocation;
    }
    notifyListeners();
  }

  void openAttentionCenter() {
    if (_attentionOpen) {
      return;
    }
    _attentionOpen = true;
    notifyListeners();
  }

  void closeAttentionCenter() {
    if (!_attentionOpen) {
      return;
    }
    _attentionOpen = false;
    notifyListeners();
  }

  void toggleAttentionCenter() {
    _attentionOpen = !_attentionOpen;
    notifyListeners();
  }

  Future<void> refreshWorkspaceSnapshot(AuthService auth) async {
    final user = auth.currentUser;
    if (user == null) {
      return;
    }
    await _loadWorkspaceSnapshot(user);
  }

  bool isNotificationDismissed(String notificationId) {
    return _dismissedNotificationIds.contains(notificationId);
  }

  int dismissedCountForIds(Iterable<String> ids) {
    int count = 0;
    for (final id in ids) {
      if (_dismissedNotificationIds.contains(id)) {
        count += 1;
      }
    }
    return count;
  }

  List<T> visibleNotifications<T>(
    Iterable<T> items,
    String Function(T item) idSelector,
  ) {
    return items
        .where((item) => !_dismissedNotificationIds.contains(idSelector(item)))
        .toList(growable: false);
  }

  Future<void> dismissNotification(String notificationId) async {
    if (_dismissedNotificationIds.contains(notificationId)) {
      return;
    }
    _dismissedNotificationIds = {
      ..._dismissedNotificationIds,
      notificationId,
    };
    notifyListeners();
    await _persistDismissedNotifications();
  }

  Future<void> restoreDismissedNotifications({
    Iterable<String>? ids,
  }) async {
    if (_dismissedNotificationIds.isEmpty) {
      return;
    }

    if (ids == null) {
      _dismissedNotificationIds = const <String>{};
    } else {
      final next = Set<String>.from(_dismissedNotificationIds);
      next.removeAll(ids);
      _dismissedNotificationIds = next;
    }
    notifyListeners();
    await _persistDismissedNotifications();
  }

  GlobalSystemUtility? utilityForLocation(String? location) {
    if (location == null || location.isEmpty) {
      return null;
    }
    if (_isMessagesLocation(location)) {
      return GlobalSystemUtility.messages;
    }
    if (_isAdminLocation(location)) {
      return GlobalSystemUtility.admin;
    }
    if (_isStudioLocation(location)) {
      return GlobalSystemUtility.studio;
    }
    if (_isClassesLocation(location)) {
      return GlobalSystemUtility.classes;
    }
    if (_isDashboardLocation(location)) {
      return GlobalSystemUtility.dashboard;
    }
    return null;
  }

  bool _isDashboardLocation(String location) => location == '/dashboard';

  bool _isClassesLocation(String location) {
    return location == '/classes' ||
        location.startsWith('/class/') ||
        location == '/classes/trash';
  }

  bool _isMessagesLocation(String location) => location == '/communication';

  bool _isAdminLocation(String location) => location == '/admin';

  bool _isStudioLocation(String location) => location == '/whiteboard';

  Future<void> _hydrateForUser(User user) async {
    final scopedKey = _dashboardPreferencesService.scopedKey(
      baseKey: _dismissedNotificationsPrefsKey,
      userId: user.userId,
    );

    final dismissedFuture = _dashboardPreferencesService.readScopedJsonList(
      scopedKey: scopedKey,
    );

    _workspaceLoading = true;
    notifyListeners();

    try {
      final dismissedRaw = await dismissedFuture;
      if (_currentUserId != user.userId) {
        return;
      }

      _dismissedNotificationIds = dismissedRaw
          .map((value) => value?.toString() ?? '')
          .where((value) => value.trim().isNotEmpty)
          .toSet();
      notifyListeners();
    } catch (_) {
      // Ignore preference hydration failures and continue with an empty set.
    }

    await _loadWorkspaceSnapshot(user);
  }

  Future<void> _loadWorkspaceSnapshot(User user) async {
    _workspaceLoading = true;
    notifyListeners();

    try {
      final snapshot = await _snapshotService.loadForUser(user);
      if (_currentUserId != user.userId) {
        return;
      }
      _workspaceSnapshot = snapshot;
    } catch (_) {
      if (_currentUserId != user.userId) {
        return;
      }
      _workspaceSnapshot = null;
    } finally {
      if (_currentUserId == user.userId) {
        _workspaceLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> _persistDismissedNotifications() async {
    final userId = _currentUserId;
    if (userId == null) {
      return;
    }

    final scopedKey = _dashboardPreferencesService.scopedKey(
      baseKey: _dismissedNotificationsPrefsKey,
      userId: userId,
    );

    await _dashboardPreferencesService.writeJsonList(
      key: scopedKey,
      items: _dismissedNotificationIds.toList()..sort(),
    );
  }
}

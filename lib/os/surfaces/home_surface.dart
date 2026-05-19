// GradeFlow OS — Home Surface
//
// The teacher's primary landing surface should read like an actual OS home:
// a desktop stage, pinned apps, glanceable live signals, and secondary
// portals tucked off to the side instead of one long dashboard feed.

import 'dart:convert';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:gradeflow/components/workspace_shell.dart';
import 'package:gradeflow/models/class.dart';
import 'package:gradeflow/nav.dart';
import 'package:gradeflow/os/os_app_model.dart';
import 'package:gradeflow/os/os_controller.dart';
import 'package:gradeflow/os/os_palette.dart';
import 'package:gradeflow/os/os_touch_feedback.dart';
import 'package:gradeflow/providers/app_providers.dart';
import 'package:gradeflow/services/auth_service.dart';
import 'package:gradeflow/services/class_service.dart';
import 'package:gradeflow/services/communication_service.dart';
import 'package:gradeflow/services/dashboard_preferences_service.dart';
import 'package:gradeflow/services/dashboard_weather_service.dart';
import 'package:gradeflow/services/global_system_shell_service.dart';
import 'package:gradeflow/services/instructos_assistant_service.dart';
import 'package:gradeflow/services/teacher_workspace_snapshot_service.dart';
import 'package:gradeflow/repositories/repository_factory.dart';

class HomeSurface extends StatefulWidget {
  const HomeSurface({super.key});

  @override
  State<HomeSurface> createState() => _HomeSurfaceState();
}

class _HomeSurfaceState extends State<HomeSurface> {
  static const String _wallpaperStyleBaseKey = 'os_home_wallpaper_style_v1';
  static const String _wallpaperImageBaseKey = 'os_home_wallpaper_image_v1';
  static const String _readabilityBaseKey = 'os_home_readability_v1';

  final DashboardPreferencesService _preferences =
      const DashboardPreferencesService();
  _HomeWallpaperStyle _wallpaperStyle = _HomeWallpaperStyle.defaultStyle;
  _HomeReadabilityPreset _readabilityPreset = _HomeReadabilityPreset.balanced;
  Uint8List? _wallpaperImageBytes;
  String? _wallpaperImageBase64;
  String? _loadedUserId;
  bool _loadingWallpaper = false;
  Map<String, int> _classStudentCounts = const {};
  String _studentCountSignature = '';
  bool _loadingStudentCounts = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.read<AuthService>();
    final userId = _homeStorageUserId(auth);
    if (userId != null) {
      _syncWallpaperForUser(userId);
    }
  }

  void _syncWallpaperForUser(String userId) {
    if (_loadedUserId == userId) return;
    _loadedUserId = userId;
    _loadWallpaper(userId);
  }

  Future<void> _loadWallpaper(String userId) async {
    setState(() => _loadingWallpaper = true);
    try {
      final style = await _preferences.readScopedString(
        scopedKey: _preferences.scopedKey(
          baseKey: _wallpaperStyleBaseKey,
          userId: userId,
        ),
      );
      final image = await _preferences.readScopedString(
        scopedKey: _preferences.scopedKey(
          baseKey: _wallpaperImageBaseKey,
          userId: userId,
        ),
      );
      final readability = await _preferences.readScopedString(
        scopedKey: _preferences.scopedKey(
          baseKey: _readabilityBaseKey,
          userId: userId,
        ),
      );
      if (!mounted || _loadedUserId != userId) return;
      setState(() {
        _wallpaperStyle = _HomeWallpaperStyleX.fromId(style);
        _readabilityPreset = _HomeReadabilityPresetX.fromId(readability);
        _wallpaperImageBase64 = image;
        _wallpaperImageBytes = _decodeWallpaperImage(image);
        _loadingWallpaper = false;
      });
    } catch (_) {
      if (!mounted || _loadedUserId != userId) return;
      setState(() => _loadingWallpaper = false);
    }
  }

  Uint8List? _decodeWallpaperImage(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    try {
      return base64Decode(value);
    } catch (_) {
      return null;
    }
  }

  String? get _wallpaperUserId => _loadedUserId;

  String? _homeStorageUserId(AuthService auth) {
    if (!auth.isInitialized || auth.isLoading) return null;
    return auth.currentUser?.userId ?? 'local';
  }

  Future<void> _saveWallpaper({
    _HomeWallpaperStyle? style,
    String? imageBase64,
    bool updateImage = false,
  }) async {
    final nextStyle = style ?? _wallpaperStyle;
    final nextImage = updateImage ? imageBase64 : _wallpaperImageBase64;
    setState(() {
      _wallpaperStyle = nextStyle;
      if (updateImage) {
        _wallpaperImageBase64 = nextImage;
        _wallpaperImageBytes = _decodeWallpaperImage(nextImage);
      }
    });

    final userId = _wallpaperUserId;
    if (userId == null) return;
    await _preferences.writeString(
      key: _preferences.scopedKey(
        baseKey: _wallpaperStyleBaseKey,
        userId: userId,
      ),
      value: nextStyle.id,
    );
    if (updateImage) {
      await _preferences.writeString(
        key: _preferences.scopedKey(
          baseKey: _wallpaperImageBaseKey,
          userId: userId,
        ),
        value: nextImage,
      );
    }
  }

  Future<void> _saveReadabilityPreset(
    _HomeReadabilityPreset preset,
  ) async {
    setState(() => _readabilityPreset = preset);
    final userId = _wallpaperUserId;
    if (userId == null) return;
    await _preferences.writeString(
      key: _preferences.scopedKey(
        baseKey: _readabilityBaseKey,
        userId: userId,
      ),
      value: preset.id,
    );
  }

  Future<void> _pickWallpaperImage() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    final bytes = picked?.files.single.bytes;
    if (bytes == null || bytes.isEmpty) return;
    await _saveWallpaper(
      style: _HomeWallpaperStyle.customImage,
      imageBase64: base64Encode(bytes),
      updateImage: true,
    );
  }

  Future<void> _clearWallpaperImage() async {
    await _saveWallpaper(
      style: _HomeWallpaperStyle.defaultStyle,
      imageBase64: null,
      updateImage: true,
    );
  }

  Future<void> _showWallpaperSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Home background',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Choose a built-in wallpaper or add your own image. Dark mode stays available from the moon button.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final style in _HomeWallpaperStyle.values)
                          if (style != _HomeWallpaperStyle.customImage ||
                              _wallpaperImageBytes != null)
                            _WallpaperChoiceChip(
                              label: style.label,
                              selected: _wallpaperStyle == style,
                              accent: style.accent,
                              onTap: () {
                                Navigator.of(sheetContext).pop();
                                _saveWallpaper(style: style);
                              },
                            ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () {
                              Navigator.of(sheetContext).pop();
                              _pickWallpaperImage();
                            },
                            icon:
                                const Icon(Icons.add_photo_alternate_outlined),
                            label: Text(
                              _wallpaperImageBytes == null
                                  ? 'Add image'
                                  : 'Change image',
                            ),
                          ),
                        ),
                        if (_wallpaperImageBytes != null) ...[
                          const SizedBox(width: 10),
                          OutlinedButton.icon(
                            onPressed: () {
                              Navigator.of(sheetContext).pop();
                              _clearWallpaperImage();
                            },
                            icon: const Icon(Icons.wallpaper_outlined),
                            label: const Text('Reset'),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 22),
                    Text(
                      'Readability',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final preset in _HomeReadabilityPreset.values)
                          _ReadabilityPresetChip(
                            preset: preset,
                            selected: _readabilityPreset == preset,
                            onTap: () {
                              setSheetState(() {
                                _readabilityPreset = preset;
                              });
                              _saveReadabilityPreset(preset);
                            },
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final shell = context.watch<GlobalSystemShellController>();
    final snapshot = shell.workspaceSnapshot;
    final auth = context.watch<AuthService>();
    final user = auth.currentUser ?? snapshot?.user;
    final wallpaperUserId = _homeStorageUserId(auth);
    if (wallpaperUserId != null &&
        _loadedUserId != wallpaperUserId &&
        !_loadingWallpaper) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncWallpaperForUser(wallpaperUserId);
      });
    }
    final serviceClasses = context.watch<ClassService>().activeClasses;
    final classes = serviceClasses.isNotEmpty
        ? serviceClasses
        : (snapshot?.activeClasses ?? const <Class>[]);
    final reminders = snapshot?.pendingReminders ??
        const <TeacherWorkspaceReminderSnapshot>[];
    final totalStudents = snapshot?.totalStudents ?? 0;
    final unread = context.watch<CommunicationService>().totalUnreadCount;
    final now = DateTime.now();
    final primaryClass = _selectPrimaryClass(snapshot?.activeClasses, classes);
    final primaryReminder = reminders.isNotEmpty ? reminders.first : null;
    final teacherName = _firstName(user?.fullName ?? '');
    final schoolName = _schoolName(user?.schoolName);
    final controller = context.read<GradeFlowOSController>();
    final themeMode = context.watch<ThemeModeNotifier>().themeMode;
    final toggleTheme = context.read<ThemeModeNotifier>().toggleTheme;
    _scheduleStudentCountSync(classes);
    final resolvedTotalStudents =
        _resolvedTotalStudents(classes: classes, fallback: totalStudents);

    return _HomeReadabilityScope(
      preset: _readabilityPreset,
      child: Scaffold(
        backgroundColor: OSColors.bg(context.isDark),
        body: SafeArea(
          bottom: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop =
                  constraints.maxWidth >= 1220 && constraints.maxHeight >= 760;
              final horizontalPadding =
                  constraints.maxWidth < 760 ? 14.0 : 20.0;
              final contentPadding = EdgeInsets.fromLTRB(
                horizontalPadding,
                10,
                horizontalPadding,
                24,
              );

              return Stack(
                children: [
                  Positioned.fill(
                    child: _HomeBackdrop(
                      style: _wallpaperStyle,
                      imageBytes: _wallpaperImageBytes,
                      readability: _readabilityPreset,
                    ),
                  ),
                  if (_loadingWallpaper)
                    const Positioned(
                      width: 0,
                      height: 0,
                      child: SizedBox.shrink(),
                    ),
                  Positioned.fill(
                    child: isDesktop
                        ? Padding(
                            padding: contentPadding,
                            child: _HomeDesktopLayout(
                              teacherName: teacherName,
                              schoolName: schoolName,
                              primaryClass: primaryClass,
                              classes: classes,
                              reminders: reminders,
                              primaryReminder: primaryReminder,
                              totalStudents: resolvedTotalStudents,
                              classStudentCounts: _classStudentCounts,
                              unread: unread,
                              now: now,
                              themeMode: themeMode,
                              onShadeTap: controller.openShade,
                              onAssistantTap: controller.openAssistant,
                              onLauncherTap: controller.openLauncher,
                              onThemeTap: toggleTheme,
                              onWallpaperTap: _showWallpaperSheet,
                            ),
                          )
                        : SingleChildScrollView(
                            padding: contentPadding,
                            child: _HomeStackedLayout(
                              width: constraints.maxWidth,
                              teacherName: teacherName,
                              schoolName: schoolName,
                              primaryClass: primaryClass,
                              classes: classes,
                              reminders: reminders,
                              primaryReminder: primaryReminder,
                              totalStudents: resolvedTotalStudents,
                              classStudentCounts: _classStudentCounts,
                              unread: unread,
                              now: now,
                              themeMode: themeMode,
                              onShadeTap: controller.openShade,
                              onAssistantTap: controller.openAssistant,
                              onLauncherTap: controller.openLauncher,
                              onThemeTap: toggleTheme,
                              onWallpaperTap: _showWallpaperSheet,
                            ),
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Class? _selectPrimaryClass(
    List<Class>? snapshotClasses,
    List<Class> serviceClasses,
  ) {
    final candidates = snapshotClasses != null && snapshotClasses.isNotEmpty
        ? snapshotClasses
        : serviceClasses;
    return candidates.isNotEmpty ? candidates.first : null;
  }

  void _scheduleStudentCountSync(List<Class> classes) {
    final ids = classes.map((classItem) => classItem.classId).toList()..sort();
    final signature = ids.join('|');
    if (signature == _studentCountSignature || _loadingStudentCounts) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          signature == _studentCountSignature ||
          _loadingStudentCounts) {
        return;
      }
      _loadStudentCounts(classes, signature);
    });
  }

  Future<void> _loadStudentCounts(
    List<Class> classes,
    String signature,
  ) async {
    setState(() => _loadingStudentCounts = true);
    final counts = <String, int>{};
    try {
      final repository = RepositoryFactory.instance;
      for (final classItem in classes) {
        final students = await repository.loadStudents(classItem.classId);
        counts[classItem.classId] = students.length;
      }
    } catch (error) {
      debugPrint('Ask InstructOS context count load failed: $error');
    }

    if (!mounted) return;
    setState(() {
      _classStudentCounts = counts;
      _studentCountSignature = signature;
      _loadingStudentCounts = false;
    });
  }

  int _resolvedTotalStudents({
    required List<Class> classes,
    required int fallback,
  }) {
    if (classes.isNotEmpty &&
        classes.every((classItem) =>
            _classStudentCounts.containsKey(classItem.classId))) {
      return classes.fold<int>(
        0,
        (total, classItem) =>
            total + (_classStudentCounts[classItem.classId] ?? 0),
      );
    }
    return fallback;
  }
}

Widget _homeFolderTransition(Widget child, Animation<double> animation) {
  final curved = CurvedAnimation(
    parent: animation,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInOut,
  );
  return FadeTransition(
    opacity: curved,
    child: SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, -0.035),
        end: Offset.zero,
      ).animate(curved),
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.985, end: 1).animate(curved),
        child: child,
      ),
    ),
  );
}

class _HomeDesktopLayout extends StatefulWidget {
  const _HomeDesktopLayout({
    required this.teacherName,
    required this.schoolName,
    required this.primaryClass,
    required this.classes,
    required this.reminders,
    required this.primaryReminder,
    required this.totalStudents,
    required this.classStudentCounts,
    required this.unread,
    required this.now,
    required this.themeMode,
    required this.onShadeTap,
    required this.onAssistantTap,
    required this.onLauncherTap,
    required this.onThemeTap,
    required this.onWallpaperTap,
  });

  final String teacherName;
  final String schoolName;
  final Class? primaryClass;
  final List<Class> classes;
  final List<TeacherWorkspaceReminderSnapshot> reminders;
  final TeacherWorkspaceReminderSnapshot? primaryReminder;
  final int totalStudents;
  final Map<String, int> classStudentCounts;
  final int unread;
  final DateTime now;
  final ThemeMode themeMode;
  final VoidCallback onShadeTap;
  final VoidCallback onAssistantTap;
  final VoidCallback onLauncherTap;
  final VoidCallback onThemeTap;
  final VoidCallback onWallpaperTap;

  @override
  State<_HomeDesktopLayout> createState() => _HomeDesktopLayoutState();
}

class _HomeDesktopLayoutState extends State<_HomeDesktopLayout> {
  static const String _miniAppTapRegionGroup = 'home-mini-app-desktop';
  _HomeMiniApp? _selectedMiniApp;
  Class? _selectedClassPreview;

  void _closeMiniApp() {
    if (_selectedMiniApp != null) {
      setState(() {
        _selectedMiniApp = null;
        _selectedClassPreview = null;
      });
    }
  }

  void _openMiniApp(_HomeMiniApp app) {
    setState(() {
      _selectedMiniApp = app;
      if (app != _HomeMiniApp.classes) {
        _selectedClassPreview = null;
      }
    });
  }

  void _openDesktopClassPreview(Class classItem) {
    setState(() {
      _selectedMiniApp = _HomeMiniApp.classes;
      _selectedClassPreview = classItem;
    });
  }

  void _toggleFolder(_HomeWorkspaceFolder folder) {
    final app = _miniAppForFolder(folder);
    setState(() {
      _selectedMiniApp = _selectedMiniApp == app ? null : app;
      if (app != _HomeMiniApp.classes || _selectedMiniApp == null) {
        _selectedClassPreview = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const sideRailWidth = 260.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: sideRailWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _HomeSchoolIdentity(
                teacherName: widget.teacherName,
                schoolName: widget.schoolName,
                unread: widget.unread,
                themeMode: widget.themeMode,
                onAssistantTap: widget.onAssistantTap,
                onShadeTap: widget.onShadeTap,
                onThemeTap: widget.onThemeTap,
                onWallpaperTap: widget.onWallpaperTap,
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 174,
                child: _HomeShortcutShelf(
                  unread: widget.unread,
                  onLauncherTap: widget.onLauncherTap,
                  onMessagesTap: () => _openMiniApp(_HomeMiniApp.messages),
                  compact: true,
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: _HomeQuickClassesStrip(
                  classes: widget.classes,
                  onClassPreview: _openDesktopClassPreview,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final stageHeight =
                  (constraints.maxHeight * 0.18).clamp(142.0, 174.0);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: stageHeight,
                    child: _HomeStagePanel(
                      teacherName: widget.teacherName,
                      schoolName: widget.schoolName,
                      primaryClass: widget.primaryClass,
                      primaryReminder: widget.primaryReminder,
                      classCount: widget.classes.length,
                      totalStudents: widget.totalStudents,
                      unread: widget.unread,
                      reminderCount: widget.reminders.length,
                      now: widget.now,
                      compact: false,
                      onMessagesTap: () => _openMiniApp(_HomeMiniApp.messages),
                      onPlannerTap: () => _openMiniApp(_HomeMiniApp.agenda),
                      onClassesTap: () => _openMiniApp(_HomeMiniApp.classes),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.center,
                    child: _HomeWorkspaceFolderStrip(
                      selected: _folderForMiniApp(_selectedMiniApp),
                      classCount: widget.classes.length,
                      reminderCount: widget.reminders.length,
                      unread: widget.unread,
                      onSelected: _toggleFolder,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 980),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 240),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInOut,
                          transitionBuilder: _homeFolderTransition,
                          child: _selectedMiniApp == null
                              ? const _HomeCalmWorkspaceFloor(
                                  key: ValueKey('workspace-closed'),
                                )
                              : TapRegion(
                                  groupId: _miniAppTapRegionGroup,
                                  onTapOutside: (_) => _closeMiniApp(),
                                  child: _HomeMiniAppWindow(
                                    key: ValueKey(_selectedMiniApp),
                                    app: _selectedMiniApp!,
                                    primaryClass: widget.primaryClass,
                                    classes: widget.classes,
                                    reminders: widget.reminders,
                                    unread: widget.unread,
                                    totalStudents: widget.totalStudents,
                                    classStudentCounts:
                                        widget.classStudentCounts,
                                    now: widget.now,
                                    selectedClass: _selectedClassPreview,
                                    onClose: _closeMiniApp,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(width: 16),
        SizedBox(
          width: sideRailWidth,
          child: _HomeUtilityRail(
            unread: widget.unread,
            reminders: widget.reminders,
            reminderCount: widget.reminders.length,
            onAudioTap: () => _openMiniApp(_HomeMiniApp.audio),
            onMessagesTap: () => _openMiniApp(_HomeMiniApp.messages),
            onAgendaTap: () => _openMiniApp(_HomeMiniApp.agenda),
            onWeatherTap: () => _openMiniApp(_HomeMiniApp.weather),
          ),
        ),
      ],
    );
  }
}

enum _HomeMiniApp {
  weather,
  today,
  ask,
  classes,
  tasks,
  messages,
  insights,
  agenda,
  audio,
}

_HomeMiniApp _miniAppForFolder(_HomeWorkspaceFolder folder) {
  return switch (folder) {
    _HomeWorkspaceFolder.today => _HomeMiniApp.today,
    _HomeWorkspaceFolder.ask => _HomeMiniApp.ask,
    _HomeWorkspaceFolder.classes => _HomeMiniApp.classes,
    _HomeWorkspaceFolder.tasks => _HomeMiniApp.tasks,
    _HomeWorkspaceFolder.messages => _HomeMiniApp.messages,
    _HomeWorkspaceFolder.insights => _HomeMiniApp.insights,
  };
}

_HomeWorkspaceFolder? _folderForMiniApp(_HomeMiniApp? app) {
  return switch (app) {
    _HomeMiniApp.today => _HomeWorkspaceFolder.today,
    _HomeMiniApp.ask => _HomeWorkspaceFolder.ask,
    _HomeMiniApp.classes => _HomeWorkspaceFolder.classes,
    _HomeMiniApp.tasks => _HomeWorkspaceFolder.tasks,
    _HomeMiniApp.messages => _HomeWorkspaceFolder.messages,
    _HomeMiniApp.insights => _HomeWorkspaceFolder.insights,
    _HomeMiniApp.weather ||
    _HomeMiniApp.agenda ||
    _HomeMiniApp.audio ||
    null =>
      null,
  };
}

class _HomeUtilityRail extends StatelessWidget {
  const _HomeUtilityRail({
    required this.unread,
    required this.reminders,
    required this.reminderCount,
    required this.onAudioTap,
    required this.onMessagesTap,
    required this.onAgendaTap,
    required this.onWeatherTap,
  });

  final int unread;
  final List<TeacherWorkspaceReminderSnapshot> reminders;
  final int reminderCount;
  final VoidCallback onAudioTap;
  final VoidCallback onMessagesTap;
  final VoidCallback onAgendaTap;
  final VoidCallback onWeatherTap;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final signalText = [
      unread == 0 ? 'Inbox quiet' : '$unread unread',
      reminderCount == 0 ? 'agenda clear' : '$reminderCount queued',
    ].join(' / ');

    return _GlassPanel(
      tone: _HomePanelTone.rail,
      radius: 30,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: OSColors.blue.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: OSColors.blue.withValues(alpha: 0.18),
                    ),
                  ),
                  child: const Icon(
                    Icons.tune_rounded,
                    size: 18,
                    color: OSColors.blue,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _PanelEyebrow(label: 'Utility Rail'),
                      const SizedBox(height: 2),
                      Text(
                        signalText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: OSColors.textSecondary(dark),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _HomeWeatherPanel(embedded: true, onTap: onWeatherTap),
          const SizedBox(height: 8),
          _HomeAudioPanel(
            embedded: true,
            compact: true,
            onTap: onAudioTap,
          ),
          const SizedBox(height: 8),
          _RailSection(
            child: _HomeMessagesWidget(
              unread: unread,
              onTap: onMessagesTap,
              compact: true,
            ),
          ),
          const SizedBox(height: 8),
          _HomeAgendaPanel(
            reminders: reminders,
            scrollable: false,
            embedded: true,
            compact: true,
            onTap: onAgendaTap,
          ),
        ],
      ),
    );
  }
}

class _HomeMessagesWidget extends StatelessWidget {
  const _HomeMessagesWidget({
    required this.unread,
    required this.onTap,
    this.compact = false,
  });

  final int unread;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final hasUnread = unread > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OSTouchFeedback(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          minSize: Size(180, compact ? 74 : 92),
          child: Container(
            padding: EdgeInsets.all(compact ? 10 : 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  OSColors.cyan.withValues(alpha: dark ? 0.18 : 0.13),
                  OSColors.blue.withValues(alpha: dark ? 0.08 : 0.07),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: OSColors.cyan.withValues(alpha: hasUnread ? 0.28 : 0.14),
              ),
            ),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: compact ? 34 : 38,
                      height: compact ? 34 : 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color:
                            OSColors.cyan.withValues(alpha: dark ? 0.18 : 0.13),
                        border: Border.all(
                          color: OSColors.cyan.withValues(alpha: 0.24),
                        ),
                      ),
                      child: const Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 19,
                        color: OSColors.cyan,
                      ),
                    ),
                    if (hasUnread)
                      Positioned(
                        right: -1,
                        top: -1,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: OSColors.urgent,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color:
                                  dark ? const Color(0xFF0F172A) : Colors.white,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _PanelEyebrow(label: 'Messages'),
                      const SizedBox(height: 3),
                      Text(
                        hasUnread
                            ? '$unread unread update${unread == 1 ? '' : 's'}'
                            : 'Inbox quiet',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: compact ? 14 : 16,
                          fontWeight: FontWeight.w900,
                          color: OSColors.text(dark),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        hasUnread
                            ? 'Review conversations before handoff.'
                            : 'Threads are standing by.',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: OSColors.textSecondary(dark),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.open_in_new_rounded,
                  size: 15,
                  color: OSColors.textMuted(dark),
                ),
              ],
            ),
          ),
        ),
        if (!compact) ...[
          const SizedBox(height: 12),
          _FolderMessagePreview(
            sender: unread == 0 ? 'Staff room' : 'Unread channels',
            snippet: unread == 0
                ? 'Recent class and staff threads are ready.'
                : '$unread conversation${unread == 1 ? '' : 's'} waiting for review.',
            status: unread == 0 ? 'quiet' : 'now',
            unread: unread > 0,
            accent: OSColors.cyan,
            onTap: onTap,
          ),
        ],
        if (!compact) ...[
          const SizedBox(height: 8),
          _FolderMessagePreview(
            sender: 'Class channels',
            snippet: 'Families, students, and staff threads.',
            status: 'live',
            accent: OSColors.blue,
            onTap: onTap,
          ),
        ],
      ],
    );
  }
}

class _HomeQuickClassesStrip extends StatelessWidget {
  const _HomeQuickClassesStrip({
    required this.classes,
    this.onClassPreview,
  });

  final List<Class> classes;
  final ValueChanged<Class>? onClassPreview;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final visible = classes;

    return _GlassPanel(
      tone: _HomePanelTone.rail,
      radius: 26,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Open the next class workspace directly.',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              height: 1.2,
              fontWeight: FontWeight.w600,
              color: OSColors.textSecondary(dark),
            ),
          ),
          const SizedBox(height: 12),
          if (visible.isEmpty)
            _HomeQuickClassEmptyCard(
              onTap: () => context.go(AppRoutes.classes),
            )
          else
            Expanded(
              child: Scrollbar(
                thumbVisibility: visible.length > 2,
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: visible.length,
                  itemBuilder: (context, index) {
                    return _HomeQuickClassCard(
                      classItem: visible[index],
                      onOpenPreview: onClassPreview == null
                          ? null
                          : () => onClassPreview!(visible[index]),
                    );
                  },
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                ),
              ),
            ),
          const SizedBox(height: 12),
          Divider(
            height: 1,
            indent: 28,
            endIndent: 28,
            color: dark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.08),
          ),
        ],
      ),
    );
  }
}

class _HomeQuickClassCard extends StatelessWidget {
  const _HomeQuickClassCard({
    required this.classItem,
    this.dense = false,
    this.onOpenPreview,
  });

  final Class classItem;
  final bool dense;
  final VoidCallback? onOpenPreview;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final classId = classItem.classId;

    return OSTouchFeedback(
      onTap: onOpenPreview ??
          () => context.go(AppRoutes.osClassWorkspace(classId)),
      borderRadius: BorderRadius.circular(dense ? 16 : 18),
      minSize: Size(204, dense ? 92 : 112),
      child: Container(
        padding: EdgeInsets.fromLTRB(10, dense ? 8 : 10, 10, dense ? 8 : 10),
        decoration: BoxDecoration(
          color: dark
              ? Colors.white.withValues(alpha: 0.034)
              : Colors.white.withValues(alpha: 0.58),
          borderRadius: BorderRadius.circular(dense ? 16 : 18),
          border: Border.all(
            color: dark
                ? Colors.white.withValues(alpha: 0.052)
                : Colors.white.withValues(alpha: 0.64),
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                _HomeQuickClassIcon(size: dense ? 38 : 40),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        classItem.className,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.05,
                          fontWeight: FontWeight.w900,
                          color: OSColors.text(dark),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        classItem.subject,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.05,
                          fontWeight: FontWeight.w600,
                          color: OSColors.textSecondary(dark),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: OSColors.textMuted(dark),
                ),
              ],
            ),
            SizedBox(height: dense ? 8 : 10),
            Row(
              children: [
                _HomeQuickClassMiniAction(
                  tooltip: 'Workspace',
                  icon: Icons.grid_view_rounded,
                  accent: OSColors.green,
                  onTap: () => context.go(AppRoutes.osClassWorkspace(classId)),
                ),
                _HomeQuickClassMiniAction(
                  tooltip: 'Students',
                  icon: Icons.people_alt_outlined,
                  accent: OSColors.cyan,
                  onTap: () => context.go(AppRoutes.osClassStudents(classId)),
                ),
                _HomeQuickClassMiniAction(
                  tooltip: 'Seating',
                  icon: Icons.event_seat_rounded,
                  accent: OSColors.amber,
                  onTap: () => context.go(AppRoutes.osClassSeating(classId)),
                ),
                _HomeQuickClassMiniAction(
                  tooltip: 'Gradebook',
                  icon: Icons.menu_book_rounded,
                  accent: OSColors.coral,
                  onTap: () => context.go(AppRoutes.osClassGradebook(classId)),
                ),
                _HomeQuickClassMiniAction(
                  tooltip: 'Schedule',
                  icon: Icons.calendar_month_outlined,
                  accent: OSColors.blue,
                  onTap: () => context.go(AppRoutes.osClassSchedule(classId)),
                ),
                _HomeQuickClassMiniAction(
                  tooltip: 'Teach',
                  icon: Icons.cast_for_education_rounded,
                  accent: OSColors.indigo,
                  onTap: () {
                    context
                        .read<GradeFlowOSController>()
                        .setSurface(OSSurface.teach, classId: classId);
                    context.go(AppRoutes.osTeach);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeQuickClassMiniAction extends StatelessWidget {
  const _HomeQuickClassMiniAction({
    required this.tooltip,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Tooltip(
          message: tooltip,
          child: OSTouchFeedback(
            onTap: onTap,
            borderRadius: BorderRadius.circular(999),
            minSize: const Size(26, 28),
            child: AspectRatio(
              aspectRatio: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: dark ? 0.10 : 0.075),
                  border: Border.all(
                    color: accent.withValues(alpha: dark ? 0.26 : 0.18),
                    width: 1.2,
                  ),
                ),
                child: Icon(icon, size: 14, color: accent),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeQuickClassIcon extends StatelessWidget {
  const _HomeQuickClassIcon({this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            OSColors.green.withValues(alpha: 0.92),
            OSColors.cyan.withValues(alpha: 0.74),
          ],
        ),
        borderRadius: BorderRadius.circular(size * 0.35),
      ),
      child: Center(
        child: Container(
          width: size * 0.45,
          height: size * 0.55,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(size * 0.10),
          ),
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Icon(
                Icons.bookmark_rounded,
                size: size * 0.20,
                color: OSColors.green.withValues(alpha: 0.86),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeQuickClassEmptyCard extends StatelessWidget {
  const _HomeQuickClassEmptyCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;

    return OSTouchFeedback(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      minSize: const Size(204, 72),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: dark
              ? Colors.white.withValues(alpha: 0.045)
              : Colors.white.withValues(alpha: 0.68),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: dark
                ? Colors.white.withValues(alpha: 0.075)
                : Colors.white.withValues(alpha: 0.72),
          ),
        ),
        child: Row(
          children: [
            const _HomeQuickClassIcon(),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Open classes',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 17,
                      height: 1.05,
                      fontWeight: FontWeight.w900,
                      color: OSColors.text(dark),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Set up the first workspace',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.1,
                      fontWeight: FontWeight.w500,
                      color: OSColors.textSecondary(dark),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.chevron_right_rounded,
              size: 24,
              color: OSColors.textMuted(dark),
            ),
          ],
        ),
      ),
    );
  }
}

enum _HomeWorkspaceFolder {
  today(label: 'Today', icon: Icons.today_rounded, accent: OSColors.blue),
  ask(
    label: 'Ask InstructOS',
    icon: Icons.auto_awesome_rounded,
    accent: OSColors.indigo,
  ),
  classes(label: 'Classes', icon: Icons.class_rounded, accent: OSColors.green),
  tasks(label: 'Tasks', icon: Icons.task_alt_rounded, accent: OSColors.amber),
  messages(label: 'Messages', icon: Icons.forum_rounded, accent: OSColors.cyan),
  insights(
      label: 'Insights', icon: Icons.insights_rounded, accent: OSColors.indigo);

  const _HomeWorkspaceFolder({
    required this.label,
    required this.icon,
    required this.accent,
  });

  final String label;
  final IconData icon;
  final Color accent;
}

class _HomeWorkspaceFolderStrip extends StatelessWidget {
  const _HomeWorkspaceFolderStrip({
    required this.selected,
    required this.classCount,
    required this.reminderCount,
    required this.unread,
    required this.onSelected,
  });

  final _HomeWorkspaceFolder? selected;
  final int classCount;
  final int reminderCount;
  final int unread;
  final ValueChanged<_HomeWorkspaceFolder> onSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: Align(
              alignment: Alignment.center,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: context.isDark
                        ? Colors.white.withValues(alpha: 0.018)
                        : Colors.white.withValues(alpha: 0.24),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: context.isDark
                          ? Colors.white.withValues(alpha: 0.035)
                          : Colors.white.withValues(alpha: 0.36),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: Row(
                      children: [
                        for (final folder in _HomeWorkspaceFolder.values) ...[
                          _HomeWorkspaceFolderChip(
                            folder: folder,
                            selected: selected == folder,
                            detail: _folderDetail(folder),
                            onTap: () => onSelected(folder),
                          ),
                          if (folder != _HomeWorkspaceFolder.values.last)
                            const SizedBox(width: 8),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _folderDetail(_HomeWorkspaceFolder folder) {
    return switch (folder) {
      _HomeWorkspaceFolder.today => 'Next up',
      _HomeWorkspaceFolder.ask => 'Assistant',
      _HomeWorkspaceFolder.classes =>
        classCount == 0 ? 'No classes' : '$classCount active',
      _HomeWorkspaceFolder.tasks =>
        reminderCount == 0 ? 'Clear' : '$reminderCount queued',
      _HomeWorkspaceFolder.messages => unread == 0 ? 'Quiet' : '$unread unread',
      _HomeWorkspaceFolder.insights => 'Signals',
    };
  }
}

class _HomeWorkspaceFolderChip extends StatelessWidget {
  const _HomeWorkspaceFolderChip({
    required this.folder,
    required this.selected,
    required this.detail,
    required this.onTap,
  });

  final _HomeWorkspaceFolder folder;
  final bool selected;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final accent = folder.accent;

    final chip = AnimatedContainer(
      duration: const Duration(milliseconds: 190),
      curve: Curves.easeOutCubic,
      width: folder == _HomeWorkspaceFolder.ask ? 168 : 134,
      padding: EdgeInsets.fromLTRB(12, selected ? 9 : 10, 12, 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: selected
              ? [
                  accent.withValues(alpha: dark ? 0.18 : 0.12),
                  (dark ? Colors.white : Colors.white)
                      .withValues(alpha: dark ? 0.065 : 0.72),
                ]
              : [
                  (dark ? Colors.white : Colors.white)
                      .withValues(alpha: dark ? 0.045 : 0.58),
                  (dark ? Colors.white : Colors.white)
                      .withValues(alpha: dark ? 0.026 : 0.40),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(
          top: const Radius.circular(18),
          bottom: Radius.circular(selected ? 12 : 18),
        ),
        border: Border.all(
          color: selected
              ? accent.withValues(alpha: dark ? 0.42 : 0.30)
              : (dark
                  ? Colors.white.withValues(alpha: 0.075)
                  : Colors.white.withValues(alpha: 0.62)),
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: dark ? 0.16 : 0.10),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: dark ? 0.22 : 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Stack(
        children: [
          if (selected)
            Positioned(
              left: 44,
              right: 10,
              bottom: 0,
              child: Container(
                height: 2,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.55),
                  borderRadius: OSRadius.pillBr,
                ),
              ),
            ),
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: selected ? 0.22 : 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: accent.withValues(alpha: selected ? 0.25 : 0.12),
                  ),
                ),
                child: Icon(folder.icon, size: 17, color: accent),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      folder.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: OSColors.text(dark),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? OSColors.textSecondary(dark)
                            : OSColors.textMuted(dark),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return Transform.translate(
      offset: Offset(0, selected ? -3 : 0),
      child: OSTouchFeedback(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        minSize: const Size(126, 58),
        child: chip,
      ),
    );
  }
}

class _HomeCalmWorkspaceFloor extends StatelessWidget {
  const _HomeCalmWorkspaceFloor({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;

    return SizedBox(
      height: 224,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            top: 4,
            left: 56,
            right: 56,
            child: IgnorePointer(
              child: Container(
                height: 42,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(40),
                  ),
                  gradient: LinearGradient(
                    colors: [
                      OSColors.blue.withValues(alpha: dark ? 0.12 : 0.16),
                      Colors.white.withValues(alpha: dark ? 0.016 : 0.14),
                      OSColors.cyan.withValues(alpha: dark ? 0.07 : 0.10),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: -12,
            right: -12,
            top: 24,
            bottom: 0,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(-0.20, -0.55),
                    radius: 0.86,
                    colors: [
                      OSColors.blue.withValues(alpha: dark ? 0.10 : 0.13),
                      OSColors.cyan.withValues(alpha: dark ? 0.036 : 0.060),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 52,
            right: 52,
            top: 72,
            child: IgnorePointer(
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  borderRadius: OSRadius.pillBr,
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.white.withValues(alpha: dark ? 0.10 : 0.34),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 38,
            top: 42,
            child: IgnorePointer(
              child: Container(
                width: 112,
                height: 112,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      OSColors.indigo.withValues(alpha: dark ? 0.07 : 0.09),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeMiniAppWindow extends StatelessWidget {
  const _HomeMiniAppWindow({
    super.key,
    required this.app,
    required this.primaryClass,
    required this.classes,
    required this.reminders,
    required this.unread,
    required this.totalStudents,
    required this.classStudentCounts,
    required this.now,
    required this.selectedClass,
    required this.onClose,
  });

  final _HomeMiniApp app;
  final Class? primaryClass;
  final List<Class> classes;
  final List<TeacherWorkspaceReminderSnapshot> reminders;
  final int unread;
  final int totalStudents;
  final Map<String, int> classStudentCounts;
  final DateTime now;
  final Class? selectedClass;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final accent = _miniAppAccent(app);
    return _GlassPanel(
      tone: _HomePanelTone.whisper,
      radius: 28,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxHeight = constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : MediaQuery.sizeOf(context).height * 0.62;
          final preferredHeight = maxHeight.clamp(420.0, 660.0);
          final windowHeight = maxHeight < 420 ? maxHeight : preferredHeight;

          return SizedBox(
            height: windowHeight,
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: dark ? 0.16 : 0.11),
                        borderRadius: BorderRadius.circular(13),
                        border:
                            Border.all(color: accent.withValues(alpha: 0.22)),
                      ),
                      child: Icon(_miniAppIcon(app), size: 18, color: accent),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _PanelEyebrow(label: 'Mini Desktop'),
                          const SizedBox(height: 2),
                          Text(
                            _miniAppTitle(app),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: OSColors.text(dark),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_miniAppFullRoute(app) != null) ...[
                      _MiniWindowIconButton(
                        icon: Icons.open_in_new_rounded,
                        tooltip: 'Open full page',
                        onTap: () => context.go(_miniAppFullRoute(app)!),
                      ),
                      const SizedBox(width: 6),
                    ],
                    _MiniWindowIconButton(
                      icon: Icons.close_rounded,
                      tooltip: 'Close',
                      onTap: onClose,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: app == _HomeMiniApp.ask
                      ? _miniAppBody(context)
                      : SingleChildScrollView(
                          child: _miniAppBody(context),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _miniAppBody(BuildContext context) {
    return switch (app) {
      _HomeMiniApp.weather => const _WeatherMiniAppContent(),
      _HomeMiniApp.ask => _AskInstructOSMiniAppContent(
          primaryClass: primaryClass,
          selectedClass: selectedClass,
          classes: classes,
          reminders: reminders,
          totalStudents: totalStudents,
          classStudentCounts: classStudentCounts,
          unread: unread,
          now: now,
        ),
      _HomeMiniApp.messages => _MessagesMiniAppContent(unread: unread),
      _HomeMiniApp.agenda => _AgendaMiniAppContent(
          title: 'Review today\'s plan',
          primaryClass: primaryClass,
          reminders: reminders,
          now: now,
        ),
      _HomeMiniApp.audio => const _FocusAudioMiniAppContent(),
      _HomeMiniApp.today => _AgendaMiniAppContent(
          title: _formatLongDate(now),
          primaryClass: primaryClass,
          reminders: reminders,
          now: now,
          showClass: true,
        ),
      _HomeMiniApp.classes => selectedClass == null
          ? _ClassesFolderContent(classes: classes)
          : _ClassPreviewMiniAppContent(classItem: selectedClass!),
      _HomeMiniApp.tasks => _TasksFolderContent(reminders: reminders, now: now),
      _HomeMiniApp.insights => _InsightsFolderContent(
          classCount: classes.length,
          totalStudents: totalStudents,
          unread: unread,
          reminderCount: reminders.length,
        ),
    };
  }
}

class _MiniWindowIconButton extends StatelessWidget {
  const _MiniWindowIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return Tooltip(
      message: tooltip,
      child: OSTouchFeedback(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        minSize: const Size(34, 34),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: dark
                ? Colors.white.withValues(alpha: 0.055)
                : Colors.white.withValues(alpha: 0.60),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: dark
                  ? Colors.white.withValues(alpha: 0.070)
                  : Colors.white.withValues(alpha: 0.70),
            ),
          ),
          child: Icon(icon, size: 17, color: OSColors.textSecondary(dark)),
        ),
      ),
    );
  }
}

String _miniAppTitle(_HomeMiniApp app) {
  return switch (app) {
    _HomeMiniApp.weather => 'Weather',
    _HomeMiniApp.ask => 'Ask InstructOS',
    _HomeMiniApp.messages => 'Messages',
    _HomeMiniApp.agenda => 'Agenda / Today\'s Plan',
    _HomeMiniApp.audio => 'Focus Audio',
    _HomeMiniApp.today => 'Today',
    _HomeMiniApp.classes => 'Classes',
    _HomeMiniApp.tasks => 'Tasks',
    _HomeMiniApp.insights => 'Insights',
  };
}

IconData _miniAppIcon(_HomeMiniApp app) {
  return switch (app) {
    _HomeMiniApp.weather => Icons.wb_cloudy_rounded,
    _HomeMiniApp.ask => Icons.auto_awesome_rounded,
    _HomeMiniApp.messages => Icons.forum_rounded,
    _HomeMiniApp.agenda => Icons.event_available_rounded,
    _HomeMiniApp.audio => Icons.graphic_eq_rounded,
    _HomeMiniApp.today => Icons.today_rounded,
    _HomeMiniApp.classes => Icons.class_rounded,
    _HomeMiniApp.tasks => Icons.task_alt_rounded,
    _HomeMiniApp.insights => Icons.insights_rounded,
  };
}

Color _miniAppAccent(_HomeMiniApp app) {
  return switch (app) {
    _HomeMiniApp.weather => OSColors.blue,
    _HomeMiniApp.ask => OSColors.indigo,
    _HomeMiniApp.messages => OSColors.cyan,
    _HomeMiniApp.agenda => OSColors.amber,
    _HomeMiniApp.audio => OSColors.indigo,
    _HomeMiniApp.today => OSColors.blue,
    _HomeMiniApp.classes => OSColors.green,
    _HomeMiniApp.tasks => OSColors.amber,
    _HomeMiniApp.insights => OSColors.indigo,
  };
}

String? _miniAppFullRoute(_HomeMiniApp app) {
  return switch (app) {
    _HomeMiniApp.messages => AppRoutes.communication,
    _HomeMiniApp.agenda ||
    _HomeMiniApp.today ||
    _HomeMiniApp.tasks =>
      AppRoutes.osPlanner,
    _HomeMiniApp.classes || _HomeMiniApp.insights => AppRoutes.classes,
    _HomeMiniApp.weather || _HomeMiniApp.audio || _HomeMiniApp.ask => null,
  };
}

class _AskInstructOSMiniAppContent extends StatefulWidget {
  const _AskInstructOSMiniAppContent({
    required this.primaryClass,
    required this.selectedClass,
    required this.classes,
    required this.reminders,
    required this.totalStudents,
    required this.classStudentCounts,
    required this.unread,
    required this.now,
  });

  final Class? primaryClass;
  final Class? selectedClass;
  final List<Class> classes;
  final List<TeacherWorkspaceReminderSnapshot> reminders;
  final int totalStudents;
  final Map<String, int> classStudentCounts;
  final int unread;
  final DateTime now;

  @override
  State<_AskInstructOSMiniAppContent> createState() =>
      _AskInstructOSMiniAppContentState();
}

class _AskInstructOSMiniAppContentState
    extends State<_AskInstructOSMiniAppContent> {
  static const List<String> _suggestedPrompts = [
    'Plan my next lesson',
    'Draft a parent message',
    'Create a quick quiz',
    'Summarise today',
    'Help me with this class',
  ];

  final InstructOSAssistantService _assistantService =
      InstructOSAssistantService();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_AskInstructOSMessage> _messages = [];
  bool _isSending = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendCurrentMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;
    final assistantContext = _assistantHomeContext();
    if (kDebugMode) {
      debugPrint('Ask InstructOS context sent:\n$assistantContext');
    }
    final conversation = [
      InstructOSAssistantMessage(
        role: 'system',
        content: assistantContext,
      ),
      ..._messages.where((message) => !message.isPending).map(
            (message) => InstructOSAssistantMessage(
              role: message.fromAssistant ? 'assistant' : 'user',
              content: message.text,
            ),
          ),
    ];

    setState(() {
      _messages
        ..add(_AskInstructOSMessage(text: text, fromAssistant: false))
        ..add(const _AskInstructOSMessage(
          text: 'Thinking...',
          fromAssistant: true,
          isPending: true,
        ));
      _controller.clear();
      _isSending = true;
    });
    _scrollToBottom();

    final reply = await _assistantService.ask(
      message: text,
      conversation: conversation,
      contextMode: 'os-home',
    );
    if (!mounted) return;

    setState(() {
      final pendingIndex = _messages.lastIndexWhere(
        (message) => message.isPending,
      );
      final replyMessage = _AskInstructOSMessage(
        text: reply,
        fromAssistant: true,
      );
      if (pendingIndex == -1) {
        _messages.add(replyMessage);
      } else {
        _messages[pendingIndex] = replyMessage;
      }
      _isSending = false;
    });
    _scrollToBottom();
  }

  void _sendSuggestedPrompt(String prompt) {
    if (_isSending) return;
    _controller.text = prompt;
    _sendCurrentMessage();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  String _assistantHomeContext() {
    final classItem = widget.selectedClass ?? widget.primaryClass;
    final knownStudentTotal = widget.classes.isNotEmpty &&
        widget.classes.every((classItem) =>
            widget.classStudentCounts.containsKey(classItem.classId));
    final lines = <String>[
      'InstructOS home context.',
      'Today: ${_formatLongDate(widget.now)}.',
      'Workspace: ${widget.classes.length} active class${widget.classes.length == 1 ? '' : 'es'}, ${_studentTotalContextLabel(knownStudentTotal)}, ${widget.reminders.length} pending reminder${widget.reminders.length == 1 ? '' : 's'}, ${widget.unread} unread message${widget.unread == 1 ? '' : 's'}.',
    ];

    if (classItem == null) {
      lines.add('Active class: none pinned; use a general teaching plan.');
    } else {
      final count = widget.classStudentCounts[classItem.classId];
      lines.add(
        'Active class: ${classItem.className}; subject: ${classItem.subject}; students: ${count ?? 'unknown in current assistant context'}; term: ${classItem.term}; school year: ${classItem.schoolYear}.',
      );
      final syllabusEntries = classItem.syllabus?.entries
              .where((entry) => entry.lessonContent.trim().isNotEmpty)
              .take(2)
              .toList(growable: false) ??
          const <ClassSyllabusEntry>[];
      if (syllabusEntries.isNotEmpty) {
        lines.add('Syllabus signals:');
        for (final entry in syllabusEntries) {
          final dateRange = entry.dateRange.trim();
          final week = entry.week.trim();
          final label = [
            if (week.isNotEmpty) 'week $week',
            if (dateRange.isNotEmpty) dateRange,
          ].join(', ');
          lines.add(
            '- ${label.isEmpty ? 'entry' : label}: ${_trimLine(entry.lessonContent, 120)}',
          );
        }
      }
    }

    if (widget.classes.isNotEmpty) {
      lines.add('Visible class summaries:');
      for (final classSummary in widget.classes.take(8)) {
        final count = widget.classStudentCounts[classSummary.classId];
        final syllabusSignal = _firstSyllabusSignal(classSummary);
        lines.add(
          '- ${classSummary.className}; subject: ${classSummary.subject}; students: ${count ?? 'unknown'}; ${syllabusSignal == null ? 'next lesson signal: unknown' : 'lesson signal: $syllabusSignal'}',
        );
      }
    }

    if (widget.reminders.isNotEmpty) {
      final reminder = widget.reminders.first;
      lines.add(
        'Nearest reminder: ${_relativeReminderLabel(reminder, widget.now)} - ${_trimLine(reminder.text, 110)}',
      );
    }

    lines.add(
      'Answer factual questions from this context when possible. Never invent student counts or roster data. If a count is unknown, say exactly what is visible and what is missing. When class/topic context is incomplete, draft a useful starting plan first and ask one focused follow-up question.',
    );
    return lines.join('\n');
  }

  String _studentTotalContextLabel(bool knownStudentTotal) {
    if (knownStudentTotal) return '${widget.totalStudents} total students';
    return '${widget.totalStudents} total students reported by the home snapshot; per-class counts still loading or unavailable';
  }

  String? _firstSyllabusSignal(Class classItem) {
    final entries = classItem.syllabus?.entries ?? const <ClassSyllabusEntry>[];
    for (final entry in entries) {
      if (entry.lessonContent.trim().isNotEmpty) {
        return _trimLine(entry.lessonContent, 80);
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            decoration: BoxDecoration(
              color: dark
                  ? Colors.white.withValues(alpha: 0.026)
                  : Colors.white.withValues(alpha: 0.48),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: dark
                    ? Colors.white.withValues(alpha: 0.050)
                    : Colors.white.withValues(alpha: 0.64),
              ),
            ),
            child: _messages.isEmpty
                ? _AskInstructOSEmptyState(
                    prompts: _suggestedPrompts,
                    onPromptTap: _sendSuggestedPrompt,
                    enabled: !_isSending,
                  )
                : ListView.separated(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(bottom: 2),
                    itemCount: _messages.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 7),
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      return _AskInstructOSBubble(message: message);
                    },
                  ),
          ),
        ),
        const SizedBox(height: 10),
        if (_messages.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _AskPromptChips(
              prompts: _suggestedPrompts,
              onPromptTap: _sendSuggestedPrompt,
              compact: true,
              enabled: !_isSending,
            ),
          ),
        _AskInstructOSInputRow(
          controller: _controller,
          onSend: _sendCurrentMessage,
          isSending: _isSending,
        ),
      ],
    );
  }
}

class _AskInstructOSMessage {
  const _AskInstructOSMessage({
    required this.text,
    required this.fromAssistant,
    this.isPending = false,
  });

  final String text;
  final bool fromAssistant;
  final bool isPending;
}

class _AskInstructOSEmptyState extends StatelessWidget {
  const _AskInstructOSEmptyState({
    required this.prompts,
    required this.onPromptTap,
    required this.enabled,
  });

  final List<String> prompts;
  final ValueChanged<String> onPromptTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _AskAssistantMark(size: 38),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ready when you are',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: OSColors.text(dark),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'I can help plan lessons, draft messages, create quizzes, and organise your day.',
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.35,
                            color: OSColors.textSecondary(dark),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _AskPromptChips(
            prompts: prompts,
            onPromptTap: onPromptTap,
            enabled: enabled,
          ),
        ],
      ),
    );
  }
}

class _AskAssistantMark extends StatelessWidget {
  const _AskAssistantMark({this.size = 30});

  final double size;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            OSColors.indigo.withValues(alpha: dark ? 0.30 : 0.18),
            OSColors.cyan.withValues(alpha: dark ? 0.16 : 0.12),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.36),
        border: Border.all(
          color: OSColors.indigo.withValues(alpha: dark ? 0.30 : 0.22),
        ),
        boxShadow: [
          BoxShadow(
            color: OSColors.indigo.withValues(alpha: dark ? 0.12 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Text(
        'I/OS',
        maxLines: 1,
        style: TextStyle(
          fontSize: size * 0.26,
          fontWeight: FontWeight.w900,
          color: dark ? const Color(0xFFEFF6FF) : OSColors.indigo,
        ),
      ),
    );
  }
}

class _AskPromptChips extends StatelessWidget {
  const _AskPromptChips({
    required this.prompts,
    required this.onPromptTap,
    this.compact = false,
    this.enabled = true,
  });

  final List<String> prompts;
  final ValueChanged<String> onPromptTap;
  final bool compact;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return Wrap(
      spacing: compact ? 7 : 8,
      runSpacing: compact ? 7 : 8,
      children: [
        for (final prompt in prompts)
          OSTouchFeedback(
            onTap: enabled ? () => onPromptTap(prompt) : null,
            borderRadius: OSRadius.pillBr,
            minSize: Size(44, compact ? 30 : 32),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 9 : 11,
                vertical: compact ? 6 : 7,
              ),
              decoration: BoxDecoration(
                color: dark
                    ? Colors.white.withValues(alpha: 0.038)
                    : Colors.white.withValues(alpha: 0.58),
                borderRadius: OSRadius.pillBr,
                border: Border.all(
                  color: OSColors.indigo.withValues(alpha: dark ? 0.20 : 0.14),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.keyboard_command_key_rounded,
                    size: compact ? 11 : 12,
                    color: OSColors.indigo.withValues(alpha: dark ? .88 : .76),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    prompt,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: compact ? 11.3 : 11.8,
                      fontWeight: FontWeight.w800,
                      color: OSColors.textSecondary(dark),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _AskInstructOSBubble extends StatelessWidget {
  const _AskInstructOSBubble({required this.message});

  final _AskInstructOSMessage message;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final fromAssistant = message.fromAssistant;
    return Align(
      alignment: fromAssistant ? Alignment.centerLeft : Alignment.centerRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (fromAssistant) ...[
              const _AskAssistantMark(size: 26),
              const SizedBox(width: 7),
            ],
            Flexible(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: fromAssistant
                      ? (dark
                          ? Colors.white.withValues(alpha: 0.050)
                          : Colors.white.withValues(alpha: 0.72))
                      : OSColors.indigo.withValues(alpha: dark ? 0.22 : 0.14),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(fromAssistant ? 6 : 16),
                    bottomRight: Radius.circular(fromAssistant ? 16 : 6),
                  ),
                  border: Border.all(
                    color: fromAssistant
                        ? (dark
                            ? Colors.white.withValues(alpha: 0.058)
                            : Colors.white.withValues(alpha: 0.78))
                        : OSColors.indigo.withValues(alpha: 0.24),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: dark ? 0.10 : 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Text(
                  message.text,
                  style: TextStyle(
                    fontSize: 12.6,
                    height: 1.34,
                    color: OSColors.text(dark),
                  ),
                ),
              ),
            ),
            if (!fromAssistant) ...[
              const SizedBox(width: 7),
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  color: OSColors.indigo.withValues(alpha: dark ? 0.72 : 0.56),
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AskInstructOSInputRow extends StatelessWidget {
  const _AskInstructOSInputRow({
    required this.controller,
    required this.onSend,
    required this.isSending,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final bool isSending;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return Container(
      padding: const EdgeInsets.fromLTRB(7, 6, 6, 6),
      decoration: BoxDecoration(
        color: dark
            ? Colors.white.withValues(alpha: 0.050)
            : Colors.white.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: dark
              ? Colors.white.withValues(alpha: 0.078)
              : Colors.white.withValues(alpha: 0.86),
        ),
        boxShadow: WorkspaceChrome.panelShadow(context, emphasis: .22),
      ),
      child: Row(
        children: [
          const _AskAssistantMark(size: 28),
          const SizedBox(width: 8),
          Tooltip(
            message: 'Voice input coming soon',
            child: IconButton(
              onPressed: null,
              icon: const Icon(Icons.mic_none_rounded),
              iconSize: 19,
              visualDensity: VisualDensity.compact,
              style: IconButton.styleFrom(
                minimumSize: const Size(30, 30),
                disabledForegroundColor: OSColors.textMuted(dark),
              ),
            ),
          ),
          Container(
            width: 1,
            height: 22,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            color: OSColors.textMuted(dark).withValues(alpha: 0.16),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              enabled: !isSending,
              minLines: 1,
              maxLines: 3,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Command InstructOS...',
                hintStyle: TextStyle(
                  color: OSColors.textMuted(dark),
                  fontSize: 13,
                ),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
              ),
              style: TextStyle(
                fontSize: 13,
                color: OSColors.text(dark),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Tooltip(
            message: 'Send',
            child: OSTouchFeedback(
              onTap: isSending ? null : onSend,
              borderRadius: BorderRadius.circular(15),
              minSize: const Size(36, 36),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: OSColors.indigo.withValues(alpha: dark ? 0.26 : 0.18),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: OSColors.indigo.withValues(alpha: 0.26),
                  ),
                ),
                child: isSending
                    ? const SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: OSColors.indigo,
                        ),
                      )
                    : const Icon(
                        Icons.arrow_upward_rounded,
                        size: 18,
                        color: OSColors.indigo,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeatherMiniAppContent extends StatefulWidget {
  const _WeatherMiniAppContent();

  @override
  State<_WeatherMiniAppContent> createState() => _WeatherMiniAppContentState();
}

class _WeatherMiniAppContentState extends State<_WeatherMiniAppContent> {
  late final DashboardWeatherService _service = DashboardWeatherService();
  late final Future<DashboardWeatherSnapshot> _weather =
      _service.fetchForecast();

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return FutureBuilder<DashboardWeatherSnapshot>(
      future: _weather,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final loading = snapshot.connectionState == ConnectionState.waiting;
        final hasError = snapshot.hasError && data == null;
        final mood = _weatherMood(data?.weatherCode, DateTime.now(), dark);
        final textColor = _weatherTextColor(mood, dark);
        final mutedColor = _weatherMutedTextColor(mood, dark);
        final accent = _weatherAccentColor(mood, dark);
        final forecast =
            data?.forecast.take(5).toList() ?? const <DashboardForecastDay>[];
        final temp =
            hasError || loading ? '--' : '${data!.temperatureC.round()}Â°';
        final condition = hasError
            ? 'Forecast unavailable'
            : loading
                ? 'Checking forecast'
                : _weatherLabel(data!.weatherCode);
        final location = hasError
            ? 'Weather will return when the network responds.'
            : loading
                ? 'Taichung City'
                : data!.locationName;
        final feelsLike = data == null
            ? 'Feels-like unavailable'
            : 'Feels like ${data.apparentTempC.round()}Â°';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _WeatherWidgetFrame(
              mood: mood,
              embedded: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: WorkspaceTypography.eyebrow(context)?.copyWith(
                              color: textColor.withValues(alpha: .74)),
                        ),
                      ),
                      Icon(
                        data == null
                            ? Icons.cloud_queue_rounded
                            : _weatherIcon(data.weatherCode),
                        color: accent,
                        size: 30,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        temp,
                        style: TextStyle(
                          fontSize: 72,
                          height: .88,
                          fontWeight: FontWeight.w900,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                condition,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                feelsLike,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: mutedColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _WeatherTeacherNote(mood: mood),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (forecast.isNotEmpty) ...[
              SizedBox(
                height: 88,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: forecast.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    return SizedBox(
                      width: 128,
                      child: _WeatherForecastTile(
                        day: forecast[index],
                        textColor: OSColors.text(dark),
                        mutedColor: OSColors.textSecondary(dark),
                        iconColor: accent,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],
            _WeatherDetailGrid(
              condition: condition,
              feelsLike: feelsLike,
              accent: accent,
            ),
          ],
        );
      },
    );
  }
}

class _WeatherTeacherNote extends StatelessWidget {
  const _WeatherTeacherNote({required this.mood});

  final _WeatherMood mood;

  @override
  Widget build(BuildContext context) {
    final note = switch (mood) {
      _WeatherMood.rain => 'Rain signal - indoor transitions may be easier.',
      _WeatherMood.cloudy =>
        'Cloud cover - keep transitions calm and flexible.',
      _WeatherMood.sunny => 'Warm afternoon - keep water nearby.',
      _WeatherMood.night => 'Evening conditions - keep dismissal paths clear.',
    };
    return _StatusPill(
        label: note, accent: _weatherAccentColor(mood, context.isDark));
  }
}

class _WeatherDetailGrid extends StatelessWidget {
  const _WeatherDetailGrid({
    required this.condition,
    required this.feelsLike,
    required this.accent,
  });

  final String condition;
  final String feelsLike;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _FolderMetric(label: 'Condition', value: condition, accent: accent),
        _FolderMetric(
            label: 'Comfort', value: feelsLike, accent: OSColors.cyan),
        _FolderMetric(
          label: 'Transitions',
          value: 'Check',
          accent: OSColors.amber,
        ),
      ],
    );
  }
}

class _MessagesMiniAppContent extends StatelessWidget {
  const _MessagesMiniAppContent({required this.unread});

  final int unread;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final conversations = [
      (
        sender: unread == 0 ? 'Staff room' : 'Unread channels',
        snippet: unread == 0
            ? 'Recent class and staff threads are ready.'
            : '$unread conversation${unread == 1 ? '' : 's'} waiting for review.',
        status: unread == 0 ? 'quiet' : 'now',
        accent: OSColors.cyan,
        unread: unread > 0,
      ),
      (
        sender: 'Class channels',
        snippet: 'Families, students, and staff threads.',
        status: 'live',
        accent: OSColors.blue,
        unread: false,
      ),
      (
        sender: 'Announcements',
        snippet: 'School-wide updates and broadcast notes.',
        status: 'school',
        accent: OSColors.indigo,
        unread: false,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth > 560;
        final list = Column(
          children: [
            _MiniSearchField(label: 'Search conversations'),
            const SizedBox(height: 10),
            for (int index = 0; index < conversations.length; index++) ...[
              _FolderMessagePreview(
                sender: conversations[index].sender,
                snippet: conversations[index].snippet,
                status: conversations[index].status,
                unread: conversations[index].unread,
                accent: conversations[index].accent,
                onTap: () {},
              ),
              if (index != conversations.length - 1) const SizedBox(height: 8),
            ],
          ],
        );

        final thread = Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: dark
                ? Colors.white.withValues(alpha: 0.032)
                : Colors.white.withValues(alpha: 0.58),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: dark
                  ? Colors.white.withValues(alpha: 0.055)
                  : Colors.white.withValues(alpha: 0.68),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _MiniAvatar(label: unread == 0 ? 'S' : 'U'),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      unread == 0 ? 'Staff room' : 'Unread channels',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: OSColors.text(dark),
                      ),
                    ),
                  ),
                  _StatusPill(
                    label: unread == 0 ? 'quiet' : '$unread unread',
                    accent: unread == 0 ? OSColors.green : OSColors.urgent,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _MessageBubble(
                text: unread == 0
                    ? 'No urgent messages are waiting right now.'
                    : 'There are updates waiting for review before your next handoff.',
                incoming: true,
              ),
              const SizedBox(height: 8),
              const _MessageBubble(
                text: 'Class channels are ready for a quick scan from Home.',
                incoming: true,
              ),
              const SizedBox(height: 8),
              const _MessageBubble(
                text:
                    'Open full messages when you need to reply or manage channels.',
                incoming: false,
              ),
              const SizedBox(height: 8),
              const _MessageBubble(
                text: 'This quick view keeps the lesson surface open.',
                incoming: true,
              ),
              const SizedBox(height: 12),
              _MiniInputBar(label: 'Reply from full Messages'),
            ],
          ),
        );

        if (!wide) {
          return Column(children: [list, const SizedBox(height: 12), thread]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 250, child: list),
            const SizedBox(width: 12),
            Expanded(child: thread),
          ],
        );
      },
    );
  }
}

class _AgendaMiniAppContent extends StatelessWidget {
  const _AgendaMiniAppContent({
    required this.title,
    required this.primaryClass,
    required this.reminders,
    required this.now,
    this.showClass = false,
  });

  final String title;
  final Class? primaryClass;
  final List<TeacherWorkspaceReminderSnapshot> reminders;
  final DateTime now;
  final bool showClass;

  @override
  Widget build(BuildContext context) {
    final visible = reminders.take(4).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _PlannerDayCard(title: title, now: now),
            ),
            const SizedBox(width: 10),
            const _MiniMonthPreview(),
          ],
        ),
        if (showClass && primaryClass != null) ...[
          const SizedBox(height: 10),
          _FolderInfoRow(
            icon: Icons.class_rounded,
            accent: OSColors.green,
            label: 'Class workspace',
            value: '${primaryClass!.className} / ${primaryClass!.subject}',
            onTap: () => context.go(
              AppRoutes.osClassWorkspace(primaryClass!.classId),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          reminders.isEmpty ? 'Planner check' : 'Upcoming reminders',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: OSColors.text(context.isDark),
          ),
        ),
        const SizedBox(height: 8),
        if (visible.isEmpty)
          const _AgendaEmptyState()
        else
          for (int index = 0; index < visible.length; index++) ...[
            _ReminderTile(reminder: visible[index], now: now),
            if (index != visible.length - 1) const SizedBox(height: 8),
          ],
      ],
    );
  }
}

class _FocusAudioMiniAppContent extends StatelessWidget {
  const _FocusAudioMiniAppContent();

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final stations = [
      ('Classroom sound', 'Quiet work and transitions', OSColors.cyan),
      ('Deep focus', 'Low-distraction study bed', OSColors.indigo),
      ('Bell reset', 'Short transition cue', OSColors.amber),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: dark
                  ? const [Color(0xFF1B2137), Color(0xFF101827)]
                  : const [Color(0xFFFFFFFF), Color(0xFFEAF4FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: dark
                  ? Colors.white.withValues(alpha: 0.075)
                  : Colors.white.withValues(alpha: 0.80),
            ),
          ),
          child: Row(
            children: [
              const _AudioArtwork(),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _PanelEyebrow(label: 'Now Playing'),
                    const SizedBox(height: 5),
                    Text(
                      'Classroom sound',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: OSColors.text(dark),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Stations for quiet work and transitions.',
                      style: TextStyle(color: OSColors.textSecondary(dark)),
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: OSRadius.pillBr,
                      child: LinearProgressIndicator(
                        minHeight: 5,
                        value: 0.58,
                        backgroundColor:
                            Colors.white.withValues(alpha: dark ? 0.08 : 0.46),
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(OSColors.cyan),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _RoundPlayButton(size: 46),
            ],
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final signal = Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: dark
                    ? Colors.white.withValues(alpha: 0.030)
                    : Colors.white.withValues(alpha: 0.56),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: dark
                      ? Colors.white.withValues(alpha: 0.055)
                      : Colors.white.withValues(alpha: 0.68),
                ),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PanelEyebrow(label: 'Signal'),
                  SizedBox(height: 12),
                  _MiniEqualizer(),
                  SizedBox(height: 14),
                  _MiniInputBar(label: 'Add station'),
                ],
              ),
            );
            if (constraints.maxWidth < 560) {
              return Column(
                children: [
                  _StationList(stations: stations),
                  const SizedBox(height: 12),
                  signal,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _StationList(stations: stations)),
                const SizedBox(width: 12),
                Expanded(child: signal),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _MiniSearchField extends StatelessWidget {
  const _MiniSearchField({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: dark
            ? Colors.white.withValues(alpha: 0.035)
            : Colors.white.withValues(alpha: 0.62),
        borderRadius: OSRadius.pillBr,
        border: Border.all(
          color: dark
              ? Colors.white.withValues(alpha: 0.055)
              : Colors.white.withValues(alpha: 0.72),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 16, color: OSColors.textMuted(dark)),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: OSColors.textMuted(dark)),
          ),
        ],
      ),
    );
  }
}

class _MiniAvatar extends StatelessWidget {
  const _MiniAvatar({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            OSColors.cyan.withValues(alpha: 0.44),
            OSColors.indigo.withValues(alpha: 0.24),
          ],
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w900,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.accent});

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: context.isDark ? 0.16 : 0.10),
        borderRadius: OSRadius.pillBr,
        border: Border.all(color: accent.withValues(alpha: 0.20)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
          color: accent,
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.text, required this.incoming});

  final String text;
  final bool incoming;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return Align(
      alignment: incoming ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: incoming
              ? (dark
                  ? Colors.white.withValues(alpha: 0.050)
                  : Colors.white.withValues(alpha: 0.72))
              : OSColors.cyan.withValues(alpha: dark ? 0.18 : 0.12),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: incoming
                ? (dark
                    ? Colors.white.withValues(alpha: 0.060)
                    : Colors.white.withValues(alpha: 0.80))
                : OSColors.cyan.withValues(alpha: 0.20),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12.5,
            height: 1.35,
            color: OSColors.text(dark),
          ),
        ),
      ),
    );
  }
}

class _MiniInputBar extends StatelessWidget {
  const _MiniInputBar({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: dark
            ? Colors.white.withValues(alpha: 0.035)
            : Colors.white.withValues(alpha: 0.62),
        borderRadius: OSRadius.pillBr,
        border: Border.all(
          color: dark
              ? Colors.white.withValues(alpha: 0.055)
              : Colors.white.withValues(alpha: 0.72),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: OSColors.textMuted(dark)),
            ),
          ),
          Icon(Icons.arrow_forward_rounded,
              size: 16, color: OSColors.textMuted(dark)),
        ],
      ),
    );
  }
}

class _PlannerDayCard extends StatelessWidget {
  const _PlannerDayCard({required this.title, required this.now});

  final String title;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            OSColors.blue.withValues(alpha: dark ? 0.13 : 0.08),
            Colors.white.withValues(alpha: dark ? 0.035 : 0.62),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: dark
              ? Colors.white.withValues(alpha: 0.060)
              : Colors.white.withValues(alpha: 0.72),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PanelEyebrow(label: 'Plan'),
          const SizedBox(height: 6),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: OSColors.text(dark),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Check schedule before relying on imported timetable details.',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              color: OSColors.textSecondary(dark),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniMonthPreview extends StatelessWidget {
  const _MiniMonthPreview();

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return Container(
      width: 132,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: dark
            ? Colors.white.withValues(alpha: 0.032)
            : Colors.white.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: dark
              ? Colors.white.withValues(alpha: 0.055)
              : Colors.white.withValues(alpha: 0.68),
        ),
      ),
      child: Column(
        children: [
          const _PanelEyebrow(label: 'Month'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: [
              for (int index = 0; index < 14; index++)
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: index == 5
                        ? OSColors.amber
                        : OSColors.textMuted(dark).withValues(alpha: 0.20),
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoundPlayButton extends StatelessWidget {
  const _RoundPlayButton({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFF6D5DFB), Color(0xFF22D3EE)],
        ),
        boxShadow: [
          BoxShadow(
            color: OSColors.indigo.withValues(alpha: 0.18),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: const Icon(Icons.play_arrow_rounded, color: Colors.white),
    );
  }
}

class _StationList extends StatelessWidget {
  const _StationList({required this.stations});

  final List<(String, String, Color)> stations;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return Column(
      children: [
        for (int index = 0; index < stations.length; index++) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: dark
                  ? Colors.white.withValues(alpha: 0.032)
                  : Colors.white.withValues(alpha: 0.58),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: stations[index].$3.withValues(alpha: 0.16),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.radio_rounded, size: 18, color: stations[index].$3),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stations[index].$1,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                          color: OSColors.text(dark),
                        ),
                      ),
                      Text(
                        stations[index].$2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: OSColors.textSecondary(dark),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (index != stations.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _ClassesFolderContent extends StatelessWidget {
  const _ClassesFolderContent({required this.classes});

  final List<Class> classes;

  @override
  Widget build(BuildContext context) {
    final visible = classes.take(3).toList();
    return _FolderPanelScaffold(
      eyebrow: 'Classes',
      title: classes.isEmpty ? 'No active classes' : 'Active class spaces',
      subtitle: classes.isEmpty
          ? 'Create a class to begin staging teaching tools.'
          : 'Tap a class, or jump straight to a teaching tool.',
      actionLabel: classes.isEmpty ? 'Open Classes' : 'Open first class',
      actionIcon: Icons.class_rounded,
      onAction: () => context.go(
        classes.isEmpty
            ? AppRoutes.classes
            : AppRoutes.osClassWorkspace(classes.first.classId),
      ),
      secondaryLabel: classes.length > 1 ? 'View all' : null,
      onSecondary:
          classes.length > 1 ? () => context.go(AppRoutes.classes) : null,
      child: Column(
        children: [
          if (visible.isEmpty)
            const _FolderEmptyLine('Class workspaces will appear here.')
          else
            for (int index = 0; index < visible.length; index++) ...[
              _HomeQuickClassCard(classItem: visible[index], dense: true),
              if (index != visible.length - 1) const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _ClassPreviewMiniAppContent extends StatelessWidget {
  const _ClassPreviewMiniAppContent({required this.classItem});

  final Class classItem;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final classId = classItem.classId;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                OSColors.green.withValues(alpha: dark ? 0.16 : 0.10),
                OSColors.cyan.withValues(alpha: dark ? 0.08 : 0.06),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: OSColors.green.withValues(alpha: dark ? 0.18 : 0.14),
            ),
          ),
          child: Row(
            children: [
              const _HomeQuickClassIcon(size: 54),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _PanelEyebrow(label: 'Class Preview'),
                    const SizedBox(height: 6),
                    Text(
                      classItem.className,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 24,
                        height: 1.0,
                        fontWeight: FontWeight.w900,
                        color: OSColors.text(dark),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${classItem.subject} / ${classItem.term}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: OSColors.textSecondary(dark),
                      ),
                    ),
                  ],
                ),
              ),
              _FolderActionButton(
                label: 'Open full workspace',
                icon: Icons.open_in_new_rounded,
                onTap: () => context.go(AppRoutes.osClassWorkspace(classId)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _ClassPreviewAction(
              label: 'Workspace',
              icon: Icons.grid_view_rounded,
              accent: OSColors.green,
              onTap: () => context.go(AppRoutes.osClassWorkspace(classId)),
            ),
            _ClassPreviewAction(
              label: 'Students',
              icon: Icons.people_alt_outlined,
              accent: OSColors.cyan,
              onTap: () => context.go(AppRoutes.osClassStudents(classId)),
            ),
            _ClassPreviewAction(
              label: 'Seating',
              icon: Icons.event_seat_rounded,
              accent: OSColors.amber,
              onTap: () => context.go(AppRoutes.osClassSeating(classId)),
            ),
            _ClassPreviewAction(
              label: 'Gradebook',
              icon: Icons.menu_book_rounded,
              accent: OSColors.coral,
              onTap: () => context.go(AppRoutes.osClassGradebook(classId)),
            ),
            _ClassPreviewAction(
              label: 'Schedule',
              icon: Icons.calendar_month_outlined,
              accent: OSColors.blue,
              onTap: () => context.go(AppRoutes.osClassSchedule(classId)),
            ),
            _ClassPreviewAction(
              label: 'Teach',
              icon: Icons.cast_for_education_rounded,
              accent: OSColors.indigo,
              onTap: () {
                context
                    .read<GradeFlowOSController>()
                    .setSurface(OSSurface.teach, classId: classId);
                context.go(AppRoutes.osTeach);
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final cards = [
              _FolderMetric(
                label: 'Students',
                value: 'Roster',
                accent: OSColors.cyan,
                onTap: () => context.go(AppRoutes.osClassStudents(classId)),
              ),
              _FolderMetric(
                label: 'Seating',
                value: 'Room',
                accent: OSColors.amber,
                onTap: () => context.go(AppRoutes.osClassSeating(classId)),
              ),
              _FolderMetric(
                label: 'Gradebook',
                value: 'Scores',
                accent: OSColors.coral,
                onTap: () => context.go(AppRoutes.osClassGradebook(classId)),
              ),
              _FolderMetric(
                label: 'Schedule',
                value: 'Plan',
                accent: OSColors.blue,
                onTap: () => context.go(AppRoutes.osClassSchedule(classId)),
              ),
            ];
            return Wrap(spacing: 10, runSpacing: 10, children: cards);
          },
        ),
      ],
    );
  }
}

class _ClassPreviewAction extends StatelessWidget {
  const _ClassPreviewAction({
    required this.label,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return OSTouchFeedback(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      minSize: const Size(132, 54),
      child: Container(
        width: 142,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: dark
              ? Colors.white.withValues(alpha: 0.035)
              : Colors.white.withValues(alpha: 0.58),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: accent.withValues(alpha: 0.18)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: OSColors.text(dark),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TasksFolderContent extends StatelessWidget {
  const _TasksFolderContent({
    required this.reminders,
    required this.now,
  });

  final List<TeacherWorkspaceReminderSnapshot> reminders;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final visible = reminders.take(3).toList();
    return _FolderPanelScaffold(
      eyebrow: 'Tasks',
      title: reminders.isEmpty ? 'Clear for now' : 'Priority queue',
      subtitle: reminders.isEmpty
          ? 'No dated reminders are asking for attention.'
          : '${reminders.length} item${reminders.length == 1 ? '' : 's'} staged from planning.',
      actionLabel: 'Open Planner',
      actionIcon: Icons.calendar_month_rounded,
      onAction: () => context.go(AppRoutes.osPlanner),
      child: Column(
        children: [
          if (visible.isEmpty)
            const _FolderEmptyLine('Planning lane is calm.')
          else
            for (int index = 0; index < visible.length; index++) ...[
              _FolderInfoRow(
                icon: Icons.task_alt_rounded,
                accent: OSColors.amber,
                label: _relativeReminderLabel(visible[index], now),
                value: _trimLine(visible[index].text, 90),
                onTap: () => context.go(AppRoutes.osPlanner),
              ),
              if (index != visible.length - 1) const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _InsightsFolderContent extends StatelessWidget {
  const _InsightsFolderContent({
    required this.classCount,
    required this.totalStudents,
    required this.unread,
    required this.reminderCount,
  });

  final int classCount;
  final int totalStudents;
  final int unread;
  final int reminderCount;

  @override
  Widget build(BuildContext context) {
    return _FolderPanelScaffold(
      eyebrow: 'Insights',
      title: 'Teaching signals',
      subtitle: 'Compact load, attention, and class health indicators.',
      actionLabel: 'Open Classes',
      actionIcon: Icons.class_rounded,
      onAction: () => context.go(AppRoutes.classes),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _FolderMetric(
            label: 'Classes',
            value: '$classCount',
            accent: OSColors.green,
            onTap: () => context.go(AppRoutes.classes),
          ),
          _FolderMetric(
            label: 'Students',
            value: '$totalStudents',
            accent: OSColors.cyan,
            onTap: () => context.go(AppRoutes.classes),
          ),
          _FolderMetric(
            label: 'Messages',
            value: unread == 0 ? 'Quiet' : '$unread',
            accent: OSColors.blue,
            onTap: () => context.go(AppRoutes.communication),
          ),
          _FolderMetric(
            label: 'Tasks',
            value: reminderCount == 0 ? 'Clear' : '$reminderCount',
            accent: OSColors.amber,
            onTap: () => context.go(AppRoutes.osPlanner),
          ),
        ],
      ),
    );
  }
}

class _FolderPanelScaffold extends StatelessWidget {
  const _FolderPanelScaffold({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.child,
    required this.actionLabel,
    required this.actionIcon,
    required this.onAction,
    this.secondaryLabel,
    this.onSecondary,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final Widget child;
  final String actionLabel;
  final IconData actionIcon;
  final VoidCallback onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PanelEyebrow(label: eyebrow),
                  const SizedBox(height: 7),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                      color: OSColors.text(dark),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.38,
                      color: OSColors.textSecondary(dark),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _FolderActionButton(
              label: actionLabel,
              icon: actionIcon,
              onTap: onAction,
            ),
          ],
        ),
        const SizedBox(height: 14),
        child,
        if (secondaryLabel != null && onSecondary != null) ...[
          const SizedBox(height: 12),
          TextButton(
            onPressed: onSecondary,
            child: Text(secondaryLabel!),
          ),
        ],
      ],
    );
  }
}

class _FolderActionButton extends StatelessWidget {
  const _FolderActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: FilledButton.styleFrom(
        visualDensity: VisualDensity.compact,
        textStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _FolderInfoRow extends StatelessWidget {
  const _FolderInfoRow({
    required this.icon,
    required this.accent,
    required this.label,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final Color accent;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final row = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: dark
            ? Colors.white.withValues(alpha: 0.035)
            : Colors.white.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: dark
              ? Colors.white.withValues(alpha: 0.055)
              : Colors.white.withValues(alpha: 0.68),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: dark ? 0.14 : 0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: accent.withValues(alpha: dark ? 0.22 : 0.16),
              ),
            ),
            child: Icon(icon, size: 16, color: accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: OSColors.text(dark),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: OSColors.textSecondary(dark),
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: OSColors.textMuted(dark),
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return row;

    return OSTouchFeedback(
      onTap: onTap!,
      borderRadius: BorderRadius.circular(18),
      minSize: const Size(220, 46),
      child: row,
    );
  }
}

class _FolderMessagePreview extends StatelessWidget {
  const _FolderMessagePreview({
    required this.sender,
    required this.snippet,
    required this.status,
    required this.accent,
    required this.onTap,
    this.unread = false,
  });

  final String sender;
  final String snippet;
  final String status;
  final Color accent;
  final VoidCallback onTap;
  final bool unread;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final preview = Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: dark
            ? Colors.white.withValues(alpha: 0.035)
            : Colors.white.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: unread
              ? accent.withValues(alpha: 0.28)
              : (dark
                  ? Colors.white.withValues(alpha: 0.055)
                  : Colors.white.withValues(alpha: 0.68)),
        ),
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      accent.withValues(alpha: dark ? 0.42 : 0.30),
                      accent.withValues(alpha: dark ? 0.16 : 0.12),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Text(
                  sender.trim().isEmpty ? '?' : sender.trim()[0],
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: dark ? Colors.white : accent,
                  ),
                ),
              ),
              if (unread)
                Positioned(
                  right: -1,
                  top: -1,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: OSColors.urgent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: dark ? const Color(0xFF0F172A) : Colors.white,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        sender,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: OSColors.text(dark),
                        ),
                      ),
                    ),
                    Text(
                      status,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: unread ? accent : OSColors.textMuted(dark),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  snippet,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: OSColors.textSecondary(dark),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: OSColors.textMuted(dark),
          ),
        ],
      ),
    );

    return OSTouchFeedback(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      minSize: const Size(220, 54),
      child: preview,
    );
  }
}

class _FolderMetric extends StatelessWidget {
  const _FolderMetric({
    required this.label,
    required this.value,
    required this.accent,
    this.onTap,
  });

  final String label;
  final String value;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final metric = Container(
      width: 132,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: dark ? 0.10 : 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: OSColors.text(dark),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: OSColors.textMuted(dark),
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return metric;

    return OSTouchFeedback(
      onTap: onTap!,
      borderRadius: BorderRadius.circular(18),
      minSize: const Size(132, 72),
      child: metric,
    );
  }
}

class _FolderEmptyLine extends StatelessWidget {
  const _FolderEmptyLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return _FolderInfoRow(
      icon: Icons.hourglass_empty_rounded,
      accent: OSColors.blue,
      label: 'Quiet',
      value: text,
    );
  }
}

class _HomeStackedLayout extends StatefulWidget {
  const _HomeStackedLayout({
    required this.width,
    required this.teacherName,
    required this.schoolName,
    required this.primaryClass,
    required this.classes,
    required this.reminders,
    required this.primaryReminder,
    required this.totalStudents,
    required this.classStudentCounts,
    required this.unread,
    required this.now,
    required this.themeMode,
    required this.onShadeTap,
    required this.onAssistantTap,
    required this.onLauncherTap,
    required this.onThemeTap,
    required this.onWallpaperTap,
  });

  final double width;
  final String teacherName;
  final String schoolName;
  final Class? primaryClass;
  final List<Class> classes;
  final List<TeacherWorkspaceReminderSnapshot> reminders;
  final TeacherWorkspaceReminderSnapshot? primaryReminder;
  final int totalStudents;
  final Map<String, int> classStudentCounts;
  final int unread;
  final DateTime now;
  final ThemeMode themeMode;
  final VoidCallback onShadeTap;
  final VoidCallback onAssistantTap;
  final VoidCallback onLauncherTap;
  final VoidCallback onThemeTap;
  final VoidCallback onWallpaperTap;

  @override
  State<_HomeStackedLayout> createState() => _HomeStackedLayoutState();
}

class _HomeStackedLayoutState extends State<_HomeStackedLayout> {
  static const String _miniAppTapRegionGroup = 'home-mini-app-stacked';
  _HomeMiniApp? _selectedMiniApp;
  Class? _selectedClassPreview;

  void _closeMiniApp() {
    if (_selectedMiniApp != null) {
      setState(() {
        _selectedMiniApp = null;
        _selectedClassPreview = null;
      });
    }
  }

  void _openMiniApp(_HomeMiniApp app) {
    setState(() {
      _selectedMiniApp = app;
      if (app != _HomeMiniApp.classes) {
        _selectedClassPreview = null;
      }
    });
  }

  // Reserved for stacked class previews if quick classes move into compact home.
  // ignore: unused_element
  void _openClassPreview(Class classItem) {
    setState(() {
      _selectedMiniApp = _HomeMiniApp.classes;
      _selectedClassPreview = classItem;
    });
  }

  void _toggleFolder(_HomeWorkspaceFolder folder) {
    final app = _miniAppForFolder(folder);
    setState(() {
      _selectedMiniApp = _selectedMiniApp == app ? null : app;
      if (app != _HomeMiniApp.classes || _selectedMiniApp == null) {
        _selectedClassPreview = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final stageHeight = widget.width < 700 ? 404.0 : 448.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HomeSystemStrip(
          teacherName: widget.teacherName,
          schoolName: widget.schoolName,
          unread: widget.unread,
          now: widget.now,
          themeMode: widget.themeMode,
          onShadeTap: widget.onShadeTap,
          onAssistantTap: widget.onAssistantTap,
          onThemeTap: widget.onThemeTap,
          onWallpaperTap: widget.onWallpaperTap,
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: stageHeight,
          child: _HomeStagePanel(
            teacherName: widget.teacherName,
            schoolName: widget.schoolName,
            primaryClass: widget.primaryClass,
            primaryReminder: widget.primaryReminder,
            classCount: widget.classes.length,
            totalStudents: widget.totalStudents,
            unread: widget.unread,
            reminderCount: widget.reminders.length,
            now: widget.now,
            compact: true,
            onMessagesTap: () => _openMiniApp(_HomeMiniApp.messages),
            onPlannerTap: () => _openMiniApp(_HomeMiniApp.agenda),
            onClassesTap: () => _openMiniApp(_HomeMiniApp.classes),
          ),
        ),
        const SizedBox(height: 14),
        _HomeWorkspaceFolderStrip(
          selected: _folderForMiniApp(_selectedMiniApp),
          classCount: widget.classes.length,
          reminderCount: widget.reminders.length,
          unread: widget.unread,
          onSelected: _toggleFolder,
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 240),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInOut,
          transitionBuilder: _homeFolderTransition,
          child: _selectedMiniApp == null
              ? const Padding(
                  key: ValueKey('workspace-closed'),
                  padding: EdgeInsets.only(top: 14),
                  child: _HomeCalmWorkspaceFloor(),
                )
              : TapRegion(
                  groupId: _miniAppTapRegionGroup,
                  onTapOutside: (_) => _closeMiniApp(),
                  child: Padding(
                    key: ValueKey(_selectedMiniApp),
                    padding: const EdgeInsets.only(top: 14),
                    child: _HomeMiniAppWindow(
                      app: _selectedMiniApp!,
                      primaryClass: widget.primaryClass,
                      classes: widget.classes,
                      reminders: widget.reminders,
                      unread: widget.unread,
                      totalStudents: widget.totalStudents,
                      classStudentCounts: widget.classStudentCounts,
                      now: widget.now,
                      selectedClass: _selectedClassPreview,
                      onClose: _closeMiniApp,
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 16),
        _HomeShortcutShelf(
          unread: widget.unread,
          onLauncherTap: widget.onLauncherTap,
          onMessagesTap: () => _openMiniApp(_HomeMiniApp.messages),
        ),
        const SizedBox(height: 16),
        _HomeUtilityRail(
          unread: widget.unread,
          reminders: widget.reminders,
          reminderCount: widget.reminders.length,
          onAudioTap: () => _openMiniApp(_HomeMiniApp.audio),
          onMessagesTap: () => _openMiniApp(_HomeMiniApp.messages),
          onAgendaTap: () => _openMiniApp(_HomeMiniApp.agenda),
          onWeatherTap: () => _openMiniApp(_HomeMiniApp.weather),
        ),
        const SizedBox(height: 112),
      ],
    );
  }
}

enum _HomeWallpaperStyle {
  defaultStyle,
  sky,
  meadow,
  aurora,
  customImage,
}

extension _HomeWallpaperStyleX on _HomeWallpaperStyle {
  String get id {
    switch (this) {
      case _HomeWallpaperStyle.defaultStyle:
        return 'default';
      case _HomeWallpaperStyle.sky:
        return 'sky';
      case _HomeWallpaperStyle.meadow:
        return 'meadow';
      case _HomeWallpaperStyle.aurora:
        return 'aurora';
      case _HomeWallpaperStyle.customImage:
        return 'custom_image';
    }
  }

  String get label {
    switch (this) {
      case _HomeWallpaperStyle.defaultStyle:
        return 'GradeFlow';
      case _HomeWallpaperStyle.sky:
        return 'Sky';
      case _HomeWallpaperStyle.meadow:
        return 'Meadow';
      case _HomeWallpaperStyle.aurora:
        return 'Aurora';
      case _HomeWallpaperStyle.customImage:
        return 'Your image';
    }
  }

  Color get accent {
    switch (this) {
      case _HomeWallpaperStyle.defaultStyle:
        return OSColors.blue;
      case _HomeWallpaperStyle.sky:
        return OSColors.cyan;
      case _HomeWallpaperStyle.meadow:
        return OSColors.green;
      case _HomeWallpaperStyle.aurora:
        return OSColors.indigo;
      case _HomeWallpaperStyle.customImage:
        return OSColors.amber;
    }
  }

  static _HomeWallpaperStyle fromId(String? id) {
    for (final style in _HomeWallpaperStyle.values) {
      if (style.id == id) return style;
    }
    return _HomeWallpaperStyle.defaultStyle;
  }
}

enum _HomeReadabilityPreset {
  clear,
  balanced,
  focus,
  highContrast,
}

extension _HomeReadabilityPresetX on _HomeReadabilityPreset {
  String get id {
    switch (this) {
      case _HomeReadabilityPreset.clear:
        return 'clear';
      case _HomeReadabilityPreset.balanced:
        return 'balanced';
      case _HomeReadabilityPreset.focus:
        return 'focus';
      case _HomeReadabilityPreset.highContrast:
        return 'high_contrast';
    }
  }

  String get label {
    switch (this) {
      case _HomeReadabilityPreset.clear:
        return 'Clear';
      case _HomeReadabilityPreset.balanced:
        return 'Balanced';
      case _HomeReadabilityPreset.focus:
        return 'Focus';
      case _HomeReadabilityPreset.highContrast:
        return 'High Contrast';
    }
  }

  IconData get icon {
    switch (this) {
      case _HomeReadabilityPreset.clear:
        return Icons.visibility_outlined;
      case _HomeReadabilityPreset.balanced:
        return Icons.tonality_outlined;
      case _HomeReadabilityPreset.focus:
        return Icons.center_focus_strong_outlined;
      case _HomeReadabilityPreset.highContrast:
        return Icons.contrast_rounded;
    }
  }

  double wallpaperScrimAlpha(bool dark, bool hasImage) {
    if (hasImage) {
      switch (this) {
        case _HomeReadabilityPreset.clear:
          return dark ? 0.26 : 0.12;
        case _HomeReadabilityPreset.balanced:
          return dark ? 0.42 : 0.28;
        case _HomeReadabilityPreset.focus:
          return dark ? 0.56 : 0.40;
        case _HomeReadabilityPreset.highContrast:
          return dark ? 0.70 : 0.56;
      }
    }

    switch (this) {
      case _HomeReadabilityPreset.clear:
        return dark ? 0.00 : 0.00;
      case _HomeReadabilityPreset.balanced:
        return dark ? 0.03 : 0.02;
      case _HomeReadabilityPreset.focus:
        return dark ? 0.09 : 0.06;
      case _HomeReadabilityPreset.highContrast:
        return dark ? 0.16 : 0.12;
    }
  }

  double get wallpaperBlurSigma {
    switch (this) {
      case _HomeReadabilityPreset.clear:
        return 0;
      case _HomeReadabilityPreset.balanced:
        return 0;
      case _HomeReadabilityPreset.focus:
        return 1.2;
      case _HomeReadabilityPreset.highContrast:
        return 2.0;
    }
  }

  double get glassBlend {
    switch (this) {
      case _HomeReadabilityPreset.clear:
        return 0;
      case _HomeReadabilityPreset.balanced:
        return 0.02;
      case _HomeReadabilityPreset.focus:
        return 0.12;
      case _HomeReadabilityPreset.highContrast:
        return 0.24;
    }
  }

  double get blurMultiplier {
    switch (this) {
      case _HomeReadabilityPreset.clear:
        return 0.86;
      case _HomeReadabilityPreset.balanced:
        return 1.0;
      case _HomeReadabilityPreset.focus:
        return 1.14;
      case _HomeReadabilityPreset.highContrast:
        return 1.28;
    }
  }

  double get borderBoost {
    switch (this) {
      case _HomeReadabilityPreset.clear:
        return 0;
      case _HomeReadabilityPreset.balanced:
        return 0.02;
      case _HomeReadabilityPreset.focus:
        return 0.08;
      case _HomeReadabilityPreset.highContrast:
        return 0.15;
    }
  }

  static _HomeReadabilityPreset fromId(String? id) {
    for (final preset in _HomeReadabilityPreset.values) {
      if (preset.id == id) return preset;
    }
    return _HomeReadabilityPreset.balanced;
  }
}

class _HomeReadabilityScope extends InheritedWidget {
  const _HomeReadabilityScope({
    required this.preset,
    required super.child,
  });

  final _HomeReadabilityPreset preset;

  static _HomeReadabilityPreset of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<_HomeReadabilityScope>();
    return scope?.preset ?? _HomeReadabilityPreset.balanced;
  }

  @override
  bool updateShouldNotify(covariant _HomeReadabilityScope oldWidget) {
    return oldWidget.preset != preset;
  }
}

class _WallpaperChoiceChip extends StatelessWidget {
  const _WallpaperChoiceChip({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      avatar: Icon(
        selected ? Icons.check_rounded : Icons.wallpaper_outlined,
        size: 17,
        color: selected ? Colors.white : accent,
      ),
      selectedColor: accent,
      labelStyle: TextStyle(
        color:
            selected ? Colors.white : Theme.of(context).colorScheme.onSurface,
        fontWeight: FontWeight.w700,
      ),
      side: BorderSide(
        color: selected ? accent : Theme.of(context).colorScheme.outlineVariant,
      ),
    );
  }
}

class _ReadabilityPresetChip extends StatelessWidget {
  const _ReadabilityPresetChip({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  final _HomeReadabilityPreset preset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = switch (preset) {
      _HomeReadabilityPreset.clear => OSColors.cyan,
      _HomeReadabilityPreset.balanced => OSColors.blue,
      _HomeReadabilityPreset.focus => OSColors.indigo,
      _HomeReadabilityPreset.highContrast => OSColors.amber,
    };

    return ChoiceChip(
      label: Text(preset.label),
      selected: selected,
      onSelected: (_) => onTap(),
      avatar: Icon(
        selected ? Icons.check_rounded : preset.icon,
        size: 17,
        color: selected ? Colors.white : accent,
      ),
      selectedColor: accent,
      labelStyle: TextStyle(
        color:
            selected ? Colors.white : Theme.of(context).colorScheme.onSurface,
        fontWeight: FontWeight.w800,
      ),
      side: BorderSide(
        color: selected ? accent : Theme.of(context).colorScheme.outlineVariant,
      ),
    );
  }
}

class _HomeBackdrop extends StatelessWidget {
  const _HomeBackdrop({
    required this.style,
    required this.imageBytes,
    required this.readability,
  });

  final _HomeWallpaperStyle style;
  final Uint8List? imageBytes;
  final _HomeReadabilityPreset readability;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final colors = _wallpaperColors(style, dark);
    final useImage = style == _HomeWallpaperStyle.customImage &&
        imageBytes != null &&
        imageBytes!.isNotEmpty;

    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        if (useImage)
          Positioned.fill(
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(
                sigmaX: readability.wallpaperBlurSigma,
                sigmaY: readability.wallpaperBlurSigma,
              ),
              child: Image.memory(
                imageBytes!,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: (dark ? Colors.black : Colors.white).withValues(
                alpha: readability.wallpaperScrimAlpha(dark, useImage),
              ),
            ),
          ),
        ),
        if (useImage && readability != _HomeReadabilityPreset.clear)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.28, -0.74),
                  radius: 1.05,
                  colors: [
                    (dark ? OSColors.blue : Colors.white).withValues(
                      alpha: dark ? 0.12 : 0.24,
                    ),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        Positioned(
          left: 32,
          right: 32,
          bottom: -132,
          child: IgnorePointer(
            child: Container(
              height: 260,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(180),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: dark
                      ? [
                          Colors.transparent,
                          const Color(0xFF07101A).withValues(alpha: 0.78),
                        ]
                      : [
                          Colors.transparent,
                          const Color(0xFFF2F7FF).withValues(alpha: 0.90),
                        ],
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _BackdropGridPainter(dark: dark),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.18, -0.68),
                  radius: 1.18,
                  colors: [
                    Colors.white.withValues(alpha: dark ? 0.08 : 0.18),
                    Colors.transparent,
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Color> _wallpaperColors(_HomeWallpaperStyle style, bool dark) {
    if (dark) {
      switch (style) {
        case _HomeWallpaperStyle.sky:
          return const [
            Color(0xFF07111D),
            Color(0xFF0B2740),
            Color(0xFF0D1627),
          ];
        case _HomeWallpaperStyle.meadow:
          return const [
            Color(0xFF081510),
            Color(0xFF123020),
            Color(0xFF0A1320),
          ];
        case _HomeWallpaperStyle.aurora:
          return const [
            Color(0xFF080B18),
            Color(0xFF1A1942),
            Color(0xFF062B35),
          ];
        case _HomeWallpaperStyle.customImage:
        case _HomeWallpaperStyle.defaultStyle:
          return const [
            Color(0xFF07111D),
            Color(0xFF0A1624),
            Color(0xFF0E1420),
          ];
      }
    }

    switch (style) {
      case _HomeWallpaperStyle.sky:
        return const [
          Color(0xFFE8F8FF),
          Color(0xFFD5EFFA),
          Color(0xFFF8FBFF),
        ];
      case _HomeWallpaperStyle.meadow:
        return const [
          Color(0xFFF4FBF4),
          Color(0xFFDDEFC4),
          Color(0xFFF8FAFF),
        ];
      case _HomeWallpaperStyle.aurora:
        return const [
          Color(0xFFF4F1FF),
          Color(0xFFDCEAFE),
          Color(0xFFE8FAF7),
        ];
      case _HomeWallpaperStyle.customImage:
      case _HomeWallpaperStyle.defaultStyle:
        return const [
          Color(0xFFF3F7FF),
          Color(0xFFE8F0FB),
          Color(0xFFF6F8FC),
        ];
    }
  }
}

class _BackdropGridPainter extends CustomPainter {
  const _BackdropGridPainter({required this.dark});

  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = (dark ? Colors.white : Colors.black).withValues(
        alpha: dark ? 0.035 : 0.04,
      )
      ..strokeWidth = 1;
    const step = 56.0;

    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.25
      ..color = OSColors.blue.withValues(alpha: dark ? 0.11 : 0.08);

    final rect = Rect.fromCircle(
      center: Offset(size.width * 0.82, size.height * 0.18),
      radius: size.shortestSide * 0.28,
    );
    canvas.drawArc(rect, 0.4, 2.8, false, arcPaint);

    final lowerRect = Rect.fromCircle(
      center: Offset(size.width * 0.15, size.height * 0.84),
      radius: size.shortestSide * 0.22,
    );
    canvas.drawArc(lowerRect, 3.3, 2.7, false, arcPaint);
  }

  @override
  bool shouldRepaint(covariant _BackdropGridPainter oldDelegate) {
    return dark != oldDelegate.dark;
  }
}

class _HomeSystemStrip extends StatelessWidget {
  const _HomeSystemStrip({
    required this.teacherName,
    required this.schoolName,
    required this.unread,
    required this.now,
    required this.themeMode,
    required this.onShadeTap,
    required this.onAssistantTap,
    required this.onThemeTap,
    required this.onWallpaperTap,
  });

  final String teacherName;
  final String schoolName;
  final int unread;
  final DateTime now;
  final ThemeMode themeMode;
  final VoidCallback onShadeTap;
  final VoidCallback onAssistantTap;
  final VoidCallback onThemeTap;
  final VoidCallback onWallpaperTap;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final compact = MediaQuery.sizeOf(context).width < 720;

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _GlassPanel(
            tone: _HomePanelTone.whisper,
            radius: 24,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF5C8AFF), Color(0xFF5EC7E6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: OSRadius.mdBr,
                  ),
                  child: const Icon(
                    Icons.cast_for_education_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'InstructOS',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0,
                          color: OSColors.text(dark),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        teacherName.isEmpty
                            ? schoolName
                            : '$teacherName - $schoolName',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: OSColors.textSecondary(dark),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _GlassPanel(
            tone: _HomePanelTone.whisper,
            radius: 24,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatClock(now),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0,
                          color: OSColors.text(dark),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatDateLine(now),
                        style: TextStyle(
                          fontSize: 11,
                          color: OSColors.textSecondary(dark),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _TopStripButton(
                  icon: Icons.notifications_outlined,
                  semanticLabel: 'Attention center',
                  badge: unread > 0 ? '$unread' : null,
                  onTap: onShadeTap,
                ),
                const SizedBox(width: 8),
                _TopStripButton(
                  icon: themeMode == ThemeMode.light
                      ? Icons.dark_mode_rounded
                      : Icons.light_mode_rounded,
                  semanticLabel: 'Toggle theme',
                  onTap: onThemeTap,
                ),
                const SizedBox(width: 8),
                _TopStripButton(
                  icon: Icons.wallpaper_rounded,
                  semanticLabel: 'Change home background',
                  onTap: onWallpaperTap,
                ),
                const SizedBox(width: 8),
                _TopStripButton(
                  icon: Icons.auto_awesome_rounded,
                  semanticLabel: 'Assistant',
                  onTap: onAssistantTap,
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _GlassPanel(
            tone: _HomePanelTone.whisper,
            radius: 24,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF5C8AFF), Color(0xFF5EC7E6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: OSRadius.mdBr,
                  ),
                  child: const Icon(
                    Icons.cast_for_education_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'InstructOS',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0,
                          color: OSColors.text(dark),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        teacherName.isEmpty
                            ? schoolName
                            : '$teacherName Ãƒâ€šÃ‚Â· $schoolName',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: OSColors.textSecondary(dark),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        _GlassPanel(
          tone: _HomePanelTone.whisper,
          radius: 24,
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 14 : 16,
            vertical: 12,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatClock(now),
                    style: TextStyle(
                      fontSize: compact ? 18 : 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                      color: OSColors.text(dark),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatDateLine(now),
                    style: TextStyle(
                      fontSize: 11,
                      color: OSColors.textSecondary(dark),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              _TopStripButton(
                icon: Icons.notifications_outlined,
                semanticLabel: 'Attention center',
                badge: unread > 0 ? '$unread' : null,
                onTap: onShadeTap,
              ),
              const SizedBox(width: 8),
              _TopStripButton(
                icon: themeMode == ThemeMode.light
                    ? Icons.dark_mode_rounded
                    : Icons.light_mode_rounded,
                semanticLabel: 'Toggle theme',
                onTap: onThemeTap,
              ),
              const SizedBox(width: 8),
              _TopStripButton(
                icon: Icons.wallpaper_rounded,
                semanticLabel: 'Change home background',
                onTap: onWallpaperTap,
              ),
              const SizedBox(width: 8),
              _TopStripButton(
                icon: Icons.auto_awesome_rounded,
                semanticLabel: 'Assistant',
                onTap: onAssistantTap,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HomeSchoolIdentity extends StatelessWidget {
  const _HomeSchoolIdentity({
    required this.teacherName,
    required this.schoolName,
    required this.unread,
    required this.themeMode,
    required this.onShadeTap,
    required this.onAssistantTap,
    required this.onThemeTap,
    required this.onWallpaperTap,
  });

  final String teacherName;
  final String schoolName;
  final int unread;
  final ThemeMode themeMode;
  final VoidCallback onShadeTap;
  final VoidCallback onAssistantTap;
  final VoidCallback onThemeTap;
  final VoidCallback onWallpaperTap;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;

    return _GlassPanel(
      tone: _HomePanelTone.whisper,
      radius: 28,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 66,
                height: 66,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: dark ? 0.08 : 0.78),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: dark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.white.withValues(alpha: 0.84),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Image.asset(
                    'assets/images/school_logo2.png',
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'InstructOS',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: OSColors.text(dark),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      schoolName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.25,
                        fontWeight: FontWeight.w600,
                        color: OSColors.textSecondary(dark),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            teacherName == 'Teacher'
                ? 'Teacher workspace'
                : '$teacherName workspace',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: OSColors.textMuted(dark),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _TopStripButton(
                icon: Icons.notifications_outlined,
                semanticLabel: 'Attention center',
                badge: unread > 0 ? '$unread' : null,
                onTap: onShadeTap,
              ),
              _TopStripButton(
                icon: themeMode == ThemeMode.light
                    ? Icons.dark_mode_rounded
                    : Icons.light_mode_rounded,
                semanticLabel: 'Toggle theme',
                onTap: onThemeTap,
              ),
              _TopStripButton(
                icon: Icons.wallpaper_rounded,
                semanticLabel: 'Change home background',
                onTap: onWallpaperTap,
              ),
              _TopStripButton(
                icon: Icons.auto_awesome_rounded,
                semanticLabel: 'Assistant',
                onTap: onAssistantTap,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TopStripButton extends StatelessWidget {
  const _TopStripButton({
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;

    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: OSTouchFeedback(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        minSize: const Size(42, 42),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: dark
                    ? Colors.white.withValues(alpha: 0.07)
                    : Colors.white.withValues(alpha: 0.74),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: dark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.white.withValues(alpha: 0.8),
                ),
              ),
              child: Icon(
                icon,
                size: 18,
                color: OSColors.textSecondary(dark),
              ),
            ),
            if (badge != null)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: OSColors.urgent,
                    borderRadius: OSRadius.pillBr,
                  ),
                  child: Text(
                    badge!,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HomeStagePanel extends StatelessWidget {
  const _HomeStagePanel({
    required this.teacherName,
    required this.schoolName,
    required this.primaryClass,
    required this.primaryReminder,
    required this.classCount,
    required this.totalStudents,
    required this.unread,
    required this.reminderCount,
    required this.now,
    required this.compact,
    required this.onMessagesTap,
    required this.onPlannerTap,
    required this.onClassesTap,
  });

  final String teacherName;
  final String schoolName;
  final Class? primaryClass;
  final TeacherWorkspaceReminderSnapshot? primaryReminder;
  final int classCount;
  final int totalStudents;
  final int unread;
  final int reminderCount;
  final DateTime now;
  final bool compact;
  final VoidCallback onMessagesTap;
  final VoidCallback onPlannerTap;
  final VoidCallback onClassesTap;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final stageGradient = LinearGradient(
      colors: dark
          ? const [
              Color(0x5518273C),
              Color(0x44111A29),
              Color(0x55172234),
            ]
          : const [
              Color(0xE8FFFFFF),
              Color(0xE4F7FAFF),
              Color(0xDCEEF3FA),
            ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    return _GlassPanel(
      tone: _HomePanelTone.stage,
      radius: compact ? WorkspaceRadius.shellCompact : WorkspaceRadius.shell,
      padding: EdgeInsets.all(compact ? 22 : 16),
      gradient: stageGradient,
      child: compact
          ? SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const _PanelEyebrow(label: 'Command Center'),
                      const Spacer(),
                      _StageStatusChip(
                        text: classCount == 0
                            ? 'No active classes'
                            : '$classCount active classes',
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    _formatClock(now),
                    style: TextStyle(
                      fontSize: 58,
                      height: 0.92,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                      color: OSColors.text(dark),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatLongDate(now),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: OSColors.textSecondary(dark),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _stageHeadline(teacherName, primaryClass),
                    style: TextStyle(
                      fontSize: 26,
                      height: 1.04,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                      color: OSColors.text(dark),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _stageSupportLine(
                      primaryClass: primaryClass,
                      primaryReminder: primaryReminder,
                      classCount: classCount,
                      unread: unread,
                      schoolName: schoolName,
                      now: now,
                    ),
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: OSColors.textSecondary(dark),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Column(
                    children: [
                      _StageSpotlightTile(
                        title: 'Lead class',
                        icon: Icons.class_rounded,
                        accent: OSColors.green,
                        headline: primaryClass?.className ?? 'No room pinned',
                        detail: primaryClass == null
                            ? 'Open Classes to start your first workspace.'
                            : primaryClass!.subject,
                        onTap: primaryClass == null ? onClassesTap : null,
                      ),
                      const SizedBox(height: 12),
                      _StageSpotlightTile(
                        title: 'Next signal',
                        icon: Icons.event_note_outlined,
                        accent: OSColors.amber,
                        headline: primaryReminder == null
                            ? 'No pending reminders'
                            : _relativeReminderLabel(primaryReminder!, now),
                        detail: primaryReminder == null
                            ? 'Your day is currently clear.'
                            : _trimLine(primaryReminder!.text, 88),
                        onTap: onPlannerTap,
                      ),
                    ],
                  ),
                ],
              ),
            )
          : _DesktopStageShell(
              teacherName: teacherName,
              schoolName: schoolName,
              primaryClass: primaryClass,
              primaryReminder: primaryReminder,
              classCount: classCount,
              unread: unread,
              now: now,
              onMessagesTap: onMessagesTap,
              onPlannerTap: onPlannerTap,
              onClassesTap: onClassesTap,
            ),
    );
  }
}

class _DesktopStageShell extends StatelessWidget {
  const _DesktopStageShell({
    required this.teacherName,
    required this.schoolName,
    required this.primaryClass,
    required this.primaryReminder,
    required this.classCount,
    required this.unread,
    required this.now,
    required this.onMessagesTap,
    required this.onPlannerTap,
    required this.onClassesTap,
  });

  final String teacherName;
  final String schoolName;
  final Class? primaryClass;
  final TeacherWorkspaceReminderSnapshot? primaryReminder;
  final int classCount;
  final int unread;
  final DateTime now;
  final VoidCallback onMessagesTap;
  final VoidCallback onPlannerTap;
  final VoidCallback onClassesTap;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final signal = primaryReminder != null
        ? _relativeReminderLabel(primaryReminder!, now)
        : unread > 0
            ? '$unread unread'
            : 'Quiet';
    final needsAttention = primaryReminder != null || unread > 0;
    final primaryActionLabel = unread > 0
        ? 'Messages'
        : primaryClass != null
            ? 'Classes'
            : 'Planner';
    final primaryActionIcon = unread > 0
        ? Icons.forum_rounded
        : primaryClass != null
            ? Icons.arrow_forward_rounded
            : Icons.calendar_month_rounded;
    final primaryAction = unread > 0
        ? onMessagesTap
        : primaryClass != null
            ? onClassesTap
            : onPlannerTap;
    // TODO: Reconnect Now/Next state after timetable import reliability is fixed.
    final commandTitle = primaryReminder != null
        ? 'Planner needs review'
        : unread > 0
            ? 'Messages need review'
            : primaryClass == null
                ? 'Check today\'s schedule'
                : 'Class workspace ready';
    final commandDetail = primaryReminder != null
        ? _trimLine(primaryReminder!.text, 84)
        : unread > 0
            ? 'Open conversations before the next handoff.'
            : primaryClass == null
                ? 'Review schedule in Planner.'
                : '${primaryClass!.className} / ${primaryClass!.subject}';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 152,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _PanelEyebrow(label: 'Command Center'),
              const SizedBox(height: 7),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  _formatClock(now),
                  style: TextStyle(
                    fontSize: 34,
                    height: 0.9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                    color: OSColors.text(dark),
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                _formatDateLine(now),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: OSColors.textSecondary(dark),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _StageStatusChip(text: signal),
                  const SizedBox(width: 8),
                  _StageStatusChip(
                    text: classCount == 0
                        ? 'No active classes'
                        : '$classCount classes',
                  ),
                  if (needsAttention) ...[
                    const SizedBox(width: 8),
                    const _StageStatusChip(text: 'Attention'),
                  ],
                ],
              ),
              const SizedBox(height: 9),
              Text(
                commandTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 19,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                  color: OSColors.text(dark),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                commandDetail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: OSColors.textSecondary(dark),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        _FolderActionButton(
          label: primaryActionLabel,
          icon: primaryActionIcon,
          onTap: primaryAction,
        ),
      ],
    );
  }
}

class _StageStatusChip extends StatelessWidget {
  const _StageStatusChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: dark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(WorkspaceRadius.pill),
        border: Border.all(
          color: dark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.72),
        ),
      ),
      child: Text(
        text,
        style: WorkspaceTypography.utility(
          context,
          color: OSColors.textSecondary(dark),
        )?.copyWith(fontSize: 11),
      ),
    );
  }
}

class _StageSpotlightTile extends StatelessWidget {
  const _StageSpotlightTile({
    required this.title,
    required this.icon,
    required this.accent,
    required this.headline,
    required this.detail,
    this.onTap,
  });

  final String title;
  final IconData icon;
  final Color accent;
  final String headline;
  final String detail;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;

    return OSTouchFeedback(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      minSize: const Size(120, 86),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: dark
              ? Colors.white.withValues(alpha: 0.035)
              : Colors.white.withValues(alpha: 0.48),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: dark
                ? Colors.white.withValues(alpha: 0.055)
                : Colors.white.withValues(alpha: 0.54),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.16),
                borderRadius: OSRadius.mdBr,
              ),
              child: Icon(icon, size: 20, color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: OSColors.textMuted(dark),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    headline,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                      color: OSColors.text(dark),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    detail,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: OSColors.textSecondary(dark),
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Padding(
                padding: const EdgeInsets.only(left: 8, top: 2),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: OSColors.textMuted(dark),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HomeShortcutShelf extends StatelessWidget {
  const _HomeShortcutShelf({
    required this.unread,
    required this.onLauncherTap,
    required this.onMessagesTap,
    this.compact = false,
  });

  final int unread;
  final VoidCallback onLauncherTap;
  final VoidCallback onMessagesTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final showLauncher = MediaQuery.sizeOf(context).width < 560;
    final shortcuts = <_HomeShortcutData>[
      _shortcutFromApp(OSAppId.teach,
          onTap: () => context.go(AppRoutes.osTeach)),
      _shortcutFromApp(
        OSAppId.whiteboard,
        onTap: () => context.push(AppRoutes.whiteboard),
      ),
      _shortcutFromApp(
        OSAppId.messages,
        onTap: onMessagesTap,
        badge: unread > 0 ? '$unread' : null,
      ),
      if (showLauncher)
        _HomeShortcutData(
          label: 'Launcher',
          icon: Icons.grid_view_rounded,
          accent: OSColors.amber,
          onTap: onLauncherTap,
        ),
    ];

    return _GlassPanel(
      tone: _HomePanelTone.whisper,
      radius: compact ? 24 : 28,
      padding: EdgeInsets.all(compact ? 12 : 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tileWidth = compact ? 64.0 : 82.0;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _PanelEyebrow(label: 'Pinned Apps'),
              SizedBox(height: compact ? 5 : 8),
              Text(
                'Quick launch',
                style: TextStyle(
                  fontSize: compact ? 14.5 : 17,
                  fontWeight: FontWeight.w800,
                  color: OSColors.text(context.isDark),
                ),
              ),
              if (!compact) ...[
                const SizedBox(height: 4),
                Text(
                  'Teach, message, and open the tools you use most.',
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.4,
                    color: OSColors.textSecondary(context.isDark),
                  ),
                ),
              ],
              SizedBox(height: compact ? 9 : 14),
              SizedBox(
                height: compact ? 72 : 96,
                child: ShaderMask(
                  shaderCallback: (rect) {
                    return LinearGradient(
                      colors: [
                        Colors.black,
                        Colors.black,
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.88, 1.0],
                    ).createShader(rect);
                  },
                  blendMode: BlendMode.dstIn,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: shortcuts.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      return _HomeShortcutIcon(
                        data: shortcuts[index],
                        width: tileWidth,
                        iconBoxSize: compact ? 44 : 58,
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  _HomeShortcutData _shortcutFromApp(
    String appId, {
    required VoidCallback onTap,
    String? badge,
  }) {
    final app = OSAppRegistry.findById(appId)!;
    return _HomeShortcutData(
      label: app.name,
      icon: app.icon,
      accent: app.color ?? OSColors.blue,
      badge: badge,
      onTap: onTap,
    );
  }
}

class _HomeShortcutData {
  const _HomeShortcutData({
    required this.label,
    required this.icon,
    required this.accent,
    required this.onTap,
    this.badge,
  });

  final String label;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;
  final String? badge;
}

class _HomeShortcutIcon extends StatelessWidget {
  const _HomeShortcutIcon({
    required this.data,
    this.width = 88,
    this.iconBoxSize = 60,
  });

  final _HomeShortcutData data;
  final double width;
  final double iconBoxSize;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final compact = iconBoxSize <= 44;

    return OSTouchFeedback(
      onTap: data.onTap,
      borderRadius: OSRadius.lgBr,
      minSize: Size(width, width),
      child: SizedBox(
        width: width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: iconBoxSize,
                  height: iconBoxSize,
                  decoration: BoxDecoration(
                    color: data.accent.withValues(alpha: 0.14),
                    borderRadius:
                        BorderRadius.circular(OSSpacing.appIconRadius),
                    border: Border.all(
                      color: data.accent.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Icon(
                    data.icon,
                    size: iconBoxSize * 0.42,
                    color: data.accent,
                  ),
                ),
                if (data.badge != null)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: OSColors.urgent,
                        borderRadius: OSRadius.pillBr,
                        border: Border.all(
                          color: dark
                              ? OSColors.bg(true)
                              : Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                      child: Text(
                        data.badge!,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: compact ? 5 : 7),
            Text(
              data.label,
              textAlign: TextAlign.center,
              maxLines: compact ? 1 : 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: compact ? 10.5 : 11,
                height: 1.2,
                fontWeight: FontWeight.w600,
                color: OSColors.textSecondary(dark),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeWeatherPanel extends StatefulWidget {
  const _HomeWeatherPanel({this.embedded = false, this.onTap});

  final bool embedded;
  final VoidCallback? onTap;

  @override
  State<_HomeWeatherPanel> createState() => _HomeWeatherPanelState();
}

class _HomeWeatherPanelState extends State<_HomeWeatherPanel> {
  late final DashboardWeatherService _service = DashboardWeatherService();
  late final Future<DashboardWeatherSnapshot> _weather =
      _service.fetchForecast();

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;

    return FutureBuilder<DashboardWeatherSnapshot>(
      future: _weather,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final loading = snapshot.connectionState == ConnectionState.waiting;
        final hasError = snapshot.hasError && data == null;
        final forecast =
            data?.forecast.take(2).toList() ?? const <DashboardForecastDay>[];
        final mood = _weatherMood(data?.weatherCode, DateTime.now(), dark);
        final textOnWeather = _weatherTextColor(mood, dark);
        final mutedOnWeather = _weatherMutedTextColor(mood, dark);
        final iconOnWeather = _weatherAccentColor(mood, dark);

        final tempLabel = hasError
            ? '--'
            : loading
                ? '--'
                : '${data!.temperatureC.round()}°';
        final conditionLabel = hasError
            ? 'Forecast unavailable'
            : loading
                ? 'Checking forecast'
                : _weatherLabel(data!.weatherCode);
        final locationLabel = hasError
            ? 'Weather will return when the network responds.'
            : loading
                ? 'Taichung City'
                : '${data!.locationName} / feels like ${data.apparentTempC.round()}°';

        final gap = widget.embedded ? 10.0 : 18.0;
        final tempSize = widget.embedded ? 38.0 : 46.0;
        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Local conditions'.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: WorkspaceTypography.eyebrow(context)?.copyWith(
                      color: textOnWeather.withValues(alpha: 0.72),
                    ),
                  ),
                ),
                Icon(
                  data == null
                      ? Icons.cloud_queue_rounded
                      : _weatherIcon(data.weatherCode),
                  color: iconOnWeather.withValues(alpha: 0.96),
                  size: 24,
                ),
              ],
            ),
            SizedBox(height: gap),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  tempLabel,
                  style: TextStyle(
                    fontSize: tempSize,
                    height: 0.92,
                    fontWeight: FontWeight.w900,
                    color: textOnWeather,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          conditionLabel,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 17,
                            height: 1.08,
                            fontWeight: FontWeight.w900,
                            color: textOnWeather,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          locationLabel,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            height: 1.25,
                            fontWeight: FontWeight.w600,
                            color: mutedOnWeather,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (forecast.isNotEmpty) ...[
              SizedBox(height: widget.embedded ? 12 : 18),
              Row(
                children: [
                  for (int index = 0; index < forecast.length; index++) ...[
                    if (index > 0) const SizedBox(width: 8),
                    Expanded(
                      child: _WeatherForecastTile(
                        day: forecast[index],
                        textColor: textOnWeather,
                        mutedColor: mutedOnWeather,
                        iconColor: iconOnWeather,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        );
        final frame = _WeatherWidgetFrame(
          mood: mood,
          embedded: widget.embedded,
          child: content,
        );
        if (widget.onTap == null) return frame;
        return OSTouchFeedback(
          onTap: widget.onTap!,
          borderRadius: BorderRadius.circular(widget.embedded ? 24 : 28),
          minSize: Size(180, widget.embedded ? 166 : 220),
          child: frame,
        );
      },
    );
  }
}

enum _WeatherMood { rain, cloudy, sunny, night }

class _WeatherWidgetFrame extends StatelessWidget {
  const _WeatherWidgetFrame({
    required this.mood,
    required this.embedded,
    required this.child,
  });

  final _WeatherMood mood;
  final bool embedded;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final radius = BorderRadius.circular(embedded ? 24 : 28);

    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: embedded ? 164 : 220),
      child: Container(
        padding: EdgeInsets.all(embedded ? 12 : 16),
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: LinearGradient(
            colors: _weatherGradient(mood, dark),
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: dark ? 0.12 : 0.54),
          ),
          boxShadow: [
            BoxShadow(
              color: _weatherAccentColor(mood, dark).withValues(
                alpha: dark ? 0.18 : 0.16,
              ),
              blurRadius: 30,
              offset: const Offset(0, 15),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _WeatherAtmospherePainter(
                    mood: mood,
                    dark: dark,
                  ),
                ),
              ),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _WeatherAtmospherePainter extends CustomPainter {
  const _WeatherAtmospherePainter({
    required this.mood,
    required this.dark,
  });

  final _WeatherMood mood;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final softGlow = Paint()
      ..shader = RadialGradient(
        colors: [
          _weatherAccentColor(mood, dark).withValues(alpha: dark ? 0.20 : 0.26),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * .82, size.height * .10),
          radius: size.width * .62,
        ),
      );
    canvas.drawCircle(
      Offset(size.width * .82, size.height * .10),
      size.width * .62,
      softGlow,
    );

    final paint = Paint()..style = PaintingStyle.stroke;
    if (mood == _WeatherMood.rain) {
      final mist = Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.white.withValues(alpha: dark ? 0.02 : 0.10),
            Colors.white.withValues(alpha: dark ? 0.10 : 0.22),
            Colors.transparent,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(Offset.zero & size);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(size.width * .42, 6, size.width * .65, size.height),
          const Radius.circular(28),
        ),
        mist,
      );
      paint
        ..color = Colors.white.withValues(alpha: dark ? 0.15 : 0.26)
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round;
      for (double x = 4; x < size.width + 24; x += 18) {
        canvas.drawLine(
          Offset(x, 2),
          Offset(x - 16, size.height - 4),
          paint,
        );
      }
      return;
    }

    if (mood == _WeatherMood.cloudy) {
      final fill = Paint()
        ..style = PaintingStyle.fill
        ..color = Colors.white.withValues(alpha: dark ? 0.075 : 0.26);
      canvas.drawOval(
          Rect.fromLTWH(size.width * .46, 4, size.width * .70, 64), fill);
      canvas.drawOval(
          Rect.fromLTWH(size.width * .30, 28, size.width * .72, 82), fill);
      canvas.drawOval(
          Rect.fromLTWH(size.width * .64, 54, size.width * .48, 58), fill);
      return;
    }

    if (mood == _WeatherMood.night) {
      final moon = Paint()
        ..color = Colors.white.withValues(alpha: dark ? 0.26 : 0.22);
      canvas.drawCircle(Offset(size.width * .84, size.height * .14), 22, moon);
      final cutout = Paint()
        ..color = const Color(0xFF0B1F3A).withValues(alpha: 0.76);
      canvas.drawCircle(
        Offset(size.width * .91, size.height * .10),
        20,
        cutout,
      );
      final star = Paint()
        ..style = PaintingStyle.fill
        ..color = Colors.white.withValues(alpha: 0.32);
      for (final offset in [
        Offset(size.width * .18, size.height * .16),
        Offset(size.width * .34, size.height * .30),
        Offset(size.width * .72, size.height * .40),
      ]) {
        canvas.drawCircle(offset, 1.4, star);
      }
      return;
    }

    final sun = Paint()
      ..color = Colors.white.withValues(
        alpha: mood == _WeatherMood.night ? 0.16 : 0.34,
      );
    canvas.drawCircle(Offset(size.width * .86, size.height * .14), 28, sun);
    paint
      ..color = Colors.white.withValues(alpha: dark ? 0.07 : 0.18)
      ..strokeWidth = 1;
    canvas.drawArc(
      Rect.fromLTWH(size.width * .52, size.height * .52, size.width * .64, 80),
      3.35,
      1.7,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _WeatherAtmospherePainter oldDelegate) {
    return mood != oldDelegate.mood || dark != oldDelegate.dark;
  }
}

class _WeatherForecastTile extends StatelessWidget {
  const _WeatherForecastTile({
    required this.day,
    required this.textColor,
    required this.mutedColor,
    required this.iconColor,
  });

  final DashboardForecastDay day;
  final Color textColor;
  final Color mutedColor;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: dark
            ? Colors.white.withValues(alpha: 0.075)
            : Colors.white.withValues(alpha: 0.30),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: dark ? 0.10 : 0.40),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_weatherIcon(day.weatherCode), size: 16, color: iconColor),
          const SizedBox(height: 8),
          Text(
            _formatDateLine(day.date),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: mutedColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${day.maxTempC.round()} / ${day.minTempC.round()} C',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeAudioPanel extends StatelessWidget {
  const _HomeAudioPanel({
    required this.onTap,
    this.embedded = false,
    this.compact = false,
  });

  final VoidCallback onTap;
  final bool embedded;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final content = Container(
      padding: EdgeInsets.all(compact ? 11 : 13),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: dark
              ? const [Color(0xFF1B2137), Color(0xFF101827)]
              : const [Color(0xFFFFFFFF), Color(0xFFEAF4FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: dark
              ? Colors.white.withValues(alpha: 0.075)
              : Colors.white.withValues(alpha: 0.80),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (!compact) ...[
                const _AudioArtwork(),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _PanelEyebrow(label: 'Focus Audio'),
                    const SizedBox(height: 5),
                    Text(
                      'Classroom sound',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: OSColors.text(dark),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Stations for quiet work and transitions.',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.35,
                        color: OSColors.textSecondary(dark),
                      ),
                    ),
                  ],
                ),
              ),
              _RoundPlayButton(size: compact ? 32 : 34),
            ],
          ),
          SizedBox(height: compact ? 9 : 12),
          ClipRRect(
            borderRadius: OSRadius.pillBr,
            child: LinearProgressIndicator(
              minHeight: 4,
              value: 0.58,
              backgroundColor:
                  Colors.white.withValues(alpha: dark ? 0.08 : 0.46),
              valueColor: AlwaysStoppedAnimation<Color>(
                OSColors.cyan.withValues(alpha: dark ? 0.92 : 0.82),
              ),
            ),
          ),
          SizedBox(height: compact ? 8 : 10),
          Row(
            children: [
              const Expanded(child: _MiniEqualizer()),
              const SizedBox(width: 12),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: dark ? 0.055 : 0.58),
                ),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: OSColors.textMuted(dark),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return OSTouchFeedback(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      minSize: Size(180, compact ? 92 : 118),
      child: embedded
          ? _RailSection(child: content)
          : _GlassPanel(
              tone: _HomePanelTone.whisper,
              radius: 28,
              padding: const EdgeInsets.all(16),
              child: content,
            ),
    );
  }
}

class _AudioArtwork extends StatelessWidget {
  const _AudioArtwork();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(17),
        gradient: const LinearGradient(
          colors: [Color(0xFF1D4ED8), Color(0xFF06B6D4), Color(0xFF67E8F9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: OSColors.indigo.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -12,
            top: -10,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.18),
              ),
            ),
          ),
          const Center(
            child: Icon(
              Icons.graphic_eq_rounded,
              color: Colors.white,
              size: 27,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniEqualizer extends StatelessWidget {
  const _MiniEqualizer();

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final bars = [0.32, 0.74, 0.48, 0.88, 0.42, 0.68, 0.36, 0.58];

    return SizedBox(
      height: 22,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (int index = 0; index < bars.length; index++) ...[
            Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: FractionallySizedBox(
                  heightFactor: bars[index],
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: OSRadius.pillBr,
                      color: (index.isEven ? OSColors.indigo : OSColors.cyan)
                          .withValues(alpha: dark ? 0.58 : 0.68),
                    ),
                  ),
                ),
              ),
            ),
            if (index != bars.length - 1) const SizedBox(width: 4),
          ],
        ],
      ),
    );
  }
}

class _HomeAgendaPanel extends StatelessWidget {
  const _HomeAgendaPanel({
    required this.reminders,
    required this.scrollable,
    this.embedded = false,
    this.compact = false,
    this.onTap,
  });

  final List<TeacherWorkspaceReminderSnapshot> reminders;
  final bool scrollable;
  final bool embedded;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final visibleReminders =
        scrollable ? reminders : reminders.take(compact ? 1 : 4).toList();
    final dark = context.isDark;
    final headerChildren = <Widget>[
      Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: OSColors.amber.withValues(alpha: dark ? 0.13 : 0.10),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: OSColors.amber.withValues(alpha: 0.18),
              ),
            ),
            child: const Icon(
              Icons.event_available_rounded,
              size: 17,
              color: OSColors.amber,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _PanelEyebrow(label: 'Agenda Queue'),
                const SizedBox(height: 3),
                Text(
                  reminders.isEmpty ? 'Clear for now' : 'Next reminders',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                    color: OSColors.text(dark),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      if (!compact) ...[
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: dark
                ? Colors.white.withValues(alpha: 0.030)
                : Colors.white.withValues(alpha: 0.46),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: dark
                  ? Colors.white.withValues(alpha: 0.045)
                  : Colors.white.withValues(alpha: 0.58),
            ),
          ),
          child: Text(
            reminders.isEmpty
                ? 'The planning lane is calm.'
                : 'Priority items stay visible without crowding the workspace.',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              height: 1.34,
              color: OSColors.textSecondary(dark),
            ),
          ),
        ),
      ],
      SizedBox(height: compact ? 8 : 10),
    ];

    final content = scrollable
        ? ListView(
            padding: EdgeInsets.zero,
            children: [
              ...headerChildren,
              if (reminders.isEmpty)
                const _AgendaEmptyState()
              else
                for (int index = 0;
                    index < visibleReminders.length;
                    index++) ...[
                  _ReminderTile(
                    reminder: visibleReminders[index],
                    now: DateTime.now(),
                  ),
                  if (index != visibleReminders.length - 1)
                    const SizedBox(height: 10),
                ],
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...headerChildren,
              if (compact)
                _StatusPill(
                  label: reminders.isEmpty
                      ? 'Planner clear'
                      : _relativeReminderLabel(
                          visibleReminders.first, DateTime.now()),
                  accent: reminders.isEmpty ? OSColors.green : OSColors.amber,
                )
              else if (reminders.isEmpty)
                const _AgendaEmptyState()
              else
                Column(
                  children: [
                    for (int index = 0;
                        index < visibleReminders.length;
                        index++) ...[
                      _ReminderTile(
                        reminder: visibleReminders[index],
                        now: DateTime.now(),
                      ),
                      if (index != visibleReminders.length - 1)
                        const SizedBox(height: 10),
                    ],
                    if (reminders.length > visibleReminders.length) ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '+${reminders.length - visibleReminders.length} more in the planning hub',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: OSColors.textMuted(dark),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
            ],
          );

    final tappableContent = onTap == null
        ? content
        : OSTouchFeedback(
            onTap: onTap!,
            borderRadius: BorderRadius.circular(22),
            minSize: const Size(180, 108),
            child: IgnorePointer(child: content),
          );

    return embedded
        ? _RailSection(
            expand: scrollable,
            child: tappableContent,
          )
        : _GlassPanel(
            tone: _HomePanelTone.whisper,
            radius: 28,
            padding: const EdgeInsets.all(16),
            child: tappableContent,
          );
  }
}

class _AgendaEmptyState extends StatelessWidget {
  const _AgendaEmptyState();

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            OSColors.blue.withValues(alpha: dark ? 0.11 : 0.07),
            Colors.white.withValues(alpha: dark ? 0.035 : 0.64),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: dark
              ? Colors.white.withValues(alpha: 0.065)
              : Colors.white.withValues(alpha: 0.72),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: OSColors.green.withValues(alpha: dark ? 0.14 : 0.10),
              border: Border.all(
                color: OSColors.green.withValues(alpha: 0.18),
              ),
            ),
            child: const Icon(
              Icons.check_rounded,
              size: 18,
              color: OSColors.green,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No queued reminders',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    color: OSColors.text(dark),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'New planner items will appear as a quiet timeline.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.35,
                    color: OSColors.textSecondary(dark),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReminderTile extends StatelessWidget {
  const _ReminderTile({
    required this.reminder,
    required this.now,
  });

  final TeacherWorkspaceReminderSnapshot reminder;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final dueLabel = _relativeReminderLabel(reminder, now);
    final accent = _reminderAccent(reminder, now);

    final tile = Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: dark
            ? Colors.white.withValues(alpha: 0.035)
            : Colors.white.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: dark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.white.withValues(alpha: 0.72),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: dark ? 0.18 : 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: accent.withValues(alpha: 0.26)),
                ),
                child: Icon(Icons.schedule_rounded, size: 13, color: accent),
              ),
              Container(
                width: 2,
                height: 42,
                margin: const EdgeInsets.only(top: 6),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: dark ? 0.24 : 0.16),
                  borderRadius: OSRadius.pillBr,
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dueLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _trimLine(reminder.text, 110),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                    color: OSColors.text(dark),
                  ),
                ),
                if (reminder.classIds.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    '${reminder.classIds.length} class context${reminder.classIds.length == 1 ? '' : 's'}',
                    style: TextStyle(
                      fontSize: 11,
                      color: OSColors.textMuted(dark),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    return OSTouchFeedback(
      onTap: () => context.go(AppRoutes.osPlanner),
      borderRadius: BorderRadius.circular(18),
      minSize: const Size(190, 78),
      child: tile,
    );
  }

  Color _reminderAccent(
    TeacherWorkspaceReminderSnapshot reminder,
    DateTime now,
  ) {
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(
      reminder.timestamp.year,
      reminder.timestamp.month,
      reminder.timestamp.day,
    );
    final difference = due.difference(today).inDays;
    if (difference < 0) return OSColors.urgent;
    if (difference == 0) return OSColors.coral;
    if (difference <= 2) return OSColors.amber;
    return OSColors.cyan;
  }
}

enum _HomePanelTone { stage, tool, whisper, rail }

class _RailSection extends StatelessWidget {
  const _RailSection({
    required this.child,
    this.expand = false,
  });

  final Widget child;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final readability = _HomeReadabilityScope.of(context);
    final solidColor = dark
        ? const Color(0xFF111A27).withValues(alpha: 0.64)
        : Colors.white.withValues(alpha: 0.92);
    final baseFill = dark
        ? Colors.white.withValues(alpha: 0.035)
        : Colors.white.withValues(alpha: 0.48);
    final borderFill = dark
        ? Colors.white.withValues(alpha: 0.055)
        : Colors.white.withValues(alpha: 0.58);

    final section = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Color.lerp(baseFill, solidColor, readability.glassBlend),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Color.lerp(
            borderFill,
            dark ? Colors.white : OSColors.blue,
            readability.borderBoost,
          )!,
        ),
      ),
      child: child,
    );

    return expand ? Expanded(child: section) : section;
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 28,
    this.gradient,
    this.tone = _HomePanelTone.tool,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final Gradient? gradient;
  final _HomePanelTone tone;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final readability = _HomeReadabilityScope.of(context);
    final (baseColor, secondaryColor, borderColor, shadowEmphasis, blurSigma) =
        switch (tone) {
      _HomePanelTone.stage => (
          dark
              ? Colors.white.withValues(alpha: 0.10)
              : Colors.white.withValues(alpha: 0.82),
          dark
              ? const Color(0xFF17253A).withValues(alpha: 0.58)
              : const Color(0xFFEAF4FF).withValues(alpha: 0.95),
          dark
              ? WorkspaceChrome.panelBorderColor(context, emphasis: 0.42)
              : Colors.white.withValues(alpha: 0.86),
          dark ? 1.25 : 1.08,
          WorkspaceChrome.panelBlur,
        ),
      _HomePanelTone.whisper => (
          dark
              ? Colors.white.withValues(alpha: 0.045)
              : Colors.white.withValues(alpha: 0.60),
          dark
              ? const Color(0xFF101827).withValues(alpha: 0.26)
              : const Color(0xFFF4F8FF).withValues(alpha: 0.78),
          dark
              ? WorkspaceChrome.panelBorderColor(context, emphasis: 0.18)
              : Colors.white.withValues(alpha: 0.66),
          dark ? 0.42 : 0.34,
          WorkspaceChrome.panelBlur * 0.78,
        ),
      _HomePanelTone.rail => (
          dark
              ? Colors.white.withValues(alpha: 0.055)
              : Colors.white.withValues(alpha: 0.58),
          dark
              ? const Color(0xFF101827).withValues(alpha: 0.34)
              : const Color(0xFFF7FAFF).withValues(alpha: 0.78),
          dark
              ? WorkspaceChrome.panelBorderColor(context, emphasis: 0.24)
              : Colors.white.withValues(alpha: 0.72),
          dark ? 0.76 : 0.54,
          WorkspaceChrome.panelBlur * 0.86,
        ),
      _HomePanelTone.tool => (
          dark
              ? Colors.white.withValues(alpha: 0.07)
              : Colors.white.withValues(alpha: 0.74),
          dark
              ? const Color(0xFF162132).withValues(alpha: 0.44)
              : const Color(0xFFF5F9FF).withValues(alpha: 0.92),
          dark
              ? WorkspaceChrome.panelBorderColor(context, emphasis: 0.34)
              : Colors.white.withValues(alpha: 0.8),
          dark ? 1.0 : 0.94,
          WorkspaceChrome.panelBlur * 0.92,
        ),
    };
    final solidColor = dark
        ? const Color(0xFF111A27).withValues(alpha: 0.72)
        : Colors.white.withValues(alpha: 0.96);
    final readableBaseColor =
        Color.lerp(baseColor, solidColor, readability.glassBlend)!;
    final readableSecondaryColor =
        Color.lerp(secondaryColor, solidColor, readability.glassBlend)!;
    final readableBorderColor = Color.lerp(
      borderColor,
      dark ? Colors.white : OSColors.blue,
      readability.borderBoost,
    )!;
    final readableBlurSigma = blurSigma * readability.blurMultiplier;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(
          sigmaX: readableBlurSigma,
          sigmaY: readableBlurSigma,
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: readableBorderColor),
            boxShadow: WorkspaceChrome.panelShadow(
              context,
              emphasis: shadowEmphasis + readability.borderBoost,
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(radius),
                    gradient: gradient ??
                        LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            readableBaseColor,
                            readableSecondaryColor,
                            readableBaseColor,
                          ],
                        ),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: Container(
                    height: 1,
                    color: WorkspaceChrome.glassHighlight(context).withValues(
                      alpha: tone == _HomePanelTone.whisper ? 0.55 : 1.0,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: padding,
                child: child,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PanelEyebrow extends StatelessWidget {
  const _PanelEyebrow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: WorkspaceTypography.eyebrow(context)?.copyWith(
        color: OSColors.textMuted(context.isDark),
      ),
    );
  }
}

String _firstName(String fullName) {
  final normalized = fullName.trim();
  if (normalized.isEmpty) {
    return 'Teacher';
  }
  return normalized.split(RegExp(r'\s+')).first;
}

String _schoolName(String? rawSchoolName) {
  final normalized = rawSchoolName?.trim() ?? '';
  return normalized.isEmpty ? 'Teacher workspace' : normalized;
}

String _formatClock(DateTime now) {
  final hour = now.hour % 12 == 0 ? 12 : now.hour % 12;
  final minute = now.minute.toString().padLeft(2, '0');
  final suffix = now.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $suffix';
}

String _formatDateLine(DateTime now) {
  const weekdays = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${weekdays[now.weekday - 1]} ${months[now.month - 1]} ${now.day}';
}

String _formatLongDate(DateTime now) {
  const weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${weekdays[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}';
}

IconData _weatherIcon(int code) {
  if (code == 0) return Icons.wb_sunny_outlined;
  if (code <= 3) return Icons.cloud_queue_rounded;
  if (code == 45 || code == 48) return Icons.foggy;
  if (code >= 51 && code <= 67) return Icons.grain_rounded;
  if (code >= 71 && code <= 77) return Icons.ac_unit_rounded;
  if (code >= 80 && code <= 82) return Icons.water_drop_outlined;
  if (code >= 95) return Icons.thunderstorm_outlined;
  return Icons.cloud_outlined;
}

_WeatherMood _weatherMood(int? code, DateTime now, bool dark) {
  if (code == null) return dark ? _WeatherMood.night : _WeatherMood.cloudy;
  final isNight = dark || now.hour < 6 || now.hour >= 18;
  if (isNight && code <= 3) return _WeatherMood.night;
  if (code == 0) return _WeatherMood.sunny;
  if (code <= 3 || code == 45 || code == 48) return _WeatherMood.cloudy;
  if (code >= 51 && code <= 99) return _WeatherMood.rain;
  return isNight ? _WeatherMood.night : _WeatherMood.cloudy;
}

List<Color> _weatherGradient(_WeatherMood mood, bool dark) {
  return switch (mood) {
    _WeatherMood.rain => dark
        ? const [Color(0xFF06101F), Color(0xFF12324F), Color(0xFF0B1726)]
        : const [Color(0xFF7FA9C7), Color(0xFFBCD2E5), Color(0xFFE7F1FA)],
    _WeatherMood.cloudy => dark
        ? const [Color(0xFF0F172A), Color(0xFF27364A), Color(0xFF111827)]
        : const [Color(0xFFAFC4D8), Color(0xFFD8E3ED), Color(0xFFF6FAFC)],
    _WeatherMood.sunny => dark
        ? const [Color(0xFF172033), Color(0xFF23466F), Color(0xFF0F172A)]
        : const [Color(0xFF57A7EA), Color(0xFFB7E4FF), Color(0xFFFFE8A3)],
    _WeatherMood.night => const [
        Color(0xFF020617),
        Color(0xFF0B1F3A),
        Color(0xFF111827),
      ],
  };
}

Color _weatherTextColor(_WeatherMood mood, bool dark) {
  if (dark || mood == _WeatherMood.night || mood == _WeatherMood.rain) {
    return const Color(0xFFF8FAFC);
  }
  return const Color(0xFF111827);
}

Color _weatherMutedTextColor(_WeatherMood mood, bool dark) {
  if (dark || mood == _WeatherMood.night || mood == _WeatherMood.rain) {
    return const Color(0xFFE2E8F0).withValues(alpha: 0.82);
  }
  return const Color(0xFF334155).withValues(alpha: 0.82);
}

Color _weatherAccentColor(_WeatherMood mood, bool dark) {
  return switch (mood) {
    _WeatherMood.rain => dark ? const Color(0xFF7DD3FC) : OSColors.blue,
    _WeatherMood.cloudy => dark ? const Color(0xFFCBD5E1) : OSColors.blue,
    _WeatherMood.sunny => dark ? const Color(0xFFFDE68A) : OSColors.amber,
    _WeatherMood.night => const Color(0xFF93C5FD),
  };
}

String _weatherLabel(int code) {
  if (code == 0) return 'Clear';
  if (code <= 3) return 'Partly cloudy';
  if (code == 45 || code == 48) return 'Foggy';
  if (code >= 51 && code <= 67) return 'Drizzle';
  if (code >= 71 && code <= 77) return 'Snow';
  if (code >= 80 && code <= 82) return 'Showers';
  if (code >= 95) return 'Thunderstorms';
  return 'Forecast';
}

String _stageHeadline(String teacherName, Class? primaryClass) {
  if (primaryClass != null) {
    return 'Ready for ${primaryClass.className}';
  }
  if (teacherName.isNotEmpty && teacherName != 'Teacher') {
    return 'Welcome back, $teacherName';
  }
  return 'Welcome back';
}

String _stageSupportLine({
  required Class? primaryClass,
  required TeacherWorkspaceReminderSnapshot? primaryReminder,
  required int classCount,
  required int unread,
  required String schoolName,
  required DateTime now,
}) {
  if (primaryReminder != null) {
    return '${_relativeReminderLabel(primaryReminder, now)}. ${_trimLine(primaryReminder.text, 96)}';
  }
  if (unread > 0) {
    return '$unread unread conversation${unread == 1 ? '' : 's'} waiting in Messages. Keep the day moving from this quiet command center.';
  }
  if (primaryClass != null) {
    return '${primaryClass.subject} is ready as your lead classroom. $classCount class workspace${classCount == 1 ? '' : 's'} available from $schoolName.';
  }
  return 'Open a class workspace or start Teach when the room is ready.';
}

String _relativeReminderLabel(
  TeacherWorkspaceReminderSnapshot reminder,
  DateTime now,
) {
  final today = DateTime(now.year, now.month, now.day);
  final dueDate = DateTime(
    reminder.timestamp.year,
    reminder.timestamp.month,
    reminder.timestamp.day,
  );
  final difference = dueDate.difference(today).inDays;
  if (difference < 0) {
    return 'Overdue';
  }
  if (difference == 0) {
    return 'Due today';
  }
  if (difference == 1) {
    return 'Due tomorrow';
  }
  return 'Due in $difference days';
}

String _trimLine(String value, int maxLength) {
  final normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (normalized.length <= maxLength) {
    return normalized;
  }
  return '${normalized.substring(0, maxLength - 1)}...';
}

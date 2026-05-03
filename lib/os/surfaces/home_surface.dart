// GradeFlow OS — Home Surface
//
// The teacher's primary landing surface should read like an actual OS home:
// a desktop stage, pinned apps, glanceable live signals, and secondary
// portals tucked off to the side instead of one long dashboard feed.

import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
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
import 'package:gradeflow/services/teacher_workspace_snapshot_service.dart';

class HomeSurface extends StatefulWidget {
  const HomeSurface({super.key});

  @override
  State<HomeSurface> createState() => _HomeSurfaceState();
}

class _HomeSurfaceState extends State<HomeSurface> {
  static const String _wallpaperStyleBaseKey = 'os_home_wallpaper_style_v1';
  static const String _wallpaperImageBaseKey = 'os_home_wallpaper_image_v1';

  final DashboardPreferencesService _preferences =
      const DashboardPreferencesService();
  _HomeWallpaperStyle _wallpaperStyle = _HomeWallpaperStyle.defaultStyle;
  Uint8List? _wallpaperImageBytes;
  String? _wallpaperImageBase64;
  String? _loadedUserId;
  bool _loadingWallpaper = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.read<AuthService>();
    _syncWallpaperForUser(auth.currentUser?.userId ?? 'local');
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
      if (!mounted || _loadedUserId != userId) return;
      setState(() {
        _wallpaperStyle = _HomeWallpaperStyleX.fromId(style);
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

  String get _wallpaperUserId => _loadedUserId ?? 'local';

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
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                        icon: const Icon(Icons.add_photo_alternate_outlined),
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
              ],
            ),
          ),
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
    final userId = user?.userId ?? 'local';
    if (_loadedUserId != userId && !_loadingWallpaper) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncWallpaperForUser(userId);
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

    return Scaffold(
      backgroundColor: OSColors.bg(context.isDark),
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop =
                constraints.maxWidth >= 1220 && constraints.maxHeight >= 760;
            final horizontalPadding = constraints.maxWidth < 760 ? 14.0 : 20.0;
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
                            totalStudents: totalStudents,
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
                            totalStudents: totalStudents,
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
  _HomeWorkspaceFolder? _selectedFolder;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 248,
          child: Align(
            alignment: Alignment.topLeft,
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                  height: 202,
                  child: _HomeShortcutShelf(
                    unread: widget.unread,
                    themeMode: widget.themeMode,
                    onAssistantTap: widget.onAssistantTap,
                    onLauncherTap: widget.onLauncherTap,
                    onThemeTap: widget.onThemeTap,
                    compact: true,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final stageHeight =
                  (constraints.maxHeight * 0.31).clamp(232.0, 286.0);
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
                      onAssistantTap: widget.onAssistantTap,
                      onLauncherTap: widget.onLauncherTap,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _HomeWorkspaceFolderStrip(
                    selected: _selectedFolder,
                    classCount: widget.classes.length,
                    reminderCount: widget.reminders.length,
                    unread: widget.unread,
                    onSelected: (folder) => setState(() {
                      _selectedFolder =
                          _selectedFolder == folder ? null : folder;
                    }),
                  ),
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 240),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        child: _selectedFolder == null
                            ? const _HomeCalmWorkspaceFloor(
                                key: ValueKey('workspace-closed'),
                              )
                            : _HomeWorkspaceFolderPanel(
                                key: ValueKey(_selectedFolder),
                                folder: _selectedFolder!,
                                primaryClass: widget.primaryClass,
                                classes: widget.classes,
                                reminders: widget.reminders,
                                unread: widget.unread,
                                totalStudents: widget.totalStudents,
                                now: widget.now,
                              ),
                      ),
                    ),
                  ),
                  const Spacer(),
                ],
              );
            },
          ),
        ),
        const SizedBox(width: 16),
        SizedBox(
          width: 296,
          child: _HomeUtilityRail(
            unread: widget.unread,
            reminderCount: widget.reminders.length,
            children: [
              const _HomeWeatherPanel(embedded: true),
              _HomeAudioPanel(
                embedded: true,
                onTap: () => context.go(AppRoutes.dashboard),
              ),
              _HomeAgendaPanel(
                reminders: widget.reminders,
                scrollable: true,
                embedded: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HomeUtilityRail extends StatelessWidget {
  const _HomeUtilityRail({
    required this.children,
    required this.unread,
    required this.reminderCount,
  });

  final List<Widget> children;
  final int unread;
  final int reminderCount;

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
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
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
          const SizedBox(height: 14),
          for (int index = 0; index < children.length; index++) ...[
            children[index],
            if (index != children.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

enum _HomeWorkspaceFolder {
  today(label: 'Today', icon: Icons.today_rounded, accent: OSColors.blue),
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
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
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
    );
  }

  String _folderDetail(_HomeWorkspaceFolder folder) {
    return switch (folder) {
      _HomeWorkspaceFolder.today => 'Open space',
      _HomeWorkspaceFolder.classes =>
        classCount == 0 ? 'No classes' : '$classCount active',
      _HomeWorkspaceFolder.tasks =>
        reminderCount == 0 ? 'Clear' : '$reminderCount queued',
      _HomeWorkspaceFolder.messages => unread == 0 ? 'Quiet' : '$unread unread',
      _HomeWorkspaceFolder.insights => 'Overview',
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
      width: 134,
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
      height: 214,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            left: 18,
            right: 18,
            top: 18,
            bottom: 28,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: dark
                      ? Colors.white.withValues(alpha: 0.045)
                      : Colors.white.withValues(alpha: 0.42),
                ),
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: dark ? 0.028 : 0.32),
                    Colors.white.withValues(alpha: dark ? 0.010 : 0.10),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          Positioned(
            top: 34,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: dark
                    ? Colors.white.withValues(alpha: 0.040)
                    : Colors.white.withValues(alpha: 0.56),
                borderRadius: OSRadius.pillBr,
                border: Border.all(
                  color: dark
                      ? Colors.white.withValues(alpha: 0.065)
                      : Colors.white.withValues(alpha: 0.70),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: OSColors.textMuted(dark),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Choose a folder when you need more',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: OSColors.textMuted(dark),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeWorkspaceFolderPanel extends StatelessWidget {
  const _HomeWorkspaceFolderPanel({
    super.key,
    required this.folder,
    required this.primaryClass,
    required this.classes,
    required this.reminders,
    required this.unread,
    required this.totalStudents,
    required this.now,
  });

  final _HomeWorkspaceFolder folder;
  final Class? primaryClass;
  final List<Class> classes;
  final List<TeacherWorkspaceReminderSnapshot> reminders;
  final int unread;
  final int totalStudents;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      tone: _HomePanelTone.whisper,
      radius: 28,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 176, maxHeight: 276),
        child: SingleChildScrollView(child: _buildFolderContent(context)),
      ),
    );
  }

  Widget _buildFolderContent(BuildContext context) {
    return switch (folder) {
      _HomeWorkspaceFolder.today => _TodayFolderContent(
          primaryClass: primaryClass,
          primaryReminder: reminders.isEmpty ? null : reminders.first,
          unread: unread,
          now: now,
        ),
      _HomeWorkspaceFolder.classes => _ClassesFolderContent(classes: classes),
      _HomeWorkspaceFolder.tasks => _TasksFolderContent(
          reminders: reminders,
          now: now,
        ),
      _HomeWorkspaceFolder.messages => _MessagesFolderContent(unread: unread),
      _HomeWorkspaceFolder.insights => _InsightsFolderContent(
          classCount: classes.length,
          totalStudents: totalStudents,
          unread: unread,
          reminderCount: reminders.length,
        ),
    };
  }
}

class _TodayFolderContent extends StatelessWidget {
  const _TodayFolderContent({
    required this.primaryClass,
    required this.primaryReminder,
    required this.unread,
    required this.now,
  });

  final Class? primaryClass;
  final TeacherWorkspaceReminderSnapshot? primaryReminder;
  final int unread;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    return _FolderPanelScaffold(
      eyebrow: 'Today',
      title: _formatLongDate(now),
      subtitle: unread == 0
          ? 'The workspace is quiet. Pull down what you need when you need it.'
          : '$unread unread message${unread == 1 ? '' : 's'} waiting quietly.',
      actionLabel: primaryClass == null ? 'Open Classes' : 'Open next class',
      actionIcon: Icons.arrow_forward_rounded,
      onAction: () => context.go(
        primaryClass == null
            ? AppRoutes.classes
            : AppRoutes.osClassWorkspace(primaryClass!.classId),
      ),
      child: Column(
        children: [
          _FolderInfoRow(
            icon: Icons.class_rounded,
            accent: OSColors.green,
            label: 'Next class',
            value: primaryClass == null
                ? 'No class pinned yet'
                : '${primaryClass!.className} / ${primaryClass!.subject}',
          ),
          const SizedBox(height: 10),
          _FolderInfoRow(
            icon: Icons.event_note_outlined,
            accent: OSColors.amber,
            label: 'Focus item',
            value: primaryReminder == null
                ? 'No pending reminders'
                : _trimLine(primaryReminder!.text, 82),
          ),
          const SizedBox(height: 10),
          _FolderInfoRow(
            icon: Icons.check_circle_outline_rounded,
            accent: OSColors.blue,
            label: 'Day status',
            value: primaryReminder == null && unread == 0
                ? 'Ready and uncluttered'
                : 'Signals are staged without crowding the desktop',
          ),
        ],
      ),
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
          : 'Open the class workspace when you are ready to work.',
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
              _FolderInfoRow(
                icon: Icons.dashboard_customize_rounded,
                accent: OSColors.green,
                label: visible[index].className,
                value: '${visible[index].subject} / ${visible[index].term}',
              ),
              if (index != visible.length - 1) const SizedBox(height: 10),
            ],
        ],
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
          ? 'No reminders are waiting in the workspace.'
          : '${reminders.length} item${reminders.length == 1 ? '' : 's'} staged from planning.',
      actionLabel: 'Open Planner',
      actionIcon: Icons.calendar_month_rounded,
      onAction: () => context.go(AppRoutes.osPlanner),
      child: Column(
        children: [
          if (visible.isEmpty)
            const _FolderEmptyLine('New planning reminders will appear here.')
          else
            for (int index = 0; index < visible.length; index++) ...[
              _FolderInfoRow(
                icon: Icons.task_alt_rounded,
                accent: OSColors.amber,
                label: _relativeReminderLabel(visible[index], now),
                value: _trimLine(visible[index].text, 90),
              ),
              if (index != visible.length - 1) const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _MessagesFolderContent extends StatelessWidget {
  const _MessagesFolderContent({required this.unread});

  final int unread;

  @override
  Widget build(BuildContext context) {
    return _FolderPanelScaffold(
      eyebrow: 'Messages',
      title: unread == 0
          ? 'Inbox quiet'
          : '$unread unread update${unread == 1 ? '' : 's'}',
      subtitle: 'A calm preview for school communication, not a full inbox.',
      actionLabel: 'Open Messages',
      actionIcon: Icons.forum_rounded,
      onAction: () => context.go(AppRoutes.communication),
      child: Column(
        children: [
          _FolderInfoRow(
            icon: Icons.mark_email_read_outlined,
            accent: OSColors.cyan,
            label: 'Inbox',
            value: unread == 0
                ? 'No unread conversations'
                : 'Unread conversations are waiting',
          ),
          const SizedBox(height: 10),
          _FolderInfoRow(
            icon: Icons.shield_moon_outlined,
            accent: OSColors.blue,
            label: 'Focus mode',
            value: 'Messages stay nearby without taking over the desktop',
          ),
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
      title: 'Teaching load overview',
      subtitle: 'Lightweight signals only. Detailed analytics can wait.',
      actionLabel: 'Open Classes',
      actionIcon: Icons.class_rounded,
      onAction: () => context.go(AppRoutes.classes),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _FolderMetric(
              label: 'Classes', value: '$classCount', accent: OSColors.green),
          _FolderMetric(
              label: 'Students',
              value: '$totalStudents',
              accent: OSColors.cyan),
          _FolderMetric(
              label: 'Messages',
              value: unread == 0 ? 'Quiet' : '$unread',
              accent: OSColors.blue),
          _FolderMetric(
              label: 'Tasks',
              value: reminderCount == 0 ? 'Clear' : '$reminderCount',
              accent: OSColors.amber),
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
  });

  final IconData icon;
  final Color accent;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
          Icon(icon, size: 17, color: accent),
          const SizedBox(width: 10),
          SizedBox(
            width: 98,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: OSColors.text(dark),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: OSColors.textSecondary(dark),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FolderMetric extends StatelessWidget {
  const _FolderMetric({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return Container(
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
  _HomeWorkspaceFolder? _selectedFolder;

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
            onAssistantTap: widget.onAssistantTap,
            onLauncherTap: widget.onLauncherTap,
          ),
        ),
        const SizedBox(height: 14),
        _HomeWorkspaceFolderStrip(
          selected: _selectedFolder,
          classCount: widget.classes.length,
          reminderCount: widget.reminders.length,
          unread: widget.unread,
          onSelected: (folder) => setState(() {
            _selectedFolder = _selectedFolder == folder ? null : folder;
          }),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 240),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: _selectedFolder == null
              ? const SizedBox.shrink(key: ValueKey('workspace-closed'))
              : Padding(
                  key: ValueKey(_selectedFolder),
                  padding: const EdgeInsets.only(top: 14),
                  child: _HomeWorkspaceFolderPanel(
                    folder: _selectedFolder!,
                    primaryClass: widget.primaryClass,
                    classes: widget.classes,
                    reminders: widget.reminders,
                    unread: widget.unread,
                    totalStudents: widget.totalStudents,
                    now: widget.now,
                  ),
                ),
        ),
        const SizedBox(height: 16),
        _HomeShortcutShelf(
          unread: widget.unread,
          themeMode: widget.themeMode,
          onAssistantTap: widget.onAssistantTap,
          onLauncherTap: widget.onLauncherTap,
          onThemeTap: widget.onThemeTap,
        ),
        const SizedBox(height: 16),
        _HomeUtilityRail(
          unread: widget.unread,
          reminderCount: widget.reminders.length,
          children: [
            const _HomeWeatherPanel(embedded: true),
            _HomeAgendaPanel(
              reminders: widget.reminders,
              scrollable: false,
              embedded: true,
            ),
          ],
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

class _HomeBackdrop extends StatelessWidget {
  const _HomeBackdrop({
    required this.style,
    required this.imageBytes,
  });

  final _HomeWallpaperStyle style;
  final Uint8List? imageBytes;

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
            child: Image.memory(
              imageBytes!,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
            ),
          ),
        if (useImage)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: dark
                    ? Colors.black.withValues(alpha: 0.42)
                    : Colors.white.withValues(alpha: 0.28),
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
                        'GradeFlow OS',
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
                        'GradeFlow OS',
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
                            : '$teacherName · $schoolName',
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
                      'GradeFlow OS',
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
    required this.onAssistantTap,
    required this.onLauncherTap,
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
  final VoidCallback onAssistantTap;
  final VoidCallback onLauncherTap;

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
    final actions = [
      _StageActionData(
        label: 'Teach',
        icon: Icons.cast_for_education_rounded,
        accent: OSColors.blue,
        filled: true,
        onTap: () => context.go(AppRoutes.osTeach),
      ),
      _StageActionData(
        label: 'Planner',
        icon: Icons.calendar_month_rounded,
        accent: OSColors.amber,
        onTap: () => context.go(AppRoutes.osPlanner),
      ),
      _StageActionData(
        label: 'Classes',
        icon: Icons.class_rounded,
        accent: OSColors.green,
        onTap: () => context.go(AppRoutes.classes),
      ),
      _StageActionData(
        label: unread == 0 ? 'Messages' : 'Messages $unread',
        icon: Icons.forum_rounded,
        accent: OSColors.cyan,
        onTap: () => context.go(AppRoutes.communication),
      ),
      _StageActionData(
        label: 'Assistant',
        icon: Icons.auto_awesome_rounded,
        accent: OSColors.indigo,
        onTap: onAssistantTap,
      ),
      _StageActionData(
        label: 'Launcher',
        icon: Icons.grid_view_rounded,
        accent: OSColors.amber,
        onTap: onLauncherTap,
      ),
    ];

    return _GlassPanel(
      tone: _HomePanelTone.stage,
      radius: compact ? WorkspaceRadius.shellCompact : WorkspaceRadius.shell,
      padding: EdgeInsets.all(compact ? 22 : 20),
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
                        onTap: primaryClass == null
                            ? null
                            : () => context.go(
                                  '${AppRoutes.osClass}/${primaryClass!.classId}',
                                ),
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
                        onTap: () => context.go(AppRoutes.osPlanner),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _StageActionCarousel(actions: actions),
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
              actions: actions,
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
    required this.actions,
  });

  final String teacherName;
  final String schoolName;
  final Class? primaryClass;
  final TeacherWorkspaceReminderSnapshot? primaryReminder;
  final int classCount;
  final int unread;
  final DateTime now;
  final List<_StageActionData> actions;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;

    return Column(
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
        const SizedBox(height: 12),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 245,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _formatClock(now),
                        style: TextStyle(
                          fontSize: 56,
                          height: 0.88,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0,
                          color: OSColors.text(dark),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatLongDate(now),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: OSColors.textSecondary(dark),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _stageHeadline(teacherName, primaryClass),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 25,
                        height: 1.05,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                        color: OSColors.text(dark),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _stageSupportLine(
                        primaryClass: primaryClass,
                        primaryReminder: primaryReminder,
                        classCount: classCount,
                        unread: unread,
                        schoolName: schoolName,
                        now: now,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.42,
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
        _StageActionCarousel(actions: actions),
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

class _StageActionData {
  const _StageActionData({
    required this.label,
    required this.icon,
    required this.accent,
    required this.onTap,
    this.filled = false,
  });

  final String label;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;
  final bool filled;
}

class _StageActionCarousel extends StatelessWidget {
  const _StageActionCarousel({required this.actions});

  final List<_StageActionData> actions;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (rect) {
        return LinearGradient(
          colors: [
            Colors.transparent,
            Colors.black,
            Colors.black,
            Colors.transparent,
          ],
          stops: const [0.0, 0.04, 0.92, 1.0],
        ).createShader(rect);
      },
      blendMode: BlendMode.dstIn,
      child: SizedBox(
        height: 44,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: actions.length,
          separatorBuilder: (_, __) => const SizedBox(width: 9),
          itemBuilder: (context, index) {
            final action = actions[index];
            return _StageActionButton(
              label: action.label,
              icon: action.icon,
              accent: action.accent,
              filled: action.filled,
              onTap: action.onTap,
            );
          },
        ),
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

class _StageActionButton extends StatelessWidget {
  const _StageActionButton({
    required this.label,
    required this.icon,
    required this.accent,
    required this.onTap,
    this.filled = false,
  });

  final String label;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;

    return OSTouchFeedback(
      onTap: onTap,
      borderRadius: OSRadius.pillBr,
      minSize: const Size(104, 36),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: BoxDecoration(
          gradient: filled
              ? LinearGradient(
                  colors: [accent, accent.withValues(alpha: 0.72)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: filled
              ? null
              : (dark
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.white.withValues(alpha: 0.50)),
          borderRadius: OSRadius.pillBr,
          border: Border.all(
            color: filled
                ? Colors.white.withValues(alpha: 0.08)
                : (dark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.white.withValues(alpha: 0.56)),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: filled ? Colors.white : accent,
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: filled ? Colors.white : OSColors.text(dark),
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
    required this.themeMode,
    required this.onAssistantTap,
    required this.onLauncherTap,
    required this.onThemeTap,
    this.compact = false,
  });

  final int unread;
  final ThemeMode themeMode;
  final VoidCallback onAssistantTap;
  final VoidCallback onLauncherTap;
  final VoidCallback onThemeTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final shortcuts = <_HomeShortcutData>[
      _shortcutFromApp(OSAppId.teach,
          onTap: () => context.go(AppRoutes.osTeach)),
      _shortcutFromApp(OSAppId.planner,
          onTap: () => context.go(AppRoutes.osPlanner)),
      _shortcutFromApp(OSAppId.classes,
          onTap: () => context.go(AppRoutes.classes)),
      _shortcutFromApp(
        OSAppId.whiteboard,
        onTap: () => context.push(AppRoutes.whiteboard),
      ),
      _shortcutFromApp(
        OSAppId.messages,
        onTap: () => context.go(AppRoutes.communication),
        badge: unread > 0 ? '$unread' : null,
      ),
      _HomeShortcutData(
        label: 'Assistant',
        icon: Icons.auto_awesome_rounded,
        accent: OSColors.indigo,
        onTap: onAssistantTap,
      ),
      _HomeShortcutData(
        label: 'Launcher',
        icon: Icons.grid_view_rounded,
        accent: OSColors.amber,
        onTap: onLauncherTap,
      ),
      _HomeShortcutData(
        label: themeMode == ThemeMode.light ? 'Dark mode' : 'Light mode',
        icon: themeMode == ThemeMode.light
            ? Icons.dark_mode_rounded
            : Icons.light_mode_rounded,
        accent: OSColors.blue,
        onTap: onThemeTap,
      ),
    ];

    return _GlassPanel(
      tone: _HomePanelTone.whisper,
      radius: compact ? 24 : 28,
      padding: EdgeInsets.all(compact ? 13 : 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tileWidth = compact ? 72.0 : 82.0;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _PanelEyebrow(label: 'Pinned Apps'),
              SizedBox(height: compact ? 6 : 8),
              Text(
                'Quick launch',
                style: TextStyle(
                  fontSize: compact ? 15.5 : 17,
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
              SizedBox(height: compact ? 11 : 14),
              SizedBox(
                height: compact ? 86 : 96,
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
                        iconBoxSize: compact ? 50 : 58,
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
            const SizedBox(height: 7),
            Text(
              data.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
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
  const _HomeWeatherPanel({this.embedded = false});

  final bool embedded;

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

        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: _PanelEyebrow(label: 'Local Conditions'),
                ),
                Icon(
                  data == null
                      ? Icons.cloud_queue_rounded
                      : _weatherIcon(data.weatherCode),
                  color: OSColors.blue,
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              hasError
                  ? 'Forecast unavailable'
                  : loading
                      ? 'Checking forecast'
                      : '${data!.temperatureC.round()} C ${_weatherLabel(data.weatherCode)}',
              style: TextStyle(
                fontSize: 18,
                height: 1.1,
                fontWeight: FontWeight.w800,
                color: OSColors.text(dark),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              hasError
                  ? 'Weather will return when the network responds.'
                  : loading
                      ? 'Taichung City'
                      : '${data!.locationName} - feels like ${data.apparentTempC.round()} C',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: OSColors.textSecondary(dark),
              ),
            ),
            if (forecast.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  for (int index = 0; index < forecast.length; index++) ...[
                    if (index > 0) const SizedBox(width: 8),
                    Expanded(
                      child: _WeatherForecastTile(day: forecast[index]),
                    ),
                  ],
                ],
              ),
            ],
          ],
        );
        return widget.embedded
            ? _RailSection(child: content)
            : _GlassPanel(
                tone: _HomePanelTone.whisper,
                radius: 28,
                padding: const EdgeInsets.all(16),
                child: content,
              );
      },
    );
  }
}

class _WeatherForecastTile extends StatelessWidget {
  const _WeatherForecastTile({required this.day});

  final DashboardForecastDay day;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: dark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.white.withValues(alpha: 0.64),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: dark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.white.withValues(alpha: 0.70),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_weatherIcon(day.weatherCode), size: 16, color: OSColors.blue),
          const SizedBox(height: 8),
          Text(
            _formatDateLine(day.date),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: OSColors.textMuted(dark),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${day.maxTempC.round()} / ${day.minTempC.round()} C',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: OSColors.text(dark),
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
  });

  final VoidCallback onTap;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final content = Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: OSColors.indigo.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: OSColors.indigo.withValues(alpha: 0.22),
            ),
          ),
          child: const Icon(
            Icons.graphic_eq_rounded,
            color: OSColors.indigo,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _PanelEyebrow(label: 'Focus Audio'),
              const SizedBox(height: 6),
              Text(
                'Classroom sound',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: OSColors.text(dark),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Open stations and quiet focus audio.',
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
        Icon(
          Icons.chevron_right_rounded,
          size: 20,
          color: OSColors.textMuted(dark),
        ),
      ],
    );

    return OSTouchFeedback(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      minSize: const Size(180, 104),
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

class _HomeAgendaPanel extends StatelessWidget {
  const _HomeAgendaPanel({
    required this.reminders,
    required this.scrollable,
    this.embedded = false,
  });

  final List<TeacherWorkspaceReminderSnapshot> reminders;
  final bool scrollable;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final visibleReminders =
        scrollable ? reminders : reminders.take(4).toList();
    final dark = context.isDark;
    final headerChildren = <Widget>[
      const _PanelEyebrow(label: 'Agenda Queue'),
      const SizedBox(height: 8),
      Text(
        reminders.isEmpty ? 'Clear for now' : 'Next reminders',
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
          color: OSColors.text(dark),
        ),
      ),
      const SizedBox(height: 4),
      Text(
        reminders.isEmpty
            ? 'Nothing is queued right now.'
            : 'Priority items stay visible without crowding the workspace.',
        style: TextStyle(
          fontSize: 12,
          height: 1.45,
          color: OSColors.textSecondary(dark),
        ),
      ),
      const SizedBox(height: 10),
    ];

    final content = scrollable
        ? ListView(
            padding: EdgeInsets.zero,
            children: [
              ...headerChildren,
              if (reminders.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: dark
                        ? Colors.white.withValues(alpha: 0.04)
                        : Colors.white.withValues(alpha: 0.66),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: dark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.white.withValues(alpha: 0.72),
                    ),
                  ),
                  child: Text(
                    'Your day is currently clear. New reminders from the planning hub will surface here automatically.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      color: OSColors.textSecondary(dark),
                    ),
                  ),
                )
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
              if (reminders.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: dark
                        ? Colors.white.withValues(alpha: 0.04)
                        : Colors.white.withValues(alpha: 0.66),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: dark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.white.withValues(alpha: 0.72),
                    ),
                  ),
                  child: Text(
                    'Your day is currently clear. New reminders from the planning hub will surface here automatically.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      color: OSColors.textSecondary(dark),
                    ),
                  ),
                )
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

    return embedded
        ? _RailSection(
            expand: scrollable,
            child: content,
          )
        : _GlassPanel(
            tone: _HomePanelTone.whisper,
            radius: 28,
            padding: const EdgeInsets.all(16),
            child: content,
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

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: dark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.white.withValues(alpha: 0.66),
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
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: accent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
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

    final section = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: dark
            ? Colors.white.withValues(alpha: 0.035)
            : Colors.white.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: dark
              ? Colors.white.withValues(alpha: 0.055)
              : Colors.white.withValues(alpha: 0.58),
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

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(
          sigmaX: blurSigma,
          sigmaY: blurSigma,
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: borderColor),
            boxShadow: WorkspaceChrome.panelShadow(
              context,
              emphasis: shadowEmphasis,
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
                            baseColor,
                            secondaryColor,
                            baseColor,
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

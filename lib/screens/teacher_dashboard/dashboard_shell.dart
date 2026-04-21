// ignore_for_file: invalid_use_of_protected_member, library_private_types_in_public_api

part of '../teacher_dashboard_screen.dart';

class _DashboardPalette {
  static Brightness brightness = Brightness.dark;

  static bool get _isLight => brightness == Brightness.light;
  static bool get isLight => _isLight;

  static Color get background =>
      _isLight ? const Color(0xFFF3F6FB) : const Color(0xFF0A0F17);
  static Color get backgroundAlt =>
      _isLight ? const Color(0xFFEAF0F7) : const Color(0xFF111827);
  static Color get sidebar =>
      _isLight ? const Color(0xFFF5F8FC) : const Color(0xFF0E1420);
  static Color get sidebarAlt =>
      _isLight ? const Color(0xFFFFFFFF) : const Color(0xFF131A26);
  static Color get panel =>
      _isLight ? const Color(0xFFFFFFFF) : const Color(0xFF131A26);
  static Color get panelAlt =>
      _isLight ? const Color(0xFFF5F8FD) : const Color(0xFF1A2130);
  static Color get panelElevated =>
      _isLight ? const Color(0xFFFFFFFF) : const Color(0xFF1C2433);
  static Color get border =>
      _isLight ? const Color(0xFFD7E0EC) : const Color(0xFF263042);
  static Color get textPrimary =>
      _isLight ? const Color(0xFF142033) : const Color(0xFFF5F7FB);
  static Color get textSecondary =>
      _isLight ? const Color(0xFF607089) : const Color(0xFF9BA8BC);
  static Color get muted =>
      _isLight ? const Color(0xFF7B8AA1) : const Color(0xFF66758C);
  static Color get accent =>
      _isLight ? const Color(0xFF4F74FF) : const Color(0xFF5C88FF);
  static Color get accentSoft =>
      _isLight ? const Color(0xFF6F90FF) : const Color(0xFF8DB1FF);
  static Color get amber =>
      _isLight ? const Color(0xFFE4A146) : const Color(0xFFF4B45F);
  static Color get coral =>
      _isLight ? const Color(0xFFE46F59) : const Color(0xFFEF7E67);
  static Color get green =>
      _isLight ? const Color(0xFF3EAD74) : const Color(0xFF58C78B);
  static Color get cyan =>
      _isLight ? const Color(0xFF44AFCB) : const Color(0xFF5EC7E6);
  static Color get purple =>
      _isLight ? const Color(0xFF7869E8) : const Color(0xFF8C7CF8);
}

Color _dashboardInteractiveOverlay({
  double emphasis = 1,
}) {
  final baseAlpha = _DashboardPalette.isLight ? 0.06 : 0.11;
  return _DashboardPalette.accent.withValues(alpha: baseAlpha * emphasis);
}

const Duration _shellMotionFast = Duration(milliseconds: 170);
const Duration _shellMotionNormal = Duration(milliseconds: 220);
const Curve _shellEase = Curves.easeOutCubic;

bool _isTouchLikeViewport(BuildContext context) {
  final shortest = MediaQuery.sizeOf(context).shortestSide;
  return shortest < 700;
}

Matrix4 _shellMotionTransform(
  BuildContext context, {
  required double lift,
  required double scale,
}) {
  final width = MediaQuery.sizeOf(context).width;
  final touchLike = _isTouchLikeViewport(context);
  final tunedLift = touchLike ? 0.0 : (width < 1180 ? lift * 0.72 : lift);
  final tunedScale =
      touchLike ? 1.0 : (width < 1180 ? 1 + ((scale - 1) * 0.72) : scale);
  final matrix = Matrix4.diagonal3Values(tunedScale, tunedScale, 1.0);
  matrix.setTranslationRaw(0.0, tunedLift, 0.0);
  return matrix;
}

class DashboardNavItemData {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isActive;
  final String? badge;

  const DashboardNavItemData({
    required this.label,
    required this.icon,
    required this.onTap,
    this.isActive = false,
    this.badge,
  });
}

class DashboardSummaryMetricData {
  final String label;
  final String value;
  final String detail;
  final IconData icon;
  final List<Color> gradientColors;
  final String actionLabel;
  final VoidCallback? onTap;

  const DashboardSummaryMetricData({
    required this.label,
    required this.value,
    required this.detail,
    required this.icon,
    required this.gradientColors,
    required this.actionLabel,
    this.onTap,
  });
}

class DashboardHeroPresentation {
  final String label;
  final List<Color> gradientColors;
  final Color primaryGlow;
  final Color secondaryGlow;
  final Color tertiaryGlow;

  const DashboardHeroPresentation({
    required this.label,
    required this.gradientColors,
    required this.primaryGlow,
    required this.secondaryGlow,
    required this.tertiaryGlow,
  });
}

class DashboardInlineActionData {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const DashboardInlineActionData({
    required this.label,
    required this.icon,
    required this.onTap,
  });
}

class DashboardClassStatusData {
  final String id;
  final String title;
  final String subtitle;
  final ClassHealthLevel level;
  final String levelLabel;
  final String statusLabel;
  final String statusDetail;
  final String recommendedLabel;
  final String recommendedDetail;
  final IconData statusIcon;
  final Color accent;
  final bool isSelected;
  final int studentCount;
  final List<DashboardClassMetricData> metrics;
  final VoidCallback onTap;
  final List<DashboardInlineActionData> actions;
  final bool suppressTimetableWarning;

  const DashboardClassStatusData({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.level,
    required this.levelLabel,
    required this.statusLabel,
    required this.statusDetail,
    required this.recommendedLabel,
    required this.recommendedDetail,
    required this.statusIcon,
    required this.accent,
    required this.isSelected,
    required this.studentCount,
    required this.metrics,
    required this.onTap,
    required this.actions,
    this.suppressTimetableWarning = false,
  });
}

class DashboardClassMetricData {
  final IconData icon;
  final String label;

  const DashboardClassMetricData({
    required this.icon,
    required this.label,
  });
}

class DashboardQuickActionData {
  final String label;
  final String detail;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  const DashboardQuickActionData({
    required this.label,
    required this.detail,
    required this.icon,
    required this.accent,
    required this.onTap,
  });
}

class _DashboardInsightData {
  final String title;
  final String value;
  final String subtitle;
  final List<double> bars;
  final Color accent;

  const _DashboardInsightData({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.bars,
    required this.accent,
  });
}

class DashboardSystemWidgetData {
  final String timeLabel;
  final String weekdayLabel;
  final String dateLabel;
  final String locationLabel;
  final String weatherLabel;
  final String weatherDetail;
  final IconData weatherIcon;
  final String nextLabel;
  final String nextDetail;
  final String liveLabel;

  const DashboardSystemWidgetData({
    required this.timeLabel,
    required this.weekdayLabel,
    required this.dateLabel,
    required this.locationLabel,
    required this.weatherLabel,
    required this.weatherDetail,
    required this.weatherIcon,
    required this.nextLabel,
    required this.nextDetail,
    required this.liveLabel,
  });
}

class DashboardSystemStatusItemData {
  final String label;
  final String value;
  final IconData icon;
  final Color accent;

  const DashboardSystemStatusItemData({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
  });
}

class DashboardAudioWidgetData {
  final DashboardAudioStationData activeStation;
  final List<DashboardAudioStationData> stations;
  final String recommendedLabel;
  final bool isFollowingRecommended;
  final ValueChanged<String>? onSelectStation;
  final VoidCallback? onUseRecommended;
  final VoidCallback? onAddStation;
  final ValueChanged<String>? onRemoveStation;

  const DashboardAudioWidgetData({
    required this.activeStation,
    this.stations = const <DashboardAudioStationData>[],
    this.recommendedLabel = 'Recommended now',
    this.isFollowingRecommended = true,
    this.onSelectStation,
    this.onUseRecommended,
    this.onAddStation,
    this.onRemoveStation,
  });
}

class DashboardAudioStationData {
  final String id;
  final String stationName;
  final String programLabel;
  final String detail;
  final String? streamUrl;
  final String stationUrl;
  final String countryLabel;
  final String categoryLabel;
  final IconData icon;
  final List<Color> gradientColors;
  final bool isCustom;

  const DashboardAudioStationData({
    required this.id,
    required this.stationName,
    required this.programLabel,
    required this.detail,
    required this.streamUrl,
    required this.stationUrl,
    required this.countryLabel,
    required this.categoryLabel,
    required this.icon,
    required this.gradientColors,
    this.isCustom = false,
  });

  bool get supportsInlinePlayback =>
      streamUrl != null && streamUrl!.trim().isNotEmpty;
}

class DashboardCommunicationWidgetData {
  final String headline;
  final String detail;
  final int unreadCount;
  final List<DashboardCommunicationThreadData> threads;
  final VoidCallback onTap;

  const DashboardCommunicationWidgetData({
    required this.headline,
    required this.detail,
    required this.unreadCount,
    required this.threads,
    required this.onTap,
  });
}

class DashboardCommunicationThreadData {
  final String title;
  final String preview;
  final String meta;
  final IconData icon;
  final Color accent;
  final int unreadCount;

  const DashboardCommunicationThreadData({
    required this.title,
    required this.preview,
    required this.meta,
    required this.icon,
    required this.accent,
    required this.unreadCount,
  });
}

class _DashboardMobileTabData {
  final String label;
  final IconData icon;

  const _DashboardMobileTabData({
    required this.label,
    required this.icon,
  });
}

extension TeacherDashboardShell on _TeacherDashboardScreenState {
  static const double _mobileBreakpoint = 760;
  static const double _desktopBreakpoint = 1180;

  ThemeData _dashboardTheme(BuildContext context) {
    final inherited = Theme.of(context);
    final base =
        inherited.brightness == Brightness.light ? lightTheme : darkTheme;
    _DashboardPalette.brightness = base.brightness;
    final colorScheme = base.colorScheme.copyWith(
      primary: _DashboardPalette.accent,
      onPrimary: Colors.white,
      primaryContainer: _DashboardPalette.brightness == Brightness.light
          ? const Color(0xFFDCE6FF)
          : const Color(0xFF22345C),
      onPrimaryContainer: _DashboardPalette.brightness == Brightness.light
          ? const Color(0xFF193066)
          : const Color(0xFFE8EEFF),
      secondary: _DashboardPalette.textSecondary,
      onSecondary: _DashboardPalette.background,
      surface: _DashboardPalette.panel,
      onSurface: _DashboardPalette.textPrimary,
      onSurfaceVariant: _DashboardPalette.textSecondary,
      outline: _DashboardPalette.border,
      shadow: Colors.black,
    );

    final dashboardBaseTextTheme =
        kIsWeb || !GoogleFonts.config.allowRuntimeFetching
            ? base.textTheme
            : GoogleFonts.plusJakartaSansTextTheme(base.textTheme);
    final textTheme = dashboardBaseTextTheme.apply(
      bodyColor: _DashboardPalette.textPrimary,
      displayColor: _DashboardPalette.textPrimary,
    );

    return base.copyWith(
      colorScheme: colorScheme,
      brightness: base.brightness,
      scaffoldBackgroundColor: _DashboardPalette.background,
      dividerColor: _DashboardPalette.border,
      textTheme: textTheme.copyWith(
        headlineMedium: textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
        titleLarge: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        titleMedium: textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        bodyMedium: textTheme.bodyMedium?.copyWith(height: 1.5),
        bodySmall: textTheme.bodySmall?.copyWith(
          color: _DashboardPalette.textSecondary,
          height: 1.45,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: _DashboardPalette.panelElevated,
        contentTextStyle: textTheme.bodyMedium,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: _DashboardPalette.border.withValues(alpha: 0.84),
          ),
        ),
      ),
      splashColor: _dashboardInteractiveOverlay(emphasis: 1.1),
      highlightColor: _dashboardInteractiveOverlay(emphasis: 1.3),
      hoverColor: _dashboardInteractiveOverlay(),
      focusColor: _dashboardInteractiveOverlay(),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _DashboardPalette.brightness == Brightness.light
            ? const Color(0xFFF7F9FC)
            : const Color(0xFF0F1520),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: _DashboardPalette.textSecondary,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: _DashboardPalette.muted,
        ),
        prefixIconColor: _DashboardPalette.textSecondary,
        suffixIconColor: _DashboardPalette.textSecondary,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: _DashboardPalette.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: _DashboardPalette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: _DashboardPalette.accentSoft,
            width: 1.2,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _DashboardPalette.accent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _DashboardPalette.textPrimary,
          side: BorderSide(color: _DashboardPalette.border),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _DashboardPalette.sidebar,
        indicatorColor: _DashboardPalette.accent.withValues(
          alpha: _DashboardPalette.brightness == Brightness.light ? 0.12 : 0.2,
        ),
      ),
    );
  }

  Widget _buildResponsiveDashboard(BuildContext context) {
    return ValueListenableBuilder<DateTime>(
      valueListenable: _nowNotifier,
      builder: (context, now, _) {
        final width = MediaQuery.sizeOf(context).width;
        final sidebar = SidebarNavigation(
          compact: width < _desktopBreakpoint,
          primaryItems: _dashboardNavItems(context),
          secondaryItems: _editionNavItems(context),
        );
        final livePanel =
            _buildLivePanelSection(context, now, compact: width < 1320);

        if (width < _mobileBreakpoint) {
          return _buildDashboardBackdrop(
            child: _buildDashboardOperatingSurface(
              context,
              now: now,
              width: width,
              surface: MobileDashboardLayout(
                body: _buildMobileDashboardBody(context, now),
                bottomNavigation: MobileBottomNavigation(
                  currentIndex: _mobileDashboardIndex,
                  onSelected: (index) {
                    setState(() => _mobileDashboardIndex = index);
                  },
                  destinations: const [
                    _DashboardMobileTabData(
                        label: 'Overview', icon: Icons.grid_view),
                    _DashboardMobileTabData(
                        label: 'Planning', icon: Icons.event_note_outlined),
                    _DashboardMobileTabData(
                        label: 'Tools', icon: Icons.widgets_outlined),
                    _DashboardMobileTabData(
                        label: 'Live', icon: Icons.campaign_outlined),
                  ],
                ),
              ),
            ),
          );
        }

        if (width < _desktopBreakpoint) {
          return _buildDashboardBackdrop(
            child: _buildDashboardOperatingSurface(
              context,
              now: now,
              width: width,
              surface: TabletDashboardLayout(
                sidebar: sidebar,
                main: _buildTabletMainContent(context, now, livePanel),
              ),
            ),
          );
        }

        return _buildDashboardBackdrop(
          child: _buildDashboardOperatingSurface(
            context,
            now: now,
            width: width,
            surface: DashboardShell(
              sidebar: sidebar,
              main: _buildDesktopMainContent(context, now),
              livePanel: livePanel,
            ),
          ),
        );
      },
    );
  }

  Widget _buildDashboardBackdrop({required Widget child}) {
    final topVeil = _DashboardPalette.isLight
        ? Colors.white.withValues(alpha: 0.44)
        : Colors.white.withValues(alpha: 0.02);
    final bottomVeil = _DashboardPalette.isLight
        ? const Color(0xFFEDF3FB).withValues(alpha: 0.72)
        : const Color(0xFF060A12).withValues(alpha: 0.66);

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  _DashboardPalette.background,
                  _DashboardPalette.backgroundAlt,
                  Color.lerp(
                    _DashboardPalette.backgroundAlt,
                    _DashboardPalette.background,
                    0.54,
                  )!,
                  _DashboardPalette.background,
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: -96,
          top: -156,
          child: _DashboardBackdropOrb(
            size: 320,
            color: _DashboardPalette.accent,
            opacity: _DashboardPalette.isLight ? 0.10 : 0.16,
          ),
        ),
        Positioned(
          right: 80,
          top: 48,
          child: _DashboardBackdropOrb(
            size: 220,
            color: _DashboardPalette.cyan,
            opacity: _DashboardPalette.isLight ? 0.08 : 0.12,
          ),
        ),
        Positioned(
          right: -84,
          bottom: -146,
          child: _DashboardBackdropOrb(
            size: 360,
            color: _DashboardPalette.green,
            opacity: _DashboardPalette.isLight ? 0.08 : 0.11,
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.22, -0.74),
                  radius: 1.18,
                  colors: [
                    topVeil,
                    Colors.transparent,
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.38, 1.0],
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(
                      alpha: _DashboardPalette.isLight ? 0.18 : 0.018,
                    ),
                    Colors.transparent,
                    Colors.transparent,
                  ],
                  stops: const [0, 0.28, 1],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 48,
          right: 48,
          bottom: -120,
          child: IgnorePointer(
            child: Container(
              height: 280,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(180),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    bottomVeil,
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(child: child),
      ],
    );
  }
}

class _DashboardBackdropOrb extends StatelessWidget {
  final double size;
  final Color color;
  final double opacity;

  const _DashboardBackdropOrb({
    required this.size,
    required this.color,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: 54, sigmaY: 54),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: opacity),
          ),
        ),
      ),
    );
  }
}

class DashboardShell extends StatelessWidget {
  final Widget sidebar;
  final Widget main;
  final Widget livePanel;

  const DashboardShell({
    super.key,
    required this.sidebar,
    required this.main,
    required this.livePanel,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        child: WorkspaceShellFrame(
          padding: const EdgeInsets.all(18),
          radius: 36,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: 220, child: sidebar),
              const SizedBox(width: 22),
              Expanded(child: main),
              const SizedBox(width: 22),
              SizedBox(
                width: 344,
                child: _DashboardUtilityRailFrame(child: livePanel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TabletDashboardLayout extends StatelessWidget {
  final Widget sidebar;
  final Widget main;

  const TabletDashboardLayout({
    super.key,
    required this.sidebar,
    required this.main,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
        child: WorkspaceShellFrame(
          padding: const EdgeInsets.all(14),
          radius: WorkspaceRadius.hero,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: 96, child: sidebar),
              const SizedBox(width: 18),
              Expanded(child: main),
            ],
          ),
        ),
      ),
    );
  }
}

class MobileDashboardLayout extends StatelessWidget {
  final Widget body;
  final Widget bottomNavigation;

  const MobileDashboardLayout({
    super.key,
    required this.body,
    required this.bottomNavigation,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SafeArea(
            bottom: false,
            child: body,
          ),
        ),
        SafeArea(
          top: false,
          child: bottomNavigation,
        ),
      ],
    );
  }
}

class MobileBottomNavigation extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onSelected;
  final List<_DashboardMobileTabData> destinations;

  const MobileBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onSelected,
    required this.destinations,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: _DashboardPalette.border.withValues(alpha: 0.86),
              ),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  _DashboardPalette.sidebarAlt.withValues(
                    alpha: _DashboardPalette.isLight ? 0.94 : 0.82,
                  ),
                  _DashboardPalette.sidebar.withValues(
                    alpha: _DashboardPalette.isLight ? 0.90 : 0.78,
                  ),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.24),
                  blurRadius: 28,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: NavigationBar(
              backgroundColor: Colors.transparent,
              selectedIndex: currentIndex,
              onDestinationSelected: onSelected,
              height: 76,
              labelBehavior:
                  NavigationDestinationLabelBehavior.onlyShowSelected,
              destinations: [
                for (final destination in destinations)
                  NavigationDestination(
                    icon: Icon(destination.icon),
                    label: destination.label,
                    tooltip: destination.label,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardUtilityRailFrame extends StatelessWidget {
  final Widget child;

  const _DashboardUtilityRailFrame({
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return WorkspaceSurfaceCard(
      radius: WorkspaceRadius.hero,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Utility rail',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Weather, signals, audio, and communication stay nearby without crowding the main deck.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: _DashboardPalette.textSecondary,
                            height: 1.4,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(WorkspaceRadius.pill),
                  color: _DashboardPalette.accent.withValues(alpha: 0.10),
                  border: Border.all(
                    color: _DashboardPalette.accent.withValues(alpha: 0.18),
                  ),
                ),
                child: Text(
                  'Live',
                  style: WorkspaceTypography.utility(
                    context,
                    color: _DashboardPalette.accentSoft,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class SidebarNavigation extends StatelessWidget {
  final bool compact;
  final List<DashboardNavItemData> primaryItems;
  final List<DashboardNavItemData> secondaryItems;

  const SidebarNavigation({
    super.key,
    required this.compact,
    required this.primaryItems,
    required this.secondaryItems,
  });

  @override
  Widget build(BuildContext context) {
    const cardPadding = EdgeInsets.fromLTRB(12, 16, 12, 16);
    final navigationItems = Column(
      crossAxisAlignment:
          compact ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        for (final item in primaryItems)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _SidebarNavButton(
              compact: compact,
              item: item,
            ),
          ),
        const SizedBox(height: 16),
        if (!compact)
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 10),
            child: Text(
              'Connected',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: _DashboardPalette.textSecondary,
                  ),
            ),
          ),
        for (final item in secondaryItems)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _SidebarNavButton(
              compact: compact,
              item: item,
              secondary: true,
            ),
          ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final hasBoundedHeight = constraints.maxHeight.isFinite;
        final availableHeight = hasBoundedHeight
            ? (constraints.maxHeight - cardPadding.vertical).clamp(
                0.0,
                double.infinity,
              )
            : null;
        final navigationBody = hasBoundedHeight
            ? SingleChildScrollView(child: navigationItems)
            : navigationItems;
        final content = Column(
          mainAxisSize: hasBoundedHeight ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment:
              compact ? CrossAxisAlignment.center : CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 12 : 14,
                vertical: compact ? 12 : 12,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: _DashboardPalette.border.withValues(alpha: 0.84),
                ),
                color: Colors.white.withValues(alpha: 0.02),
              ),
              child: compact
                  ? Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: _DashboardPalette.accent.withValues(alpha: 0.16),
                      ),
                      child: Icon(
                        Icons.grading_rounded,
                        color: _DashboardPalette.accentSoft,
                      ),
                    )
                  : Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: _DashboardPalette.accent.withValues(
                              alpha: 0.16,
                            ),
                          ),
                          child: Icon(
                            Icons.grading_rounded,
                            color: _DashboardPalette.accentSoft,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                GradeFlowProductConfig.appName,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Teacher OS',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelMedium
                                    ?.copyWith(
                                      color: _DashboardPalette.textSecondary,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 18),
            if (hasBoundedHeight)
              Expanded(child: navigationBody)
            else
              navigationBody,
            if (!compact)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: Colors.white.withValues(alpha: 0.02),
                  border: Border.all(
                    color: _DashboardPalette.border.withValues(alpha: 0.82),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Connected surfaces',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Admin and Messages stay nearby without crowding the planning hub.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
          ],
        );

        return DashboardPanelCard(
          padding: cardPadding,
          gradientColors: [
            _DashboardPalette.sidebar,
            _DashboardPalette.sidebarAlt,
          ],
          child: hasBoundedHeight
              ? SizedBox(height: availableHeight, child: content)
              : content,
        );
      },
    );
  }
}

class DashboardTopSummary extends StatefulWidget {
  final String title;
  final String subtitle;
  final String todayLine;
  final List<Widget> actions;
  final List<DashboardSummaryMetricData> metrics;
  final DashboardHeroPresentation presentation;
  final ImageProvider<Object>? backgroundImage;
  final bool compact;

  const DashboardTopSummary({
    super.key,
    required this.title,
    required this.subtitle,
    required this.todayLine,
    required this.actions,
    required this.metrics,
    required this.presentation,
    required this.backgroundImage,
    this.compact = false,
  });

  @override
  State<DashboardTopSummary> createState() => _DashboardTopSummaryState();
}

class _DashboardTopSummaryState extends State<DashboardTopSummary> {
  bool _detailsExpanded = false;

  @override
  Widget build(BuildContext context) {
    final primaryMetric =
        widget.metrics.isNotEmpty ? widget.metrics.first : null;
    final secondaryMetric =
        widget.metrics.length > 1 ? widget.metrics[1] : null;
    final summaryPills = widget.todayLine
        .split('•')
        .map((segment) => segment.trim())
        .where((segment) => segment.isNotEmpty)
        .toList(growable: false);
    final deckAccent = _commandDeckAccent(
      presentation: widget.presentation,
      backgroundImage: widget.backgroundImage,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final baseTheme = Theme.of(context);
        final wide = !widget.compact && constraints.maxWidth > 1060;
        return DashboardPanelCard(
          surfaceType: SurfaceType.whisper,
          padding: EdgeInsets.all(widget.compact ? 16 : 20),
          radius: wide ? 30 : 26,
          gradientColors: [
            _DashboardPalette.sidebarAlt,
            _DashboardPalette.sidebar,
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CommandHeader(
                eyebrow: 'Planning hub',
                title: widget.title,
                subtitle: widget.subtitle,
                leading: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: deckAccent.withValues(alpha: 0.14),
                    border: Border.all(
                      color: deckAccent.withValues(alpha: 0.20),
                    ),
                  ),
                  child: Icon(
                    Icons.space_dashboard_outlined,
                    color: deckAccent,
                    size: 22,
                  ),
                ),
                primaryAction:
                    widget.actions.isNotEmpty ? widget.actions.first : null,
                contextPills: [
                  for (final pill in summaryPills)
                    _CommandDeckSummaryPill(
                      label: pill,
                      accent: deckAccent,
                    ),
                  _CommandDeckSummaryPill(
                    label: widget.backgroundImage != null
                        ? 'Personalized hub'
                        : widget.presentation.label,
                    icon: widget.backgroundImage != null
                        ? Icons.image_outlined
                        : Icons.palette_outlined,
                    accent: deckAccent,
                  ),
                ],
                pulseTone: CommandPulseTone.calm,
                pulseLabel: 'Planning hub staged and ready',
              ),
              if (widget.actions.length > 1) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.actions.skip(1).toList(growable: false),
                ),
              ],
              if (wide) ...[
                const SizedBox(height: 16),
                _CommandDeckStagePreview(
                  presentation: widget.presentation,
                  backgroundImage: widget.backgroundImage,
                  summaryPills: summaryPills,
                  accent: deckAccent,
                  primaryMetric: primaryMetric,
                  secondaryMetric: secondaryMetric,
                ),
              ],
              if (primaryMetric != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: Colors.white.withValues(alpha: 0.035),
                    border: Border.all(
                      color: deckAccent.withValues(alpha: 0.16),
                    ),
                  ),
                  child: LayoutBuilder(
                    builder: (context, box) {
                      final narrow = box.maxWidth < 520;
                      final toggleButton = TextButton.icon(
                        onPressed: () {
                          setState(() => _detailsExpanded = !_detailsExpanded);
                        },
                        icon: Icon(
                          _detailsExpanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          color: deckAccent,
                        ),
                        label: Text(
                          _detailsExpanded ? 'Hide details' : 'Show details',
                          style: TextStyle(
                            color: deckAccent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      );
                      final primaryActionButton = TextButton.icon(
                        onPressed: primaryMetric.onTap,
                        icon: Icon(
                          primaryMetric.icon,
                          color: deckAccent,
                          size: 18,
                        ),
                        label: Text(
                          primaryMetric.actionLabel,
                          style: TextStyle(
                            color: deckAccent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      );

                      final summaryCopy = Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _detailsExpanded
                                  ? 'Planning hub details open'
                                  : '${primaryMetric.label} is ready',
                              style: baseTheme.textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${primaryMetric.value} • ${primaryMetric.detail}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: baseTheme.textTheme.bodySmall?.copyWith(
                                color: _DashboardPalette.textSecondary,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      );

                      final badge = Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: deckAccent.withValues(alpha: 0.12),
                          border: Border.all(
                            color: deckAccent.withValues(alpha: 0.18),
                          ),
                        ),
                        child: Icon(
                          _detailsExpanded
                              ? Icons.unfold_less_rounded
                              : Icons.unfold_more_rounded,
                          color: deckAccent,
                          size: 18,
                        ),
                      );

                      if (narrow) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                badge,
                                const SizedBox(width: 10),
                                summaryCopy,
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                primaryActionButton,
                                toggleButton,
                              ],
                            ),
                          ],
                        );
                      }

                      return Row(
                        children: [
                          badge,
                          const SizedBox(width: 10),
                          summaryCopy,
                          const SizedBox(width: 8),
                          primaryActionButton,
                          const SizedBox(width: 12),
                          toggleButton,
                        ],
                      );
                    },
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  child: !_detailsExpanded
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              for (final metric in widget.metrics)
                                SizedBox(
                                  width: widget.compact
                                      ? constraints.maxWidth
                                      : constraints.maxWidth > 1180
                                          ? (constraints.maxWidth - 20) / 3
                                          : constraints.maxWidth > 740
                                              ? (constraints.maxWidth - 10) / 2
                                              : constraints.maxWidth,
                                  child: _CommandDeckCompactMetricCard(
                                    metric: metric,
                                    accent: deckAccent,
                                  ),
                                ),
                            ],
                          ),
                        ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

Color _commandDeckAccent({
  required DashboardHeroPresentation presentation,
  required ImageProvider<Object>? backgroundImage,
}) {
  final base = backgroundImage != null
      ? presentation.secondaryGlow
      : presentation.primaryGlow;
  return Color.lerp(base, _DashboardPalette.accent, 0.38)!;
}

class _CommandDeckSummaryPill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color accent;

  const _CommandDeckSummaryPill({
    required this.label,
    this.icon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.14),
            Colors.white.withValues(alpha: 0.03),
          ],
        ),
        border: Border.all(
          color: accent.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: accent),
            const SizedBox(width: 8),
          ] else ...[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withValues(alpha: 0.92),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.22),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: _DashboardPalette.isLight
                      ? _DashboardPalette.textPrimary
                      : Colors.white.withValues(alpha: 0.90),
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _CommandDeckCompactMetricCard extends StatelessWidget {
  final DashboardSummaryMetricData metric;
  final Color accent;

  const _CommandDeckCompactMetricCard({
    required this.metric,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final panelAccent =
        Color.lerp(metric.gradientColors.first, accent, 0.58) ?? accent;

    return DashboardPanelCard(
      onTap: metric.onTap,
      radius: 20,
      padding: const EdgeInsets.all(14),
      gradientColors: [
        _DashboardPalette.panel,
        _DashboardPalette.panelAlt,
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: panelAccent.withValues(alpha: 0.12),
                  border: Border.all(
                    color: panelAccent.withValues(alpha: 0.18),
                  ),
                ),
                child: Icon(metric.icon, size: 18, color: panelAccent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  metric.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: _DashboardPalette.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            metric.value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            metric.detail,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _DashboardPalette.textSecondary,
                  height: 1.35,
                ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: panelAccent.withValues(alpha: 0.10),
              border: Border.all(
                color: panelAccent.withValues(alpha: 0.16),
              ),
            ),
            child: Row(
              children: [
                Text(
                  metric.actionLabel,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: panelAccent,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 18,
                  color: panelAccent,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommandDeckStagePreview extends StatelessWidget {
  final DashboardHeroPresentation presentation;
  final ImageProvider<Object>? backgroundImage;
  final List<String> summaryPills;
  final Color accent;
  final DashboardSummaryMetricData? primaryMetric;
  final DashboardSummaryMetricData? secondaryMetric;

  const _CommandDeckStagePreview({
    required this.presentation,
    required this.backgroundImage,
    required this.summaryPills,
    required this.accent,
    required this.primaryMetric,
    required this.secondaryMetric,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseMetric = primaryMetric ?? secondaryMetric;
    final visiblePills = summaryPills.take(3).toList(growable: false);

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 250),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: accent.withValues(alpha: 0.16),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: presentation.gradientColors,
                ),
              ),
            ),
            if (backgroundImage != null)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: backgroundImage!,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            Positioned(
              top: -26,
              right: -12,
              child: _DashboardBackdropOrb(
                size: 148,
                color: presentation.secondaryGlow,
                opacity: 0.18,
              ),
            ),
            Positioned(
              left: -32,
              bottom: -44,
              child: _DashboardBackdropOrb(
                size: 164,
                color: presentation.tertiaryGlow,
                opacity: 0.16,
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.08),
                      Colors.black.withValues(alpha: 0.34),
                      Colors.black.withValues(alpha: 0.72),
                    ],
                    stops: const [0.0, 0.46, 1.0],
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
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _CommandDeckStageChip(
                        label: 'Workspace shell',
                        icon: Icons.window_rounded,
                      ),
                      const Spacer(),
                      _CommandDeckStageChip(
                        label: backgroundImage == null
                            ? presentation.label
                            : 'Custom scene',
                        icon: backgroundImage == null
                            ? Icons.auto_awesome_rounded
                            : Icons.image_outlined,
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    'Teacher cockpit',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: Colors.white.withValues(alpha: 0.76),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    baseMetric?.value ?? 'Daily hub ready',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.7,
                      color: Colors.white,
                      height: 1.04,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    baseMetric?.detail ??
                        'Calm overview, fast pivots, and live class context stay in one shell.',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.82),
                      height: 1.45,
                    ),
                  ),
                  if (visiblePills.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final pill in visiblePills)
                          _CommandDeckStageChip(label: pill),
                      ],
                    ),
                  ],
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color: Colors.black.withValues(alpha: 0.18),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.10),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          secondaryMetric?.label ?? 'Right rail',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          secondaryMetric == null
                              ? 'Messages, signals, and live tools stay docked nearby.'
                              : '${secondaryMetric!.value} - ${secondaryMetric!.detail}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.78),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommandDeckStageChip extends StatelessWidget {
  final String label;
  final IconData? icon;

  const _CommandDeckStageChip({
    required this.label,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.16),
            Colors.white.withValues(alpha: 0.07),
          ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: Colors.white.withValues(alpha: 0.82)),
            const SizedBox(width: 7),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.88),
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _CommandDeckPrimaryPanel extends StatefulWidget {
  final DashboardSummaryMetricData metric;
  final Color accent;

  const _CommandDeckPrimaryPanel({
    required this.metric,
    required this.accent,
  });

  @override
  State<_CommandDeckPrimaryPanel> createState() =>
      _CommandDeckPrimaryPanelState();
}

class _CommandDeckPrimaryPanelState extends State<_CommandDeckPrimaryPanel>
    with SingleTickerProviderStateMixin {
  bool _hovered = false;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 6400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final metric = widget.metric;
    final panelAccent =
        Color.lerp(metric.gradientColors.first, widget.accent, 0.6)!;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: _shellMotionNormal,
        curve: _shellEase,
        transform: _shellMotionTransform(
          context,
          lift: _hovered ? -1.5 : 0.0,
          scale: _hovered ? 1.006 : 1.0,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: metric.onTap,
            borderRadius: BorderRadius.circular(22),
            hoverColor: _dashboardInteractiveOverlay(),
            focusColor: _dashboardInteractiveOverlay(),
            highlightColor: _dashboardInteractiveOverlay(emphasis: 1.25),
            splashColor: _dashboardInteractiveOverlay(emphasis: 1.35),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                color: Colors.white.withValues(alpha: 0.04),
                border: Border.all(
                  color: panelAccent.withValues(alpha: _hovered ? 0.3 : 0.22),
                ),
                boxShadow: _hovered
                    ? [
                        BoxShadow(
                          color: panelAccent.withValues(alpha: 0.16),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: IgnorePointer(
                        child: AnimatedBuilder(
                          animation: _controller,
                          builder: (context, child) {
                            return Align(
                              alignment: Alignment(
                                  -1.15 + (_controller.value * 2.3), 0),
                              child: FractionallySizedBox(
                                widthFactor: 0.4,
                                heightFactor: 1.25,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                      colors: [
                                        Colors.transparent,
                                        panelAccent.withValues(alpha: 0.08),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      metric.label,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelLarge
                                          ?.copyWith(
                                            color:
                                                _DashboardPalette.textSecondary,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      metric.value,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: -0.45,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  color: panelAccent.withValues(alpha: 0.14),
                                  border: Border.all(
                                    color: panelAccent.withValues(alpha: 0.22),
                                  ),
                                ),
                                child: Icon(
                                  metric.icon,
                                  size: 20,
                                  color: panelAccent,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            metric.detail,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: _DashboardPalette.textSecondary,
                                  height: 1.4,
                                ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              FilledButton.icon(
                                onPressed: metric.onTap,
                                style: FilledButton.styleFrom(
                                  backgroundColor:
                                      panelAccent.withValues(alpha: 0.16),
                                  foregroundColor:
                                      _DashboardPalette.textPrimary,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    side: BorderSide(
                                      color:
                                          panelAccent.withValues(alpha: 0.22),
                                    ),
                                  ),
                                ),
                                icon: Icon(metric.icon,
                                    size: 18, color: panelAccent),
                                label: Text(
                                  metric.actionLabel,
                                  style: TextStyle(
                                    color: _DashboardPalette.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                'Primary focus',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelMedium
                                    ?.copyWith(
                                      color: _DashboardPalette.textSecondary,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CommandDeckSecondaryPanel extends StatefulWidget {
  final DashboardSummaryMetricData metric;
  final Color accent;

  const _CommandDeckSecondaryPanel({
    required this.metric,
    required this.accent,
  });

  @override
  State<_CommandDeckSecondaryPanel> createState() =>
      _CommandDeckSecondaryPanelState();
}

class _CommandDeckSecondaryPanelState
    extends State<_CommandDeckSecondaryPanel> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final metric = widget.metric;
    final panelAccent =
        Color.lerp(metric.gradientColors.first, widget.accent, 0.55)!;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: _shellMotionFast,
        curve: _shellEase,
        transform: _shellMotionTransform(
          context,
          lift: _hovered ? -1.0 : 0.0,
          scale: 1.0,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: metric.onTap,
            borderRadius: BorderRadius.circular(20),
            hoverColor: _dashboardInteractiveOverlay(),
            focusColor: _dashboardInteractiveOverlay(),
            highlightColor: _dashboardInteractiveOverlay(emphasis: 1.25),
            splashColor: _dashboardInteractiveOverlay(emphasis: 1.35),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.white.withValues(alpha: 0.035),
                border: Border.all(
                  color: panelAccent.withValues(alpha: _hovered ? 0.28 : 0.18),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          metric.label,
                          style:
                              Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: _DashboardPalette.textSecondary,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ),
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: panelAccent.withValues(alpha: 0.12),
                        ),
                        child: Icon(metric.icon, size: 18, color: panelAccent),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    metric.value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.25,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    metric.detail,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: _DashboardPalette.textSecondary,
                          height: 1.4,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        metric.actionLabel,
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: panelAccent,
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 18,
                        color: panelAccent,
                      ),
                    ],
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

class _DashboardSectionTag extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? foregroundColor;
  final Color? backgroundColor;
  final Color? borderColor;

  const _DashboardSectionTag({
    required this.label,
    this.icon,
    this.foregroundColor,
    this.backgroundColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedForeground =
        foregroundColor ?? _DashboardPalette.textSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: backgroundColor ?? Colors.white.withValues(alpha: 0.05),
        border: Border.all(
          color: borderColor ?? Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: resolvedForeground),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: resolvedForeground,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.25,
                ),
          ),
        ],
      ),
    );
  }
}

class ClassStatusSection extends StatelessWidget {
  final List<DashboardClassStatusData> classes;
  final VoidCallback onOpenClasses;
  final bool compact;
  final Widget? warning;

  const ClassStatusSection({
    super.key,
    required this.classes,
    required this.onOpenClasses,
    this.compact = false,
    this.warning,
  });

  @override
  Widget build(BuildContext context) {
    DashboardClassStatusData? selectedClass;
    for (final classData in classes) {
      if (classData.isSelected) {
        selectedClass = classData;
        break;
      }
    }

    return _DashboardSectionFrame(
      title: 'Class Spaces',
      subtitle:
          'Monitor class signals here, then open the selected class workspace below.',
      action: TextButton.icon(
        onPressed: onOpenClasses,
        icon: const Icon(Icons.arrow_forward_rounded, size: 18),
        label: const Text('Open classes'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (warning != null) ...[
            warning!,
            const SizedBox(height: 12),
          ],
          if (classes.isEmpty)
            DashboardPanelCard(
              padding: const EdgeInsets.all(18),
              radius: 22,
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: _DashboardPalette.accent.withValues(alpha: 0.12),
                    ),
                    child: Icon(
                      Icons.class_outlined,
                      color: _DashboardPalette.accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Create your first class to populate class spaces here.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: _DashboardPalette.textSecondary,
                            height: 1.4,
                          ),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            _DashboardClassRail(
              classes: classes,
              compact: compact,
            ),
            if (selectedClass != null) ...[
              const SizedBox(height: 12),
              _SelectedDashboardClassPanel(
                data: selectedClass,
                compact: compact,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

Color _dashboardClassAccentForLevel(ClassHealthLevel level) {
  switch (level) {
    case ClassHealthLevel.ready:
      return _DashboardPalette.green;
    case ClassHealthLevel.attention:
      return _DashboardPalette.amber;
    case ClassHealthLevel.urgent:
      return _DashboardPalette.coral;
  }
}

class _DashboardClassRail extends StatelessWidget {
  final List<DashboardClassStatusData> classes;
  final bool compact;

  const _DashboardClassRail({
    required this.classes,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (int index = 0; index < classes.length; index++) ...[
            _DashboardClassRailTile(
              data: classes[index],
              compact: compact,
            ),
            if (index != classes.length - 1) const SizedBox(width: 10),
          ],
        ],
      ),
    );
  }
}

class _DashboardClassRailTile extends StatelessWidget {
  final DashboardClassStatusData data;
  final bool compact;

  const _DashboardClassRailTile({
    required this.data,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final statusAccent = _dashboardClassAccentForLevel(data.level);
    final selected = data.isSelected;

    return SizedBox(
      width: compact ? 214 : 236,
      child: DashboardPanelCard(
        onTap: data.onTap,
        radius: 20,
        padding: EdgeInsets.all(compact ? 12 : 14),
        gradientColors: selected
            ? [
                Color.lerp(_DashboardPalette.panel, statusAccent, 0.12) ??
                    _DashboardPalette.panel,
                Color.lerp(_DashboardPalette.panelAlt, statusAccent, 0.08) ??
                    _DashboardPalette.panelAlt,
              ]
            : [
                _DashboardPalette.panel,
                _DashboardPalette.panelAlt,
              ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: statusAccent,
                    boxShadow: [
                      BoxShadow(
                        color: statusAccent.withValues(alpha: 0.28),
                        blurRadius: 10,
                        spreadRadius: 0.4,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    data.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: statusAccent.withValues(
                      alpha: selected ? 0.16 : 0.08,
                    ),
                    border: Border.all(
                      color: statusAccent.withValues(
                        alpha: selected ? 0.26 : 0.14,
                      ),
                    ),
                  ),
                  child: Icon(
                    selected
                        ? Icons.check_rounded
                        : Icons.arrow_outward_rounded,
                    size: 16,
                    color: statusAccent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              data.subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _DashboardPalette.textSecondary,
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  data.statusIcon,
                  size: 16,
                  color: statusAccent,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    data.statusLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.people_alt_outlined,
                  size: 14,
                  color: _DashboardPalette.textSecondary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    data.studentCount == 1
                        ? '1 student'
                        : '${data.studentCount} students',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: _DashboardPalette.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                Text(
                  data.levelLabel,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: statusAccent,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectedDashboardClassPanel extends StatelessWidget {
  final DashboardClassStatusData data;
  final bool compact;

  const _SelectedDashboardClassPanel({
    required this.data,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final statusAccent = _dashboardClassAccentForLevel(data.level);
    final actions = data.actions.take(2).toList(growable: false);

    return DashboardPanelCard(
      radius: 22,
      padding: EdgeInsets.all(compact ? 14 : 16),
      gradientColors: [
        Color.lerp(_DashboardPalette.panel, statusAccent, 0.08) ??
            _DashboardPalette.panel,
        Color.lerp(_DashboardPalette.panelAlt, statusAccent, 0.04) ??
            _DashboardPalette.panelAlt,
      ],
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = !compact && constraints.maxWidth > 860;
          final summary = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: statusAccent.withValues(alpha: 0.12),
                      border: Border.all(
                        color: statusAccent.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Icon(
                      data.statusIcon,
                      color: statusAccent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data.title,
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.3,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          data.subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: _DashboardPalette.textSecondary,
                                    height: 1.35,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _DashboardSectionTag(
                    label: data.levelLabel,
                    foregroundColor: statusAccent,
                    backgroundColor: statusAccent.withValues(alpha: 0.08),
                    borderColor: statusAccent.withValues(alpha: 0.18),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _DashboardSectionTag(
                    label: data.statusLabel,
                    icon: data.statusIcon,
                    foregroundColor: statusAccent,
                    backgroundColor: statusAccent.withValues(alpha: 0.10),
                    borderColor: statusAccent.withValues(alpha: 0.18),
                  ),
                  _DashboardSectionTag(
                    label: data.studentCount == 1
                        ? '1 student'
                        : '${data.studentCount} students',
                    icon: Icons.people_alt_outlined,
                  ),
                  for (final metric in data.metrics.take(4))
                    _DashboardSectionTag(
                      label: metric.label,
                      icon: metric.icon,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                data.statusDetail.isNotEmpty
                    ? data.statusDetail
                    : data.statusLabel,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: _DashboardPalette.textSecondary,
                      height: 1.45,
                    ),
              ),
              if (data.recommendedLabel.isNotEmpty ||
                  data.recommendedDetail.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: statusAccent.withValues(alpha: 0.08),
                    border: Border.all(
                      color: statusAccent.withValues(alpha: 0.16),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Next move',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: statusAccent,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        data.recommendedLabel.isNotEmpty
                            ? data.recommendedLabel
                            : data.statusLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      if (data.recommendedDetail.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          data.recommendedDetail,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: _DashboardPalette.textSecondary,
                                    height: 1.35,
                                  ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          );

          final actionColumn = actions.isEmpty
              ? const SizedBox.shrink()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Open',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: _DashboardPalette.textSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 10),
                    for (int index = 0; index < actions.length; index++) ...[
                      _ClassActionButton(
                        action: actions[index],
                        accent: statusAccent,
                        primary: index == 0,
                        compact: false,
                        minHeight: 46,
                      ),
                      if (index != actions.length - 1)
                        const SizedBox(height: 8),
                    ],
                  ],
                );

          if (!wide || actions.isEmpty) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                summary,
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  actionColumn,
                ],
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 5, child: summary),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: actionColumn,
              ),
            ],
          );
        },
      ),
    );
  }
}

class QuickActionsSection extends StatelessWidget {
  final List<DashboardQuickActionData> actions;
  final bool compact;

  const QuickActionsSection({
    super.key,
    required this.actions,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return _DashboardSectionFrame(
      title: 'Launches',
      subtitle: 'Fast setup and teaching jumps from the planning hub.',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final columns = compact
              ? 2
              : width > 900
                  ? 4
                  : 2;
          final gap = 12.0;
          final tileWidth =
              columns == 1 ? width : (width - (gap * (columns - 1))) / columns;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final action in actions)
                SizedBox(
                  width: tileWidth,
                  child: _DashboardActionCard(data: action),
                ),
            ],
          );
        },
      ),
    );
  }
}

class DashboardWorkspaceModeStrip extends StatelessWidget {
  final DashboardWorkspaceSection selectedSection;
  final ValueChanged<DashboardWorkspaceSection> onSelected;
  final String description;
  final VoidCallback? onCustomizeLayout;

  const DashboardWorkspaceModeStrip({
    super.key,
    required this.selectedSection,
    required this.onSelected,
    required this.description,
    this.onCustomizeLayout,
  });

  String _selectionLabel() {
    switch (selectedSection) {
      case DashboardWorkspaceSection.today:
        return 'Overview';
      case DashboardWorkspaceSection.classroom:
        return 'Class tools';
      case DashboardWorkspaceSection.planning:
        return 'Planning';
      case DashboardWorkspaceSection.workspace:
        return 'Support';
    }
  }

  List<_WorkspaceStripItemData> _items() => const [
        _WorkspaceStripItemData(
          section: DashboardWorkspaceSection.today,
          label: 'Overview',
          icon: Icons.insights_outlined,
        ),
        _WorkspaceStripItemData(
          section: DashboardWorkspaceSection.classroom,
          label: 'Class tools',
          icon: Icons.draw_outlined,
        ),
        _WorkspaceStripItemData(
          section: DashboardWorkspaceSection.planning,
          label: 'Planning',
          icon: Icons.event_note_outlined,
        ),
        _WorkspaceStripItemData(
          section: DashboardWorkspaceSection.workspace,
          label: 'Support',
          icon: Icons.workspaces_outline,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final touchLike = _isTouchLikeViewport(context);
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final compactStripLabels = touchLike || viewportWidth < 1020;
    final items = _items();

    return DashboardPanelCard(
      surfaceType: SurfaceType.whisper,
      padding: const EdgeInsets.all(16),
      radius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: _DashboardPalette.accent.withValues(alpha: 0.16),
                ),
                child: Icon(
                  Icons.view_carousel_outlined,
                  size: 18,
                  color: _DashboardPalette.accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Planning hub',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'A secondary support surface for planning, reminders, and launch tools.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: _DashboardPalette.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (onCustomizeLayout != null)
                IconButton(
                  tooltip: 'Customize planning hub',
                  onPressed: onCustomizeLayout,
                  icon: const Icon(Icons.tune),
                ),
              if (onCustomizeLayout != null) const SizedBox(width: 8),
              _DashboardSectionTag(
                label: _selectionLabel(),
                icon: Icons.tune_rounded,
                foregroundColor: _DashboardPalette.accent,
                backgroundColor:
                    _DashboardPalette.accent.withValues(alpha: 0.12),
                borderColor: _DashboardPalette.accent.withValues(alpha: 0.18),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Colors.white.withValues(alpha: 0.025),
              border: Border.all(
                color: _DashboardPalette.border.withValues(alpha: 0.85),
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (int index = 0; index < items.length; index++) ...[
                    _WorkspaceStripButton(
                      item: items[index],
                      selected: selectedSection == items[index].section,
                      compactLabel: compactStripLabels,
                      onTap: () => onSelected(items[index].section),
                    ),
                    if (index != items.length - 1) const SizedBox(width: 6),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.white.withValues(alpha: 0.03),
              border: Border.all(
                color: _DashboardPalette.border.withValues(alpha: 0.72),
              ),
            ),
            child: Text(
              description,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _DashboardPalette.textSecondary,
                    height: 1.45,
                  ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkspaceStripItemData {
  final DashboardWorkspaceSection section;
  final String label;
  final IconData icon;

  const _WorkspaceStripItemData({
    required this.section,
    required this.label,
    required this.icon,
  });
}

class _WorkspaceStripButton extends StatefulWidget {
  final _WorkspaceStripItemData item;
  final bool selected;
  final bool compactLabel;
  final VoidCallback onTap;

  const _WorkspaceStripButton({
    required this.item,
    required this.selected,
    required this.compactLabel,
    required this.onTap,
  });

  @override
  State<_WorkspaceStripButton> createState() => _WorkspaceStripButtonState();
}

class _WorkspaceStripButtonState extends State<_WorkspaceStripButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.selected;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: _shellMotionNormal,
        curve: _shellEase,
        transform: _shellMotionTransform(
          context,
          lift: !active && _hovered ? -1.0 : 0.0,
          scale: !active && _hovered ? 1.006 : 1.0,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: active
              ? _DashboardPalette.accent.withValues(alpha: 0.16)
              : Colors.white.withValues(alpha: _hovered ? 0.06 : 0.02),
          border: Border.all(
            color: active
                ? _DashboardPalette.accent.withValues(alpha: 0.3)
                : _DashboardPalette.border.withValues(alpha: 0.72),
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: _DashboardPalette.accent.withValues(alpha: 0.18),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(14),
            hoverColor: _dashboardInteractiveOverlay(),
            focusColor: _dashboardInteractiveOverlay(),
            highlightColor: _dashboardInteractiveOverlay(emphasis: 1.25),
            splashColor: _dashboardInteractiveOverlay(emphasis: 1.35),
            child: AnimatedContainer(
              duration: _shellMotionFast,
              curve: _shellEase,
              constraints: BoxConstraints(
                minHeight: widget.compactLabel ? 44 : 42,
              ),
              padding: EdgeInsets.symmetric(
                horizontal: widget.compactLabel ? 11 : 12,
                vertical: 9,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.item.icon,
                    size: 17,
                    color: active
                        ? _DashboardPalette.accentSoft
                        : _DashboardPalette.textSecondary,
                  ),
                  if (!widget.compactLabel) ...[
                    const SizedBox(width: 8),
                    Text(
                      widget.item.label,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: active
                                ? _DashboardPalette.textPrimary
                                : _DashboardPalette.textSecondary,
                            fontWeight:
                                active ? FontWeight.w800 : FontWeight.w700,
                          ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DashboardSectionPreviewCard extends StatelessWidget {
  final String title;
  final String detail;
  final IconData icon;
  final String actionLabel;
  final VoidCallback onTap;

  const DashboardSectionPreviewCard({
    super.key,
    required this.title,
    required this.detail,
    required this.icon,
    required this.actionLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return DashboardPanelCard(
      surfaceType: SurfaceType.tool,
      padding: const EdgeInsets.all(16),
      radius: 22,
      minHeight: 170,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DashboardSectionTag(
            label: 'Standby',
            icon: icon,
            foregroundColor: _DashboardPalette.accent,
            backgroundColor: _DashboardPalette.accent.withValues(alpha: 0.12),
            borderColor: _DashboardPalette.accent.withValues(alpha: 0.18),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            detail,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _DashboardPalette.textSecondary,
                  height: 1.45,
                ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.white.withValues(alpha: 0.04),
              border: Border.all(
                color: _DashboardPalette.border.withValues(alpha: 0.78),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    actionLabel,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: _DashboardPalette.accent.withValues(alpha: 0.12),
                  ),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: _DashboardPalette.accent,
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

class InsightsSection extends StatelessWidget {
  final List<_DashboardInsightData> insights;
  final bool compact;

  const InsightsSection({
    super.key,
    required this.insights,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return _DashboardSectionFrame(
      title: 'Insights',
      subtitle: 'Signal over noise for the week ahead.',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final columns = compact
              ? 1
              : width > 980
                  ? 3
                  : 2;
          final gap = 14.0;
          final tileWidth =
              columns == 1 ? width : (width - (gap * (columns - 1))) / columns;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final insight in insights)
                SizedBox(
                  width: tileWidth,
                  child: _DashboardInsightCard(data: insight),
                ),
            ],
          );
        },
      ),
    );
  }
}

class PlanningSection extends StatelessWidget {
  final List<Widget> panels;
  final bool compact;

  const PlanningSection({
    super.key,
    required this.panels,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return _DashboardSectionFrame(
      title: 'Planning lane',
      subtitle: 'Reminders, calendar, and timetable stay visible here.',
      child: _ResponsivePanelWrap(
        compact: compact,
        children: panels,
      ),
    );
  }
}

class WorkspaceSection extends StatelessWidget {
  final List<Widget> panels;
  final bool compact;

  const WorkspaceSection({
    super.key,
    required this.panels,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return _DashboardSectionFrame(
      title: 'Support tools',
      subtitle: 'Links, research, and utility panels on standby.',
      child: _ResponsivePanelWrap(
        compact: compact,
        children: panels,
      ),
    );
  }
}

class LivePanel extends StatelessWidget {
  final DashboardSystemWidgetData systemWidget;
  final DashboardAudioWidgetData audioWidget;
  final List<DashboardSystemStatusItemData> statusItems;
  final DashboardCommunicationWidgetData communicationWidget;
  final bool compact;

  const LivePanel({
    super.key,
    required this.systemWidget,
    required this.audioWidget,
    required this.statusItems,
    required this.communicationWidget,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DashboardSystemWidgetCard(
          data: systemWidget,
          compact: compact,
        ),
        const SizedBox(height: 12),
        _DashboardAudioWidgetCard(
          data: audioWidget,
        ),
        const SizedBox(height: 12),
        _DashboardSystemStatusCard(
          items: statusItems,
        ),
        const SizedBox(height: 12),
        _DashboardCommunicationWidgetCard(
          data: communicationWidget,
          compact: compact,
        ),
      ],
    );
  }
}

class _DashboardSystemWidgetCard extends StatelessWidget {
  final DashboardSystemWidgetData data;
  final bool compact;

  const _DashboardSystemWidgetCard({
    required this.data,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return DashboardPanelCard(
      padding: const EdgeInsets.all(16),
      radius: 22,
      minHeight: compact ? 0 : 188,
      gradientColors: [
        _DashboardPalette.sidebarAlt,
        _DashboardPalette.panel,
      ],
      child: Stack(
        children: [
          Positioned(
            top: -28,
            right: -24,
            child: IgnorePointer(
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _DashboardPalette.accent.withValues(alpha: 0.20),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _SystemWidgetBadge(
                    label: data.liveLabel,
                    icon: Icons.cloud_done_outlined,
                    emphasized: true,
                  ),
                  const Spacer(),
                  Icon(
                    data.weatherIcon,
                    size: 20,
                    color: _DashboardPalette.accent,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.08),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: Text(
                  data.timeLabel,
                  key: ValueKey<String>(data.timeLabel),
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.15,
                      ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${data.weekdayLabel} • ${data.dateLabel}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: _DashboardPalette.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: Colors.white.withValues(alpha: 0.04),
                  border: Border.all(
                    color: _DashboardPalette.border.withValues(alpha: 0.82),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: _DashboardPalette.accent.withValues(alpha: 0.12),
                      ),
                      child: Icon(
                        data.weatherIcon,
                        size: 20,
                        color: _DashboardPalette.accent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${data.weatherLabel} ${data.weatherDetail}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            data.locationLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: _DashboardPalette.textSecondary,
                                    ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _SystemMetricTile(
                      label: 'Location',
                      value: data.locationLabel,
                      icon: Icons.location_on_outlined,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SystemMetricTile(
                      label: data.nextLabel,
                      value: data.nextDetail,
                      icon: Icons.schedule_rounded,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DashboardAudioWidgetCard extends StatefulWidget {
  final DashboardAudioWidgetData data;

  const _DashboardAudioWidgetCard({
    required this.data,
  });

  @override
  State<_DashboardAudioWidgetCard> createState() =>
      _DashboardAudioWidgetCardState();
}

class _DashboardAudioWidgetCardState extends State<_DashboardAudioWidgetCard> {
  late final DashboardAudioPlayer _audioPlayer = DashboardAudioPlayer();
  bool _playing = false;
  bool _busy = false;
  String? _errorText;

  DashboardAudioStationData get _activeStation => widget.data.activeStation;

  @override
  void didUpdateWidget(covariant _DashboardAudioWidgetCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final stationChanged = oldWidget.data.activeStation.id != _activeStation.id;
    if (_playing && stationChanged) {
      if (_activeStation.supportsInlinePlayback) {
        unawaited(_startPlayback());
      } else {
        unawaited(_stopForStationChange());
      }
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _openStationPage() async {
    await launchUrl(
      Uri.parse(_activeStation.stationUrl),
      webOnlyWindowName: '_blank',
    );
  }

  Future<void> _stopForStationChange() async {
    try {
      await _audioPlayer.pause();
    } finally {
      if (mounted) {
        setState(() {
          _playing = false;
        });
      }
    }
  }

  Future<void> _startPlayback() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _errorText = null;
    });

    try {
      if (!_audioPlayer.isSupported || !_activeStation.supportsInlinePlayback) {
        if (_playing) {
          await _audioPlayer.pause();
        }
        if (mounted) {
          setState(() {
            _playing = false;
          });
        }
        await _openStationPage();
        return;
      }

      await _audioPlayer.play(_activeStation.streamUrl!);
      if (!mounted) return;
      setState(() {
        _playing = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _playing = false;
        _errorText = 'Stream did not start. Try again or open the station.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _pausePlayback() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _errorText = null;
    });

    try {
      await _audioPlayer.pause();
      if (!mounted) return;
      setState(() {
        _playing = false;
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _openStationLibrary() async {
    final stations = widget.data.stations;
    if (stations.isEmpty &&
        widget.data.onAddStation == null &&
        widget.data.onUseRecommended == null) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) {
        final theme = Theme.of(context);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Station library',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Pick a station for the live card or add your own stream. External-only stations open in the browser.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                if (widget.data.onUseRecommended != null)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: _DashboardPalette.accent.withValues(alpha: 0.12),
                        border: Border.all(
                          color:
                              _DashboardPalette.accent.withValues(alpha: 0.22),
                        ),
                      ),
                      child: Icon(
                        Icons.auto_awesome_rounded,
                        color: _DashboardPalette.accentSoft,
                      ),
                    ),
                    title: const Text('Follow recommended mix'),
                    subtitle: Text(widget.data.recommendedLabel),
                    trailing: widget.data.isFollowingRecommended
                        ? Icon(
                            Icons.check_circle_rounded,
                            color: _DashboardPalette.green,
                          )
                        : null,
                    onTap: () {
                      widget.data.onUseRecommended?.call();
                      Navigator.of(context).pop();
                    },
                  ),
                if (widget.data.onUseRecommended != null)
                  const Divider(height: 20),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: stations.length,
                    separatorBuilder: (_, __) => const Divider(height: 12),
                    itemBuilder: (context, index) {
                      final station = stations[index];
                      final selected = station.id == _activeStation.id;
                      final accent = station.gradientColors.first;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: station.gradientColors,
                            ),
                          ),
                          child: Icon(station.icon, color: Colors.white),
                        ),
                        title: Text(
                          station.stationName,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        subtitle: Text(
                          '${station.programLabel} • ${station.countryLabel} • ${station.categoryLabel}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.35,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                color: accent.withValues(alpha: 0.10),
                              ),
                              child: Text(
                                station.supportsInlinePlayback
                                    ? 'Direct'
                                    : 'External',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: accent,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (selected) ...[
                              const SizedBox(width: 10),
                              Icon(
                                Icons.check_circle_rounded,
                                color: _DashboardPalette.green,
                              ),
                            ],
                            if (station.isCustom &&
                                widget.data.onRemoveStation != null) ...[
                              const SizedBox(width: 4),
                              IconButton(
                                tooltip: 'Remove custom station',
                                onPressed: () {
                                  widget.data.onRemoveStation?.call(station.id);
                                  Navigator.of(context).pop();
                                },
                                icon: const Icon(Icons.delete_outline_rounded),
                              ),
                            ],
                          ],
                        ),
                        onTap: () {
                          widget.data.onSelectStation?.call(station.id);
                          Navigator.of(context).pop();
                        },
                      );
                    },
                  ),
                ),
                if (widget.data.onAddStation != null) ...[
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        widget.data.onAddStation?.call();
                      },
                      icon: const Icon(Icons.add_link_rounded),
                      label: const Text('Add custom station'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final station = _activeStation;
    final accent = Color.lerp(
          station.gradientColors.first,
          _DashboardPalette.accent,
          0.24,
        ) ??
        _DashboardPalette.accent;
    final inlineReady =
        station.supportsInlinePlayback && _audioPlayer.isSupported;
    final stations = widget.data.stations.isEmpty
        ? <DashboardAudioStationData>[station]
        : widget.data.stations;

    return DashboardPanelCard(
      padding: const EdgeInsets.all(16),
      radius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final showRecommendation = constraints.maxWidth >= 360 &&
                  widget.data.recommendedLabel.trim().isNotEmpty;
              return Row(
                children: [
                  Text(
                    'Audio',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: _DashboardPalette.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const Spacer(),
                  if (showRecommendation)
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          color: accent.withValues(alpha: 0.10),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.18),
                          ),
                        ),
                        child: Text(
                          widget.data.isFollowingRecommended
                              ? widget.data.recommendedLabel
                              : 'Pinned station',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: accent,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ),
                    ),
                  if (stations.length > 1 ||
                      widget.data.onAddStation != null ||
                      widget.data.onUseRecommended != null) ...[
                    const SizedBox(width: 6),
                    IconButton(
                      tooltip: 'Open station library',
                      onPressed: _openStationLibrary,
                      icon: const Icon(Icons.library_music_rounded),
                    ),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  station.gradientColors.first.withValues(alpha: 0.28),
                  station.gradientColors.last.withValues(alpha: 0.12),
                ],
              ),
              border: Border.all(
                color: accent.withValues(alpha: 0.22),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final stationIcon = Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: station.gradientColors,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.18),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Icon(
                        station.icon,
                        color: Colors.white,
                        size: 24,
                      ),
                    );
                    final stationCopy = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          station.stationName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          station.programLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: _DashboardPalette.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                      ],
                    );
                    final handoffBadge = Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: Colors.white.withValues(alpha: 0.10),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Text(
                        inlineReady ? 'Direct web' : 'Browser handoff',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: _DashboardPalette.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    );

                    if (constraints.maxWidth < 340) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              stationIcon,
                              const SizedBox(width: 12),
                              Expanded(child: stationCopy),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: handoffBadge,
                          ),
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        stationIcon,
                        const SizedBox(width: 12),
                        Expanded(child: stationCopy),
                        const SizedBox(width: 10),
                        Flexible(child: handoffBadge),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _DashboardAudioTag(
                      label: station.countryLabel,
                      accent: accent,
                    ),
                    _DashboardAudioTag(
                      label: station.categoryLabel,
                      accent: accent,
                    ),
                    if (station.isCustom)
                      _DashboardAudioTag(
                        label: 'Custom',
                        accent: _DashboardPalette.amber,
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: List<Widget>.generate(12, (index) {
                    final height = _playing
                        ? 10.0 + (((index * 7) % 6) * 5.0)
                        : 10.0 + ((index % 3) * 2.0);
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: index == 11 ? 0 : 4),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          height: height,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: Colors.white.withValues(
                              alpha: _playing ? 0.86 : 0.28,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            station.detail,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _DashboardPalette.textSecondary,
                  height: 1.4,
                ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final playButton = FilledButton.icon(
                onPressed:
                    _busy ? null : (_playing ? _pausePlayback : _startPlayback),
                style: FilledButton.styleFrom(
                  backgroundColor: accent.withValues(alpha: 0.18),
                  foregroundColor: _DashboardPalette.textPrimary,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: accent.withValues(alpha: 0.24),
                    ),
                  ),
                ),
                icon: _busy
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: accent,
                        ),
                      )
                    : Icon(
                        _playing
                            ? Icons.pause_rounded
                            : (inlineReady
                                ? Icons.play_arrow_rounded
                                : Icons.open_in_new_rounded),
                        color: accent,
                      ),
                label: Text(
                  _busy
                      ? (_playing ? 'Pausing' : 'Connecting')
                      : _playing
                          ? 'Pause'
                          : (inlineReady ? 'Play live' : 'Open live'),
                ),
              );
              final stationPageButton = OutlinedButton.icon(
                onPressed: _openStationPage,
                icon: const Icon(Icons.radio_rounded),
                label: const Text('Station page'),
              );
              final statusLabel = Text(
                _busy
                    ? 'Starting'
                    : _playing
                        ? 'Live'
                        : (inlineReady ? 'Ready' : 'External'),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: _DashboardPalette.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
              );

              if (constraints.maxWidth < 520) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        playButton,
                        stationPageButton,
                      ],
                    ),
                    const SizedBox(height: 8),
                    statusLabel,
                  ],
                );
              }

              return Row(
                children: [
                  playButton,
                  const SizedBox(width: 8),
                  stationPageButton,
                  const Spacer(),
                  statusLabel,
                ],
              );
            },
          ),
          if (stations.length > 1) ...[
            const SizedBox(height: 14),
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: stations.length > 6 ? 6 : stations.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final quickStation = stations[index];
                  final selected = quickStation.id == station.id;
                  final quickAccent = quickStation.gradientColors.first;
                  return FilterChip(
                    selected: selected,
                    onSelected: (_) =>
                        widget.data.onSelectStation?.call(quickStation.id),
                    label: Text(quickStation.stationName),
                    avatar: Icon(
                      quickStation.icon,
                      size: 16,
                      color: selected
                          ? _DashboardPalette.textPrimary
                          : quickAccent,
                    ),
                    selectedColor: quickAccent.withValues(alpha: 0.18),
                    backgroundColor:
                        Theme.of(context).colorScheme.surface.withValues(
                              alpha: 0.42,
                            ),
                    side: BorderSide(
                      color: selected
                          ? quickAccent.withValues(alpha: 0.28)
                          : _DashboardPalette.border.withValues(alpha: 0.8),
                    ),
                    labelStyle:
                        Theme.of(context).textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: selected
                                  ? _DashboardPalette.textPrimary
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                  );
                },
              ),
            ),
          ],
          if (_errorText != null) ...[
            const SizedBox(height: 10),
            Text(
              _errorText!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _DashboardPalette.coral,
                    height: 1.35,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DashboardAudioTag extends StatelessWidget {
  final String label;
  final Color accent;

  const _DashboardAudioTag({
    required this.label,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: accent.withValues(alpha: 0.10),
        border: Border.all(
          color: accent.withValues(alpha: 0.16),
        ),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: accent,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _DashboardSystemStatusCard extends StatelessWidget {
  final List<DashboardSystemStatusItemData> items;

  const _DashboardSystemStatusCard({
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return DashboardPanelCard(
      padding: const EdgeInsets.all(16),
      radius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'System',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: _DashboardPalette.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          for (int index = 0; index < items.length; index++) ...[
            _DashboardSystemStatusRow(item: items[index]),
            if (index != items.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _DashboardSystemStatusRow extends StatelessWidget {
  final DashboardSystemStatusItemData item;

  const _DashboardSystemStatusRow({
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.03),
        border: Border.all(
          color: _DashboardPalette.border.withValues(alpha: 0.74),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: item.accent.withValues(alpha: 0.12),
            ),
            child: Icon(
              item.icon,
              size: 18,
              color: item.accent,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              item.label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              item.value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _DashboardPalette.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardCommunicationWidgetCard extends StatefulWidget {
  final DashboardCommunicationWidgetData data;
  final bool compact;

  const _DashboardCommunicationWidgetCard({
    required this.data,
    required this.compact,
  });

  @override
  State<_DashboardCommunicationWidgetCard> createState() =>
      _DashboardCommunicationWidgetCardState();
}

class _DashboardCommunicationWidgetCardState
    extends State<_DashboardCommunicationWidgetCard> {
  bool _isHovered = false;
  bool _isExpanded = false;

  bool _touchLike({required BuildContext context}) {
    final shortestSide = MediaQuery.sizeOf(context).shortestSide;
    return shortestSide < 700;
  }

  @override
  Widget build(BuildContext context) {
    final compactCard = widget.compact;
    final touchLike = _touchLike(context: context);
    final reveal = _isExpanded || (_isHovered && !touchLike);
    final previewThreads =
        widget.data.threads.take(reveal ? (compactCard ? 2 : 3) : 1).toList();
    final accent = previewThreads.isNotEmpty
        ? previewThreads.first.accent
        : _DashboardPalette.accent;

    return MouseRegion(
      onEnter: (_) {
        if (!touchLike) {
          setState(() => _isHovered = true);
        }
      },
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onLongPress: () {
          if (touchLike) {
            setState(() => _isExpanded = !_isExpanded);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          transform: _shellMotionTransform(
            context,
            lift: reveal ? -1.5 : 0.0,
            scale: reveal ? 1.006 : 1.0,
          ),
          child: DashboardPanelCard(
            onTap: widget.data.onTap,
            padding: const EdgeInsets.all(16),
            radius: 22,
            minHeight:
                reveal ? (compactCard ? 196 : 210) : (compactCard ? 148 : 160),
            gradientColors: [
              _DashboardPalette.panel,
              _DashboardPalette.panelAlt.withValues(alpha: reveal ? 1.0 : 0.9),
            ],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Messages',
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(
                                  color: _DashboardPalette.textSecondary,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            widget.data.headline,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.2,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.data.detail,
                            maxLines: reveal ? 2 : 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: _DashboardPalette.textSecondary,
                                      height: 1.4,
                                    ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: accent.withValues(alpha: 0.12),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.20),
                        ),
                      ),
                      child: Text(
                        widget.data.unreadCount > 0
                            ? '${widget.data.unreadCount}'
                            : 'Open',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: accent,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (previewThreads.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: Colors.white.withValues(alpha: 0.03),
                      border: Border.all(
                        color: _DashboardPalette.border.withValues(alpha: 0.78),
                      ),
                    ),
                    child: Text(
                      'Inbox clear.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: _DashboardPalette.textSecondary,
                          ),
                    ),
                  ),
                for (int index = 0; index < previewThreads.length; index++) ...[
                  _CommunicationPreviewRow(
                    thread: previewThreads[index],
                    previewLines: reveal ? 2 : 1,
                    showMeta: reveal,
                  ),
                  if (index != previewThreads.length - 1)
                    const SizedBox(height: 9),
                ],
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: accent.withValues(alpha: 0.08),
                    border: Border.all(
                      color: accent.withValues(alpha: 0.16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Open inbox',
                          style:
                              Theme.of(context).textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: accent,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CommunicationPreviewRow extends StatelessWidget {
  final DashboardCommunicationThreadData thread;
  final int previewLines;
  final bool showMeta;

  const _CommunicationPreviewRow({
    required this.thread,
    this.previewLines = 1,
    this.showMeta = false,
  });

  String _wordBoundaryPreview(String input, {int maxChars = 180}) {
    final normalized = input.trim();
    if (normalized.length <= maxChars) {
      return normalized;
    }
    final cut = normalized.substring(0, maxChars);
    final boundary = cut.lastIndexOf(RegExp(r'\s'));
    final safe = boundary > 40 ? cut.substring(0, boundary) : cut;
    return safe.trimRight();
  }

  @override
  Widget build(BuildContext context) {
    final previewText = _wordBoundaryPreview(thread.preview);

    Future<void> openFullPreview() async {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(thread.title),
          content: Text(
            thread.preview,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(
          color: _DashboardPalette.border.withValues(alpha: 0.78),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: thread.accent.withValues(alpha: 0.14),
              border: Border.all(
                color: thread.accent.withValues(alpha: 0.22),
              ),
            ),
            child: Icon(
              thread.icon,
              size: 18,
              color: thread.accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  thread.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Tooltip(
                  message: thread.preview,
                  child: InkWell(
                    onTap: openFullPreview,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        previewText,
                        maxLines: previewLines,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: _DashboardPalette.textSecondary,
                              height: 1.45,
                            ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (thread.unreadCount > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: thread.accent.withValues(alpha: 0.16),
                    border: Border.all(
                      color: thread.accent.withValues(alpha: 0.24),
                    ),
                  ),
                  child: Text(
                    '${thread.unreadCount}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: thread.accent,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
              if (showMeta && thread.unreadCount > 0) const SizedBox(height: 6),
              if (showMeta)
                Text(
                  thread.meta,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: _DashboardPalette.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SystemMetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _SystemMetricTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(
          color: _DashboardPalette.border.withValues(alpha: 0.74),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: _DashboardPalette.accent.withValues(alpha: 0.14),
            ),
            child: Icon(icon, size: 18, color: _DashboardPalette.accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: _DashboardPalette.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
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

class _SystemWidgetBadge extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool emphasized;

  const _SystemWidgetBadge({
    required this.label,
    required this.icon,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = emphasized
        ? _DashboardPalette.accentSoft
        : _DashboardPalette.textSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: emphasized
            ? _DashboardPalette.accent.withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.04),
        border: Border.all(
          color: emphasized
              ? _DashboardPalette.accent.withValues(alpha: 0.18)
              : _DashboardPalette.border.withValues(alpha: 0.78),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foreground),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class DashboardPanelCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double minHeight;
  final List<Color>? gradientColors;
  final VoidCallback? onTap;
  final SurfaceType surfaceType;
  final bool expandChild;

  const DashboardPanelCard({
    super.key,
    required this.child,
    this.padding = WorkspaceSpacing.headerPadding,
    this.radius = WorkspaceRadius.card,
    this.minHeight = 0,
    this.gradientColors,
    this.onTap,
    this.surfaceType = SurfaceType.tool,
    this.expandChild = false,
  });

  @override
  Widget build(BuildContext context) {
    return CommandSurfaceCard(
      surfaceType: surfaceType,
      padding: EdgeInsets.zero,
      radius: radius,
      onTap: onTap,
      expandChild: expandChild,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight),
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

class _SidebarNavButton extends StatefulWidget {
  final bool compact;
  final bool secondary;
  final DashboardNavItemData item;

  const _SidebarNavButton({
    required this.compact,
    required this.item,
    this.secondary = false,
  });

  @override
  State<_SidebarNavButton> createState() => _SidebarNavButtonState();
}

class _SidebarNavButtonState extends State<_SidebarNavButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final active = item.isActive;
    final touchLike = _isTouchLikeViewport(context);
    final child = AnimatedContainer(
      duration: _shellMotionNormal,
      curve: _shellEase,
      padding: EdgeInsets.symmetric(
        horizontal: widget.compact ? 10 : 12,
        vertical: widget.compact ? 11 : 11,
      ),
      constraints: BoxConstraints(minHeight: widget.compact ? 44 : 46),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: active
            ? _DashboardPalette.accent.withValues(alpha: 0.12)
            : Colors.white.withValues(
                alpha: _hovered ? 0.05 : (widget.secondary ? 0.02 : 0.0),
              ),
        border: Border.all(
          color: active
              ? _DashboardPalette.accent.withValues(alpha: 0.22)
              : _DashboardPalette.border
                  .withValues(alpha: widget.secondary || _hovered ? 0.64 : 0),
        ),
        boxShadow: active
            ? [
                BoxShadow(
                  color: _DashboardPalette.accent.withValues(alpha: 0.16),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: widget.compact
          ? Icon(
              item.icon,
              color: active
                  ? _DashboardPalette.accentSoft
                  : _DashboardPalette.textSecondary,
            )
          : Row(
              children: [
                AnimatedContainer(
                  duration: _shellMotionFast,
                  curve: _shellEase,
                  width: 3,
                  height: 20,
                  margin: const EdgeInsets.only(right: 9),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color:
                        active ? _DashboardPalette.accent : Colors.transparent,
                  ),
                ),
                Icon(
                  item.icon,
                  size: 19,
                  color: active
                      ? _DashboardPalette.accentSoft
                      : _DashboardPalette.textSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: active
                              ? Colors.white
                              : _DashboardPalette.textSecondary,
                          fontWeight:
                              active ? FontWeight.w700 : FontWeight.w600,
                        ),
                  ),
                ),
                if (item.badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: active
                          ? _DashboardPalette.accent.withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.04),
                    ),
                    child: Text(
                      item.badge!,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: active
                                ? _DashboardPalette.textPrimary
                                : _DashboardPalette.textSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
              ],
            ),
    );

    return Tooltip(
      message:
          item.badge == null ? item.label : '${item.label} (${item.badge})',
      child: MouseRegion(
        onEnter: (_) {
          if (!touchLike) {
            setState(() => _hovered = true);
          }
        },
        onExit: (_) => setState(() => _hovered = false),
        child: InkWell(
          onTap: item.onTap,
          borderRadius: BorderRadius.circular(16),
          hoverColor: _dashboardInteractiveOverlay(),
          focusColor: _dashboardInteractiveOverlay(),
          highlightColor: _dashboardInteractiveOverlay(emphasis: 1.25),
          splashColor: _dashboardInteractiveOverlay(emphasis: 1.35),
          child: child,
        ),
      ),
    );
  }
}

class _DashboardSectionFrame extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? action;

  const _DashboardSectionFrame({
    required this.title,
    required this.subtitle,
    required this.child,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.35,
                        ),
                  ),
                  const SizedBox(height: 4),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 620),
                    child: Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: _DashboardPalette.textSecondary,
                            height: 1.45,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            if (action != null) ...[
              const SizedBox(width: 12),
              action!,
            ],
          ],
        ),
        const SizedBox(height: 16),
        child,
      ],
    );
  }
}

class DashboardClassCard extends StatefulWidget {
  final DashboardClassStatusData data;

  const DashboardClassCard({
    super.key,
    required this.data,
  });

  @override
  State<DashboardClassCard> createState() => _DashboardClassCardState();
}

class _DashboardClassCardState extends State<DashboardClassCard> {
  bool _isHovered = false;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didUpdateWidget(covariant DashboardClassCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data.isSelected && !widget.data.isSelected) {
      _isExpanded = false;
      _isHovered = false;
    }
  }

  Color _statusAccent() {
    return _dashboardClassAccentForLevel(widget.data.level);
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  bool _isTouchLike({
    required bool compactWidth,
    required BuildContext context,
  }) {
    final shortestSide = MediaQuery.sizeOf(context).shortestSide;
    return compactWidth || shortestSide < 700;
  }

  void _handleCardTap({required bool touchLike}) {
    if (touchLike) {
      if (!widget.data.isSelected) {
        widget.data.onTap();
        return;
      }
      _toggleExpanded();
      return;
    }

    if (!widget.data.isSelected) {
      widget.data.onTap();
      if (_isExpanded) {
        setState(() => _isExpanded = false);
      }
      return;
    }

    _toggleExpanded();
  }

  void _handleLongPress({required bool touchLike}) {
    if (!touchLike) {
      return;
    }
    if (!widget.data.isSelected) {
      widget.data.onTap();
    }
    if (!_isExpanded) {
      setState(() => _isExpanded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusAccent = _statusAccent();
    final suppressStatusChip = widget.data.suppressTimetableWarning &&
        widget.data.statusLabel.toLowerCase().contains('timetable');
    final primaryAction =
        widget.data.actions.isNotEmpty ? widget.data.actions.first : null;
    final secondaryActions = widget.data.actions.length > 1
        ? widget.data.actions.sublist(1)
        : <DashboardInlineActionData>[];

    return LayoutBuilder(
      builder: (context, constraints) {
        final compactCard = constraints.maxWidth < 392;
        final touchLike = _isTouchLike(
          compactWidth: compactCard,
          context: context,
        );
        final hoveredPreview = _isHovered && !touchLike && !_isExpanded;
        final selected = widget.data.isSelected;
        final showFocusPreview = (selected || hoveredPreview) && !_isExpanded;
        final previewMetric =
            widget.data.metrics.isNotEmpty ? widget.data.metrics.first : null;
        final compactActionHeight = touchLike ? 44.0 : 40.0;

        return MouseRegion(
          onEnter: (_) {
            if (!touchLike && !_isExpanded) {
              setState(() => _isHovered = true);
            }
          },
          onExit: (_) {
            setState(() => _isHovered = false);
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onLongPress: () => _handleLongPress(touchLike: touchLike),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              transform: _shellMotionTransform(
                context,
                lift: hoveredPreview ? -2.0 : 0.0,
                scale: hoveredPreview ? 1.01 : 1.0,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected
                      ? statusAccent.withValues(alpha: 0.44)
                      : _DashboardPalette.border.withValues(alpha: 0.22),
                  width: selected ? 1.4 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: hoveredPreview || _isExpanded ? 0.13 : 0.08,
                    ),
                    blurRadius: hoveredPreview || _isExpanded ? 12 : 5,
                    offset: hoveredPreview || _isExpanded
                        ? const Offset(0, 4)
                        : const Offset(0, 2),
                  ),
                  if (hoveredPreview || selected)
                    BoxShadow(
                      color: statusAccent.withValues(alpha: 0.13),
                      blurRadius: 20,
                      spreadRadius: 0.2,
                      offset: const Offset(0, 6),
                    ),
                ],
              ),
              child: DashboardPanelCard(
                onTap: () => _handleCardTap(touchLike: touchLike),
                minHeight: _isExpanded ? 292 : (compactCard ? 130 : 138),
                radius: 20,
                padding: EdgeInsets.all(compactCard ? 12 : 14),
                gradientColors: [
                  _DashboardPalette.panel,
                  _DashboardPalette.panelAlt.withValues(
                    alpha: hoveredPreview || selected ? 1.0 : 0.84,
                  ),
                ],
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOutCubic,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header: Always visible
                      Text(
                        widget.data.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.15,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.data.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: _DashboardPalette.textSecondary,
                              height: 1.25,
                            ),
                      ),
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          Icon(
                            Icons.people_alt_outlined,
                            size: 14,
                            color: _DashboardPalette.textSecondary,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              widget.data.studentCount == 0
                                  ? 'Roster empty'
                                  : '${widget.data.studentCount} students',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: _DashboardPalette.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                          if (previewMetric != null) const SizedBox(width: 8),
                          if (previewMetric != null)
                            Flexible(
                              child: Text(
                                previewMetric.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.end,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: _DashboardPalette.textSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                        ],
                      ),
                      if (!suppressStatusChip) ...[
                        const SizedBox(height: 7),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: statusAccent.withValues(alpha: 0.08),
                            border: Border.all(
                              color: statusAccent.withValues(alpha: 0.14),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                widget.data.statusIcon,
                                size: 16,
                                color: statusAccent,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  widget.data.statusLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),

                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        child: !showFocusPreview
                            ? const SizedBox(
                                key: ValueKey('card-preview-empty'),
                              )
                            : Container(
                                key: const ValueKey('card-preview-layer'),
                                width: double.infinity,
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  color: _DashboardPalette.textSecondary
                                      .withValues(alpha: 0.08),
                                  border: Border.all(
                                    color: _DashboardPalette.border
                                        .withValues(alpha: 0.7),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.north_east_rounded,
                                      size: 14,
                                      color: _DashboardPalette.textSecondary,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        widget.data.recommendedLabel.isNotEmpty
                                            ? widget.data.recommendedLabel
                                            : widget.data.statusDetail,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              color: _DashboardPalette
                                                  .textSecondary,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),

                      // Actions: Only show primary in collapsed, hide when expanded
                      if (!_isExpanded && primaryAction != null)
                        _ClassActionButton(
                          action: primaryAction,
                          accent: statusAccent,
                          primary: true,
                          compact: true,
                          minHeight: compactActionHeight,
                        ),

                      // Secondary actions: Visible on hover only (not when expanded)
                      if ((hoveredPreview && !_isExpanded) &&
                          secondaryActions.isNotEmpty) ...[
                        AnimatedOpacity(
                          opacity: hoveredPreview && !_isExpanded ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 200),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(height: 6),
                              ...secondaryActions.map(
                                (action) => Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: _ClassActionButton(
                                    action: action,
                                    accent: statusAccent,
                                    primary: false,
                                    compact: true,
                                    minHeight: compactActionHeight,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Expanded content: Detail section
                      if (_isExpanded) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: _DashboardPalette.textSecondary
                                .withValues(alpha: 0.08),
                            border: Border.all(
                              color: _DashboardPalette.border
                                  .withValues(alpha: 0.7),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'State',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: _DashboardPalette.textSecondary,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.data.statusDetail.isNotEmpty
                                    ? widget.data.statusDetail
                                    : widget.data.statusLabel,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: _DashboardPalette.textSecondary,
                                      height: 1.4,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Metrics
                        if (widget.data.metrics.isNotEmpty) ...[
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: widget.data.metrics
                                .take(3)
                                .map(
                                  (metric) => Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      color: _DashboardPalette.textSecondary
                                          .withValues(alpha: 0.08),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          metric.icon,
                                          size: 14,
                                          color:
                                              _DashboardPalette.textSecondary,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          metric.label,
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelSmall
                                              ?.copyWith(
                                                color: _DashboardPalette
                                                    .textSecondary,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // Next block
                        if (widget.data.recommendedLabel.isNotEmpty) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: statusAccent.withValues(alpha: 0.06),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Next',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        color: _DashboardPalette.textSecondary,
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.data.recommendedLabel,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: statusAccent,
                                      ),
                                ),
                                if (widget.data.recommendedDetail.isNotEmpty)
                                  const SizedBox(height: 4),
                                if (widget.data.recommendedDetail.isNotEmpty)
                                  Text(
                                    widget.data.recommendedDetail,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color:
                                              _DashboardPalette.textSecondary,
                                        ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // All actions visible when expanded
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (primaryAction != null)
                              _ClassActionButton(
                                action: primaryAction,
                                accent: statusAccent,
                                primary: true,
                                compact: false,
                                minHeight: touchLike ? 46 : 44,
                              ),
                            ...secondaryActions.map(
                              (action) => Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: _ClassActionButton(
                                  action: action,
                                  accent: statusAccent,
                                  primary: false,
                                  compact: false,
                                  minHeight: touchLike ? 46 : 44,
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Close button when expanded
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            onPressed: _toggleExpanded,
                            child: const Text('Collapse details'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DashboardActionCard extends StatefulWidget {
  final DashboardQuickActionData data;

  const _DashboardActionCard({required this.data});

  @override
  State<_DashboardActionCard> createState() => _DashboardActionCardState();
}

class _DashboardActionCardState extends State<_DashboardActionCard> {
  bool _isHovered = false;
  bool _isExpanded = false;

  String _compactHint(String input, {int maxChars = 34}) {
    final normalized = input.trim();
    if (normalized.length <= maxChars) {
      return normalized;
    }
    return '${normalized.substring(0, maxChars - 1).trimRight()}...';
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final touchLike = constraints.maxWidth < 300 ||
            MediaQuery.sizeOf(context).shortestSide < 700;
        final reveal = _isExpanded || (_isHovered && !touchLike);

        return MouseRegion(
          onEnter: (_) {
            if (!touchLike) {
              setState(() => _isHovered = true);
            }
          },
          onExit: (_) => setState(() => _isHovered = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onLongPress: () {
              if (touchLike) {
                setState(() => _isExpanded = !_isExpanded);
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              transform: _shellMotionTransform(
                context,
                lift: reveal ? -1.5 : 0.0,
                scale: reveal ? 1.008 : 1.0,
              ),
              child: DashboardPanelCard(
                onTap: widget.data.onTap,
                minHeight: reveal ? 118 : 96,
                padding: const EdgeInsets.all(14),
                radius: 20,
                gradientColors: [
                  _DashboardPalette.panel,
                  _DashboardPalette.panelAlt
                      .withValues(alpha: reveal ? 1.0 : 0.9),
                ],
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: widget.data.accent.withValues(alpha: 0.18),
                            border: Border.all(
                              color: widget.data.accent.withValues(alpha: 0.30),
                            ),
                          ),
                          child: Icon(widget.data.icon, color: Colors.white),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            widget.data.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 170),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      child: reveal
                          ? Text(
                              widget.data.detail,
                              key: ValueKey('${widget.data.label}-detail'),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: _DashboardPalette.textSecondary,
                                    height: 1.4,
                                  ),
                            )
                          : Text(
                              _compactHint(widget.data.detail),
                              key: ValueKey('${widget.data.label}-hint'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: _DashboardPalette.textSecondary,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DashboardInsightCard extends StatelessWidget {
  final _DashboardInsightData data;

  const _DashboardInsightCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return DashboardPanelCard(
      minHeight: 178,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  data.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              Text(
                data.value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: data.accent,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            data.subtitle,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (int index = 0; index < data.bars.length; index++) ...[
                Expanded(
                  child: Container(
                    height: 56,
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      height: (14 + (data.bars[index].clamp(0.0, 1.0) * 42))
                          .toDouble(),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            data.accent.withValues(alpha: 0.94),
                            data.accent.withValues(alpha: 0.34),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (index != data.bars.length - 1) const SizedBox(width: 8),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ClassActionButton extends StatelessWidget {
  final DashboardInlineActionData action;
  final Color accent;
  final bool primary;
  final bool compact;
  final double minHeight;

  const _ClassActionButton({
    required this.action,
    required this.accent,
    required this.primary,
    this.compact = false,
    this.minHeight = 44,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = primary
        ? (_DashboardPalette.isLight ? accent : accent)
        : _DashboardPalette.textPrimary;
    final backgroundColor = primary
        ? accent.withValues(alpha: 0.12)
        : Colors.white.withValues(alpha: 0.03);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: action.onTap,
        borderRadius: BorderRadius.circular(16),
        hoverColor: _dashboardInteractiveOverlay(),
        focusColor: _dashboardInteractiveOverlay(),
        highlightColor: _dashboardInteractiveOverlay(emphasis: 1.25),
        splashColor: _dashboardInteractiveOverlay(emphasis: 1.35),
        child: Container(
          constraints: BoxConstraints(minHeight: minHeight),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: backgroundColor,
            border: Border.all(
              color: primary
                  ? accent.withValues(alpha: 0.20)
                  : _DashboardPalette.border.withValues(alpha: 0.78),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(action.icon, size: compact ? 17 : 18, color: foreground),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    action.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: foreground,
                          fontWeight: FontWeight.w700,
                          fontSize: compact ? 13 : null,
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
}

class _ResponsivePanelWrap extends StatelessWidget {
  final bool compact;
  final List<Widget> children;

  const _ResponsivePanelWrap({
    required this.compact,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (compact) {
          return Column(
            children: [
              for (int index = 0; index < children.length; index++) ...[
                children[index],
                if (index != children.length - 1) const SizedBox(height: 14),
              ],
            ],
          );
        }

        final width = constraints.maxWidth;
        final columns = width > 980 ? 2 : 1;
        final gap = 14.0;
        final panelWidth = columns == 1 ? width : (width - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final child in children)
              SizedBox(width: panelWidth, child: child),
          ],
        );
      },
    );
  }
}

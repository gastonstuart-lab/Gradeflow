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

class _DashboardNavItemData {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isActive;
  final String? badge;

  const _DashboardNavItemData({
    required this.label,
    required this.icon,
    required this.onTap,
    this.isActive = false,
    this.badge,
  });
}

class _DashboardSummaryMetricData {
  final String label;
  final String value;
  final String detail;
  final IconData icon;
  final List<Color> gradientColors;
  final VoidCallback? onTap;

  const _DashboardSummaryMetricData({
    required this.label,
    required this.value,
    required this.detail,
    required this.icon,
    required this.gradientColors,
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

class _DashboardQuickActionData {
  final String label;
  final String detail;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  const _DashboardQuickActionData({
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

class _DashboardLiveStoryData {
  final String label;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final List<String> chips;
  final VoidCallback? onTap;

  const _DashboardLiveStoryData({
    required this.label,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.chips,
    this.onTap,
  });
}

class _DashboardAnnouncementData {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback? onTap;

  const _DashboardAnnouncementData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    this.onTap,
  });
}

class DashboardSystemWidgetData {
  final String timeLabel;
  final String weekdayLabel;
  final String dateLabel;
  final String statusLabel;
  final String statusDetail;
  final String weatherLabel;
  final String nextLabel;
  final String focusLabel;

  const DashboardSystemWidgetData({
    required this.timeLabel,
    required this.weekdayLabel,
    required this.dateLabel,
    required this.statusLabel,
    required this.statusDetail,
    required this.weatherLabel,
    required this.nextLabel,
    required this.focusLabel,
  });
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

    final dashboardBaseTextTheme = kIsWeb
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
      ),
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
                        label: 'Home', icon: Icons.grid_view),
                    _DashboardMobileTabData(
                        label: 'Schedule', icon: Icons.event_note_outlined),
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
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _DashboardPalette.background,
                  _DashboardPalette.backgroundAlt,
                  Color(0xFF131A27),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: -120,
          left: -80,
          child: IgnorePointer(
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _DashboardPalette.accent.withValues(alpha: 0.22),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          right: -120,
          top: 120,
          child: IgnorePointer(
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _DashboardPalette.cyan.withValues(alpha: 0.14),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -120,
          left: 180,
          child: IgnorePointer(
            child: Container(
              width: 360,
              height: 360,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _DashboardPalette.purple.withValues(alpha: 0.12),
                    Colors.transparent,
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
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: 236, child: sidebar),
            const SizedBox(width: 20),
            Expanded(child: main),
            const SizedBox(width: 20),
            SizedBox(
              width: 330,
              child: SingleChildScrollView(child: livePanel),
            ),
          ],
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
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: 92, child: sidebar),
            const SizedBox(width: 16),
            Expanded(child: main),
          ],
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
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _DashboardPalette.border),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_DashboardPalette.sidebarAlt, _DashboardPalette.sidebar],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: onSelected,
        height: 72,
        destinations: [
          for (final destination in destinations)
            NavigationDestination(
              icon: Icon(destination.icon),
              label: destination.label,
            ),
        ],
      ),
    );
  }
}

class SidebarNavigation extends StatelessWidget {
  final bool compact;
  final List<_DashboardNavItemData> primaryItems;
  final List<_DashboardNavItemData> secondaryItems;

  const SidebarNavigation({
    super.key,
    required this.compact,
    required this.primaryItems,
    required this.secondaryItems,
  });

  @override
  Widget build(BuildContext context) {
    return DashboardPanelCard(
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 18),
      gradientColors: [
        _DashboardPalette.sidebarAlt,
        _DashboardPalette.sidebar,
      ],
      child: Column(
        crossAxisAlignment:
            compact ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 12 : 14,
              vertical: compact ? 12 : 14,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _DashboardPalette.border),
              color: Colors.white.withValues(alpha: 0.04),
            ),
            child: compact
                ? Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        colors: [
                          _DashboardPalette.cyan,
                          _DashboardPalette.accent,
                        ],
                      ),
                    ),
                    child: const Icon(
                      Icons.grading_rounded,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: LinearGradient(
                            colors: [
                              _DashboardPalette.cyan,
                              _DashboardPalette.accent,
                            ],
                          ),
                        ),
                        child: const Icon(
                          Icons.grading_rounded,
                          color: Colors.white,
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
                                      color: _DashboardPalette.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: compact
                    ? CrossAxisAlignment.center
                    : CrossAxisAlignment.start,
                children: [
                  for (final item in primaryItems)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
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
                        'Editions',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: _DashboardPalette.textSecondary,
                            ),
                      ),
                    ),
                  for (final item in secondaryItems)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _SidebarNavButton(
                        compact: compact,
                        item: item,
                        secondary: true,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (!compact)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: Colors.white.withValues(alpha: 0.04),
                border: Border.all(color: _DashboardPalette.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Connected editions',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Admin and Communication are available when you need them without crowding the daily teaching workspace.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class DashboardTopSummary extends StatelessWidget {
  final String title;
  final String subtitle;
  final String todayLine;
  final List<Widget> actions;
  final List<_DashboardSummaryMetricData> metrics;
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
  Widget build(BuildContext context) {
    final metricMinWidth = compact ? 220.0 : 224.0;
    const heroPrimary = Color(0xFFF8FAFF);
    final heroSecondary = Colors.white.withValues(alpha: 0.74);
    final heroOutline = Colors.white.withValues(alpha: 0.18);
    return LayoutBuilder(
      builder: (context, constraints) {
        final showControlsCard =
            actions.isNotEmpty && !compact && constraints.maxWidth > 860;
        final baseTheme = Theme.of(context);
        final actionTheme = baseTheme.copyWith(
          iconButtonTheme: IconButtonThemeData(
            style: IconButton.styleFrom(
              foregroundColor: heroPrimary,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              padding: const EdgeInsets.all(12),
            ),
          ),
        );

        return DashboardPanelCard(
          padding: EdgeInsets.all(compact ? 20 : 26),
          radius: compact ? 24 : 28,
          gradientColors: presentation.gradientColors,
          child: Stack(
            children: [
              if (backgroundImage != null)
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(compact ? 24 : 28),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        image: DecorationImage(
                          image: backgroundImage!,
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                          opacity: 0.34,
                        ),
                      ),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFF081019).withValues(alpha: 0.76),
                              const Color(0xFF101723).withValues(alpha: 0.64),
                              const Color(0xFF0C131D).withValues(alpha: 0.84),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned(
                top: -72,
                right: -56,
                child: IgnorePointer(
                  child: Container(
                    width: compact ? 180 : 260,
                    height: compact ? 180 : 260,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          presentation.primaryGlow.withValues(alpha: 0.28),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: -40,
                bottom: -90,
                child: IgnorePointer(
                  child: Container(
                    width: compact ? 160 : 220,
                    height: compact ? 160 : 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          presentation.secondaryGlow.withValues(alpha: 0.18),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: compact ? 120 : 180,
                top: compact ? -36 : -28,
                child: IgnorePointer(
                  child: Container(
                    width: compact ? 100 : 140,
                    height: compact ? 100 : 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          presentation.tertiaryGlow.withValues(alpha: 0.16),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Column(
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
                              'Command deck',
                              style: baseTheme.textTheme.labelLarge?.copyWith(
                                color: heroSecondary,
                                letterSpacing: 0.9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              title,
                              style: (compact
                                      ? baseTheme.textTheme.headlineSmall
                                      : baseTheme.textTheme.headlineMedium)
                                  ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: heroPrimary,
                                letterSpacing: -0.6,
                                height: 1.05,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              subtitle,
                              style: baseTheme.textTheme.bodyMedium?.copyWith(
                                color: heroSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 620),
                              child: Text(
                                'Today, classes, and live communication stay pinned.',
                                style: baseTheme.textTheme.bodySmall?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.78),
                                  height: 1.45,
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                _HeroSignalPill(
                                  icon: Icons.today_rounded,
                                  label: todayLine,
                                  borderColor: heroOutline,
                                ),
                                _HeroSignalPill(
                                  icon: Icons.palette_outlined,
                                  label: backgroundImage != null
                                      ? '${presentation.label} + custom backdrop'
                                      : '${presentation.label} hero style',
                                  borderColor:
                                      Colors.white.withValues(alpha: 0.12),
                                  backgroundColor:
                                      Colors.white.withValues(alpha: 0.035),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (showControlsCard) ...[
                        const SizedBox(width: 18),
                        SizedBox(
                          width: 228,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.08),
                              ),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.white.withValues(alpha: 0.08),
                                  Colors.white.withValues(alpha: 0.04),
                                ],
                              ),
                            ),
                            child: Theme(
                              data: actionTheme,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Controls',
                                    style: baseTheme.textTheme.labelLarge
                                        ?.copyWith(
                                      color: heroPrimary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Theme, feedback, and sign-out stay close.',
                                    style:
                                        baseTheme.textTheme.bodySmall?.copyWith(
                                      color: heroSecondary,
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    children: actions,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ] else if (actions.isNotEmpty) ...[
                        const SizedBox(width: 14),
                        Theme(
                          data: actionTheme,
                          child: Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: actions,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 22),
                  Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.18),
                          Colors.white.withValues(alpha: 0.04),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const _DashboardSectionTag(
                        label: 'Snapshot',
                        icon: Icons.stacked_bar_chart_rounded,
                        foregroundColor: Color(0xFFF8FAFF),
                        backgroundColor: Color.fromRGBO(255, 255, 255, 0.06),
                        borderColor: Color.fromRGBO(255, 255, 255, 0.12),
                      ),
                      Text(
                        'Tap a tile to jump.',
                        style: baseTheme.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.72),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      for (final metric in metrics)
                        SizedBox(
                          width: metricMinWidth,
                          child: _SummaryMetricTile(metric: metric),
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HeroSignalPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color borderColor;
  final Color? backgroundColor;

  const _HeroSignalPill({
    required this.icon,
    required this.label,
    required this.borderColor,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        color: backgroundColor ?? Colors.white.withValues(alpha: 0.05),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.white.withValues(alpha: 0.92)),
          const SizedBox(width: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: const Color(0xFFF8FAFF),
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
            ),
          ),
        ],
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

  const ClassStatusSection({
    super.key,
    required this.classes,
    required this.onOpenClasses,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return _DashboardSectionFrame(
      title: 'Your Classes',
      subtitle: 'Live status and direct class actions.',
      action: TextButton.icon(
        onPressed: onOpenClasses,
        icon: const Icon(Icons.arrow_forward_rounded, size: 18),
        label: const Text('Open classes'),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final columns = compact
              ? 1
              : width > 980
                  ? 3
                  : 2;
          final gap = 14.0;
          final cardWidth =
              columns == 1 ? width : (width - (gap * (columns - 1))) / columns;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final classData in classes)
                SizedBox(
                  width: cardWidth,
                  child: DashboardClassCard(data: classData),
                ),
            ],
          );
        },
      ),
    );
  }
}

class QuickActionsSection extends StatelessWidget {
  final List<_DashboardQuickActionData> actions;
  final bool compact;

  const QuickActionsSection({
    super.key,
    required this.actions,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return _DashboardSectionFrame(
      title: 'Quick Actions',
      subtitle: 'Fast moves for setup and live teaching.',
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

  const DashboardWorkspaceModeStrip({
    super.key,
    required this.selectedSection,
    required this.onSelected,
    required this.description,
  });

  String _selectionLabel() {
    switch (selectedSection) {
      case DashboardWorkspaceSection.today:
        return 'Today';
      case DashboardWorkspaceSection.classroom:
        return 'Studio';
      case DashboardWorkspaceSection.planning:
        return 'Schedule';
      case DashboardWorkspaceSection.workspace:
        return 'Tools';
    }
  }

  @override
  Widget build(BuildContext context) {
    return DashboardPanelCard(
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
                      'Workspace',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Primary surfaces stay pinned while one secondary surface takes focus.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
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
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Colors.white.withValues(alpha: 0.03),
              border: Border.all(
                color: _DashboardPalette.border.withValues(alpha: 0.85),
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<DashboardWorkspaceSection>(
                segments: const [
                  ButtonSegment(
                    value: DashboardWorkspaceSection.today,
                    icon: Icon(Icons.insights_outlined),
                    label: Text('Today'),
                  ),
                  ButtonSegment(
                    value: DashboardWorkspaceSection.classroom,
                    icon: Icon(Icons.draw_outlined),
                    label: Text('Classroom'),
                  ),
                  ButtonSegment(
                    value: DashboardWorkspaceSection.planning,
                    icon: Icon(Icons.event_note_outlined),
                    label: Text('Schedule'),
                  ),
                  ButtonSegment(
                    value: DashboardWorkspaceSection.workspace,
                    icon: Icon(Icons.workspaces_outline),
                    label: Text('Workspace'),
                  ),
                ],
                selected: {selectedSection},
                onSelectionChanged: (selection) => onSelected(selection.first),
              ),
            ),
          ),
          const SizedBox(height: 12),
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
      title: 'Schedule',
      subtitle: 'Reminders, calendar, and timetable.',
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
      title: 'Workspace',
      subtitle: 'Secondary tools and links on standby.',
      child: _ResponsivePanelWrap(
        compact: compact,
        children: panels,
      ),
    );
  }
}

class LivePanel extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<String> channels;
  final DashboardSystemWidgetData systemWidget;
  final DashboardCommunicationWidgetData communicationWidget;
  final List<_DashboardLiveStoryData> stories;
  final List<_DashboardAnnouncementData> announcements;
  final bool compact;

  const LivePanel({
    super.key,
    required this.title,
    required this.subtitle,
    required this.channels,
    required this.systemWidget,
    required this.communicationWidget,
    required this.stories,
    required this.announcements,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return DashboardPanelCard(
      padding: const EdgeInsets.all(16),
      radius: 28,
      gradientColors: [
        _DashboardPalette.sidebarAlt,
        _DashboardPalette.sidebar,
      ],
      child: Stack(
        children: [
          Positioned(
            top: -64,
            right: -34,
            child: IgnorePointer(
              child: Container(
                width: 170,
                height: 170,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _DashboardPalette.accent.withValues(alpha: 0.14),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -76,
            left: -56,
            child: IgnorePointer(
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _DashboardPalette.cyan.withValues(alpha: 0.12),
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
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: _DashboardPalette.border.withValues(alpha: 0.9),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.07),
                      Colors.white.withValues(alpha: 0.03),
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DashboardSectionTag(
                      label: 'Live rail',
                      icon: Icons.radar_rounded,
                      foregroundColor: _DashboardPalette.accentSoft,
                      backgroundColor:
                          _DashboardPalette.accent.withValues(alpha: 0.10),
                      borderColor:
                          _DashboardPalette.accent.withValues(alpha: 0.18),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.3,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                subtitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(height: 1.45),
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
                            color: _DashboardPalette.accent
                                .withValues(alpha: 0.18),
                            border: Border.all(
                              color: _DashboardPalette.accent
                                  .withValues(alpha: 0.28),
                            ),
                          ),
                          child: Text(
                            '${channels.length} signals',
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                      ],
                    ),
                    if (channels.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final channel in channels.take(compact ? 3 : 4))
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: _DashboardPalette.border,
                                ),
                                color: Colors.white.withValues(alpha: 0.05),
                              ),
                              child: Text(
                                channel,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelMedium
                                    ?.copyWith(
                                      color: _DashboardPalette.textSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const _DashboardSectionTag(
                label: 'Widget',
                icon: Icons.schedule_rounded,
              ),
              const SizedBox(height: 10),
              _DashboardSystemWidgetCard(
                data: systemWidget,
                compact: compact,
              ),
              const SizedBox(height: 12),
              const _DashboardSectionTag(
                label: 'Messages',
                icon: Icons.forum_outlined,
              ),
              const SizedBox(height: 10),
              _DashboardCommunicationWidgetCard(
                data: communicationWidget,
                compact: compact,
              ),
              const SizedBox(height: 12),
              const _DashboardSectionTag(
                label: 'Live',
                icon: Icons.public_outlined,
              ),
              const SizedBox(height: 10),
              for (final story in stories) ...[
                _DashboardLiveStoryCard(story: story, compact: compact),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  const _DashboardSectionTag(
                    label: 'Updates',
                    icon: Icons.campaign_outlined,
                  ),
                  if (announcements.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    _DashboardSectionTag(
                      label: '${announcements.length}',
                      foregroundColor: _DashboardPalette.accentSoft,
                      backgroundColor:
                          _DashboardPalette.accent.withValues(alpha: 0.10),
                      borderColor:
                          _DashboardPalette.accent.withValues(alpha: 0.18),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              DashboardPanelCard(
                padding: const EdgeInsets.all(14),
                radius: 22,
                gradientColors: const [
                  Color(0xFF171F2C),
                  Color(0xFF131A26),
                ],
                minHeight: 120,
                child: Column(
                  children: [
                    if (announcements.isEmpty)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'No new staff updates.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    for (int index = 0;
                        index < announcements.length;
                        index++) ...[
                      _DashboardAnnouncementTile(item: announcements[index]),
                      if (index != announcements.length - 1)
                        const SizedBox(height: 10),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
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
      minHeight: compact ? 0 : 176,
      gradientColors: [
        Color.lerp(_DashboardPalette.accent, _DashboardPalette.panelAlt, 0.82)!,
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
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _SystemWidgetBadge(
                    label: 'Local',
                    icon: Icons.schedule_rounded,
                  ),
                  _SystemWidgetBadge(
                    label: data.focusLabel,
                    icon: Icons.adjust_rounded,
                    emphasized: true,
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
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.1,
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: _DashboardPalette.accent.withValues(alpha: 0.14),
                      ),
                      child: Icon(
                        Icons.auto_awesome_rounded,
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
                            data.statusLabel,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.2,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            data.statusDetail,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: _DashboardPalette.textSecondary,
                                      height: 1.45,
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
                      label: 'Weather',
                      value: data.weatherLabel,
                      icon: Icons.cloud_outlined,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SystemMetricTile(
                      label: 'Next',
                      value: data.nextLabel,
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

class _DashboardCommunicationWidgetCard extends StatelessWidget {
  final DashboardCommunicationWidgetData data;
  final bool compact;

  const _DashboardCommunicationWidgetCard({
    required this.data,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final previewThreads = data.threads.take(compact ? 2 : 3).toList();
    final accent = previewThreads.isNotEmpty
        ? previewThreads.first.accent
        : _DashboardPalette.accent;

    return DashboardPanelCard(
      onTap: data.onTap,
      padding: const EdgeInsets.all(16),
      radius: 22,
      gradientColors: [
        Color.lerp(accent, _DashboardPalette.panelAlt, 0.84)!,
        _DashboardPalette.panel,
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
                      data.headline,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data.detail,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: _DashboardPalette.textSecondary,
                            height: 1.45,
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
                  color: accent.withValues(alpha: 0.14),
                  border: Border.all(
                    color: accent.withValues(alpha: 0.24),
                  ),
                ),
                child: Text(
                  data.unreadCount > 0 ? '${data.unreadCount}' : 'Open',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (previewThreads.isEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: Colors.white.withValues(alpha: 0.04),
                border: Border.all(
                  color: _DashboardPalette.border.withValues(alpha: 0.78),
                ),
              ),
              child: Text(
                'No new messages.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _DashboardPalette.textSecondary,
                    ),
              ),
            ),
          for (int index = 0; index < previewThreads.length; index++) ...[
            _CommunicationPreviewRow(thread: previewThreads[index]),
            if (index != previewThreads.length - 1) const SizedBox(height: 10),
          ],
          const SizedBox(height: 12),
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
                    'Open communication',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: _DashboardPalette.textSecondary,
                  size: 18,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommunicationPreviewRow extends StatelessWidget {
  final DashboardCommunicationThreadData thread;

  const _CommunicationPreviewRow({
    required this.thread,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
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
                Text(
                  thread.preview,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _DashboardPalette.textSecondary,
                        height: 1.4,
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
              if (thread.unreadCount > 0) const SizedBox(height: 6),
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

  const DashboardPanelCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 24,
    this.minHeight = 0,
    this.gradientColors,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: _DashboardPalette.border),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: gradientColors ??
            [
              _DashboardPalette.panelAlt,
              _DashboardPalette.panel,
            ],
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.22),
          blurRadius: 22,
          offset: const Offset(0, 14),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.12),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );

    final content = Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(
                      alpha: _DashboardPalette.isLight ? 0.06 : 0.05,
                    ),
                    Colors.transparent,
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.32, 1.0],
                ),
              ),
            ),
          ),
        ),
        ConstrainedBox(
          constraints: BoxConstraints(minHeight: minHeight),
          child: Padding(
            padding: padding,
            child: child,
          ),
        ),
      ],
    );

    final body = content;

    return DecoratedBox(
      decoration: decoration,
      child: Material(
        type: MaterialType.transparency,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: onTap == null
              ? body
              : InkWell(
                  onTap: onTap,
                  child: body,
                ),
        ),
      ),
    );
  }
}

class _SidebarNavButton extends StatelessWidget {
  final bool compact;
  final bool secondary;
  final _DashboardNavItemData item;

  const _SidebarNavButton({
    required this.compact,
    required this.item,
    this.secondary = false,
  });

  @override
  Widget build(BuildContext context) {
    final active = item.isActive;
    final child = AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 14,
        vertical: compact ? 12 : 13,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: active
            ? _DashboardPalette.accent.withValues(alpha: 0.18)
            : Colors.white.withValues(alpha: secondary ? 0.02 : 0.0),
        border: Border.all(
          color: active
              ? _DashboardPalette.accent.withValues(alpha: 0.45)
              : _DashboardPalette.border.withValues(alpha: secondary ? 0.8 : 0),
        ),
      ),
      child: compact
          ? Icon(
              item.icon,
              color: active
                  ? _DashboardPalette.textPrimary
                  : _DashboardPalette.textSecondary,
            )
          : Row(
              children: [
                Icon(
                  item.icon,
                  size: 20,
                  color: active
                      ? _DashboardPalette.textPrimary
                      : _DashboardPalette.textSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: active
                              ? _DashboardPalette.textPrimary
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
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                    child: Text(
                      item.badge!,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: _DashboardPalette.textSecondary,
                          ),
                    ),
                  ),
              ],
            ),
    );

    final tappable = InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(16),
      child: child,
    );

    if (!compact || kIsWeb) {
      return tappable;
    }

    return Tooltip(
      message:
          item.badge == null ? item.label : '${item.label} (${item.badge})',
      child: tappable,
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

class _SummaryMetricTile extends StatelessWidget {
  final _DashboardSummaryMetricData metric;

  const _SummaryMetricTile({required this.metric});

  @override
  Widget build(BuildContext context) {
    return DashboardPanelCard(
      onTap: metric.onTap,
      padding: const EdgeInsets.all(18),
      minHeight: 132,
      radius: 22,
      gradientColors: metric.gradientColors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  metric.label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.84),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                ),
              ),
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: Colors.white.withValues(alpha: 0.14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Icon(metric.icon, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            metric.value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.45,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            metric.detail,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.82),
                  height: 1.45,
                ),
          ),
          const SizedBox(height: 14),
          Container(
            width: 58,
            height: 4,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

class DashboardClassCard extends StatelessWidget {
  final DashboardClassStatusData data;

  const DashboardClassCard({
    super.key,
    required this.data,
  });

  Color _statusAccent() {
    switch (data.level) {
      case ClassHealthLevel.ready:
        return _DashboardPalette.green;
      case ClassHealthLevel.attention:
        return _DashboardPalette.amber;
      case ClassHealthLevel.urgent:
        return _DashboardPalette.coral;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusAccent = _statusAccent();
    return LayoutBuilder(
      builder: (context, constraints) {
        final compactCard = constraints.maxWidth < 390;

        return DashboardPanelCard(
          onTap: data.onTap,
          minHeight: compactCard ? 280 : 292,
          radius: 26,
          padding: EdgeInsets.all(compactCard ? 16 : 18),
          gradientColors: [
            Color.lerp(statusAccent, _DashboardPalette.panelAlt, 0.86)!,
            _DashboardPalette.panel,
          ],
          child: Stack(
            children: [
              Positioned(
                top: -20,
                right: -18,
                child: IgnorePointer(
                  child: Container(
                    width: compactCard ? 84 : 94,
                    height: compactCard ? 84 : 94,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          statusAccent.withValues(alpha: 0.24),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: statusAccent.withValues(alpha: 0.16),
                          border: Border.all(
                            color: statusAccent.withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Icon(
                          Icons.class_rounded,
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
                              data.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.45,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              data.subtitle,
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
                            if (!compactCard) ...[
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _ClassMetaChip(
                                    icon: Icons.people_alt_outlined,
                                    label: data.studentCount == 0
                                        ? 'Roster empty'
                                        : '${data.studentCount} students',
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _ClassBadge(
                            label: data.levelLabel,
                            color: statusAccent,
                          ),
                          if (data.isSelected) ...[
                            const SizedBox(height: 8),
                            _ClassBadge(
                              label: 'Focused',
                              color: _DashboardPalette.accent,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: compactCard ? 10 : 12),
                  Container(
                    padding: EdgeInsets.all(compactCard ? 12 : 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          statusAccent.withValues(alpha: 0.28),
                          statusAccent.withValues(alpha: 0.12),
                        ],
                      ),
                      border: Border.all(
                        color: statusAccent.withValues(alpha: 0.4),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: statusAccent.withValues(alpha: 0.16),
                          blurRadius: 18,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: Colors.white.withValues(alpha: 0.16),
                              ),
                              child: Icon(
                                data.statusIcon,
                                size: 18,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'State',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.86),
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          data.statusLabel,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.2,
                                  ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          data.statusDetail,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.86),
                                    height: 1.45,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: compactCard ? 10 : 12),
                  Container(
                    padding: EdgeInsets.all(compactCard ? 12 : 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          statusAccent.withValues(alpha: 0.10),
                          Colors.white.withValues(alpha: 0.02),
                        ],
                      ),
                      border: Border.all(
                        color: statusAccent.withValues(alpha: 0.22),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: statusAccent.withValues(alpha: 0.14),
                          ),
                          child: Icon(
                            Icons.arrow_outward_rounded,
                            size: 18,
                            color: statusAccent,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    'Next',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelLarge
                                        ?.copyWith(
                                          color:
                                              _DashboardPalette.textSecondary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                  _DashboardSectionTag(
                                    label: data.studentCount == 0
                                        ? 'Roster empty'
                                        : '${data.studentCount} students',
                                    icon: Icons.people_alt_outlined,
                                    foregroundColor:
                                        _DashboardPalette.textSecondary,
                                    backgroundColor:
                                        Colors.white.withValues(alpha: 0.04),
                                    borderColor: _DashboardPalette.border
                                        .withValues(alpha: 0.72),
                                  ),
                                ],
                              ),
                              SizedBox(height: compactCard ? 4 : 6),
                              Text(
                                data.recommendedLabel,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                data.recommendedDetail,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: _DashboardPalette.textSecondary,
                                      height: 1.45,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: compactCard ? 10 : 12),
                  if (!compactCard) ...[
                    Text(
                      'Signals',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: _DashboardPalette.textSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final metric in data.metrics)
                        _ClassMetaChip(
                          icon: metric.icon,
                          label: metric.label,
                        ),
                    ],
                  ),
                  SizedBox(height: compactCard ? 10 : 12),
                  Row(
                    children: [
                      for (int index = 0;
                          index < data.actions.length;
                          index++) ...[
                        Expanded(
                          child: _ClassActionButton(
                            action: data.actions[index],
                            accent: statusAccent,
                            primary: index == 0,
                          ),
                        ),
                        if (index != data.actions.length - 1)
                          const SizedBox(width: 10),
                      ],
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DashboardActionCard extends StatelessWidget {
  final _DashboardQuickActionData data;

  const _DashboardActionCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return DashboardPanelCard(
      onTap: data.onTap,
      minHeight: 108,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: data.accent.withValues(alpha: 0.18),
              border: Border.all(color: data.accent.withValues(alpha: 0.34)),
            ),
            child: Icon(data.icon, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  data.detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
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

class _DashboardLiveStoryCard extends StatelessWidget {
  final _DashboardLiveStoryData story;
  final bool compact;

  const _DashboardLiveStoryCard({
    required this.story,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = _DashboardPalette.isLight;
    final storyTitleColor =
        isLight ? _DashboardPalette.textPrimary : Colors.white;
    final storySecondaryColor = isLight
        ? _DashboardPalette.textSecondary
        : Colors.white.withValues(alpha: 0.82);
    final storyChipColor = isLight
        ? _DashboardPalette.muted
        : Colors.white.withValues(alpha: 0.84);
    final iconColor = isLight ? story.accent : Colors.white;
    final iconSurface = isLight
        ? story.accent.withValues(alpha: 0.14)
        : Colors.white.withValues(alpha: 0.12);
    final chipSurface = isLight
        ? story.accent.withValues(alpha: 0.1)
        : Colors.white.withValues(alpha: 0.1);
    return DashboardPanelCard(
      onTap: story.onTap,
      padding: const EdgeInsets.all(16),
      radius: 22,
      minHeight: compact ? 0 : 144,
      gradientColors: [
        if (isLight) ...[
          Color.lerp(story.accent, Colors.white, 0.78)!,
          Color.lerp(story.accent, Colors.white, 0.92)!,
        ] else ...[
          Color.lerp(story.accent, _DashboardPalette.panelAlt, 0.78)!,
          Color.lerp(
            story.accent,
            _DashboardPalette.panel,
            0.92,
          )!,
        ],
      ],
      child: Stack(
        children: [
          Positioned(
            top: -24,
            right: -18,
            child: IgnorePointer(
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      story.accent.withValues(alpha: isLight ? 0.16 : 0.24),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: iconSurface,
                      border: Border.all(
                        color: story.accent.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Icon(story.icon, color: iconColor, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      story.label,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: storySecondaryColor,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  if (story.onTap != null)
                    Icon(
                      Icons.arrow_outward_rounded,
                      size: 18,
                      color: storySecondaryColor,
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                story.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: storyTitleColor,
                      letterSpacing: -0.2,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                story.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: storySecondaryColor,
                      height: 1.45,
                    ),
              ),
              if (story.chips.isNotEmpty) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final chip in story.chips.take(compact ? 2 : 3))
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          color: chipSurface,
                          border: Border.all(
                            color: story.accent.withValues(alpha: 0.15),
                          ),
                        ),
                        child: Text(
                          chip,
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: storyChipColor,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _DashboardAnnouncementTile extends StatelessWidget {
  final _DashboardAnnouncementData item;

  const _DashboardAnnouncementTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white.withValues(alpha: 0.035),
            border: Border.all(
              color: item.accent.withValues(alpha: 0.22),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: item.accent.withValues(alpha: 0.16),
                ),
                child: Icon(item.icon, size: 18, color: item.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: _DashboardPalette.textSecondary,
                            height: 1.4,
                          ),
                    ),
                  ],
                ),
              ),
              if (item.onTap != null) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 18,
                  color: _DashboardPalette.textSecondary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ClassBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _ClassBadge({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.16),
        border: Border.all(
          color: color.withValues(alpha: 0.24),
        ),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: _DashboardPalette.isLight ? color : Colors.white,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _ClassMetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ClassMetaChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(
          color: _DashboardPalette.border.withValues(alpha: 0.75),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: _DashboardPalette.textSecondary),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: _DashboardPalette.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
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

  const _ClassActionButton({
    required this.action,
    required this.accent,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = primary ? Colors.white : _DashboardPalette.textPrimary;
    final background = primary
        ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accent.withValues(alpha: 0.92),
              accent.withValues(alpha: 0.72),
            ],
          )
        : LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.05),
              Colors.white.withValues(alpha: 0.02),
            ],
          );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: action.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 46,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: background,
            border: Border.all(
              color: primary
                  ? accent.withValues(alpha: 0.34)
                  : _DashboardPalette.border,
            ),
            boxShadow: primary
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.20),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(action.icon, size: 18, color: foreground),
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

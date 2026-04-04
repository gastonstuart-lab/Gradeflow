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
  final String actionLabel;
  final VoidCallback? onTap;

  const _DashboardSummaryMetricData({
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
  final String stationName;
  final String programLabel;
  final String detail;

  const DashboardAudioWidgetData({
    required this.stationName,
    required this.programLabel,
    required this.detail,
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
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  _DashboardPalette.background,
                  _DashboardPalette.backgroundAlt,
                  _DashboardPalette.background,
                ],
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
                    Colors.white.withValues(alpha: 0.012),
                    Colors.transparent,
                    Colors.transparent,
                  ],
                  stops: const [0, 0.28, 1],
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
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: 216, child: sidebar),
            const SizedBox(width: 20),
            Expanded(child: main),
            const SizedBox(width: 20),
            SizedBox(
              width: 336,
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
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
      gradientColors: [
        _DashboardPalette.sidebar,
        _DashboardPalette.sidebarAlt,
      ],
      child: Column(
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
                          color:
                              _DashboardPalette.accent.withValues(alpha: 0.16),
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
              ),
            ),
          ),
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
                    'Connected editions',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Admin and Communication stay nearby without crowding the daily dashboard.',
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
    final primaryMetric = metrics.isNotEmpty ? metrics.first : null;
    final secondaryMetrics = metrics.length > 1
        ? metrics.sublist(1)
        : const <_DashboardSummaryMetricData>[];
    final summaryPills = todayLine
        .split('•')
        .map((segment) => segment.trim())
        .where((segment) => segment.isNotEmpty)
        .toList(growable: false);
    final deckAccent = _commandDeckAccent(
      presentation: presentation,
      backgroundImage: backgroundImage,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final baseTheme = Theme.of(context);
        final wide = !compact && constraints.maxWidth > 1060;

        return DashboardPanelCard(
          padding: EdgeInsets.all(compact ? 18 : 22),
          radius: 24,
          gradientColors: [
            _DashboardPalette.sidebarAlt,
            _DashboardPalette.sidebar,
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
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              'Command deck',
                              style: baseTheme.textTheme.labelLarge?.copyWith(
                                color: _DashboardPalette.textSecondary,
                                letterSpacing: 0.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            _CommandDeckLiveBadge(accent: deckAccent),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          title,
                          style: (compact
                                  ? baseTheme.textTheme.headlineSmall
                                  : baseTheme.textTheme.headlineMedium)
                              ?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          subtitle,
                          style: baseTheme.textTheme.bodyMedium?.copyWith(
                            color: _DashboardPalette.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (actions.isNotEmpty) ...[
                    const SizedBox(width: 16),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: wide ? 232 : 180,
                      ),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.end,
                        children: actions,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final pill in summaryPills)
                    _CommandDeckSummaryPill(
                      label: pill,
                      accent: deckAccent,
                    ),
                  _CommandDeckSummaryPill(
                    label: backgroundImage != null
                        ? 'Personalized deck'
                        : presentation.label,
                    icon: backgroundImage != null
                        ? Icons.image_outlined
                        : Icons.palette_outlined,
                    accent: deckAccent,
                  ),
                ],
              ),
              if (primaryMetric != null) ...[
                const SizedBox(height: 16),
                if (wide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 8,
                        child: _CommandDeckPrimaryPanel(
                          metric: primaryMetric,
                          accent: deckAccent,
                        ),
                      ),
                      if (secondaryMetrics.isNotEmpty) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 5,
                          child: Column(
                            children: [
                              for (int index = 0;
                                  index < secondaryMetrics.length;
                                  index++) ...[
                                _CommandDeckSecondaryPanel(
                                  metric: secondaryMetrics[index],
                                  accent: deckAccent,
                                ),
                                if (index != secondaryMetrics.length - 1)
                                  const SizedBox(height: 12),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  )
                else ...[
                  _CommandDeckPrimaryPanel(
                    metric: primaryMetric,
                    accent: deckAccent,
                  ),
                  if (secondaryMetrics.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    for (int index = 0;
                        index < secondaryMetrics.length;
                        index++) ...[
                      _CommandDeckSecondaryPanel(
                        metric: secondaryMetrics[index],
                        accent: deckAccent,
                      ),
                      if (index != secondaryMetrics.length - 1)
                        const SizedBox(height: 12),
                    ],
                  ],
                ],
              ],
            ],
          ),
        );
      },
    );
  }
}

class _CommandDeckLiveBadge extends StatefulWidget {
  final Color accent;

  const _CommandDeckLiveBadge({
    required this.accent,
  });

  @override
  State<_CommandDeckLiveBadge> createState() => _CommandDeckLiveBadgeState();
}

class _CommandDeckLiveBadgeState extends State<_CommandDeckLiveBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final pulse = 0.14 + (_controller.value * 0.16);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: widget.accent.withValues(alpha: 0.10),
            border: Border.all(
              color: widget.accent.withValues(alpha: 0.18 + pulse),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.accent.withValues(alpha: 0.92),
                  boxShadow: [
                    BoxShadow(
                      color: widget.accent.withValues(alpha: 0.18 + pulse),
                      blurRadius: 10,
                      spreadRadius: 0.8,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Live',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: _DashboardPalette.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
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
        border: Border.all(
          color: accent.withValues(alpha: 0.18),
        ),
        color: Colors.white.withValues(alpha: 0.04),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: accent),
            const SizedBox(width: 8),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: _DashboardPalette.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _CommandDeckPrimaryPanel extends StatefulWidget {
  final _DashboardSummaryMetricData metric;
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

    return Material(
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
              color: panelAccent.withValues(alpha: 0.22),
            ),
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
                          alignment:
                              Alignment(-1.15 + (_controller.value * 2.3), 0),
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
                                        color: _DashboardPalette.textSecondary,
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
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
                              foregroundColor: _DashboardPalette.textPrimary,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: BorderSide(
                                  color: panelAccent.withValues(alpha: 0.22),
                                ),
                              ),
                            ),
                            icon:
                                Icon(metric.icon, size: 18, color: panelAccent),
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
    );
  }
}

class _CommandDeckSecondaryPanel extends StatelessWidget {
  final _DashboardSummaryMetricData metric;
  final Color accent;

  const _CommandDeckSecondaryPanel({
    required this.metric,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final panelAccent = Color.lerp(metric.gradientColors.first, accent, 0.55)!;

    return Material(
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
              color: panelAccent.withValues(alpha: 0.18),
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
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
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
            ],
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
      subtitle: 'Compact class summaries and direct actions.',
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
              : width > 1320
                  ? 4
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
      padding: const EdgeInsets.all(18),
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
  bool _playing = true;

  @override
  Widget build(BuildContext context) {
    return DashboardPanelCard(
      padding: const EdgeInsets.all(16),
      radius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Audio',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: _DashboardPalette.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            widget.data.stationName,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.data.programLabel,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: _DashboardPalette.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            widget.data.detail,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _DashboardPalette.textSecondary,
                  height: 1.4,
                ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              InkWell(
                onTap: () => setState(() => _playing = !_playing),
                borderRadius: BorderRadius.circular(14),
                child: Ink(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: _DashboardPalette.accent.withValues(alpha: 0.14),
                    border: Border.all(
                      color: _DashboardPalette.accent.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        size: 18,
                        color: _DashboardPalette.accentSoft,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _playing ? 'Pause' : 'Play',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: _DashboardPalette.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              Text(
                _playing ? 'Live' : 'Paused',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
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
        _DashboardPalette.panel,
        _DashboardPalette.panelAlt,
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
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: _DashboardPalette.textSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 8),
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
                  color: accent.withValues(alpha: 0.12),
                  border: Border.all(
                    color: accent.withValues(alpha: 0.20),
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
            _CommunicationPreviewRow(thread: previewThreads[index]),
            if (index != previewThreads.length - 1) const SizedBox(height: 10),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
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
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
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
      border: Border.all(
        color: _DashboardPalette.border.withValues(alpha: 0.86),
      ),
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: gradientColors ??
            [
              _DashboardPalette.panel,
              _DashboardPalette.panelAlt,
            ],
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.18),
          blurRadius: 20,
          offset: const Offset(0, 10),
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
                    Colors.white.withValues(alpha: 0.018),
                    Colors.transparent,
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.24, 1.0],
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
                  hoverColor: _dashboardInteractiveOverlay(),
                  focusColor: _dashboardInteractiveOverlay(),
                  highlightColor: _dashboardInteractiveOverlay(emphasis: 1.3),
                  splashColor: _dashboardInteractiveOverlay(emphasis: 1.4),
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
        horizontal: compact ? 10 : 12,
        vertical: compact ? 11 : 11,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: active
            ? _DashboardPalette.accent.withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: secondary ? 0.02 : 0.0),
        border: Border.all(
          color: active
              ? _DashboardPalette.accent.withValues(alpha: 0.22)
              : _DashboardPalette.border
                  .withValues(alpha: secondary ? 0.64 : 0),
        ),
      ),
      child: compact
          ? Icon(
              item.icon,
              color: active
                  ? _DashboardPalette.accentSoft
                  : _DashboardPalette.textSecondary,
            )
          : Row(
              children: [
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
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: Colors.white.withValues(alpha: 0.04),
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
      hoverColor: _dashboardInteractiveOverlay(),
      focusColor: _dashboardInteractiveOverlay(),
      highlightColor: _dashboardInteractiveOverlay(emphasis: 1.25),
      splashColor: _dashboardInteractiveOverlay(emphasis: 1.35),
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
        final primaryAction = data.actions.isNotEmpty ? data.actions.first : null;

        return DashboardPanelCard(
          onTap: data.onTap,
          minHeight: compactCard ? 140 : 148,
          radius: 20,
          padding: EdgeInsets.all(compactCard ? 12 : 14),
          gradientColors: [
            _DashboardPalette.panel,
            _DashboardPalette.panelAlt,
          ],
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.15,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                data.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _DashboardPalette.textSecondary,
                      height: 1.25,
                    ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.people_alt_outlined,
                    size: 15,
                    color: _DashboardPalette.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      data.studentCount == 0
                          ? 'Roster empty'
                          : '${data.studentCount} students',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: _DashboardPalette.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                      data.statusIcon,
                      size: 16,
                      color: statusAccent,
                    ),
                    const SizedBox(width: 8),
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
              ),
              const SizedBox(height: 10),
              if (primaryAction != null)
                _ClassActionButton(
                  action: primaryAction,
                  accent: statusAccent,
                  primary: true,
                  compact: true,
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.12),
        border: Border.all(
          color: color.withValues(alpha: 0.18),
        ),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: _DashboardPalette.isLight ? color : color,
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
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
  final bool compact;

  const _ClassActionButton({
    required this.action,
    required this.accent,
    required this.primary,
    this.compact = false,
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
          height: compact ? 40 : 44,
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

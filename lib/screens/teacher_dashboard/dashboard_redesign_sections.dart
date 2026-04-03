// ignore_for_file: invalid_use_of_protected_member, library_private_types_in_public_api

part of '../teacher_dashboard_screen.dart';

extension TeacherDashboardRedesignSections on _TeacherDashboardScreenState {
  Widget _buildDesktopMainContent(BuildContext context, DateTime now) {
    return _buildDashboardScrollPage(
      context,
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 24),
      children: [
        _buildDashboardTopSummarySection(context, now, compact: false),
        _buildDashboardClassStatusSection(context, now, compact: false),
        _buildDashboardQuickActionsSection(context, compact: false),
        _buildDashboardInsightsSection(context, now, compact: false),
        _buildDashboardPlanningSection(context, now, compact: false),
        _buildDashboardWorkspaceSection(context, compact: false),
      ],
    );
  }

  Widget _buildTabletMainContent(
    BuildContext context,
    DateTime now,
    Widget livePanel,
  ) {
    return _buildDashboardScrollPage(
      context,
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 20),
      children: [
        _buildDashboardTopSummarySection(context, now, compact: true),
        livePanel,
        _buildDashboardClassStatusSection(context, now, compact: true),
        _buildDashboardQuickActionsSection(context, compact: true),
        _buildDashboardInsightsSection(context, now, compact: true),
        _buildDashboardPlanningSection(context, now, compact: true),
        _buildDashboardWorkspaceSection(context, compact: true),
      ],
    );
  }

  Widget _buildMobileDashboardBody(BuildContext context, DateTime now) {
    Widget page;
    switch (_mobileDashboardIndex) {
      case 1:
        page = _buildDashboardScrollPage(
          context,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 100),
          children: [
            _buildDashboardPlanningSection(context, now, compact: true),
          ],
        );
        break;
      case 2:
        page = _buildDashboardScrollPage(
          context,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 100),
          children: [
            _buildDashboardWorkspaceSection(context, compact: true),
          ],
        );
        break;
      case 3:
        page = _buildDashboardScrollPage(
          context,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 100),
          children: [
            _buildLivePanelSection(context, now, compact: true),
          ],
        );
        break;
      default:
        page = _buildDashboardScrollPage(
          context,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 100),
          children: [
            _buildDashboardTopSummarySection(context, now, compact: true),
            _buildDashboardClassStatusSection(context, now, compact: true),
            _buildDashboardQuickActionsSection(context, compact: true),
            _buildDashboardInsightsSection(context, now, compact: true),
          ],
        );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: KeyedSubtree(
        key: ValueKey<int>(_mobileDashboardIndex),
        child: page,
      ),
    );
  }

  Widget _buildDashboardScrollPage(
    BuildContext context, {
    required EdgeInsets padding,
    required List<Widget> children,
  }) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int index = 0; index < children.length; index++) ...[
            children[index],
            if (index != children.length - 1) const SizedBox(height: 28),
          ],
        ],
      ),
    );
  }

  Widget _buildDashboardTopSummarySection(
    BuildContext context,
    DateTime now, {
    required bool compact,
  }) {
    final user = context.read<AuthService>().currentUser;
    final teacherName = (user?.fullName.trim().isNotEmpty ?? false)
        ? user!.fullName.trim()
        : 'Teacher';
    final schoolName =
        GradeFlowProductConfig.resolvedSchoolName(user?.schoolName);

    return KeyedSubtree(
      key: _summarySectionKey,
      child: DashboardTopSummary(
        title: 'Welcome back, $teacherName',
        subtitle: '$schoolName • ${RepositoryFactory.sourceOfTruthLabel}',
        todayLine: _dashboardTodayLine(now),
        actions: _dashboardHeaderActions(context),
        metrics: _dashboardSummaryMetrics(now),
        compact: compact,
      ),
    );
  }

  Widget _buildDashboardClassStatusSection(
    BuildContext context,
    DateTime now, {
    required bool compact,
  }) {
    return KeyedSubtree(
      key: _classStatusSectionKey,
      child: ClassStatusSection(
        classes: _dashboardClassCards(context, now),
        onOpenClasses: () => context.go(AppRoutes.classes),
        compact: compact,
      ),
    );
  }

  Widget _buildDashboardQuickActionsSection(
    BuildContext context, {
    required bool compact,
  }) {
    return KeyedSubtree(
      key: _quickActionsSectionKey,
      child: QuickActionsSection(
        actions: _dashboardQuickActions(context),
        compact: compact,
      ),
    );
  }

  Widget _buildDashboardInsightsSection(
    BuildContext context,
    DateTime now, {
    required bool compact,
  }) {
    return KeyedSubtree(
      key: _insightsSectionKey,
      child: InsightsSection(
        insights: _dashboardInsights(now),
        compact: compact,
      ),
    );
  }

  Widget _buildDashboardPlanningSection(
    BuildContext context,
    DateTime now, {
    required bool compact,
  }) {
    return KeyedSubtree(
      key: _planningSectionKey,
      child: PlanningSection(
        compact: compact,
        panels: [
          _buildReminderSummaryCard(context),
          KeyedSubtree(
            key: _calendarSectionKey,
            child: _Card(
              child: _buildCalendar(context),
            ),
          ),
          _buildTimetableSnapshotCard(context, now),
        ],
      ),
    );
  }

  Widget _buildDashboardWorkspaceSection(
    BuildContext context, {
    required bool compact,
  }) {
    return KeyedSubtree(
      key: _workspaceSectionKey,
      child: WorkspaceSection(
        compact: compact,
        panels: [
          KeyedSubtree(
            key: _classToolsSectionKey,
            child: _buildClassToolsSectionCard(context),
          ),
          _buildQuickLinksCard(context),
          _buildResearchToolsCard(context),
          const PilotFeedbackCard(
            initialArea: 'Dashboard redesign',
            initialRoute: '/dashboard',
          ),
        ],
      ),
    );
  }

  Widget _buildLivePanelSection(
    BuildContext context,
    DateTime now, {
    required bool compact,
  }) {
    final communication = _communicationWorkspaceSnapshot(now);
    return KeyedSubtree(
      key: _livePanelSectionKey,
      child: LivePanel(
        title: compact ? 'Comms' : communication.railTitle,
        subtitle: communication.railSubtitle,
        channels: communication.channels
            .map(
              (channel) => channel.unreadCount > 0
                  ? '${channel.name} - ${channel.unreadCount}'
                  : channel.name,
            )
            .toList(),
        stories: _dashboardLiveStories(context),
        announcements: _dashboardAnnouncements(now),
        compact: compact,
      ),
    );
  }

  List<_DashboardNavItemData> _dashboardNavItems(BuildContext context) => [
        _DashboardNavItemData(
          label: 'Dashboard',
          icon: Icons.dashboard_rounded,
          onTap: () => unawaited(_scrollToSection(_summarySectionKey)),
          isActive: true,
        ),
        _DashboardNavItemData(
          label: 'Classes',
          icon: Icons.class_rounded,
          onTap: () => context.go(AppRoutes.classes),
        ),
        _DashboardNavItemData(
          label: 'Gradebook',
          icon: Icons.grading_rounded,
          onTap: () => _openSelectedClassRoute(context, 'gradebook'),
        ),
        _DashboardNavItemData(
          label: 'Seating',
          icon: Icons.event_seat_rounded,
          onTap: () => _openSelectedClassRoute(context, 'seating'),
        ),
        _DashboardNavItemData(
          label: 'Timetable',
          icon: Icons.table_chart_rounded,
          onTap: _openTimetableDialog,
        ),
        _DashboardNavItemData(
          label: 'Imports',
          icon: Icons.file_upload_outlined,
          onTap: () => context.go(AppRoutes.classes),
        ),
        _DashboardNavItemData(
          label: 'Reports',
          icon: Icons.assessment_outlined,
          onTap: () => _openSelectedClassRoute(context, 'export'),
        ),
        _DashboardNavItemData(
          label: 'Tools',
          icon: Icons.widgets_outlined,
          onTap: () => unawaited(_scrollToSection(_classToolsSectionKey)),
        ),
      ];

  List<_DashboardNavItemData> _editionNavItems(BuildContext context) => [
        _DashboardNavItemData(
          label: 'Admin',
          icon: Icons.admin_panel_settings_outlined,
          badge: 'Live',
          onTap: () => context.go(AppRoutes.admin),
        ),
        _DashboardNavItemData(
          label: 'Communication',
          icon: Icons.forum_outlined,
          badge: 'Live',
          onTap: () => context.go(AppRoutes.communication),
        ),
      ];

  List<Widget> _dashboardHeaderActions(BuildContext context) {
    final themeMode = context.watch<ThemeModeNotifier>().themeMode;
    return [
      const PilotFeedbackIconButton(
        initialArea: 'Dashboard redesign',
        initialRoute: '/dashboard',
      ),
      IconButton(
        tooltip: themeMode == ThemeMode.dark
            ? 'Switch app theme'
            : 'Switch app theme',
        icon: Icon(
          themeMode == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode,
        ),
        onPressed: () => context.read<ThemeModeNotifier>().toggleTheme(),
      ),
      IconButton(
        tooltip: 'Log out',
        icon: const Icon(Icons.logout),
        onPressed: () => unawaited(_logoutDashboard(context)),
      ),
    ];
  }

  Future<void> _logoutDashboard(BuildContext context) async {
    await context.read<GoogleAuthService>().signOut();
    await context.read<AuthService>().logout();
    if (!context.mounted) return;
    context.go(AppRoutes.home);
  }

  void _openSelectedClassRoute(BuildContext context, String suffix) {
    final classId = _selectedClassId;
    if (classId == null) {
      context.go(AppRoutes.classes);
      return;
    }
    context.push('/class/$classId/$suffix');
  }

  String _dashboardTodayLine(DateTime now) {
    final todayClasses = _dashboardTodaySessionCount(now);
    final reminders = _pendingReminders().length;
    final actionsNeeded = _dashboardAttentionCount(now);
    return 'Today: $todayClasses class${todayClasses == 1 ? '' : 'es'} | '
        '$reminders reminder${reminders == 1 ? '' : 's'} | '
        '$actionsNeeded action${actionsNeeded == 1 ? '' : 's'} needed';
  }

  int _dashboardTodaySessionCount(DateTime now) {
    return _selectedTimetableClasses()
        .where((slot) => slot.dayOfWeek == now.weekday - 1)
        .length;
  }

  int _dashboardAttentionCount(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final thisWeek = today.add(const Duration(days: 7));
    int count = _pendingReminders().where((reminder) {
      final date = DateTime(reminder.timestamp.year, reminder.timestamp.month,
          reminder.timestamp.day);
      return !date.isAfter(thisWeek);
    }).length;
    if (_selectedTimetableId == null) count += 1;
    if (_classes.isEmpty) count += 1;
    return count;
  }

  CommunicationWorkspaceSnapshot _communicationWorkspaceSnapshot(DateTime now) {
    final user = context.read<AuthService>().currentUser;
    final communicationService = context.watch<CommunicationService>();
    final teacherName = (user?.fullName.trim().isNotEmpty ?? false)
        ? user!.fullName.trim()
        : 'Teacher';
    final schoolName =
        GradeFlowProductConfig.resolvedSchoolName(user?.schoolName);

    final liveAdminAlerts = communicationService.adminAlertMessages
        .where((message) => message.isAlert)
        .toList(growable: false);

    return _communicationWorkspaceService.buildSnapshot(
      CommunicationWorkspaceContext(
        schoolName: schoolName,
        teacherName: teacherName,
        sourceOfTruthLabel: RepositoryFactory.sourceOfTruthLabel,
        sourceOfTruthDescription: RepositoryFactory.sourceOfTruthDescription,
        cloudSyncEnabled: RepositoryFactory.isUsingFirestore,
        activeClassCount: _classes.length,
        totalStudents: _totalStudents,
        pendingReminderCount: _pendingReminders().length,
        focusedClassName: _selectedClassBrief()?.name,
        focusedDepartmentName: _focusedDepartmentName(),
        schoolAlerts: [
          for (final alert in liveAdminAlerts.take(3))
            CommunicationAlertSeed(
              title: _headlineSafe(alert.text, maxLength: 72),
              timestamp: alert.createdAt,
              audienceLabel: alert.authorName,
              severity: alert.severity,
              requiresAcknowledgement:
                  alert.severity == CommunicationAlertSeverity.urgent,
            ),
          for (final reminder in _schoolWideReminders().take(5))
            CommunicationAlertSeed(
              title: _headlineSafe(reminder.text, maxLength: 72),
              timestamp: reminder.timestamp,
              audienceLabel: 'School-wide',
              severity: _communicationSeverityForReminder(reminder, now),
              requiresAcknowledgement:
                  _communicationSeverityForReminder(reminder, now) ==
                      CommunicationAlertSeverity.urgent,
            ),
        ],
      ),
    );
  }

  String? _focusedDepartmentName() {
    final subtitle = _selectedClassBrief()?.subtitle.trim();
    if (subtitle == null || subtitle.isEmpty) return null;
    final parts = subtitle.split('•');
    final department = parts.first.trim();
    if (department.isEmpty) return null;
    return department;
  }

  CommunicationAlertSeverity _communicationSeverityForReminder(
    _Reminder reminder,
    DateTime now,
  ) {
    final today = DateTime(now.year, now.month, now.day);
    final dueDate = DateTime(
      reminder.timestamp.year,
      reminder.timestamp.month,
      reminder.timestamp.day,
    );
    final daysUntil = dueDate.difference(today).inDays;
    if (daysUntil <= 1) return CommunicationAlertSeverity.urgent;
    if (daysUntil <= 4) return CommunicationAlertSeverity.attention;
    return CommunicationAlertSeverity.info;
  }

  List<_DashboardSummaryMetricData> _dashboardSummaryMetrics(DateTime now) {
    final currentClass = _currentTimetableClass(now);
    final nextClass = _nextTimetableClass(now);
    final nextReminder = _nextOpenReminder();
    final communication = _communicationWorkspaceSnapshot(now);

    return [
      _DashboardSummaryMetricData(
        label: currentClass != null ? 'Now Teaching' : 'Next Class',
        value: currentClass?.timetableClass.title ??
            nextClass?.timetableClass.title ??
            'Timetable ready',
        detail: currentClass != null
            ? 'Until ${_formatHourMinute(currentClass.endAt)}'
            : nextClass != null
                ? _relativeTimetableTime(nextClass.startAt, now)
                : 'Upload a timetable to pin the day.',
        icon: currentClass != null
            ? Icons.play_circle_fill_rounded
            : Icons.badge_rounded,
        gradientColors: const [Color(0xFF3457A9), Color(0xFF253552)],
        onTap: _openTimetableDialog,
      ),
      _DashboardSummaryMetricData(
        label: 'Planning Queue',
        value: nextReminder != null
            ? _headlineSafe(nextReminder.text, maxLength: 26)
            : 'No urgent reminders',
        detail: nextReminder != null
            ? '${_shortMonthDay(nextReminder.timestamp)}${_optionalTimeInline(nextReminder.timestamp)}'
            : 'Your planning runway is clear right now.',
        icon: Icons.assignment_late_rounded,
        gradientColors: const [Color(0xFF6B2F39), Color(0xFF3B2730)],
        onTap: () => unawaited(_scrollToSection(_planningSectionKey)),
      ),
      _DashboardSummaryMetricData(
        label: communication.summaryLabel,
        value: _headlineSafe(communication.summaryValue, maxLength: 24),
        detail: communication.summaryDetail,
        icon: Icons.forum_rounded,
        gradientColors: const [Color(0xFF365A9B), Color(0xFF25304E)],
        onTap: () => unawaited(_scrollToSection(_livePanelSectionKey)),
      ),
    ];
  }

  List<_DashboardClassStatusData> _dashboardClassCards(
    BuildContext context,
    DateTime now,
  ) {
    final accents = <Color>[
      _DashboardPalette.amber,
      _DashboardPalette.accent,
      _DashboardPalette.green,
      _DashboardPalette.coral,
      _DashboardPalette.cyan,
      _DashboardPalette.purple,
    ];

    return _classes.asMap().entries.map((entry) {
      final classBrief = entry.value;
      final classId = classBrief.id;
      final reminders = _classReminders(classId);
      final current = _classMatchingTimetable(classBrief, now, next: false);
      final upcoming = _classMatchingTimetable(classBrief, now, next: true);
      final accent = accents[entry.key % accents.length];

      String statusLabel;
      String statusDetail;
      IconData statusIcon;

      if (current != null) {
        statusLabel = 'Live now';
        statusDetail = 'Ends ${_formatHourMinute(current.endAt)}';
        statusIcon = Icons.wifi_tethering_rounded;
      } else if (upcoming != null) {
        statusLabel = 'Next on timetable';
        statusDetail = _relativeTimetableTime(upcoming.startAt, now);
        statusIcon = Icons.schedule_rounded;
      } else if (reminders.isNotEmpty) {
        statusLabel =
            '${reminders.length} reminder${reminders.length == 1 ? '' : 's'}';
        statusDetail = _headlineSafe(reminders.first.text, maxLength: 38);
        statusIcon = Icons.flag_rounded;
      } else if (classBrief.studentCount == 0) {
        statusLabel = 'Roster needed';
        statusDetail = 'No students imported yet';
        statusIcon = Icons.group_add_rounded;
      } else {
        statusLabel = 'Ready for class';
        statusDetail = 'Stable and ready for grading, seating, and attendance';
        statusIcon = Icons.check_circle_rounded;
      }

      return _DashboardClassStatusData(
        id: classId,
        title: classBrief.name,
        subtitle: classBrief.subtitle,
        statusLabel: statusLabel,
        statusDetail: statusDetail,
        statusIcon: statusIcon,
        accent: accent,
        isSelected: classId == _selectedClassId,
        studentCount: classBrief.studentCount,
        onTap: () {
          setState(() => _selectedClassId = classId);
          _refreshNames();
        },
        actions: [
          _DashboardInlineActionData(
            label: 'Gradebook',
            icon: Icons.grading_outlined,
            onTap: () => context.push('/class/$classId/gradebook'),
          ),
          _DashboardInlineActionData(
            label: 'Seating',
            icon: Icons.event_seat_outlined,
            onTap: () => context.push('/class/$classId/seating'),
          ),
        ],
      );
    }).toList();
  }

  List<_DashboardQuickActionData> _dashboardQuickActions(
    BuildContext context,
  ) {
    final selectedName = _selectedClassBrief()?.name ?? 'selected class';
    return [
      _DashboardQuickActionData(
        label: 'Add Class',
        detail: 'Open class management and create a new teaching space.',
        icon: Icons.add_box_outlined,
        accent: _DashboardPalette.accent,
        onTap: () => context.go(AppRoutes.classes),
      ),
      _DashboardQuickActionData(
        label: 'Import Roster',
        detail: 'Jump into class import for classes and student rosters.',
        icon: Icons.upload_file_outlined,
        accent: _DashboardPalette.green,
        onTap: () => context.go(AppRoutes.classes),
      ),
      _DashboardQuickActionData(
        label: 'Seating Plan',
        detail: 'Open seating for $selectedName without leaving the flow.',
        icon: Icons.event_seat_outlined,
        accent: _DashboardPalette.cyan,
        onTap: () => _openSelectedClassRoute(context, 'seating'),
      ),
      _DashboardQuickActionData(
        label: 'Create Test',
        detail: 'Jump into exam setup for $selectedName.',
        icon: Icons.note_alt_outlined,
        accent: _DashboardPalette.coral,
        onTap: () => _openSelectedClassRoute(context, 'exams'),
      ),
    ];
  }

  List<_DashboardInsightData> _dashboardInsights(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final overdue = _pendingReminders().where((reminder) {
      final date = DateTime(reminder.timestamp.year, reminder.timestamp.month,
          reminder.timestamp.day);
      return date.isBefore(today);
    }).length;
    final dueToday = _pendingReminders().where((reminder) {
      final date = DateTime(reminder.timestamp.year, reminder.timestamp.month,
          reminder.timestamp.day);
      return date == today;
    }).length;
    final dueWeek = _pendingReminders().where((reminder) {
      final date = DateTime(reminder.timestamp.year, reminder.timestamp.month,
          reminder.timestamp.day);
      return !date.isBefore(today) &&
          !date.isAfter(today.add(const Duration(days: 7)));
    }).length;

    final rosterBars = _normalizedBars(
      _classes.take(4).map((classItem) => classItem.studentCount).toList(),
      length: 4,
    );

    final weekCounts = List<int>.filled(5, 0);
    for (final slot in _selectedTimetableClasses()) {
      if (slot.dayOfWeek >= 0 && slot.dayOfWeek < weekCounts.length) {
        weekCounts[slot.dayOfWeek] += 1;
      }
    }

    return [
      _DashboardInsightData(
        title: 'Action Load',
        value: _dashboardAttentionCount(now).toString(),
        subtitle: '$overdue overdue • $dueToday today • $dueWeek within 7 days',
        bars: _normalizedBars(
            [overdue, dueToday, dueWeek, _pendingReminders().length],
            length: 4),
        accent: _DashboardPalette.coral,
      ),
      _DashboardInsightData(
        title: 'Roster Reach',
        value: _totalStudents.toString(),
        subtitle: '${_classes.length} classes live in the teacher workspace',
        bars: rosterBars,
        accent: _DashboardPalette.cyan,
      ),
      _DashboardInsightData(
        title: 'Week Cadence',
        value: weekCounts.fold<int>(0, (sum, count) => sum + count).toString(),
        subtitle:
            '${_dashboardTodaySessionCount(now)} session${_dashboardTodaySessionCount(now) == 1 ? '' : 's'} today in the active timetable',
        bars: _normalizedBars(weekCounts, length: 5),
        accent: _DashboardPalette.green,
      ),
    ];
  }

  List<_DashboardLiveStoryData> _dashboardLiveStories(BuildContext context) {
    final communication = _communicationWorkspaceSnapshot(DateTime.now());
    return communication.deskCards.map((card) {
      return _DashboardLiveStoryData(
        label: card.overline,
        title: card.title,
        subtitle: card.description,
        icon: _communicationKindIcon(card.kind),
        accent: _communicationKindAccent(card.kind),
        chips: [
          ...card.chips.take(3),
          if (card.unreadCount > 0) '${card.unreadCount} unread',
        ],
        onTap: () => context.go(AppRoutes.communication),
      );
    }).toList();
  }

  List<_DashboardAnnouncementData> _dashboardAnnouncements(DateTime now) {
    final communication = _communicationWorkspaceSnapshot(now);
    return communication.announcements.map((item) {
      return _DashboardAnnouncementData(
        title: _headlineSafe(item.title, maxLength: 42),
        subtitle: item.subtitle,
        icon: _communicationAnnouncementIcon(item.kind, item.severity),
        accent: _communicationSeverityAccent(item.severity),
        onTap: item.kind == CommunicationChannelKind.adminAlerts
            ? () => context.go(AppRoutes.admin)
            : () => context.go(AppRoutes.communication),
      );
    }).toList();
  }

  IconData _communicationKindIcon(CommunicationChannelKind kind) {
    switch (kind) {
      case CommunicationChannelKind.adminAlerts:
        return Icons.campaign_rounded;
      case CommunicationChannelKind.staffRoom:
        return Icons.groups_rounded;
      case CommunicationChannelKind.department:
        return Icons.forum_rounded;
      case CommunicationChannelKind.gradeTeam:
        return Icons.hub_rounded;
      case CommunicationChannelKind.direct:
        return Icons.chat_bubble_rounded;
      case CommunicationChannelKind.sharedFiles:
        return Icons.folder_shared_rounded;
    }
  }

  Color _communicationKindAccent(CommunicationChannelKind kind) {
    switch (kind) {
      case CommunicationChannelKind.adminAlerts:
        return _DashboardPalette.amber;
      case CommunicationChannelKind.staffRoom:
        return _DashboardPalette.accent;
      case CommunicationChannelKind.department:
        return _DashboardPalette.cyan;
      case CommunicationChannelKind.gradeTeam:
        return _DashboardPalette.purple;
      case CommunicationChannelKind.direct:
        return _DashboardPalette.green;
      case CommunicationChannelKind.sharedFiles:
        return _DashboardPalette.coral;
    }
  }

  IconData _communicationAnnouncementIcon(
    CommunicationChannelKind kind,
    CommunicationAlertSeverity severity,
  ) {
    if (kind == CommunicationChannelKind.adminAlerts) {
      switch (severity) {
        case CommunicationAlertSeverity.urgent:
          return Icons.priority_high_rounded;
        case CommunicationAlertSeverity.attention:
          return Icons.notification_important_outlined;
        case CommunicationAlertSeverity.info:
          return Icons.campaign_outlined;
      }
    }

    switch (kind) {
      case CommunicationChannelKind.staffRoom:
        return Icons.cloud_done_outlined;
      case CommunicationChannelKind.department:
        return Icons.class_outlined;
      case CommunicationChannelKind.gradeTeam:
        return Icons.hub_outlined;
      case CommunicationChannelKind.direct:
        return Icons.chat_bubble_outline_rounded;
      case CommunicationChannelKind.sharedFiles:
        return Icons.folder_shared_outlined;
      case CommunicationChannelKind.adminAlerts:
        return Icons.campaign_outlined;
    }
  }

  Color _communicationSeverityAccent(CommunicationAlertSeverity severity) {
    switch (severity) {
      case CommunicationAlertSeverity.urgent:
        return _DashboardPalette.coral;
      case CommunicationAlertSeverity.attention:
        return _DashboardPalette.amber;
      case CommunicationAlertSeverity.info:
        return _DashboardPalette.green;
    }
  }

  Widget _buildTimetableSnapshotCard(BuildContext context, DateTime now) {
    final timetable = _selectedTimetable();
    final currentClass = _currentTimetableClass(now);
    final nextClass = _nextTimetableClass(now);
    final slotCount = _selectedTimetableClasses().length;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.table_chart_outlined),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Timetable runway',
                  style: context.textStyles.titleMedium?.semiBold,
                ),
              ),
              OutlinedButton.icon(
                onPressed: _openTimetableDialog,
                icon: const Icon(Icons.edit_calendar_outlined),
                label: Text(timetable == null ? 'Add timetable' : 'Manage'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            timetable?.name ?? 'No timetable selected yet',
            style: context.textStyles.titleSmall?.semiBold,
          ),
          const SizedBox(height: 8),
          Text(
            currentClass != null
                ? 'Now teaching ${currentClass.timetableClass.title} until ${_formatHourMinute(currentClass.endAt)}.'
                : nextClass != null
                    ? 'Next up: ${nextClass.timetableClass.title} ${_relativeTimetableTime(nextClass.startAt, now)}.'
                    : 'Upload or edit a timetable to anchor the rest of the dashboard.',
            style: context.textStyles.bodyMedium?.withColor(
              Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildMetricChip(context, '$slotCount slots'),
              _buildMetricChip(context,
                  _selectedTimetableId == null ? 'Local only' : 'Pinned'),
              if (currentClass != null) _buildMetricChip(context, 'Live class'),
            ],
          ),
        ],
      ),
    );
  }

  List<_Reminder> _classReminders(String classId) {
    final items = _pendingReminders()
        .where((reminder) => reminder.classIds?.contains(classId) ?? false)
        .toList();
    items.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return items;
  }

  _TimetableSlotMoment? _classMatchingTimetable(
    _ClassBrief classBrief,
    DateTime now, {
    required bool next,
  }) {
    final target =
        next ? _nextTimetableClass(now) : _currentTimetableClass(now);
    if (target == null) return null;
    return _classMatchesTimetableLabel(classBrief, target.timetableClass.title)
        ? target
        : null;
  }

  bool _classMatchesTimetableLabel(_ClassBrief classBrief, String title) {
    final left = classBrief.name.toLowerCase().replaceAll(' ', '');
    final right = title.toLowerCase().replaceAll(' ', '');
    return left.isNotEmpty && (right.contains(left) || left.contains(right));
  }

  List<double> _normalizedBars(List<int> counts, {required int length}) {
    final values = List<int>.from(counts);
    while (values.length < length) {
      values.add(0);
    }
    if (values.length > length) {
      values.removeRange(length, values.length);
    }
    final maxValue =
        values.fold<int>(0, (max, value) => value > max ? value : max);
    if (maxValue == 0) {
      return List<double>.filled(length, 0.18);
    }
    return values
        .map((value) => value == 0 ? 0.18 : (value / maxValue).clamp(0.18, 1.0))
        .toList();
  }
}

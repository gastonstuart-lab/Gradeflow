// ignore_for_file: invalid_use_of_protected_member, library_private_types_in_public_api

part of '../teacher_dashboard_screen.dart';

class _DashboardWidgetToggleConfig {
  final String id;
  final String label;

  const _DashboardWidgetToggleConfig({
    required this.id,
    required this.label,
  });
}

extension TeacherDashboardRedesignSections on _TeacherDashboardScreenState {
  Widget _buildDesktopMainContent(BuildContext context, DateTime now) {
    return _buildDashboardScrollPage(
      context,
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 24),
      children: [
        _buildDashboardTopSummarySection(context, now, compact: false),
        _buildDashboardClassStatusSection(context, now, compact: false),
        _buildDashboardQuickActionsSection(context, compact: false),
        _buildDashboardWorkspaceModeSection(context),
        ..._buildDashboardFocusedSurfaces(context, now, compact: false),
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
        _buildDashboardWorkspaceModeSection(context),
        ..._buildDashboardFocusedSurfaces(context, now, compact: true),
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
            _buildDashboardWorkspaceSection(context, now, compact: true),
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
            _buildDashboardWorkspaceModeSection(context),
            ..._buildDashboardFocusedSurfaces(context, now, compact: true),
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
        actions: _dashboardHeaderActions(context, now),
        metrics: _dashboardSummaryMetrics(now),
        presentation: _dashboardHeroPresentation(),
        backgroundImage: _dashboardHeroImageProvider(),
        compact: compact,
      ),
    );
  }

  Widget _buildDashboardClassStatusSection(
    BuildContext context,
    DateTime now, {
    required bool compact,
  }) {
    final showTimetableWarning = _selectedTimetableId == null;
    return KeyedSubtree(
      key: _classStatusSectionKey,
      child: ClassStatusSection(
        classes: _dashboardClassCards(context, now),
        onOpenClasses: () => context.go(AppRoutes.classes),
        compact: compact,
        warning: showTimetableWarning
            ? _buildTimetableMissingWarning(context)
            : null,
      ),
    );
  }

  Widget _buildTimetableMissingWarning(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: _DashboardPalette.amber.withValues(alpha: 0.10),
        border: Border.all(
          color: _DashboardPalette.amber.withValues(alpha: 0.20),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 18,
            color: _DashboardPalette.amber,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Review setup while timetable details are still missing.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _DashboardPalette.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
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
    final previews =
        _buildDashboardSectionPreviews(context, now, compact: compact);
    final panelBuilders = <String, Widget Function()>{
      _DashboardLayoutKeys.planningReminderSummary: () =>
          _buildReminderSummaryCard(context),
      _DashboardLayoutKeys.planningCalendar: () => KeyedSubtree(
            key: _calendarSectionKey,
            child: _Card(
              child: _buildCalendar(context),
            ),
          ),
      _DashboardLayoutKeys.planningTimetableSnapshot: () =>
          _buildTimetableSnapshotCard(context, now),
      if (previews.isNotEmpty)
        _DashboardLayoutKeys.planningPreviewGrid: () =>
            _buildDashboardStandbySurfaceCard(
              context,
              previews,
              compact: compact,
            ),
    };
    final orderedIds = _orderedWidgetIdsForSurface(
      DashboardWorkspaceSection.planning,
      _dashboardWidgetIdsForSurface(DashboardWorkspaceSection.planning),
    );
    final panels = <Widget>[];
    for (final id in orderedIds) {
      if (_isDashboardWidgetVisible(DashboardWorkspaceSection.planning, id)) {
        final builder = panelBuilders[id];
        if (builder != null) {
          panels.add(builder());
        }
      }
    }

    return KeyedSubtree(
      key: _planningSectionKey,
      child: PlanningSection(
        compact: compact,
        panels: panels.isEmpty
            ? [
                _buildDashboardEmptySurfaceCard(
                  context,
                  message:
                      'No schedule widgets are visible. Use Customize to show panels.',
                ),
              ]
            : panels,
      ),
    );
  }

  Widget _buildDashboardWorkspaceSection(
    BuildContext context,
    DateTime now, {
    required bool compact,
  }) {
    final previews =
        _buildDashboardSectionPreviews(context, now, compact: compact);
    final panelBuilders = <String, Widget Function()>{
      _DashboardLayoutKeys.workspaceQuickLinks: () =>
          _buildQuickLinksCard(context),
      _DashboardLayoutKeys.workspaceResearchTools: () =>
          _buildResearchToolsCard(context),
      _DashboardLayoutKeys.workspacePilotFeedback: () =>
          const PilotFeedbackCard(
            initialArea: 'Dashboard redesign',
            initialRoute: '/dashboard',
          ),
      if (previews.isNotEmpty)
        _DashboardLayoutKeys.workspacePreviewGrid: () =>
            _buildDashboardStandbySurfaceCard(
              context,
              previews,
              compact: compact,
            ),
    };
    final orderedIds = _orderedWidgetIdsForSurface(
      DashboardWorkspaceSection.workspace,
      _dashboardWidgetIdsForSurface(DashboardWorkspaceSection.workspace),
    );
    final panels = <Widget>[];
    for (final id in orderedIds) {
      if (_isDashboardWidgetVisible(DashboardWorkspaceSection.workspace, id)) {
        final builder = panelBuilders[id];
        if (builder != null) {
          panels.add(builder());
        }
      }
    }

    return KeyedSubtree(
      key: _workspaceSectionKey,
      child: WorkspaceSection(
        compact: compact,
        panels: panels.isEmpty
            ? [
                _buildDashboardEmptySurfaceCard(
                  context,
                  message:
                      'No workspace widgets are visible. Use Customize to show panels.',
                ),
              ]
            : panels,
      ),
    );
  }

  Widget _buildDashboardWorkspaceModeSection(BuildContext context) {
    return DashboardWorkspaceModeStrip(
      selectedSection: _workspaceSection,
      description: _workspaceSectionDescription(_workspaceSection),
      onCustomizeLayout: _openDashboardLayoutCustomizer,
      onSelected: _setWorkspaceSection,
    );
  }

  List<Widget> _buildDashboardFocusedSurfaces(
    BuildContext context,
    DateTime now, {
    required bool compact,
  }) {
    final previews =
        _buildDashboardSectionPreviews(context, now, compact: compact);
    final orderedIds = _orderedWidgetIdsForSurface(
      _workspaceSection,
      _dashboardWidgetIdsForSurface(_workspaceSection),
    );
    switch (_workspaceSection) {
      case DashboardWorkspaceSection.today:
        final widgets = <Widget>[];
        for (final id in orderedIds) {
          if (!_isDashboardWidgetVisible(DashboardWorkspaceSection.today, id)) {
            continue;
          }
          switch (id) {
            case _DashboardLayoutKeys.todayInsights:
              widgets.add(
                _buildDashboardInsightsSection(context, now, compact: compact),
              );
              break;
            case _DashboardLayoutKeys.todayPreviewGrid:
              if (previews.isNotEmpty) {
                widgets.add(
                  _buildDashboardStandbySurfaceCard(
                    context,
                    previews,
                    compact: compact,
                  ),
                );
              }
              break;
            default:
              break;
          }
        }
        return [
          if (widgets.isEmpty)
            _buildDashboardEmptySurfaceCard(
              context,
              message:
                  'No Today widgets are visible. Use Customize to show panels.',
            )
          else
            ...widgets,
        ];
      case DashboardWorkspaceSection.classroom:
        final widgets = <Widget>[];
        for (final id in orderedIds) {
          if (!_isDashboardWidgetVisible(
            DashboardWorkspaceSection.classroom,
            id,
          )) {
            continue;
          }
          switch (id) {
            case _DashboardLayoutKeys.classroomStudio:
              widgets.add(
                _buildDashboardClassroomStudioSection(
                  context,
                  compact: compact,
                ),
              );
              break;
            case _DashboardLayoutKeys.classroomPreviewGrid:
              if (previews.isNotEmpty) {
                widgets.add(
                  _buildDashboardStandbySurfaceCard(
                    context,
                    previews,
                    compact: compact,
                  ),
                );
              }
              break;
            default:
              break;
          }
        }
        return [
          if (widgets.isEmpty)
            _buildDashboardEmptySurfaceCard(
              context,
              message:
                  'No Classroom widgets are visible. Use Customize to show panels.',
            )
          else
            ...widgets,
        ];
      case DashboardWorkspaceSection.planning:
        return [
          _buildDashboardPlanningSection(context, now, compact: compact),
        ];
      case DashboardWorkspaceSection.workspace:
        return [
          _buildDashboardWorkspaceSection(context, now, compact: compact),
        ];
    }
  }

  Widget _buildDashboardClassroomStudioSection(
    BuildContext context, {
    required bool compact,
  }) {
    return _DashboardSectionFrame(
      title: 'Classroom Studio',
      subtitle: 'Whiteboard and live classroom tools.',
      child: _ResponsivePanelWrap(
        compact: compact,
        children: [
          KeyedSubtree(
            key: _classToolsSectionKey,
            child: _buildClassToolsSectionCard(context),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardSectionPreviewGrid(
    List<DashboardSectionPreviewCard> previews, {
    required bool compact,
  }) {
    final columns = compact ? 1 : 3;
    final gap = 14.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final tileWidth =
            columns == 1 ? width : (width - (gap * (columns - 1))) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final preview in previews)
              SizedBox(
                width: tileWidth,
                child: preview,
              ),
          ],
        );
      },
    );
  }

  List<DashboardSectionPreviewCard> _buildDashboardSectionPreviews(
    BuildContext context,
    DateTime now, {
    required bool compact,
  }) {
    final previews = <DashboardSectionPreviewCard>[];
    final nextReminder = _nextOpenReminder();

    if (_workspaceSection != DashboardWorkspaceSection.today) {
      previews.add(
        DashboardSectionPreviewCard(
          title: 'Today overview',
          detail: 'Insights and priorities stay one tap away.',
          icon: Icons.insights_outlined,
          actionLabel: 'Open today',
          onTap: () => _setWorkspaceSection(DashboardWorkspaceSection.today),
        ),
      );
    }
    if (_workspaceSection != DashboardWorkspaceSection.classroom) {
      previews.add(
        DashboardSectionPreviewCard(
          title: 'Classroom studio',
          detail: 'Whiteboard, timer, polls, and room tools.',
          icon: Icons.draw_outlined,
          actionLabel: 'Open studio',
          onTap: () =>
              _setWorkspaceSection(DashboardWorkspaceSection.classroom),
        ),
      );
    }
    if (_workspaceSection != DashboardWorkspaceSection.planning) {
      previews.add(
        DashboardSectionPreviewCard(
          title: 'Schedule board',
          detail: nextReminder != null
              ? 'Next: ${_headlineSafe(nextReminder.text, maxLength: 52)}.'
              : 'Calendar, timetable, and reminders.',
          icon: Icons.event_note_outlined,
          actionLabel: 'Open schedule',
          onTap: () => _setWorkspaceSection(DashboardWorkspaceSection.planning),
        ),
      );
    }
    if (_workspaceSection != DashboardWorkspaceSection.workspace) {
      previews.add(
        DashboardSectionPreviewCard(
          title: 'Workspace tools',
          detail:
              '${_customLinks.length + 3} links and helper tools stay on standby.',
          icon: Icons.workspaces_outline,
          actionLabel: 'Open tools',
          onTap: () =>
              _setWorkspaceSection(DashboardWorkspaceSection.workspace),
        ),
      );
    }

    return previews.take(compact ? 2 : 3).toList(growable: false);
  }

  List<String> _dashboardWidgetIdsForSurface(
    DashboardWorkspaceSection surface,
  ) {
    return _dashboardWidgetToggleConfig(surface)
        .map((toggle) => toggle.id)
        .toList(growable: false);
  }

  Widget _buildDashboardEmptySurfaceCard(
    BuildContext context, {
    required String message,
  }) {
    return _Card(
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: _DashboardPalette.textSecondary,
            ),
      ),
    );
  }

  Widget _buildDashboardStandbySurfaceCard(
    BuildContext context,
    List<DashboardSectionPreviewCard> previews, {
    required bool compact,
  }) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.view_agenda_outlined),
              const SizedBox(width: 8),
              Text(
                'Standby surfaces',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Keep other dashboard surfaces close without changing the default flow.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _DashboardPalette.textSecondary,
                ),
          ),
          const SizedBox(height: 14),
          _buildDashboardSectionPreviewGrid(previews, compact: compact),
        ],
      ),
    );
  }

  List<_DashboardWidgetToggleConfig> _dashboardWidgetToggleConfig(
    DashboardWorkspaceSection surface,
  ) {
    switch (surface) {
      case DashboardWorkspaceSection.today:
        return const [
          _DashboardWidgetToggleConfig(
            id: _DashboardLayoutKeys.todayInsights,
            label: 'Insights',
          ),
          _DashboardWidgetToggleConfig(
            id: _DashboardLayoutKeys.todayPreviewGrid,
            label: 'Cross-surface previews',
          ),
        ];
      case DashboardWorkspaceSection.classroom:
        return const [
          _DashboardWidgetToggleConfig(
            id: _DashboardLayoutKeys.classroomStudio,
            label: 'Classroom studio',
          ),
          _DashboardWidgetToggleConfig(
            id: _DashboardLayoutKeys.classroomPreviewGrid,
            label: 'Cross-surface previews',
          ),
        ];
      case DashboardWorkspaceSection.planning:
        return const [
          _DashboardWidgetToggleConfig(
            id: _DashboardLayoutKeys.planningReminderSummary,
            label: 'Reminder summary',
          ),
          _DashboardWidgetToggleConfig(
            id: _DashboardLayoutKeys.planningCalendar,
            label: 'Calendar',
          ),
          _DashboardWidgetToggleConfig(
            id: _DashboardLayoutKeys.planningTimetableSnapshot,
            label: 'Timetable snapshot',
          ),
          _DashboardWidgetToggleConfig(
            id: _DashboardLayoutKeys.planningPreviewGrid,
            label: 'Cross-surface previews',
          ),
        ];
      case DashboardWorkspaceSection.workspace:
        return const [
          _DashboardWidgetToggleConfig(
            id: _DashboardLayoutKeys.workspaceQuickLinks,
            label: 'Quick links',
          ),
          _DashboardWidgetToggleConfig(
            id: _DashboardLayoutKeys.workspaceResearchTools,
            label: 'Research tools',
          ),
          _DashboardWidgetToggleConfig(
            id: _DashboardLayoutKeys.workspacePilotFeedback,
            label: 'Pilot feedback',
          ),
          _DashboardWidgetToggleConfig(
            id: _DashboardLayoutKeys.workspacePreviewGrid,
            label: 'Cross-surface previews',
          ),
        ];
    }
  }

  Future<void> _openDashboardLayoutCustomizer() async {
    var selectedSurface = _workspaceSection;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final toggles = _dashboardWidgetToggleConfig(selectedSurface);
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: DashboardPanelCard(
                  radius: 20,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Customize dashboard',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SegmentedButton<DashboardWorkspaceSection>(
                          segments: const [
                            ButtonSegment(
                              value: DashboardWorkspaceSection.today,
                              label: Text('Today'),
                            ),
                            ButtonSegment(
                              value: DashboardWorkspaceSection.classroom,
                              label: Text('Classroom'),
                            ),
                            ButtonSegment(
                              value: DashboardWorkspaceSection.planning,
                              label: Text('Schedule'),
                            ),
                            ButtonSegment(
                              value: DashboardWorkspaceSection.workspace,
                              label: Text('Workspace'),
                            ),
                          ],
                          selected: {selectedSurface},
                          onSelectionChanged: (selection) {
                            setSheetState(() {
                              selectedSurface = selection.first;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...toggles.map(
                        (toggle) => SwitchListTile.adaptive(
                          dense: true,
                          value: _isDashboardWidgetVisible(
                            selectedSurface,
                            toggle.id,
                          ),
                          onChanged: (isVisible) {
                            _setDashboardWidgetVisibility(
                              surface: selectedSurface,
                              widgetId: toggle.id,
                              isVisible: isVisible,
                            );
                            setSheetState(() {});
                          },
                          title: Text(toggle.label),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () {
                              _resetDashboardSurfaceLayout(selectedSurface);
                              setSheetState(() {});
                            },
                            child: const Text('Reset surface'),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () {
                              _resetDashboardLayoutToDefaults();
                              setSheetState(() {
                                selectedSurface = _workspaceSection;
                              });
                            },
                            child: const Text('Reset all'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLivePanelSection(
    BuildContext context,
    DateTime now, {
    required bool compact,
  }) {
    final communicationWidget = _dashboardCommunicationWidgetData(now);
    return KeyedSubtree(
      key: _livePanelSectionKey,
      child: LivePanel(
        systemWidget: _dashboardSystemWidgetData(now),
        audioWidget: _dashboardAudioWidgetData(now),
        statusItems: _dashboardSystemStatusItems(now),
        communicationWidget: communicationWidget,
        compact: compact,
      ),
    );
  }

  List<DashboardNavItemData> _dashboardNavItems(BuildContext context) => [
        DashboardNavItemData(
          label: 'Dashboard',
          icon: Icons.dashboard_rounded,
          onTap: () => unawaited(_scrollToSection(_summarySectionKey)),
          isActive: true,
        ),
        DashboardNavItemData(
          label: 'Classes',
          icon: Icons.class_rounded,
          onTap: () => context.go(AppRoutes.classes),
        ),
        DashboardNavItemData(
          label: 'Gradebook',
          icon: Icons.grading_rounded,
          onTap: () => _openSelectedClassRoute(context, 'gradebook'),
        ),
        DashboardNavItemData(
          label: 'Seating',
          icon: Icons.event_seat_rounded,
          onTap: () => _openSelectedClassRoute(context, 'seating'),
        ),
        DashboardNavItemData(
          label: 'Timetable',
          icon: Icons.table_chart_rounded,
          onTap: _openTimetableDialog,
        ),
        DashboardNavItemData(
          label: 'Imports',
          icon: Icons.file_upload_outlined,
          onTap: () => context.go(AppRoutes.classes),
        ),
        DashboardNavItemData(
          label: 'Reports',
          icon: Icons.assessment_outlined,
          onTap: () => _openSelectedClassRoute(context, 'export'),
        ),
        DashboardNavItemData(
          label: 'Tools',
          icon: Icons.widgets_outlined,
          onTap: () => unawaited(_scrollToSection(_classToolsSectionKey)),
        ),
      ];

  List<DashboardNavItemData> _editionNavItems(BuildContext context) => [
        DashboardNavItemData(
          label: 'Admin',
          icon: Icons.admin_panel_settings_outlined,
          badge: 'Live',
          onTap: () => context.go(AppRoutes.admin),
        ),
        DashboardNavItemData(
          label: 'Communication',
          icon: Icons.forum_outlined,
          badge: 'Live',
          onTap: () => context.go(AppRoutes.communication),
        ),
      ];

  List<Widget> _dashboardHeaderActions(BuildContext context, DateTime now) {
    final themeMode = context.watch<ThemeModeNotifier>().themeMode;
    final notificationCenter = _dashboardNotificationCenterData(now);
    return [
      _DashboardHeaderUtilityButton(
        label: 'Attention center',
        icon: Icons.notifications_active_outlined,
        badge: notificationCenter.totalCount > 0
            ? _compactBadgeCount(notificationCenter.totalCount)
            : null,
        onPressed: _toggleNotificationCenter,
      ),
      const PilotFeedbackIconButton(
        initialArea: 'Dashboard redesign',
        initialRoute: '/dashboard',
      ),
      IconButton(
        icon: const Icon(Icons.palette_outlined),
        onPressed: _openHeroPersonalizationSheet,
      ),
      IconButton(
        icon: Icon(
          themeMode == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode,
        ),
        onPressed: () => context.read<ThemeModeNotifier>().toggleTheme(),
      ),
      IconButton(
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
    _openSelectedClassRouteSafely(context, suffix);
  }

  String _dashboardTodayLine(DateTime now) {
    final activeClasses = _classes.length;
    final reminders = _pendingReminders().length;
    final actionsNeeded = _dashboardAttentionCount(now);
    return '$activeClasses class${activeClasses == 1 ? '' : 'es'} • '
        '$reminders reminder${reminders == 1 ? '' : 's'} • '
        '$actionsNeeded to review';
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
        liveChannels: [
          for (final channel in communicationService.channels)
            CommunicationChannelPreview(
              channelId: channel.channelId,
              name: channel.name,
              kind: channel.kind,
              description: channel.description,
              readOnly: channel.readOnly,
              unreadCount:
                  communicationService.unreadCountForChannel(channel.channelId),
              memberCount: channel.memberCount,
              lastMessagePreview: channel.lastMessagePreview,
              lastSenderName: channel.lastSenderName,
              lastMessageAt: channel.lastMessageAt,
            ),
        ],
        liveTotalUnread: communicationService.totalUnreadCount,
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

  List<DashboardSummaryMetricData> _dashboardSummaryMetrics(DateTime now) {
    final currentClass = _currentTimetableClass(now);
    final nextClass = _nextTimetableClass(now);
    final nextReminder = _nextOpenReminder();
    final communication = _communicationWorkspaceSnapshot(now);
    final activeChannels = communication.channels
        .where((channel) => channel.unreadCount > 0)
        .length;

    return [
      DashboardSummaryMetricData(
        label: currentClass != null ? 'Now Teaching' : 'Next Class',
        value: currentClass?.timetableClass.title ??
            nextClass?.timetableClass.title ??
            'Timetable ready',
        detail: currentClass != null
            ? 'Until ${_formatHourMinute(currentClass.endAt)}'
            : nextClass != null
                ? _relativeTimetableTime(nextClass.startAt, now)
                : 'Timetable ready',
        icon: currentClass != null
            ? Icons.play_circle_fill_rounded
            : Icons.badge_rounded,
        gradientColors: const [Color(0xFF3457A9), Color(0xFF253552)],
        actionLabel: 'Open timetable',
        onTap: _openTimetableDialog,
      ),
      DashboardSummaryMetricData(
        label: 'Attention',
        value: nextReminder != null
            ? _headlineSafe(nextReminder.text, maxLength: 26)
            : 'Clear for now',
        detail: nextReminder != null
            ? '${_shortMonthDay(nextReminder.timestamp)}${_optionalTimeInline(nextReminder.timestamp)}'
            : 'No urgent alerts',
        icon: Icons.warning_amber_rounded,
        gradientColors: const [Color(0xFF6B2F39), Color(0xFF3B2730)],
        actionLabel: 'Review schedule',
        onTap: () => unawaited(_scrollToSection(_planningSectionKey)),
      ),
      DashboardSummaryMetricData(
        label: 'Messages',
        value: communication.totalUnread > 0
            ? '${communication.totalUnread} unread'
            : 'Inbox clear',
        detail: activeChannels > 0
            ? '$activeChannels active thread${activeChannels == 1 ? '' : 's'}'
            : 'Staff channels ready',
        icon: Icons.forum_rounded,
        gradientColors: const [Color(0xFF365A9B), Color(0xFF25304E)],
        actionLabel: 'Open inbox',
        onTap: () => unawaited(_scrollToSection(_livePanelSectionKey)),
      ),
    ];
  }

  List<DashboardClassStatusData> _dashboardClassCards(
    BuildContext context,
    DateTime now,
  ) {
    return _classes.asMap().entries.map((entry) {
      final classBrief = entry.value;
      final classId = classBrief.id;
      final health = _classHealthFor(classBrief, now);
      final secondaryAction = _resolvedSecondaryAction(health);

      return DashboardClassStatusData(
        id: classId,
        title: classBrief.name,
        subtitle: classBrief.subtitle,
        level: health.level,
        levelLabel: health.levelLabel,
        statusLabel: health.primaryReason,
        statusDetail: health.secondaryDetail,
        recommendedLabel: health.recommendedLabel,
        recommendedDetail: health.recommendedDetail,
        statusIcon: _healthStatusIcon(health),
        accent: _DashboardPalette.accent,
        isSelected: classId == _dashboardRailSelectedClassId,
        studentCount: classBrief.studentCount,
        metrics: [
          for (final metric in health.metrics)
            DashboardClassMetricData(
              icon: _healthMetricIcon(metric.label),
              label: '${metric.label}: ${metric.value}',
            ),
        ],
        onTap: () => _selectDashboardClassFromRail(classId),
        actions: [
          _dashboardActionForHealth(
            context,
            classBrief,
            health.primaryAction,
          ),
          _dashboardActionForHealth(
            context,
            classBrief,
            secondaryAction,
          ),
        ],
        suppressTimetableWarning: _selectedTimetableId == null &&
            !_classHasTimetableContext(classBrief),
      );
    }).toList();
  }

  ClassHealthRecord _classHealthFor(
    _ClassBrief classBrief,
    DateTime now,
  ) {
    final staticSignals = _classHealthSignalsByClassId[classBrief.id] ??
        ClassHealthStaticSignals.fallback(
          classId: classBrief.id,
          className: classBrief.name,
          studentCount: classBrief.studentCount,
          classUpdatedAt: classBrief.updatedAt ?? now,
        );
    final reminders = _classReminders(classBrief.id);
    final current = _currentTimetableMomentForClass(classBrief, now);
    final upcoming = _nextTimetableMomentForClass(classBrief, now);
    return _classHealthService.build(
      staticSignals: staticSignals,
      runtimeSignals: ClassHealthRuntimeSignals(
        now: now,
        isFocused: classBrief.id == _selectedClassId,
        hasSelectedTimetable: _selectedTimetableId != null,
        hasTimetableContext: _classHasTimetableContext(classBrief),
        isLiveNow: current != null,
        currentClassEndsAt: current?.endAt,
        nextClassStartsAt: upcoming?.startAt,
        openReminderCount: reminders.length,
        dueSoonReminderCount: _reminderCountWithin(reminders, now, days: 7),
        overdueReminderCount: _overdueReminderCount(reminders, now),
        nextReminderText: reminders.isEmpty ? null : reminders.first.text,
        nextReminderAt: reminders.isEmpty ? null : reminders.first.timestamp,
      ),
    );
  }

  DashboardInlineActionData _dashboardActionForHealth(
    BuildContext context,
    _ClassBrief classBrief,
    ClassHealthAction action,
  ) {
    return DashboardInlineActionData(
      label: action.label,
      icon: _healthActionIcon(action.type),
      onTap: () {
        _focusClass(classBrief.id);
        switch (action.type) {
          case ClassHealthActionType.openClassWorkspace:
            context.go('${AppRoutes.osClass}/${classBrief.id}');
            return;
          case ClassHealthActionType.openClassesWorkspace:
            context.go(AppRoutes.classes);
            return;
          case ClassHealthActionType.openGradebook:
            context.push('/class/${classBrief.id}/gradebook');
            return;
          case ClassHealthActionType.openSeating:
            context.push('/class/${classBrief.id}/seating');
            return;
          case ClassHealthActionType.openTimetable:
            _openTimetableDialog();
            return;
          case ClassHealthActionType.reviewPlanning:
            unawaited(_openPlanningSurface());
            return;
          case ClassHealthActionType.openExport:
            context.push('/class/${classBrief.id}/export');
            return;
        }
      },
    );
  }

  ClassHealthAction _resolvedSecondaryAction(ClassHealthRecord health) {
    if (health.secondaryAction.type != health.primaryAction.type ||
        health.secondaryAction.label != health.primaryAction.label) {
      return health.secondaryAction;
    }

    switch (health.primaryAction.type) {
      case ClassHealthActionType.openClassWorkspace:
        return const ClassHealthAction(
          label: 'Open classes',
          detail: 'Return to the classes workspace.',
          type: ClassHealthActionType.openClassesWorkspace,
        );
      case ClassHealthActionType.openClassesWorkspace:
        return const ClassHealthAction(
          label: 'Open class',
          detail: 'Jump into the full class workspace.',
          type: ClassHealthActionType.openClassWorkspace,
        );
      case ClassHealthActionType.openGradebook:
        return const ClassHealthAction(
          label: 'Open class',
          detail: 'Review students, notes, and setup around the gradebook.',
          type: ClassHealthActionType.openClassWorkspace,
        );
      case ClassHealthActionType.openSeating:
        return const ClassHealthAction(
          label: 'Open class',
          detail: 'Keep the wider class context visible while editing seats.',
          type: ClassHealthActionType.openClassWorkspace,
        );
      case ClassHealthActionType.openTimetable:
        return const ClassHealthAction(
          label: 'Open class',
          detail: 'Review setup while timetable details are still missing.',
          type: ClassHealthActionType.openClassWorkspace,
        );
      case ClassHealthActionType.reviewPlanning:
        return const ClassHealthAction(
          label: 'Open class',
          detail: 'Keep the class workspace close while handling follow-up.',
          type: ClassHealthActionType.openClassWorkspace,
        );
      case ClassHealthActionType.openExport:
        return const ClassHealthAction(
          label: 'Open gradebook',
          detail: 'Review grade items before the export pass.',
          type: ClassHealthActionType.openGradebook,
        );
    }
  }

  void _focusClass(String classId) {
    _setSelectedDashboardClass(classId);
  }

  void _selectDashboardClassFromRail(String classId) {
    setState(() {
      _selectedClassId = classId;
      _dashboardRailSelectedClassId = classId;
    });
    _refreshNames();
  }

  Future<void> _openPlanningSurface() async {
    if (MediaQuery.sizeOf(context).width <
        TeacherDashboardShell._mobileBreakpoint) {
      setState(() => _mobileDashboardIndex = 1);
      await Future<void>.delayed(const Duration(milliseconds: 260));
    }
    if (!mounted) return;
    await _scrollToSection(_planningSectionKey);
  }

  int _overdueReminderCount(List<_Reminder> reminders, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    return reminders.where((reminder) {
      final date = DateTime(
        reminder.timestamp.year,
        reminder.timestamp.month,
        reminder.timestamp.day,
      );
      return date.isBefore(today);
    }).length;
  }

  int _reminderCountWithin(
    List<_Reminder> reminders,
    DateTime now, {
    required int days,
  }) {
    final today = DateTime(now.year, now.month, now.day);
    final end = today.add(Duration(days: days));
    return reminders.where((reminder) {
      final date = DateTime(
        reminder.timestamp.year,
        reminder.timestamp.month,
        reminder.timestamp.day,
      );
      return !date.isBefore(today) && !date.isAfter(end);
    }).length;
  }

  bool _classHasTimetableContext(_ClassBrief classBrief) {
    if (_selectedTimetableId == null) {
      return false;
    }
    return _selectedTimetableClasses().any(
      (slot) => _classMatchesTimetableLabel(classBrief, slot.title),
    );
  }

  _TimetableSlotMoment? _currentTimetableMomentForClass(
    _ClassBrief classBrief,
    DateTime now,
  ) {
    for (final moment in _timetableMoments(now)) {
      if (_classMatchesTimetableLabel(
              classBrief, moment.timetableClass.title) &&
          !now.isBefore(moment.startAt) &&
          now.isBefore(moment.endAt)) {
        return moment;
      }
    }
    return null;
  }

  _TimetableSlotMoment? _nextTimetableMomentForClass(
    _ClassBrief classBrief,
    DateTime now,
  ) {
    for (final moment in _timetableMoments(now)) {
      if (_classMatchesTimetableLabel(
              classBrief, moment.timetableClass.title) &&
          moment.startAt.isAfter(now)) {
        return moment;
      }
    }
    return null;
  }

  IconData _healthStatusIcon(ClassHealthRecord health) {
    switch (health.primaryAction.type) {
      case ClassHealthActionType.openClassesWorkspace:
        return Icons.group_add_rounded;
      case ClassHealthActionType.reviewPlanning:
        return Icons.event_note_outlined;
      case ClassHealthActionType.openSeating:
        return Icons.event_seat_outlined;
      case ClassHealthActionType.openTimetable:
        return Icons.schedule_rounded;
      case ClassHealthActionType.openGradebook:
        return Icons.grading_outlined;
      case ClassHealthActionType.openExport:
        return Icons.ios_share_rounded;
      case ClassHealthActionType.openClassWorkspace:
        return health.level == ClassHealthLevel.ready
            ? Icons.check_circle_rounded
            : Icons.class_rounded;
    }
  }

  IconData _healthActionIcon(ClassHealthActionType type) {
    switch (type) {
      case ClassHealthActionType.openClassWorkspace:
        return Icons.open_in_new_rounded;
      case ClassHealthActionType.openClassesWorkspace:
        return Icons.upload_file_outlined;
      case ClassHealthActionType.openGradebook:
        return Icons.grading_outlined;
      case ClassHealthActionType.openSeating:
        return Icons.event_seat_outlined;
      case ClassHealthActionType.openTimetable:
        return Icons.schedule_rounded;
      case ClassHealthActionType.reviewPlanning:
        return Icons.event_note_outlined;
      case ClassHealthActionType.openExport:
        return Icons.ios_share_rounded;
    }
  }

  IconData _healthMetricIcon(String label) {
    switch (label) {
      case 'Roster':
        return Icons.people_alt_outlined;
      case 'Timing':
        return Icons.schedule_rounded;
      case 'Follow-up':
        return Icons.flag_outlined;
      case 'Setup':
        return Icons.event_seat_outlined;
      case 'Gradebook':
        return Icons.grading_outlined;
      case 'Planning':
      case 'Context':
        return Icons.event_note_outlined;
      case 'Room':
        return Icons.meeting_room_outlined;
      default:
        return Icons.info_outline_rounded;
    }
  }

  List<DashboardQuickActionData> _dashboardQuickActions(
    BuildContext context,
  ) {
    final selectedClassId = _selectedDashboardActionClassId();
    final selectedName = selectedClassId == null
        ? 'your class'
        : (_classes
                .where((classItem) => classItem.id == selectedClassId)
                .firstOrNull
                ?.name ??
            'your class');
    return [
      DashboardQuickActionData(
        label: 'Add Class',
        detail: 'Create or open a class space.',
        icon: Icons.add_box_outlined,
        accent: _DashboardPalette.accent,
        onTap: () => context.go(AppRoutes.classes),
      ),
      DashboardQuickActionData(
        label: 'Import Roster',
        detail: 'Bring in classes and rosters.',
        icon: Icons.upload_file_outlined,
        accent: _DashboardPalette.green,
        onTap: () => context.go(AppRoutes.classes),
      ),
      DashboardQuickActionData(
        label: 'Seating Plan',
        detail: 'Open seating for $selectedName.',
        icon: Icons.event_seat_outlined,
        accent: _DashboardPalette.cyan,
        onTap: () => _openSelectedClassRoute(context, 'seating'),
      ),
      DashboardQuickActionData(
        label: 'Whiteboard',
        detail: 'Open the teaching whiteboard.',
        icon: Icons.draw_rounded,
        accent: _DashboardPalette.amber,
        onTap: () => context.push(
          AppRoutes.whiteboard,
          extra: _dashboardWhiteboardController,
        ),
      ),
      DashboardQuickActionData(
        label: 'Create Test',
        detail: 'Jump into exam setup.',
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

  DashboardSystemWidgetData _dashboardSystemWidgetData(DateTime now) {
    final currentClass = _currentTimetableClass(now);
    final nextClass = _nextTimetableClass(now);
    final nextReminder = _nextOpenReminder();
    final weather = _weatherSnapshot;
    final schoolName = GradeFlowProductConfig.resolvedSchoolName(
      context.read<AuthService>().currentUser?.schoolName,
    );

    final nextLabel = currentClass != null
        ? 'Now teaching'
        : nextClass != null
            ? 'Next class'
            : nextReminder != null
                ? 'Next reminder'
                : 'Clear';
    final nextDetail = currentClass != null
        ? '${currentClass.timetableClass.title} until ${_formatHourMinute(currentClass.endAt)}'
        : nextClass != null
            ? '${_headlineSafe(nextClass.timetableClass.title, maxLength: 48)} ${_relativeTimetableTime(nextClass.startAt, now)}'
            : nextReminder != null
                ? '${_headlineSafe(nextReminder.text, maxLength: 52)} • ${_shortMonthDay(nextReminder.timestamp)}'
                : 'No urgent blockers in the queue.';

    return DashboardSystemWidgetData(
      timeLabel: _formatTime(now),
      weekdayLabel: _weekdayLabel(now),
      dateLabel: _shortMonthDay(now),
      locationLabel: weather?.locationName ?? schoolName,
      weatherLabel: weather != null
          ? '${weather.temperatureC.round()}°'
          : (_weatherBusy ? '--' : '--'),
      weatherDetail: weather != null
          ? _weatherCodeLabel(weather.weatherCode)
          : (_weatherBusy ? 'Syncing forecast' : 'Forecast pending'),
      weatherIcon: _weatherCodeIcon(weather?.weatherCode ?? 1),
      nextLabel: nextLabel,
      nextDetail: nextDetail,
      liveLabel: RepositoryFactory.sourceOfTruthLabel,
    );
  }

  DashboardAudioWidgetData _dashboardAudioWidgetData(DateTime now) {
    final stations = _dashboardAudioStations();
    final recommendedStationId = _recommendedDashboardAudioStationId(now);
    final recommendedStation = stations.firstWhere(
      (station) => station.id == recommendedStationId,
      orElse: () => stations.first,
    );
    final selectedStation = _selectedAudioStationId == null
        ? null
        : stations
            .where((station) => station.id == _selectedAudioStationId)
            .firstOrNull;

    return DashboardAudioWidgetData(
      activeStation: selectedStation ?? recommendedStation,
      stations: stations,
      recommendedLabel: _recommendedDashboardAudioLabel(recommendedStation),
      isFollowingRecommended: selectedStation == null ||
          selectedStation.id == recommendedStation.id,
      onSelectStation: _selectDashboardAudioStation,
      onUseRecommended: _useRecommendedDashboardAudioStation,
      onAddStation: _promptAddCustomAudioStation,
      onRemoveStation: _removeCustomAudioStation,
    );
  }

  List<DashboardAudioStationData> _dashboardAudioStations() {
    return <DashboardAudioStationData>[
      const DashboardAudioStationData(
        id: 'groove-salad',
        stationName: 'Groove Salad',
        programLabel: 'SomaFM / USA',
        detail:
            'Low-noise ambient and downtempo for arrivals, setup, and first period focus.',
        streamUrl: 'https://ice5.somafm.com/groovesalad-128-mp3',
        stationUrl: 'https://somafm.com/groovesalad/',
        countryLabel: 'USA',
        categoryLabel: 'Ambient',
        icon: Icons.spa_outlined,
        gradientColors: [Color(0xFF2C5B82), Color(0xFF68B7C8)],
      ),
      const DashboardAudioStationData(
        id: 'sonic-universe',
        stationName: 'Sonic Universe',
        programLabel: 'SomaFM / USA',
        detail:
            'Smooth jazz and cosmic groove for planning gaps, marking, and quieter admin blocks.',
        streamUrl: 'https://ice5.somafm.com/sonicuniverse-128-mp3',
        stationUrl: 'https://somafm.com/sonicuniverse/',
        countryLabel: 'USA',
        categoryLabel: 'Jazz',
        icon: Icons.graphic_eq_rounded,
        gradientColors: [Color(0xFF4B347A), Color(0xFFB067C8)],
      ),
      const DashboardAudioStationData(
        id: 'drone-zone',
        stationName: 'Drone Zone',
        programLabel: 'SomaFM / USA',
        detail:
            'A calmer atmospheric stream for wrap-up, exports, and tomorrow planning.',
        streamUrl: 'https://ice5.somafm.com/dronezone-128-mp3',
        stationUrl: 'https://somafm.com/dronezone/',
        countryLabel: 'USA',
        categoryLabel: 'Calm',
        icon: Icons.nightlight_round,
        gradientColors: [Color(0xFF243A73), Color(0xFF4E6FB8)],
      ),
      const DashboardAudioStationData(
        id: 'talksport',
        stationName: 'talkSPORT',
        programLabel: 'Sports radio / United Kingdom',
        detail:
            'Fast-moving football and live sports talk when the room wants energy instead of music.',
        streamUrl: null,
        stationUrl: 'https://talksport.com/live/',
        countryLabel: 'UK',
        categoryLabel: 'Sports Talk',
        icon: Icons.sports_football_rounded,
        gradientColors: [Color(0xFF6C3A1C), Color(0xFFE07B39)],
      ),
      const DashboardAudioStationData(
        id: 'abc-radio-national',
        stationName: 'ABC Radio National',
        programLabel: 'ABC Listen / Australia',
        detail:
            'Documentary, current affairs, and long-form talk for deep work or quieter planning blocks.',
        streamUrl: null,
        stationUrl: 'https://www.abc.net.au/listen/live/radionational',
        countryLabel: 'Australia',
        categoryLabel: 'Talk',
        icon: Icons.mic_external_on_rounded,
        gradientColors: [Color(0xFF194F52), Color(0xFF39A0A4)],
      ),
      const DashboardAudioStationData(
        id: 'france-inter',
        stationName: 'France Inter',
        programLabel: 'Radio France / France',
        detail:
            'A strong international news and conversation option for teachers who prefer global coverage.',
        streamUrl: null,
        stationUrl: 'https://www.radiofrance.fr/franceinter/direct',
        countryLabel: 'France',
        categoryLabel: 'News',
        icon: Icons.public_rounded,
        gradientColors: [Color(0xFF24498E), Color(0xFF5B8CFF)],
      ),
      ..._customAudioStations.map(_dashboardAudioStationFromStored),
    ];
  }

  DashboardAudioStationData _dashboardAudioStationFromStored(
    _StoredDashboardAudioStation station,
  ) {
    final category = station.categoryLabel.trim().toLowerCase();
    final icon = switch (category) {
      'talk' || 'sports talk' || 'sport' => Icons.mic_external_on_rounded,
      'news' => Icons.public_rounded,
      'ambient' || 'calm' || 'focus' => Icons.spa_outlined,
      'jazz' || 'groove' => Icons.graphic_eq_rounded,
      _ => Icons.radio_rounded,
    };

    final gradientColors = switch (category) {
      'talk' || 'sports talk' || 'sport' => const [
          Color(0xFF7A4B22),
          Color(0xFFE38A45)
        ],
      'news' => const [Color(0xFF275086), Color(0xFF6BA4FF)],
      'ambient' || 'calm' || 'focus' => const [
          Color(0xFF2F5A64),
          Color(0xFF6DB8B6)
        ],
      'jazz' || 'groove' => const [Color(0xFF5A3275), Color(0xFFB56FD1)],
      _ => const [Color(0xFF3D465D), Color(0xFF6C7EA8)],
    };

    return DashboardAudioStationData(
      id: station.id,
      stationName: station.stationName,
      programLabel: station.programLabel.trim().isEmpty
          ? 'Custom station'
          : station.programLabel,
      detail: station.detail.trim().isEmpty
          ? 'Teacher-added station for the live dashboard widget.'
          : station.detail,
      streamUrl: station.streamUrl,
      stationUrl: station.stationUrl,
      countryLabel:
          station.countryLabel.trim().isEmpty ? 'Global' : station.countryLabel,
      categoryLabel: station.categoryLabel.trim().isEmpty
          ? 'Radio'
          : station.categoryLabel,
      icon: icon,
      gradientColors: gradientColors,
      isCustom: true,
    );
  }

  String _recommendedDashboardAudioStationId(DateTime now) {
    final hour = now.hour;
    if (hour < 11) {
      return 'groove-salad';
    }
    if (hour < 15) {
      return 'sonic-universe';
    }
    return 'drone-zone';
  }

  String _recommendedDashboardAudioLabel(DashboardAudioStationData station) {
    return 'Recommended now: ${station.stationName}';
  }

  void _selectDashboardAudioStation(String stationId) {
    final normalized = stationId.trim();
    if (normalized.isEmpty || normalized == _selectedAudioStationId) {
      return;
    }

    setState(() {
      _selectedAudioStationId = normalized;
    });
    unawaited(_saveAudioStations());
  }

  void _useRecommendedDashboardAudioStation() {
    if (_selectedAudioStationId == null) {
      return;
    }

    setState(() {
      _selectedAudioStationId = null;
    });
    unawaited(_saveAudioStations());
    _showDashboardFeedback(
      'Audio now follows the recommended station for the time of day.',
      title: 'Dashboard audio',
    );
  }

  Future<void> _promptAddCustomAudioStation() async {
    final formKey = GlobalKey<FormState>();
    final stationCtrl = TextEditingController();
    final sourceCtrl = TextEditingController();
    final detailCtrl = TextEditingController();
    final countryCtrl = TextEditingController();
    final categoryCtrl = TextEditingController();
    final stationUrlCtrl = TextEditingController(text: 'https://');
    final streamUrlCtrl = TextEditingController();

    final added = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add custom station'),
        content: SizedBox(
          width: 520,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: stationCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Station name',
                      hintText: 'e.g. talkSPORT',
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter a station name.'
                        : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: sourceCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Source / program',
                      hintText: 'e.g. Sports radio / United Kingdom',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: detailCtrl,
                    minLines: 2,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      hintText:
                          'What kind of listening does this station work for?',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: countryCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Country',
                            hintText: 'e.g. UK',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: categoryCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Category',
                            hintText: 'e.g. Talk',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: stationUrlCtrl,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'Station page URL',
                      hintText: 'https://station.example/live',
                    ),
                    validator: (value) {
                      final hasStation =
                          value != null && value.trim().isNotEmpty;
                      final hasStream = streamUrlCtrl.text.trim().isNotEmpty;
                      if (!hasStation && !hasStream) {
                        return 'Add a station page or direct stream URL.';
                      }
                      if (hasStation &&
                          _validatedDashboardAudioUrl(value) == null) {
                        return 'Enter a valid URL.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: streamUrlCtrl,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'Direct stream URL (optional)',
                      hintText: 'https://stream.example/live.mp3',
                    ),
                    validator: (value) {
                      final hasStream =
                          value != null && value.trim().isNotEmpty;
                      final hasStation = stationUrlCtrl.text.trim().isNotEmpty;
                      if (!hasStream && !hasStation) {
                        return 'Add a station page or direct stream URL.';
                      }
                      if (hasStream &&
                          _validatedDashboardAudioUrl(value) == null) {
                        return 'Enter a valid stream URL.';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (!(formKey.currentState?.validate() ?? false)) {
                return;
              }
              Navigator.of(dialogContext).pop(true);
            },
            child: const Text('Add station'),
          ),
        ],
      ),
    );

    if (added != true || !mounted) {
      return;
    }

    final streamUrl = streamUrlCtrl.text.trim().isEmpty
        ? null
        : _validatedDashboardAudioUrl(streamUrlCtrl.text.trim());
    final stationUrl = stationUrlCtrl.text.trim().isEmpty
        ? streamUrl
        : _validatedDashboardAudioUrl(stationUrlCtrl.text.trim());
    if (stationUrl == null) {
      return;
    }

    final created = _StoredDashboardAudioStation(
      id: 'custom-audio-${DateTime.now().microsecondsSinceEpoch}',
      stationName: stationCtrl.text.trim(),
      programLabel: sourceCtrl.text.trim(),
      detail: detailCtrl.text.trim(),
      streamUrl: streamUrl,
      stationUrl: stationUrl,
      countryLabel: countryCtrl.text.trim(),
      categoryLabel: categoryCtrl.text.trim(),
    );

    setState(() {
      _customAudioStations.add(created);
      _selectedAudioStationId = created.id;
    });
    await _saveAudioStations();
    if (!mounted) {
      return;
    }
    _showDashboardFeedback(
      '${created.stationName} is ready in your station library.',
      title: 'Dashboard audio',
    );
  }

  String? _validatedDashboardAudioUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final normalized = trimmed.contains('://') ? trimmed : 'https://$trimmed';
    final uri = Uri.tryParse(normalized);
    if (uri == null || uri.host.isEmpty) {
      return null;
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return null;
    }
    return uri.toString();
  }

  Future<void> _removeCustomAudioStation(String stationId) async {
    final station =
        _customAudioStations.where((item) => item.id == stationId).firstOrNull;
    if (station == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove custom station?'),
        content: Text(
          'Remove "${station.stationName}" from your dashboard station library?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _customAudioStations.removeWhere((item) => item.id == stationId);
      if (_selectedAudioStationId == stationId) {
        _selectedAudioStationId = null;
      }
    });
    await _saveAudioStations();
    if (!mounted) {
      return;
    }
    _showDashboardFeedback(
      '${station.stationName} was removed from your station library.',
      title: 'Dashboard audio',
    );
  }

  List<DashboardSystemStatusItemData> _dashboardSystemStatusItems(
      DateTime now) {
    final nextReminder = _nextOpenReminder();
    final attentionCount = _dashboardAttentionCount(now);

    return [
      DashboardSystemStatusItemData(
        label: 'Alerts',
        value: attentionCount > 0 ? '$attentionCount to review' : 'Clear',
        icon: Icons.notifications_active_outlined,
        accent: attentionCount > 0
            ? _DashboardPalette.amber
            : _DashboardPalette.green,
      ),
      DashboardSystemStatusItemData(
        label: 'Sync',
        value: RepositoryFactory.sourceOfTruthLabel,
        icon: RepositoryFactory.isUsingFirestore
            ? Icons.cloud_done_outlined
            : Icons.offline_bolt_outlined,
        accent: RepositoryFactory.isUsingFirestore
            ? _DashboardPalette.accent
            : _DashboardPalette.amber,
      ),
      DashboardSystemStatusItemData(
        label: 'Calendar',
        value: nextReminder != null
            ? _shortMonthDay(nextReminder.timestamp)
            : 'Up to date',
        icon: Icons.event_note_outlined,
        accent: nextReminder != null
            ? _DashboardPalette.cyan
            : _DashboardPalette.green,
      ),
    ];
  }

  DashboardCommunicationWidgetData _dashboardCommunicationWidgetData(
    DateTime now,
  ) {
    final communication = _communicationWorkspaceSnapshot(now);
    final sortedChannels = [...communication.channels]..sort((left, right) {
        final unread = right.unreadCount.compareTo(left.unreadCount);
        if (unread != 0) {
          return unread;
        }
        final rightStamp = right.lastMessageAt?.millisecondsSinceEpoch ?? 0;
        final leftStamp = left.lastMessageAt?.millisecondsSinceEpoch ?? 0;
        final stamp = rightStamp.compareTo(leftStamp);
        if (stamp != 0) {
          return stamp;
        }
        return right.memberCount.compareTo(left.memberCount);
      });

    final activeThreads = sortedChannels
        .where(
          (channel) =>
              channel.unreadCount > 0 ||
              channel.lastMessageAt != null ||
              (channel.lastMessagePreview?.trim().isNotEmpty ?? false),
        )
        .take(3)
        .map(
          (channel) => DashboardCommunicationThreadData(
            title: channel.name,
            preview: _dashboardCommunicationPreview(channel),
            meta: _dashboardCommunicationMeta(channel, now),
            icon: _dashboardCommunicationIcon(channel.kind),
            accent: _dashboardCommunicationAccent(channel.kind),
            unreadCount: channel.unreadCount,
          ),
        )
        .toList(growable: false);

    final activeCount = communication.channels
        .where((channel) => channel.unreadCount > 0)
        .length;
    final liveCount =
        activeCount == 0 && communication.totalUnread > 0 ? 1 : activeCount;
    final headline = communication.totalUnread > 0
        ? '${communication.totalUnread} unread'
        : 'Inbox clear';
    final detail = communication.totalUnread > 0
        ? '$liveCount live thread${liveCount == 1 ? '' : 's'} need attention'
        : 'Staff channels are quiet';

    return DashboardCommunicationWidgetData(
      headline: headline,
      detail: detail,
      unreadCount: communication.totalUnread,
      threads: activeThreads,
      onTap: () => context.go(AppRoutes.communication),
    );
  }

  String _dashboardCommunicationPreview(CommunicationChannelPreview channel) {
    final message = channel.lastMessagePreview?.trim();
    if (message != null && message.isNotEmpty) {
      final author = channel.lastSenderName?.trim();
      if (author != null && author.isNotEmpty) {
        return '$author: $message';
      }
      return message;
    }
    return channel.description;
  }

  String _dashboardCommunicationMeta(
    CommunicationChannelPreview channel,
    DateTime now,
  ) {
    if (channel.unreadCount > 0) {
      return '${channel.unreadCount} new';
    }
    final stamp = channel.lastMessageAt;
    if (stamp != null) {
      final sameDay = stamp.year == now.year &&
          stamp.month == now.month &&
          stamp.day == now.day;
      if (sameDay) {
        return _formatTime(stamp);
      }
      return _shortMonthDay(stamp);
    }
    return '${channel.memberCount} members';
  }

  IconData _dashboardCommunicationIcon(CommunicationChannelKind kind) {
    switch (kind) {
      case CommunicationChannelKind.staffRoom:
        return Icons.forum_outlined;
      case CommunicationChannelKind.department:
        return Icons.school_outlined;
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

  Color _dashboardCommunicationAccent(CommunicationChannelKind kind) {
    switch (kind) {
      case CommunicationChannelKind.staffRoom:
        return _DashboardPalette.accent;
      case CommunicationChannelKind.department:
        return _DashboardPalette.cyan;
      case CommunicationChannelKind.gradeTeam:
        return _DashboardPalette.green;
      case CommunicationChannelKind.direct:
        return _DashboardPalette.amber;
      case CommunicationChannelKind.sharedFiles:
        return _DashboardPalette.purple;
      case CommunicationChannelKind.adminAlerts:
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
                  'Timetable overview',
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

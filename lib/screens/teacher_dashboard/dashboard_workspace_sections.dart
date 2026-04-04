// ignore_for_file: invalid_use_of_protected_member, library_private_types_in_public_api, unused_element

part of '../teacher_dashboard_screen.dart';

enum DashboardWorkspaceSection {
  today,
  classroom,
  planning,
  workspace,
}

extension TeacherDashboardWorkspaceSections on _TeacherDashboardScreenState {
  Future<void> _openDashboardSection(
    DashboardWorkspaceSection section, {
    GlobalKey? focusKey,
  }) async {
    if (_workspaceSection != section) {
      setState(() => _workspaceSection = section);
      await Future<void>.delayed(const Duration(milliseconds: 32));
    }
    if (!mounted) {
      return;
    }
    await _scrollToSection(focusKey ?? _workspaceSectionKey);
  }

  String _workspaceSectionTitle(DashboardWorkspaceSection section) {
    switch (section) {
      case DashboardWorkspaceSection.today:
        return 'Today';
      case DashboardWorkspaceSection.classroom:
        return 'Classroom';
      case DashboardWorkspaceSection.planning:
        return 'Schedule';
      case DashboardWorkspaceSection.workspace:
        return 'Workspace';
    }
  }

  String _workspaceSectionDescription(DashboardWorkspaceSection section) {
    switch (section) {
      case DashboardWorkspaceSection.today:
        return 'Priorities, cues, and next moves.';
      case DashboardWorkspaceSection.classroom:
        return 'Whiteboard, timer, grouping, and live tools.';
      case DashboardWorkspaceSection.planning:
        return 'Calendar, reminders, and timetable.';
      case DashboardWorkspaceSection.workspace:
        return 'Links, research, and extra tools.';
    }
  }

  List<Widget> _buildDashboardSections(
    BuildContext context, {
    required bool isNarrow,
  }) {
    return [
      _buildDashboardCommandDeck(context, isNarrow: isNarrow),
      const SizedBox(height: 16),
      _buildWorkspaceSectionSwitcher(context),
      const SizedBox(height: 12),
      ..._buildActiveWorkspaceSection(context),
    ];
  }

  Widget _buildDashboardCommandDeck(
    BuildContext context, {
    required bool isNarrow,
  }) {
    final user = context.watch<AuthService>().currentUser;
    final teacherName = (user?.fullName.trim().isNotEmpty ?? false)
        ? user!.fullName.trim()
        : 'Teacher';
    final schoolName =
        GradeFlowProductConfig.resolvedSchoolName(user?.schoolName);
    final nextReminder = _nextOpenReminder();
    final nextScheduleItem = _nextUpcomingScheduleItem();
    final now = DateTime.now();
    final currentTimetableClass = _currentTimetableClass(now);
    final nextTimetableClass = _nextTimetableClass(now);

    Widget teacherCard() {
      return _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                      backgroundImage: (user?.photoBase64 != null &&
                              user!.photoBase64!.isNotEmpty)
                          ? MemoryImage(
                              const Base64Decoder().convert(user.photoBase64!),
                            )
                          : null,
                      child: (user?.photoBase64 == null ||
                              (user?.photoBase64?.isEmpty ?? true))
                          ? Text(
                              teacherName[0].toUpperCase(),
                              style: context.textStyles.titleLarge?.withColor(
                                Theme.of(context)
                                    .colorScheme
                                    .onPrimaryContainer,
                              ),
                            )
                          : null,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: InkWell(
                        onTap:
                            _updatingTeacherPhoto ? null : _changeTeacherPhoto,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(context).dividerColor,
                              width: 0.5,
                            ),
                          ),
                          padding: const EdgeInsets.all(6),
                          child: Icon(
                            Icons.camera_alt,
                            size: 18,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome, $teacherName',
                        style: context.textStyles.titleLarge?.semiBold,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      ValueListenableBuilder<DateTime>(
                        valueListenable: _nowNotifier,
                        builder: (context, now, _) => Text(
                          '${_formatDate(now)} • ${_formatTime(now)}',
                          style: context.textStyles.bodySmall?.withColor(
                            Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        schoolName,
                        style: context.textStyles.bodySmall?.withColor(
                          Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: () => context.go(AppRoutes.classes),
                  icon: const Icon(Icons.class_),
                  label: const Text('My classes'),
                ),
                OutlinedButton.icon(
                  onPressed: _openTimetableDialog,
                  icon: Icon(
                    _selectedTimetableId == null
                        ? Icons.upload_file
                        : Icons.table_chart,
                  ),
                  label: Text(
                    _selectedTimetableId == null
                        ? 'Upload timetable'
                        : 'Timetable',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _openDashboardSection(
                    DashboardWorkspaceSection.classroom,
                    focusKey: _classToolsSectionKey,
                  ),
                  icon: const Icon(Icons.widgets_outlined),
                  label: const Text('Classroom tools'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _openDashboardSection(
                    DashboardWorkspaceSection.planning,
                    focusKey: _calendarSectionKey,
                  ),
                  icon: const Icon(Icons.event_note_outlined),
                  label: const Text('Schedule'),
                ),
              ],
            ),
          ],
        ),
      );
    }

    Widget statusCard() {
      final statusRows = <String>[
        RepositoryFactory.sourceOfTruthDescription,
        if (currentTimetableClass != null)
          'Now teaching ${currentTimetableClass.timetableClass.title} until ${_formatHourMinute(currentTimetableClass.endAt)}.',
        if (currentTimetableClass == null && nextTimetableClass != null)
          'Next class ${_relativeTimetableTime(nextTimetableClass.startAt, now)}: ${nextTimetableClass.timetableClass.title}.',
        if (nextReminder != null)
          'Next reminder ${_shortMonthDay(nextReminder.timestamp)}: ${_headlineSafe(nextReminder.text, maxLength: 70)}.',
        if (nextReminder == null && nextScheduleItem?.date != null)
          'Next dated class plan ${_shortMonthDay(nextScheduleItem!.date!)}: ${_headlineSafe(nextScheduleItem.title, maxLength: 70)}.',
      ];

      return _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.space_dashboard_outlined),
                const SizedBox(width: 8),
                Text(
                  'Workspace status',
                  style: context.textStyles.titleLarge?.semiBold,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildMetricChip(context, '${_classes.length} classes'),
                _buildMetricChip(context, '$_totalStudents students'),
                _buildMetricChip(context, RepositoryFactory.sourceOfTruthLabel),
                _buildMetricChip(
                  context,
                  _selectedClassBrief()?.name ?? 'No class selected',
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final row in statusRows.take(3)) ...[
              Text(
                row,
                style: context.textStyles.bodyMedium,
              ),
              const SizedBox(height: 8),
            ],
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _openDashboardSection(
                    DashboardWorkspaceSection.today,
                  ),
                  icon: const Icon(Icons.today_outlined),
                  label: const Text('Daily view'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _openDashboardSection(
                    DashboardWorkspaceSection.workspace,
                    focusKey: _workspaceSectionKey,
                  ),
                  icon: const Icon(Icons.link_outlined),
                  label: const Text('Workspace tools'),
                ),
              ],
            ),
          ],
        ),
      );
    }

    if (isNarrow) {
      return Column(
        children: [
          teacherCard(),
          const SizedBox(height: 12),
          statusCard(),
        ],
      );
    }

    return IntrinsicHeight(
      child: Row(
        children: [
          Expanded(child: teacherCard()),
          const SizedBox(width: 12),
          Expanded(child: statusCard()),
        ],
      ),
    );
  }

  Widget _buildWorkspaceSectionSwitcher(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.view_carousel_outlined),
              const SizedBox(width: 8),
              Text(
                'Teacher workspace',
                style: context.textStyles.titleMedium?.semiBold,
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<DashboardWorkspaceSection>(
              segments: const [
                ButtonSegment(
                  value: DashboardWorkspaceSection.today,
                  icon: Icon(Icons.today_outlined),
                  label: Text('Today'),
                ),
                ButtonSegment(
                  value: DashboardWorkspaceSection.classroom,
                  icon: Icon(Icons.widgets_outlined),
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
              selected: {_workspaceSection},
              onSelectionChanged: (selection) {
                setState(() => _workspaceSection = selection.first);
              },
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _workspaceSectionDescription(_workspaceSection),
            style: context.textStyles.bodySmall?.withColor(
              Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildActiveWorkspaceSection(BuildContext context) {
    switch (_workspaceSection) {
      case DashboardWorkspaceSection.today:
        return [
          _buildTodayFocusCard(context),
          const SizedBox(height: 12),
          _buildReminderSummaryCard(context),
        ];
      case DashboardWorkspaceSection.classroom:
        return [
          KeyedSubtree(
            key: _classToolsSectionKey,
            child: _buildClassToolsSectionCard(context),
          ),
        ];
      case DashboardWorkspaceSection.planning:
        return [
          _buildReminderSummaryCard(context),
          const SizedBox(height: 12),
          KeyedSubtree(
            key: _calendarSectionKey,
            child: _Card(child: _buildCalendar(context)),
          ),
        ];
      case DashboardWorkspaceSection.workspace:
        return [
          KeyedSubtree(
            key: _workspaceSectionKey,
            child: _buildQuickLinksCard(context),
          ),
          const SizedBox(height: 12),
          _buildResearchToolsCard(context),
          const SizedBox(height: 12),
          const PilotFeedbackCard(
            initialArea: 'General pilot',
            initialRoute: '/dashboard',
          ),
        ];
    }
  }

  Widget _buildTodayFocusCard(BuildContext context) {
    final now = DateTime.now();
    final nextReminder = _nextOpenReminder();
    final nextScheduleItem = _nextUpcomingScheduleItem();
    final currentTimetableClass = _currentTimetableClass(now);
    final nextTimetableClass = _nextTimetableClass(now);

    String primaryLine() {
      if (currentTimetableClass != null) {
        return 'Now teaching ${currentTimetableClass.timetableClass.title} until ${_formatHourMinute(currentTimetableClass.endAt)}.';
      }
      if (nextTimetableClass != null) {
        return 'Next class ${_relativeTimetableTime(nextTimetableClass.startAt, now)}: ${nextTimetableClass.timetableClass.title}.';
      }
      if (nextReminder != null) {
        return 'Next reminder ${_shortMonthDay(nextReminder.timestamp)}: ${_headlineSafe(nextReminder.text, maxLength: 72)}.';
      }
      return 'No immediate blockers right now. Add a reminder or calendar note if something needs to stay visible.';
    }

    String secondaryLine() {
      if (nextReminder != null && currentTimetableClass != null) {
        return 'After class, ${_headlineSafe(nextReminder.text, maxLength: 72)} is the next thing waiting.';
      }
      if (nextScheduleItem?.date != null) {
        return 'The next dated class plan lands on ${_shortMonthDay(nextScheduleItem!.date!)}.';
      }
      return 'Your dashboard is set up to keep classroom tools and schedule context one click away.';
    }

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.track_changes_outlined),
              const SizedBox(width: 8),
              Text(
                'Today at a glance',
                style: context.textStyles.titleMedium?.semiBold,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(primaryLine(), style: context.textStyles.titleSmall?.semiBold),
          const SizedBox(height: 8),
          Text(
            secondaryLine(),
            style: context.textStyles.bodyMedium?.withColor(
              Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () => _openDashboardSection(
                  DashboardWorkspaceSection.classroom,
                  focusKey: _classToolsSectionKey,
                ),
                icon: const Icon(Icons.widgets_outlined),
                label: const Text('Open classroom'),
              ),
              OutlinedButton.icon(
                onPressed: () => _openDashboardSection(
                  DashboardWorkspaceSection.planning,
                  focusKey: _calendarSectionKey,
                ),
                icon: const Icon(Icons.event_note_outlined),
                label: const Text('Open schedule'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReminderSummaryCard(BuildContext context) {
    return _Card(
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          leading: const Icon(Icons.event_available_outlined),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _summaryRange == _SummaryRange.week
                    ? "This week's to-dos and reminders"
                    : "This month's to-dos and reminders",
                style: context.textStyles.titleMedium?.semiBold,
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SegmentedButton<_SummaryRange>(
                  segments: const [
                    ButtonSegment(
                      value: _SummaryRange.week,
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Weekly'),
                      ),
                    ),
                    ButtonSegment(
                      value: _SummaryRange.month,
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Monthly'),
                      ),
                    ),
                  ],
                  selected: {_summaryRange},
                  onSelectionChanged: (selection) {
                    setState(() => _summaryRange = selection.first);
                  },
                  style: const ButtonStyle(
                    padding: WidgetStatePropertyAll(
                      EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
            ],
          ),
          subtitle: Builder(
            builder: (context) {
              final list = _periodReminders();
              return Text(
                '${list.length} item${list.length == 1 ? '' : 's'}',
                style: context.textStyles.bodySmall?.withColor(
                  Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              );
            },
          ),
          children: [
            if (_periodReminders().isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'No items in this period yet. Add some from the schedule section below.',
                  style: context.textStyles.bodySmall?.withColor(
                    Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              ..._periodReminders().map(
                (r) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Checkbox(
                    value: r.done,
                    onChanged: (value) {
                      setState(() => r.done = value ?? false);
                      unawaited(_saveReminders());
                    },
                  ),
                  title: Text(
                    r.text,
                    overflow: TextOverflow.ellipsis,
                    style: r.done
                        ? context.textStyles.bodyMedium?.copyWith(
                            decoration: TextDecoration.lineThrough,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          )
                        : context.textStyles.bodyMedium,
                  ),
                  subtitle: Text(
                    '${_weekdayLabel(r.timestamp)} • ${_formatDate(r.timestamp)}${_optionalTimeInline(r.timestamp)}${_scopeLabel(r)}',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () {
                      setState(() => _reminders.remove(r));
                      unawaited(_saveReminders());
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildClassToolsSectionCard(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 620;
    final classPicker = ConstrainedBox(
      constraints: const BoxConstraints(
        maxWidth: 280,
        minWidth: 120,
      ),
      child: DropdownButtonFormField<String>(
        key: ValueKey(_selectedClassId),
        initialValue: _selectedClassId,
        isDense: true,
        decoration: const InputDecoration(
          labelText: 'Class',
          isDense: true,
          border: OutlineInputBorder(),
        ),
        items: _classes
            .map(
              (c) => DropdownMenuItem(
                value: c.id,
                child: Text(c.name),
              ),
            )
            .toList(),
        onChanged: (id) {
          if (id == null) {
            return;
          }
          setState(() => _selectedClassId = id);
          _refreshNames();
        },
      ),
    );

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isCompact)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.widgets_outlined),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Classroom tools',
                        style: context.textStyles.titleMedium?.semiBold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.fullscreen),
                      onPressed: _openPresent,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                classPicker,
              ],
            )
          else
            Row(
              children: [
                const Icon(Icons.widgets_outlined),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Classroom tools',
                    style: context.textStyles.titleMedium?.semiBold,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(child: classPicker),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.fullscreen),
                  onPressed: _openPresent,
                ),
              ],
            ),
          const SizedBox(height: 12),
          if (_selectedClassId != null) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _openSeatingPlan,
                icon: const Icon(Icons.event_seat_outlined),
                label: const Text('Open seating plan'),
              ),
            ),
            const SizedBox(height: 12),
          ],
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (int i = 0; i < _toolTabs.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(_toolTabs[i]),
                      selected: _selectedToolTab == i,
                      onSelected: (_) => setState(() => _selectedToolTab = i),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildClassToolsBody(context),
        ],
      ),
    );
  }

  Widget _buildQuickLinksCard(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.link_outlined),
              const SizedBox(width: 8),
              Text(
                'Quick links',
                style: context.textStyles.titleMedium?.semiBold,
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: _promptEditCustomLinks,
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _LinkPill(
                    label: 'Attendance',
                    icon: Icons.how_to_reg_outlined,
                    onTap: _openAttendancePortal,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _LinkPill(
                    label: 'Google Drive',
                    icon: Icons.drive_folder_upload_outlined,
                    onTap: () => _openExternal('https://drive.google.com/'),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _LinkPill(
                    label: 'ClassroomScreen',
                    icon: Icons.dashboard_customize_outlined,
                    onTap: () => _openExternal('https://classroomscreen.com/'),
                  ),
                ),
                for (int i = 0; i < _customLinks.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _LinkPill(
                      label: _customLinks[i].label,
                      icon: Icons.link,
                      onTap: () => _openExternal(_customLinks[i].url),
                      onLongPress: () => _confirmRemoveCustomLink(i),
                    ),
                  ),
                _AddLinkPill(onTap: _promptAddQuickLink),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResearchToolsCard(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 760;
    final searchFields = <Widget>[
      SizedBox(
        width: isCompact ? double.infinity : 420,
        child: TextField(
          controller: _googleSearchCtrl,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _submitGoogleSearch(),
          decoration: InputDecoration(
            labelText: 'Google Search',
            hintText: 'Type and press Enter',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(
              icon: const Icon(Icons.open_in_new),
              onPressed: _submitGoogleSearch,
            ),
          ),
        ),
      ),
      SizedBox(
        width: isCompact ? double.infinity : 420,
        child: TextField(
          controller: _askAiCtrl,
          textInputAction: TextInputAction.send,
          onSubmitted: (_) => _submitAiSearch(),
          decoration: InputDecoration(
            labelText: 'Ask AI',
            hintText: 'Type your question and press Enter',
            prefixIcon: const Icon(Icons.auto_awesome_outlined),
            suffixIcon: IconButton(
              icon: const Icon(Icons.open_in_new),
              onPressed: _submitAiSearch,
            ),
          ),
        ),
      ),
    ];

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.manage_search_outlined),
              const SizedBox(width: 8),
              Text(
                'Research tools',
                style: context.textStyles.titleMedium?.semiBold,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isCompact)
            Column(
              children: [
                searchFields[0],
                const SizedBox(height: 12),
                searchFields[1],
              ],
            )
          else
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: searchFields,
            ),
        ],
      ),
    );
  }

  Widget _buildMetricChip(BuildContext context, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Text(
        label,
        style: context.textStyles.labelMedium?.semiBold,
      ),
    );
  }
}

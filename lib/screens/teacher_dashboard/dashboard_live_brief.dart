// ignore_for_file: library_private_types_in_public_api, unused_element

part of '../teacher_dashboard_screen.dart';

extension TeacherDashboardLiveBrief on _TeacherDashboardScreenState {
  String _forecastChip(DashboardForecastDay day) {
    return '${_weekdayLabel(day.date)} ${day.maxTempC.round()}°/${day.minTempC.round()}°';
  }

  Future<void> _scrollToSection(GlobalKey key) async {
    final targetContext = key.currentContext;
    if (targetContext == null) return;
    await Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeInOutCubic,
      alignment: 0.08,
    );
  }

  List<DashboardStorySlide> _dashboardStorySlides(BuildContext context) {
    final worldLead =
        _worldNewsStories.isNotEmpty ? _worldNewsStories.first : null;
    final localLead =
        _localNewsStories.isNotEmpty ? _localNewsStories.first : null;
    final leadStory = worldLead ?? localLead;
    final weather = _weatherSnapshot;
    final pendingReminders = _pendingReminders();
    final nextReminder =
        pendingReminders.isNotEmpty ? pendingReminders.first : null;
    final nextSchoolEvent = _nextSchoolWideReminder();
    final nextScheduleItem = _nextUpcomingScheduleItem();
    final openReminders = pendingReminders.length;
    final schoolWideCount = _schoolWideReminders().length;
    final forecast = weather?.forecast ?? const <DashboardForecastDay>[];
    final weatherDetailsUrl = _dashboardWeatherService.detailsUrl(
      locationName: weather?.locationName ??
          GradeFlowProductConfig.dashboardWeatherLocationName,
    );
    final weatherChips = <String>[
      if (forecast.isNotEmpty) _forecastChip(forecast[0]),
      if (forecast.length > 1) _forecastChip(forecast[1]),
      if (forecast.length > 2) _forecastChip(forecast[2]),
    ];
    final eventLead = nextSchoolEvent ?? nextReminder;
    final eventDate = eventLead?.timestamp ?? nextScheduleItem?.date;
    final followUpReminder =
        pendingReminders.length > 1 ? pendingReminders[1] : null;

    return [
      DashboardStorySlide(
        overline: 'World & Local News',
        title: _newsBusy && leadStory == null
            ? 'Loading the live news desk...'
            : leadStory != null
                ? _headlineSafe(leadStory.title, maxLength: 92)
                : 'World and local headlines will appear here as soon as the live feeds respond.',
        description: leadStory != null
            ? [
                if (worldLead != null && localLead != null)
                  'The world desk is live, and the local desk is tracking "${_headlineSafe(localLead.title, maxLength: 84)}".',
                if (worldLead != null && localLead == null)
                  'The world desk is live now with fresh international coverage.',
                if (localLead != null && worldLead == null)
                  'The local desk is live now with campus-relevant headlines.',
                'Use the story buttons below or tap the visual panel to open the full article.',
              ].join(' ')
            : (_newsError != null
                ? 'The news feeds are temporarily unavailable. This panel will keep retrying automatically in the background.'
                : 'This panel blends world coverage with local headlines so the planning hub feels useful the moment it opens.'),
        chips: [
          if (worldLead != null) 'World • ${worldLead.source}',
          if (localLead != null) 'Local • ${localLead.source}',
          if (leadStory != null) _relativeFromNow(leadStory.publishedAt),
          if (leadStory != null && leadStory.commentCount > 0)
            '${leadStory.commentCount} comments',
          if (leadStory != null &&
              leadStory.commentCount == 0 &&
              leadStory.score == 0)
            'Live desk',
          if (leadStory == null && _newsBusy) 'Refreshing',
        ],
        visualLabel: leadStory != null
            ? (leadStory.desk == DashboardNewsDesk.local
                ? 'Local desk'
                : 'World desk')
            : 'Status',
        visualValue: leadStory != null ? leadStory.source : 'Stand by',
        visualCaption: leadStory != null
            ? worldLead != null && localLead != null
                ? 'Primary story opens the world desk. Use the second button for the local desk.'
                : leadStory.score > 0
                    ? '${leadStory.score} upvotes • tap through for the full story'
                    : 'Tap through for the latest coverage from this news desk.'
            : 'Live world and local updates will fill this panel automatically when the feeds return.',
        icon: Icons.public_rounded,
        visual: DashboardStoryVisual.spotlight,
        imageAssetPath: _TeacherDashboardScreenState._worldHeroImageAsset,
        imageUrl: leadStory?.imageUrl ?? localLead?.imageUrl,
        ctaLabel: worldLead != null
            ? 'Open world story'
            : (localLead != null ? 'Open story' : null),
        secondaryCtaLabel:
            worldLead != null && localLead != null ? 'Open local story' : null,
        onTap: worldLead != null
            ? () => _openExternal(worldLead.url)
            : (localLead != null ? () => _openExternal(localLead.url) : null),
        onSecondaryTap: worldLead != null && localLead != null
            ? () => _openExternal(localLead.url)
            : null,
      ),
      DashboardStorySlide(
        overline: 'Weather & Forecast',
        title: weather == null
            ? (_weatherBusy
                ? 'Loading campus weather...'
                : 'Campus forecast is standing by.')
            : '${weather.locationName} is ${weather.temperatureC.round()}° right now with ${_weatherCodeLabel(weather.weatherCode).toLowerCase()}.',
        description: weather == null
            ? (_weatherError != null
                ? 'The local forecast is temporarily unavailable. This panel refreshes automatically, so it should recover on the next pass.'
                : 'Current temperature, feel-like temperature, wind, and the next few days will live here.')
            : 'Feels like ${weather.apparentTempC.round()}°, wind ${weather.windSpeedKph.round()} km/h, with the next few days visible before class starts. Tap through for the fuller forecast.',
        chips: weatherChips.isNotEmpty
            ? weatherChips
            : [
                if (_weatherBusy) 'Refreshing',
                if (!_weatherBusy) 'Forecast pending',
              ],
        visualLabel: weather != null ? 'Current' : 'Forecast',
        visualValue:
            weather != null ? '${weather.temperatureC.round()}°' : '--',
        visualCaption: weather != null
            ? '${_weatherCodeLabel(weather.weatherCode)} • updated ${_relativeFromNow(weather.observedAt)}'
            : 'Open-Meteo forecast for ${GradeFlowProductConfig.dashboardWeatherLocationName} refreshes automatically in the background.',
        icon: _weatherCodeIcon(weather?.weatherCode ?? 1),
        visual: DashboardStoryVisual.campus,
        imageAssetPath: _TeacherDashboardScreenState._weatherHeroImageAsset,
        ctaLabel: 'View full forecast',
        secondaryCtaLabel: 'Refresh',
        onTap: () => _openExternal(weatherDetailsUrl),
        onSecondaryTap: _loadWeatherForecast,
      ),
      DashboardStorySlide(
        overline: 'Upcoming Events',
        title: eventLead != null
            ? _headlineSafe(eventLead.text, maxLength: 86)
            : nextScheduleItem != null
                ? _headlineSafe(nextScheduleItem.title, maxLength: 86)
                : 'Upcoming events and school moments will appear here.',
        description: eventLead != null
            ? [
                'Next up on ${_shortMonthDay(eventLead.timestamp)}${_optionalTimeInline(eventLead.timestamp)} for ${_reminderScopeText(eventLead)}.',
                if (nextSchoolEvent != null &&
                    nextReminder != null &&
                    nextSchoolEvent != nextReminder)
                  'The next school-wide moment is "${_headlineSafe(nextSchoolEvent.text, maxLength: 72)}".',
                if (nextScheduleItem != null && nextScheduleItem.date != null)
                  'Class timeline: ${_shortMonthDay(nextScheduleItem.date!)} ${_headlineSafe(nextScheduleItem.title, maxLength: 64)}.',
              ].join(' ')
            : nextScheduleItem != null && nextScheduleItem.date != null
                ? 'The next dated class timeline item lands on ${_shortMonthDay(nextScheduleItem.date!)}. Open the calendar below to keep the broader school day in view.'
                : 'Use the calendar and reminder tools below to pin personal reminders, school events, and things coming up. This panel will keep the next important item in view.',
        chips: [
          '$openReminders upcoming',
          if (schoolWideCount > 0) '$schoolWideCount school-wide',
          if (nextScheduleItem?.date != null)
            _shortMonthDay(nextScheduleItem!.date!),
          'Calendar',
        ],
        visualLabel: nextSchoolEvent != null
            ? 'School-wide'
            : eventLead != null
                ? _reminderScopeText(eventLead)
                : nextScheduleItem != null
                    ? 'Class timeline'
                    : 'Events',
        visualValue: eventDate != null ? _shortMonthDay(eventDate) : 'Clear',
        visualCaption: followUpReminder != null
            ? 'After that: ${_shortMonthDay(followUpReminder.timestamp)} ${_headlineSafe(followUpReminder.text, maxLength: 62)}'
            : nextScheduleItem != null
                ? _headlineSafe(nextScheduleItem.title, maxLength: 70)
                : 'A clear board gives you room to teach, improvise, and still stay ahead of what is coming up.',
        icon: Icons.event_note_rounded,
        visual: DashboardStoryVisual.studio,
        imageAssetPath: _TeacherDashboardScreenState._eventsHeroImageAsset,
        ctaLabel: 'Open calendar',
        secondaryCtaLabel: nextScheduleItem != null ? 'Class timeline' : null,
        onTap: () => _openDashboardSection(
          DashboardWorkspaceSection.planning,
          focusKey: _calendarSectionKey,
        ),
        onSecondaryTap: nextScheduleItem != null
            ? () => _openDashboardSection(
                  DashboardWorkspaceSection.classroom,
                  focusKey: _classToolsSectionKey,
                )
            : null,
      ),
    ];
  }

  List<String> _liveDashboardHeadlines({DateTime? referenceTime}) {
    final now = referenceTime ?? DateTime.now();
    final items = <String>[];
    final selectedClass = _selectedClassBrief();
    final nextReminder = _nextOpenReminder();
    final nextSchoolEvent = _nextSchoolWideReminder();
    final nextScheduleItem = _nextUpcomingScheduleItem();
    final currentTimetableClass = _currentTimetableClass(now);
    final nextTimetableClass = _nextTimetableClass(now);
    final weather = _weatherSnapshot;

    if (currentTimetableClass != null) {
      final nextLabel = nextTimetableClass != null
          ? ' • next ${_headlineSafe(nextTimetableClass.timetableClass.title, maxLength: 42)} ${_relativeTimetableTime(nextTimetableClass.startAt, now)}'
          : '';
      items.add(
        'Now teaching • ${_headlineSafe(currentTimetableClass.timetableClass.title, maxLength: 54)} until ${_formatHourMinute(currentTimetableClass.endAt)}$nextLabel',
      );
    } else if (nextTimetableClass != null) {
      items.add(
        'Next class • ${_relativeTimetableTime(nextTimetableClass.startAt, now)} • ${_headlineSafe(nextTimetableClass.timetableClass.title, maxLength: 68)}',
      );
    }

    if (_worldNewsStories.isNotEmpty) {
      for (final story in _worldNewsStories.take(2)) {
        items.add(
          'World news • ${story.source} • ${_headlineSafe(story.title)}',
        );
      }
    }

    if (_localNewsStories.isNotEmpty) {
      for (final story in _localNewsStories.take(2)) {
        items.add(
          'Local news • ${story.source} • ${_headlineSafe(story.title)}',
        );
      }
    } else if (_worldNewsStories.isEmpty && _newsBusy) {
      items.add('World news panel is refreshing the latest headlines...');
    } else if (_worldNewsStories.isEmpty && _newsError != null) {
      items.add(
        'World and local news feeds are temporarily offline. Auto-refresh will retry.',
      );
    }

    if (weather != null) {
      final nextDay = weather.forecast.length > 1 ? weather.forecast[1] : null;
      items.add(
        'Weather • ${weather.locationName} ${weather.temperatureC.round()}° • ${_weatherCodeLabel(weather.weatherCode)}${nextDay != null ? ' • ${_weekdayLabel(nextDay.date)} ${nextDay.maxTempC.round()}°/${nextDay.minTempC.round()}°' : ''}',
      );
    } else if (_weatherBusy) {
      items.add(
        'Weather panel is refreshing the current forecast for ${GradeFlowProductConfig.dashboardWeatherLocationName}.',
      );
    } else if (_weatherError != null) {
      items.add(
        'Weather feed is temporarily unavailable. Forecast refresh will retry.',
      );
    }

    if (nextSchoolEvent != null) {
      items.add(
        'School event • ${_shortMonthDay(nextSchoolEvent.timestamp)} • ${_headlineSafe(nextSchoolEvent.text)}',
      );
    }

    if (nextReminder != null) {
      items.add(
        'Coming up • ${_shortMonthDay(nextReminder.timestamp)} • ${_headlineSafe(nextReminder.text)}',
      );
    } else if (nextScheduleItem?.date != null) {
      items.add(
        'Class timeline • ${_shortMonthDay(nextScheduleItem!.date!)} • ${_headlineSafe(nextScheduleItem.title)}',
      );
    } else {
      items.add(
        'Upcoming events • no urgent reminders right now • add messages from the calendar below',
      );
    }

    if (_classes.isNotEmpty || _totalStudents > 0) {
      items.add(
        '${_classes.length} classes live across $_totalStudents students in your teacher OS',
      );
    }

    if (selectedClass != null) {
      items.add(
        'Focused class • ${selectedClass.name} • ready for tools, seating, and schedule work',
      );
    }

    items.add(
      'Quick polls, QR, timers, groups, and reminders are all one jump below the hero rail',
    );
    return items;
  }
}

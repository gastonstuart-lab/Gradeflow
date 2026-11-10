import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gradeflow/nav.dart';
import 'package:gradeflow/config/instructos_design.dart';
import 'package:gradeflow/models/class.dart';
import 'package:gradeflow/services/teacher_workspace_snapshot_service.dart';
import 'package:gradeflow/services/home_weekly_timetable_service.dart';
import 'package:gradeflow/components/home/teacher_home_clock.dart';
import 'package:gradeflow/components/home/teacher_home_presentation.dart';

/// Approved desktop presentation, supplied only with existing Home data/actions.
class ApprovedTeacherHome extends StatelessWidget {
  const ApprovedTeacherHome({
    super.key,
    required this.teacherName,
    required this.schoolName,
    required this.primaryClass,
    required this.classes,
    required this.studentCounts,
    required this.reminders,
    required this.loading,
    required this.remindersAvailable,
    required this.onSelectClass,
    required this.onOpenClassroom,
    required this.onOpenPlanner,
    required this.onOpenGrades,
    required this.onOpenStudents,
    required this.onOpenIedStudio,
    required this.onOpenScience,
    required this.onMoreHomeTools,
    required this.onToggleTheme,
    required this.onAttention,
    required this.onAssistant,
    this.heroGradientColors = const [Color(0xff103553), Color(0xff1a5875), Color(0xff148b88)],
    this.heroBackgroundImage,
    this.onCustomiseHome,
    this.timetable,
    this.onUploadTimetable,
  });

  final String teacherName;
  final String schoolName;
  final Class? primaryClass;
  final List<Class> classes;
  final Map<String, int> studentCounts;
  final List<TeacherWorkspaceReminderSnapshot> reminders;
  final bool loading;
  final bool remindersAvailable;
  final ValueChanged<String> onSelectClass;
  final VoidCallback onOpenClassroom;
  final VoidCallback onOpenPlanner;
  final VoidCallback onOpenGrades;
  final VoidCallback onOpenStudents;
  final VoidCallback onOpenIedStudio;
  final VoidCallback onOpenScience;
  final VoidCallback onMoreHomeTools;
  final VoidCallback onToggleTheme;
  final VoidCallback onAttention;
  final VoidCallback onAssistant;
  final List<Color> heroGradientColors;
  final ImageProvider<Object>? heroBackgroundImage;
  final VoidCallback? onCustomiseHome;
  final HomeWeeklyTimetable? timetable;
  final VoidCallback? onUploadTimetable;

  bool _dark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;
  Color _text(BuildContext context) =>
      _dark(context) ? const Color(0xffeef6ff) : const Color(0xff133c67);
  Color _subtle(BuildContext context) =>
      _dark(context) ? const Color(0xff9fb4c7) : const Color(0xff60758c);
  Color _line(BuildContext context) =>
      _dark(context) ? const Color(0xff29445e) : const Color(0xffdce8f3);

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return TeacherHomePresentation(
      teacherName: teacherName,
      now: now,
      header: _header(context),
      classCard: _classCard(context),
      teachingDay: _teachingDay(context),
      shortcuts: _destinations(context),
      calendar: _calendar(context, now),
      reminders: _reminders(context),
      footer: Text(
        'Your selected class stays in focus as you move between teaching tools.',
        style: TextStyle(fontSize: 12, color: _subtle(context)),
      ),
    );
  }

  Widget _header(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
        color: _dark(context)
            ? const Color(0xff0d1d2c)
            : Colors.white.withValues(alpha: .9),
        child: Row(children: [
          const InstructOSBrandMark(size: 40),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('InstructOS',
                    style: TextStyle(
                        color: _text(context),
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.5)),
                Text(schoolName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: _subtle(context), fontSize: 11)),
              ])),
          IconButton(
              tooltip: 'Attention center',
              onPressed: onAttention,
              icon: const Icon(Icons.notifications_none_rounded)),
          IconButton(
              tooltip: 'Assistant',
              onPressed: onAssistant,
              icon: const Icon(Icons.auto_awesome_outlined)),
          if (MediaQuery.sizeOf(context).width >= 900)
            TextButton.icon(
                onPressed: onMoreHomeTools,
                icon: const Icon(Icons.tune_rounded),
                label: const Text('More Home tools'))
          else
            IconButton(
                tooltip: 'More Home tools',
                onPressed: onMoreHomeTools,
                icon: const Icon(Icons.tune_rounded)),
          IconButton(
              tooltip: 'Toggle theme',
              onPressed: onToggleTheme,
              icon: Icon(_dark(context)
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_rounded)),
          if (MediaQuery.sizeOf(context).width >= 600) ...[
            const SizedBox(width: 12),
            TeacherHomeClock(color: _text(context)),
          ],
        ]),
      );

  void _moveClass(int direction) {
    if (loading || classes.length < 2) return;
    final currentIndex = classes.indexWhere(
      (c) => c.classId == primaryClass?.classId,
    );
    if (currentIndex < 0) return;
    final nextIndex = (currentIndex + direction + classes.length) % classes.length;
    onSelectClass(classes[nextIndex].classId);
  }

  Widget _classCard(BuildContext context) {
    final item = primaryClass;
    final count = item == null ? null : studentCounts[item.classId];
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: heroGradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
              color: Color(0x35234b74), blurRadius: 34, offset: Offset(0, 14))
        ],
        border: Border.all(color: Colors.white.withValues(alpha: .22)),
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragEnd: classes.length < 2 || loading
            ? null
            : (details) {
                final velocity = details.primaryVelocity ?? 0;
                if (velocity < -150) _moveClass(1);
                if (velocity > 150) _moveClass(-1);
              },
        child: Stack(children: [
          if (heroBackgroundImage != null) ...[
            Positioned.fill(
              child: Image(image: heroBackgroundImage!, fit: BoxFit.cover),
            ),
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Color(0xf20b2438),
                      Color(0xd10b2438),
                      Color(0x9c0b2438),
                    ],
                  ),
                ),
              ),
            ),
          ],
        if (heroBackgroundImage == null)
        const Positioned(
            right: -18,
            top: -22,
            child: IgnorePointer(
                child: Opacity(
                    opacity: .15,
                    child: SizedBox(
                        width: 330,
                        height: 250,
                        child: Stack(children: [
                          Positioned(
                              right: 18,
                              top: 16,
                              child: Icon(Icons.eco_rounded,
                                  size: 150, color: Colors.white)),
                          Positioned(
                              right: 130,
                              top: 78,
                              child: Icon(Icons.water_drop_rounded,
                                  size: 88, color: Colors.white)),
                          Positioned(
                              right: 72,
                              top: 138,
                              child: Icon(Icons.hub_rounded,
                                  size: 112, color: Colors.white)),
                        ]))))),
        Padding(
            padding: const EdgeInsets.all(26),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 16,
                    runSpacing: 12,
                    children: [
                      const Text('TEACHER HOME',
                          style: TextStyle(
                              color: Color(0xffaee3e1),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.8)),
                      if (classes.isNotEmpty && !loading)
                        SizedBox(
                            width: 220, child: _classSelector(context, item)),
                      if (onCustomiseHome != null)
                        TextButton.icon(
                          onPressed: onCustomiseHome,
                          icon: const Icon(Icons.palette_outlined, size: 18),
                          label: const Text('Personalise'),
                          style: TextButton.styleFrom(foregroundColor: Colors.white),
                        ),
                    ],
                  )),
              const SizedBox(height: 18),
              Row(children: [
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: Text(
                      loading
                          ? 'Loading your classes…'
                          : item?.className ?? 'No class selected',
                      key: ValueKey('home-class-title-${item?.classId}'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 42,
                        height: 1.05,
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.4,
                      ),
                    ),
                  ),
                ),
                if (classes.length > 1 && !loading) ...[
                  IconButton(
                    tooltip: 'Previous class',
                    onPressed: () => _moveClass(-1),
                    icon: const Icon(Icons.chevron_left_rounded, color: Colors.white),
                  ),
                  Text(
                    '${classes.indexWhere((c) => c.classId == item?.classId) + 1} / ${classes.length}',
                    style: const TextStyle(
                      color: Color(0xffd6e6ef),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Next class',
                    onPressed: () => _moveClass(1),
                    icon: const Icon(Icons.chevron_right_rounded, color: Colors.white),
                  ),
                ],
              ]),
              const SizedBox(height: 9),
              Text(
                  item == null
                      ? 'Choose a class to open the existing classroom.'
                      : '${item.subject} · ${count == null ? 'Student count unavailable' : '$count students'}',
                  style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xffd6e6ef))),
              const SizedBox(height: 20),
              const Text('Ready for class',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                      color: Colors.white)),
              const SizedBox(height: 8),
              const Text(
                  'Open your room map to pick students, check work and enter scores.',
                  style: TextStyle(
                      height: 1.55, fontSize: 15.5, color: Color(0xffe0edf3))),
              const SizedBox(height: 22),
              Text(
                  '${classes.length} active class${classes.length == 1 ? '' : 'es'}',
                  style: const TextStyle(color: Color(0xffd6e6ef))),
              const SizedBox(height: 20),
              Wrap(spacing: 10, runSpacing: 10, children: [
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xff164f72),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 16)),
                  onPressed: loading ? null : onOpenClassroom,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: Text(item == null ? 'Choose class' : 'Open Classroom'),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(
                          color: Colors.white.withValues(alpha: .42)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 16)),
                  onPressed: onOpenPlanner,
                  icon: const Icon(Icons.schedule_rounded),
                  label: const Text('Check Planner'),
                ),
              ]),
            ])),
      ]),
      ),
    );
  }

  Widget _classSelector(BuildContext context, Class? item) =>
      DropdownButtonFormField<String>(
        key: ValueKey('home-class-selector-${item?.classId}'),
        initialValue: classes.any((c) => c.classId == item?.classId)
            ? item?.classId
            : null,
        isExpanded: true,
        dropdownColor: const Color(0xff103553),
        iconEnabledColor: const Color(0xffd6e6ef),
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: const InputDecoration(
          labelText: 'Selected class',
          filled: true,
          fillColor: Color(0xff123f57),
          labelStyle: TextStyle(color: Color(0xffd6e6ef)),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          isDense: true,
          border: OutlineInputBorder(),
        ),
        items: [
          for (final c in classes)
            DropdownMenuItem(
                value: c.classId,
                child: Text(c.className, overflow: TextOverflow.ellipsis))
        ],
        onChanged: (value) {
          if (value != null) onSelectClass(value);
        },
      );


  Widget _teachingDay(BuildContext context) => TeacherHomeCard(
        title: 'Teaching day',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (timetable == null) ...[
              Text(
                'Upload a weekly timetable to see what is happening now, next and following.',
                style: TextStyle(color: _subtle(context), fontSize: 13),
              ),
              const SizedBox(height: 12),
              if (onUploadTimetable != null)
                OutlinedButton.icon(
                  onPressed: onUploadTimetable,
                  icon: const Icon(Icons.upload_file_rounded),
                  label: const Text('Upload timetable'),
                ),
            ] else ...[
              Row(children: [
                Expanded(
                  child: Text(
                    timetable!.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _subtle(context),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                if (onUploadTimetable != null)
                  TextButton.icon(
                    onPressed: onUploadTimetable,
                    icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                    label: const Text('Replace'),
                  ),
              ]),
              const SizedBox(height: 12),
              StreamBuilder<DateTime>(
                stream: Stream<DateTime>.periodic(
                  const Duration(minutes: 1),
                  (_) => DateTime.now(),
                ),
                initialData: DateTime.now(),
                builder: (context, snapshot) {
                  final now = snapshot.data ?? DateTime.now();
                  final sequence = HomeTeachingSequence.fromSchedule(
                    timetable!.classes,
                    now,
                  );
                  return LayoutBuilder(builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 570
                        ? 3
                        : constraints.maxWidth >= 340
                            ? 2
                            : 1;
                    final width =
                        (constraints.maxWidth - (columns - 1) * 10) / columns;
                    return Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _teachingMomentCard(context, 'Now', sequence.current,
                            width, now),
                        _teachingMomentCard(context, 'Next', sequence.next,
                            width, now),
                        _teachingMomentCard(context, 'Following',
                            sequence.following, width, now),
                      ],
                    );
                  });
                },
              ),
              const SizedBox(height: 8),
              Text(
                'Timetable labels are suggestions; your chosen class remains selected until you change it.',
                style: TextStyle(color: _subtle(context), fontSize: 11),
              ),
            ],
          ],
        ),
      );

  Widget _teachingMomentCard(
    BuildContext context,
    String label,
    HomeTeachingMoment? moment,
    double width,
    DateTime now,
  ) {
    final isNow = label == 'Now' && moment != null;
    final bg = _dark(context)
        ? const Color(0xff14283a)
        : const Color(0xfff2f7fc);
    final day = moment?.startAt;
    final sameDay = day != null &&
        day.year == now.year &&
        day.month == now.month &&
        day.day == now.day;
    String time(DateTime value) =>
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
    final when = moment == null
        ? (label == 'Now' ? 'Free period' : 'Nothing scheduled')
        : '${sameDay ? 'Today' : const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][day.weekday - 1]} ${time(moment.startAt)}–${time(moment.endAt)}';
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isNow
                ? const Color(0xff0f9588)
                : (_dark(context)
                    ? const Color(0xff2b4b5f)
                    : const Color(0xffdce8f3)),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(),
                style: TextStyle(
                  color: isNow ? const Color(0xff0f9588) : _subtle(context),
                  fontWeight: FontWeight.w800,
                  fontSize: 10,
                  letterSpacing: 1,
                )),
            const SizedBox(height: 5),
            Text(
              moment?.title ?? (label == 'Now' ? 'Not teaching' : '—'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _text(context),
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              when,
              style: TextStyle(color: _subtle(context), fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _destinations(BuildContext context) => TeacherHomeCard(
      title: 'Within reach',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Where do you want to go?',
            style: TextStyle(color: _subtle(context), fontSize: 11.5)),
        const SizedBox(height: 10),
        LayoutBuilder(builder: (context, size) {
          final actions = [
            _quickTool(context, Icons.menu_book_rounded, 'Grades',
                'Open class Gradebook', loading ? null : onOpenGrades),
            _quickTool(context, Icons.people_alt_rounded, 'Students',
                'Open student records', loading ? null : onOpenStudents),
            _quickTool(context, Icons.calendar_month_rounded, 'Planner',
                'Your planning workspace', onOpenPlanner),
            _quickTool(context, Icons.meeting_room_rounded, 'Classroom',
                'Open the selected class', loading ? null : onOpenClassroom),
            _quickTool(context, Icons.open_in_new_rounded, 'IED Studio',
                'Open external resource', onOpenIedStudio),
            _quickTool(context, Icons.open_in_new_rounded, 'Science',
                'Open external resource', onOpenScience),
          ];
          final columns = size.maxWidth < 520
              ? 1
              : size.maxWidth >= 590
                  ? 3
                  : 2;
          return Wrap(spacing: 10, runSpacing: 10, children: [
            for (final action in actions)
              SizedBox(
                  width: (size.maxWidth - 10 * (columns - 1)) / columns,
                  child: action)
          ]);
        }),
      ]));

  Widget _quickTool(BuildContext context, IconData icon, String title,
          String subtitle, VoidCallback? onTap) =>
      Material(
        color:
            _dark(context) ? const Color(0xff122536) : const Color(0xfff6f9fc),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _line(context))),
              child: Row(children: [
                Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [Color(0xff1769ce), Color(0xff168c8a)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight),
                        borderRadius: BorderRadius.circular(14)),
                    child: Icon(icon, color: Colors.white, size: 20)),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(title,
                          style: TextStyle(
                              color: _text(context),
                              fontWeight: FontWeight.w800,
                              fontSize: 14)),
                      const SizedBox(height: 3),
                      Text(subtitle,
                          style: TextStyle(
                              color: _subtle(context),
                              fontSize: 11.5,
                              height: 1.25))
                    ])),
                const Icon(Icons.arrow_forward_rounded,
                    color: Color(0xff7690a8), size: 17),
              ]),
            )),
      );

  Widget _calendar(BuildContext context, DateTime now) {
    final start = DateTime(now.year, now.month);
    final count = DateTime(now.year, now.month + 1, 0).day;
    final offset = start.weekday - 1;
    final total = ((offset + count) / 7).ceil() * 7;
    return TeacherHomeCard(
        title: 'Calendar',
        child: Column(children: [
          Row(children: [
            const SizedBox(width: 44),
            Expanded(
                child: Text('${_months[now.month - 1]} ${now.year}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: _text(context), fontWeight: FontWeight.w600))),
            IconButton(
                tooltip: 'Open Planner',
                onPressed: onOpenPlanner,
                icon: const Icon(Icons.open_in_new, size: 18))
          ]),
          Row(children: [
            for (final day in ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
              Expanded(
                  child: Text(day,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _subtle(context), fontSize: 12)))
          ]),
          const SizedBox(height: 8),
          for (var row = 0; row < total ~/ 7; row++)
            Row(children: [
              for (var col = 0; col < 7; col++)
                Expanded(
                    child: _day(
                        context, row * 7 + col - offset + 1, count, now.day))
            ]),
          const SizedBox(height: 12),
          Text('Open Planner for events and reminders',
              textAlign: TextAlign.center,
              style: TextStyle(color: _subtle(context), fontSize: 11.5)),
        ]));
  }

  Widget _day(BuildContext context, int day, int count, int today) {
    if (day < 1 || day > count) return const SizedBox(height: 40);
    final now = DateTime.now();
    final date =
        DateTime(now.year, now.month, day).toIso8601String().split('T').first;
    return Semantics(
        key: ValueKey('home-planner-date-$date'),
        label: 'Open Planner for $date',
        button: true,
        child: Material(
            color: day == today
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => context.go('${AppRoutes.osPlanner}?date=$date'),
                child: SizedBox(
                    height: 44,
                    child: Center(
                        child: Text('$day',
                            style: TextStyle(
                                color: day == today
                                    ? Theme.of(context).colorScheme.onPrimary
                                    : _text(context))))))));
  }

  Widget _reminders(BuildContext context) => TeacherHomeCard(
      title: 'Things to remember',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (loading)
          const Text('Loading reminders…')
        else if (!remindersAvailable)
          const Text('Reminders unavailable')
        else if (reminders.isEmpty)
          const Text('No pending reminders loaded')
        else
          for (final reminder in reminders)
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.notes_outlined, size: 20),
                      const SizedBox(width: 12),
                      Expanded(child: Text(reminder.text))
                    ])),
        const SizedBox(height: 12),
        Text('Manage your reminders in Planner.',
            style: TextStyle(color: _subtle(context), fontSize: 13)),
        const SizedBox(height: 10),
        Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
                onPressed: onOpenPlanner,
                icon: const Icon(Icons.arrow_forward_rounded, size: 17),
                label: const Text('Open Planner'))),
      ]));
}

const _months = [
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
  'December'
];

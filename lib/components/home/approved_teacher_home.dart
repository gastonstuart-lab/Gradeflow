import 'package:flutter/material.dart';
import 'package:gradeflow/models/class.dart';
import 'package:gradeflow/services/teacher_workspace_snapshot_service.dart';
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
      dayPlan: _dayPlan(context),
      classCard: _classCard(context),
      shortcuts: _destinations(context),
      calendar: _calendar(context, now),
      reminders: _reminders(context),
      footer: Text(
        'Calendar shows the local date · Timetable and lesson continuation are not connected to Home',
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
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xff1769ce), Color(0xff158d8a)]),
              borderRadius: BorderRadius.circular(13),
            ),
            child:
                const Icon(Icons.layers_rounded, color: Colors.white, size: 23),
          ),
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

  Widget _dayPlan(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: _dark(context)
              ? const Color(0xff0d1d2c)
              : Colors.white.withValues(alpha: .9),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _line(context)),
          boxShadow: [
            BoxShadow(
                color: _dark(context)
                    ? Colors.black.withValues(alpha: .20)
                    : const Color(0x0c284d78),
                blurRadius: 20,
                offset: const Offset(0, 7))
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.calendar_view_day_rounded,
                size: 18, color: Color(0xff148c8a)),
            const SizedBox(width: 8),
            Text('Day plan',
                style: TextStyle(
                    color: _text(context),
                    fontWeight: FontWeight.w900,
                    fontSize: 15))
          ]),
          const SizedBox(height: 10),
          LayoutBuilder(builder: (context, size) {
            final items = [
              _planTile(
                  context,
                  'Selected class',
                  loading
                      ? 'Loading teaching context…'
                      : primaryClass?.className ?? 'No class selected',
                  'Your selected teaching class',
                  active: true),
              _planTile(context, 'Timetable', 'Unavailable on Home',
                  'No timetable connected to Home'),
              _planTile(context, 'Next lesson', 'Unavailable on Home',
                  'No next-class timing connected'),
            ];
            if (size.maxWidth < 760) {
              return Column(children: [
                for (var i = 0; i < items.length; i++) ...[
                  items[i],
                  if (i < items.length - 1) const SizedBox(height: 8)
                ]
              ]);
            }
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (var i = 0; i < items.length; i++) ...[
                Expanded(child: items[i]),
                if (i < items.length - 1) const SizedBox(width: 8)
              ]
            ]);
          }),
        ]),
      );

  Widget _planTile(
          BuildContext context, String label, String title, String detail,
          {bool active = false}) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: _dark(context)
              ? (active ? const Color(0xff102f4c) : const Color(0xff122536))
              : (active ? const Color(0xffedf6ff) : const Color(0xfff7f9fc)),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: active ? const Color(0xffbed9f3) : _line(context)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: TextStyle(
                  color: active ? const Color(0xff4da3ff) : _subtle(context),
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  letterSpacing: -.25)),
          const SizedBox(height: 7),
          Text(title,
              style: TextStyle(
                  color: _text(context),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(detail,
              style: TextStyle(
                  color: _subtle(context), fontSize: 10.5, height: 1.25)),
        ]),
      );

  Widget _classCard(BuildContext context) {
    final item = primaryClass;
    final count = item == null ? null : studentCounts[item.classId];
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xff103553), Color(0xff1a5875), Color(0xff148b88)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
              color: Color(0x35234b74), blurRadius: 34, offset: Offset(0, 14))
        ],
        border: Border.all(color: const Color(0xff3a8093)),
      ),
      child: Stack(children: [
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
            padding: const EdgeInsets.all(34),
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
                    ],
                  )),
              const SizedBox(height: 18),
              Text(
                  loading
                      ? 'Loading your classes…'
                      : item?.className ?? 'No class selected',
                  style: const TextStyle(
                      fontSize: 48,
                      height: 1,
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.4)),
              const SizedBox(height: 9),
              Text(
                  item == null
                      ? 'Choose a class to open the existing classroom.'
                      : '${item.subject} · ${count == null ? 'Student count unavailable' : '$count students'}',
                  style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xffd6e6ef))),
              const SizedBox(height: 28),
              const Text('Lesson continuation',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                      color: Colors.white)),
              const SizedBox(height: 8),
              const Text(
                  'Not connected on Home. Open Classroom to use the existing teaching workspace.',
                  style: TextStyle(
                      height: 1.55, fontSize: 15.5, color: Color(0xffe0edf3))),
              const SizedBox(height: 22),
              Text(
                  '${classes.length} active class${classes.length == 1 ? '' : 'es'}',
                  style: const TextStyle(color: Color(0xffd6e6ef))),
              const SizedBox(height: 30),
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
            _quickTool(context, Icons.hub_rounded, 'IED Studio',
                'Open connected destination', onOpenIedStudio),
            _quickTool(context, Icons.science_rounded, 'Science',
                'Open connected destination', onOpenScience),
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
            const IconButton(onPressed: null, icon: Icon(Icons.chevron_left)),
            Expanded(
                child: Text('${_months[now.month - 1]} ${now.year}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: _text(context), fontWeight: FontWeight.w600))),
            const IconButton(onPressed: null, icon: Icon(Icons.chevron_right))
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
          Text('Local date only · No calendar synchronization',
              textAlign: TextAlign.center,
              style: TextStyle(color: _subtle(context), fontSize: 11.5)),
        ]));
  }

  Widget _day(BuildContext context, int day, int count, int today) {
    if (day < 1 || day > count) return const SizedBox(height: 40);
    return Container(
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
            color: day == today ? const Color(0xff1769ce) : null,
            borderRadius: BorderRadius.circular(999)),
        child: Text('$day',
            style: TextStyle(
                color: day == today ? Colors.white : _text(context))));
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
                      const Icon(Icons.check_box_outline_blank, size: 20),
                      const SizedBox(width: 12),
                      Expanded(child: Text(reminder.text))
                    ])),
        const SizedBox(height: 12),
        InputDecorator(
            decoration: const InputDecoration(
                border: OutlineInputBorder(),
                enabled: false,
                prefixIcon: Icon(Icons.lock_outline_rounded)),
            child: Text('Reminder editing is unavailable on Home',
                style: TextStyle(color: _subtle(context), fontSize: 12))),
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

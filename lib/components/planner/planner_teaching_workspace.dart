import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gradeflow/components/time_slot_timetable.dart';
import 'package:gradeflow/models/class.dart' as school;
import 'package:gradeflow/nav.dart';
import 'package:gradeflow/services/home_weekly_timetable_service.dart';

String plannerClock(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

class PlannerLunch {
  const PlannerLunch(this.start, this.end);
  final int start;
  final int end;
}

/// Visual grouping retains the original immutable period objects.
List<List<TimeSlotClass>> plannerLessonBlocks(
    List<TimeSlotClass> lessons, bool combine) {
  final sorted = [...lessons]..sort((a, b) => a.dayOfWeek != b.dayOfWeek
      ? a.dayOfWeek.compareTo(b.dayOfWeek)
      : a.startMinutes.compareTo(b.startMinutes));
  final blocks = <List<TimeSlotClass>>[];
  for (final lesson in sorted) {
    final previous = blocks.isEmpty ? null : blocks.last.last;
    if (combine &&
        previous != null &&
        previous.dayOfWeek == lesson.dayOfWeek &&
        previous.classId != null &&
        previous.classId == lesson.classId &&
        previous.title == lesson.title &&
        previous.room == lesson.room &&
        lesson.startMinutes >= previous.endMinutes &&
        lesson.startMinutes - previous.endMinutes <= 15) {
      blocks.last.add(lesson);
    } else {
      blocks.add([lesson]);
    }
  }
  return blocks;
}

class PlannerTeachingWorkspace extends StatefulWidget {
  const PlannerTeachingWorkspace(
      {super.key,
      required this.lessons,
      required this.classes,
      required this.date,
      required this.todayView,
      required this.onSelectDate,
      this.lunch,
      this.periods = const [],
      this.now,
      required this.onUpload,
      required this.onManage});
  final List<TimeSlotClass> lessons;
  final List<school.Class> classes;
  final DateTime date;
  final bool todayView;
  final ValueChanged<DateTime> onSelectDate;
  final PlannerLunch? lunch;
  final List<({int start, int end})> periods;
  final DateTime? now;
  final VoidCallback onUpload;
  final VoidCallback onManage;
  @override
  State<PlannerTeachingWorkspace> createState() =>
      _PlannerTeachingWorkspaceState();
}

class _PlannerTeachingWorkspaceState extends State<PlannerTeachingWorkspace> {
  bool compact = false;
  bool combine = true;
  List<TimeSlotClass>? selected;

  @override
  void didUpdateWidget(covariant PlannerTeachingWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lessons != widget.lessons ||
        oldWidget.date != widget.date ||
        oldWidget.todayView != widget.todayView) selected = null;
  }

  Color _color(TimeSlotClass lesson) {
    final subject = widget.classes
            .where((c) => c.classId == lesson.classId)
            .firstOrNull
            ?.subject ??
        lesson.title;
    final value = subject.toLowerCase();
    if (value.contains('science') || value.startsWith('sci'))
      return const Color(0xff23815a);
    if (value.contains('performance') ||
        value.startsWith('pa ') ||
        value == 'pa') return const Color(0xffb9652c);
    if (value.contains('eep')) return const Color(0xff306dc5);
    return Theme.of(context).colorScheme.primary;
  }

  Widget _lesson(List<TimeSlotClass> block, {bool next = false, bool current = false}) {
    final lesson = block.first;
    final color = _color(lesson);
    final active = selected?.first == lesson;
    final tight = compact || (!widget.todayView && MediaQuery.sizeOf(context).height <= 1000 && block.length == 1);
    return Semantics(
        button: true,
        label:
            '${lesson.title}, ${plannerClock(lesson.startMinutes)} to ${plannerClock(block.last.endMinutes)}',
        child: Padding(
            padding: const EdgeInsets.all(3),
            child: Material(
                key: ValueKey(
                    'planner-lesson-${lesson.dayOfWeek}-${lesson.startMinutes}'),
                color: color.withValues(
                    alpha: Theme.of(context).brightness == Brightness.dark
                        ? .25
                        : .10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                        color: active ? color : color.withValues(alpha: .35),
                        width: active ? 2 : 1)),
                child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _openLessonDetails(block),
                    child: Padding(
                        padding: EdgeInsets.all(tight ? 6 : 10),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (current)
                                Text('In class now',
                                    style: TextStyle(
                                        color: color,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        height: 1.15))
                              else if (next)
                                Text('Next lesson',
                                    style: TextStyle(
                                        color: color,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        height: 1.15)),
                              Text(lesson.title,
                                  maxLines: tight ? 1 : 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: tight ? 12 : 13,
                                      height: 1.15)),
                              Text(
                                  '${plannerClock(lesson.startMinutes)}–${plannerClock(block.last.endMinutes)}',
                                  style: const TextStyle(
                                      fontSize: 12, height: 1.1)),
                              if (block.length > 1)
                                Text('${block.length} periods',
                                    style:
                                        Theme.of(context).textTheme.labelSmall),
                            ]))))));
  }

  Future<void> _openLessonDetails(List<TimeSlotClass> block) async {
    if (!mounted) return;
    setState(() => selected = block);
    try {
      await showGeneralDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Close lesson details',
        barrierColor: Colors.black.withValues(alpha: .28),
        transitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (sheetContext, animation, secondaryAnimation) {
          final size = MediaQuery.sizeOf(sheetContext);
          // Fixed, touch-friendly details width: preserve the week behind it.
          final panelWidth = size.width < 640
              ? size.width * .94
              : size.width < 1100
                  ? 380.0
                  : 420.0;
          return Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: panelWidth,
              height: size.height,
              child: SafeArea(
                child: Material(
                  elevation: 16,
                  color: Theme.of(sheetContext).colorScheme.surface,
                  borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(20)),
                  clipBehavior: Clip.antiAlias,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: _details(sheetContext, block),
                  ),
                ),
              ),
            ),
          );
        },
        transitionBuilder: (context, animation, secondaryAnimation, child) =>
            SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1, 0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            ),
      );
    } finally {
      if (mounted) setState(() => selected = null);
    }
  }

  Widget _details(BuildContext sheetContext, List<TimeSlotClass> block) {
    final lesson = block.first;
    final linked = widget.classes
        .where((c) => c.classId == lesson.classId && !c.isArchived)
        .firstOrNull;
    return Card(
        margin: const EdgeInsets.only(top: 12),
        child: Padding(
            padding: const EdgeInsets.all(18),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                    child: Text(lesson.title,
                        style: Theme.of(context).textTheme.titleMedium)),
                IconButton(
                    tooltip: 'Close lesson details',
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    icon: const Icon(Icons.close))
              ]),
              for (final period in block)
                Text(
                    '${plannerClock(period.startMinutes)}–${plannerClock(period.endMinutes)}'),
              if (lesson.room != null) Text('Room ${lesson.room}'),
              if (linked == null)
                const Text(
                    'Confirm this lesson’s class in timetable import to open class tools.')
              else
                Wrap(spacing: 10, runSpacing: 8, children: [
                  FilledButton.icon(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        context.go(AppRoutes.osClassroom(linked.classId));
                      },
                      icon: const Icon(Icons.chair_outlined),
                      label: const Text('Classroom')),
                  OutlinedButton(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        context.go(AppRoutes.osClassGradebook(linked.classId));
                      },
                      child: const Text('Gradebook')),
                  OutlinedButton(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        context.go(AppRoutes.osClassWorkspace(linked.classId));
                      },
                      child: const Text('Class information')),
                ]),
            ])));
  }

  @override
  Widget build(BuildContext context) {
    final now = widget.now ?? DateTime.now();
    final blocks = plannerLessonBlocks(widget.lessons, combine);
    final daily = blocks
        .where((b) => b.first.dayOfWeek == widget.date.weekday - 1)
        .toList();
    final sameDay = DateUtils.isSameDay(widget.date, now);
    // A visually grouped double lesson still has separate teaching periods.
    // The interval between periods must not appear as active class time.
    DateTime atMinute(int minute) => DateTime(widget.date.year,
        widget.date.month, widget.date.day, minute ~/ 60, minute % 60);
    final current = sameDay
        ? daily
            .where((b) => b.any((period) =>
                !now.isBefore(atMinute(period.startMinutes)) &&
                now.isBefore(atMinute(period.endMinutes))))
            .firstOrNull
        : null;
    final next = daily
        .where((b) => b.any((period) =>
            !atMinute(period.startMinutes).isBefore(now)))
        .firstOrNull;
    final timeline = [
      ...widget.lessons.map((l) => (start: l.startMinutes, end: l.endMinutes)),
      ...widget.periods
    ];
    final start = timeline.isEmpty
        ? 0
        : timeline.map((l) => l.start).reduce((a, b) => a < b ? a : b);
    final end = timeline.isEmpty
        ? 0
        : timeline.map((l) => l.end).reduce((a, b) => a > b ? a : b);
    final duration = (end - start).clamp(1, 1440).toDouble();
    final availableGridHeight =
        (MediaQuery.sizeOf(context).height - 230).clamp(500.0, 800.0).toDouble();
    final scale = compact
        ? 1.0
        : (availableGridHeight / duration).clamp(1.0, 1.45).toDouble();
    final monday = DateUtils.dateOnly(widget.date)
        .subtract(Duration(days: widget.date.weekday - 1));
    final content = <Widget>[
      Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(widget.todayView ? 'Teaching today' : 'Weekly timetable',
                style: Theme.of(context).textTheme.headlineSmall),
            Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilterChip(
                      label: const Text('Compact'),
                      selected: compact,
                      onSelected: (v) => setState(() => compact = v)),
                  FilterChip(
                      label: const Text('Group doubles'),
                      selected: combine,
                      onSelected: (v) => setState(() {
                            combine = v;
                            selected = null;
                          })),
                  OutlinedButton(
                      onPressed: widget.onUpload,
                      child: const Text('Import timetable')),
                  TextButton(
                      onPressed: widget.onManage,
                      child: const Text('Versions')),
                ]),
          ]),
      const SizedBox(height: 8),
      const Wrap(spacing: 18, children: [
        Text('● EEP', style: TextStyle(color: Color(0xff306dc5))),
        Text('● Science', style: TextStyle(color: Color(0xff23815a))),
        Text('● Performance Arts', style: TextStyle(color: Color(0xffb9652c)))
      ]),
      const SizedBox(height: 12),
      if (widget.lessons.isEmpty)
        const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
                'Import and confirm a timetable to see your teaching periods here.'))
      else if (widget.todayView) ...[
        Text('${widget.date.day}/${widget.date.month}/${widget.date.year}',
            style: Theme.of(context).textTheme.titleMedium),
        if (sameDay && next == null && widget.lessons.isNotEmpty)
          Builder(builder: (context) {
            final upcoming =
                HomeTeachingSequence.fromSchedule(widget.lessons, now).next;
            if (upcoming == null) return const SizedBox.shrink();
            return TextButton(
                onPressed: () => widget.onSelectDate(upcoming.startAt),
                child: Text(
                    'Next scheduled: ${upcoming.title} · ${upcoming.startAt.day}/${upcoming.startAt.month} ${plannerClock(upcoming.startAt.hour * 60 + upcoming.startAt.minute)}'));
          }),
        if (daily.isEmpty)
          const Text('No teaching periods scheduled for this day.'),
        for (final block in daily)
          _lesson(block, next: sameDay && block == next,
              current: sameDay && block == current),
      ] else
        LayoutBuilder(builder: (context, constraints) {
          final width =
              constraints.maxWidth < 800 ? 800.0 : constraints.maxWidth;
          final height = (end - start) * scale + 32;
          final ticks = timeline.map((l) => l.start).toSet().toList()..sort();
          return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                  width: width,
                  child: Column(children: [
                    Row(children: [
                      const SizedBox(width: 70),
                      for (var day = 0; day < 5; day++)
                        Expanded(
                            child: TextButton(
                                onPressed: () => widget.onSelectDate(
                                    monday.add(Duration(days: day))),
                                child: Text('${const [
                                  'Mon',
                                  'Tue',
                                  'Wed',
                                  'Thu',
                                  'Fri'
                                ][day]} ${monday.add(Duration(days: day)).day}')))
                    ]),
                    SizedBox(
                        height: height,
                        child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                  width: 70,
                                  child: Stack(children: [
                                    for (final tick in ticks)
                                      Positioned(
                                          top: (tick - start) * scale,
                                          child: Text(plannerClock(tick),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .labelMedium))
                                  ])),
                              for (var day = 0; day < 5; day++)
                                Expanded(
                                    child: DecoratedBox(
                                        decoration: BoxDecoration(
                                            border: Border(
                                                left: BorderSide(
                                                    color: Theme.of(context)
                                                        .dividerColor
                                                        .withValues(
                                                            alpha: .3)))),
                                        child: SizedBox(
                                            height: height,
                                            child: Stack(children: [
                                              if (widget.lunch != null)
                                                Positioned(
                                                    top: (widget.lunch!.start -
                                                            start) *
                                                        scale,
                                                    left: 4,
                                                    right: 4,
                                                    height: (widget.lunch!.end -
                                                            widget
                                                                .lunch!.start) *
                                                        scale,
                                                    child: Center(
                                                        child: Text(
                                                            'Lunch\n${plannerClock(widget.lunch!.start)}–${plannerClock(widget.lunch!.end)}',
                                                            textAlign: TextAlign
                                                                .center,
                                                            style: Theme.of(
                                                                    context)
                                                                .textTheme
                                                                .labelSmall))),
                                              for (final block
                                                  in blocks.where(
                                                      (b) =>
                                                          b.first.dayOfWeek ==
                                                          day))
                                                Positioned(
                                                    top: (block.first
                                                                .startMinutes -
                                                            start) *
                                                        scale,
                                                    left: 0,
                                                    right: 0,
                                                    height: (block.last
                                                                .endMinutes -
                                                            block.first
                                                                .startMinutes) *
                                                        scale,
                                                    child: _lesson(block)),
                                            ])))),
                            ])),
                  ])));
        }),
    ];
    // Details use an overlay sheet so the teaching grid never jumps or shrinks.
    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch, children: content);
  }
}

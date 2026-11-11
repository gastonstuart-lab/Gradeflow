import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:gradeflow/models/class.dart';
import 'package:gradeflow/services/home_weekly_timetable_service.dart';

/// Only existing roster IDs can be selected; timetable labels are advisory.
class TeacherHomeClassRail extends StatefulWidget {
  const TeacherHomeClassRail({
    super.key,
    required this.classes,
    required this.selectedClassId,
    required this.studentCounts,
    required this.onSelectClass,
    this.timetable,
    this.onUploadTimetable,
    this.combineConsecutivePeriods = true,
    this.onCombineConsecutivePeriodsChanged,
  });

  final List<Class> classes;
  final String? selectedClassId;
  final Map<String, int> studentCounts;
  final ValueChanged<String>? onSelectClass;
  final HomeWeeklyTimetable? timetable;
  final VoidCallback? onUploadTimetable;
  final bool combineConsecutivePeriods;
  final ValueChanged<bool>? onCombineConsecutivePeriodsChanged;

  @override
  State<TeacherHomeClassRail> createState() => _TeacherHomeClassRailState();
}

class _TeacherHomeClassRailState extends State<TeacherHomeClassRail> {
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _move(int direction) {
    if (!_scroll.hasClients) return;
    final p = _scroll.position;
    final target = (_scroll.offset + direction * 305)
        .clamp(p.minScrollExtent, p.maxScrollExtent).toDouble();
    _scroll.animateTo(target,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? const Color(0xFFEAF4F8) : const Color(0xFF173B63);
    final muted = dark ? const Color(0xFFB8C9D8) : const Color(0xFF62778A);
    return Container(
      key: const ValueKey('home-compact-class-rail'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF102433) : const Color(0xFDFBFDFF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: dark
            ? const Color(0xFF294658) : const Color(0xFFD9E6EE)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Your classes', style: TextStyle(
              color: ink, fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(width: 7),
          Text('${widget.classes.length}', style: TextStyle(
              color: muted, fontSize: 12)),
          const Spacer(),
          if (widget.timetable == null && widget.onUploadTimetable != null)
            TextButton.icon(
              onPressed: widget.onUploadTimetable,
              icon: const Icon(Icons.upload_file_outlined, size: 16),
              label: const Text('Timetable'),
            ),
          if (widget.timetable != null)
            PopupMenuButton<String>(
              tooltip: 'Timetable options',
              icon: Icon(Icons.more_horiz_rounded, color: muted),
              onSelected: (action) {
                if (action == 'replace') widget.onUploadTimetable?.call();
                if (action == 'combine') {
                  widget.onCombineConsecutivePeriodsChanged?.call(
                      !widget.combineConsecutivePeriods);
                }
              },
              itemBuilder: (_) => [
                if (widget.onUploadTimetable != null)
                  const PopupMenuItem(
                    value: 'replace',
                    child: Text('Replace timetable'),
                  ),
                if (widget.onCombineConsecutivePeriodsChanged != null)
                  CheckedPopupMenuItem(
                    value: 'combine',
                    checked: widget.combineConsecutivePeriods,
                    child: const Text('Combine double periods'),
                  ),
              ],
            ),
        ]),
        const SizedBox(height: 8),
        if (widget.classes.isEmpty)
          Text('Your saved classes appear here.',
              style: TextStyle(color: muted, fontSize: 12))
        else
          Row(children: [
            IconButton(
              tooltip: 'Scroll classes left',
              icon: const Icon(Icons.chevron_left_rounded),
              onPressed: () => _move(-1),
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 42),
            ),
            Expanded(child: SizedBox(height: 90, child:
              ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(
                  dragDevices: {
                    PointerDeviceKind.mouse,
                    PointerDeviceKind.touch,
                    PointerDeviceKind.trackpad,
                    PointerDeviceKind.stylus,
                  },
                  scrollbars: false,
                ),
                child: ListView.separated(
                  key: const ValueKey('home-class-rail-list'),
                  controller: _scroll,
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.classes.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 9),
                  itemBuilder: (_, i) => _chip(context, widget.classes[i]),
                ),
              ),
            )),
            IconButton(
              tooltip: 'Scroll classes right',
              icon: const Icon(Icons.chevron_right_rounded),
              onPressed: () => _move(1),
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 42),
            ),
          ]),
        if (widget.timetable != null) ...[
          const SizedBox(height: 8),
          _status(muted),
        ],
      ]),
    );
  }

  Widget _chip(BuildContext context, Class item) {
    final tone = classSubjectTone(item.subject, item.className);
    final selected = widget.selectedClassId == item.classId;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? const Color(0xFFF3F8FC) : const Color(0xFF173B63);
    final count = widget.studentCounts[item.classId];
    final base = dark ? const Color(0xFF132C3B) : Colors.white;
    return Semantics(
      selected: selected, button: true,
      label: 'Select ${item.className}, ${item.subject}',
      child: Material(
        color: Color.lerp(base, tone.color, selected ? .13 : .07),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          key: ValueKey('home-rail-class-${item.classId}'),
          onTap: widget.onSelectClass == null ? null :
              () => widget.onSelectClass!(item.classId),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 148,
            padding: const EdgeInsets.fromLTRB(10, 7, 9, 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? tone.color :
                    tone.color.withValues(alpha: .32),
                width: selected ? 1.8 : 1,
              ),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(tone.icon, color: tone.color, size: 15),
                const SizedBox(width: 5),
                Expanded(child: Text(item.className,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(color: ink,
                      fontWeight: FontWeight.w800, fontSize: 12.5))),
                if (selected) Icon(Icons.check_circle,
                    size: 13, color: tone.color),
              ]),
              const SizedBox(height: 5),
              Text(tone.label, style: TextStyle(
                  color: dark ? const Color(0xFFBDCED9) :
                      const Color(0xFF63788B),
                  fontSize: 10.5)),
              const Spacer(),
              if (count != null) Text('$count students',
                  style: TextStyle(color: dark ? const Color(0xFFBDCED9) :
                      const Color(0xFF63788B), fontSize: 10.5)),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _status(Color muted) => StreamBuilder<DateTime>(
    stream: Stream<DateTime>.periodic(
        const Duration(minutes: 1), (_) => DateTime.now()),
    initialData: DateTime.now(),
    builder: (context, snapshot) {
      final now = snapshot.data ?? DateTime.now();
      final sequence = HomeTeachingSequence.fromSchedule(
        widget.timetable!.classes, now,
        combineConsecutivePeriods: widget.combineConsecutivePeriods,
      );
      final moment = sequence.current ?? sequence.next;
      if (moment == null) return Text('No upcoming lessons',
          style: TextStyle(color: muted, fontSize: 11));
      final isNow = sequence.current != null;
      String clock(DateTime d) => '${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
      return Row(children: [
        Text(isNow ? 'NOW' : 'UP NEXT', style: const TextStyle(
            fontSize: 10, fontWeight: FontWeight.w800,
            color: Color(0xFF14867D))),
        const SizedBox(width: 7),
        Flexible(child: Text(
          '${moment.title} · ${clock(moment.startAt)}–${clock(moment.endAt)}',
          maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(color: muted, fontSize: 11.5))),
        if (isNow && sequence.next != null) ...[
          const SizedBox(width: 12),
          Text('NEXT', style: TextStyle(
              fontWeight: FontWeight.w800, fontSize: 10, color: muted)),
          const SizedBox(width: 7),
          Flexible(child: Text(sequence.next!.title,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: muted, fontSize: 11.5))),
        ],
      ]);
    },
  );
}

class HomeClassSubjectTone {
  const HomeClassSubjectTone(this.color, this.icon, this.label);
  final Color color;
  final IconData icon;
  final String label;
}

/// Deterministic subject colour, independent from timetable Now/Next status.
HomeClassSubjectTone classSubjectTone(String subject, String className) {
  final text = '$subject $className'.toLowerCase();
  if (text.contains('science') || text.contains('sci ') ||
      text.contains('biology')) {
    return const HomeClassSubjectTone(
      Color(0xFF14845E), Icons.science_outlined, 'Science');
  }
  if (text.contains('performance') || text.contains('arts') ||
      RegExp(r'\bpa\b').hasMatch(text)) {
    return const HomeClassSubjectTone(
      Color(0xFF8758B5), Icons.theater_comedy_outlined, 'Performance Arts');
  }
  if (text.contains('math')) {
    return const HomeClassSubjectTone(
      Color(0xFFB17D1D), Icons.calculate_outlined, 'Mathematics');
  }
  if (text.contains('eep') || text.contains('english') ||
      text.contains('literature')) {
    return const HomeClassSubjectTone(
      Color(0xFF216EA5), Icons.menu_book_outlined, 'English / EEP');
  }
  return HomeClassSubjectTone(
    const Color(0xFF327D85), Icons.school_outlined,
    subject.isEmpty ? 'Class' : subject);
}

import 'package:flutter/material.dart';

class PreviewReminder {
  final String text;
  bool done = false;
  PreviewReminder(this.text);
}

/// Session-only organizer; no calendar account or timetable reads.
class PreviewDesktopBook extends ChangeNotifier {
  DateTime selected = DateUtils.dateOnly(DateTime.now());
  late DateTime month = DateTime(selected.year, selected.month);
  final reminders = <PreviewReminder>[
    PreviewReminder('Prepare the food web cards'),
    PreviewReminder('Leave a note for the next lesson'),
  ];
  void select(DateTime date) {
    selected = date;
    notifyListeners();
  }

  void moveMonth(int amount) {
    month = DateTime(month.year, month.month + amount);
    notifyListeners();
  }

  void today() {
    selected = DateUtils.dateOnly(DateTime.now());
    month = DateTime(selected.year, selected.month);
    notifyListeners();
  }

  void add(String text) {
    if (text.trim().isEmpty) return;
    reminders.add(PreviewReminder(text.trim()));
    notifyListeners();
  }

  void toggle(PreviewReminder reminder) {
    reminder.done = !reminder.done;
    notifyListeners();
  }
}

class TeachingPreviewDesktop extends StatefulWidget {
  final PreviewDesktopBook book;
  final Widget classCard;
  final VoidCallback onClass;
  final VoidCallback onQuiz;
  final VoidCallback onTimer;
  final VoidCallback onRoom;
  final VoidCallback? onAttendance;
  final String teacherName;
  const TeachingPreviewDesktop(
      {super.key,
      required this.book,
      required this.classCard,
      required this.onClass,
      required this.onQuiz,
      required this.onTimer,
      required this.onRoom,
      this.onAttendance,
      this.teacherName = 'Teacher'});
  @override
  State<TeachingPreviewDesktop> createState() => _TeachingPreviewDesktopState();
}

class _TeachingPreviewDesktopState extends State<TeachingPreviewDesktop> {
  final _reminder = TextEditingController();
  @override
  void dispose() {
    _reminder.dispose();
    super.dispose();
  }

  static const _months = [
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
  static const _weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday'
  ];
  String _date(DateTime date) => '${date.day} ${_months[date.month - 1]}';
  String _fullDate(DateTime date) =>
      '${_weekdays[date.weekday - 1]} · ${_date(date)}';
  void _add() {
    widget.book.add(_reminder.text);
    _reminder.clear();
  }

  Widget _card(String title, Widget child) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .9),
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x0c284d78),
                  blurRadius: 24,
                  offset: Offset(0, 8))
            ],
            border: Border.all(color: const Color(0xffdce8f3))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -.5)),
          const SizedBox(height: 18),
          child
        ]),
      );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: widget.book,
      builder: (context, _) => DecoratedBox(
          decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [
            Color(0xffe5eff9),
            Color(0xfff6f9fc),
            Color(0xffeaf5f3)
          ], begin: Alignment.topLeft, end: Alignment.bottomRight)),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              MediaQuery.sizeOf(context).width < 700 ? 18 : 36,
              30,
              MediaQuery.sizeOf(context).width < 700 ? 18 : 36,
              118,
            ),
            child: Center(
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1380),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          LayoutBuilder(builder: (context, size) {
                            final greeting = Text(
                              'Welcome, ${widget.teacherName}.',
                              style: TextStyle(
                                  fontSize: size.maxWidth < 600 ? 28 : 34,
                                  height: 1,
                                  letterSpacing: -.8,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xff133c67)),
                            );
                            final date = Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 7),
                              decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: .72),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                      color: const Color(0xffdce8f3))),
                              child: Text(_fullDate(DateTime.now()),
                                  style: const TextStyle(
                                      color: Color(0xff60758c),
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700)),
                            );
                            if (size.maxWidth < 620) {
                              return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    greeting,
                                    const SizedBox(height: 9),
                                    date
                                  ]);
                            }
                            return Row(children: [
                              Expanded(child: greeting),
                              date,
                            ]);
                          }),
                          const SizedBox(height: 14),
                          _schedule(),
                          const SizedBox(height: 18),
                          LayoutBuilder(builder: (context, size) {
                            final main = Column(children: [
                              widget.classCard,
                              const SizedBox(height: 18),
                              _shortcuts(),
                            ]);
                            final side = Column(children: [
                              _calendar(),
                              const SizedBox(height: 20),
                              _reminders()
                            ]);
                            if (size.maxWidth < 900)
                              return Column(children: [
                                main,
                                const SizedBox(height: 20),
                                side
                              ]);
                            return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(flex: 3, child: main),
                                  const SizedBox(width: 24),
                                  Expanded(flex: 2, child: side)
                                ]);
                          }),
                          const SizedBox(height: 22),
                          const Text(
                              'Example schedule and reminders · No school calendar connected · Refresh clears edits',
                              style: TextStyle(
                                  fontSize: 12, color: Color(0xff60758c))),
                        ]))),
          )));

  Widget _schedule() {
    final selectedToday =
        DateUtils.isSameDay(widget.book.selected, DateTime.now());
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .9),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xffdce8f3)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0c284d78),
              blurRadius: 20,
              offset: Offset(0, 7))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.calendar_view_day_rounded,
              size: 18, color: Color(0xff148c8a)),
          const SizedBox(width: 8),
          Text('Day plan · ${_date(widget.book.selected)}',
              style: const TextStyle(
                  color: Color(0xff133c67),
                  fontWeight: FontWeight.w900,
                  fontSize: 15)),
          const Spacer(),
          if (!selectedToday)
            TextButton(
                onPressed: widget.book.today,
                child: const Text('Back to today')),
        ]),
        const SizedBox(height: 10),
        if (widget.book.selected.weekday > 5)
          const Text('No demo lessons scheduled.',
              style: TextStyle(color: Color(0xff60758c)))
        else
          LayoutBuilder(builder: (context, size) {
            final items = <Widget>[
              _planTile(
                  time: '10:10',
                  title: 'J2 Science',
                  subtitle: 'Room 204 · Food webs',
                  badge: 'CURRENT',
                  active: true,
                  onTap: widget.onClass),
              _planTile(
                  time: '11:10',
                  title: 'Preparation',
                  subtitle: 'Review and reset',
                  badge: 'NEXT'),
              _planTile(
                  time: '13:00',
                  title: 'Planning block',
                  subtitle: 'Teacher tasks',
                  badge: 'LATER'),
            ];
            if (size.maxWidth < 760) {
              return Column(children: [
                for (var i = 0; i < items.length; i++) ...[
                  items[i],
                  if (i != items.length - 1) const SizedBox(height: 8),
                ]
              ]);
            }
            return Row(children: [
              for (var i = 0; i < items.length; i++) ...[
                Expanded(child: items[i]),
                if (i != items.length - 1) const SizedBox(width: 8),
              ]
            ]);
          }),
      ]),
    );
  }

  Widget _planTile({
    required String time,
    required String title,
    required String subtitle,
    required String badge,
    bool active = false,
    VoidCallback? onTap,
  }) =>
      Material(
        color: active ? const Color(0xffedf6ff) : const Color(0xfff7f9fc),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                  color: active
                      ? const Color(0xffbed9f3)
                      : const Color(0xffe2ebf3)),
            ),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(time,
                    style: TextStyle(
                        color: active
                            ? const Color(0xff1769ce)
                            : const Color(0xff60758c),
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        letterSpacing: -.25)),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: active
                          ? const Color(0xffd8ebff)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xffdce7f0))),
                  child: Text(badge,
                      style: TextStyle(
                          fontSize: 9,
                          letterSpacing: 1,
                          fontWeight: FontWeight.w900,
                          color: active
                              ? const Color(0xff1769ce)
                              : const Color(0xff60758c))),
                ),
              ]),
              const SizedBox(height: 7),
              Text(title,
                  style: const TextStyle(
                      color: Color(0xff133c67),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: const TextStyle(
                      color: Color(0xff60758c),
                      fontSize: 10.5,
                      height: 1.25)),
              if (onTap != null) ...[
                const SizedBox(height: 5),
                const Row(children: [
                  Text('Open',
                      style: TextStyle(
                          color: Color(0xff1769ce),
                          fontWeight: FontWeight.w800,
                          fontSize: 10.5)),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward_rounded,
                      color: Color(0xff1769ce), size: 13),
                ]),
              ],
            ]),
          ),
        ),
      );

  Widget _shortcuts() => _card(
      'Within reach',
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Open what you need without losing the teaching thread.',
            style: TextStyle(color: Color(0xff60758c), fontSize: 11.5)),
        const SizedBox(height: 10),
        LayoutBuilder(builder: (context, size) {
          final tools = <Widget>[
            _quickTool(
                icon: Icons.edit_note_rounded,
                title: 'Quiz entry',
                subtitle: 'Enter marks quickly',
                onTap: widget.onQuiz),
            _quickTool(
                icon: Icons.timer_outlined,
                title: 'Focus timer',
                subtitle: 'Keep the room moving',
                onTap: widget.onTimer),
            _quickTool(
                icon: Icons.dashboard_customize_outlined,
                title: 'Classroom layout',
                subtitle: 'Adjust tables and seats',
                onTap: widget.onRoom),
            if (widget.onAttendance != null)
              _quickTool(
                  icon: Icons.open_in_new_rounded,
                  title: 'School attendance',
                  subtitle: 'Open the school system',
                  onTap: widget.onAttendance!),
          ];
          if (size.maxWidth < 520) {
            return Column(children: [
              for (var i = 0; i < tools.length; i++) ...[
                tools[i],
                if (i != tools.length - 1) const SizedBox(height: 10),
              ]
            ]);
          }
          final columns = size.maxWidth >= 590 ? 3 : 2;
          final gaps = 10.0 * (columns - 1);
          return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final tool in tools)
                  SizedBox(
                      width: (size.maxWidth - gaps) / columns,
                      child: tool),
              ]);
        }),
      ]));

  Widget _quickTool({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) =>
      Material(
        color: const Color(0xfff6f9fc),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xffdfebf4))),
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
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              color: Color(0xff133c67),
                              fontWeight: FontWeight.w800,
                              fontSize: 14)),
                      const SizedBox(height: 3),
                      Text(subtitle,
                          style: const TextStyle(
                              color: Color(0xff60758c),
                              fontSize: 11.5,
                              height: 1.25)),
                    ]),
              ),
              const Icon(Icons.arrow_forward_rounded,
                  color: Color(0xff7690a8), size: 17),
            ]),
          ),
        ),
      );

  Widget _calendar() {
    final book = widget.book;
    final start = DateTime(book.month.year, book.month.month);
    final count = DateTime(start.year, start.month + 1, 0).day;
    final offset = start.weekday - 1;
    final total = ((offset + count) / 7).ceil() * 7;
    return _card(
        'Calendar',
        Column(children: [
          Row(children: [
            IconButton(
                tooltip: 'Previous month',
                onPressed: () => book.moveMonth(-1),
                icon: const Icon(Icons.chevron_left)),
            Expanded(
                child: Text('${_months[start.month - 1]} ${start.year}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w600))),
            IconButton(
                tooltip: 'Next month',
                onPressed: () => book.moveMonth(1),
                icon: const Icon(Icons.chevron_right))
          ]),
          Row(children: [
            for (final day in ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
              Expanded(
                  child: Text(day,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Color(0xff60758c), fontSize: 12)))
          ]),
          const SizedBox(height: 8),
          for (var row = 0; row < total ~/ 7; row++)
            Row(children: [
              for (var col = 0; col < 7; col++)
                Expanded(child: _day(start, row * 7 + col - offset + 1, count))
            ]),
          TextButton(onPressed: book.today, child: const Text('Back to today')),
        ]));
  }

  Widget _day(DateTime start, int day, int count) {
    if (day < 1 || day > count) return const SizedBox(height: 40);
    final date = DateTime(start.year, start.month, day);
    final selected = DateUtils.isSameDay(date, widget.book.selected);
    return Tooltip(
        message: _date(date),
        child: TextButton(
          key: ValueKey('calendar-${date.year}-${date.month}-$day'),
          style: TextButton.styleFrom(
              minimumSize: const Size(0, 40),
              padding: EdgeInsets.zero,
              backgroundColor: selected ? const Color(0xff1769ce) : null,
              foregroundColor:
                  selected ? Colors.white : const Color(0xff173457)),
          onPressed: () => widget.book.select(date),
          child: Text('$day'),
        ));
  }

  Widget _reminders() => _card(
      'Things to remember',
      Column(children: [
        for (final reminder in widget.book.reminders)
          CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: reminder.done,
              onChanged: (_) => widget.book.toggle(reminder),
              title: Text(reminder.text,
                  style: TextStyle(
                      decoration:
                          reminder.done ? TextDecoration.lineThrough : null))),
        const SizedBox(height: 12),
        TextField(
            controller: _reminder,
            decoration: const InputDecoration(
                labelText: 'Add a reminder', border: OutlineInputBorder()),
            onSubmitted: (_) => _add()),
        const SizedBox(height: 10),
        Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
                onPressed: _add,
                icon: const Icon(Icons.add),
                label: const Text('Add reminder'))),
      ]));
}

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
  const TeachingPreviewDesktop(
      {super.key,
      required this.book,
      required this.classCard,
      required this.onClass,
      required this.onQuiz,
      required this.onTimer,
      required this.onRoom,
      this.onAttendance});
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
  String _date(DateTime date) => '${date.day} ${_months[date.month - 1]}';
  void _add() {
    widget.book.add(_reminder.text);
    _reminder.clear();
  }

  Widget _card(String title, Widget child) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .9),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xffdde5dc))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
          const SizedBox(height: 18),
          child
        ]),
      );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: widget.book,
      builder: (context, _) => SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1240),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 18),
                          const Text('YOUR DESKTOP / DEMO ORGANIZER',
                              style: TextStyle(
                                  fontSize: 11,
                                  letterSpacing: 2,
                                  color: Color(0xff657975))),
                          const SizedBox(height: 12),
                          const Text('A little less to carry.',
                              style: TextStyle(
                                  fontSize: 38,
                                  letterSpacing: -1.2,
                                  fontWeight: FontWeight.w500)),
                          const SizedBox(height: 8),
                          Text(
                              '${_date(DateTime.now())} · Your classroom and the rest of your day, together.',
                              style: const TextStyle(
                                  color: Color(0xff657975), height: 1.5)),
                          const SizedBox(height: 26),
                          LayoutBuilder(builder: (context, size) {
                            final main = Column(children: [
                              widget.classCard,
                              const SizedBox(height: 20),
                              _schedule(),
                              const SizedBox(height: 20),
                              _shortcuts()
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
                          const SizedBox(height: 24),
                          const Text(
                              'Example schedule and reminders · No school calendar connected · Refresh clears edits',
                              style: TextStyle(
                                  fontSize: 12, color: Color(0xff657975))),
                        ]))),
          ));

  Widget _schedule() => _card(
      'Day plan · ${_date(widget.book.selected)}',
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Example schedule for the selected day',
            style: TextStyle(color: Color(0xff657975), fontSize: 12)),
        const SizedBox(height: 14),
        if (widget.book.selected.weekday > 5)
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('No demo lessons scheduled.'))
        else ...[
          ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Text('10:10'),
              title: const Text('J2 Science'),
              subtitle: const Text('Room 204 · Food webs · Demo class'),
              trailing: const Icon(Icons.arrow_forward),
              onTap: widget.onClass),
          const Divider(),
          const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Text('11:10'),
              title: Text('Preparation time'),
              subtitle: Text('Review work and plan the next lesson')),
          const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Text('13:00'),
              title: Text('Planning block'),
              subtitle: Text('An example space for teacher tasks')),
        ],
      ]));

  Widget _shortcuts() => _card(
      'Within reach',
      Wrap(spacing: 10, runSpacing: 10, children: [
        OutlinedButton.icon(
            onPressed: widget.onQuiz,
            icon: const Icon(Icons.edit_note),
            label: const Text('Quiz entry')),
        OutlinedButton.icon(
            onPressed: widget.onTimer,
            icon: const Icon(Icons.timer_outlined),
            label: const Text('Focus timer')),
        OutlinedButton.icon(
            onPressed: widget.onRoom,
            icon: const Icon(Icons.dashboard_customize_outlined),
            label: const Text('Classroom layout')),
        if (widget.onAttendance != null)
          OutlinedButton.icon(
              onPressed: widget.onAttendance,
              icon: const Icon(Icons.open_in_new),
              label: const Text('School attendance')),
      ]));

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
                          color: Color(0xff657975), fontSize: 12)))
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
              backgroundColor: selected ? const Color(0xff23675c) : null,
              foregroundColor:
                  selected ? Colors.white : const Color(0xff203c39)),
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

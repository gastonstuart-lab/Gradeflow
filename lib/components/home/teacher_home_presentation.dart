import 'package:flutter/material.dart';

/// Presentation extracted from the approved 72ad2d7 teaching desktop.
/// Slots receive functional content; this widget owns no preview or saved state.
class TeacherHomePresentation extends StatelessWidget {
  const TeacherHomePresentation({
    super.key,
    required this.teacherName,
    required this.now,
    required this.header,
    required this.dayPlan,
    required this.classCard,
    required this.shortcuts,
    required this.calendar,
    required this.reminders,
    required this.footer,
  });

  final String teacherName;
  final DateTime now;
  final Widget header;
  final Widget dayPlan;
  final Widget classCard;
  final Widget shortcuts;
  final Widget calendar;
  final Widget reminders;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final text = dark ? const Color(0xffeef6ff) : const Color(0xff133c67);
    final subtle = dark ? const Color(0xff9fb4c7) : const Color(0xff60758c);
    final line = dark ? const Color(0xff29445e) : const Color(0xffdce8f3);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: dark
              ? const [Color(0xff07131f), Color(0xff0a1724), Color(0xff0c1d29)]
              : const [Color(0xffe5eff9), Color(0xfff6f9fc), Color(0xffeaf5f3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(children: [
        header,
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              MediaQuery.sizeOf(context).width < 700 ? 18 : 36,
              30,
              MediaQuery.sizeOf(context).width < 700 ? 18 : 36,
              24,
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
                        'Welcome, $teacherName.',
                        style: TextStyle(
                          fontSize: size.maxWidth < 600 ? 28 : 34,
                          height: 1,
                          letterSpacing: -.8,
                          fontWeight: FontWeight.w900,
                          color: text,
                        ),
                      );
                      final date = Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: dark
                              ? const Color(0xff102334)
                              : Colors.white.withValues(alpha: .72),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: line),
                        ),
                        child: Text(
                          '${_weekdays[now.weekday - 1]} · ${now.day} ${_months[now.month - 1]}',
                          style: TextStyle(
                              color: subtle,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700),
                        ),
                      );
                      if (size.maxWidth < 620) {
                        return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              greeting,
                              const SizedBox(height: 9),
                              date
                            ]);
                      }
                      return Row(children: [Expanded(child: greeting), date]);
                    }),
                    const SizedBox(height: 14),
                    dayPlan,
                    const SizedBox(height: 18),
                    LayoutBuilder(builder: (context, size) {
                      final main = Column(children: [
                        classCard,
                        const SizedBox(height: 18),
                        shortcuts
                      ]);
                      final side = Column(children: [
                        calendar,
                        const SizedBox(height: 20),
                        reminders
                      ]);
                      if (size.maxWidth < 900) {
                        return Column(
                            children: [main, const SizedBox(height: 20), side]);
                      }
                      return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 3, child: main),
                            const SizedBox(width: 24),
                            Expanded(flex: 2, child: side),
                          ]);
                    }),
                    const SizedBox(height: 22),
                    footer,
                  ],
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

/// Approved desktop card material and spacing, without domain behavior.
class TeacherHomeCard extends StatelessWidget {
  const TeacherHomeCard({super.key, required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color:
            dark ? const Color(0xff0d1d2c) : Colors.white.withValues(alpha: .9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
            color: dark ? const Color(0xff29445e) : const Color(0xffdce8f3)),
        boxShadow: [
          BoxShadow(
              color: dark
                  ? Colors.black.withValues(alpha: .24)
                  : const Color(0x0c284d78),
              blurRadius: 24,
              offset: const Offset(0, 8))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: TextStyle(
                color: dark ? const Color(0xffeef6ff) : const Color(0xff133c67),
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -.5)),
        const SizedBox(height: 18),
        child,
      ]),
    );
  }
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
const _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday'
];

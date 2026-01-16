import 'package:flutter/material.dart';

/// Simple time-slot based timetable
/// Shows a week view where classes span their actual time duration
class TimeSlotTimetable extends StatelessWidget {
  final List<TimeSlotClass> classes;
  final DateTime weekStart;

  const TimeSlotTimetable({
    Key? key,
    required this.classes,
    required this.weekStart,
  }) : super(key: key);

  static const List<String> dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
  static const int startHour = 8;
  static const int endHour = 18;

  List<TimeSlotClass> _getClassesForDay(int dayOfWeek) {
    return classes.where((c) => c.dayOfWeek == dayOfWeek).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: day names
          Row(
            children: [
              SizedBox(width: 80, child: Padding(padding: EdgeInsets.all(8), child: Text('Time', style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold)))),
              for (int day = 0; day < 5; day++)
                SizedBox(
                  width: 180,
                  child: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                      border: Border(bottom: BorderSide(color: theme.colorScheme.outlineVariant)),
                    ),
                    child: Center(
                      child: Text(
                        dayNames[day],
                        style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          // Scrollable content
          Expanded(
            child: SingleChildScrollView(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Time axis
                  SizedBox(
                    width: 80,
                    child: Column(
                      children: [
                        for (int h = startHour; h < endHour; h++)
                          SizedBox(
                            height: 60,
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border(bottom: BorderSide(color: theme.colorScheme.outlineVariant, width: 0.5)),
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(4),
                                child: Text('${h.toString().padLeft(2, '0')}:00', style: theme.textTheme.labelSmall),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Day columns
                  for (int day = 0; day < 5; day++)
                    SizedBox(
                      width: 180,
                      child: Stack(
                        children: [
                          // Background grid
                          Column(
                            children: [
                              for (int h = startHour; h < endHour; h++)
                                SizedBox(
                                  height: 60,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      border: Border(
                                        right: BorderSide(color: theme.colorScheme.outlineVariant),
                                        bottom: BorderSide(color: theme.colorScheme.outlineVariant, width: 0.5),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          // Classes positioned absolutely
                          ..._buildClassBlocks(theme, day),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildClassBlocks(ThemeData theme, int dayOfWeek) {
    final dayClasses = _getClassesForDay(dayOfWeek);
    if (dayClasses.isEmpty) return [];

    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.indigo,
    ];

    return dayClasses.map((cls) {
      // Calculate position from top
      final startMinFromMidnight = cls.startMinutes;
      final startMinFromGridStart = startMinFromMidnight - (startHour * 60);

      // Calculate height based on duration
      final durationMin = cls.endMinutes - cls.startMinutes;

      // Each hour = 60px, so each minute = 1px
      final topPx = (startMinFromGridStart / 60) * 60;
      final heightPx = (durationMin / 60) * 60;

      final colorIndex = dayClasses.indexOf(cls) % colors.length;

      return Positioned(
        top: topPx,
        left: 4,
        right: 4,
        height: heightPx.clamp(30, 500),
        child: Container(
          decoration: BoxDecoration(
            color: colors[colorIndex].withValues(alpha: 0.2),
            border: Border.all(color: colors[colorIndex], width: 2),
            borderRadius: BorderRadius.circular(6),
          ),
          padding: EdgeInsets.all(6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                cls.title,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors[colorIndex],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (cls.room != null)
                Text(
                  cls.room!,
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 9),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              Text(
                '${_formatTime(cls.startMinutes)}-${_formatTime(cls.endMinutes)}',
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 8),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  String _formatTime(int minutes) {
    final h = (minutes ~/ 60).toString().padLeft(2, '0');
    final m = (minutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class TimeSlotClass {
  final String title;
  final String? room;
  final int dayOfWeek; // 0=Mon, 4=Fri
  final int startMinutes; // Minutes since midnight
  final int endMinutes;

  TimeSlotClass({
    required this.title,
    required this.dayOfWeek,
    required this.startMinutes,
    required this.endMinutes,
    this.room,
  });
}

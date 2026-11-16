import 'dart:async';
import 'package:flutter/material.dart';

/// Reads the device clock each tick so tab suspension cannot accumulate drift.
class TeachingPreviewClock extends StatefulWidget {
  final Color color;
  final bool showDate;
  final DateTime Function()? now;
  const TeachingPreviewClock(
      {super.key,
      this.color = const Color(0xff203c39),
      this.showDate = true,
      this.now});
  @override
  State<TeachingPreviewClock> createState() => _TeachingPreviewClockState();
}

class _TeachingPreviewClockState extends State<TeachingPreviewClock> {
  late DateTime _time;
  Timer? _tick;
  DateTime _read() => (widget.now?.call() ?? DateTime.now()).toLocal();
  @override
  void initState() {
    super.initState();
    _time = _read();
    _tick = Timer.periodic(
        const Duration(seconds: 1), (_) => setState(() => _time = _read()));
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String two(int n) => n.toString().padLeft(2, '0');
    final clock =
        '${two(_time.hour)}:${two(_time.minute)}:${two(_time.second)}';
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return Tooltip(
        message: 'Local device time',
        child: Semantics(
            label: 'Local time $clock',
            excludeSemantics: true,
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(clock,
                      key: const ValueKey('live-clock'),
                      style: TextStyle(
                          color: widget.color,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          fontFeatures: const [FontFeature.tabularFigures()])),
                  if (widget.showDate)
                    Text(
                        '${days[_time.weekday - 1]} · ${_time.day} ${months[_time.month - 1]}',
                        style: TextStyle(
                            color: widget.color.withValues(alpha: .7),
                            fontSize: 11)),
                ])));
  }
}

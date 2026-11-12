import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:gradeflow/services/gradeflow_weather_service.dart';

IconData gradeFlowWeatherIcon(int code, {bool isDay = true}) {
  if (code == 0) return isDay ? Icons.wb_sunny_rounded : Icons.nightlight_round;
  if (code <= 3) return Icons.wb_cloudy_rounded;
  if (code == 45 || code == 48) return Icons.blur_on_rounded;
  if (code >= 95) return Icons.thunderstorm_rounded;
  if (code >= 71 && code <= 86) return Icons.ac_unit_rounded;
  if (code >= 51 && code <= 82) return Icons.water_drop_rounded;
  return Icons.cloud_rounded;
}

String gradeFlowWeatherDescription(int code) {
  if (code == 0) return 'Clear skies';
  if (code <= 2) return 'Partly cloudy';
  if (code == 3) return 'Overcast';
  if (code == 45 || code == 48) return 'Foggy';
  if (code >= 95) return 'Thunderstorms';
  if (code >= 71 && code <= 86) return 'Snow';
  if (code >= 51 && code <= 82) return 'Rain showers';
  return 'Cloudy';
}

String _hourLabel(String timestamp) =>
    timestamp.length >= 16 ? timestamp.substring(11, 16) : '--:--';

String _weekday(String date) {
  final parsed = DateTime.tryParse(date);
  if (parsed == null) return date;
  return const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][
      parsed.weekday - 1];
}

/// Elevated gradient header that responds to conditions, rather than a flat card.
class GradeFlowWeatherHero extends StatelessWidget {
  const GradeFlowWeatherHero({super.key, required this.forecast});
  final GradeFlowWeather forecast;

  @override
  Widget build(BuildContext context) {
    final palette = !forecast.isDay
        ? const [Color(0xff142C56), Color(0xff59649F)]
        : forecast.weatherCode >= 51
            ? const [Color(0xff305D8E), Color(0xff74A5C1)]
            : const [Color(0xff3178B2), Color(0xff56B9C6)];
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: palette,
          begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(23),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('${forecast.temperature.round()}°',
              style: const TextStyle(fontSize: 64, height: 1,
                  fontWeight: FontWeight.w300, letterSpacing: -3,
                  color: Colors.white)),
          const Spacer(),
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutBack,
            tween: Tween(begin: .8, end: 1),
            builder: (_, scale, child) =>
                Transform.scale(scale: scale, child: child),
            child: Icon(gradeFlowWeatherIcon(forecast.weatherCode,
                isDay: forecast.isDay), size: 66, color: Colors.white),
          ),
        ]),
        const SizedBox(height: 12),
        Text(gradeFlowWeatherDescription(forecast.weatherCode),
            style: const TextStyle(color: Colors.white,
                fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('Feels like ${forecast.feelsLike.round()}°'
            '${forecast.days.isEmpty ? '' : '  ·  High ${forecast.days.first.high.round()}° / Low ${forecast.days.first.low.round()}°'}',
          style: const TextStyle(color: Color(0xffE8F5FF), fontSize: 12)),
      ]),
    );
  }
}

/// Temperature-line chart plus forecast icons and rain percentages.
class GradeFlowHourlyWeather extends StatelessWidget {
  const GradeFlowHourlyWeather({super.key, required this.hours});
  final List<GradeFlowWeatherHour> hours;

  @override
  Widget build(BuildContext context) {
    if (hours.isEmpty) return const Text('Hourly forecast unavailable');
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final chartWidth = math.max(330.0, hours.length * 57.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Temperature trend',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: chartWidth,
            child: Column(children: [
              SizedBox(
                height: 103,
                child: CustomPaint(
                  key: const ValueKey('weather-hourly-chart'),
                  painter: _TemperatureLinePainter(
                    values: hours.map((x) => x.temperature).toList(),
                    color: accent,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
              const SizedBox(height: 10),
              Row(children: [
                for (final h in hours)
                  SizedBox(
                    width: chartWidth / hours.length,
                    child: Column(children: [
                      Text(_hourLabel(h.localTime),
                          style: theme.textTheme.labelSmall),
                      const SizedBox(height: 7),
                      Icon(gradeFlowWeatherIcon(h.weatherCode),
                          color: accent, size: 19),
                      const SizedBox(height: 6),
                      Text('${h.temperature.round()}°',
                          style: const TextStyle(fontSize: 12,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 3),
                      Text('${h.rainChance}% rain',
                          style: TextStyle(fontSize: 10,
                            color: theme.colorScheme.onSurfaceVariant)),
                    ]),
                  ),
              ]),
            ]),
          ),
        ),
      ],
    );
  }
}

class _TemperatureLinePainter extends CustomPainter {
  const _TemperatureLinePainter({required this.values, required this.color});
  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final minValue = values.reduce(math.min) - 1.5;
    final maxValue = values.reduce(math.max) + 1.5;
    final range = math.max(1.0, maxValue - minValue);
    final step = size.width / values.length;
    final points = [
      for (var i = 0; i < values.length; i++)
        Offset(step * (i + .5),
            10 + (maxValue - values[i]) / range * (size.height - 20)),
    ];
    final curve = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1], b = points[i];
      final mid = (a.dx + b.dx) / 2;
      curve.cubicTo(mid, a.dy, mid, b.dy, b.dx, b.dy);
    }
    final filled = Path.from(curve)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();
    canvas.drawPath(filled, Paint()..color = color.withValues(alpha: .13));
    canvas.drawPath(curve, Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke);
    for (final point in points) {
      canvas.drawCircle(point, 3.5, Paint()..color = color);
      canvas.drawCircle(point, 1.4, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant _TemperatureLinePainter old) =>
      old.values != values || old.color != color;
}

/// Five-day highs and lows use aligned temperature-range bars.
class GradeFlowDailyWeather extends StatelessWidget {
  const GradeFlowDailyWeather({super.key, required this.days});
  final List<GradeFlowWeatherDay> days;

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) return const Text('Five-day forecast unavailable');
    final theme = Theme.of(context);
    final low = days.map((x) => x.low).reduce(math.min);
    final high = days.map((x) => x.high).reduce(math.max);
    final range = math.max(1.0, high - low);
    return Column(
      key: const ValueKey('weather-five-day-forecast'),
      children: [
        for (final d in days)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Row(children: [
              SizedBox(width: 45, child: Text(_weekday(d.localDate),
                  style: const TextStyle(fontSize: 12,
                      fontWeight: FontWeight.w800))),
              Icon(gradeFlowWeatherIcon(d.weatherCode),
                  color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: 5),
              SizedBox(width: 47, child: Text('${d.rainChance}%',
                  style: TextStyle(fontSize: 11,
                      color: theme.colorScheme.onSurfaceVariant))),
              Text('${d.low.round()}°',
                  style: theme.textTheme.labelMedium),
              const SizedBox(width: 8),
              Expanded(child: LayoutBuilder(builder: (_, constraints) {
                final w = constraints.maxWidth;
                return SizedBox(height: 9, child: Stack(children: [
                  Container(decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(99))),
                  Positioned(
                    left: (d.low - low) / range * w,
                    right: (high - d.high) / range * w,
                    top: 0, bottom: 0,
                    child: Container(decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(99),
                      gradient: const LinearGradient(colors: [
                        Color(0xff6B98E3),
                        Color(0xff5AC6B3),
                        Color(0xffEFB15F),
                      ]),
                    )),
                  ),
                ]));
              })),
              const SizedBox(width: 8),
              Text('${d.high.round()}°',
                  style: const TextStyle(fontSize: 12,
                      fontWeight: FontWeight.w800)),
            ]),
          ),
      ],
    );
  }
}

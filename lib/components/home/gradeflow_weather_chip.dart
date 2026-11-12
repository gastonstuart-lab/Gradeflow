import 'package:flutter/material.dart';
import 'package:gradeflow/components/home/gradeflow_weather_visuals.dart';
import 'package:gradeflow/services/gradeflow_weather_service.dart';
import 'package:url_launcher/url_launcher.dart';

/// Small top-bar control that expands to an animated forecast flyout.
/// Uses an approximate city forecast, with no location permission.
class GradeFlowWeatherChip extends StatefulWidget {
  const GradeFlowWeatherChip({super.key, this.service, this.autoLoad = true});

  final GradeFlowWeatherService? service;
  final bool autoLoad;

  @override
  State<GradeFlowWeatherChip> createState() => _GradeFlowWeatherChipState();
}

class _GradeFlowWeatherChipState extends State<GradeFlowWeatherChip> {
  late final _WeatherController controller;

  @override
  void initState() {
    super.initState();
    controller = _WeatherController(
      service: widget.service ?? GradeFlowWeatherService(),
    );
    if (widget.autoLoad) controller.refresh();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _open() {
    if (controller.forecast == null && !controller.loading) {
      controller.refresh();
    }
    final screen = MediaQuery.sizeOf(context);
    if (screen.width < 700) {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (_) => SizedBox(
          height: screen.height * .78,
          child: _WeatherFlyout(controller: controller),
        ),
      );
    } else {
      showGeneralDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Close weather forecast',
        barrierColor: Colors.black.withValues(alpha: .15),
        transitionDuration: const Duration(milliseconds: 240),
        pageBuilder: (context, _, __) => SafeArea(
          child: Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.only(top: 76, right: 20, bottom: 20),
              child: Material(
                elevation: 20,
                borderRadius: BorderRadius.circular(27),
                color: Theme.of(context).colorScheme.surface,
                clipBehavior: Clip.antiAlias,
                child: SizedBox(
                  width: 405,
                  child: _WeatherFlyout(controller: controller),
                ),
              ),
            ),
          ),
        ),
        transitionBuilder: (_, animation, __, child) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            alignment: Alignment.topRight,
            scale: Tween<double>(begin: .94, end: 1).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
            child: child,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final current = controller.forecast;
        return Tooltip(
          message: 'Taichung weather — open hourly and five-day forecast',
          child: Material(
            borderRadius: BorderRadius.circular(24),
            color: scheme.primaryContainer.withValues(alpha: .55),
            child: InkWell(
              key: const ValueKey('gradeflow-weather-trigger'),
              onTap: _open,
              borderRadius: BorderRadius.circular(24),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(gradeFlowWeatherIcon(current?.weatherCode ?? 2,
                      isDay: current?.isDay ?? true),
                    color: scheme.primary, size: 20),
                  const SizedBox(width: 7),
                  Text(
                    current == null
                        ? 'Weather'
                        : '${current.temperature.round()}°',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface, fontSize: 14),
                  ),
                ]),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Only cached in-memory; never writes to the student's database.
class _WeatherController extends ChangeNotifier {
  _WeatherController({required this.service}) {
    forecast = _cached;
  }

  final GradeFlowWeatherService service;
  static GradeFlowWeather? _cached;
  static DateTime? _cachedAt;

  GradeFlowWeather? forecast;
  bool loading = false;
  bool failed = false;
  bool disposed = false;

  Future<void> refresh({bool force = false}) async {
    if (loading) return;
    if (!force && _cached != null && _cachedAt != null &&
        DateTime.now().difference(_cachedAt!) < const Duration(minutes: 30)) {
      forecast = _cached;
      failed = false;
      notifyListeners();
      return;
    }
    loading = true;
    failed = false;
    notifyListeners();
    try {
      final next = await service.fetchTaichung();
      _cached = next;
      _cachedAt = DateTime.now();
      if (disposed) return;
      forecast = next;
    } catch (_) {
      if (disposed) return;
      failed = true;
    } finally {
      if (!disposed) {
        loading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }
}

class _WeatherFlyout extends StatefulWidget {
  const _WeatherFlyout({required this.controller});
  final _WeatherController controller;

  @override
  State<_WeatherFlyout> createState() => _WeatherFlyoutState();
}

class _WeatherFlyoutState extends State<_WeatherFlyout> {
  bool hourly = true;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final data = widget.controller.forecast;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Taichung',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900)),
                    Text('Current city forecast · °C',
                      style: TextStyle(color: scheme.onSurfaceVariant,
                        fontSize: 11.5)),
                  ],
                )),
                IconButton(
                  tooltip: 'Refresh weather',
                  onPressed: widget.controller.loading ? null
                      : () => widget.controller.refresh(force: true),
                  icon: const Icon(Icons.refresh_rounded)),
                IconButton(
                  tooltip: 'Close weather',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded)),
              ]),
              const SizedBox(height: 16),
              if (data == null && widget.controller.loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 38),
                  child: Center(child: CircularProgressIndicator()))
              else if (data == null) ...[
                const SizedBox(height: 20),
                Icon(Icons.cloud_off_outlined, size: 36,
                    color: scheme.onSurfaceVariant),
                const SizedBox(height: 12),
                const Center(child: Text('Weather currently unavailable')),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => widget.controller.refresh(force: true),
                  child: const Text('Try again'),
                ),
              ] else ...[
                GradeFlowWeatherHero(forecast: data),
                if (widget.controller.failed)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('Showing a cached forecast — refresh failed',
                        style: TextStyle(fontSize: 11))),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: _WeatherStat(
                    icon: Icons.water_drop_outlined,
                    label: 'Rain',
                    value: data.hours.isEmpty
                        ? '—' : '${data.hours.first.rainChance}%')),
                  const SizedBox(width: 8),
                  Expanded(child: _WeatherStat(
                    icon: Icons.opacity_rounded,
                    label: 'Humidity',
                    value: '${data.humidity}%')),
                  const SizedBox(width: 8),
                  Expanded(child: _WeatherStat(
                    icon: Icons.air_rounded,
                    label: 'Wind',
                    value: '${data.windKmh.round()} km/h')),
                ]),
                const SizedBox(height: 22),
                SegmentedButton<bool>(
                  key: const ValueKey('weather-forecast-tabs'),
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: true, label: Text('Hourly'),
                      icon: Icon(Icons.schedule_rounded)),
                    ButtonSegment(value: false, label: Text('5 days'),
                      icon: Icon(Icons.calendar_month_rounded)),
                  ],
                  selected: {hourly},
                  onSelectionChanged: (value) =>
                      setState(() => hourly = value.first),
                ),
                const SizedBox(height: 15),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: hourly
                      ? GradeFlowHourlyWeather(
                          key: const ValueKey('weather-hourly-view'),
                          hours: data.hours)
                      : GradeFlowDailyWeather(
                          key: const ValueKey('weather-daily-view'),
                          days: data.days),
                ),
                const SizedBox(height: 18),
                Text('Updated ${data.observedTime.length >= 16 ? data.observedTime.substring(11, 16) : 'recently'}',
                  style: TextStyle(fontSize: 11,
                    color: scheme.onSurfaceVariant)),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => launchUrl(
                      Uri.parse('https://open-meteo.com/'),
                      mode: LaunchMode.externalApplication),
                    child: const Text('Forecast data: Open-Meteo'),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _WeatherStat extends StatelessWidget {
  const _WeatherStat({required this.icon,
      required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 82,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        color: scheme.surfaceContainerHighest.withValues(alpha: .65)),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 19, color: scheme.primary),
        const SizedBox(height: 5),
        Text(value, style: const TextStyle(
          fontWeight: FontWeight.w800, fontSize: 12.5)),
        const SizedBox(height: 3),
        Text(label, style: TextStyle(
          color: scheme.onSurfaceVariant, fontSize: 10)),
      ]),
    );
  }
}

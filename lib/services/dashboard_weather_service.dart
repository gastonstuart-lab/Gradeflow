import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:gradeflow/config/gradeflow_product_config.dart';

class DashboardForecastDay {
  final DateTime date;
  final double maxTempC;
  final double minTempC;
  final int precipitationChance;
  final int weatherCode;

  const DashboardForecastDay({
    required this.date,
    required this.maxTempC,
    required this.minTempC,
    required this.precipitationChance,
    required this.weatherCode,
  });
}

class DashboardWeatherSnapshot {
  final String locationName;
  final DateTime observedAt;
  final double temperatureC;
  final double apparentTempC;
  final double windSpeedKph;
  final int weatherCode;
  final List<DashboardForecastDay> forecast;

  const DashboardWeatherSnapshot({
    required this.locationName,
    required this.observedAt,
    required this.temperatureC,
    required this.apparentTempC,
    required this.windSpeedKph,
    required this.weatherCode,
    required this.forecast,
  });
}

class DashboardWeatherService {
  static const String _locationName =
      GradeFlowProductConfig.dashboardWeatherLocationName;
  static final Uri _forecastUri = Uri.https(
    'api.open-meteo.com',
    '/v1/forecast',
    {
      'latitude': '${GradeFlowProductConfig.dashboardWeatherLatitude}',
      'longitude': '${GradeFlowProductConfig.dashboardWeatherLongitude}',
      'current':
          'temperature_2m,apparent_temperature,weather_code,wind_speed_10m',
      'daily':
          'weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max',
      'forecast_days': '4',
      'timezone': GradeFlowProductConfig.dashboardWeatherTimeZone,
    },
  );

  Future<DashboardWeatherSnapshot> fetchForecast() async {
    final response = await http.get(_forecastUri);
    if (response.statusCode >= 400) {
      throw Exception('Weather request failed (${response.statusCode})');
    }

    final decoded = jsonDecode(response.body);
    final root =
        decoded is Map<String, dynamic> ? decoded : const <String, dynamic>{};
    final current =
        root['current'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    final daily =
        root['daily'] as Map<String, dynamic>? ?? const <String, dynamic>{};

    final dates = _stringList(daily['time']);
    final maxTemps = _doubleList(daily['temperature_2m_max']);
    final minTemps = _doubleList(daily['temperature_2m_min']);
    final rainChances = _intList(daily['precipitation_probability_max']);
    final weatherCodes = _intList(daily['weather_code']);

    final forecast = <DashboardForecastDay>[];
    final forecastCount = [
      dates.length,
      maxTemps.length,
      minTemps.length,
      rainChances.length,
      weatherCodes.length,
    ].reduce((a, b) => a < b ? a : b);

    for (var i = 0; i < forecastCount; i++) {
      final date = DateTime.tryParse(dates[i]);
      if (date == null) continue;
      forecast.add(
        DashboardForecastDay(
          date: date,
          maxTempC: maxTemps[i],
          minTempC: minTemps[i],
          precipitationChance: rainChances[i],
          weatherCode: weatherCodes[i],
        ),
      );
    }

    return DashboardWeatherSnapshot(
      locationName: _locationName,
      observedAt: DateTime.tryParse((current['time'] ?? '').toString()) ??
          DateTime.now(),
      temperatureC: (current['temperature_2m'] as num?)?.toDouble() ?? 0,
      apparentTempC: (current['apparent_temperature'] as num?)?.toDouble() ?? 0,
      windSpeedKph: (current['wind_speed_10m'] as num?)?.toDouble() ?? 0,
      weatherCode: (current['weather_code'] as num?)?.toInt() ?? 0,
      forecast: forecast,
    );
  }

  String detailsUrl({String locationName = _locationName}) {
    final query = '$locationName weather forecast';
    return 'https://www.google.com/search?q=${Uri.encodeQueryComponent(query)}';
  }

  List<String> _stringList(Object? value) => value is List
      ? value.map((e) => e.toString()).toList()
      : const <String>[];

  List<double> _doubleList(Object? value) => value is List
      ? value.map((e) => (e as num).toDouble()).toList()
      : const <double>[];

  List<int> _intList(Object? value) => value is List
      ? value.map((e) => (e as num).toInt()).toList()
      : const <int>[];
}

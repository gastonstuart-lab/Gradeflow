import 'dart:convert';

import 'package:http/http.dart' as http;

/// Weather data for a compact teacher dashboard; contains no personal data.
class GradeFlowWeather {
  const GradeFlowWeather({
    required this.temperature,
    required this.feelsLike,
    required this.humidity,
    required this.windKmh,
    required this.weatherCode,
    required this.isDay,
    required this.observedTime,
    required this.hours,
    required this.days,
  });

  final double temperature;
  final double feelsLike;
  final int humidity;
  final double windKmh;
  final int weatherCode;
  final bool isDay;
  final String observedTime;
  final List<GradeFlowWeatherHour> hours;
  final List<GradeFlowWeatherDay> days;
}

class GradeFlowWeatherHour {
  const GradeFlowWeatherHour({
    required this.localTime,
    required this.temperature,
    required this.rainChance,
    required this.weatherCode,
  });
  final String localTime;
  final double temperature;
  final int rainChance;
  final int weatherCode;
}

class GradeFlowWeatherDay {
  const GradeFlowWeatherDay({
    required this.localDate,
    required this.low,
    required this.high,
    required this.rainChance,
    required this.weatherCode,
  });
  final String localDate;
  final double low;
  final double high;
  final int rainChance;
  final int weatherCode;
}

/// Fixed city-level Taichung forecast. No GPS, user coordinates or API key.
///
/// Open-Meteo's free API is for eligible non-commercial use and requires data
/// attribution. Review licensing before making GradeFlow a commercial product.
class GradeFlowWeatherService {
  GradeFlowWeatherService({Future<http.Response> Function(Uri)? get})
      : _get = get ?? http.get;

  final Future<http.Response> Function(Uri) _get;

  static final Uri taichungForecastUri = Uri.https(
    'api.open-meteo.com',
    '/v1/forecast',
    {
      'latitude': '24.1477',
      'longitude': '120.6736',
      'timezone': 'Asia/Taipei',
      'temperature_unit': 'celsius',
      'wind_speed_unit': 'kmh',
      'forecast_days': '5',
      'current': 'temperature_2m,relative_humidity_2m,apparent_temperature,is_day,weather_code,wind_speed_10m',
      'hourly': 'temperature_2m,precipitation_probability,weather_code',
      'daily': 'temperature_2m_max,temperature_2m_min,weather_code,precipitation_probability_max',
    },
  );

  Future<GradeFlowWeather> fetchTaichung() async {
    final response = await _get(taichungForecastUri).timeout(
      const Duration(seconds: 10),
    );
    if (response.statusCode != 200) {
      throw StateError('Weather provider returned HTTP ${response.statusCode}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Weather response is not an object');
    }
    return parseForecast(decoded);
  }

  static GradeFlowWeather parseForecast(Map<String, dynamic> source) {
    final current = _object(source['current'], 'current');
    final hourly = _object(source['hourly'], 'hourly');
    final daily = _object(source['daily'], 'daily');
    final observed = (current['time'] ?? '').toString();
    if (observed.isEmpty) {
      throw const FormatException('Weather observation has no timestamp');
    }

    final hourTimes = _list(hourly, 'time');
    final hourTemps = _list(hourly, 'temperature_2m');
    final hourRain = _list(hourly, 'precipitation_probability');
    final hourCodes = _list(hourly, 'weather_code');
    final firstHour = hourTimes.indexWhere(
      (time) => time.toString().compareTo(observed) >= 0,
    );
    final hours = <GradeFlowWeatherHour>[];
    if (firstHour >= 0) {
      for (var index = firstHour;
          index < hourTimes.length && hours.length < 12;
          index++) {
        if (index >= hourTemps.length ||
            index >= hourRain.length ||
            index >= hourCodes.length) {
          break;
        }
        hours.add(GradeFlowWeatherHour(
          localTime: hourTimes[index].toString(),
          temperature: _number(hourTemps[index]),
          rainChance: _integer(hourRain[index]),
          weatherCode: _integer(hourCodes[index]),
        ));
      }
    }

    final dayDates = _list(daily, 'time');
    final dayHighs = _list(daily, 'temperature_2m_max');
    final dayLows = _list(daily, 'temperature_2m_min');
    final dayRain = _list(daily, 'precipitation_probability_max');
    final dayCodes = _list(daily, 'weather_code');
    final days = <GradeFlowWeatherDay>[];
    for (var index = 0; index < dayDates.length && days.length < 5; index++) {
      if (index >= dayHighs.length ||
          index >= dayLows.length ||
          index >= dayRain.length ||
          index >= dayCodes.length) {
        break;
      }
      days.add(GradeFlowWeatherDay(
        localDate: dayDates[index].toString(),
        high: _number(dayHighs[index]),
        low: _number(dayLows[index]),
        rainChance: _integer(dayRain[index]),
        weatherCode: _integer(dayCodes[index]),
      ));
    }

    return GradeFlowWeather(
      temperature: _number(current['temperature_2m']),
      feelsLike: _number(current['apparent_temperature']),
      humidity: _integer(current['relative_humidity_2m']),
      windKmh: _number(current['wind_speed_10m']),
      weatherCode: _integer(current['weather_code']),
      isDay: _integer(current['is_day']) == 1,
      observedTime: observed,
      hours: hours,
      days: days,
    );
  }

  static Map<String, dynamic> _object(dynamic value, String key) {
    if (value is Map<String, dynamic>) return value;
    throw FormatException('Missing weather object: $key');
  }

  static List<dynamic> _list(Map<String, dynamic> object, String key) {
    final value = object[key];
    if (value is List<dynamic>) return value;
    throw FormatException('Missing weather field: $key');
  }

  static double _number(dynamic value) {
    if (value is num) return value.toDouble();
    throw const FormatException('Weather value is not numeric');
  }

  static int _integer(dynamic value) {
    if (value is num) return value.round();
    throw const FormatException('Weather value is not numeric');
  }
}

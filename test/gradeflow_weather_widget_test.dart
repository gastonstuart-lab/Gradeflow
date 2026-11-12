import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/components/home/gradeflow_weather_chip.dart';
import 'package:gradeflow/services/gradeflow_weather_service.dart';
import 'package:http/http.dart' as http;

Map<String, dynamic> _fixture() {
  final times = [
    for (int i = 0; i < 16; i++)
      DateTime(2026, 11, 12, 8 + i).toIso8601String().substring(0, 16),
  ];
  return {
    'current': {
      'time': '2026-11-12T09:00',
      'temperature_2m': 24.2,
      'relative_humidity_2m': 67,
      'apparent_temperature': 25.5,
      'is_day': 1,
      'weather_code': 2,
      'wind_speed_10m': 8.4,
    },
    'hourly': {
      'time': times,
      'temperature_2m': [for (int i = 0; i < times.length; i++) 22.0 + i / 3],
      'precipitation_probability': [for (int i = 0; i < times.length; i++) i * 3],
      'weather_code': [for (int i = 0; i < times.length; i++) i < 7 ? 2 : 61],
    },
    'daily': {
      'time': ['2026-11-12','2026-11-13','2026-11-14','2026-11-15','2026-11-16'],
      'temperature_2m_max': [29, 30, 28, 27, 26],
      'temperature_2m_min': [19, 20, 18, 18, 17],
      'precipitation_probability_max': [10, 20, 60, 45, 10],
      'weather_code': [2, 0, 61, 3, 2],
    },
  };
}

void main() {
  test('Weather parser supplies a 12-hour chart and five-day high/low bars', () {
    final forecast = GradeFlowWeatherService.parseForecast(_fixture());
    expect(forecast.temperature, 24.2);
    expect(forecast.humidity, 67);
    expect(forecast.hours, hasLength(12));
    expect(forecast.days, hasLength(5));
    expect(forecast.hours.first.localTime, '2026-11-12T09:00');
    expect(forecast.days.last.rainChance, 10);
    expect(GradeFlowWeatherService.taichungForecastUri.host,
        'api.open-meteo.com');
    expect(GradeFlowWeatherService.taichungForecastUri.queryParameters['timezone'],
        'Asia/Taipei');
  });

  test('Weather service uses injectable network request with no API key', () async {
    final provider = GradeFlowWeatherService(
      get: (uri) async => http.Response(jsonEncode(_fixture()), 200),
    );
    final forecast = await provider.fetchTaichung();
    expect(forecast.days.first.high, 29);
    expect(forecast.isDay, isTrue);
  });

  testWidgets('Short desktop weather flyout stays inside viewport and scrolls',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 620);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final provider = GradeFlowWeatherService(
      get: (_) async => http.Response(jsonEncode(_fixture()), 200),
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Align(
        alignment: Alignment.topRight,
        child: GradeFlowWeatherChip(service: provider),
      )),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(const ValueKey('gradeflow-weather-trigger')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final surface = find.byKey(
        const ValueKey('gradeflow-weather-desktop-surface'));
    expect(surface, findsOneWidget);
    expect(tester.getBottomRight(surface).dy, lessThanOrEqualTo(620));
    expect(find.byKey(const ValueKey('gradeflow-weather-panel-scroll')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('gradeflow-weather-hourly-scroll')),
        findsOneWidget);
    expect(find.text('Scroll for later hours'), findsOneWidget);
    await tester.ensureVisible(find.text('5 days'));
    await tester.pump();
    await tester.tap(find.text('5 days'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('weather-five-day-forecast')),
        findsOneWidget);
    await tester.ensureVisible(find.text('Forecast data: Open-Meteo'));
    await tester.pump();
    expect(tester.getBottomRight(surface).dy, lessThanOrEqualTo(620));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Weather forecast opens as a scrollable sheet in dark mobile theme',
      (tester) async {
    tester.view.physicalSize = const Size(390, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final provider = GradeFlowWeatherService(
      get: (_) async => http.Response(jsonEncode(_fixture()), 200),
    );
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(brightness: Brightness.dark),
      home: Scaffold(body: Align(
        alignment: Alignment.topRight,
        child: GradeFlowWeatherChip(service: provider),
      )),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tap(find.byKey(const ValueKey('gradeflow-weather-trigger')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('gradeflow-weather-desktop-surface')),
        findsNothing);
    expect(find.byKey(const ValueKey('gradeflow-weather-panel-scroll')),
        findsOneWidget);
    final panelContext = tester.element(
        find.byKey(const ValueKey('gradeflow-weather-panel-scroll')));
    expect(Theme.of(panelContext).brightness, Brightness.dark);

    await tester.ensureVisible(find.text('5 days'));
    await tester.pump();
    await tester.tap(find.text('5 days'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('weather-five-day-forecast')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Small weather trigger opens graphic hourly and daily forecasts',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final provider = GradeFlowWeatherService(
      get: (_) async => http.Response(jsonEncode(_fixture()), 200),
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Align(
        alignment: Alignment.topRight,
        child: GradeFlowWeatherChip(service: provider),
      )),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.byKey(const ValueKey('gradeflow-weather-trigger')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('gradeflow-weather-trigger')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Taichung'), findsOneWidget);
    expect(find.byKey(const ValueKey('weather-hourly-chart')), findsOneWidget);
    expect(find.text('Rain'), findsOneWidget);
    await tester.tap(find.text('5 days'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('weather-five-day-forecast')), findsOneWidget);
    await tester.tap(find.byTooltip('Close weather'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('gradeflow-weather-trigger')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

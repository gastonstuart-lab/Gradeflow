import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/screens/teacher_dashboard_screen.dart';
import 'package:gradeflow/theme.dart';

void main() {
  group('Quick action cards', () {
    testWidgets('rest state is compact and long press reveals fuller detail',
        (tester) async {
      await tester.pumpWidget(
        _buildHarness(
          QuickActionsSection(
            actions: [
              DashboardQuickActionData(
                label: 'Import Roster',
                detail: 'Bring in classes and rosters from your latest files.',
                icon: Icons.upload_file_outlined,
                accent: Colors.green,
                onTap: _noop,
              ),
            ],
          ),
        ),
      );

      expect(find.text('Import Roster'), findsOneWidget);
      expect(find.byKey(const ValueKey('Import Roster-detail')), findsNothing);

      await tester.longPress(find.text('Import Roster'));
      await tester.pumpAndSettle();

      expect(
          find.byKey(const ValueKey('Import Roster-detail')), findsOneWidget);
    });

    testWidgets('tap forwards callback', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _buildHarness(
          QuickActionsSection(
            actions: [
              DashboardQuickActionData(
                label: 'Open Seating',
                detail: 'Open seating for your selected class.',
                icon: Icons.event_seat_outlined,
                accent: Colors.orange,
                onTap: () => taps++,
              ),
            ],
          ),
        ),
      );

      await tester.tap(find.text('Open Seating'));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });
  });

  group('Live/message cards', () {
    testWidgets(
        'message card stays concise at rest and reveals more on long press',
        (tester) async {
      await tester.pumpWidget(_buildHarness(_demoLivePanel()));

      expect(find.text('Messages'), findsOneWidget);
      expect(find.text('2m ago'), findsNothing);
      expect(find.text('Admin Alerts'), findsNothing);

      await tester.ensureVisible(find.text('Messages'));
      await tester.longPress(find.text('Messages'));
      await tester.pumpAndSettle();

      expect(find.text('2m ago'), findsOneWidget);
      expect(find.text('Admin Alerts'), findsOneWidget);
    });

    testWidgets('message card tap forwards callback', (tester) async {
      var opened = 0;

      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _buildHarness(
          _demoLivePanel(
            onOpenMessages: () => opened++,
          ),
        ),
      );

      await tester.ensureVisible(find.text('Open inbox'));
      await tester.tap(find.text('Open inbox'));
      await tester.pumpAndSettle();

      expect(opened, 1);
    });
  });
}

Widget _buildHarness(Widget child) {
  return MaterialApp(
    theme: darkTheme,
    home: Scaffold(
      body: SingleChildScrollView(
        child: Center(
          child: SizedBox(width: 520, child: child),
        ),
      ),
    ),
  );
}

Widget _demoLivePanel({VoidCallback? onOpenMessages}) {
  return LivePanel(
    compact: true,
    systemWidget: const DashboardSystemWidgetData(
      timeLabel: '08:40',
      weekdayLabel: 'Monday',
      dateLabel: 'Apr 5',
      locationLabel: 'Room 305',
      weatherLabel: 'Sunny',
      weatherDetail: '24°C',
      weatherIcon: Icons.wb_sunny_outlined,
      nextLabel: 'Next',
      nextDetail: 'EEP J1FG',
      liveLabel: 'Cloud sync',
    ),
    audioWidget: const DashboardAudioWidgetData(
      activeStation: DashboardAudioStationData(
        id: 'groove-salad',
        stationName: 'Groove Salad',
        programLabel: 'Morning Mix',
        detail: 'Calm tracks for setup before class.',
        streamUrl: 'https://ice5.somafm.com/groovesalad-128-mp3',
        stationUrl: 'https://somafm.com/groovesalad/',
        countryLabel: 'USA',
        categoryLabel: 'Ambient',
        icon: Icons.spa_outlined,
        gradientColors: [Color(0xFF2C5B82), Color(0xFF68B7C8)],
      ),
    ),
    statusItems: const [
      DashboardSystemStatusItemData(
        label: 'Drive sync',
        value: 'Healthy',
        icon: Icons.cloud_done_outlined,
        accent: Colors.green,
      ),
    ],
    communicationWidget: DashboardCommunicationWidgetData(
      headline: '3 unread',
      detail: '2 live threads need attention',
      unreadCount: 3,
      threads: const [
        DashboardCommunicationThreadData(
          title: 'J1FG Parents',
          preview: 'Can we confirm tomorrow\'s seat rotation before class?',
          meta: '2m ago',
          icon: Icons.forum_outlined,
          accent: Colors.blue,
          unreadCount: 2,
        ),
        DashboardCommunicationThreadData(
          title: 'Admin Alerts',
          preview: 'Updated hallway supervision schedule posted.',
          meta: '8m ago',
          icon: Icons.campaign_outlined,
          accent: Colors.orange,
          unreadCount: 1,
        ),
      ],
      onTap: onOpenMessages ?? _noop,
    ),
  );
}

void _noop() {}

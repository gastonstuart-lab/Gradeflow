import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/screens/teacher_dashboard_screen.dart';
import 'package:gradeflow/theme.dart';

void main() {
  group('Workspace strip', () {
    testWidgets('tapping a mode emits selection callback', (tester) async {
      DashboardWorkspaceSection? selected;
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _harness(
          DashboardWorkspaceModeStrip(
            selectedSection: DashboardWorkspaceSection.today,
            onSelected: (value) => selected = value,
            description: 'Focus one workspace area while keeping context nearby.',
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.event_note_outlined));
  await tester.pump();

      expect(selected, DashboardWorkspaceSection.planning);
    });
  });

  group('Command deck summary', () {
    testWidgets('summary metric panel tap forwards callback', (tester) async {
      var tapped = 0;

      await tester.pumpWidget(
        _harness(
          DashboardTopSummary(
            title: 'Teacher command center',
            subtitle: 'Operate classes, planning, and communication in one place.',
            todayLine: 'Now: EEP J1FG • Next: Meeting',
            actions: [
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.palette_outlined),
              ),
            ],
            metrics: [
              DashboardSummaryMetricData(
                label: 'Now Teaching',
                value: 'EEP J1FG',
                detail: 'Until 09:35',
                icon: Icons.play_circle_fill_rounded,
                gradientColors: const [Color(0xFF3457A9), Color(0xFF253552)],
                actionLabel: 'Open timetable',
                onTap: () => tapped++,
              ),
              DashboardSummaryMetricData(
                label: 'Messages',
                value: '3 unread',
                detail: '2 threads active',
                icon: Icons.forum_rounded,
                gradientColors: const [Color(0xFF365A9B), Color(0xFF25304E)],
                actionLabel: 'Open inbox',
                onTap: () => tapped++,
              ),
            ],
            presentation: const DashboardHeroPresentation(
              label: 'Default',
              gradientColors: [Color(0xFF1E2A40), Color(0xFF111827)],
              primaryGlow: Color(0xFF4F74FF),
              secondaryGlow: Color(0xFF6F90FF),
              tertiaryGlow: Color(0xFF8DB1FF),
            ),
            backgroundImage: null,
          ),
        ),
      );

      await tester.tap(find.text('Open timetable'));
      await tester.pump();

      expect(tapped, 1);
    });
  });

  group('Sidebar navigation', () {
    testWidgets('sidebar nav item tap forwards callback', (tester) async {
      var navTap = 0;
      await tester.pumpWidget(
        _harness(
          SizedBox(
            width: 260,
            child: SizedBox(
              height: 420,
              child: SidebarNavigation(
                compact: false,
                primaryItems: [
                  DashboardNavItemData(
                    label: 'Dashboard',
                    icon: Icons.dashboard_rounded,
                    isActive: true,
                    onTap: () => navTap++,
                  ),
                  DashboardNavItemData(
                    label: 'Classes',
                    icon: Icons.class_rounded,
                    onTap: () => navTap++,
                  ),
                ],
                secondaryItems: const [],
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Classes'));
      await tester.pumpAndSettle();

      expect(navTap, 1);
    });
  });
}

Widget _harness(Widget child) {
  return MaterialApp(
    theme: darkTheme,
    home: Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    ),
  );
}

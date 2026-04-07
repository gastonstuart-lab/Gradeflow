import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/models/class_health_model.dart';
import 'package:gradeflow/screens/teacher_dashboard_screen.dart';
import 'package:gradeflow/theme.dart';

void main() {
  group('DashboardClassCard Interactive States', () {
    testWidgets(
      'collapsed state shows only title, subtitle, count, status chip, and primary action',
      (tester) async {
        await tester.pumpWidget(
          _buildHarness(
            DashboardClassCard(
              data: DashboardClassStatusData(
                id: 'class-a',
                title: 'EEP 4 J1FG',
                subtitle: 'English • 2025-2026 Spring',
                level: ClassHealthLevel.urgent,
                levelLabel: 'Urgent',
                statusLabel: 'Roster still missing for this class',
                statusDetail: 'Import students before gradebook and seating.',
                recommendedLabel: 'Import roster',
                recommendedDetail: 'Open classes and bring the roster in.',
                statusIcon: Icons.group_add_rounded,
                accent: Colors.blue,
                isSelected: false,
                studentCount: 0,
                metrics: const [
                  DashboardClassMetricData(
                    icon: Icons.people_alt_outlined,
                    label: 'Roster: Missing',
                  ),
                  DashboardClassMetricData(
                    icon: Icons.schedule_rounded,
                    label: 'Timing: 8:45 AM',
                  ),
                ],
                onTap: () {},
                actions: const [
                  DashboardInlineActionData(
                    label: 'Open classes',
                    icon: Icons.upload_file_outlined,
                    onTap: _noop,
                  ),
                  DashboardInlineActionData(
                    label: 'Open class',
                    icon: Icons.open_in_new_rounded,
                    onTap: _noop,
                  ),
                ],
              ),
            ),
          ),
        );

        // Collapsed state checks
        expect(find.text('EEP 4 J1FG'), findsOneWidget);
        expect(find.text('English • 2025-2026 Spring'), findsOneWidget);
        expect(find.text('Roster empty'), findsOneWidget);
        expect(find.text('Roster still missing for this class'), findsOneWidget); // status label
        
        // Detail/metrics/recommended NOT visible in collapsed state
        expect(find.text('Import students before gradebook and seating.'), findsNothing);
        expect(find.text('Import roster'), findsNothing);
        expect(find.text('Roster: Missing'), findsOneWidget);
        expect(find.text('Timing: 8:45 AM'), findsNothing);
        
        // Only primary action visible in collapsed
        expect(find.text('Open classes'), findsOneWidget);
        expect(find.text('Open class'), findsNothing); // secondary action hidden
        expect(find.byKey(const ValueKey('card-preview-layer')), findsNothing);
      },
    );

    testWidgets(
      'selected state shows richer preview without full expansion',
      (tester) async {
        await tester.pumpWidget(
          _buildHarness(
            DashboardClassCard(
              data: DashboardClassStatusData(
                id: 'class-selected',
                title: 'EEP Focus',
                subtitle: 'English • 2025-2026 Spring',
                level: ClassHealthLevel.attention,
                levelLabel: 'Attention',
                statusLabel: '2 follow-up items due soon',
                statusDetail: 'Review the next reminders before class.',
                recommendedLabel: 'Review reminders',
                recommendedDetail: 'Open planning and clear the next items.',
                statusIcon: Icons.flag_outlined,
                accent: Colors.orange,
                isSelected: true,
                studentCount: 22,
                metrics: const [
                  DashboardClassMetricData(
                    icon: Icons.flag_outlined,
                    label: 'Follow-up: 2 due soon',
                  ),
                ],
                onTap: _noop,
                actions: const [
                  DashboardInlineActionData(
                    label: 'Open planning',
                    icon: Icons.event_note_outlined,
                    onTap: _noop,
                  ),
                ],
              ),
            ),
          ),
        );

        expect(find.text('Review reminders'), findsOneWidget);
        expect(find.byKey(const ValueKey('card-preview-layer')), findsOneWidget);
        expect(find.text('State'), findsNothing);
      },
    );

    testWidgets(
      'expanded state shows State block, Next block, metrics, and all actions',
      (tester) async {
        await tester.pumpWidget(
          _buildHarness(
            DashboardClassCard(
              data: DashboardClassStatusData(
                id: 'class-a',
                title: 'EEP 4 J1FG',
                subtitle: 'English • 2025-2026 Spring',
                level: ClassHealthLevel.urgent,
                levelLabel: 'Urgent',
                statusLabel: 'Roster still missing for this class',
                statusDetail: 'Import students before gradebook and seating.',
                recommendedLabel: 'Import roster',
                recommendedDetail: 'Open classes and bring the roster in.',
                statusIcon: Icons.group_add_rounded,
                accent: Colors.blue,
                isSelected: true,
                studentCount: 0,
                metrics: const [
                  DashboardClassMetricData(
                    icon: Icons.people_alt_outlined,
                    label: 'Roster: Missing',
                  ),
                  DashboardClassMetricData(
                    icon: Icons.schedule_rounded,
                    label: 'Timing: 8:45 AM',
                  ),
                ],
                onTap: () {},
                actions: const [
                  DashboardInlineActionData(
                    label: 'Open classes',
                    icon: Icons.upload_file_outlined,
                    onTap: _noop,
                  ),
                  DashboardInlineActionData(
                    label: 'Open class',
                    icon: Icons.open_in_new_rounded,
                    onTap: _noop,
                  ),
                ],
              ),
            ),
          ),
        );

        // Find the card and tap it to expand
        final cardFinder = find.byType(DashboardClassCard);
        await tester.tap(cardFinder);
        await tester.pumpAndSettle();

        // All content now visible
        expect(find.text('EEP 4 J1FG'), findsOneWidget);
        expect(find.text('Roster still missing for this class'), findsOneWidget);
        expect(find.text('State'), findsOneWidget);
        expect(find.text('Next'), findsOneWidget);
        expect(find.text('Import students before gradebook and seating.'), findsOneWidget);
        expect(find.text('Import roster'), findsOneWidget);
        expect(find.text('Roster: Missing'), findsNWidgets(2));
        expect(find.text('Timing: 8:45 AM'), findsOneWidget);
        expect(find.text('Open classes'), findsOneWidget);
        expect(find.text('Open class'), findsOneWidget); // Now visible
        expect(find.text('Collapse details'), findsOneWidget);
      },
    );

    testWidgets(
      'tap collapse button returns to collapsed state',
      (tester) async {
        await tester.pumpWidget(
          _buildHarness(
            DashboardClassCard(
              data: DashboardClassStatusData(
                id: 'class-a',
                title: 'EEP 4 J1FG',
                subtitle: 'English • 2025-2026 Spring',
                level: ClassHealthLevel.urgent,
                levelLabel: 'Urgent',
                statusLabel: 'Roster still missing for this class',
                statusDetail: 'Import students before gradebook and seating.',
                recommendedLabel: 'Import roster',
                recommendedDetail: 'Open classes and bring the roster in.',
                statusIcon: Icons.group_add_rounded,
                accent: Colors.blue,
                isSelected: true,
                studentCount: 0,
                metrics: const [],
                onTap: () {},
                actions: const [
                  DashboardInlineActionData(
                    label: 'Primary action',
                    icon: Icons.upload_file_outlined,
                    onTap: _noop,
                  ),
                ],
              ),
            ),
          ),
        );

        // Expand
        await tester.tap(find.byType(DashboardClassCard));
        await tester.pumpAndSettle();
        expect(find.text('Collapse details'), findsOneWidget);

        // Collapse
        await tester.tap(find.text('Collapse details'));
        await tester.pumpAndSettle();

        // Collapse button gone, detail hidden
        expect(find.text('Collapse details'), findsNothing);
        expect(find.text('Import students before gradebook and seating.'), findsNothing);
      },
    );

    testWidgets(
      'action button taps call their onTap callbacks',
      (tester) async {
        var primaryTapCount = 0;
        var secondaryTapCount = 0;

        await tester.pumpWidget(
          _buildHarness(
            DashboardClassCard(
              data: DashboardClassStatusData(
                id: 'class-b',
                title: 'Science J2ABC',
                subtitle: 'Science • 2025-2026 Spring',
                level: ClassHealthLevel.attention,
                levelLabel: 'Attention',
                statusLabel: '2 follow-up items due soon',
                statusDetail: 'Review the next reminders before class.',
                recommendedLabel: 'Review reminders',
                recommendedDetail: 'Open planning and clear the next items.',
                statusIcon: Icons.flag_outlined,
                accent: Colors.orange,
                isSelected: true,
                studentCount: 22,
                metrics: const [],
                onTap: () {},
                actions: [
                  DashboardInlineActionData(
                    label: 'Primary route',
                    icon: Icons.arrow_forward_rounded,
                    onTap: () => primaryTapCount++,
                  ),
                  DashboardInlineActionData(
                    label: 'Secondary route',
                    icon: Icons.open_in_new_rounded,
                    onTap: () => secondaryTapCount++,
                  ),
                ],
              ),
            ),
          ),
        );

        // Expand to see all actions
        await tester.tap(find.byType(DashboardClassCard));
        await tester.pumpAndSettle();

        // Tap primary action
        await tester.tap(find.text('Primary route'));
        await tester.pumpAndSettle();
        expect(primaryTapCount, 1);

        // Tap secondary action
        await tester.tap(find.text('Secondary route'));
        await tester.pumpAndSettle();
        expect(secondaryTapCount, 1);
      },
    );
  });
}

Widget _buildHarness(Widget child) {
  return MaterialApp(
    theme: darkTheme,
    home: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: SizedBox(
            width: 420,
            child: child,
          ),
        ),
      ),
    ),
  );
}

void _noop() {}


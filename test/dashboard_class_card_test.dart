import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/models/class_health_model.dart';
import 'package:gradeflow/screens/teacher_dashboard_screen.dart';
import 'package:gradeflow/theme.dart';

void main() {
  testWidgets(
    'dashboard class card renders health cues and next steps',
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

      expect(find.text('EEP 4 J1FG'), findsOneWidget);
      expect(find.text('Urgent'), findsOneWidget);
      expect(find.text('Focused'), findsOneWidget);
      expect(find.text('State'), findsOneWidget);
      expect(find.text('Roster still missing for this class'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);
      expect(find.text('Import roster'), findsOneWidget);
      expect(find.text('Roster: Missing'), findsOneWidget);
      expect(find.text('Timing: 8:45 AM'), findsOneWidget);
      expect(find.text('Open classes'), findsOneWidget);
      expect(find.text('Open class'), findsOneWidget);
    },
  );

  testWidgets(
    'dashboard class card forwards card and action taps',
    (tester) async {
      var cardTapCount = 0;
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
              isSelected: false,
              studentCount: 22,
              metrics: const [
                DashboardClassMetricData(
                  icon: Icons.flag_outlined,
                  label: 'Follow-up: 2 due soon',
                ),
              ],
              onTap: () => cardTapCount++,
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

      final cardFinder = find.byType(DashboardClassCard);
      await tester.tapAt(tester.getCenter(cardFinder));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Primary route'));
      await tester.tap(find.text('Primary route'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Secondary route'));
      await tester.tap(find.text('Secondary route'));
      await tester.pumpAndSettle();

      expect(cardTapCount, 1);
      expect(primaryTapCount, 1);
      expect(secondaryTapCount, 1);
    },
  );
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

import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/services/pilot_feedback_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('pilot feedback persists entries and guide dismissal', () async {
    final service = PilotFeedbackService();
    await service.load();

    final entry = await service.addEntry(
      category: 'Bug',
      area: 'Seating',
      summary: 'Swap felt confusing',
      details:
          'I could drag a student, but I did not understand what seat would win.',
      route: '/class/demo/seating',
    );
    await service.dismissGuide();

    final reloaded = PilotFeedbackService();
    await reloaded.load();

    expect(reloaded.entries, hasLength(1));
    expect(reloaded.entries.single.summary, entry.summary);
    expect(reloaded.entries.single.route, '/class/demo/seating');
    expect(reloaded.guideDismissed, isTrue);
    expect(
      reloaded.buildReportText(reloaded.entries.single, teacherName: 'Alex'),
      contains('Teacher: Alex'),
    );
  });
}

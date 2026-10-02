import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/os/os_app_model.dart';

void main() {
  test('global launcher exposes only standalone cross-class tools', () {
    final apps = OSAppRegistry.launcherApps;
    final ids = apps.map((app) => app.id).toSet();

    expect(apps.any((app) => app.requiresClassContext), isFalse);

    expect(
      ids,
      containsAll(<String>{
        OSAppId.classes,
        OSAppId.planner,
        OSAppId.whiteboard,
        OSAppId.messages,
        OSAppId.schoolDataInbox,
        OSAppId.assistant,
        OSAppId.connected,
      }),
    );

    expect(ids, isNot(contains(OSAppId.teach)));
    expect(ids, isNot(contains(OSAppId.seating)));
    expect(ids, isNot(contains(OSAppId.gradebook)));
    expect(ids, isNot(contains(OSAppId.exports)));
    expect(ids, isNot(contains(OSAppId.attendance)));
    expect(ids, isNot(contains(OSAppId.files)));
    expect(ids, isNot(contains(OSAppId.reports)));
  });

  test('hidden launcher apps remain registered for contextual routes', () {
    for (final id in <String>[
      OSAppId.teach,
      OSAppId.seating,
      OSAppId.gradebook,
      OSAppId.exports,
      OSAppId.attendance,
      OSAppId.files,
      OSAppId.reports,
    ]) {
      expect(OSAppRegistry.findById(id), isNotNull);
    }
  });
}

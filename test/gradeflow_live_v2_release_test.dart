import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/config/gradeflow_live_v2_release.dart';
import 'package:gradeflow/config/planner_v2_staging_safety.dart';

void main() {
  bool allowed({
    bool enabled = true,
    bool staging = false,
    bool preview = false,
    bool emulators = false,
    bool web = true,
    String project = GradeFlowLiveV2Release.projectId,
    String host = 'gradeflow-20260113.web.app',
  }) =>
      GradeFlowLiveV2Release.mayStart(
        enabled: enabled,
        stagingEnabled: staging,
        previewEnabled: preview,
        emulatorEnabled: emulators,
        isWeb: web,
        firebaseProjectId: project,
        originHost: host,
      );

  test('reviewed V2 is permitted only at original live Hosting domains', () {
    expect(allowed(), isTrue);
    expect(allowed(host: 'gradeflow-20260113.firebaseapp.com'), isTrue);
    expect(allowed(host: 'GRADEFLOW-20260113.WEB.APP'), isTrue);
  });

  test('reviewed V2 is blocked on preview, fake and other project origins', () {
    for (final host in <String>[
      'gradeflow-20260113--classroom-v2-a1b2.web.app',
      'localhost',
      '127.0.0.1',
      'gradeflow-20260113.web.app.evil.example',
      'gradeflow-20260113-example.web.app',
      'gradeflow.web.app',
    ]) {
      expect(allowed(host: host), isFalse, reason: host);
    }
    expect(allowed(project: 'demo-gradeflow-v2-staging'), isFalse);
    expect(allowed(project: 'new-gradeflow-project'), isFalse);
  });

  test('does not allow simultaneous staging, preview or emulator settings', () {
    expect(allowed(staging: true), isFalse);
    expect(allowed(preview: true), isFalse);
    expect(allowed(emulators: true), isFalse);
    expect(allowed(web: false), isFalse);
  });

  test('ordinary builds retain the previous production behaviour', () {
    expect(allowed(enabled: false, host: 'localhost'), isTrue);
    expect(
      PlannerV2StagingSafety.mayStart(
        stagingEnabled: false,
        configuredProjectId: GradeFlowLiveV2Release.projectId,
        requiredStagingProjectId: '',
      ),
      isTrue,
    );
  });
}

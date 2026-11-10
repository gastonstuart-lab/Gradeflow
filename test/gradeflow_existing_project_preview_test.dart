import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/config/gradeflow_existing_project_preview.dart';

void main() {
  const project = GradeFlowExistingProjectPreview.projectId;
  const channel = 'gradeflow-20260113--classroom-v2-a1b2c3.web.app';

  bool allowed({
    bool enabled = true,
    bool staging = false,
    bool emulators = false,
    bool isWeb = true,
    String projectId = project,
    String host = channel,
  }) =>
      GradeFlowExistingProjectPreview.mayStart(
        enabled: enabled,
        stagingEnabled: staging,
        emulatorEnabled: emulators,
        isWeb: isWeb,
        projectId: projectId,
        originHost: host,
      );

  test('permits precisely the selected Hosting review channel', () {
    expect(allowed(), isTrue);
    expect(
      GradeFlowExistingProjectPreview.isAllowedPreviewHost(channel),
      isTrue,
    );
  });

  test('blocks the live GradeFlow site and other firebaseapp/Hosting sites', () {
    for (final host in <String>[
      'gradeflow-20260113.web.app',
      'gradeflow-20260113.firebaseapp.com',
      'gradeflow-20260113--live-a1b2c3.web.app',
      'gradeflow-20260113--classroom-v3-a1b2c3.web.app',
      'gradeflow-20260113--classroom-v2-a1b2c3.firebaseapp.com',
      'gradeflow-20260113--classroom-v2-a1b2c3.web.app.evil.example',
      'classroom-v2-a1b2c3.web.app',
      'localhost',
      '127.0.0.1',
    ]) {
      expect(allowed(host: host), isFalse, reason: 'blocked host: $host');
    }
  });

  test('blocks wrong project or combinations with staging/emulators/native', () {
    expect(allowed(projectId: 'another-firebase-project'), isFalse);
    expect(allowed(staging: true), isFalse);
    expect(allowed(emulators: true), isFalse);
    expect(allowed(isWeb: false), isFalse);
  });

  test('synthetic demo credentials work only in explicitly enabled previews', () {
    bool isDemo(String email, String password, {bool previewEnabled = true}) =>
        GradeFlowExistingProjectPreview.isSyntheticDemoLogin(
          email: email, password: password, previewEnabled: previewEnabled,
        );
    expect(isDemo('teacher@demo.com', 'demo'), true);
    expect(isDemo(' TEACHER@DEMO.COM ', 'demo'), true);
    expect(isDemo('teacher@demo.com', 'wrong'), false);
    expect(isDemo('a-real-teacher@example.com', 'demo'), false);
    expect(isDemo('teacher@demo.com', 'demo', previewEnabled: false), false);
  });

  test('does not modify ordinary production or dedicated-staging builds', () {
    expect(allowed(enabled: false, host: 'gradeflow-20260113.web.app'), isTrue);
    expect(allowed(enabled: false, host: 'localhost'), isTrue);
  });
}

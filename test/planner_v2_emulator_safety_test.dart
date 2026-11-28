import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/config/planner_v2_emulator_safety.dart';

void main() {
  test('ordinary application never requires local emulator', () {
    expect(PlannerV2EmulatorSafety.permitted(
      enabled: false, stagingEnabled: false,
      projectId: 'gradeflow-20260113', originHost: 'gradeflow.example.com',
    ), isTrue);
  });
  test('local emulator denies production project on localhost', () {
    expect(PlannerV2EmulatorSafety.permitted(
      enabled: true, stagingEnabled: true,
      projectId: 'gradeflow-20260113', originHost: 'localhost',
    ), isFalse);
  });
  test('local emulator denies public hosts even with demo project', () {
    expect(PlannerV2EmulatorSafety.permitted(
      enabled: true, stagingEnabled: true,
      projectId: PlannerV2EmulatorSafety.demoProjectId,
      originHost: 'gradeflow-test.vercel.app',
    ), isFalse);
  });
  test('local emulator denies missing staging switch', () {
    expect(PlannerV2EmulatorSafety.permitted(
      enabled: true, stagingEnabled: false,
      projectId: PlannerV2EmulatorSafety.demoProjectId,
      originHost: '127.0.0.1',
    ), isFalse);
  });
  test('web auth bootstrap is strictly opt-in debug loopback demo', () {
    bool allowed({bool enabled = true, bool staging = true,
        String project = PlannerV2EmulatorSafety.demoProjectId,
        String host = '127.0.0.1', bool debug = true}) =>
        PlannerV2EmulatorSafety.mayPrimeWebAuth(
          enabled: enabled, stagingEnabled: staging, projectId: project,
          originHost: host, debugMode: debug,
        );
    expect(allowed(), isTrue);
    expect(allowed(host: 'localhost'), isTrue);
    expect(allowed(enabled: false), isFalse);
    expect(allowed(staging: false), isFalse);
    expect(allowed(project: 'gradeflow-20260113'), isFalse);
    expect(allowed(host: 'gradeflow-test.vercel.app'), isFalse);
    expect(allowed(debug: false), isFalse);
  });
  test('only demo project and loopback are allowed with staging', () {
    for (final host in ['localhost', '127.0.0.1']) {
      expect(PlannerV2EmulatorSafety.permitted(
        enabled: true, stagingEnabled: true,
        projectId: PlannerV2EmulatorSafety.demoProjectId, originHost: host,
      ), isTrue);
    }
  });
}

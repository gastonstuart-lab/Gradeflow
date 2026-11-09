/// Local Firebase emulator access for authenticated release testing.
///
/// This mode must never be used for real school data or on a public site.
/// It is enabled only by an explicit compile-time flag *and* a loopback web
/// origin *and* the fixed Firebase demo project ID.
class PlannerV2EmulatorSafety {
  const PlannerV2EmulatorSafety._();

  static const enabled = bool.fromEnvironment(
    'GRADEFLOW_V2_LOCAL_EMULATORS',
    defaultValue: false,
  );

  static const demoProjectId = 'demo-gradeflow-v2-staging';

  static bool permitted({
    required bool enabled,
    required bool stagingEnabled,
    required String projectId,
    required String originHost,
  }) =>
      !enabled ||
      (stagingEnabled &&
          projectId == demoProjectId &&
          (originHost == 'localhost' || originHost == '127.0.0.1'));
}

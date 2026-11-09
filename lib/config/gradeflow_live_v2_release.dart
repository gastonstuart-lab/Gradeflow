/// Opt-in to the reviewed Classroom V2 on the ORIGINAL GradeFlow live site.
/// The flag does not change Firebase options, Firestore rules, or Hosting.
/// A build intended for a preview channel must never pass this guard.
class GradeFlowLiveV2Release {
  const GradeFlowLiveV2Release._();

  static const enabled = bool.fromEnvironment(
    'GRADEFLOW_LIVE_CLASSROOM_V2',
    defaultValue: false,
  );

  static const projectId = 'gradeflow-20260113';

  static bool isAllowedLiveHost(String host) {
    final normalized = host.trim().toLowerCase();
    return normalized == 'gradeflow-20260113.web.app' ||
        normalized == 'gradeflow-20260113.firebaseapp.com';
  }

  static bool mayStart({
    required bool enabled,
    required bool stagingEnabled,
    required bool previewEnabled,
    required bool emulatorEnabled,
    required bool isWeb,
    required String firebaseProjectId,
    required String originHost,
  }) {
    if (!enabled) return true;
    return isWeb &&
        !stagingEnabled &&
        !previewEnabled &&
        !emulatorEnabled &&
        firebaseProjectId == projectId &&
        isAllowedLiveHost(originHost);
  }
}

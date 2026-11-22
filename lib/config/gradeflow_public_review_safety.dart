/// An isolated, full-application *local-data-only* public review build.
///
/// This is deliberately distinct from the production Firebase release and
/// from the historical Firebase Hosting preview that permits real sign-in.
/// A review build never initializes Firebase, so no live teacher or pupil
/// data can be read or written. All example records live in browser storage.
class GradeFlowPublicReviewSafety {
  const GradeFlowPublicReviewSafety._();

  static const enabled = bool.fromEnvironment(
    'GRADEFLOW_PUBLIC_REVIEW_LOCAL_ONLY',
    defaultValue: false,
  );

  static const projectPrefix = 'gradeflow-pr173-full-review';

  static bool permitted({
    required bool enabled,
    required bool isWeb,
    required String originHost,
    required bool liveEnabled,
    required bool existingProjectPreviewEnabled,
    required bool stagingEnabled,
    required bool emulatorEnabled,
  }) {
    if (!enabled) return true; // Production and existing modes unchanged.
    final host = originHost.trim().toLowerCase();
    final validHost = host == 'localhost' ||
        host == '127.0.0.1' ||
        host == '$projectPrefix.vercel.app' ||
        (host.startsWith('$projectPrefix-') &&
            host.endsWith('.vercel.app'));
    return isWeb &&
        validHost &&
        !liveEnabled &&
        !existingProjectPreviewEnabled &&
        !stagingEnabled &&
        !emulatorEnabled;
  }
}

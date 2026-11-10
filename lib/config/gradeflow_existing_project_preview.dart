/// Explicit opt-in for a *Hosting preview channel* in the existing
/// GradeFlow Firebase project. This is not a separate Firebase project.
///
/// The URL guard is checked at runtime, so an accidentally published preview
/// bundle fails closed on the main production Hosting domain.
class GradeFlowExistingProjectPreview {
  const GradeFlowExistingProjectPreview._();

  static const enabled = bool.fromEnvironment(
    'GRADEFLOW_EXISTING_PROJECT_PREVIEW',
    defaultValue: false,
  );

  static const projectId = 'gradeflow-20260113';
  static const channelId = 'classroom-v2';

  /// A Firebase Hosting preview URL is
  /// SITE_ID--CHANNEL_ID-RANDOM_HASH.web.app.
  /// Neither the normal production domain nor arbitrary review hosts qualify.
  static bool isAllowedPreviewHost(String host) {
    final hostname = host.toLowerCase().trim();
    return RegExp(
      r'^gradeflow-20260113--classroom-v2-[a-z0-9-]+\.web\.app$',
    ).hasMatch(hostname);
  }

  /// Preview-only exception for synthetic sample data. It does not authorize
  /// real users or permit Firestore access without Firebase authentication.
  static bool isSyntheticDemoLogin({
    required String email,
    required String password,
    bool? previewEnabled,
  }) =>
      (previewEnabled ?? enabled) &&
      email.trim().toLowerCase() == 'teacher@demo.com' &&
      password == 'demo';

  static bool mayStart({
    required bool enabled,
    required bool stagingEnabled,
    required bool emulatorEnabled,
    required bool isWeb,
    required String projectId,
    required String originHost,
  }) {
    if (!enabled) return true; // Leave normal builds unchanged.
    return isWeb &&
        !stagingEnabled &&
        !emulatorEnabled &&
        projectId == GradeFlowExistingProjectPreview.projectId &&
        isAllowedPreviewHost(originHost);
  }
}

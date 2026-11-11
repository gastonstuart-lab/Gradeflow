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
  /// Each preview bundle is bound to ONE approved Firebase Hosting channel.
  /// The existing Classroom review remains the default to preserve its guard.
  static const channelId = String.fromEnvironment(
    'GRADEFLOW_EXISTING_PROJECT_PREVIEW_CHANNEL',
    defaultValue: 'classroom-v2',
  );

  static const allowedChannelIds = {'classroom-v2', 'login-boxes'};

  /// A Firebase Hosting preview URL is
  /// SITE_ID--CHANNEL_ID-RANDOM_HASH.web.app.
  /// Neither the normal production domain nor arbitrary review hosts qualify.
  static bool isAllowedPreviewHost(String host, {String? expectedChannel}) {
    final channel = expectedChannel ?? channelId;
    if (!allowedChannelIds.contains(channel)) return false;
    final hostname = host.toLowerCase().trim();
    final pattern = RegExp(
      '^gradeflow-20260113--${RegExp.escape(channel)}-[a-z0-9-]+\\.web\\.app\\

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
,
    );
    return pattern.hasMatch(hostname);
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

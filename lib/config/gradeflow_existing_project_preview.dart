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

  /// Each review build is scoped to one known Hosting preview channel.
  /// The previously approved classroom-v2 build keeps its original default.
  static const channelId = String.fromEnvironment(
    'GRADEFLOW_EXISTING_PROJECT_PREVIEW_CHANNEL',
    defaultValue: 'classroom-v2',
  );

  // Add only individually reviewed, fixed Hosting preview channels.
  // The build must still supply the matching channel ID explicitly and
  // match its exact Firebase-generated host; no production host is allowed.
  static const allowedChannelIds = {
    'classroom-v2',
    'login-boxes',
    'classes-v2',
  };

  /// A Firebase Hosting preview URL is SITE--CHANNEL-HASH.web.app.
  /// Production, arbitrary preview channels and near-matching hosts fail closed.
  static bool isAllowedPreviewHost(String host, {String? expectedChannel}) {
    final channel = expectedChannel ?? channelId;
    if (!allowedChannelIds.contains(channel)) return false;
    final hostname = host.toLowerCase().trim();
    final pattern = RegExp(
      r'^gradeflow-20260113--' +
          RegExp.escape(channel) +
          r'-[a-z0-9-]+\.web\.app$',
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
    String? expectedChannel,
  }) {
    if (!enabled) return true; // Leave normal builds unchanged.
    return isWeb &&
        !stagingEnabled &&
        !emulatorEnabled &&
        projectId == GradeFlowExistingProjectPreview.projectId &&
        isAllowedPreviewHost(originHost, expectedChannel: expectedChannel);
  }
}

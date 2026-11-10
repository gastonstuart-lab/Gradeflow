import 'package:gradeflow/config/gradeflow_existing_project_preview.dart';
import 'package:gradeflow/config/gradeflow_live_v2_release.dart';

/// Prevent authenticated Planner V2 staging builds from quietly accessing
/// the production GradeFlow Firebase project.
///
/// A staging build is intentionally blocked until it has been configured
/// against a distinct Firebase project. Build-time flags by themselves do
/// not switch Firebase projects.
class PlannerV2StagingSafety {
  const PlannerV2StagingSafety._();

  static const productionProjectId = 'gradeflow-20260113';

  static const stagingEnabled = bool.fromEnvironment(
    'GRADEFLOW_PLANNER_V2_STAGING',
    defaultValue: false,
  );

  // Both non-live review modes require real Firebase authentication and must
  // never migrate old local data into the connected Firestore project. The
  // dedicated-staging safety checks below remain unchanged.
  static const protectedTestingMode =
      stagingEnabled || GradeFlowExistingProjectPreview.enabled;

  // Approved V2 can also be released to the existing live Hosting domain,
  // but only when its independent project-and-host guard passes at startup.
  // This keeps the default production build unchanged.
  static const authenticatedV2Mode =
      protectedTestingMode || GradeFlowLiveV2Release.enabled;

  static const requiredStagingProjectId = String.fromEnvironment(
    'GRADEFLOW_STAGING_FIREBASE_PROJECT_ID',
    defaultValue: '',
  );

  static bool mayStart({
    required bool stagingEnabled,
    required String configuredProjectId,
    required String requiredStagingProjectId,
  }) {
    if (!stagingEnabled) return true;

    final actual = configuredProjectId.trim();
    final expected = requiredStagingProjectId.trim();
    return expected.isNotEmpty &&
        expected != productionProjectId &&
        actual == expected;
  }

  static String? blockingReason({
    required bool stagingEnabled,
    required String configuredProjectId,
    required String requiredStagingProjectId,
  }) {
    if (mayStart(
      stagingEnabled: stagingEnabled,
      configuredProjectId: configuredProjectId,
      requiredStagingProjectId: requiredStagingProjectId,
    )) return null;

    return 'Planner V2 staging is blocked to protect school data. '
        'This build must use a separate Firebase project, not '
        'the production project gradeflow-20260113. '
        'Set up dedicated staging Firebase options and an explicitly '
        'matching GRADEFLOW_STAGING_FIREBASE_PROJECT_ID before testing '
        'authenticated classes.';
  }
}

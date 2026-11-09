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

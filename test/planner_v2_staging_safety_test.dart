import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/config/planner_v2_staging_safety.dart';

void main() {
  test('normal production build retains normal startup', () {
    expect(
      PlannerV2StagingSafety.mayStart(
        stagingEnabled: false,
        configuredProjectId: 'gradeflow-20260113',
        requiredStagingProjectId: '',
      ),
      isTrue,
    );
  });

  test('staging rejects production Firebase even if claimed as staging', () {
    for (final claimed in ['', 'gradeflow-20260113', 'gradeflow-test']) {
      expect(
        PlannerV2StagingSafety.mayStart(
          stagingEnabled: true,
          configuredProjectId: 'gradeflow-20260113',
          requiredStagingProjectId: claimed,
        ),
        isFalse,
      );
    }
  });

  test('staging rejects missing and mismatched environment', () {
    expect(
      PlannerV2StagingSafety.mayStart(
        stagingEnabled: true,
        configuredProjectId: 'gradeflow-staging-a',
        requiredStagingProjectId: '',
      ),
      isFalse,
    );
    expect(
      PlannerV2StagingSafety.mayStart(
        stagingEnabled: true,
        configuredProjectId: 'gradeflow-staging-a',
        requiredStagingProjectId: 'gradeflow-staging-b',
      ),
      isFalse,
    );
  });

  test('staging only permits explicitly matched non-production project', () {
    expect(
      PlannerV2StagingSafety.mayStart(
        stagingEnabled: true,
        configuredProjectId: 'gradeflow-staging-a',
        requiredStagingProjectId: 'gradeflow-staging-a',
      ),
      isTrue,
    );
  });

  test('rejected staging has explicit safety explanation', () {
    final reason = PlannerV2StagingSafety.blockingReason(
      stagingEnabled: true,
      configuredProjectId: 'gradeflow-20260113',
      requiredStagingProjectId: 'gradeflow-staging-a',
    );
    expect(reason, contains('blocked'));
    expect(reason, contains('gradeflow-20260113'));
  });
}

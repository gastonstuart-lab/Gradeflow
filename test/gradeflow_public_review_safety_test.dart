import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/config/gradeflow_public_review_safety.dart';

void main() {
  bool permitted({
    bool enabled = true,
    bool isWeb = true,
    String host = 'gradeflow-pr173-full-review-abc123.vercel.app',
    bool live = false,
    bool preview = false,
    bool staging = false,
    bool emulators = false,
  }) => GradeFlowPublicReviewSafety.permitted(
    enabled: enabled,
    isWeb: isWeb,
    originHost: host,
    liveEnabled: live,
    existingProjectPreviewEnabled: preview,
    stagingEnabled: staging,
    emulatorEnabled: emulators,
  );

  test('permits explicitly selected local-only review hosting', () {
    expect(permitted(), isTrue);
    expect(permitted(host: 'gradeflow-pr173-full-review.vercel.app'),
        isTrue);
    expect(permitted(host: 'gradeflow-pr173-full-review-gastonstuart-4233s-projects.vercel.app'),
        isTrue);
    expect(permitted(host: 'localhost'), isTrue);
    expect(permitted(host: '127.0.0.1'), isTrue);
  });

  test('rejects live host, foreign hosting, and lookalike suffixes', () {
    expect(permitted(host: 'gradeflow-20260113.web.app'), isFalse);
    expect(permitted(host: 'gradeflow-20260113.firebaseapp.com'), isFalse);
    expect(permitted(host: 'gradeflow-pr173-full-review.vercel.app.bad.tld'),
        isFalse);
    expect(permitted(host: 'someone-else.vercel.app'), isFalse);
    expect(permitted(host: 'gradeflow-pr173-full-review.attacker.tld'),
        isFalse);
    expect(permitted(host: 'gradeflow-pr173-full-reviewer.vercel.app'),
        isFalse);
  });

  test('never combines demo with live, preview, staging or emulators', () {
    expect(permitted(live: true), isFalse);
    expect(permitted(preview: true), isFalse);
    expect(permitted(staging: true), isFalse);
    expect(permitted(emulators: true), isFalse);
    expect(permitted(isWeb: false), isFalse);
  });

  test('does not alter existing build modes without review flag', () {
    expect(permitted(enabled: false, host: 'gradeflow-20260113.web.app',
      live: true), isTrue);
  });
}

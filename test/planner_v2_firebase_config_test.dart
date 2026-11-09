import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/config/planner_v2_firebase_config.dart';

void main() {
  test('dedicated project and complete options are required', () {
    expect(
      PlannerV2FirebaseConfig.isComplete(
        projectId: 'gradeflow-v2-staging',
        apiKey: 'staging-api-key',
        appId: 'staging-app-id',
        senderId: 'staging-sender-id',
        authDomain: 'gradeflow-v2-staging.firebaseapp.com',
        storageBucket: 'gradeflow-v2-staging.firebasestorage.app',
      ),
      isTrue,
    );
  });

  test('production project cannot be used as staging', () {
    expect(
      PlannerV2FirebaseConfig.isComplete(
        projectId: 'gradeflow-20260113',
        apiKey: 'api',
        appId: 'app',
        senderId: 'sender',
        authDomain: 'gradeflow-20260113.firebaseapp.com',
        storageBucket: 'gradeflow-20260113.firebasestorage.app',
      ),
      isFalse,
    );
  });

  test('empty fields and mismatched production auth domain are rejected', () {
    expect(
      PlannerV2FirebaseConfig.isComplete(
        projectId: 'gradeflow-v2-staging',
        apiKey: '',
        appId: 'app',
        senderId: 'sender',
        authDomain: 'gradeflow-v2-staging.firebaseapp.com',
        storageBucket: 'gradeflow-v2-staging.firebasestorage.app',
      ),
      isFalse,
    );
    expect(
      PlannerV2FirebaseConfig.isComplete(
        projectId: 'gradeflow-v2-staging',
        apiKey: 'api',
        appId: 'app',
        senderId: 'sender',
        authDomain: 'gradeflow-20260113.firebaseapp.com',
        storageBucket: 'gradeflow-v2-staging.firebasestorage.app',
      ),
      isFalse,
    );
    expect(
      PlannerV2FirebaseConfig.isComplete(
        projectId: 'gradeflow-v2-staging',
        apiKey: 'api',
        appId: 'app',
        senderId: 'sender',
        authDomain: 'gradeflow-v2-staging.firebaseapp.com',
        storageBucket: 'gradeflow-20260113.firebasestorage.app',
      ),
      isFalse,
    );
    expect(
      PlannerV2FirebaseConfig.isComplete(
        projectId: 'gradeflow-v2-staging',
        apiKey: 'api',
        appId: 'app',
        senderId: 'sender',
        authDomain: 'gradeflow-v2-staging.firebaseapp.com',
        storageBucket: 'some-other-project.firebasestorage.app',
      ),
      isFalse,
    );
  });
}

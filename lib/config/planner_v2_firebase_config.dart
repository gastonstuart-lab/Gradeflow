import 'package:firebase_core/firebase_core.dart';
import 'package:gradeflow/firebase_options.dart';
import 'package:gradeflow/config/planner_v2_staging_safety.dart';

/// Staging Firebase web app configuration, supplied at build time.
/// All five values must belong to the SAME, dedicated non-production Firebase
/// project. Firebase web API keys are public identifiers, not admin credentials.
/// Never embed service account keys or real student records here.
class PlannerV2FirebaseConfig {
  const PlannerV2FirebaseConfig._();

  static const stagingApiKey = String.fromEnvironment(
    'GRADEFLOW_STAGING_FIREBASE_API_KEY',
    defaultValue: '',
  );
  static const stagingAppId = String.fromEnvironment(
    'GRADEFLOW_STAGING_FIREBASE_APP_ID',
    defaultValue: '',
  );
  static const stagingMessagingSenderId = String.fromEnvironment(
    'GRADEFLOW_STAGING_FIREBASE_SENDER_ID',
    defaultValue: '',
  );
  static const stagingAuthDomain = String.fromEnvironment(
    'GRADEFLOW_STAGING_FIREBASE_AUTH_DOMAIN',
    defaultValue: '',
  );
  static const stagingStorageBucket = String.fromEnvironment(
    'GRADEFLOW_STAGING_FIREBASE_STORAGE_BUCKET',
    defaultValue: '',
  );

  static bool isComplete({
    required String projectId,
    required String apiKey,
    required String appId,
    required String senderId,
    required String authDomain,
    required String storageBucket,
  }) {
    final id = projectId.trim();
    if (id.isEmpty ||
        id == PlannerV2StagingSafety.productionProjectId ||
        apiKey.trim().isEmpty ||
        appId.trim().isEmpty ||
        senderId.trim().isEmpty ||
        storageBucket.trim().isEmpty) return false;
    // Reject production domains and buckets, and require the expected Firebase
    // Auth hostname. A custom staging domain must be explicitly designed later.
    if (authDomain.trim() != '$id.firebaseapp.com') return false;
    if (storageBucket.trim() == 'gradeflow-20260113.firebasestorage.app') {
      return false;
    }
    return true;
  }

  static bool get stagingConfigured => isComplete(
    projectId: PlannerV2StagingSafety.requiredStagingProjectId,
    apiKey: stagingApiKey,
    appId: stagingAppId,
    senderId: stagingMessagingSenderId,
    authDomain: stagingAuthDomain,
    storageBucket: stagingStorageBucket,
  );

  static FirebaseOptions get currentPlatform {
    if (!PlannerV2StagingSafety.stagingEnabled) {
      return DefaultFirebaseOptions.currentPlatform;
    }
    if (!stagingConfigured) {
      throw StateError('Dedicated staging Firebase configuration missing');
    }
    return FirebaseOptions(
      apiKey: stagingApiKey,
      appId: stagingAppId,
      messagingSenderId: stagingMessagingSenderId,
      projectId: PlannerV2StagingSafety.requiredStagingProjectId,
      authDomain: stagingAuthDomain,
      storageBucket: stagingStorageBucket,
    );
  }
}

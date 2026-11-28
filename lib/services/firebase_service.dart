import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gradeflow/config/planner_v2_emulator_safety.dart';
import 'package:flutter/foundation.dart';
import 'package:gradeflow/config/planner_v2_firebase_config.dart';
import 'package:gradeflow/config/planner_v2_staging_safety.dart';
import 'package:gradeflow/config/emulator_auth_bootstrap_stub.dart'
    if (dart.library.js_interop) 'package:gradeflow/config/emulator_auth_bootstrap_web.dart';

/// Centralized Firebase initialization.
/// Call [maybeInitialize] once at app startup (from main.dart).
/// If Firebase is not configured, app runs in local-only mode (SharedPreferences).
class FirebaseService {
  static bool _initialized = false;
  static bool _available = false;

  /// Whether Firebase has been successfully initialized.
  static bool get isInitialized => _initialized;

  /// Whether Firebase is available (configured and initialized).
  static bool get isAvailable => _available;

  /// Initialize Firebase if configured.
  /// Safe to call before runApp() — will not throw if config missing.
  /// Returns true if Firebase is now available, false if running local-only.
  static Future<bool> maybeInitialize() async {
    if (_initialized) return _available;

    try {
      final options = PlannerV2FirebaseConfig.currentPlatform;
      if (PlannerV2EmulatorSafety.enabled && kIsWeb) {
        // FlutterFire 6.3.1 restores the Auth session inside initializeApp.
        // A fresh noopener tab lacks the per-tab emulator setting. Prime it
        // before any Firebase service initializes, only for the guarded demo.
        if (!PlannerV2EmulatorSafety.mayPrimeWebAuth(
          enabled: PlannerV2EmulatorSafety.enabled,
          stagingEnabled: PlannerV2StagingSafety.stagingEnabled,
          projectId: options.projectId,
          originHost: Uri.base.host,
          debugMode: kDebugMode,
        )) {
          throw StateError('Web emulator startup requires a loopback debug demo build');
        }
        primeWebAuthEmulator();
      }
      await Firebase.initializeApp(
        options: options,
      ).timeout(const Duration(seconds: 4));
      if (PlannerV2EmulatorSafety.enabled) {
        // Guarded in main.dart before this function can run. Never direct
        // an authenticated production or public web build to local emulators.
        // Connect Auth first: Firestore may request the current identity
        // when its instance is created. Creating Firestore before the Auth
        // emulator connection can start token refresh on a live endpoint.
        await FirebaseAuth.instance.useAuthEmulator('127.0.0.1', 9099);
        FirebaseFirestore.instance.useFirestoreEmulator('127.0.0.1', 8180);
        // Firebase Auth restores web persistence asynchronously. Wait until
        // the first emulator-backed auth state has been resolved before the
        // application's AuthService reads currentUser or GoRouter redirects.
        await FirebaseAuth.instance.authStateChanges().first;
      } else if (PlannerV2StagingSafety.authenticatedV2Mode && kIsWeb) {
        // In release mode, Firebase Auth restores persisted browser state
        // asynchronously. Do not decide whether the user is logged in
        // until the first restored auth state is available: otherwise an
        // authenticated deep link can redirect to Login after a refresh.
        await FirebaseAuth.instance.authStateChanges().first
            .timeout(const Duration(seconds: 8));
      }
      _initialized = true;
      _available = true;
      debugPrint('Firebase initialized successfully');
      return true;
    } catch (e) {
      _initialized = true; // don't retry
      _available = false;
      debugPrint('Firebase not configured; running local-only mode: $e');
      return false;
    }
  }
}

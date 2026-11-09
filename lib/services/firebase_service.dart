import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gradeflow/config/planner_v2_emulator_safety.dart';
import 'package:flutter/foundation.dart';
import 'package:gradeflow/config/planner_v2_firebase_config.dart';

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
      await Firebase.initializeApp(
        options: PlannerV2FirebaseConfig.currentPlatform,
      ).timeout(const Duration(seconds: 4));
      if (PlannerV2EmulatorSafety.enabled) {
        // Guarded in main.dart before this function can run. Never direct
        // an authenticated production or public web build to local emulators.
        FirebaseFirestore.instance.useFirestoreEmulator('127.0.0.1', 8180);
        await FirebaseAuth.instance.useAuthEmulator('127.0.0.1', 9099);
        // Firebase Auth restores web persistence asynchronously. Wait until
        // the first emulator-backed auth state has been resolved before the
        // application's AuthService reads currentUser or GoRouter redirects.
        await FirebaseAuth.instance.authStateChanges().first;
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

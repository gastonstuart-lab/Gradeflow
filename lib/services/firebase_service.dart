import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:gradeflow/firebase_options.dart';

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
        options: DefaultFirebaseOptions.currentPlatform,
      );
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

import 'package:gradeflow/repositories/data_repository.dart';
import 'package:gradeflow/repositories/local_repository.dart';
import 'package:gradeflow/repositories/firestore_repository.dart';
import 'package:gradeflow/services/firebase_service.dart';
import 'package:flutter/foundation.dart';

/// Factory for creating the appropriate DataRepository implementation.
/// Returns LocalRepository (SharedPreferences) if Firebase unavailable,
/// otherwise returns FirestoreRepository (cloud sync).
class RepositoryFactory {
  static DataRepository? _instance;
  
  /// Get the current repository instance.
  /// Creates LocalRepository by default; call `initialize()` first for Firestore.
  static DataRepository get instance {
    _instance ??= LocalRepository();
    return _instance!;
  }
  
  /// Initialize the repository based on Firebase availability.
  /// Call this after FirebaseService.maybeInitialize() in main().
  static Future<void> initialize({String? userId}) async {
    if (FirebaseService.isAvailable && userId != null) {
      _instance = FirestoreRepository(userId: userId);
      debugPrint('RepositoryFactory: Using Firestore for user $userId');
    } else {
      _instance = LocalRepository();
      debugPrint('RepositoryFactory: Using local storage (SharedPreferences)');
    }
  }
  
  /// Force reset to local-only mode (useful for testing or logout).
  static void useLocal() {
    _instance = LocalRepository();
    debugPrint('RepositoryFactory: Switched to local storage');
  }
  
  /// Check if using cloud sync.
  static bool get isUsingFirestore => _instance is FirestoreRepository;
}

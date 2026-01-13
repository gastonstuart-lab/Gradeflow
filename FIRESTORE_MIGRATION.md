# Firestore Migration Guide

## Overview
This guide explains how to activate Cloud Firestore for Gradeflow, enabling cloud sync and multi-device access.

## Current Status
- ✅ Firebase packages installed (`firebase_core`, `cloud_firestore`)
- ✅ Repository layer implemented (Local ↔ Firestore swap)
- ✅ Opt-in initialization (app works without Firebase config)
- ⏳ Firebase project configuration (pending)
- ⏳ Data migration from SharedPreferences to Firestore (pending)

## Step 1: Create Firebase Project

### Option A: Using FlutterFire CLI (Recommended)
1. Install FlutterFire CLI:
   ```powershell
   dart pub global activate flutterfire_cli
   ```

2. Run FlutterFire configure:
   ```powershell
   flutterfire configure
   ```
   - Select or create a Firebase project
   - Choose platforms: Web, Android, iOS
   - This creates `lib/firebase_options.dart` automatically

### Option B: Manual Setup
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create a new project or use existing
3. Add Web, Android, and iOS apps
4. Download configuration files:
   - Web: Copy config from Firebase Console → Project Settings → Web app
   - Android: Download `google-services.json` → place in `android/app/`
   - iOS: Download `GoogleService-Info.plist` → place in `ios/Runner/`

## Step 2: Update Firebase Configuration

Edit `lib/services/firebase_service.dart`:

```dart
FirebaseOptions? _getFirebaseOptions() {
  return DefaultFirebaseOptions.currentPlatform; // Import from firebase_options.dart
}
```

Add import at top of file:
```dart
import 'package:gradeflow/firebase_options.dart';
```

## Step 3: Configure Android (if using Android)

Edit `android/build.gradle`:
```gradle
dependencies {
    classpath 'com.google.gms:google-services:4.4.0'
}
```

Edit `android/app/build.gradle`:
```gradle
apply plugin: 'com.google.gms.google-services' // Add at end of file
```

## Step 4: Enable Firestore in Firebase Console

1. Go to Firebase Console → Firestore Database
2. Click "Create database"
3. Choose production mode
4. Select a region (closest to your users)

## Step 5: Set Up Security Rules

In Firebase Console → Firestore Database → Rules, use:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // User can only access their own data
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

## Step 6: Migrate Local Data to Firestore

### Option A: Manual Migration Tool (Recommended for first-time setup)

Create `lib/tools/migrate_to_firestore.dart`:

```dart
import 'package:gradeflow/repositories/local_repository.dart';
import 'package:gradeflow/repositories/firestore_repository.dart';
import 'package:gradeflow/services/auth_service.dart';

Future<void> migrateToFirestore(String userId) async {
  print('Starting migration to Firestore...');
  
  final local = LocalRepository();
  final cloud = FirestoreRepository(userId: userId);
  
  // Migrate classes
  final classes = await local.loadClasses();
  await cloud.saveClasses(classes);
  print('Migrated ${classes.length} classes');
  
  // Migrate templates
  final templates = await local.loadTemplates();
  await cloud.saveTemplates(templates);
  print('Migrated ${templates.length} templates');
  
  // For each class, migrate students, items, scores, exams, categories
  for (final cls in classes) {
    final students = await local.loadStudents(cls.id);
    await cloud.saveStudents(cls.id, students);
    print('  Class ${cls.name}: migrated ${students.length} students');
    
    final items = await local.loadGradeItems(cls.id);
    await cloud.saveGradeItems(cls.id, items);
    print('  Class ${cls.name}: migrated ${items.length} grade items');
    
    for (final item in items) {
      final scores = await local.loadScores(cls.id, item.id);
      await cloud.saveScores(cls.id, item.id, scores);
    }
    
    final exams = await local.loadExams(cls.id);
    await cloud.saveExams(cls.id, exams);
    print('  Class ${cls.name}: migrated ${exams.length} exams');
    
    final categories = await local.loadCategories(cls.id);
    await cloud.saveCategories(cls.id, categories);
    print('  Class ${cls.name}: migrated ${categories.length} categories');
  }
  
  print('Migration complete!');
}
```

### Option B: In-App Migration Button

Add to Settings screen or Teacher Dashboard:

```dart
ElevatedButton(
  onPressed: () async {
    final userId = context.read<AuthService>().currentUser?.id;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please sign in first')),
      );
      return;
    }
    
    await migrateToFirestore(userId);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Data migrated to Firestore!')),
    );
  },
  child: Text('Import Local Data to Cloud'),
)
```

## Step 7: Switch to Firestore Repository

Edit `lib/main.dart`:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await FirebaseService.maybeInitialize();
  
  // Get current user ID (after sign-in)
  // For now, initialize as local-only; switch after login
  await RepositoryFactory.initialize();
  
  runApp(const MyApp());
}
```

After successful login in `AuthService`:

```dart
// In AuthService.signIn() method, after user authenticated:
await RepositoryFactory.initialize(userId: user.id);
```

## Step 8: Update Services to Use Repository

Example for `StudentService`:

Before:
```dart
Future<void> saveStudents() async {
  final prefs = await SharedPreferences.getInstance();
  // ... manual serialization
}
```

After:
```dart
Future<void> saveStudents() async {
  await RepositoryFactory.instance.saveStudents(classId, _students);
}
```

Repeat for all services (ClassService, GradeItemService, etc.)

## Verification Checklist

- [ ] `firebase_options.dart` exists and contains config
- [ ] Firestore enabled in Firebase Console
- [ ] Security rules configured
- [ ] Local data migrated to Firestore
- [ ] App successfully reads/writes to Firestore
- [ ] Multi-device sync working (test on 2 devices)
- [ ] Offline mode working (airplane mode test)

## Rollback Plan

If issues arise, revert to local-only mode:

1. Comment out Firebase initialization in `main.dart`
2. Force local mode:
   ```dart
   RepositoryFactory.useLocal();
   ```
3. Your local data in SharedPreferences is unchanged

## Production Deployment

1. **Firebase Hosting** (for web):
   ```powershell
   firebase init hosting
   flutter build web
   firebase deploy
   ```

2. **Android**:
   - Ensure `google-services.json` is in `android/app/`
   - Build: `flutter build apk --release`

3. **iOS**:
   - Ensure `GoogleService-Info.plist` is in `ios/Runner/`
   - Build: `flutter build ios --release`

## Performance Tips

1. **Indexes**: Monitor Firestore console for missing index warnings
2. **Batch Writes**: Repository already uses batched writes for efficiency
3. **Offline Persistence**: Firestore enables this by default
4. **Pagination**: For large datasets, implement pagination in `loadStudents()`, etc.

## Support

- Firebase Console: https://console.firebase.google.com/
- FlutterFire Docs: https://firebase.flutter.dev/
- Firestore Best Practices: https://firebase.google.com/docs/firestore/best-practices

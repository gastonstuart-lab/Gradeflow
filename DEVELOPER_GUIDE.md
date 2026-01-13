# Developer Guide - GradeFlow

## Quick Start for Development

### First Time Setup
```powershell
# 1. Navigate to project
cd c:\Dev\Gradeflow

# 2. Install dependencies
flutter pub get

# 3. Run in Chrome
flutter run -d chrome

# Or use the script
.\scripts\dev-run.ps1 -Platform chrome
```

### Available Development Scripts

All scripts are in the `scripts/` directory:

```powershell
# Development
.\scripts\dev-run.ps1 -Platform chrome     # Run on Chrome
.\scripts\dev-run.ps1 -Platform edge       # Run on Edge

# Production Builds
.\scripts\build-web.ps1                     # Build for web deployment
.\scripts\build-android.ps1                 # Build Android APK
```

---

## Architecture Overview

### State Management: Provider Pattern

The app uses **Provider** for state management:

- `AuthService`: User authentication and session
- `ClassService`: Class CRUD operations
- `StudentService`: Student management
- `GradeCategoryService`: Category management
- `GradeItemService`: Grade item management
- `StudentScoreService`: Score tracking
- `FinalExamService`: Final exam scores
- `CalculationService`: Grade calculations (stateless)
- `ExportService`: Data export (stateless)
- `FileImportService`: File parsing (stateless)

All services are configured in `lib/providers/app_providers.dart`.

### Data Persistence

**SharedPreferences** is used for local storage:
- User data: `current_user`, `users`
- Classes: `classes`
- Students: `students`
- Categories: `grading_categories`
- Grade items: `grade_items`
- Scores: `student_scores`
- Final exams: `final_exams`
- Change history: `change_history`
- Trash: `deleted_students`

### Navigation

**GoRouter** handles routing:
- `/` - Login screen
- `/dashboard` - Teacher dashboard
- `/classes` - Class list
- `/class/:classId` - Class detail
- `/class/:classId/students` - Student list
- `/class/:classId/students/trash` - Deleted students
- `/class/:classId/gradebook` - Gradebook
- `/class/:classId/categories` - Category management
- `/class/:classId/exam` - Exam input
- `/class/:classId/export` - Export screen
- `/class/:classId/results` - Final results

See `lib/nav.dart` for full routing configuration.

---

## Adding New Features

### 1. Adding a New Screen

```dart
// 1. Create screen file
// lib/screens/my_new_screen.dart
import 'package:flutter/material.dart';

class MyNewScreen extends StatefulWidget {
  const MyNewScreen({super.key});

  @override
  State<MyNewScreen> createState() => _MyNewScreenState();
}

class _MyNewScreenState extends State<MyNewScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My New Screen')),
      body: const Center(child: Text('Hello!')),
    );
  }
}

// 2. Add route in lib/nav.dart
GoRoute(
  path: '/my-new-screen',
  name: 'myNewScreen',
  pageBuilder: (context, state) => 
    const NoTransitionPage(child: MyNewScreen()),
),

// 3. Navigate to it
context.go('/my-new-screen');
```

### 2. Adding a New Model

```dart
// lib/models/my_model.dart
class MyModel {
  final String id;
  final String name;
  final DateTime createdAt;

  MyModel({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'createdAt': createdAt.toIso8601String(),
  };

  factory MyModel.fromJson(Map<String, dynamic> json) => MyModel(
    id: json['id'] as String,
    name: json['name'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}
```

### 3. Adding a New Service

```dart
// lib/services/my_service.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:gradeflow/models/my_model.dart';

class MyService extends ChangeNotifier {
  static const String _key = 'my_models';
  List<MyModel> _items = [];

  List<MyModel> get items => List.unmodifiable(_items);

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_key);
    if (json != null) {
      final list = jsonDecode(json) as List;
      _items = list.map((e) => MyModel.fromJson(e)).toList();
      notifyListeners();
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(_items.map((e) => e.toJson()).toList()));
  }

  Future<void> add(MyModel item) async {
    _items.add(item);
    await _save();
    notifyListeners();
  }

  Future<void> delete(String id) async {
    _items.removeWhere((e) => e.id == id);
    await _save();
    notifyListeners();
  }
}

// Register in lib/providers/app_providers.dart
ChangeNotifierProvider(create: (_) => MyService()..initialize()),
```

---

## Styling Guidelines

### Theme Usage

Always use theme colors instead of hardcoded values:

```dart
// ✅ Good
color: Theme.of(context).colorScheme.primary

// ❌ Bad
color: Colors.blue
```

### Text Styles

Use context extension for text styles:

```dart
// Get theme text styles
Text('Title', style: context.textStyles.titleLarge)
Text('Body', style: context.textStyles.bodyMedium)

// Modify styles
Text('Bold', style: context.textStyles.bodyLarge?.bold)
Text('Colored', style: context.textStyles.bodyMedium?.withColor(Colors.red))
```

### Spacing

Use `AppSpacing` constants:

```dart
SizedBox(height: AppSpacing.md)
Padding(padding: AppSpacing.paddingLg)
```

### Border Radius

Use `AppRadius` constants:

```dart
BorderRadius.circular(AppRadius.md)
```

---

## Testing

### Manual Testing Checklist

Before deploying:

- [ ] Demo login works
- [ ] Create class
- [ ] Import students (CSV/Excel)
- [ ] Create categories
- [ ] Add grade items
- [ ] Enter scores
- [ ] View final results
- [ ] Export to CSV/Excel/PDF
- [ ] Test dark mode
- [ ] Test responsive layout
- [ ] Clear data and re-test

### Testing Import Files

Create test CSV:
```csv
Student ID,Chinese Name,English First Name,English Last Name,Seat No,Class
101,王小明,Ming,Wang,1,J2A
102,李小華,Hua,Li,2,J2A
```

---

## Deployment

### Web (Firebase Hosting)

```powershell
# 1. Build
.\scripts\build-web.ps1

# 2. Install Firebase CLI (first time only)
npm install -g firebase-tools

# 3. Login
firebase login

# 4. Initialize (first time only)
firebase init hosting

# 5. Deploy
firebase deploy
```

### Web (Netlify)

```powershell
# 1. Build
.\scripts\build-web.ps1

# 2. Install Netlify CLI
npm install -g netlify-cli

# 3. Deploy
netlify deploy --prod --dir=build/web
```

### Android

```powershell
# 1. Build
.\scripts\build-android.ps1

# 2. Install on device
flutter install

# Or upload to Google Play Console
# build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

### iOS

```bash
# 1. Build
flutter build ios --release

# 2. Open in Xcode
open ios/Runner.xcworkspace

# 3. Archive and distribute via Xcode
```

---

## Performance Optimization

### 1. Large Student Lists

Use `ListView.builder` instead of `ListView`:

```dart
ListView.builder(
  itemCount: students.length,
  itemBuilder: (context, index) => StudentTile(students[index]),
)
```

### 2. Heavy Calculations

Use `compute` for background processing:

```dart
final result = await compute(heavyCalculation, data);
```

### 3. Image Optimization

For student photos, limit size:

```dart
final compressed = await FlutterImageCompress.compressWithList(
  bytes,
  minWidth: 200,
  minHeight: 200,
  quality: 85,
);
```

---

## Troubleshooting

### Issue: "Target of URI doesn't exist"

**Solution**: Run `flutter pub get` and restart the analyzer:
```powershell
flutter pub get
# Then restart VS Code or run: Dart: Restart Analysis Server
```

### Issue: OpenAI import not working

**Solution**: Ensure API key is provided:
```powershell
flutter run -d chrome `
  --dart-define=OPENAI_PROXY_API_KEY=sk-... `
  --dart-define=OPENAI_PROXY_ENDPOINT=https://api.openai.com/v1/chat/completions
```

### Issue: PDF Chinese characters not showing

**Solution**: The app downloads fonts on first use. Ensure internet connection.

### Issue: Build fails on web

**Solution**: Try clean build:
```powershell
flutter clean
flutter pub get
flutter build web --release
```

---

## Code Style

Follow the [Effective Dart](https://dart.dev/guides/language/effective-dart) guide:

- Use `const` constructors where possible
- Prefer `final` over `var`
- Use trailing commas for better formatting
- Document public APIs with `///` comments
- Keep functions small and focused
- Extract complex widgets into separate files

---

## Best Practices

1. **Always dispose controllers**:
   ```dart
   @override
   void dispose() {
     _controller.dispose();
     super.dispose();
   }
   ```

2. **Check mounted before setState**:
   ```dart
   if (mounted) {
     setState(() => _loading = false);
   }
   ```

3. **Use Provider.of with listen: false in callbacks**:
   ```dart
   onPressed: () {
     final service = context.read<MyService>();
     service.doSomething();
   }
   ```

4. **Handle errors gracefully**:
   ```dart
   try {
     await riskyOperation();
   } catch (e) {
     debugPrint('Error: $e');
     if (mounted) {
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text('Operation failed: $e')),
       );
     }
   }
   ```

---

## Resources

- [Flutter Documentation](https://docs.flutter.dev/)
- [Provider Package](https://pub.dev/packages/provider)
- [GoRouter](https://pub.dev/packages/go_router)
- [Material Design 3](https://m3.material.io/)

---

**Happy Coding!** 🚀

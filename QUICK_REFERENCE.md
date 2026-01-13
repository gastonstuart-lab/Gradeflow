# Quick Reference Guide - GradeFlow

## 🚀 Common Commands

### Development
```powershell
# Start development server
flutter run -d chrome

# Or use script
.\scripts\dev-run.ps1

# Hot reload
Press 'r' in terminal

# Hot restart
Press 'R' in terminal

# Open DevTools
Press 'v' in terminal
```

### Building
```powershell
# Web
.\scripts\build-web.ps1
# or
flutter build web --release

# Android
.\scripts\build-android.ps1
# or
flutter build apk --release

# iOS
flutter build ios --release
```

### Cleaning
```powershell
# Clean build files
flutter clean

# Get dependencies
flutter pub get

# Full clean + rebuild
flutter clean; flutter pub get; flutter run -d chrome
```

---

## 📊 Grade Calculation Formula

### Process Score (平時成績)
```
For each category:
  CategoryScore = aggregate(all items in category)
  
ProcessScore = Σ(CategoryScore × CategoryWeight)
```

### Final Grade (學期總成績)
```
FinalGrade = (ProcessScore × 40%) + (ExamScore × 60%)
```

### Aggregation Methods

1. **Average** (平均)
   ```
   Score = Sum(all scores) / Count(all scores)
   ```

2. **Sum** (總和)
   ```
   Score = Sum(all scores)
   ```

3. **Best N** (取最佳N項)
   ```
   Score = Sum(top N scores) / N
   ```

4. **Drop Lowest N** (去掉最低N項)
   ```
   Score = Sum(remaining scores) / Count(remaining scores)
   ```

---

## 📁 CSV Import Format

### Required Columns
```csv
Student ID,Chinese Name,English First Name,English Last Name
101234,王小明,Ming,Wang
```

### Optional Columns
```csv
Student ID,Chinese Name,English First Name,English Last Name,Seat No,Class
101234,王小明,Ming,Wang,1,J2A
```

### Alternative Headers
The system recognizes these variations:
- Student ID: `student_id`, `id`, `學號`
- Chinese Name: `chinese_name`, `name`, `姓名`, `中文姓名`
- First Name: `first_name`, `firstname`, `given_name`
- Last Name: `last_name`, `lastname`, `surname`, `family_name`
- Seat No: `seat_no`, `seat`, `座號`, `座位`
- Class: `class`, `form`, `班級`

---

## 🎨 Theme Colors Reference

### Light Mode
```dart
Primary: #4F46E5 (Indigo)
Background: #F8FAFC (Cool Gray)
Surface: #FFFFFF (White)
Error: #EF4444 (Red)
Success: #10B981 (Green)
Warning: #F59E0B (Amber)
```

### Dark Mode
```dart
Primary: #818CF8 (Light Indigo)
Background: #0F1419 (Deep Blue-Charcoal)
Surface: #1A1F26 (Charcoal)
Error: #F87171 (Light Red)
Success: #34D399 (Light Green)
```

---

## 🔌 Service Initialization Order

1. `AuthService` - Must initialize first
2. All other services can initialize in parallel
3. Services auto-load data from SharedPreferences
4. Call `.initialize()` in `AppProviders` widget

---

## 📱 Supported Platforms

| Platform | Status | Notes |
|----------|--------|-------|
| Chrome | ✅ | Primary development target |
| Edge | ✅ | Full support |
| Firefox | ✅ | Full support |
| Safari | ✅ | Full support |
| Android | ✅ | API 21+ |
| iOS | ✅ | iOS 12+ |
| Windows | 🔶 | Experimental |
| macOS | 🔶 | Experimental |
| Linux | 🔶 | Experimental |

---

## 🐛 Debug Tips

### Check Analyzer Issues
```powershell
flutter analyze
```

### View Logs
```dart
debugPrint('My debug message');
```

### Performance Profiling
```powershell
flutter run --profile -d chrome
# Press 'v' to open DevTools
```

### Check for Updates
```powershell
flutter pub outdated
flutter pub upgrade
```

---

## 📊 Data Storage Keys

All data is stored in SharedPreferences:

```dart
// User & Auth
'current_user'          // Current logged-in user
'users'                 // All registered users

// Core Data
'classes'               // All classes
'students'              // All students
'grading_categories'    // Grading categories
'grade_items'           // Individual grade items
'student_scores'        // Student scores
'final_exams'           // Final exam scores
'change_history'        // Grade change history
'deleted_students'      // Soft-deleted students

// Settings
'theme_mode'            // Light/dark mode preference
```

---

## 🔐 Security Checklist

- [ ] Update application ID in `android/app/build.gradle`
- [ ] Don't commit `.env` files
- [ ] Don't commit API keys
- [ ] Use HTTPS for all external requests
- [ ] Validate all user inputs
- [ ] Sanitize data before storage
- [ ] Implement proper error handling

---

## 🚢 Pre-Deployment Checklist

### Before Building
- [ ] Update version in `pubspec.yaml`
- [ ] Update `CHANGELOG.md`
- [ ] Test all core features
- [ ] Test light/dark mode
- [ ] Test responsive layout
- [ ] Run `flutter analyze` (no errors)
- [ ] Run `flutter test` (if tests exist)

### Web Deployment
- [ ] Build: `flutter build web --release`
- [ ] Test build locally: `python -m http.server -d build/web`
- [ ] Configure Firebase/Netlify
- [ ] Deploy
- [ ] Test production URL

### Android Deployment
- [ ] Update version code in `pubspec.yaml`
- [ ] Build: `flutter build apk --release`
- [ ] Test on physical device
- [ ] Sign with release key (if publishing)
- [ ] Upload to Play Store

### iOS Deployment
- [ ] Update version in `pubspec.yaml`
- [ ] Build: `flutter build ios --release`
- [ ] Open in Xcode
- [ ] Archive and validate
- [ ] Upload to App Store Connect

---

## 📞 Getting Help

### Documentation
- Project README: `README.md`
- Developer Guide: `DEVELOPER_GUIDE.md`
- This guide: `QUICK_REFERENCE.md`

### Official Resources
- [Flutter Docs](https://docs.flutter.dev/)
- [Dart Docs](https://dart.dev/guides)
- [Material Design](https://m3.material.io/)

### Troubleshooting
1. Check `DEVELOPER_GUIDE.md` → Troubleshooting section
2. Run `flutter doctor` to check setup
3. Try `flutter clean` and rebuild
4. Search [Flutter GitHub Issues](https://github.com/flutter/flutter/issues)
5. Ask on [Flutter Discord](https://discord.gg/flutter)

---

**Pro Tip**: Keep this file bookmarked for quick access to common tasks! 📌

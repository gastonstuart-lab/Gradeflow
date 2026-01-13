# 🎓 GradeFlow

**Say goodbye to grading headaches!** GradeFlow is a robust web and mobile app designed to simplify high school grade management, offering intuitive input, intelligent calculations, and seamless final grade exports for teachers.

Built for **The Affiliated High School of Tunghai University** (東海大學附屬高級中學)

---

## ✨ Features

### 📚 **Class Management**
- Create and manage multiple classes with subject, year, and term information
- Archive old classes to keep your workspace organized
- Import entire rosters from CSV/Excel files
- AI-powered roster import using OpenAI (optional)

### 👨‍🎓 **Student Management**
- Add students individually or bulk import
- Track Chinese names and English names
- Seat numbers and class codes
- Soft delete with trash/restore functionality
- Photo support for student avatars

### 📊 **Advanced Grading System**
- **Flexible Categories**: Create custom grading categories (Homework, Quizzes, Projects, etc.)
- **Multiple Aggregation Methods**:
  - Average: Standard averaging
  - Sum: Total points
  - Best N: Keep only the top N scores
  - Drop Lowest N: Drop the worst N scores
- **Weighted Calculations**: Each category has customizable weight percentage
- **Final Exam Integration**: Separate final exam scores with configurable weighting
- **Real-time Grade Calculations**: Automatic computation of final grades
- **Change History**: Track all grade modifications with timestamps

### 🧑‍🏫 **Teacher Dashboard**
A comprehensive suite of classroom tools:
- **Name Picker**: Randomly select students for participation
- **Group Maker**: Automatically create balanced student groups
- **Seating Chart Designer**: Create custom seating arrangements with drag-and-drop
- **Attendance Tracker**: Mark present/late/absent by date
- **Participation Counter**: Track student engagement
- **Quick Poll**: Live A/B/C/D polling
- **Timer & Stopwatch**: Classroom time management
- **QR Code Generator**: Quick resource sharing

### 📤 **Export Capabilities**
- **CSV Export**: Compatible with Excel and Google Sheets
- **Excel Export**: Professional .xlsx format with formatting
- **PDF Export**: Print-ready reports with Unicode support (including Chinese characters)
- Customizable export templates

### 🎨 **Modern UI/UX**
- Material Design 3 with dynamic color scheme
- Light and Dark mode support
- Responsive layout for web, tablet, and mobile
- Smooth animations and transitions
- Animated glow borders for visual emphasis

---

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) (3.6.0 or higher)
- Chrome (for web development)
- Android Studio or Xcode (for mobile development)

### Installation

1. **Clone or extract the repository**
   ```bash
   cd c:\Dev\Gradeflow
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the app**
   
   For web (recommended for development):
   ```bash
   flutter run -d chrome
   ```
   
   For Android:
   ```bash
   flutter run -d <device_id>
   ```
   
   For iOS:
   ```bash
   flutter run -d <device_id>
   ```

### Demo Login

Use the **"Demo Login"** button on the login screen to instantly create and log in with a demo teacher account pre-populated with sample data.

Or create a new account with any email address (no password required for demo mode).

---

## 🔧 Configuration

### OpenAI Integration (Optional)

For AI-powered roster import, you can configure OpenAI API access:

1. Get an API key from [OpenAI Platform](https://platform.openai.com/api-keys)

2. Run with environment variables:
   ```bash
   flutter run -d chrome \
     --dart-define=OPENAI_PROXY_API_KEY=sk-your-key-here \
     --dart-define=OPENAI_PROXY_ENDPOINT=https://api.openai.com/v1/chat/completions
   ```

**Note**: The app works fully without OpenAI configuration. It will fall back to local parsing for roster imports.

---

## 📱 Platform Support

| Platform | Status |
|----------|--------|
| 🌐 Web | ✅ Fully Supported |
| 🤖 Android | ✅ Fully Supported |
| 🍎 iOS | ✅ Fully Supported |
| 🪟 Windows | 🔶 Experimental |
| 🍎 macOS | 🔶 Experimental |
| 🐧 Linux | 🔶 Experimental |

---

## 📦 Build for Production

### Web Deployment

1. **Build for web**:
   ```bash
   flutter build web --release
   ```

2. The output will be in `build/web/` directory

3. Deploy to any static hosting service:
   - Firebase Hosting
   - GitHub Pages
   - Netlify
   - Vercel
   - AWS S3 + CloudFront

   Example for Firebase:
   ```bash
   firebase init hosting
   firebase deploy
   ```

### Android APK

```bash
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

### iOS App

```bash
flutter build ios --release
```

Then open in Xcode to sign and distribute.

---

## 🗂️ Project Structure

```
lib/
├── main.dart                    # App entry point
├── nav.dart                     # Route configuration (GoRouter)
├── theme.dart                   # Material 3 theme and styling
│
├── components/                  # Reusable UI components
│   ├── animated_glow_border.dart
│   ├── class_card.dart
│   ├── pdf_web_viewer.dart
│   └── school_banner.dart
│
├── models/                      # Data models
│   ├── change_history.dart      # Grade change tracking
│   ├── class.dart               # Class entity
│   ├── deleted_student_entry.dart
│   ├── final_exam.dart          # Final exam scores
│   ├── grade_item.dart          # Individual grade items
│   ├── grading_category.dart    # Categories (Homework, Quiz, etc.)
│   ├── grading_template.dart
│   ├── student.dart             # Student entity
│   ├── student_score.dart       # Individual scores
│   └── user.dart                # Teacher/user entity
│
├── providers/                   # State management
│   └── app_providers.dart       # Provider configuration
│
├── screens/                     # UI screens
│   ├── category_management_screen.dart
│   ├── class_detail_screen.dart
│   ├── class_list_screen.dart
│   ├── deleted_students_screen.dart
│   ├── exam_input_screen.dart
│   ├── export_screen.dart
│   ├── final_results_screen.dart
│   ├── gradebook_screen.dart
│   ├── login_screen.dart
│   ├── student_detail_screen.dart
│   ├── student_list_screen.dart
│   └── teacher_dashboard_screen.dart
│
├── services/                    # Business logic
│   ├── auth_service.dart        # Authentication
│   ├── calculation_service.dart # Grade calculations
│   ├── class_service.dart       # Class CRUD
│   ├── export_service.dart      # CSV/Excel/PDF export
│   ├── file_import_service.dart # CSV/Excel parsing
│   ├── final_exam_service.dart
│   ├── grade_item_service.dart
│   ├── grading_category_service.dart
│   ├── grading_template_service.dart
│   ├── student_score_service.dart
│   ├── student_service.dart
│   └── student_trash_service.dart

```

---

## 🎯 Usage Guide

### Getting Started with GradeFlow

1. **Login**: Use Demo Login or create an account
2. **Create a Class**: Navigate to "My Classes" → "Add Class"
3. **Add Students**:
   - Import from CSV/Excel (recommended)
   - Or add individually
4. **Set Up Grading**:
   - Go to class → "Categories"
   - Create categories (e.g., Homework 30%, Quizzes 20%, Projects 50%)
   - Add grade items under each category
5. **Enter Grades**:
   - Use "Gradebook" for quick data entry
   - Or "Exam Input" for batch exam score entry
6. **View Results**: Check "Final Results" for computed grades
7. **Export**: Generate CSV, Excel, or PDF reports

### Importing Student Rosters

Your CSV/Excel file should have these columns (in any order):
- **Student ID** (required): Unique identifier
- **Chinese Name** (required): 學生姓名
- **English First Name** (required)
- **English Last Name** (required)
- **Seat No** (optional): 座號
- **Class** or **Form** (optional): 班級

Example CSV:
```csv
Student ID,Chinese Name,English First Name,English Last Name,Seat No,Class
101234,王小明,Ming,Wang,1,J2A
101235,李小華,Hua,Li,2,J2A
```

---

## 🛠️ Technology Stack

- **Framework**: Flutter 3.32.8
- **Language**: Dart 3.6.0
- **State Management**: Provider
- **Routing**: GoRouter
- **Local Storage**: SharedPreferences
- **File Handling**: file_picker, excel, csv
- **PDF Generation**: pdf package with Unicode support
- **Charts**: fl_chart
- **Fonts**: Google Fonts
- **Icons**: Material Icons, Cupertino Icons

---

## 🔐 Data & Privacy

- All data is stored **locally** on the device using SharedPreferences
- No backend server required
- No user data is transmitted except when using optional AI import (sends roster data to OpenAI)
- Perfect for privacy-conscious institutions

---

## 🐛 Known Limitations

- Dart analyzer may show errors until first build completes (these are normal)
- OpenAI API requires API key (feature is optional)
- PDF Chinese font loading requires internet connection (first use only)
- Desktop platforms (Windows/macOS/Linux) are experimental

---

## 🤝 Contributing

This is a private project built for The Affiliated High School of Tunghai University. If you'd like to contribute or report issues:

1. Test the feature thoroughly
2. Document the issue or enhancement
3. Provide clear reproduction steps

---

## 📄 License

Proprietary - All rights reserved
© 2025 The Affiliated High School of Tunghai University

---

## 🙏 Acknowledgments

- Built with [Flutter](https://flutter.dev)
- Icons from [Material Design](https://material.io/design)
- Fonts from [Google Fonts](https://fonts.google.com)
- CJK font support via [Noto Sans TC](https://fonts.google.com/noto/specimen/Noto+Sans+TC)

---

## 📞 Support

For questions or support, contact the development team at your school's IT department.

---

**Happy Teaching! 教學快樂！** 🎉

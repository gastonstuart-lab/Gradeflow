# Changelog

All notable changes to GradeFlow will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-01-12

### Added
- Complete class management system
  - Create, edit, archive classes
  - Support for multiple subjects, years, and terms
- Comprehensive student management
  - Individual student profiles
  - Bulk import via CSV/Excel
  - AI-powered roster import (OpenAI integration)
  - Soft delete with trash/restore functionality
  - Student photo support
- Advanced grading system
  - Flexible grading categories (Homework, Quizzes, Projects, etc.)
  - Multiple aggregation methods (Average, Sum, Best N, Drop Lowest N)
  - Weighted category calculations
  - Final exam integration
  - Real-time grade calculations
  - Complete change history tracking
- Teacher Dashboard with classroom tools
  - Random name picker
  - Automatic group maker
  - Seating chart designer with drag-and-drop
  - Attendance tracker
  - Participation counter
  - Quick poll (A/B/C/D)
  - Timer and stopwatch
  - QR code generator
- Export capabilities
  - CSV export (Excel/Google Sheets compatible)
  - Excel (.xlsx) export with formatting
  - PDF export with Unicode support (Chinese characters)
- Modern UI/UX
  - Material Design 3
  - Light and dark mode
  - Responsive layout for all screen sizes
  - Smooth animations and transitions
  - Animated glow borders
- Platform support
  - Web (fully supported)
  - Android (fully supported)
  - iOS (fully supported)
- Development infrastructure
  - Comprehensive README
  - Developer guide
  - Build scripts (PowerShell)
  - Deployment configurations (Firebase, Netlify)
  - Environment configuration examples

### Fixed
- Android application ID updated from placeholder to `com.gradeflow.app`

### Security
- All data stored locally on device
- No backend server required
- Optional OpenAI integration with user control

---

## [Unreleased]

### Planned Features
- Backend sync option (Firebase/Supabase)
- Multi-teacher collaboration
- Parent portal
- Mobile app optimizations
- Offline mode improvements
- Batch grade editing
- Custom export templates
- Email integration
- Calendar integration
- Gradebook formula builder

---

## Version History

- **1.0.0** (2025-01-12) - Initial release
  - Full-featured class and grade management system
  - Teacher dashboard tools
  - Export capabilities
  - Multi-platform support

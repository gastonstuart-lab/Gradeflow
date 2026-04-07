/// GradeFlow OS — App Model
///
/// Defines [OSApp] (the unit of an app/module in the OS) and [OSAppRegistry]
/// (the built-in app catalogue).  Every tool that exists in GradeFlow —
/// Gradebook, Seating, Whiteboard, Export, Messages, etc. — is registered
/// here as a first-class OS app.  The launcher, dock, and home surface all
/// read from this registry.
library os_app_model;

import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// APP ID CONSTANTS
// ─────────────────────────────────────────────────────────────────────────────

class OSAppId {
  OSAppId._();

  static const String home = 'gradeflow.home';
  static const String classes = 'gradeflow.classes';
  static const String gradebook = 'gradeflow.gradebook';
  static const String seating = 'gradeflow.seating';
  static const String whiteboard = 'gradeflow.whiteboard';
  static const String exports = 'gradeflow.exports';
  static const String messages = 'gradeflow.messages';
  static const String planner = 'gradeflow.planner';
  static const String attendance = 'gradeflow.attendance';
  static const String files = 'gradeflow.files';
  static const String reports = 'gradeflow.reports';
  static const String connected = 'gradeflow.connected';
  static const String teach = 'gradeflow.teach';
  static const String assistant = 'gradeflow.assistant';
  static const String settings = 'gradeflow.settings';
}

// ─────────────────────────────────────────────────────────────────────────────
// APP CATEGORY
// ─────────────────────────────────────────────────────────────────────────────

enum OSAppCategory {
  core, // Home, Teach, Classes
  classroom, // Whiteboard, Seating
  gradebook, // Gradebook, Export, Reports
  communication, // Messages, Attendance
  productivity, // Planner, Files
  system, // Admin, Settings, Connected
}

// ─────────────────────────────────────────────────────────────────────────────
// OSApp
// ─────────────────────────────────────────────────────────────────────────────

class OSApp {
  const OSApp({
    required this.id,
    required this.name,
    required this.icon,
    required this.category,
    this.description,
    this.route,
    this.color,
    this.requiresClassContext = false,
    this.hideInTeachMode = false,
    this.isSystemApp = false,
  });

  final String id;
  final String name;
  final IconData icon;
  final OSAppCategory category;
  final String? description;

  /// go_router route to navigate to when this app is opened.
  /// Null means the app is handled by the OS (e.g. Home).
  final String? route;

  /// Accent colour used for the app icon background.
  final Color? color;

  /// True if the app needs a class to be selected first.
  final bool requiresClassContext;

  /// True if this app should not be shown inside TeachSurface.
  final bool hideInTeachMode;

  final bool isSystemApp;
}

// ─────────────────────────────────────────────────────────────────────────────
// REGISTRY
// ─────────────────────────────────────────────────────────────────────────────

class OSAppRegistry {
  OSAppRegistry._();

  static const List<OSApp> all = [
    OSApp(
      id: OSAppId.home,
      name: 'Home',
      icon: Icons.home_rounded,
      category: OSAppCategory.core,
      description: 'Your teaching workspace',
      route: '/os/home',
      color: Color(0xFF5C8AFF),
      isSystemApp: true,
    ),
    OSApp(
      id: OSAppId.teach,
      name: 'Teach',
      icon: Icons.cast_for_education_rounded,
      category: OSAppCategory.core,
      description: 'Classroom mode — projection safe',
      route: '/os/teach',
      color: Color(0xFF5EC7E6),
    ),
    OSApp(
      id: OSAppId.classes,
      name: 'Classes',
      icon: Icons.class_rounded,
      category: OSAppCategory.core,
      description: 'All your class groups',
      route: '/classes',
      color: Color(0xFF58C78B),
    ),
    OSApp(
      id: OSAppId.whiteboard,
      name: 'Whiteboard',
      icon: Icons.draw_rounded,
      category: OSAppCategory.classroom,
      description: 'Freehand drawing & annotation',
      route: '/whiteboard',
      color: Color(0xFF7869F0),
    ),
    OSApp(
      id: OSAppId.seating,
      name: 'Seating',
      icon: Icons.event_seat_rounded,
      category: OSAppCategory.classroom,
      description: 'Room layout & seat assignments',
      route: null, // context-aware: needs classId
      color: Color(0xFFF4B45F),
      requiresClassContext: true,
    ),
    OSApp(
      id: OSAppId.gradebook,
      name: 'Gradebook',
      icon: Icons.menu_book_rounded,
      category: OSAppCategory.gradebook,
      description: 'Scores, grades & assessments',
      route: null, // context-aware: needs classId
      color: Color(0xFFEF7E67),
      requiresClassContext: true,
    ),
    OSApp(
      id: OSAppId.exports,
      name: 'Export',
      icon: Icons.picture_as_pdf_rounded,
      category: OSAppCategory.gradebook,
      description: 'PDFs, CSVs, and reports',
      route: null,
      color: Color(0xFF5EC7E6),
      requiresClassContext: true,
    ),
    OSApp(
      id: OSAppId.messages,
      name: 'Messages',
      icon: Icons.forum_rounded,
      category: OSAppCategory.communication,
      description: 'Staff and student communication',
      route: '/communication',
      color: Color(0xFF5C8AFF),
      hideInTeachMode: true,
    ),
    OSApp(
      id: OSAppId.planner,
      name: 'Planner',
      icon: Icons.calendar_month_rounded,
      category: OSAppCategory.productivity,
      description: 'Schedule, reminders & timetable',
      route: '/os/home',
      color: Color(0xFF58C78B),
    ),
    OSApp(
      id: OSAppId.attendance,
      name: 'Attendance',
      icon: Icons.how_to_reg_rounded,
      category: OSAppCategory.communication,
      description: 'Attendance tracking',
      route: null,
      color: Color(0xFFF4B45F),
      requiresClassContext: true,
    ),
    OSApp(
      id: OSAppId.files,
      name: 'Files',
      icon: Icons.folder_rounded,
      category: OSAppCategory.productivity,
      description: 'Class files & uploads',
      route: null,
      color: Color(0xFF9BA8BB),
      requiresClassContext: true,
    ),
    OSApp(
      id: OSAppId.reports,
      name: 'Reports',
      icon: Icons.analytics_rounded,
      category: OSAppCategory.gradebook,
      description: 'Class insights & analytics',
      route: null,
      color: Color(0xFF7869F0),
      requiresClassContext: true,
    ),
    OSApp(
      id: OSAppId.connected,
      name: 'Connected',
      icon: Icons.admin_panel_settings_rounded,
      category: OSAppCategory.system,
      description: 'Admin workspace & school link',
      route: '/admin',
      color: Color(0xFF66758C),
      hideInTeachMode: true,
      isSystemApp: true,
    ),
    OSApp(
      id: OSAppId.assistant,
      name: 'Assistant',
      icon: Icons.auto_awesome_rounded,
      category: OSAppCategory.core,
      description: 'AI-powered teaching assistant',
      route: null,
      color: Color(0xFF5C8AFF),
      isSystemApp: true,
    ),
  ];

  static OSApp? findById(String id) {
    for (final app in all) {
      if (app.id == id) return app;
    }
    return null;
  }

  static List<OSApp> byCategory(OSAppCategory category) =>
      all.where((a) => a.category == category).toList();

  /// Apps suitable for the dock (non-system, non-context-requiring).
  static List<OSApp> get dockDefaults => [
        findById(OSAppId.home)!,
        findById(OSAppId.classes)!,
        findById(OSAppId.whiteboard)!,
        findById(OSAppId.messages)!,
        findById(OSAppId.teach)!,
      ];

  /// Apps visible in the launcher (everything except purely internal OS apps).
  static List<OSApp> get launcherApps =>
      all.where((a) => a.id != OSAppId.home).toList();

  /// Apps safe to show inside TeachSurface.
  static List<OSApp> get teachModeApps =>
      all.where((a) => !a.hideInTeachMode).toList();
}

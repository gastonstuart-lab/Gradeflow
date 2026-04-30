/// GradeFlow OS — Design Tokens
///
/// Centralised colours, spacing, motion, and radius values for the OS shell
/// layer.  Surface-level screens (HomeSurface, ClassSurface, TeachSurface)
/// and every OS chrome component (dock, launcher, shade, assistant, idle)
/// must use these tokens so the OS has one coherent visual identity.

import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// COLOURS
// ─────────────────────────────────────────────────────────────────────────────

class OSColors {
  OSColors._();

  // Backgrounds
  static const Color darkBg = Color(0xFF090E16);
  static const Color darkBgAlt = Color(0xFF0D1320);
  static const Color darkSurface = Color(0xFF111827);
  static const Color darkSurfaceAlt = Color(0xFF151F2E);
  static const Color darkSurfaceElevated = Color(0xFF1C2436);
  static const Color darkPanel = Color(0xFF1A2130);

  static const Color lightBg = Color(0xFFF0F4FA);
  static const Color lightBgAlt = Color(0xFFE8EEF7);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceAlt = Color(0xFFF5F8FC);
  static const Color lightSurfaceElevated = Color(0xFFFFFFFF);
  static const Color lightPanel = Color(0xFFF7F9FD);

  // Text
  static const Color darkText = Color(0xFFF4F7FC);
  static const Color darkTextSecondary = Color(0xFF9BA8BB);
  static const Color darkTextMuted = Color(0xFF66758C);

  static const Color lightText = Color(0xFF0D1829);
  static const Color lightTextSecondary = Color(0xFF536070);
  static const Color lightTextMuted = Color(0xFF8899AA);

  // Borders
  static const Color darkBorder = Color(0xFF1E2C40);
  static const Color lightBorder = Color(0xFFD8E2EE);

  // Accents
  static const Color blue = Color(0xFF5C8AFF);
  static const Color blueSoft = Color(0xFF8DB2FF);
  static const Color indigo = Color(0xFF7869F0);
  static const Color amber = Color(0xFFF4B45F);
  static const Color green = Color(0xFF58C78B);
  static const Color coral = Color(0xFFEF7E67);
  static const Color cyan = Color(0xFF5EC7E6);

  // Status
  static const Color urgent = Color(0xFFEF5350);
  static const Color attention = Color(0xFFF4B45F);
  static const Color info = Color(0xFF5C8AFF);
  static const Color success = Color(0xFF58C78B);

  // Dock
  static const Color dockDark = Color(0xCC0D1420);
  static const Color dockLight = Color(0xCCF2F6FC);

  // Teach mode (projection-safe dark)
  static const Color teachBg = Color(0xFF060A10);
  static const Color teachSurface = Color(0xFF0E1520);
  static const Color teachAccent = Color(0xFF5EC7E6);

  static Color bg(bool dark) => dark ? darkBg : lightBg;
  static Color surface(bool dark) => dark ? darkSurface : lightSurface;
  static Color text(bool dark) => dark ? darkText : lightText;
  static Color textSecondary(bool dark) =>
      dark ? darkTextSecondary : lightTextSecondary;
  static Color border(bool dark) => dark ? darkBorder : lightBorder;
  static Color dock(bool dark) => dark ? dockDark : dockLight;
  static Color textMuted(bool dark) => dark ? darkTextMuted : lightTextMuted;
}

// ─────────────────────────────────────────────────────────────────────────────
// MOTION
// ─────────────────────────────────────────────────────────────────────────────

class OSMotion {
  OSMotion._();

  static const Duration instant = Duration(milliseconds: 100);
  static const Duration fast = Duration(milliseconds: 180);
  static const Duration normal = Duration(milliseconds: 260);
  static const Duration slow = Duration(milliseconds: 380);
  static const Duration xslow = Duration(milliseconds: 540);

  static const Curve ease = Curves.easeOutCubic;
  static const Curve easeIn = Curves.easeInCubic;
  static const Curve spring = Curves.elasticOut;
  static const Curve decel = Curves.decelerate;

  // Surface transitions
  static const Duration surfaceIn = Duration(milliseconds: 300);
  static const Duration surfaceOut = Duration(milliseconds: 220);
  static const Curve surfaceCurve = Curves.easeOutCubic;

  // Overlay (shade, launcher, assistant)
  static const Duration overlayIn = Duration(milliseconds: 320);
  static const Duration overlayOut = Duration(milliseconds: 240);
}

// ─────────────────────────────────────────────────────────────────────────────
// SPACING
// ─────────────────────────────────────────────────────────────────────────────

class OSSpacing {
  OSSpacing._();

  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;

  // Dock
  static const double dockHeight = 68.0;
  static const double dockBottomMargin = 16.0;
  static const double dockItemSize = 52.0;

  // App icon
  static const double appIconSize = 56.0;
  static const double appIconRadius = 14.0;

  // Widget card
  static const double widgetCorner = 20.0;
  static const double widgetPad = 16.0;
}

// ─────────────────────────────────────────────────────────────────────────────
// RADIUS
// ─────────────────────────────────────────────────────────────────────────────

class OSRadius {
  OSRadius._();

  static const double xs = 6.0;
  static const double sm = 10.0;
  static const double md = 14.0;
  static const double lg = 20.0;
  static const double xl = 28.0;
  static const double pill = 999.0;

  static BorderRadius get xsBr => BorderRadius.circular(xs);
  static BorderRadius get smBr => BorderRadius.circular(sm);
  static BorderRadius get mdBr => BorderRadius.circular(md);
  static BorderRadius get lgBr => BorderRadius.circular(lg);
  static BorderRadius get xlBr => BorderRadius.circular(xl);
  static BorderRadius get pillBr => BorderRadius.circular(pill);
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────────────────

extension OSBrightnessX on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}

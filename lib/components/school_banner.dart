import 'package:flutter/material.dart';
import 'package:gradeflow/theme.dart';

/// A slim, reusable school banner that shows your school logo under the AppBar.
/// Use it in AppBar.bottom as a PreferredSizeWidget.
class SchoolBannerBar extends StatelessWidget implements PreferredSizeWidget {
  final double height;
  const SchoolBannerBar({super.key, this.height = 56});

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    final String primaryLogo = 'assets/images/school_logo2.png';
    final String fallbackLogo = 'assets/images/school_logo2.png';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: isDark
              ? [
                  const Color(0xFF1A2332), // Deep navy
                  const Color(0xFF243447), // Slate blue
                  const Color(0xFF2A4A5A), // Muted teal-blue
                ]
              : [
                  const Color(0xFF1E3A5F), // Professional navy
                  const Color(0xFF2B5876), // Ocean blue
                  const Color(0xFF4E7B9B), // Soft steel blue
                ],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x15000000),
            offset: Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo with circular subtle background
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        offset: const Offset(0, 2),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Image.asset(
                    primaryLogo,
                    height: 64,
                    width: 64,
                    errorBuilder: (context, error, stack) =>
                        Image.asset(fallbackLogo, height: 64, width: 64),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                // Elegant separator
                Container(
                  height: 24,
                  width: 1.5,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.0),
                        Colors.white.withValues(alpha: 0.6),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                // School name with improved typography
                Flexible(
                  child: Text(
                    'The Affiliated High School of Tunghai University',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                      shadows: [
                        Shadow(
                          offset: const Offset(0, 1),
                          blurRadius: 2,
                          color: Colors.black.withValues(alpha: 0.25),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

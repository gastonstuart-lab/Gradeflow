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

    return Container(
      height: height,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            Color(0xFF3B5998), // Muted blue
            Color(0xFF4A6FA5), // Softer blue
            Color(0xFFEAB308), // Muted gold
            Color(0xFF2D3E50), // Soft charcoal
          ],
          stops: [0.0, 0.35, 0.65, 1.0],
        ),
        border: Border(
          bottom: BorderSide(
            color: Color(0x332D3E50),
            width: 1,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                primaryLogo,
                height: 36,
                errorBuilder: (context, error, stack) =>
                    Image.asset(fallbackLogo, height: 36),
              ),
              const SizedBox(width: AppSpacing.sm),
              const Icon(Icons.circle, size: 4, color: Color(0xFFFFFFFF)),
              const SizedBox(width: AppSpacing.sm),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: Text(
                  'The Affiliated High School of Tunghai University',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    shadows: [
                      Shadow(
                        offset: Offset(0.5, 0.5),
                        blurRadius: 3,
                        color: Color(0x40000000),
                      ),
                    ],
                  ),
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

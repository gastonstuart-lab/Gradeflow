import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:gradeflow/theme.dart';

class SchoolIdentityPill extends StatelessWidget {
  final bool compact;
  final double? maxWidth;
  final String schoolName;

  const SchoolIdentityPill({
    super.key,
    this.compact = false,
    this.maxWidth,
    this.schoolName = 'The Affiliated High School of Tunghai University',
  });

  @override
  Widget build(BuildContext context) {
    final String primaryLogo = 'assets/images/school_logo2.png';
    final String fallbackLogo = 'assets/images/school_logo2.png';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pillHeight = compact ? 40.0 : 46.0;
    final logoSize = compact ? 28.0 : 40.0;
    final radius = compact ? 999.0 : 999.0;
    final horizontalPadding = compact ? 14.0 : AppSpacing.lg;
    final borderColor = Colors.white.withValues(alpha: isDark ? 0.16 : 0.22);
    final panelGradient = isDark
        ? [
            const Color(0xFF17314A).withValues(alpha: compact ? 0.54 : 0.80),
            const Color(0xFF244E73).withValues(alpha: compact ? 0.48 : 0.70),
            const Color(0xFF3F7CA8).withValues(alpha: compact ? 0.42 : 0.62),
          ]
        : [
            const Color(0xFF1D4567).withValues(alpha: compact ? 0.56 : 0.84),
            const Color(0xFF2B638D).withValues(alpha: compact ? 0.48 : 0.76),
            const Color(0xFF79B3DA).withValues(alpha: compact ? 0.38 : 0.62),
          ];

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: maxWidth ?? (compact ? 460 : 820),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(
              sigmaX: compact ? 16 : 20, sigmaY: compact ? 16 : 20),
          child: Container(
            height: pillHeight,
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: panelGradient,
              ),
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: compact ? 0.10 : 0.12),
                  blurRadius: compact ? 14 : 18,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: const Color(0xFF86D7FF).withValues(
                    alpha: compact ? 0.08 : 0.12,
                  ),
                  blurRadius: compact ? 18 : 24,
                  spreadRadius: -10,
                ),
              ],
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned(
                  left: -20,
                  top: -14,
                  child: IgnorePointer(
                    child: Container(
                      width: compact ? 84 : 120,
                      height: compact ? 84 : 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Colors.white
                                .withValues(alpha: compact ? 0.12 : 0.18),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: compact ? 0.08 : 0.10),
                        Colors.transparent,
                        Colors.black.withValues(alpha: compact ? 0.04 : 0.05),
                      ],
                      stops: const [0.0, 0.42, 1.0],
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: logoSize,
                      height: logoSize,
                      padding: EdgeInsets.all(compact ? 4 : 6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white
                            .withValues(alpha: compact ? 0.08 : 0.10),
                        border: Border.all(
                          color: Colors.white
                              .withValues(alpha: compact ? 0.14 : 0.16),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white
                                .withValues(alpha: compact ? 0.06 : 0.08),
                            blurRadius: compact ? 10 : 16,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Image.asset(
                        primaryLogo,
                        errorBuilder: (context, error, stack) =>
                            Image.asset(fallbackLogo),
                      ),
                    ),
                    SizedBox(width: compact ? 10 : AppSpacing.md),
                    Container(
                      width: compact ? 1 : 1.2,
                      height: compact ? 18 : 24,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(alpha: 0.0),
                            Colors.white
                                .withValues(alpha: compact ? 0.42 : 0.52),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(width: compact ? 10 : AppSpacing.md),
                    Expanded(
                      child: Text(
                        schoolName,
                        style: ((compact
                                        ? context.textStyles.titleSmall
                                        : context.textStyles.titleMedium)
                                    ?.semiBold ??
                                TextStyle(
                                  fontSize: compact ? 14 : 16,
                                  fontWeight: FontWeight.w600,
                                ))
                            .withColor(Colors.white)
                            .copyWith(
                          letterSpacing: compact ? 0.05 : 0.15,
                          shadows: [
                            Shadow(
                              offset: const Offset(0, 1),
                              blurRadius: 3,
                              color: Colors.black.withValues(alpha: 0.18),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SchoolIdentityHeaderMark extends StatelessWidget {
  final String schoolName;
  final double? maxWidth;
  final bool compact;

  const SchoolIdentityHeaderMark({
    super.key,
    this.schoolName = 'The Affiliated High School of Tunghai University',
    this.maxWidth,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final badgeSize = compact ? 40.0 : 48.0;
    final textStyle = ((compact
                    ? context.textStyles.titleSmall
                    : context.textStyles.titleMedium)
                ?.semiBold ??
            TextStyle(
              fontSize: compact ? 15 : 17,
              fontWeight: FontWeight.w700,
            ))
        .withColor(Colors.white)
        .copyWith(
      letterSpacing: compact ? 0.08 : 0.14,
      shadows: [
        Shadow(
          offset: const Offset(0, 1),
          blurRadius: 4,
          color: Colors.black.withValues(alpha: 0.22),
        ),
      ],
    );

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth ?? 640),
      child: SizedBox(
        height: compact ? 46 : 56,
        child: Stack(
          alignment: Alignment.center,
          children: [
            IgnorePointer(
              child: Container(
                height: compact ? 32 : 38,
                margin: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.transparent,
                      Colors.white.withValues(alpha: isDark ? 0.06 : 0.10),
                      Colors.white.withValues(alpha: isDark ? 0.10 : 0.14),
                      Colors.white.withValues(alpha: isDark ? 0.06 : 0.10),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: _HeaderLightRule(
                    fadeLeft: true,
                    compact: compact,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: badgeSize,
                  height: badgeSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withValues(alpha: isDark ? 0.26 : 0.32),
                        Colors.white.withValues(alpha: isDark ? 0.12 : 0.16),
                      ],
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.22),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8BD9FF).withValues(alpha: 0.18),
                        blurRadius: 18,
                        spreadRadius: -2,
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.14),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(compact ? 7 : 8),
                    child: Image.asset('assets/images/school_logo2.png'),
                  ),
                ),
                const SizedBox(width: 14),
                Flexible(
                  flex: 5,
                  child: Text(
                    schoolName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: textStyle,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _HeaderLightRule(
                    fadeLeft: false,
                    compact: compact,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class SchoolHeroMasthead extends StatelessWidget {
  final String schoolName;
  final String subtitle;
  final double? maxWidth;
  final bool compact;

  const SchoolHeroMasthead({
    super.key,
    this.schoolName = 'The Affiliated High School of Tunghai University',
    this.subtitle = 'Teacher Dashboard',
    this.maxWidth,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final logoSize = compact ? 52.0 : 66.0;
    final titleStyle = ((compact
                    ? context.textStyles.titleMedium
                    : context.textStyles.headlineSmall)
                ?.semiBold ??
            TextStyle(
              fontSize: compact ? 18 : 24,
              fontWeight: FontWeight.w700,
            ))
        .withColor(Colors.white)
        .copyWith(
      letterSpacing: compact ? 0.06 : 0.12,
      shadows: [
        Shadow(
          offset: const Offset(0, 1),
          blurRadius: 6,
          color: Colors.black.withValues(alpha: 0.24),
        ),
      ],
    );

    final subtitleStyle = (context.textStyles.labelLarge?.semiBold ??
            const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))
        .withColor(Colors.white.withValues(alpha: 0.92))
        .copyWith(letterSpacing: 0.24);

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth ?? 760),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: logoSize,
            height: logoSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.white.withValues(alpha: isDark ? 0.30 : 0.36),
                  Colors.white.withValues(alpha: isDark ? 0.10 : 0.14),
                ],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.22),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF8BD9FF).withValues(alpha: 0.20),
                  blurRadius: 28,
                  spreadRadius: -4,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.16),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.all(compact ? 10 : 12),
              child: Image.asset('assets/images/school_logo2.png'),
            ),
          ),
          SizedBox(height: compact ? 8 : 10),
          Text(
            schoolName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: titleStyle,
          ),
          SizedBox(height: compact ? 8 : 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _HeaderAccentLine(compact: compact),
              const SizedBox(width: 10),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 12 : 14,
                  vertical: compact ? 7 : 8,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: Colors.white.withValues(alpha: isDark ? 0.10 : 0.12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.dashboard_customize_rounded,
                      size: compact ? 14 : 16,
                      color: Colors.white.withValues(alpha: 0.94),
                    ),
                    const SizedBox(width: 8),
                    Text(subtitle, style: subtitleStyle),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _HeaderAccentLine(compact: compact, mirrored: true),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderLightRule extends StatelessWidget {
  final bool fadeLeft;
  final bool compact;

  const _HeaderLightRule({
    required this.fadeLeft,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final colors = fadeLeft
        ? [
            Colors.transparent,
            Colors.white.withValues(alpha: 0.0),
            Colors.white.withValues(alpha: compact ? 0.18 : 0.22),
            const Color(0xFF8BD9FF).withValues(alpha: compact ? 0.18 : 0.22),
          ]
        : [
            const Color(0xFF8BD9FF).withValues(alpha: compact ? 0.18 : 0.22),
            Colors.white.withValues(alpha: compact ? 0.18 : 0.22),
            Colors.white.withValues(alpha: 0.0),
            Colors.transparent,
          ];

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          height: 1.2,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: LinearGradient(colors: colors),
          ),
        ),
        SizedBox(height: compact ? 4 : 5),
        Align(
          alignment: fadeLeft ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: compact ? 36 : 48,
            height: 1,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: Colors.white.withValues(alpha: 0.20),
            ),
          ),
        ),
      ],
    );
  }
}

class _HeaderAccentLine extends StatelessWidget {
  final bool compact;
  final bool mirrored;

  const _HeaderAccentLine({
    required this.compact,
    this.mirrored = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = mirrored
        ? [
            const Color(0xFF8BD9FF).withValues(alpha: compact ? 0.18 : 0.22),
            Colors.white.withValues(alpha: compact ? 0.16 : 0.20),
            Colors.transparent,
          ]
        : [
            Colors.transparent,
            Colors.white.withValues(alpha: compact ? 0.16 : 0.20),
            const Color(0xFF8BD9FF).withValues(alpha: compact ? 0.18 : 0.22),
          ];

    return Container(
      width: compact ? 36 : 56,
      height: 1.2,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: LinearGradient(colors: colors),
      ),
    );
  }
}

/// A slim, reusable school banner that shows your school logo under the AppBar.
/// Use it in AppBar.bottom as a PreferredSizeWidget.
class SchoolBannerBar extends StatelessWidget implements PreferredSizeWidget {
  final double height;

  const SchoolBannerBar({super.key, this.height = 56});

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.xs,
          AppSpacing.lg,
          AppSpacing.sm,
        ),
        child: Center(
          child: SchoolIdentityPill(
            maxWidth: 820,
          ),
        ),
      ),
    );
  }
}

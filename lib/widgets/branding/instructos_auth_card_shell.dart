import 'dart:ui';

import 'package:flutter/material.dart';

class InstructOSAuthCardShell extends StatelessWidget {
  final Widget child;
  final bool compact;

  const InstructOSAuthCardShell({
    super.key,
    required this.child,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(compact ? 30 : 34);

    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.44),
                blurRadius: 48,
                offset: const Offset(0, 24),
              ),
              BoxShadow(
                color: theme.colorScheme.primary.withValues(alpha: 0.14),
                blurRadius: 54,
              ),
            ],
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.18),
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF172033).withValues(alpha: 0.70),
                  const Color(0xFF0D1322).withValues(alpha: 0.56),
                  const Color(0xFF111827).withValues(alpha: 0.44),
                ],
                stops: const [0.0, 0.54, 1.0],
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  left: -80,
                  top: -90,
                  child: _GlowDisc(
                    size: compact ? 190 : 240,
                    color: const Color(0xFFA855F7),
                    opacity: 0.18,
                  ),
                ),
                Positioned(
                  right: -90,
                  bottom: -100,
                  child: _GlowDisc(
                    size: compact ? 210 : 260,
                    color: const Color(0xFF22D3EE),
                    opacity: 0.14,
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: radius,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.055),
                          width: 6,
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(compact ? 22 : 30),
                  child: child,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GlowDisc extends StatelessWidget {
  final double size;
  final Color color;
  final double opacity;

  const _GlowDisc({
    required this.size,
    required this.color,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 42, sigmaY: 42),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: opacity),
        ),
      ),
    );
  }
}

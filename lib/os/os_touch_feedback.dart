import 'package:flutter/material.dart';
import 'package:gradeflow/os/os_palette.dart';

class OSTouchFeedback extends StatefulWidget {
  const OSTouchFeedback({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.borderRadius,
    this.minSize,
    this.enableHoverLift = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final BorderRadius? borderRadius;
  final Size? minSize;
  final bool enableHoverLift;

  @override
  State<OSTouchFeedback> createState() => _OSTouchFeedbackState();
}

class _OSTouchFeedbackState extends State<OSTouchFeedback> {
  bool _pressed = false;
  bool _hovered = false;
  bool _longPressed = false;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final canHover = widget.enableHoverLift &&
        MediaQuery.of(context).size.shortestSide > 700;
    final liftY = canHover && _hovered ? -3.0 : 0.0;
    final scale = _pressed ? 0.975 : 1.0;

    Widget content = AnimatedContainer(
      duration: OSMotion.fast,
      curve: OSMotion.ease,
      constraints: widget.minSize != null
          ? BoxConstraints(
              minWidth: widget.minSize!.width,
              minHeight: widget.minSize!.height,
            )
          : null,
      transform: Matrix4.identity()..translate(0.0, liftY, 0.0),
      decoration: BoxDecoration(
        borderRadius: widget.borderRadius,
        boxShadow: canHover && _hovered
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: dark ? 0.24 : 0.08),
                  blurRadius: 14,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: AnimatedScale(
        duration: OSMotion.fast,
        curve: OSMotion.ease,
        scale: scale,
        child: AnimatedContainer(
          duration: OSMotion.fast,
          curve: OSMotion.ease,
          decoration: _longPressed
              ? BoxDecoration(
                  borderRadius: widget.borderRadius,
                  border: Border.all(
                    color: OSColors.blue.withValues(alpha: 0.35),
                    width: 1,
                  ),
                )
              : null,
          child: widget.child,
        ),
      ),
    );

    content = MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onLongPressStart: (_) => setState(() => _longPressed = true),
        onLongPressEnd: (_) {
          setState(() => _longPressed = false);
          widget.onLongPress?.call();
        },
        onTap: widget.onTap,
        child: content,
      ),
    );

    return content;
  }
}

import 'package:flutter/material.dart';

enum TeacherWhiteboardInk {
  chalk,
  amber,
  cyan,
  green,
  rose,
}

class TeacherWhiteboardController extends ChangeNotifier {
  final List<_WhiteboardStroke> _strokes = <_WhiteboardStroke>[];
  _WhiteboardStroke? _activeStroke;

  int get strokeCount => _strokes.length;
  bool get canUndo => _strokes.isNotEmpty;
  bool get isEmpty => _strokes.isEmpty;

  void startStroke({
    required Offset point,
    required Color color,
    required double width,
  }) {
    _activeStroke = _WhiteboardStroke(
      color: color,
      width: width,
      points: <Offset>[point],
    );
    _strokes.add(_activeStroke!);
    notifyListeners();
  }

  void appendPoint(Offset point) {
    final activeStroke = _activeStroke;
    if (activeStroke == null) return;
    activeStroke.points.add(point);
    notifyListeners();
  }

  void endStroke() {
    _activeStroke = null;
    notifyListeners();
  }

  void undo() {
    if (_strokes.isEmpty) return;
    _strokes.removeLast();
    _activeStroke = null;
    notifyListeners();
  }

  void clear() {
    if (_strokes.isEmpty) return;
    _strokes.clear();
    _activeStroke = null;
    notifyListeners();
  }
}

class TeacherWhiteboardWorkspace extends StatefulWidget {
  final TeacherWhiteboardController? controller;
  final bool compact;
  final bool fillAvailableHeight;
  final bool showStatusChips;
  final VoidCallback? onOpenFullscreen;
  final VoidCallback? onClose;
  final String title;

  const TeacherWhiteboardWorkspace({
    super.key,
    this.controller,
    this.compact = false,
    this.fillAvailableHeight = false,
    this.showStatusChips = true,
    this.onOpenFullscreen,
    this.onClose,
    this.title = 'Whiteboard',
  });

  @override
  State<TeacherWhiteboardWorkspace> createState() =>
      _TeacherWhiteboardWorkspaceState();
}

class _TeacherWhiteboardWorkspaceState
    extends State<TeacherWhiteboardWorkspace> {
  late final TeacherWhiteboardController _controller =
      widget.controller ?? TeacherWhiteboardController();
  late final bool _ownsController = widget.controller == null;
  TeacherWhiteboardInk _ink = TeacherWhiteboardInk.chalk;
  double _strokeWidth = 4.0;
  bool _showGrid = true;
  int? _pointerId;

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  Color _boardColor(ThemeData theme) {
    return theme.brightness == Brightness.dark
        ? const Color(0xFF0E1726)
        : const Color(0xFFF5F9FF);
  }

  Color _inkColor(ThemeData theme, TeacherWhiteboardInk ink) {
    final isDark = theme.brightness == Brightness.dark;
    switch (ink) {
      case TeacherWhiteboardInk.chalk:
        return isDark ? const Color(0xFFF8FBFF) : const Color(0xFF0F172A);
      case TeacherWhiteboardInk.amber:
        return isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309);
      case TeacherWhiteboardInk.cyan:
        return isDark ? const Color(0xFF67E8F9) : const Color(0xFF0F766E);
      case TeacherWhiteboardInk.green:
        return isDark ? const Color(0xFF86EFAC) : const Color(0xFF15803D);
      case TeacherWhiteboardInk.rose:
        return isDark ? const Color(0xFFFDA4AF) : const Color(0xFFBE123C);
    }
  }

  void _handlePointerDown(PointerDownEvent event) {
    _pointerId = event.pointer;
    _controller.startStroke(
      point: event.localPosition,
      color: _inkColor(Theme.of(context), _ink),
      width: _strokeWidth,
    );
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (_pointerId != event.pointer) return;
    _controller.appendPoint(event.localPosition);
  }

  void _handlePointerEnd([int? pointer]) {
    if (pointer != null && _pointerId != pointer) return;
    _pointerId = null;
    _controller.endStroke();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final boardHeight = widget.compact ? 340.0 : 520.0;
    final isDark = theme.brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final board = Container(
          height: widget.fillAvailableHeight ? null : boardHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.compact ? 20 : 28),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.54),
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _boardColor(theme),
                Color.lerp(
                    _boardColor(theme), Colors.black, isDark ? 0.12 : 0.02)!,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: theme.shadowColor.withValues(
                  alpha: isDark ? 0.28 : 0.08,
                ),
                blurRadius: 28,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(widget.compact ? 20 : 28),
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: _handlePointerDown,
              onPointerMove: _handlePointerMove,
              onPointerUp: (event) => _handlePointerEnd(event.pointer),
              onPointerCancel: (event) => _handlePointerEnd(event.pointer),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CustomPaint(
                    painter: _WhiteboardBackgroundPainter(
                      accent: theme.colorScheme.primary,
                      darkMode: isDark,
                      showGrid: _showGrid,
                    ),
                  ),
                  RepaintBoundary(
                    child: CustomPaint(
                      painter: _WhiteboardPainter(controller: _controller),
                      isComplex: true,
                      willChange: true,
                    ),
                  ),
                  IgnorePointer(
                    child: Align(
                      alignment: Alignment.bottomRight,
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: Colors.black.withValues(alpha: 0.18),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.10),
                            ),
                          ),
                          child: Text(
                            _controller.isEmpty
                                ? 'Tap and draw'
                                : '${_controller.strokeCount} stroke${_controller.strokeCount == 1 ? '' : 's'}',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.86)
                                  : theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: theme.colorScheme.primary.withValues(alpha: 0.16),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.26),
                    ),
                  ),
                  child: Icon(
                    Icons.draw_rounded,
                    color: theme.colorScheme.primary,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Pen, grid, and board controls stay ready.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.onOpenFullscreen != null) ...[
                  IconButton(
                    onPressed: widget.onOpenFullscreen,
                    icon: const Icon(Icons.open_in_full_rounded),
                  ),
                ],
                if (widget.onClose != null) ...[
                  TextButton.icon(
                    onPressed: widget.onClose,
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('Back'),
                  ),
                ],
              ],
            ),
            if (widget.showStatusChips) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _WhiteboardStatusChip(
                    label: widget.compact
                        ? 'Quick classroom tool'
                        : 'Full teaching canvas',
                    icon: Icons.flash_on_outlined,
                  ),
                  _WhiteboardStatusChip(
                    label: '${_inkLabel(_ink)} ink',
                    icon: Icons.edit_outlined,
                  ),
                  _WhiteboardStatusChip(
                    label: _strokeWidth == 3.0
                        ? 'Fine line'
                        : _strokeWidth == 4.0
                            ? 'Medium line'
                            : 'Bold line',
                    icon: Icons.line_weight_rounded,
                  ),
                  _WhiteboardStatusChip(
                    label: _showGrid ? 'Grid on' : 'Grid off',
                    icon: Icons.grid_4x4_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 14),
            ] else
              const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final ink in TeacherWhiteboardInk.values)
                  _WhiteboardInkChip(
                    label: _inkLabel(ink),
                    color: _inkColor(theme, ink),
                    selected: ink == _ink,
                    onTap: () => setState(() => _ink = ink),
                  ),
                _WhiteboardThicknessButton(
                  label: 'Fine',
                  selected: _strokeWidth == 3.0,
                  onTap: () => setState(() => _strokeWidth = 3.0),
                ),
                _WhiteboardThicknessButton(
                  label: 'Medium',
                  selected: _strokeWidth == 4.0,
                  onTap: () => setState(() => _strokeWidth = 4.0),
                ),
                _WhiteboardThicknessButton(
                  label: 'Bold',
                  selected: _strokeWidth == 6.0,
                  onTap: () => setState(() => _strokeWidth = 6.0),
                ),
                FilterChip(
                  label: const Text('Grid'),
                  avatar: const Icon(Icons.grid_4x4_rounded, size: 18),
                  selected: _showGrid,
                  onSelected: (selected) {
                    setState(() => _showGrid = selected);
                  },
                ),
                OutlinedButton.icon(
                  onPressed: _controller.canUndo ? _controller.undo : null,
                  icon: const Icon(Icons.undo_rounded),
                  label: const Text('Undo'),
                ),
                OutlinedButton.icon(
                  onPressed: _controller.isEmpty ? null : _controller.clear,
                  icon: const Icon(Icons.layers_clear_rounded),
                  label: const Text('Clear'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (widget.fillAvailableHeight) Expanded(child: board) else board,
          ],
        );
      },
    );
  }

  String _inkLabel(TeacherWhiteboardInk ink) {
    switch (ink) {
      case TeacherWhiteboardInk.chalk:
        return 'Chalk';
      case TeacherWhiteboardInk.amber:
        return 'Amber';
      case TeacherWhiteboardInk.cyan:
        return 'Cyan';
      case TeacherWhiteboardInk.green:
        return 'Green';
      case TeacherWhiteboardInk.rose:
        return 'Rose';
    }
  }
}

class _WhiteboardInkChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _WhiteboardInkChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: color.withValues(alpha: selected ? 0.18 : 0.08),
          border: Border.all(
            color: selected
                ? color.withValues(alpha: 0.44)
                : color.withValues(alpha: 0.20),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WhiteboardStatusChip extends StatelessWidget {
  final String label;
  final IconData icon;

  const _WhiteboardStatusChip({
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.14),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _WhiteboardThicknessButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _WhiteboardThicknessButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}

class _WhiteboardPainter extends CustomPainter {
  final TeacherWhiteboardController controller;

  _WhiteboardPainter({
    required this.controller,
  }) : super(repaint: controller);

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in controller._strokes) {
      if (stroke.points.isEmpty) continue;
      final paint = Paint()
        ..color = stroke.color
        ..strokeWidth = stroke.width
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true;

      if (stroke.points.length == 1) {
        canvas.drawCircle(stroke.points.first, stroke.width * 0.5,
            paint..style = PaintingStyle.fill);
        continue;
      }

      final path = Path()
        ..moveTo(stroke.points.first.dx, stroke.points.first.dy);
      for (int index = 1; index < stroke.points.length; index++) {
        final previous = stroke.points[index - 1];
        final current = stroke.points[index];
        final midPoint = Offset(
          (previous.dx + current.dx) / 2,
          (previous.dy + current.dy) / 2,
        );
        path.quadraticBezierTo(
            previous.dx, previous.dy, midPoint.dx, midPoint.dy);
      }
      path.lineTo(stroke.points.last.dx, stroke.points.last.dy);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WhiteboardPainter oldDelegate) {
    return oldDelegate.controller != controller;
  }
}

class _WhiteboardBackgroundPainter extends CustomPainter {
  final Color accent;
  final bool darkMode;
  final bool showGrid;

  const _WhiteboardBackgroundPainter({
    required this.accent,
    required this.darkMode,
    required this.showGrid,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (showGrid) {
      final majorPaint = Paint()
        ..color = Colors.white.withValues(alpha: darkMode ? 0.045 : 0.08)
        ..strokeWidth = 1;

      const spacing = 28.0;
      for (double x = spacing; x < size.width; x += spacing) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), majorPaint);
      }
      for (double y = spacing; y < size.height; y += spacing) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), majorPaint);
      }
    }

    final highlightPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          accent.withValues(alpha: darkMode ? 0.10 : 0.08),
          Colors.transparent,
        ],
      ).createShader(Offset.zero & size);

    canvas.drawRect(Offset.zero & size, highlightPaint);
  }

  @override
  bool shouldRepaint(covariant _WhiteboardBackgroundPainter oldDelegate) {
    return oldDelegate.accent != accent ||
        oldDelegate.darkMode != darkMode ||
        oldDelegate.showGrid != showGrid;
  }
}

class _WhiteboardStroke {
  final Color color;
  final double width;
  final List<Offset> points;

  _WhiteboardStroke({
    required this.color,
    required this.width,
    required this.points,
  });
}

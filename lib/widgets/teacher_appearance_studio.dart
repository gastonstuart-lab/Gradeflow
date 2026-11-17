import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gradeflow/providers/app_providers.dart';
import 'package:gradeflow/services/teacher_appearance_controller.dart';

/// A compact live theme selector. Existing Home wallpaper choices are retained.
Future<void> showTeacherAppearanceStudio(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => const _AppearanceSheet(),
  );
}

class _AppearanceSheet extends StatelessWidget {
  const _AppearanceSheet();

  @override
  Widget build(BuildContext context) {
    final choices = context.watch<TeacherAppearanceController>();
    final themeMode = context.watch<ThemeModeNotifier>();
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: 0.85,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 28),
          children: [
            Text('Personalisation Studio',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text('Make GradeFlow yours. Changes preview instantly and are saved for this teacher on this device.',
                style: TextStyle(color: colors.onSurfaceVariant)),
            const SizedBox(height: 22),
            Text('Appearance', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, dimensions) {
                if (dimensions.maxWidth < 440) {
                  return Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final mode in ThemeMode.values)
                      ChoiceChip(
                        label: Text(mode == ThemeMode.system
                            ? 'System'
                            : mode == ThemeMode.light ? 'Light' : 'Dark'),
                        selected: themeMode.themeMode == mode,
                        onSelected: (_) =>
                            context.read<ThemeModeNotifier>().setThemeMode(mode),
                      ),
                  ]);
                }
                return SegmentedButton<ThemeMode>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: ThemeMode.light, label: Text('Light'), icon: Icon(Icons.light_mode_outlined)),
                    ButtonSegment(value: ThemeMode.dark, label: Text('Dark'), icon: Icon(Icons.dark_mode_outlined)),
                    ButtonSegment(value: ThemeMode.system, label: Text('System'), icon: Icon(Icons.settings_brightness)),
                  ],
                  selected: {themeMode.themeMode},
                  onSelectionChanged: (values) =>
                      context.read<ThemeModeNotifier>().setThemeMode(values.first),
                );
              },
            ),
            const SizedBox(height: 24),
            Text('Live workspace preview', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            const _LiveWorkspacePreview(),
            const SizedBox(height: 24),
            Text('Choose your background — applies to all pages', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            LayoutBuilder(builder: (context, constraints) {
              final width = constraints.maxWidth >= 520
                  ? (constraints.maxWidth - 24) / 3
                  : (constraints.maxWidth - 12) / 2;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final entry in TeacherAppearanceController.backgrounds.entries)
                    SizedBox(
                      width: width,
                      child: _BackgroundChoice(
                        label: entry.value,
                        id: entry.key,
                        accent: choices.accentColor,
                        selected: choices.background == entry.key,
                        onTap: () => context.read<TeacherAppearanceController>().setBackground(entry.key),
                      ),
                    ),
                ],
              );
            }),
            const SizedBox(height: 22),
            Text('Accent colour', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            Wrap(spacing: 12, runSpacing: 12, children: [
              for (final entry in TeacherAppearanceController.accents.entries)
                Tooltip(
                  message: entry.key,
                  child: ChoiceChip(
                    label: Text(entry.key[0].toUpperCase() + entry.key.substring(1)),
                    selected: choices.accent == entry.key,
                    avatar: CircleAvatar(radius: 10, backgroundColor: entry.value),
                    onSelected: (_) => context.read<TeacherAppearanceController>().setAccent(entry.key),
                  ),
                ),
            ]),
            const SizedBox(height: 24),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Show ambient backgrounds'),
              subtitle: const Text('Keeps classroom tools, score cells and controls readable'),
              value: choices.enabled,
              onChanged: context.read<TeacherAppearanceController>().setEnabled,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Show on Teaching Studio screens'),
              subtitle: const Text(
                'Optional and reduced in strength so the board and lesson controls stay clear. Off by default.',
              ),
              value: choices.showInTeachMode,
              onChanged: choices.enabled
                  ? context.read<TeacherAppearanceController>().setShowInTeachMode
                  : null,
            ),
            const SizedBox(height: 10),
                        Text('Background strength: ${(choices.intensity * 100).round()}%',
                style: Theme.of(context).textTheme.titleSmall),
            Slider(
              value: choices.intensity,
              min: 0,
              max: 1,
              divisions: 20,
              label: '${(choices.intensity * 100).round()}%',
              onChanged: choices.enabled
                  ? context.read<TeacherAppearanceController>().setIntensity
                  : null,
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: context.read<TeacherAppearanceController>().reset,
              icon: const Icon(Icons.restart_alt),
              label: const Text('Restore appearance defaults'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveWorkspacePreview extends StatelessWidget {
  const _LiveWorkspacePreview();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<TeacherAppearanceController>();
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final accent = settings.accentColor;
    final foreground = dark ? const Color(0xFFEDF3FF) : const Color(0xFF122136);
    final base = dark ? const Color(0xFF101827) : const Color(0xFFF4F7FC);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        height: 162,
        decoration: BoxDecoration(
          color: base,
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(children: [
          if (settings.enabled && settings.background != 'minimal')
            Positioned.fill(
              child: Opacity(
                opacity: settings.intensity,
                child: CustomPaint(
                  painter: _PreviewPainter(settings.background, accent),
                ),
              ),
            ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      width: 10, height: 10,
                      decoration: BoxDecoration(
                        color: accent, borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('GradeFlow', style: TextStyle(
                      color: foreground, fontWeight: FontWeight.w800,
                    )),
                    const Spacer(),
                    Container(
                      width: 62, height: 12,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 18),
                  Row(children: [
                    Expanded(child: _PreviewPanel(color: foreground, accent: accent)),
                    const SizedBox(width: 10),
                    Expanded(child: _PreviewPanel(color: foreground, accent: accent)),
                    const SizedBox(width: 10),
                    Expanded(child: _PreviewPanel(color: foreground, accent: accent)),
                  ]),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _PreviewPanel extends StatelessWidget {
  const _PreviewPanel({required this.color, required this.accent});
  final Color color;
  final Color accent;

  @override
  Widget build(BuildContext context) => Container(
    height: 76,
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.83),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 30, height: 5,
        decoration: BoxDecoration(color: accent,
          borderRadius: BorderRadius.circular(4))),
      const SizedBox(height: 11),
      Container(height: 5, decoration: BoxDecoration(
        color: color.withValues(alpha: 0.30),
        borderRadius: BorderRadius.circular(4))),
      const SizedBox(height: 6),
      FractionallySizedBox(widthFactor: 0.65,
        child: Container(height: 5, decoration: BoxDecoration(
          color: color.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(4)))),
    ]),
  );
}

class _BackgroundChoice extends StatelessWidget {
  const _BackgroundChoice({
    required this.id, required this.label, required this.accent,
    required this.selected, required this.onTap,
  });

  final String id;
  final String label;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? const Color(0xFF0D172A) : const Color(0xFFF2F6FB);
    return Semantics(
      button: true,
      selected: selected,
      label: '$label background',
      child: Material(
        color: base,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: 116,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? accent : Theme.of(context).colorScheme.outlineVariant,
                width: selected ? 2 : 1,
              ),
            ),
            child: Stack(children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CustomPaint(painter: _PreviewPainter(id, accent)),
                ),
              ),
              Positioned(
                left: 10, right: 10, bottom: 9,
                child: Text(label,
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF172033),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  )),
              ),
              if (selected)
                Positioned(right: 8, top: 8,
                  child: Icon(Icons.check_circle, color: accent, size: 21)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _PreviewPainter extends CustomPainter {
  const _PreviewPainter(this.id, this.color);
  final String id;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withValues(alpha: 0.26);
    if (id == 'boxes') {
        paint.style = PaintingStyle.stroke;
        for (double x = 0; x < size.width; x += 20) {
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
        }
        for (double y = 0; y < size.height; y += 20) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
        }
        canvas.drawRect(const Rect.fromLTWH(60, 20, 20, 20),
          Paint()..color = color.withValues(alpha: 0.40));
    } else if (id == 'aurora') {
        canvas.drawOval(
          Rect.fromLTWH(size.width * 0.08, -20, size.width * 0.75, size.height),
          Paint()..shader = RadialGradient(colors: [
            color.withValues(alpha: 0.55),
            Colors.transparent,
          ]).createShader(Offset.zero & size),
        );
    } else if (id == 'dots') {
        for (double x = 12; x < size.width; x += 17) {
          for (double y = 9; y < size.height; y += 17) {
            canvas.drawCircle(Offset(x, y), 1.3, paint);
          }
        }
    } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(12, 12, size.width * .52, 35), const Radius.circular(10)),
          Paint()..color = color.withValues(alpha: 0.10),
        );
    }
  }

  @override
  bool shouldRepaint(covariant _PreviewPainter oldDelegate) =>
      oldDelegate.id != id || oldDelegate.color != color;
}

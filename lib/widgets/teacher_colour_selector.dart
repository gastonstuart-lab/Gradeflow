import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gradeflow/services/teacher_appearance_controller.dart';

/// Reusable colour choices for compact Settings and full Personalisation.
class TeacherColourSelector extends StatelessWidget {
  const TeacherColourSelector({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final appearance = context.watch<TeacherAppearanceController>();
    final border = Theme.of(context).colorScheme.outlineVariant;
    return Wrap(
      spacing: compact ? 10 : 12,
      runSpacing: 11,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final choice in TeacherAppearanceController.accents.entries)
          Tooltip(
            message: choice.key,
            child: Semantics(
              button: true,
              selected: appearance.accent == choice.key,
              label: 'Use ${choice.key} colour',
              child: InkWell(
                onTap: () =>
                    context.read<TeacherAppearanceController>().setAccent(choice.key),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: compact ? 38 : 42,
                  height: compact ? 38 : 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: choice.value,
                    border: Border.all(
                      color: appearance.accent == choice.key
                          ? Theme.of(context).colorScheme.onSurface
                          : border,
                      width: appearance.accent == choice.key ? 3 : 1,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: appearance.accent == choice.key
                      ? Icon(
                          Icons.check_rounded,
                          size: 21,
                          color: choice.value.computeLuminance() > .45
                              ? const Color(0xFF172033) : Colors.white,
                        )
                      : null,
                ),
              ),
            ),
          ),
        OutlinedButton.icon(
          key: const Key('custom-colour-button'),
          onPressed: () => showTeacherCustomColourPicker(context),
          icon: Icon(Icons.colorize_rounded,
              size: 18, color: appearance.isCustomAccent
                  ? appearance.customAccent
                  : null),
          label: Text(appearance.isCustomAccent
              ? 'Custom ${TeacherAppearanceController.toHex(appearance.customAccent)}'
              : 'Custom…'),
          style: OutlinedButton.styleFrom(
            side: BorderSide(
              color: appearance.isCustomAccent
                  ? appearance.themeAccent(Theme.of(context).brightness)
                  : border,
            ),
          ),
        ),
      ],
    );
  }
}

/// Opaque RGB colour editor. Changes only on Apply, never on Cancel.
Future<void> showTeacherCustomColourPicker(BuildContext context) async {
  final appearance = context.read<TeacherAppearanceController>();
  final initial = appearance.isCustomAccent
      ? appearance.customAccent : appearance.accentColor;
  var hsv = HSVColor.fromColor(initial);

  final selected = await showDialog<Color>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) {
        final preview = hsv.toColor();
        return AlertDialog(
          title: const Text('Choose your colour'),
          content: SizedBox(
            width: 345,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  label: 'Selected colour ${TeacherAppearanceController.toHex(preview)}',
                  child: Container(
                    height: 66,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: preview,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      TeacherAppearanceController.toHex(preview),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: preview.computeLuminance() > .45
                            ? const Color(0xFF172033)
                            : Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text('Hue', style: Theme.of(dialogContext).textTheme.labelLarge),
                Slider(
                  key: const Key('colour-hue'),
                  value: hsv.hue,
                  min: 0,
                  max: 360,
                  divisions: 72,
                  label: '${hsv.hue.round()}°',
                  onChanged: (v) =>
                      setDialogState(() => hsv = hsv.withHue(v)),
                ),
                Text('Saturation',
                    style: Theme.of(dialogContext).textTheme.labelLarge),
                Slider(
                  value: hsv.saturation,
                  min: 0,
                  max: 1,
                  divisions: 20,
                  label: '${(hsv.saturation * 100).round()}%',
                  onChanged: (v) =>
                      setDialogState(() => hsv = hsv.withSaturation(v)),
                ),
                Text('Brightness',
                    style: Theme.of(dialogContext).textTheme.labelLarge),
                Slider(
                  value: hsv.value,
                  min: 0,
                  max: 1,
                  divisions: 20,
                  label: '${(hsv.value * 100).round()}%',
                  onChanged: (v) =>
                      setDialogState(() => hsv = hsv.withValue(v)),
                ),
                Text(
                  'Preview the colour before applying it to buttons, accents and glowing backgrounds.',
                  style: Theme.of(dialogContext).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('apply-custom-colour'),
              onPressed: () => Navigator.of(dialogContext).pop(preview),
              child: const Text('Apply colour'),
            ),
          ],
        );
      },
    ),
  );
  if (selected != null && context.mounted) {
    context.read<TeacherAppearanceController>().setCustomAccent(selected);
  }
}

import 'package:flutter/material.dart';
import 'package:gradeflow/widgets/teacher_colour_selector.dart';
import 'package:provider/provider.dart';
import 'package:gradeflow/providers/app_providers.dart';
import 'package:gradeflow/services/teacher_appearance_controller.dart';
import 'package:gradeflow/widgets/teacher_appearance_studio.dart';

/// A single small entry point for the most obvious display settings.
/// More detailed settings remain one tap away in Personalisation Studio.
Future<void> showTeacherQuickSettings(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: MediaQuery.sizeOf(sheetContext).height * .84,
        ),
        child: const SingleChildScrollView(
          child: _QuickSettingsSheet(),
        ),
      ),
    ),
  );
}

class _QuickSettingsSheet extends StatelessWidget {
  const _QuickSettingsSheet();

  @override
  Widget build(BuildContext context) {
    final appearance = context.watch<TeacherAppearanceController>();
    final theme = context.watch<ThemeModeNotifier>();
    final colors = Theme.of(context).colorScheme;
    final keyboardBottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 2, 20, 20 + keyboardBottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune_rounded, color: colors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Quick settings',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    )),
              ),
              IconButton(
                tooltip: 'Close settings',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Personalise any page. Your teaching tools stay unchanged.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 19),
          Text('Appearance', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 7),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final mode in ThemeMode.values)
                ChoiceChip(
                  label: Text(switch (mode) {
                    ThemeMode.light => 'Light',
                    ThemeMode.dark => 'Dark',
                    ThemeMode.system => 'System',
                  }),
                  selected: theme.themeMode == mode,
                  onSelected: (_) =>
                      context.read<ThemeModeNotifier>().setThemeMode(mode),
                ),
            ],
          ),
          const SizedBox(height: 17),
          Text('Background', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 7),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final background
                  in TeacherAppearanceController.backgrounds.entries)
                ChoiceChip(
                  label: Text(
                    background.key == 'boxes'
                        ? 'Neon boxes'
                        : background.value,
                  ),
                  selected: appearance.background == background.key,
                  onSelected: (_) =>
                      context.read<TeacherAppearanceController>()
                          .setBackground(background.key),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Text('Colours', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 9),
          const TeacherColourSelector(compact: true),
          const SizedBox(height: 6),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Background effects'),
            subtitle: const Text('Off keeps the workspace simple'),
            value: appearance.enabled,
            onChanged:
                context.read<TeacherAppearanceController>().setEnabled,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      context.read<TeacherAppearanceController>().reset(),
                  icon: const Icon(Icons.restart_alt_rounded, size: 18),
                  label: const Text('Reset'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: () {
                    // Close this compact menu before opening full details.
                    final navigator = Navigator.of(context);
                    final parent = navigator.context;
                    navigator.pop();
                    // The navigator remains mounted after the sheet closes.
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (parent.mounted) {
                        showTeacherAppearanceStudio(parent);
                      }
                    });
                  },
                  icon: const Icon(Icons.palette_outlined, size: 19),
                  label: const Text('More personalisation'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

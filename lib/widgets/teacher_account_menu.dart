import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:gradeflow/nav.dart';
import 'package:gradeflow/providers/app_providers.dart';
import 'package:gradeflow/services/auth_service.dart';
import 'package:gradeflow/services/teacher_appearance_controller.dart';
import 'package:gradeflow/services/browser_fullscreen_stub.dart'
    if (dart.library.js_interop) 'package:gradeflow/services/browser_fullscreen_web.dart'
    as display;
import 'package:gradeflow/widgets/teacher_colour_selector.dart';

/// A single anchored, compact account menu for authenticated OS pages.
///
/// Navigation remains in the dock. The account menu owns appearance,
/// desktop/display settings and a safely confirmed sign-out.
class TeacherAccountMenu extends StatefulWidget {
  const TeacherAccountMenu({super.key});

  @override
  State<TeacherAccountMenu> createState() => _TeacherAccountMenuState();
}

class _TeacherAccountMenuState extends State<TeacherAccountMenu> {
  final MenuController _controller = MenuController();
  bool _showAppearance = false;
  bool _advancedOpen = false;

  void _toggleMenu() {
    if (_controller.isOpen) {
      _controller.close();
    } else {
      setState(() {
        _showAppearance = false;
        _advancedOpen = false;
      });
      _controller.open();
    }
  }

  void _closeMenu() {
    if (_controller.isOpen) _controller.close();
  }

  Future<void> _confirmSignOut() async {
    _closeMenu();
    final auth = context.read<AuthService?>();
    if (auth == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out of GradeFlow?'),
        content: const Text(
          'You can sign in again later. Saved teaching work will not be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await auth.logout();
    if (!mounted) return;
    if (auth.isAuthenticated) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Could not sign out. Try again.')),
      );
      return;
    }
    context.go(AppRoutes.home);
  }

  Future<void> _toggleFullscreen() async {
    _closeMenu();
    final success = await display.toggleBrowserFullscreen();
    if (!success && mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text(
          'Fullscreen was blocked. Press F11 or use an installed desktop app.',
        )),
      );
    }
  }

  Future<void> _showDesktopHelp() {
    _closeMenu();
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Open GradeFlow as a desktop app'),
        content: const Text(
          'On Windows, open GradeFlow in Microsoft Edge, choose the … '
          'menu and select Apps → Install this site as an app. '
          'Launch it from Start for a separate window without browser tabs. '
          'Fullscreen also remains available from this menu.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService?>();
    final teacher = auth?.currentUser;
    final name = teacher?.fullName.trim() ?? '';
    final shortName = name.isNotEmpty ? name.split(' ').first : 'Teacher';
    final email = teacher?.email.trim() ?? '';
    final initial = name.isEmpty ? 'T' : name.characters.first.toUpperCase();
    final palette = Theme.of(context).colorScheme;
    final availableWidth = MediaQuery.sizeOf(context).width;
    final panelWidth = (availableWidth - 28).clamp(260.0, 368.0);
    final maxHeight = (MediaQuery.sizeOf(context).height - 100)
        .clamp(240.0, 720.0);

    return MenuAnchor(
      controller: _controller,
      alignmentOffset: const Offset(0, 8),
      style: MenuStyle(
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        backgroundColor: WidgetStatePropertyAll(palette.surface),
        elevation: const WidgetStatePropertyAll(12),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
      ),
      menuChildren: [
        SizedBox(
          width: panelWidth,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: SingleChildScrollView(
              primary: false,
              child: _showAppearance
                  ? _appearancePane(context)
                  : _accountPane(context, name, email, initial),
            ),
          ),
        ),
      ],
      builder: (context, controller, child) => Tooltip(
        message: 'Account and settings',
        child: InkWell(
          key: const Key('teacher-account-settings-button'),
          onTap: _toggleMenu,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
            decoration: BoxDecoration(
              color: palette.surface.withValues(alpha: .94),
              border: Border.all(color: palette.outlineVariant),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _avatar(initial, palette),
                if (availableWidth >= 1100) ...[
                  const SizedBox(width: 7),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 78),
                    child: Text(shortName,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w800)),
                  ),
                ],
                const SizedBox(width: 5),
                Icon(Icons.keyboard_arrow_down_rounded,
                  size: 16, color: palette.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _avatar(String initial, ColorScheme palette) => Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: palette.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(initial, style: TextStyle(
          fontWeight: FontWeight.w900,
          color: palette.onPrimaryContainer,
          fontSize: 15,
        )),
      );

  Widget _accountPane(
    BuildContext context,
    String name,
    String email,
    String initial,
  ) {
    final palette = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 15, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            _avatar(initial, palette),
            const SizedBox(width: 11),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name.isEmpty ? 'Teacher account' : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  )),
                if (email.isNotEmpty)
                  Text(email,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: palette.onSurfaceVariant,
                    )),
              ],
            )),
          ]),
          const Divider(height: 24),
          _menuAction(
            key: const Key('account-appearance-option'),
            icon: Icons.palette_outlined,
            title: 'Appearance & colours',
            subtitle: 'Themes, neon backgrounds and custom colours',
            onTap: () => setState(() => _showAppearance = true),
          ),
          if (display.browserFullscreenAvailable) ...[
            _menuAction(
              key: const Key('account-fullscreen-option'),
              icon: Icons.fullscreen_rounded,
              title: 'Toggle fullscreen',
              subtitle: 'Expand or restore the desktop window',
              onTap: () => unawaited(_toggleFullscreen()),
            ),
            if (MediaQuery.sizeOf(context).width >= 600)
              _menuAction(
                key: const Key('account-desktop-option'),
                icon: Icons.desktop_windows_outlined,
                title: 'Open as desktop app',
                subtitle: 'Windows and Microsoft Edge',
                onTap: () => unawaited(_showDesktopHelp()),
              ),
          ],
          const Divider(height: 20),
          _menuAction(
            key: const Key('account-signout-option'),
            icon: Icons.logout_rounded,
            title: 'Sign out',
            subtitle: 'Leave this teacher account safely',
            destructive: true,
            onTap: (context.watch<AuthService?>()?.isAuthenticated ?? false)
                ? () => unawaited(_confirmSignOut())
                : null,
          ),
        ],
      ),
    );
  }

  Widget _menuAction({
    Key? key,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    bool destructive = false,
  }) {
    final theme = Theme.of(context);
    final colour = destructive
        ? theme.colorScheme.error : theme.colorScheme.primary;
    return ListTile(
      key: key,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      dense: true,
      enabled: onTap != null,
      leading: Icon(icon, color: colour),
      title: Text(title,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: destructive ? theme.colorScheme.error : null,
        )),
      subtitle: Text(subtitle, maxLines: 2),
      trailing: const Icon(Icons.chevron_right_rounded, size: 17),
      onTap: onTap,
    );
  }

  Widget _appearancePane(BuildContext context) {
    final appearance = context.watch<TeacherAppearanceController?>();
    final modes = context.watch<ThemeModeNotifier?>();
    final palette = Theme.of(context).colorScheme;
    if (appearance == null || modes == null) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Text('Appearance settings are unavailable.'),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton.icon(
            key: const Key('account-settings-back'),
            onPressed: () => setState(() => _showAppearance = false),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 14),
            label: const Text('Back to settings'),
          ),
          Text('Appearance & colours',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('Changes apply instantly across your workspace.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: palette.onSurfaceVariant)),
          const SizedBox(height: 17),
          Text('Appearance', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 7),
          Wrap(spacing: 7, runSpacing: 6, children: [
            for (final mode in ThemeMode.values)
              ChoiceChip(
                label: Text(switch (mode) {
                  ThemeMode.light => 'Light',
                  ThemeMode.dark => 'Dark',
                  ThemeMode.system => 'System',
                }),
                selected: modes.themeMode == mode,
                onSelected: (_) =>
                    context.read<ThemeModeNotifier>().setThemeMode(mode),
              ),
          ]),
          const SizedBox(height: 14),
          Text('Background', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 7),
          Wrap(spacing: 7, runSpacing: 6, children: [
            for (final option in TeacherAppearanceController.backgrounds.entries)
              ChoiceChip(
                label: Text(option.key == 'boxes' ? 'Neon boxes' : option.value),
                selected: appearance.background == option.key,
                onSelected: (_) => context.read<TeacherAppearanceController>()
                    .setBackground(option.key),
              ),
          ]),
          const SizedBox(height: 16),
          Text('Choose your colours',
            style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 10),
          const TeacherColourSelector(compact: true),
          const SizedBox(height: 14),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text('Background effects'),
            value: appearance.enabled,
            onChanged: context.read<TeacherAppearanceController>().setEnabled,
          ),
          OutlinedButton.icon(
            onPressed: () => setState(() => _advancedOpen = !_advancedOpen),
            icon: Icon(_advancedOpen
                ? Icons.keyboard_arrow_up_rounded
                : Icons.tune_rounded),
            label: Text(_advancedOpen ? 'Less options' : 'Advanced options'),
          ),
          if (_advancedOpen) ...[
            const SizedBox(height: 9),
            Text('Background intensity: ${(appearance.intensity * 100).round()}%',
              style: Theme.of(context).textTheme.bodySmall),
            Slider(
              value: appearance.intensity,
              divisions: 20,
              min: 0,
              max: 1,
              onChanged: appearance.enabled
                  ? context.read<TeacherAppearanceController>().setIntensity
                  : null,
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Show effects in Teaching Studio'),
              subtitle: const Text('Subtle, off by default'),
              value: appearance.showInTeachMode,
              onChanged: appearance.enabled
                  ? context.read<TeacherAppearanceController>()
                      .setShowInTeachMode
                  : null,
            ),
            TextButton.icon(
              onPressed: context.read<TeacherAppearanceController>().reset,
              icon: const Icon(Icons.restart_alt_rounded),
              label: const Text('Restore appearance defaults'),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _closeMenu,
              child: const Text('Done'),
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:gradeflow/nav.dart';
import 'package:gradeflow/services/auth_service.dart';
import 'package:gradeflow/services/browser_fullscreen_stub.dart'
    if (dart.library.js_interop) 'package:gradeflow/services/browser_fullscreen_web.dart'
    as display;
import 'package:gradeflow/widgets/teacher_quick_settings.dart';

enum _AccountAction { appearance, signOut }

/// Compact account/settings entry for every authenticated OS screen.
/// The approved Home header hosts this directly; other OS routes host it
/// in the shell so the dock remains dedicated to navigation.
class TeacherAccountMenu extends StatelessWidget {
  const TeacherAccountMenu({super.key});

  Future<void> _confirmSignOut(BuildContext context) async {
    final auth = context.read<AuthService?>();
    if (auth == null) return;
    final answer = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out of GradeFlow?'),
        content: const Text(
          'You can sign in again later. Your saved teaching work is not deleted.',
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
    if (answer != true || !context.mounted) return;
    await auth.logout();
    if (!context.mounted) return;
    if (auth.isAuthenticated) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Could not sign out. Please try again.')),
      );
      return;
    }
    context.go(AppRoutes.home);
  }

  Future<void> _tryFullscreen(BuildContext context) async {
    final ok = await display.toggleBrowserFullscreen();
    if (!ok && context.mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text(
          'Fullscreen was blocked by the browser. Try the button again or press F11.',
        )),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService?>();
    final name = auth?.currentUser?.fullName.trim() ?? '';
    final email = auth?.currentUser?.email.trim() ?? '';
    final initial = name.isEmpty ? 'T' : name.characters.first.toUpperCase();
    final style = Theme.of(context);
    final colors = style.colorScheme;

    return PopupMenuButton<_AccountAction>(
      key: const Key('teacher-account-settings-button'),
      tooltip: 'Account and settings',
      position: PopupMenuPosition.under,
      offset: const Offset(0, 5),
      constraints: const BoxConstraints(minWidth: 254, maxWidth: 300),
      onSelected: (action) {
        if (action == _AccountAction.appearance) {
          // Defer until the popup is removed, keeping one modal open at a time.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) showTeacherQuickSettings(context);
          });
        } else if (action == _AccountAction.signOut) {
          unawaited(_confirmSignOut(context));
        }
      },
      itemBuilder: (menuContext) => [
        PopupMenuItem<_AccountAction>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name.isEmpty ? 'Teacher account' : name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: style.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors.onSurface,
                ),
              ),
              if (email.isNotEmpty)
                Text(email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: style.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  )),
              const SizedBox(height: 6),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<_AccountAction>(
          key: Key('account-appearance-option'),
          value: _AccountAction.appearance,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: Icon(Icons.palette_outlined),
            title: Text('Appearance & colours'),
            subtitle: Text('Theme, backgrounds and neon effects'),
          ),
        ),
        if (display.browserFullscreenAvailable)
          PopupMenuItem<_AccountAction>(
            key: const Key('account-fullscreen-option'),
            // requestFullscreen needs to be inside this real user click.
            onTap: () => unawaited(_tryFullscreen(context)),
            child: const ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(Icons.fullscreen_rounded),
              title: Text('Toggle fullscreen'),
              subtitle: Text('Press Esc to exit'),
            ),
          ),
        const PopupMenuDivider(),
        PopupMenuItem<_AccountAction>(
          key: const Key('account-signout-option'),
          value: _AccountAction.signOut,
          enabled: auth != null && auth.isAuthenticated,
          child: const ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: Icon(Icons.logout_rounded),
            title: Text('Sign out'),
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surface.withValues(alpha: 0.94),
            shape: BoxShape.circle,
            border: Border.all(color: colors.outlineVariant),
          ),
          child: SizedBox(
            width: 40, height: 40,
            child: Center(child: Text(
              initial,
              style: style.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w900,
                color: colors.primary,
              ),
            )),
          ),
        ),
      ),
    );
  }
}

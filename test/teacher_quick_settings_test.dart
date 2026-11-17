import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gradeflow/providers/app_providers.dart';
import 'package:gradeflow/services/teacher_appearance_controller.dart';
import 'package:gradeflow/widgets/teacher_quick_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('small settings entry shows immediate theme and background options',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final theme = ThemeModeNotifier();
    final appearance = TeacherAppearanceController();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ThemeModeNotifier>.value(value: theme),
          ChangeNotifierProvider<TeacherAppearanceController>.value(
              value: appearance),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: FilledButton(
                  onPressed: () => showTeacherQuickSettings(context),
                  child: const Text('Settings'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Quick settings'), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
    expect(find.text('Neon boxes'), findsOneWidget);
    expect(find.text('More personalisation'), findsOneWidget);
    expect(find.text('Colours'), findsOneWidget);
    expect(find.byKey(const Key('custom-colour-button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('custom-colour-button')));
    await tester.pumpAndSettle();
    expect(find.text('Choose your colour'), findsOneWidget);
    await tester.tap(find.byKey(const Key('colour-hue')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('apply-custom-colour')));
    await tester.pumpAndSettle();
    expect(appearance.accent, 'custom');

    await tester.tap(find.text('Neon boxes'));
    await tester.pumpAndSettle();
    expect(appearance.background, 'boxes');

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(theme.themeMode, ThemeMode.dark);

    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(appearance.background, 'minimal');
    await tester.pumpWidget(const SizedBox.shrink());
    theme.dispose();
    appearance.dispose();
  });
}

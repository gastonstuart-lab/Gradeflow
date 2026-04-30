import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/os/os_palette.dart';

void main() {
  testWidgets('OS brightness follows the app theme, not platform brightness',
      (tester) async {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(
      binding.platformDispatcher.clearPlatformBrightnessTestValue,
    );

    bool? resolvedDark;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        home: Builder(
          builder: (context) {
            resolvedDark = context.isDark;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(resolvedDark, isFalse);
  });
}

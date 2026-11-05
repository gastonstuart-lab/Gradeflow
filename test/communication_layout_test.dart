import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/repositories/repository_factory.dart';
import 'package:gradeflow/screens/communication_hub_screen.dart';
import 'package:gradeflow/services/auth_service.dart';
import 'package:gradeflow/services/communication_service.dart';
import 'package:gradeflow/theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final size in [const Size(1280, 720), const Size(390, 844)]) {
    testWidgets('channel list and conversation remain usable at $size',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      RepositoryFactory.useLocal();
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final auth = AuthService();
      await auth.register(
          'fixture@example.test', 'Synthetic teacher', 'Test school');
      final messages = CommunicationService()..syncAuth(auth);
      await messages.load();
      await tester.pumpWidget(MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthService>.value(value: auth),
            ChangeNotifierProvider<CommunicationService>.value(value: messages),
          ],
          child: MaterialApp(
              theme: lightTheme, home: const CommunicationHubScreen())));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text(messages.selectedMessages.first.text), findsWidgets);
      if (size.width < 900) {
        await tester.tap(find.text('Show channels'));
        await tester.pumpAndSettle();
      }
      expect(find.text('Staff channels'), findsOneWidget);
      expect(find.text(messages.channels[1].name), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      messages.dispose();
      auth.dispose();
    });
  }
}

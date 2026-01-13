import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gradeflow/theme.dart';
import 'package:gradeflow/nav.dart';
import 'package:gradeflow/providers/app_providers.dart';
import 'package:gradeflow/services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _authInitScheduled = false;

  @override
  Widget build(BuildContext context) {
    return AppProviders(
      child: Consumer<ThemeModeNotifier>(
        builder: (context, themeModeNotifier, _) {
          final authService = context.watch<AuthService>();

          if (!_authInitScheduled && !authService.isInitialized && !authService.isLoading) {
            _authInitScheduled = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              try {
                context.read<AuthService>().initialize();
              } catch (e) {
                debugPrint('Deferred auth initialize failed: $e');
                _authInitScheduled = false;
              }
            });
          }

          return MaterialApp.router(
            title: 'The Affiliated High School of Tunghai University',
            debugShowCheckedModeBanner: false,
            theme: lightTheme,
            darkTheme: darkTheme,
            themeMode: themeModeNotifier.themeMode,
            routerConfig: AppRouter.router,
          );
        },
      ),
    );
  }
}

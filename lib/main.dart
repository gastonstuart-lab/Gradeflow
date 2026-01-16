import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:gradeflow/theme.dart';
import 'package:gradeflow/nav.dart';
import 'package:gradeflow/providers/app_providers.dart';
import 'package:gradeflow/services/auth_service.dart';
import 'package:gradeflow/services/firebase_service.dart';
import 'package:responsive_framework/responsive_framework.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    // Makes the web app accessible (and allows Playwright to use role/text selectors).
    RendererBinding.instance.ensureSemantics();
  }

  // Initialize Firebase if configured (safe even if firebase_options.dart missing)
  await FirebaseService.maybeInitialize();

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

          if (!_authInitScheduled &&
              !authService.isInitialized &&
              !authService.isLoading) {
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
            builder: (context, child) {
              return ResponsiveBreakpoints.builder(
                child: child!,
                breakpoints: const [
                  Breakpoint(start: 0, end: 479, name: PHONE),
                  Breakpoint(start: 480, end: 767, name: TABLET),
                  Breakpoint(start: 768, end: 1023, name: 'TABLET_LANDSCAPE'),
                  Breakpoint(start: 1024, end: 1439, name: DESKTOP),
                  Breakpoint(start: 1440, end: double.infinity, name: 'XL'),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:provider/provider.dart';
import 'package:gradeflow/components/gradeflow_launch_experience.dart';
import 'package:gradeflow/config/gradeflow_product_config.dart';
import 'package:gradeflow/config/planner_v2_staging_safety.dart';
import 'package:gradeflow/config/gradeflow_existing_project_preview.dart';
import 'package:gradeflow/config/planner_v2_firebase_config.dart';
import 'package:gradeflow/config/planner_v2_emulator_safety.dart';
import 'package:gradeflow/theme.dart';
import 'package:gradeflow/nav.dart';
import 'package:gradeflow/providers/app_providers.dart';
import 'package:gradeflow/services/auth_service.dart';
import 'package:gradeflow/services/firebase_service.dart';
import 'package:responsive_framework/responsive_framework.dart';

void main() async {
  // Configure path routing before Flutter initializes the browser binding.
  // Otherwise the initial platform route can be captured as '/' and a class
  // deep link is lost before GoRouter is created.
  if (kIsWeb) {
    usePathUrlStrategy();
  }
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    // Makes the web app accessible (and allows Playwright to use role/text selectors).
    RendererBinding.instance.ensureSemantics();
  }

  // An approved preview build may use the existing Firebase project, but
  // ONLY from the designated Hosting preview-channel URL. If someone
  // accidentally publishes it on the live Hosting channel, show a blocked
  // screen before Firebase, authentication, providers or data can load.
  if (!GradeFlowExistingProjectPreview.mayStart(
    enabled: GradeFlowExistingProjectPreview.enabled,
    stagingEnabled: PlannerV2StagingSafety.stagingEnabled,
    emulatorEnabled: PlannerV2EmulatorSafety.enabled,
    isWeb: kIsWeb,
    projectId: GradeFlowExistingProjectPreview.enabled &&
            !PlannerV2StagingSafety.stagingEnabled
        ? PlannerV2FirebaseConfig.currentPlatform.projectId
        : '',
    originHost: Uri.base.host,
  )) {
    runApp(const _PlannerV2StagingBlocked(
      reason: 'GradeFlow V2 review is allowed only on the designated '
          'Firebase Hosting preview channel. The live site is unchanged.',
    ));
    return;
  }

  // Emulator connections are never allowed on public domains or any
  // Firebase project other than this fixed, synthetic-only demo project.
  if (!PlannerV2EmulatorSafety.permitted(
    enabled: PlannerV2EmulatorSafety.enabled,
    stagingEnabled: PlannerV2StagingSafety.stagingEnabled,
    projectId: PlannerV2StagingSafety.requiredStagingProjectId,
    originHost: Uri.base.host,
  )) {
    runApp(const _PlannerV2StagingBlocked(
      reason: 'Local Firebase emulators are allowed only on localhost '
          'with the synthetic demo GradeFlow staging project.',
    ));
    return;
  }

  // Fail closed BEFORE building providers/auth. The normal application
  // continues unchanged; a staging build pointing to the production
  // Firebase project must never load school or student data.
  final reason = PlannerV2StagingSafety.stagingEnabled &&
          !PlannerV2FirebaseConfig.stagingConfigured
      ? 'Planner V2 staging requires complete, separate Firebase web '
          'configuration. No authentication or student data was loaded.'
      : PlannerV2StagingSafety.blockingReason(
          stagingEnabled: PlannerV2StagingSafety.stagingEnabled,
          configuredProjectId:
              PlannerV2FirebaseConfig.currentPlatform.projectId,
          requiredStagingProjectId:
              PlannerV2StagingSafety.requiredStagingProjectId,
        );
  if (reason != null) {
    runApp(_PlannerV2StagingBlocked(reason: reason));
    return;
  }

  if (PlannerV2StagingSafety.protectedTestingMode) {
    // Preview and staging must never degrade into local-only login when Firebase
    // initialization fails. Normal production startup stays unchanged.
    final ok = await FirebaseService.maybeInitialize();
    if (!ok) {
      runApp(const _PlannerV2StagingBlocked(
        reason: 'Staging Firebase could not be initialized. '
            'Authentication and classroom data have not been loaded.',
      ));
      return;
    }
  }

  // Initialize Firebase if configured. On web this must not block runApp(),
  // because browser SDK startup can stall behind network or extension state.
  if (!kIsWeb) {
    await FirebaseService.maybeInitialize();
  }

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

          // On a deep link or browser refresh, restore the Firebase session
          // before constructing GoRouter. Otherwise the first redirect sees
          // a signed-out user and discards the requested class URL.
          if (!authService.isInitialized) {
            return const MaterialApp(
              home: Scaffold(
                body: Center(child: CircularProgressIndicator()),
              ),
            );
          }

          return MaterialApp.router(
            title: GradeFlowProductConfig.appName,
            debugShowCheckedModeBanner: false,
            theme: lightTheme,
            darkTheme: darkTheme,
            themeMode: themeModeNotifier.themeMode,
            routerConfig: AppRouter.router,
            builder: (context, child) {
              return ResponsiveBreakpoints.builder(
                child: GradeFlowLaunchGate(
                  child: child!,
                ),
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

class _PlannerV2StagingBlocked extends StatelessWidget {
  const _PlannerV2StagingBlocked({required this.reason});

  final String reason;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GradeFlow — staging blocked',
      home: Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.shield_outlined, size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    'Staging safety check',
                    style: TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(reason, textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

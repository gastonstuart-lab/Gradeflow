/// Isolated native-Flutter visual acceptance build for teacher appearance.
///
/// This entrypoint NEVER initializes Firebase, real repositories, records or
/// authentic accounts. It reuses the actual account menu, colour selector,
/// theme controller and interactive ambient painter from GradeFlow V2.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:gradeflow/models/user.dart';
import 'package:gradeflow/nav.dart' show AppRoutes;
import 'package:gradeflow/theme.dart';
import 'package:gradeflow/providers/app_providers.dart';
import 'package:gradeflow/services/auth_service.dart';
import 'package:gradeflow/services/teacher_appearance_controller.dart';
import 'package:gradeflow/widgets/teacher_account_menu.dart';
import 'package:gradeflow/widgets/teacher_appearance_overlay.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Browser review uses the same accessible semantics as the real V2 app.
  RendererBinding.instance.ensureSemantics();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>(
          create: (_) => _SampleOnlyAuth(),
        ),
        ChangeNotifierProxyProvider<AuthService, TeacherAppearanceController>(
          create: (_) => TeacherAppearanceController(),
          update: (_, auth, old) {
            old ??= TeacherAppearanceController();
            old.syncAuth(auth);
            return old;
          },
        ),
        ChangeNotifierProxyProvider<AuthService, ThemeModeNotifier>(
          create: (_) => ThemeModeNotifier(),
          update: (_, auth, old) {
            old ??= ThemeModeNotifier();
            old.syncAuth(auth);
            return old;
          },
        ),
      ],
      child: const _NativeReviewApp(),
    ),
  );
}

class _SampleOnlyAuth extends AuthService {
  bool _signedIn = true;

  @override
  bool get isAuthenticated => _signedIn;

  @override
  User? get currentUser => _signedIn
      ? User(
          userId: 'native-preview-only',
          email: 'teacher@example.test',
          fullName: 'Sample Teacher',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        )
      : null;

  @override
  Future<void> logout() async {
    _signedIn = false;
    notifyListeners();
  }

  void enterPreview() {
    _signedIn = true;
    notifyListeners();
  }
}

final _router = GoRouter(
  initialLocation: AppRoutes.osHome,
  routes: [
    GoRoute(path: AppRoutes.home, builder: (_, __) => const _DemoSignIn()),
    GoRoute(path: AppRoutes.osHome,
        builder: (_, __) => const _SampleTeacherPage(section: 'home')),
    GoRoute(path: '/review/planner',
        builder: (_, __) => const _SampleTeacherPage(section: 'planner')),
    GoRoute(path: '/review/gradebook',
        builder: (_, __) => const _SampleTeacherPage(section: 'gradebook')),
  ],
);

class _NativeReviewApp extends StatelessWidget {
  const _NativeReviewApp();

  @override
  Widget build(BuildContext context) {
    final appearance = context.watch<TeacherAppearanceController>();
    final mode = context.watch<ThemeModeNotifier>();
    ThemeData apply(ThemeData base, Brightness brightness) =>
        appearance.accent == 'indigo'
            ? base
            : base.copyWith(
                colorScheme: base.colorScheme.copyWith(
                  primary: appearance.themeAccent(brightness),
                  onPrimary: brightness == Brightness.dark
                      ? const Color(0xFF101827) : Colors.white,
                ),
              );

    return MaterialApp.router(
      title: 'GradeFlow Native Menu Review — no real school data',
      debugShowCheckedModeBanner: false,
      theme: apply(lightTheme, Brightness.light),
      darkTheme: apply(darkTheme, Brightness.dark),
      themeMode: mode.themeMode,
      routerConfig: _router,
    );
  }
}

class _DemoSignIn extends StatelessWidget {
  const _DemoSignIn();

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.school_rounded, size: 45),
                      const SizedBox(height: 14),
                      Text('GradeFlow preview',
                          style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 11),
                      const Text(
                        'This native Flutter review has fictional information only. '
                        'It does not connect to GradeFlow, Firebase or real accounts.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: () {
                          context.read<AuthService>().letPreviewSignIn();
                          context.go(AppRoutes.osHome);
                        },
                        icon: const Icon(Icons.arrow_forward_rounded),
                        label: const Text('Enter sample workspace'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

extension on AuthService {
  void letPreviewSignIn() {
    (this as _SampleOnlyAuth).enterPreview();
  }
}

class _SampleTeacherPage extends StatefulWidget {
  const _SampleTeacherPage({required this.section});
  final String section;

  @override
  State<_SampleTeacherPage> createState() => _SampleTeacherPageState();
}

class _SampleTeacherPageState extends State<_SampleTeacherPage> {
  final ValueNotifier<Offset?> _pointer = ValueNotifier<Offset?>(null);

  @override
  void dispose() {
    _pointer.dispose();
    super.dispose();
  }

  String get _heading => switch (widget.section) {
        'planner' => 'Your teaching week.',
        'gradebook' => 'Grading, without distractions.',
        _ => 'Good evening, Teacher.',
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPhone = MediaQuery.sizeOf(context).width < 650;
    return Scaffold(
      body: Listener(
        onPointerHover: (event) => _pointer.value = event.localPosition,
        onPointerMove: (event) => _pointer.value = event.localPosition,
        onPointerDown: (event) => _pointer.value = event.localPosition,
        child: Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(color: theme.scaffoldBackgroundColor),
            ),
            // Fictional sample content imitates density, not the V2 pages.
            Positioned.fill(
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                      isPhone ? 18 : 44, 22, isPhone ? 18 : 44, 112),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1160),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Container(
                              width: 37, height: 37,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.school_rounded,
                                  color: Colors.white, size: 21),
                            ),
                            const SizedBox(width: 11),
                            Text('GradeFlow',
                              style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800)),
                            const Spacer(),
                            const SizedBox(width: 64),
                          ]),
                          const SizedBox(height: 23),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainer,
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 11, vertical: 7),
                              child: Text(
                                'NATIVE FLUTTER PREVIEW · FICTIONAL RECORDS',
                                style: TextStyle(
                                    fontSize: 10, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                          const SizedBox(height: 56),
                          Text(_heading,
                            style: theme.textTheme.displaySmall?.copyWith(
                                fontWeight: FontWeight.w900)),
                          const SizedBox(height: 11),
                          Text('Open the small teacher account button in the top right '
                            'to customise colours, neon backgrounds and display '
                            'settings. Only sample information is shown.',
                            style: theme.textTheme.bodyMedium),
                          const SizedBox(height: 24),
                          if (widget.section == 'home') ...[
                            _stats(theme, isPhone),
                            const SizedBox(height: 16),
                            _card('Upcoming lessons', [
                              _item('J2 Science · Metals', '09:15'),
                              _item('EEP · Literature', '11:10'),
                              _item('Performance Arts', '14:20'),
                            ]),
                          ] else if (widget.section == 'planner') ...[
                            _stats(theme, isPhone),
                            const SizedBox(height: 16),
                            _card('Thursday · Plan', [
                              _item('J1 English · Vocabulary', '08:15'),
                              _item('J2 Science · Conductivity', '09:15'),
                              _item('Performance Arts · Rehearsal', '13:20'),
                            ]),
                          ] else ...[
                            _card('J2 Science · Sample Gradebook', [
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  columns: const [
                                    DataColumn(label: Text('Student')),
                                    DataColumn(label: Text('Homework')),
                                    DataColumn(label: Text('Quiz')),
                                    DataColumn(label: Text('Participation')),
                                  ],
                                  rows: const [
                                    DataRow(cells: [
                                      DataCell(Text('Alex Chen')),
                                      DataCell(Text('95')),
                                      DataCell(Text('91')),
                                      DataCell(Text('96')),
                                    ]),
                                    DataRow(cells: [
                                      DataCell(Text('Jamie Lin')),
                                      DataCell(Text('100')),
                                      DataCell(Text('92')),
                                      DataCell(Text('95')),
                                    ]),
                                    DataRow(cells: [
                                      DataCell(Text('Sam Wu')),
                                      DataCell(Text('88')),
                                      DataCell(Text('94')),
                                      DataCell(Text('98')),
                                    ]),
                                  ],
                                ),
                              ),
                            ]),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: TeacherAppearanceOverlay(
                pointer: _pointer,
                attenuation: widget.section == 'gradebook'
                    ? .5
                    : widget.section == 'planner' ? .75 : 1,
              ),
            ),
            Positioned(
              top: MediaQuery.paddingOf(context).top + 13,
              right: isPhone ? 15 : 40,
              child: const TeacherAccountMenu(),
            ),
            Positioned(
              bottom: 18,
              left: 12,
              right: 12,
              child: Center(
                child: Card(
                  elevation: 8,
                  child: Padding(
                    padding: const EdgeInsets.all(5),
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 5,
                      children: [
                        _tab(context, 'Home', Icons.home_rounded,
                            AppRoutes.osHome, widget.section == 'home'),
                        _tab(context, 'Planner', Icons.calendar_today_rounded,
                            '/review/planner', widget.section == 'planner'),
                        _tab(context, 'Gradebook', Icons.grade_rounded,
                            '/review/gradebook', widget.section == 'gradebook'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tab(BuildContext context, String text, IconData icon,
      String path, bool selected) => TextButton.icon(
        onPressed: () => context.go(path),
        icon: Icon(icon, size: 17),
        label: Text(text),
        style: TextButton.styleFrom(
          backgroundColor: selected
              ? Theme.of(context).colorScheme.primaryContainer : null,
        ),
      );

  Widget _stats(ThemeData theme, bool isPhone) {
    final items = [
      ('Teaching today', '5 lessons'),
      ('Classes', '8 groups'),
      ('Grades to review', '12'),
    ];
    final cards = [
      for (final item in items)
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.$1,
                      style: theme.textTheme.labelLarge),
                  const SizedBox(height: 12),
                  Text(item.$2,
                      style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ),
    ];
    return isPhone
        ? Column(children: [
            for (final item in items)
              Card(child: ListTile(
                title: Text(item.$1),
                trailing: Text(item.$2,
                    style: theme.textTheme.titleMedium),
              )),
          ])
        : Row(children: cards);
  }

  Widget _card(String title, List<Widget> contents) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              ...contents,
            ],
          ),
        ),
      );

  Widget _item(String label, String time) => ListTile(
        leading: const Icon(Icons.auto_awesome_rounded),
        title: Text(label),
        trailing: Text(time),
      );
}

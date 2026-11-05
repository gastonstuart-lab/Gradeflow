import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gradeflow/models/class.dart';
import 'package:gradeflow/models/student.dart';
import 'package:gradeflow/models/grade_item.dart';
import 'package:gradeflow/models/grading_category.dart';
import 'package:gradeflow/repositories/repository_factory.dart';
import 'package:gradeflow/services/auth_service.dart';
import 'package:gradeflow/services/class_service.dart';
import 'package:gradeflow/services/student_service.dart';
import 'package:gradeflow/services/grade_item_service.dart';
import 'package:gradeflow/services/grading_category_service.dart';
import 'package:gradeflow/services/student_score_service.dart';
import 'package:gradeflow/services/final_exam_service.dart';
import 'package:gradeflow/screens/class_detail_screen.dart';
import 'package:gradeflow/screens/student_list_screen.dart';
import 'package:gradeflow/theme.dart';
import 'package:gradeflow/os/surfaces/class_surface.dart';
import 'package:gradeflow/os/os_controller.dart';

class _ReadyLocalAuth extends AuthService {
  @override
  bool get isInitialized => true;
  @override
  bool get isLoading => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ClassService classes;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    RepositoryFactory.useLocal();
    final now = DateTime(2026, 11, 5);
    classes = ClassService();
    await classes.addClass(Class(
        classId: 'synthetic',
        className: 'Synthetic class',
        subject: 'Test subject',
        schoolYear: '2026',
        term: 'Fall',
        teacherId: 'fixture-teacher',
        createdAt: now,
        updatedAt: now));
    await RepositoryFactory.instance.saveStudents('synthetic', [
      Student(
          studentId: 'fixture-one',
          chineseName: '測試',
          englishFirstName: 'Fixture',
          englishLastName: 'One',
          classId: 'synthetic',
          createdAt: now,
          updatedAt: now)
    ]);
    await RepositoryFactory.instance.saveCategories('synthetic', [
      GradingCategory(
          categoryId: 'work',
          classId: 'synthetic',
          name: 'Classwork',
          weightPercent: 100,
          aggregationMethod: AggregationMethod.average,
          isActive: true,
          createdAt: now,
          updatedAt: now)
    ]);
    await RepositoryFactory.instance.saveGradeItems('synthetic', [
      GradeItem(
          gradeItemId: 'assessment',
          classId: 'synthetic',
          categoryId: 'work',
          name: 'Unmarked assessment',
          isActive: true,
          createdAt: now,
          updatedAt: now)
    ]);
  });
  Future<void> mount(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final router =
        GoRouter(routes: [GoRoute(path: '/', builder: (_, __) => child)]);
    addTearDown(router.dispose);
    await tester.pumpWidget(MultiProvider(providers: [
      ChangeNotifierProvider(create: (_) => GradeFlowOSController()),
      ChangeNotifierProvider<AuthService>(create: (_) => _ReadyLocalAuth()),
      ChangeNotifierProvider<ClassService>.value(value: classes),
      ChangeNotifierProvider(create: (_) => StudentService()),
      ChangeNotifierProvider(create: (_) => GradingCategoryService()),
      ChangeNotifierProvider(create: (_) => GradeItemService()),
      ChangeNotifierProvider(create: (_) => StudentScoreService()),
      ChangeNotifierProvider(create: (_) => FinalExamService()),
    ], child: MaterialApp.router(theme: lightTheme, routerConfig: router)));
    await tester.pumpAndSettle();
  }

  testWidgets('opening class planning never generates scores or exams',
      (tester) async {
    await mount(tester, const ClassDetailScreen(classId: 'synthetic'));
    expect(tester.takeException(), isNull);
    expect(
        await RepositoryFactory.instance.loadScores('synthetic', 'assessment'),
        isEmpty);
    expect(await RepositoryFactory.instance.loadExams('synthetic'), isEmpty);
  });
  testWidgets('adding a student leaves all existing assessments unmarked',
      (tester) async {
    await mount(tester, const StudentListScreen(classId: 'synthetic'));
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    final fields = find.descendant(
        of: find.byType(AlertDialog), matching: find.byType(TextField));
    for (var i = 0; i < 5; i++) {
      await tester.enterText(
          fields.at(i), ['fixture-two', '測試', 'Fixture', 'Two', '2'][i]);
    }
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
        (await RepositoryFactory.instance.loadStudents('synthetic'))
            .any((s) => s.studentId == 'fixture-two'),
        isTrue);
    expect(
        await RepositoryFactory.instance.loadScores('synthetic', 'assessment'),
        isEmpty);
    expect(await RepositoryFactory.instance.loadExams('synthetic'), isEmpty);
  });
  testWidgets('class hub shows actual tools instead of fabricated live metrics',
      (tester) async {
    await mount(tester, const ClassSurface(classId: 'synthetic'));
    expect(find.text('Synthetic class'), findsOneWidget);
    expect(find.text('Gradebook'), findsOneWidget);
    expect(find.text('Engagement'), findsNothing);
    expect(find.text('Live class activity'), findsNothing);
    expect(find.textContaining('Jayden'), findsNothing);
  });
  test(
      'new classes use the confirmed syllabus policy without replacing existing weights',
      () async {
    final service = GradingCategoryService();
    await service.seedDefaultCategories('new-fixture');
    final values = {
      for (final c
          in await RepositoryFactory.instance.loadCategories('new-fixture'))
        c.name: c.weightPercent
    };
    expect(values, {
      'Participation': 20.0,
      'Homework': 30.0,
      'Classwork': 20.0,
      'Quiz': 30.0
    });
    await service.seedDefaultCategories('synthetic');
    final existing =
        await RepositoryFactory.instance.loadCategories('synthetic');
    expect(existing.length, 1);
    expect(existing.single.weightPercent, 100);
  });
}

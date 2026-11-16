import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:gradeflow/components/class_creation_dialog.dart';
import 'package:gradeflow/models/class.dart';
import 'package:gradeflow/repositories/local_repository.dart';
import 'package:gradeflow/services/class_service.dart';
import 'package:gradeflow/services/grading_category_service.dart';
import 'package:gradeflow/repositories/repository_factory.dart';

Class pupilClass(String id, {String teacher = 'fictional'}) => Class(
    classId: id,
    className: id,
    subject: 'Science',
    schoolYear: '2026-2027',
    term: 'Fall',
    teacherId: teacher,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026));

class RejectClasses extends InMemorySharedPreferencesStore {
  RejectClasses() : super.empty();
  bool reject = true;
  @override
  Future<bool> setValue(String type, String key, Object value) async {
    if (reject && key.endsWith('classes')) return false;
    return super.setValue(type, key, value);
  }
}

class RejectCategories extends InMemorySharedPreferencesStore {
  RejectCategories() : super.empty();
  bool reject = true;

  @override
  Future<bool> setValue(String type, String key, Object value) async {
    if (reject && key.endsWith('categories_new')) return false;
    return super.setValue(type, key, value);
  }
}

class ThrowClasses extends LocalRepository {
  @override
  Future<void> saveClasses(List<Class> classes) async =>
      throw StateError('Fictional failed write');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('rejected save leaves no phantom class and retry saves exactly once',
      () async {
    final store = RejectClasses();
    SharedPreferencesStorePlatform.instance = store;
    final repo = LocalRepository();
    final service = ClassService(repository: repo);
    var notifications = 0;
    service.addListener(() => notifications++);
    await expectLater(service.addClass(pupilClass('new')), throwsStateError);
    expect(service.classes, isEmpty);
    expect(notifications, 0);
    expect(await repo.loadClasses(), isEmpty);
    store.reject = false;
    await service.addClass(pupilClass('new'));
    await expectLater(service.addClass(pupilClass('new')), throwsStateError);
    final fresh = ClassService(repository: LocalRepository());
    await fresh.loadClasses('fictional');
    expect(fresh.classes.single.classId, 'new');
    service.dispose();
    fresh.dispose();
  });
  test('thrown save reaches caller without changing visible classes', () async {
    final service = ClassService(repository: ThrowClasses());
    await expectLater(service.addClass(pupilClass('new')), throwsStateError);
    expect(service.classes, isEmpty);
    service.dispose();
  });
  test(
      'creation retains stale and other-teacher records and serializes additions',
      () async {
    final repo = LocalRepository();
    await repo.saveClasses([pupilClass('other', teacher: 'someone-else')]);
    final service = ClassService(repository: repo);
    await service.loadClasses('fictional');
    await repo.saveClasses(
        [pupilClass('other', teacher: 'someone-else'), pupilClass('later')]);
    await Future.wait([
      service.addClass(pupilClass('one')),
      service.addClass(pupilClass('two'))
    ]);
    expect((await repo.loadClasses()).map((c) => c.classId),
        containsAll(['other', 'later', 'one', 'two']));
    expect(service.classes.every((c) => c.teacherId == 'fictional'), isTrue);
    service.dispose();
  });
  testWidgets(
      'failed creation keeps form values for retry and closes only after success',
      (tester) async {
    final controller = TextEditingController(text: 'Fictional Science');
    var calls = 0;
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => showDialog<bool>(
                        context: context,
                        builder: (_) => ClassCreationDialog(
                            content: TextField(controller: controller),
                            onCreate: () async {
                              calls++;
                              if (calls == 1) throw StateError('failed');
                            })),
                    child: const Text('Open'))))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(
        find.textContaining('Class creation did not complete'), findsOneWidget);
    expect(controller.text, 'Fictional Science');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.byType(ClassCreationDialog), findsNothing);
    controller.dispose();
  });

  testWidgets(
      'grading category failure keeps a saved class and retries setup without duplication',
      (tester) async {
    final store = RejectCategories();
    SharedPreferencesStorePlatform.instance = store;
    RepositoryFactory.useLocal();
    final repository = LocalRepository();
    final classService = ClassService(repository: repository);
    final categories = GradingCategoryService();
    var classPersisted = false;

    Future<void> createOrFinish() async {
      if (!classPersisted) {
        await classService.addClass(pupilClass('new'));
        classPersisted = true;
      }
      try {
        await categories.seedDefaultCategories('new', throwOnFailure: true);
      } catch (_) {
        throw const ClassGradingSetupPending();
      }
    }

    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => showDialog<bool>(
                        context: context,
                        builder: (_) => ClassCreationDialog(
                            content: const TextField(),
                            onCreate: createOrFinish)),
                    child: const Text('Open'))))));

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(find.textContaining('The class was saved'), findsOneWidget);
    expect(find.text('Retry grading setup'), findsOneWidget);
    expect((await repository.loadClasses()), hasLength(1));
    expect((await repository.loadCategories('new')), isEmpty);

    store.reject = false;
    await tester.tap(find.text('Retry grading setup'));
    await tester.pumpAndSettle();
    expect(find.byType(ClassCreationDialog), findsNothing);
    expect((await repository.loadClasses()), hasLength(1));
    final savedCategories = await repository.loadCategories('new');
    expect(savedCategories.map((category) => category.name), containsAll([
      'Participation', 'Homework', 'Classwork', 'Quiz',
    ]));
    expect(savedCategories, hasLength(4));
    classService.dispose();
    categories.dispose();
  });

  test('class import labels contain no BEL control characters', () {
    final source = File('lib/screens/class_list_screen.dart').readAsStringSync();
    expect(source.contains('\u0007'), isFalse);
    expect(source, contains(' • '));
  });
}

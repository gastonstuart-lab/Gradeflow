import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/models/class.dart';
import 'package:gradeflow/repositories/repository_factory.dart';
import 'package:gradeflow/services/class_service.dart';
import 'package:gradeflow/services/grading_category_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

Class fictionalSection(String id) => Class(
      classId: id,
      className: 'Fictional $id',
      subject: 'Science',
      schoolYear: '2026-2027',
      term: 'Fall',
      teacherId: 'fictional-teacher',
      createdAt: DateTime(2026, 11, 16),
      updatedAt: DateTime(2026, 11, 16),
    );

class RejectCategoryWrites extends InMemorySharedPreferencesStore {
  RejectCategoryWrites() : super.empty();

  String? rejectedClassId;

  @override
  Future<bool> setValue(String type, String key, Object value) async {
    if (key == 'categories_$rejectedClassId') return false;
    return super.setValue(type, key, value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    RepositoryFactory.useLocal();
  });

  test('failed category save leaves one durable class and can recover after reload', () async {
    final storage = RejectCategoryWrites()..rejectedClassId = 'target';
    SharedPreferencesStorePlatform.instance = storage;
    final repository = RepositoryFactory.instance;
    final creator = ClassService();
    final categories = GradingCategoryService();

    await creator.addClass(fictionalSection('target'));
    await expectLater(
      categories.seedDefaultCategories('target', throwOnFailure: true),
      throwsStateError,
    );
    expect(await repository.loadClasses(), hasLength(1));
    expect(await repository.loadCategories('target'), isEmpty);

    creator.dispose();
    categories.dispose();
    final reopened = ClassService();
    await reopened.loadClasses('fictional-teacher');
    expect(reopened.classes.single.classId, 'target');

    storage.rejectedClassId = null;
    final repair = GradingCategoryService();
    await repair.seedDefaultCategories('target', throwOnFailure: true);
    await repair.seedDefaultCategories('target', throwOnFailure: true);
    expect(await repository.loadClasses(), hasLength(1));
    final saved = await repository.loadCategories('target');
    expect(saved, hasLength(4));
    expect(saved.map((category) => category.name), containsAll([
      'Participation', 'Homework', 'Classwork', 'Quiz',
    ]));
    expect(saved.fold<double>(0, (sum, category) => sum + category.weightPercent), 100);
    reopened.dispose();
    repair.dispose();
  });

  test('interrupted multi-class setup preserves earlier classes and policies', () async {
    final storage = RejectCategoryWrites()..rejectedClassId = 'second';
    SharedPreferencesStorePlatform.instance = storage;
    final repo = RepositoryFactory.instance;
    final classes = ClassService();
    final categories = GradingCategoryService();
    await classes.addClass(fictionalSection('first'));
    await categories.seedDefaultCategories('first', throwOnFailure: true);
    await classes.addClass(fictionalSection('second'));
    await expectLater(
      categories.seedDefaultCategories('second', throwOnFailure: true),
      throwsStateError,
    );
    final firstBefore = await repo.loadCategories('first');
    expect(firstBefore, hasLength(4));
    expect(await repo.loadCategories('second'), isEmpty);
    expect(await repo.loadClasses(), hasLength(2));

    storage.rejectedClassId = null;
    final repair = GradingCategoryService();
    await repair.seedDefaultCategories('second', throwOnFailure: true);
    expect(await repo.loadClasses(), hasLength(2));
    expect(await repo.loadCategories('first'), firstBefore);
    expect(await repo.loadCategories('second'), hasLength(4));
    classes.dispose();
    categories.dispose();
    repair.dispose();
  });
}

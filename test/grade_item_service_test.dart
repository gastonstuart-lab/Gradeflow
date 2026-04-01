import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/models/grading_category.dart';
import 'package:gradeflow/repositories/repository_factory.dart';
import 'package:gradeflow/services/grade_item_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    RepositoryFactory.useLocal();
  });

  test('seedDemoGradeItems uses category-aware default names', () async {
    final service = GradeItemService();
    final now = DateTime.now();
    final categories = [
      GradingCategory(
        categoryId: 'cat-participation',
        classId: 'class-a',
        name: 'Participation',
        weightPercent: 25,
        aggregationMethod: AggregationMethod.average,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      ),
      GradingCategory(
        categoryId: 'cat-homework',
        classId: 'class-a',
        name: 'Homework',
        weightPercent: 25,
        aggregationMethod: AggregationMethod.average,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      ),
      GradingCategory(
        categoryId: 'cat-quiz',
        classId: 'class-a',
        name: 'Quiz',
        weightPercent: 25,
        aggregationMethod: AggregationMethod.average,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      ),
    ];

    await service.seedDemoGradeItems('class-a', categories);
    await service.loadGradeItems('class-a');

    final names = service.gradeItems.map((item) => item.name).toList();
    expect(names, containsAll(['Week 1', 'Week 2']));
    expect(names, containsAll(['Homework 1', 'Homework 2']));
    expect(names, containsAll(['Quiz 1', 'Quiz 2']));
  });
}

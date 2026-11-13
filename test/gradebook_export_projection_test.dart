import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gradeflow/models/class.dart' as school;
import 'package:gradeflow/models/student.dart';
import 'package:gradeflow/repositories/local_repository.dart';
import 'package:gradeflow/services/gradebook_export_projection.dart';
import 'package:gradeflow/services/gradebook_workspace.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalRepository repo;
  late GradebookWorkspace book;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repo = LocalRepository();
    final now = DateTime(2026, 11, 12);
    await repo.saveClasses([
      school.Class(
        classId: 'c', className: 'Mock class', subject: 'Science',
        schoolYear: '2026', term: 'Fall', teacherId: 'teacher',
        createdAt: now, updatedAt: now,
      ),
    ]);
    await repo.saveStudents('c', [
      Student(
        studentId: 's', classId: 'c', chineseName: '測試',
        englishFirstName: 'Sample', englishLastName: 'Student',
        createdAt: now, updatedAt: now,
      ),
    ]);
    book = GradebookWorkspace(repo, 'c');
    await book.load();
    await book.setUpCategories();
    for (final category in book.categories) {
      await book.addAssessment(category.categoryId, 'Sample ${category.name}', 100);
    }
  });

  tearDown(() => book.dispose());

  test('XLSX summary columns keep their position without fixed policy labels', () {
    expect(GradebookExportProjection.summaryHeaders, hasLength(7));
    expect(GradebookExportProjection.summaryHeaders.first, 'Homework');
    expect(GradebookExportProjection.summaryHeaders[1], 'Quiz');
    expect(GradebookExportProjection.summaryHeaders[4],
      'Process Score (saved category weights)');
    expect(GradebookExportProjection.summaryHeaders.last, 'Final Grade');
    expect(
      GradebookExportProjection.summaryHeaders.join(' '),
      isNot(contains('40%')),
    );
    expect(
      GradebookExportProjection.summaryHeaders.join(' '),
      isNot(contains('60%')),
    );
  });

  test('snapshot matches custom category weights and a persisted 70/30 split',
      () async {
    const marks = <String, double>{
      'Homework': 100,
      'Quizzes': 90,
      'Classwork': 80,
      'Participation': 70,
    };
    for (final item in book.items) {
      final category = book.categories.singleWhere(
        (c) => c.categoryId == item.categoryId,
      );
      await book.saveScore(
        's', item, marks[GradebookWorkspace.canonical(category.name)], 'teacher',
      );
    }
    await book.saveExam('s', 60);
    await book.setCourseworkWeightPercent(70);
    await repo.saveCategories('c', [
      for (final category in book.categories)
        category.copyWith(weightPercent: 25),
    ]);
    await book.load();
    expect(book.policyMatches, isTrue);

    final exported = GradebookExportProjection.calculatedValues(book, 's');
    expect(exported, hasLength(7));
    expect(exported.sublist(0, 4), [100, 90, 80, 70]);
    expect(exported[4], closeTo(85, .00001));
    expect(exported[5], 60);
    expect(exported[6], closeTo(77.5, .00001));
    expect(exported[6], closeTo(book.finalGrade('s')!, .00001));
    expect(exported[6], isNot(closeTo(75, .00001)));

    final reopened = GradebookWorkspace(repo, 'c');
    await reopened.load();
    final reexport = GradebookExportProjection.calculatedValues(reopened, 's');
    expect(reexport, exported);
    reopened.dispose();
  });

  test('blank and zero grades are never confused in XLSX projection', () async {
    for (final item in book.items) {
      await book.saveScore('s', item, 80, 'teacher');
    }
    await book.saveExam('s', 90);
    final homeworkCategory = book.categories.singleWhere(
      (c) => GradebookWorkspace.canonical(c.name) == 'Homework',
    );
    final homeworkItem = book.items.singleWhere(
      (i) => i.categoryId == homeworkCategory.categoryId,
    );

    await book.saveScore('s', homeworkItem, null, 'teacher');
    var exported = GradebookExportProjection.calculatedValues(book, 's');
    expect(exported[0], isNull);
    expect(exported[4], isNull);
    expect(exported[6], isNull);
    expect(exported[5], 90);

    await book.saveScore('s', homeworkItem, 0, 'teacher');
    exported = GradebookExportProjection.calculatedValues(book, 's');
    expect(exported[0], 0);
    expect(exported[4], isNotNull);
    expect(exported[6], closeTo(book.finalGrade('s')!, .00001));
    expect(exported[6], isNotNull);
  });

  test('unrecognised or invalid category policy never fabricates a final mark',
      () async {
    await repo.saveCategories('c', [
      for (final category in book.categories)
        category.copyWith(weightPercent: 30),
    ]);
    await book.load();
    expect(book.policyMatches, isFalse);
    final exported = GradebookExportProjection.calculatedValues(book, 's');
    expect(exported[4], isNull);
    expect(exported[6], isNull);
  });
}

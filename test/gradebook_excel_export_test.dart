import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/models/class.dart' as school;
import 'package:gradeflow/models/final_exam.dart';
import 'package:gradeflow/models/grade_item.dart';
import 'package:gradeflow/models/grading_category.dart';
import 'package:gradeflow/models/student.dart';
import 'package:gradeflow/models/student_score.dart';
import 'package:gradeflow/repositories/data_repository.dart';
import 'package:gradeflow/services/gradebook_excel_export.dart';

// Deliberately changes scores on a second read, simulating another device.
// Fake rejects all unimplemented methods, including every persistence write.
class ExportRepository extends Fake implements DataRepository {
  final reads = <String, int>{};
  final now = DateTime(2026);
  bool failScores = false;
  double? quiz = 96;
  double? exam = 80;
  final classes = ['a', 'b', 'archived'];
  static const marks = {
    'Homework': 100.0,
    'Quizzes': 96.0,
    'Classwork': 90.0,
    'Participation': 80.0,
  };

  @override
  Future<List<school.Class>> loadClasses() async => [
    for (final id in classes)
      school.Class(
        classId: id,
        className: 'Fictional $id',
        subject: 'Science',
        schoolYear: '2026',
        term: 'Fall',
        teacherId: 'fictional-teacher',
        courseworkWeightPercent: 70,
        isArchived: id == 'archived',
        createdAt: now,
        updatedAt: now,
      ),
  ];
  @override
  Future<List<Student>> loadStudents(String classId) async => [
    Student(
      studentId: '$classId-pupil',
      classId: classId,
      chineseName: '測試',
      englishFirstName: 'Fictional',
      englishLastName: classId,
      createdAt: now,
      updatedAt: now,
    ),
  ];
  @override
  Future<List<GradingCategory>> loadCategories(String classId) async => [
    for (final name in marks.keys)
      GradingCategory(
        categoryId: name,
        classId: classId,
        name: name,
        weightPercent: 25,
        aggregationMethod: AggregationMethod.average,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      ),
  ];
  @override
  Future<List<GradeItem>> loadGradeItems(String classId) async => [
    for (final name in marks.keys)
      GradeItem(
        gradeItemId: name,
        classId: classId,
        categoryId: name,
        name: name,
        maxScore: 100,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      ),
  ];
  @override
  Future<List<StudentScore>> loadScores(
    String classId,
    String gradeItemId,
  ) async {
    if (failScores) throw StateError('Fictional score read failure');
    final key = '$classId/$gradeItemId';
    final count = reads.update(key, (n) => n + 1, ifAbsent: () => 1);
    return [
      StudentScore(
        studentId: '$classId-pupil',
        gradeItemId: gradeItemId,
        score: count > 1
            ? 1
            : gradeItemId == 'Quizzes'
            ? quiz
            : marks[gradeItemId],
        createdAt: now,
        updatedAt: now,
      ),
    ];
  }

  @override
  Future<List<FinalExam>> loadExams(String classId) async => [
    FinalExam(
      studentId: '$classId-pupil',
      examScore: exam,
      createdAt: now,
      updatedAt: now,
    ),
  ];
}

double? number(Data? cell) => double.tryParse(cell?.value.toString() ?? '');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'summary and details share one read per class and preserve saved policy',
    () async {
      final repo = ExportRepository();
      final excel = Excel.decodeBytes(await GradebookExcelExport.build(repo));
      final summary = excel['All Classes'].rows;
      final detail = excel['Assessments'].rows;
      expect(
        excel.tables.keys,
        unorderedEquals(['All Classes', 'Assessments']),
      );
      expect(summary, hasLength(3));
      expect(detail, hasLength(9));
      expect(summary.first[7]!.value.toString(), 'Homework');
      expect(summary.first[13]!.value.toString(), 'Final Grade');
      for (var row = 1; row <= 2; row++) {
        final id = row == 1 ? 'a' : 'b';
        expect(summary[row][4]!.value.toString(), '$id-pupil');
        expect(summary[row].skip(7).map(number).toList(), [
          100,
          96,
          90,
          80,
          91.5,
          80,
          88.05,
        ]);
        final quiz = detail
            .skip(1)
            .singleWhere(
              (r) =>
                  r[0]!.value.toString() == id &&
                  r[4]!.value.toString() == 'Quizzes',
            );
        expect(number(quiz[6]), number(summary[row][8]));
      }
      expect(repo.reads, hasLength(8));
      expect(repo.reads.values, everyElement(1));
      expect(
        repo.reads.keys.any((key) => key.startsWith('archived/')),
        isFalse,
      );
    },
  );

  test('blank assessments remain blank and exam zero stays numeric', () async {
    final repo = ExportRepository()
      ..quiz = null
      ..exam = 0;
    final excel = Excel.decodeBytes(await GradebookExcelExport.build(repo));
    final row = excel['All Classes'].rows[1];
    expect(number(row[8]), isNull);
    expect(number(row[11]), isNull);
    expect(number(row[12]), 0);
    expect(number(row[13]), isNull);
    final quiz = excel['Assessments'].rows
        .skip(1)
        .firstWhere((r) => r[4]!.value.toString() == 'Quizzes');
    expect(number(quiz[6]), isNull);
  });

  test('empty export keeps both headers and original columns', () async {
    final repo = ExportRepository()..classes.clear();
    final excel = Excel.decodeBytes(await GradebookExcelExport.build(repo));
    expect(excel['All Classes'].rows.single, hasLength(14));
    expect(excel['Assessments'].rows.single, hasLength(7));
  });

  test(
    'failed read produces no partial workbook and next export can retry',
    () async {
      final repo = ExportRepository()..failScores = true;
      await expectLater(GradebookExcelExport.build(repo), throwsStateError);
      repo.failScores = false;
      final excel = Excel.decodeBytes(await GradebookExcelExport.build(repo));
      expect(excel['All Classes'].rows, hasLength(3));
    },
  );
}

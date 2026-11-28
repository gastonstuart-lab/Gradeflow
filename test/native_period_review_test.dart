import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gradeflow/models/class.dart' as school;
import 'package:gradeflow/models/student.dart';
import 'package:gradeflow/services/gradebook_workspace.dart';
import 'package:gradeflow/services/native_period_snapshot.dart';
import 'package:gradeflow/services/historical_grade_export_adapter.dart';
import 'package:gradeflow/models/grading_period.dart';
import 'package:gradeflow/components/native_period_review_dialog.dart';
import 'package:gradeflow/repositories/local_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late LocalRepository repo;
  late GradebookWorkspace book;
  final at = DateTime.utc(2026,11,28);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repo = LocalRepository();
    await repo.saveClasses([school.Class(classId:'class',className:'Fictional',subject:'Science',
        schoolYear:'2026',term:'Fall',teacherId:'teacher',courseworkWeightPercent:70,createdAt:at,updatedAt:at)]);
    await repo.saveStudents('class',[
      Student(studentId:'one',classId:'class',chineseName:'測試',englishFirstName:'Fictional',englishLastName:'One',createdAt:at,updatedAt:at),
      Student(studentId:'two',classId:'class',chineseName:'測試',englishFirstName:'Fictional',englishLastName:'Two',createdAt:at,updatedAt:at),
    ]);
    book = GradebookWorkspace(repo,'class');
    await book.load(); await book.setUpCategories();
    for(final cat in book.categories) {
      await book.addAssessment(cat.categoryId,'${cat.name} 1',100);
    }
    final cats = book.categories.map((c)=>c.copyWith(weightPercent:25)).toList();
    await repo.saveCategories('class',cats);
    await book.load();
    for(final item in book.items) {
      await book.saveScore('one',item,item.name.startsWith('Participation')?0:80,'teacher');
    }
    await book.saveExam('one',90);
  });
  tearDown(()=>book.dispose());
  Future<GradebookDataset> capture() => NativePeriodSnapshot.capture(repo,ownerId:'teacher',classId:'class');
  test('archive policy directly matches actual native workspace with custom weights, zero and blank',() async {
    final snapshot = await capture();
    final period = GradingPeriod(periodId:'old',label:'Current',createdAt:at,
        dataset:snapshot,policyVersion:GradingPeriod.nativeCalculationVersion);
    final grades = HistoricalGradeExportAdapter().calculate(period);
    for(final student in book.students) {
      final id = student.studentId;
      for(final cat in book.categories) {
        expect(grades[id]![cat.categoryId],book.average(id,cat.categoryId));
      }
      expect(grades[id]!['processScore'],book.process(id));
      expect(grades[id]!['examScore'],book.exam(id));
      expect(grades[id]!['finalGrade'],book.finalGrade(id));
    }
    expect(grades['one']!['finalGrade'],69);
    expect(grades['two']!['finalGrade'],isNull);
    await expectLater(NativePeriodSnapshot.capture(repo,ownerId:'other',classId:'class'),throwsStateError);
  });
  testWidgets('native grading-period dialog archives a copy, creates blank defaults, returns to old marks',
      (tester) async {
    final snapshot = await capture();
    final before = snapshot.toJson();
    await tester.binding.setSurfaceSize(const Size(1440,900));
    addTearDown(()=>tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:NativePeriodReviewDialog(snapshot:snapshot))));
    await tester.pumpAndSettle();
    expect(find.text('Grading periods demo'),findsOneWidget);
    expect(find.text('69.00'),findsOneWidget);
    await tester.tap(find.text('New grading period')); await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField),'Fictional next');
    await tester.tap(find.text('Archive & start')); await tester.pumpAndSettle();
    expect(find.textContaining('20 assessments'),findsOneWidget);
    expect(find.text('69.00'),findsNothing);
    await tester.tap(find.byType(DropdownButtonFormField<String>)); await tester.pumpAndSettle();
    await tester.tap(find.text('Current period · Archived').last); await tester.pumpAndSettle();
    expect(find.text('Export historical Excel'),findsOneWidget);
    expect(find.text('69.00'),findsOneWidget);
    expect((await capture()).toJson(),before);
  });
}

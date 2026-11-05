import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// SharedPreferences' existing platform test seam; no new runtime dependency.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:gradeflow/services/gradebook_workspace.dart';
import 'package:gradeflow/repositories/local_repository.dart';
import 'package:gradeflow/models/student.dart';
import 'package:gradeflow/models/student_score.dart';
import 'package:gradeflow/models/change_history.dart';
import 'package:gradeflow/services/gradebook_import_plan.dart';

class FailingRepository extends LocalRepository {
  bool failScore=false,failHistory=false;
  @override
  Future<void> saveScores(String c,String i,List<StudentScore> s) async {if(failScore)throw StateError('disk unavailable');await super.saveScores(c,i,s);}
  @override
  Future<void> addScoreHistory(String c,ChangeHistory h,{int maxEntries=100}) async {if(failHistory)throw StateError('history unavailable');await super.addScoreHistory(c,h,maxEntries:maxEntries);}
}
class RejectingPreferences extends InMemorySharedPreferencesStore {
  RejectingPreferences():super.empty();
  @override
  Future<bool> setValue(String type,String key,Object value)async=>false;
}
void main(){
  TestWidgetsFlutterBinding.ensureInitialized();
  late FailingRepository repo;
  late GradebookWorkspace book;
  setUp(()async{
    SharedPreferences.setMockInitialValues({});repo=FailingRepository();
    final now=DateTime(2026);
    await repo.saveStudents('c',[Student(studentId:'s',classId:'c',chineseName:'測試',englishFirstName:'Test',englishLastName:'Student',createdAt:now,updatedAt:now)]);
    book=GradebookWorkspace(repo,'c');await book.load();await book.setUpCategories();
    for(final c in book.categories){await book.addAssessment(c.categoryId,'${c.name} 1',100);}
  });
  tearDown(()=>book.dispose());
  test('opening and adding an assessment never creates full marks',()async{
    expect(book.values,isEmpty);expect(book.process('s'),isNull);
    final reopened=GradebookWorkspace(repo,'c');await reopened.load();expect(reopened.values,isEmpty);reopened.dispose();
  });
  test('weights, missing scores, zeros and reload use the same records',()async{
    for(final i in book.items){await book.saveScore('s',i,80,'teacher');}
    expect(book.process('s'),closeTo(80,1e-9));expect(book.finalGrade('s'),isNull);
    await book.saveExam('s',90);expect(book.finalGrade('s'),closeTo(86,1e-9));
    final homework=book.items.firstWhere((i)=>i.name.startsWith('Homework'));
    await book.saveScore('s',homework,0,'teacher');expect(book.process('s'),closeTo(56,1e-9));
    final reopened=GradebookWorkspace(repo,'c');await reopened.load();expect(reopened.score('s',homework.gradeItemId),0);expect(reopened.exam('s'),90);reopened.dispose();
    await book.saveScore('s',homework,null,'teacher');expect(book.process('s'),isNull);
  });
  test('failed score stays unconfirmed and retry succeeds',()async{
    final i=book.items.first;repo.failScore=true;
    await expectLater(book.saveScore('s',i,72,'teacher'),throwsStateError);
    expect(book.saveState,GradebookSaveState.failed);expect(book.score('s',i.gradeItemId),isNull);
    repo.failScore=false;await book.saveScore('s',i,72,'teacher');expect(book.saveState,GradebookSaveState.saved);expect(book.score('s',i.gradeItemId),72);
  });
  test('history failure is distinct from score failure',()async{
    repo.failHistory=true;await book.saveScore('s',book.items.first,63,'teacher');
    expect(book.saveState,GradebookSaveState.historyIncomplete);
    expect((await repo.loadScores('c',book.items.first.gradeItemId)).single.score,63);
  });
  test('cross-class and out-of-range scores rejected without writes',()async{
    await expectLater(book.saveScore('other-student',book.items.first,80,'teacher'),throwsStateError);
    await expectLater(book.saveScore('s',book.items.first,101,'teacher'),throwsArgumentError);
    expect(book.values,isEmpty);
  });
  test('undo restores a missing score and previous exam value',()async{
    final i=book.items.first;await book.saveScore('s',i,0,'teacher');expect(book.canUndo,true);
    await book.undoLastEdit();expect(book.score('s',i.gradeItemId),isNull);
    await book.saveExam('s',90);await book.saveExam('s',80);await book.undoLastEdit();expect(book.exam('s'),90);
  });
  test('multiple assessments require every score and normalize maximums',()async{
    final cat=book.categories.first;await book.addAssessment(cat.categoryId,'Small quiz',20);
    final list=book.categoryItems(cat.categoryId);await book.saveScore('s',list.first,80,'teacher');expect(book.average('s',cat.categoryId),isNull);
    await book.saveScore('s',list.last,10,'teacher');expect(book.average('s',cat.categoryId),65);
  });
  test('repository rejects false acknowledgements rather than implying success',()async{
    SharedPreferences.setMockInitialValues({});SharedPreferencesStorePlatform.instance=RejectingPreferences();
    await expectLater(LocalRepository().saveScores('c','i',[]),throwsStateError);
    expect(await LocalRepository().loadScores('c','i'),isEmpty);
  });
  test('opening a different GPA policy does not silently change it',()async{
    final cats=book.categories.map((c)=>c.copyWith(weightPercent:25)).toList();
    await repo.saveCategories('c',cats);await book.load();expect(book.policyMatches,false);expect(book.process('s'),isNull);
    expect((await repo.loadCategories('c')).first.weightPercent,25);
    await book.setUpCategories();expect(book.policyMatches,true);
  });
  test('standalone import validates every ID and value before writes',(){
    final source={'columns':{for(final k in GradebookWorkspace.processWeights.keys)k:['Score']},'scores':{'s':{'exam':80,for(final k in GradebookWorkspace.processWeights.keys)k:[null]}}};
    final p=GradebookImportPlan.parse(source,{'s'});expect(p.entered,1);expect(book.values,isEmpty);
    expect(()=>GradebookImportPlan.parse(source,{'different-id'}),throwsFormatException);
    (source['scores'] as Map)['s']['exam']=101;
    expect(()=>GradebookImportPlan.parse(source,{'s'}),throwsFormatException);
  });
}

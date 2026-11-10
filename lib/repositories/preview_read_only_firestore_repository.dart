import 'package:gradeflow/repositories/firestore_repository.dart';
import 'package:gradeflow/models/student.dart';
import 'package:gradeflow/models/class.dart';
import 'package:gradeflow/models/grade_item.dart';
import 'package:gradeflow/models/student_score.dart';
import 'package:gradeflow/models/final_exam.dart';
import 'package:gradeflow/models/change_history.dart';
import 'package:gradeflow/models/grading_category.dart';
import 'package:gradeflow/models/grading_template.dart';
import 'package:gradeflow/models/seating_layout.dart';
import 'package:gradeflow/models/room_setup.dart';

/// An existing-project Hosting preview can READ the current teacher's records,
/// but must never write grades, class records, seating or other repository data.
/// This is a server-independent second line of defense for review builds only.
class PreviewReadOnlyFirestoreRepository extends FirestoreRepository {
  PreviewReadOnlyFirestoreRepository({required super.userId});

  Never get _readonly => throw StateError(
    'Review preview is read-only. Open the live GradeFlow site to save changes.',
  );

  @override
  Future<void> saveStudents(String classId, List<Student> students) async => _readonly;
  @override
  Future<void> deleteStudent(String classId, String studentId) async => _readonly;
  @override
  Future<void> saveClasses(List<Class> classes) async => _readonly;
  @override
  Future<void> deleteClass(String classId) async => _readonly;
  @override
  Future<void> saveGradeItems(String classId, List<GradeItem> items) async => _readonly;
  @override
  Future<void> deleteGradeItem(String classId, String itemId) async => _readonly;
  @override
  Future<void> saveScores(String classId, String gradeItemId, List<StudentScore> scores) async => _readonly;
  @override
  Future<void> addScoreHistory(String classId, ChangeHistory entry, {int maxEntries = 100}) async => _readonly;
  @override
  Future<void> deleteScoreHistoryEntry(String classId, String changeId) async => _readonly;
  @override
  Future<void> saveExams(String classId, List<FinalExam> exams) async => _readonly;
  @override
  Future<void> saveCategories(String classId, List<GradingCategory> categories) async => _readonly;
  @override
  Future<void> saveTemplates(List<GradingTemplate> templates) async => _readonly;
  @override
  Future<void> saveSeatingLayouts(String classId, List<SeatingLayout> layouts) async => _readonly;
  @override
  Future<void> deleteSeatingLayout(String classId, String layoutId) async => _readonly;
  @override
  Future<void> saveActiveSeatingLayoutId(String classId, String layoutId) async => _readonly;
  @override
  Future<void> saveAssignedRoomSetupId(String classId, String? roomSetupId) async => _readonly;
  @override
  Future<void> saveRoomSetups(List<RoomSetup> roomSetups) async => _readonly;
  @override
  Future<void> deleteRoomSetup(String roomSetupId) async => _readonly;
  @override
  Future<void> clearAll() async => _readonly;
  @override
  Future<void> flushPendingWrites() async => _readonly;
}

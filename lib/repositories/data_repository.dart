import 'package:gradeflow/models/student.dart';
import 'package:gradeflow/models/class.dart';
import 'package:gradeflow/models/grade_item.dart';
import 'package:gradeflow/models/student_score.dart';
import 'package:gradeflow/models/final_exam.dart';
import 'package:gradeflow/models/change_history.dart';
import 'package:gradeflow/models/grading_category.dart';
import 'package:gradeflow/models/grading_template.dart';

/// Abstract interface for all data persistence operations.
/// Implementations can use SharedPreferences (local), Firestore (cloud), or both.
abstract class DataRepository {
  // Students
  Future<List<Student>> loadStudents(String classId);
  Future<void> saveStudents(String classId, List<Student> students);
  Future<void> deleteStudent(String classId, String studentId);
  
  // Classes
  Future<List<Class>> loadClasses();
  Future<void> saveClasses(List<Class> classes);
  Future<void> deleteClass(String classId);
  
  // Grade Items
  Future<List<GradeItem>> loadGradeItems(String classId);
  Future<void> saveGradeItems(String classId, List<GradeItem> items);
  Future<void> deleteGradeItem(String classId, String itemId);
  
  // Student Scores
  Future<List<StudentScore>> loadScores(String classId, String gradeItemId);
  Future<void> saveScores(String classId, String gradeItemId, List<StudentScore> scores);

  // Score Change History (Undo)
  Future<List<ChangeHistory>> loadScoreHistory(String classId, {int limit});
  Future<void> addScoreHistory(String classId, ChangeHistory entry, {int maxEntries});
  Future<void> deleteScoreHistoryEntry(String classId, String changeId);
  
  // Final Exams
  Future<List<FinalExam>> loadExams(String classId);
  Future<void> saveExams(String classId, List<FinalExam> exams);
  
  // Grading Categories
  Future<List<GradingCategory>> loadCategories(String classId);
  Future<void> saveCategories(String classId, List<GradingCategory> categories);
  
  // Grading Templates
  Future<List<GradingTemplate>> loadTemplates();
  Future<void> saveTemplates(List<GradingTemplate> templates);
  
  // Utility
  Future<void> clearAll();
  Future<bool> hasPendingWrites();
  Future<void> flushPendingWrites();
}

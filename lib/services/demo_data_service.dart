import 'package:gradeflow/models/user.dart';
import 'package:gradeflow/services/class_service.dart';
import 'package:gradeflow/services/final_exam_service.dart';
import 'package:gradeflow/services/grade_item_service.dart';
import 'package:gradeflow/services/grading_category_service.dart';
import 'package:gradeflow/services/student_score_service.dart';
import 'package:gradeflow/services/student_service.dart';

class DemoDataService {
  static const String demoUserId = 'demo-teacher-1';
  static const String demoEmail = 'teacher@demo.com';

  static bool isDemoUser(User? user) {
    if (user == null) return false;
    return user.userId == demoUserId ||
        user.email.trim().toLowerCase() == demoEmail;
  }

  static Future<void> ensureDemoWorkspace({
    required String teacherId,
    required ClassService classService,
    required StudentService studentService,
    required GradingCategoryService categoryService,
    required GradeItemService gradeItemService,
    required StudentScoreService scoreService,
    required FinalExamService examService,
  }) async {
    await classService.loadClasses(teacherId);
    if (classService.classes.isEmpty) {
      await classService.seedDemoClasses(teacherId);
      await classService.loadClasses(teacherId);
    }

    for (final classItem in classService.classes) {
      await studentService.seedDemoStudents(classItem.classId);
      await studentService.loadStudents(classItem.classId);

      await categoryService.seedDefaultCategories(classItem.classId);
      await categoryService.loadCategories(classItem.classId);

      await gradeItemService.seedDemoGradeItems(
        classItem.classId,
        categoryService.categories,
      );
      await gradeItemService.loadGradeItems(classItem.classId);

      final studentIds = studentService.students.map((s) => s.studentId).toList();
      final gradeItemIds =
          gradeItemService.gradeItems.map((g) => g.gradeItemId).toList();

      if (studentIds.isEmpty || gradeItemIds.isEmpty) continue;

      await scoreService.seedDemoScores(
        classItem.classId,
        studentIds,
        gradeItemIds,
      );
      await scoreService.loadScores(classItem.classId, gradeItemIds);

      await examService.seedDemoExams(classItem.classId, studentIds);
      await examService.loadExams(classItem.classId, studentIds);
    }
  }
}

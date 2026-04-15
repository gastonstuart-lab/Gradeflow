import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/repositories/repository_factory.dart';
import 'package:gradeflow/services/class_note_service.dart';
import 'package:gradeflow/services/class_schedule_service.dart';
import 'package:gradeflow/services/class_service.dart';
import 'package:gradeflow/services/demo_data_service.dart';
import 'package:gradeflow/services/final_exam_service.dart';
import 'package:gradeflow/services/grade_item_service.dart';
import 'package:gradeflow/services/grading_category_service.dart';
import 'package:gradeflow/services/seating_service.dart';
import 'package:gradeflow/services/student_score_service.dart';
import 'package:gradeflow/services/student_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    RepositoryFactory.useLocal();
  });

  test('ensureDemoWorkspace seeds planning and seating context', () async {
    final classService = ClassService();
    final studentService = StudentService();
    final categoryService = GradingCategoryService();
    final gradeItemService = GradeItemService();
    final scoreService = StudentScoreService();
    final examService = FinalExamService();

    await DemoDataService.ensureDemoWorkspace(
      teacherId: DemoDataService.demoUserId,
      classService: classService,
      studentService: studentService,
      categoryService: categoryService,
      gradeItemService: gradeItemService,
      scoreService: scoreService,
      examService: examService,
    );

    await classService.loadClasses(DemoDataService.demoUserId);
    expect(classService.classes, isNotEmpty);

    final firstClass = classService.classes.first;
    final schedule = await ClassScheduleService().load(firstClass.classId);
    final notes = await ClassNoteService().load(
      classId: firstClass.classId,
      userId: DemoDataService.demoUserId,
    );

    await studentService.loadStudents(firstClass.classId);
    final seatingService = SeatingService();
    await seatingService.loadRoomSetups();
    await seatingService.loadLayouts(
      firstClass.classId,
      studentCount: studentService.students.length,
    );

    final layout = seatingService.activeLayout(firstClass.classId);
    expect(schedule, isNotEmpty);
    expect(notes, isNotEmpty);
    expect(layout, isNotNull);
    expect(layout!.tables, isNotEmpty);
    expect(
      layout.seats.where((seat) => (seat.studentId ?? '').isNotEmpty),
      isNotEmpty,
    );
    expect(
      seatingService.assignedRoomSetup(firstClass.classId),
      isNotNull,
    );
  });
}

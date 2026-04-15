import 'package:gradeflow/models/class.dart';
import 'package:gradeflow/models/class_note_item.dart';
import 'package:gradeflow/models/class_schedule_item.dart';
import 'package:gradeflow/models/room_setup.dart';
import 'package:gradeflow/models/seating_layout.dart';
import 'package:gradeflow/models/student.dart';
import 'package:gradeflow/models/user.dart';
import 'package:gradeflow/services/class_note_service.dart';
import 'package:gradeflow/services/class_schedule_service.dart';
import 'package:gradeflow/services/class_service.dart';
import 'package:gradeflow/services/final_exam_service.dart';
import 'package:gradeflow/services/grade_item_service.dart';
import 'package:gradeflow/services/grading_category_service.dart';
import 'package:gradeflow/services/seating_service.dart';
import 'package:gradeflow/services/student_score_service.dart';
import 'package:gradeflow/services/student_service.dart';

class DemoDataService {
  static const String demoUserId = 'demo-teacher-1';
  static const String demoEmail = 'teacher@demo.com';
  static const String _demoSharedRoomName = 'Demo collaborative room';

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
    final scheduleService = ClassScheduleService();
    final noteService = ClassNoteService();
    final seatingService = SeatingService();

    await classService.loadClasses(teacherId);
    if (classService.classes.isEmpty) {
      await classService.seedDemoClasses(teacherId);
      await classService.loadClasses(teacherId);
    }

    await seatingService.loadRoomSetups();
    var sharedRoomSetupId = _existingDemoRoomSetupId(seatingService.roomSetups);

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

      final studentIds =
          studentService.students.map((s) => s.studentId).toList();
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

      await _seedDemoScheduleIfNeeded(
        classItem: classItem,
        scheduleService: scheduleService,
      );
      await _seedDemoNotesIfNeeded(
        classItem: classItem,
        userId: teacherId,
        noteService: noteService,
      );
      sharedRoomSetupId = await _seedDemoSeatingIfNeeded(
        classItem: classItem,
        students: List<Student>.from(studentService.students),
        seatingService: seatingService,
        sharedRoomSetupId: sharedRoomSetupId,
      );
    }
  }

  static Future<void> _seedDemoScheduleIfNeeded({
    required Class classItem,
    required ClassScheduleService scheduleService,
  }) async {
    final existing = await scheduleService.load(classItem.classId);
    if (existing.isNotEmpty) return;

    final now = DateTime.now();
    final weekStart = _startOfWeek(now);
    final nextWeekStart = weekStart.add(const Duration(days: 7));
    final room = _roomForSubject(classItem.subject);

    final items = <ClassScheduleItem>[
      ClassScheduleItem(
        title: _lessonTitleFor(classItem.subject, 'Warm-up and launch'),
        date: weekStart.add(const Duration(days: 1)),
        week: _weekNumber(now),
        room: room,
        startTimeMinutes: 8 * 60,
        endTimeMinutes: (8 * 60) + 45,
        details: {
          'Focus': 'Attendance, opener, and success criteria',
          'Materials': 'Slides and mini whiteboard prompts',
        },
      ),
      ClassScheduleItem(
        title: _lessonTitleFor(classItem.subject, 'Guided practice'),
        date: weekStart.add(const Duration(days: 3)),
        week: _weekNumber(now),
        room: room,
        startTimeMinutes: 10 * 60,
        endTimeMinutes: (10 * 60) + 45,
        details: {
          'Focus': 'Modeling, partner work, and checks for understanding',
          'Assessment': 'Exit ticket',
        },
      ),
      ClassScheduleItem(
        title: _lessonTitleFor(classItem.subject, 'Review and reteach'),
        date: nextWeekStart.add(const Duration(days: 1)),
        week: _weekNumber(nextWeekStart),
        room: room,
        startTimeMinutes: 8 * 60,
        endTimeMinutes: (8 * 60) + 45,
        details: {
          'Focus': 'Use last week\'s data to regroup students',
          'Homework': 'Bring notebook and corrected practice',
        },
      ),
    ];

    await scheduleService.save(classItem.classId, items);
  }

  static Future<void> _seedDemoNotesIfNeeded({
    required Class classItem,
    required String userId,
    required ClassNoteService noteService,
  }) async {
    final existing = await noteService.load(
      classId: classItem.classId,
      userId: userId,
    );
    if (existing.isNotEmpty) return;

    final today = _dateOnly(DateTime.now());
    final notes = <ClassNoteItem>[
      ClassNoteItem(
        id: '${classItem.classId}-demo-note-1',
        text: 'Pull two student samples into tomorrow\'s opener.',
        createdAt: today.subtract(const Duration(days: 1)),
        remindAt: today.add(const Duration(days: 1)),
      ),
      ClassNoteItem(
        id: '${classItem.classId}-demo-note-2',
        text: 'Check who still needs a quick conference before the next quiz.',
        createdAt: today,
      ),
    ];

    await noteService.save(
      classId: classItem.classId,
      userId: userId,
      items: notes,
    );
  }

  static Future<String?> _seedDemoSeatingIfNeeded({
    required Class classItem,
    required List<Student> students,
    required SeatingService seatingService,
    required String? sharedRoomSetupId,
  }) async {
    await seatingService.loadLayouts(
      classItem.classId,
      studentCount: students.length,
    );

    final currentLayout = seatingService.activeLayout(classItem.classId);
    if (currentLayout == null || !_isBlankStarterLayout(currentLayout)) {
      return sharedRoomSetupId;
    }

    if (sharedRoomSetupId != null) {
      await seatingService.applyRoomSetupToClass(
        classId: classItem.classId,
        roomSetupId: sharedRoomSetupId,
      );
    } else {
      await seatingService.applyTemplate(
        classItem.classId,
        SeatingTemplateType.currentClassroom,
        students.length,
      );
      final savedRoom = await seatingService.saveRoomSetupFromLayout(
        classId: classItem.classId,
        name: _demoSharedRoomName,
      );
      sharedRoomSetupId = savedRoom?.roomSetupId;
    }

    if (students.isNotEmpty) {
      await seatingService.autoAssignStudents(classItem.classId, students);
    }

    final seededLayout = seatingService.activeLayout(classItem.classId);
    if (seededLayout == null || seededLayout.seats.isEmpty) {
      return sharedRoomSetupId;
    }

    final orderedSeats = seatingService.orderedSeatsForLayout(seededLayout);
    final leadSeat = orderedSeats.first;
    await seatingService.setSeatStatus(
      classItem.classId,
      leadSeat.seatId,
      SeatStatusColor.green,
    );
    await seatingService.setSeatLocked(
      classItem.classId,
      leadSeat.seatId,
      true,
    );
    await seatingService.updateSeatNote(
      classItem.classId,
      leadSeat.seatId,
      note: 'Student captain helps launch materials.',
      reminder: true,
    );

    if (orderedSeats.length > 1) {
      await seatingService.setSeatStatus(
        classItem.classId,
        orderedSeats[1].seatId,
        SeatStatusColor.yellow,
      );
      await seatingService.updateSeatNote(
        classItem.classId,
        orderedSeats[1].seatId,
        note: 'Quick check-in before independent work.',
        reminder: false,
      );
    }

    return sharedRoomSetupId;
  }

  static bool _isBlankStarterLayout(SeatingLayout layout) {
    return layout.tables.isEmpty && layout.seats.isEmpty;
  }

  static String? _existingDemoRoomSetupId(List<RoomSetup> roomSetups) {
    for (final setup in roomSetups) {
      if (setup.name.trim().toLowerCase() ==
          _demoSharedRoomName.toLowerCase()) {
        return setup.roomSetupId;
      }
    }
    return null;
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static DateTime _startOfWeek(DateTime value) {
    final normalized = _dateOnly(value);
    return normalized.subtract(Duration(days: normalized.weekday - 1));
  }

  static int _weekNumber(DateTime value) {
    final startOfYear = DateTime(value.year, 1, 1);
    final dayOffset = value.difference(startOfYear).inDays;
    return (dayOffset ~/ 7) + 1;
  }

  static String _roomForSubject(String subject) {
    final normalized = subject.trim().toLowerCase();
    if (normalized.contains('math')) return 'Room 204';
    if (normalized.contains('english')) return 'Language Studio';
    if (normalized.contains('physics')) return 'Science Lab';
    return 'Classroom 1';
  }

  static String _lessonTitleFor(String subject, String suffix) {
    final normalized = subject.trim();
    if (normalized.isEmpty) return suffix;
    return '$normalized: $suffix';
  }
}

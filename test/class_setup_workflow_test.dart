import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gradeflow/models/class.dart';
import 'package:gradeflow/models/student.dart';
import 'package:gradeflow/models/seating_layout.dart';
import 'package:gradeflow/repositories/repository_factory.dart';
import 'package:gradeflow/services/class_service.dart';
import 'package:gradeflow/services/file_import_service.dart';
import 'package:gradeflow/services/student_service.dart';
import 'package:gradeflow/services/seating_service.dart';

Class fictionalClass(String id) => Class(
    classId: id,
    className: 'Fictional $id',
    subject: 'Science',
    schoolYear: '2026-2027',
    term: 'Fall',
    teacherId: 'fictional-teacher',
    createdAt: DateTime(2026, 11, 16),
    updatedAt: DateTime(2026, 11, 16));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    RepositoryFactory.useLocal();
  });

  test(
      'joined local class creation, import, missing pupil, room reuse and fresh-service reload',
      () async {
    final classes = ClassService();
    await classes.addClass(fictionalClass('source'));
    await classes.addClass(fictionalClass('target'));
    final parser = FileImportService();
    final students = StudentService();
    final rows = parser.parseCSV(
        'studentId,chineseName,englishFirstName,englishLastName\n101,Fictional,First,Pupil\n102,Fictional,Second,Pupil');
    expect(rows.where((r) => r.isValid), hasLength(2));
    await students.addStudents(parser.convertToStudents(rows, 'target'));
    await students.addStudent(Student(
        studentId: '103',
        chineseName: 'Fictional',
        englishFirstName: 'Missing',
        englishLastName: 'Pupil',
        classId: 'target',
        createdAt: DateTime(2026, 11, 16),
        updatedAt: DateTime(2026, 11, 16)));
    final seats = SeatingService();
    await seats.loadLayouts('source');
    await seats.addTable('source', SeatingTableType.rectangular, seatCount: 4);
    await seats.assignStudentToSeat('source',
        seats.activeLayout('source')!.seats.first.seatId, 'source-only-pupil');
    final room = await seats.saveRoomSetupFromLayout(
        classId: 'source', name: 'Fictional reusable room');
    expect(room, isNotNull);
    expect(
        await seats.applyRoomSetupToClass(
            classId: 'target', roomSetupId: room!.roomSetupId),
        isNotNull);
    await RepositoryFactory.instance.flushPendingWrites();
    classes.dispose();
    students.dispose();
    seats.dispose();
    RepositoryFactory.useLocal();
    final reopenedClasses = ClassService();
    await reopenedClasses.loadClasses('fictional-teacher');
    expect(reopenedClasses.classes.map((c) => c.classId),
        containsAll(['source', 'target']));
    final reopenedStudents = StudentService();
    await reopenedStudents.loadStudents('target');
    expect(reopenedStudents.students.map((s) => s.studentId),
        ['101', '102', '103']);
    expect(await RepositoryFactory.instance.loadStudents('source'), isEmpty);
    final reopenedSeats = SeatingService();
    await reopenedSeats.loadRoomSetups();
    await reopenedSeats.loadLayouts('target');
    expect(reopenedSeats.assignedRoomSetupId('target'), room.roomSetupId);
    expect(reopenedSeats.activeLayout('target')!.tables, hasLength(1));
    expect(reopenedSeats.activeLayout('target')!.seats, hasLength(4));
    expect(
        reopenedSeats
            .activeLayout('target')!
            .seats
            .every((s) => s.studentId == null),
        isTrue);
    reopenedClasses.dispose();
    reopenedStudents.dispose();
    reopenedSeats.dispose();
  });
}

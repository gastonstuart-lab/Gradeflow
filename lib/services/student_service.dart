import 'package:flutter/foundation.dart';
import 'package:gradeflow/models/student.dart';
import 'package:gradeflow/repositories/repository_factory.dart';

class StudentService extends ChangeNotifier {
  List<Student> _students = [];
  bool _isLoading = false;

  List<Student> get students => _students;
  bool get isLoading => _isLoading;

  Future<void> loadStudents(String classId) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final repo = RepositoryFactory.instance;
      _students = _sortStudentsByStudentId(await repo.loadStudents(classId));
    } catch (e) {
      debugPrint('Failed to load students: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addStudent(Student newStudent) async {
    try {
      _students.add(newStudent);
      _students = _sortStudentsByStudentId(_students);
      final repo = RepositoryFactory.instance;
      await repo.saveStudents(newStudent.classId, _students);
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to add student: $e');
    }
  }

  Future<void> addStudents(List<Student> newStudents) async {
    try {
      _students.addAll(newStudents);
      _students = _sortStudentsByStudentId(_students);
      if (newStudents.isNotEmpty) {
        final repo = RepositoryFactory.instance;
        await repo.saveStudents(newStudents.first.classId, _students);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to add students: $e');
    }
  }

  Future<void> updateStudent(Student updatedStudent) async {
    try {
      final localIndex = _students.indexWhere((s) => s.studentId == updatedStudent.studentId);
      if (localIndex == -1) return;
      _students[localIndex] = updatedStudent;
      _students = _sortStudentsByStudentId(_students);
      final repo = RepositoryFactory.instance;
      await repo.saveStudents(updatedStudent.classId, _students);
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to update student: $e');
    }
  }

  Future<void> deleteStudent(String studentId) async {
    try {
      final classId = _students.firstWhere((s) => s.studentId == studentId).classId;
      final repo = RepositoryFactory.instance;
      await repo.deleteStudent(classId, studentId);
      _students.removeWhere((s) => s.studentId == studentId);
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to delete student: $e');
    }
  }

  Student? getStudentById(String studentId) {
    try {
      return _students.firstWhere((s) => s.studentId == studentId);
    } catch (e) {
      return null;
    }
  }

  Future<void> seedDemoStudents(String classId) async {
    try {
      final repo = RepositoryFactory.instance;
      final existing = await repo.loadStudents(classId);
      if (existing.isEmpty) {
        final now = DateTime.now();
        final demoStudents = [
          Student(
            studentId: '$classId-student-1',
            chineseName: '李明',
            englishFirstName: 'Ming',
            englishLastName: 'Li',
            seatNo: '1',
            classCode: 'A',
            photoBase64: null,
            classId: classId,
            createdAt: now,
            updatedAt: now,
          ),
          Student(
            studentId: '$classId-student-2',
            chineseName: '王芳',
            englishFirstName: 'Fang',
            englishLastName: 'Wang',
            seatNo: '2',
            classCode: 'A',
            photoBase64: null,
            classId: classId,
            createdAt: now,
            updatedAt: now,
          ),
          Student(
            studentId: '$classId-student-3',
            chineseName: '张伟',
            englishFirstName: 'Wei',
            englishLastName: 'Zhang',
            seatNo: '3',
            classCode: 'A',
            photoBase64: null,
            classId: classId,
            createdAt: now,
            updatedAt: now,
          ),
          Student(
            studentId: '$classId-student-4',
            chineseName: '刘娜',
            englishFirstName: 'Na',
            englishLastName: 'Liu',
            seatNo: '4',
            classCode: 'A',
            photoBase64: null,
            classId: classId,
            createdAt: now,
            updatedAt: now,
          ),
          Student(
            studentId: '$classId-student-5',
            chineseName: '陈强',
            englishFirstName: 'Qiang',
            englishLastName: 'Chen',
            seatNo: '5',
            classCode: 'A',
            photoBase64: null,
            classId: classId,
            createdAt: now,
            updatedAt: now,
          ),
        ];
        await repo.saveStudents(classId, demoStudents);
        debugPrint('Demo students seeded for class $classId');
      }
    } catch (e) {
      debugPrint('Failed to seed demo students: $e');
    }
  }

  List<Student> _sortStudentsByStudentId(List<Student> students) {
    final sorted = List<Student>.from(students);
    sorted.sort((left, right) {
      final idCompare = _naturalCompare(
        left.studentId.toLowerCase(),
        right.studentId.toLowerCase(),
      );
      if (idCompare != 0) return idCompare;

      final chineseCompare = left.chineseName
          .toLowerCase()
          .compareTo(right.chineseName.toLowerCase());
      if (chineseCompare != 0) return chineseCompare;

      return left.englishFullName
          .toLowerCase()
          .compareTo(right.englishFullName.toLowerCase());
    });
    return sorted;
  }

  int _naturalCompare(String left, String right) {
    final leftParts = RegExp(r'\d+|\D+')
        .allMatches(left)
        .map((match) => match.group(0)!)
        .toList();
    final rightParts = RegExp(r'\d+|\D+')
        .allMatches(right)
        .map((match) => match.group(0)!)
        .toList();
    final limit =
        leftParts.length < rightParts.length ? leftParts.length : rightParts.length;

    for (int i = 0; i < limit; i++) {
      final leftPart = leftParts[i];
      final rightPart = rightParts[i];
      final leftNumber = int.tryParse(leftPart);
      final rightNumber = int.tryParse(rightPart);
      final compare = leftNumber != null && rightNumber != null
          ? leftNumber.compareTo(rightNumber)
          : leftPart.compareTo(rightPart);
      if (compare != 0) return compare;
    }

    return leftParts.length.compareTo(rightParts.length);
  }
}

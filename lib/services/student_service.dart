import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:gradeflow/models/student.dart';

class StudentService extends ChangeNotifier {
  static const String _studentsKey = 'students';
  List<Student> _students = [];
  bool _isLoading = false;

  List<Student> get students => _students;
  bool get isLoading => _isLoading;

  Future<void> loadStudents(String classId) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final studentsJson = prefs.getString(_studentsKey);
      
      if (studentsJson != null) {
        final List<dynamic> studentList = json.decode(studentsJson) as List;
        _students = studentList
            .map((s) => Student.fromJson(s as Map<String, dynamic>))
            .where((s) => s.classId == classId)
            .toList();
      }
    } catch (e) {
      debugPrint('Failed to load students: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addStudent(Student newStudent) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final studentsJson = prefs.getString(_studentsKey);
      List<Map<String, dynamic>> studentList = [];
      
      if (studentsJson != null) {
        studentList = (json.decode(studentsJson) as List).cast<Map<String, dynamic>>();
      }
      
      studentList.add(newStudent.toJson());
      await prefs.setString(_studentsKey, json.encode(studentList));
      
      _students.add(newStudent);
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to add student: $e');
    }
  }

  Future<void> addStudents(List<Student> newStudents) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final studentsJson = prefs.getString(_studentsKey);
      List<Map<String, dynamic>> studentList = [];
      
      if (studentsJson != null) {
        studentList = (json.decode(studentsJson) as List).cast<Map<String, dynamic>>();
      }
      
      for (var student in newStudents) {
        studentList.add(student.toJson());
      }
      
      await prefs.setString(_studentsKey, json.encode(studentList));
      _students.addAll(newStudents);
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to add students: $e');
    }
  }

  Future<void> updateStudent(Student updatedStudent) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final studentsJson = prefs.getString(_studentsKey);
      
      if (studentsJson != null) {
        List<Map<String, dynamic>> studentList = (json.decode(studentsJson) as List).cast<Map<String, dynamic>>();
        final index = studentList.indexWhere((s) => s['studentId'] == updatedStudent.studentId);
        
        if (index != -1) {
          studentList[index] = updatedStudent.toJson();
          await prefs.setString(_studentsKey, json.encode(studentList));
          
          final localIndex = _students.indexWhere((s) => s.studentId == updatedStudent.studentId);
          if (localIndex != -1) {
            _students[localIndex] = updatedStudent;
            notifyListeners();
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to update student: $e');
    }
  }

  Future<void> deleteStudent(String studentId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final studentsJson = prefs.getString(_studentsKey);
      
      if (studentsJson != null) {
        List<Map<String, dynamic>> studentList = (json.decode(studentsJson) as List).cast<Map<String, dynamic>>();
        studentList.removeWhere((s) => s['studentId'] == studentId);
        await prefs.setString(_studentsKey, json.encode(studentList));
        
        _students.removeWhere((s) => s.studentId == studentId);
        notifyListeners();
      }
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
      final prefs = await SharedPreferences.getInstance();
      final studentsJson = prefs.getString(_studentsKey);
      List<Map<String, dynamic>> studentList = [];
      
      if (studentsJson != null) {
        studentList = (json.decode(studentsJson) as List).cast<Map<String, dynamic>>();
      }
      
      final existingStudents = studentList.where((s) => s['classId'] == classId).toList();
      
      if (existingStudents.isEmpty) {
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
        
        for (var student in demoStudents) {
          studentList.add(student.toJson());
        }
        
        await prefs.setString(_studentsKey, json.encode(studentList));
        debugPrint('Demo students seeded for class $classId');
      }
    } catch (e) {
      debugPrint('Failed to seed demo students: $e');
    }
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/components/home/home_teaching_class_context.dart';
import 'package:gradeflow/models/class.dart';

Class _class(String id) => Class(
  classId: id,
  className: 'Synthetic $id',
  subject: 'Synthetic Science',
  schoolYear: '2026-2027',
  term: 'Fall',
  teacherId: 'fictional-teacher',
  createdAt: DateTime(2026, 11, 9),
  updatedAt: DateTime(2026, 11, 9),
);

void main() {
  test('Home restores the last routed class after navigating back', () {
    final classes = [_class('biology'), _class('english')];
    final selected = resolveHomeTeachingClass(
      signedInTeacherId: 'fictional-teacher',
      loadedClasses: classes,
      snapshotClasses: null,
      lastRoutedClassId: 'english',
    );
    expect(selected!.classId, 'english');
  });

  test('a deliberate Home dropdown choice overrides route history', () {
    final classes = [_class('biology'), _class('english')];
    final selected = resolveHomeTeachingClass(
      signedInTeacherId: 'fictional-teacher',
      loadedClasses: classes,
      snapshotClasses: null,
      selectedClassId: 'biology',
      lastRoutedClassId: 'english',
    );
    expect(selected!.classId, 'biology');
  });

  test('stale or unauthorized remembered ID cannot select another class', () {
    final allowed = [_class('teacher-b-class')];
    final selected = resolveHomeTeachingClass(
      signedInTeacherId: 'fictional-teacher',
      loadedClasses: allowed,
      snapshotClasses: null,
      selectedClassId: 'former-teacher-secret',
      lastRoutedClassId: 'former-teacher-secret',
    );
    expect(selected!.classId, 'teacher-b-class');
  });

  test('only loaded class list is authoritative when present', () {
    final selected = resolveHomeTeachingClass(
      signedInTeacherId: 'fictional-teacher',
      loadedClasses: [_class('current-teacher-class')],
      snapshotClasses: [_class('obsolete-previous-teacher-class')],
      lastRoutedClassId: 'obsolete-previous-teacher-class',
    );
    expect(selected!.classId, 'current-teacher-class');
  });

  test('snapshot can populate Home before live class list arrives', () {
    final selected = resolveHomeTeachingClass(
      signedInTeacherId: 'fictional-teacher',
      loadedClasses: const [],
      snapshotClasses: [_class('cached-a'), _class('cached-b')],
      lastRoutedClassId: 'cached-b',
    );
    expect(selected!.classId, 'cached-b');
  });

  test('a class owned by another account is excluded even if cached', () {
    final otherOwner = Class(
      classId: 'teacher-a-class',
      className: 'Private class',
      subject: 'Synthetic Science',
      schoolYear: '2026-2027',
      term: 'Fall',
      teacherId: 'teacher-a',
      createdAt: DateTime(2026, 11, 9),
      updatedAt: DateTime(2026, 11, 9),
    );
    final chosen = resolveHomeTeachingClass(
      signedInTeacherId: 'fictional-teacher',
      loadedClasses: [otherOwner, _class('own-class')],
      snapshotClasses: [otherOwner],
      lastRoutedClassId: 'teacher-a-class',
    );
    expect(chosen!.classId, 'own-class');
  });

  test('signed out Home never renders cached classes', () {
    expect(resolveHomeTeachingClass(
      signedInTeacherId: null,
      loadedClasses: [_class('previous-account')],
      snapshotClasses: [_class('previous-account')],
    ), isNull);
  });

  test('an empty teacher account cannot use remembered class ID', () {
    final selected = resolveHomeTeachingClass(
      signedInTeacherId: 'fictional-teacher',
      loadedClasses: const [],
      snapshotClasses: const [],
      lastRoutedClassId: 'prior-user-class',
    );
    expect(selected, isNull);
  });
}

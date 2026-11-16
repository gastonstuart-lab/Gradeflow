import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/models/class.dart';
import 'package:gradeflow/services/class_setup_identity.dart';

Class testClass(
  String id, {
  String name = 'J2ABC G4',
  String subject = 'Science',
  String year = '2026-2027',
  String term = 'Fall',
  String teacher = 'fictional-teacher',
}) =>
    Class(
      classId: id,
      className: name,
      subject: subject,
      schoolYear: year,
      term: term,
      teacherId: teacher,
      createdAt: DateTime(2026, 11, 16),
      updatedAt: DateTime(2026, 11, 16),
    );

void main() {
  test('an interrupted class import resolves to its already saved section', () {
    final existing = testClass('durable-id');
    final retried = testClass('new-random-id');
    expect(ClassSetupIdentity.findUnique([existing], retried)?.classId,
        'durable-id');
  });

  test('class identity ignores harmless case and whitespace differences', () {
    final existing = testClass('first', name: ' J2ABC   G4 ');
    final retried = testClass('second', name: 'j2abc g4');
    expect(ClassSetupIdentity.sameSection(existing, retried), isTrue);
  });

  test('same class name in another term is not the same section', () {
    final existing = testClass('fall');
    final spring = testClass('spring', term: 'Spring');
    expect(ClassSetupIdentity.findUnique([existing], spring), isNull);
  });

  test('same name but another school year is not the same section', () {
    final existing = testClass('old');
    final nextYear = testClass('new', year: '2027-2028');
    expect(ClassSetupIdentity.findUnique([existing], nextYear), isNull);
  });

  test('same name with another subject or teacher is not merged', () {
    final original = testClass('first');
    expect(ClassSetupIdentity.findUnique(
      [original], testClass('english', subject: 'English')), isNull);
    expect(ClassSetupIdentity.findUnique(
      [original], testClass('teacher-b', teacher: 'other-teacher')), isNull);
  });

  test('two ambiguous existing sections reject automatic import routing', () {
    final existing = [testClass('a'), testClass('b')];
    expect(
      () => ClassSetupIdentity.findUnique(existing, testClass('candidate')),
      throwsStateError,
    );
  });
}

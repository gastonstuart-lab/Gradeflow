import 'package:gradeflow/models/class.dart';

/// Identifies an existing teacher section before retrying a class import.
/// Names alone are insufficient: the same group can recur each school term.
class ClassSetupIdentity {
  static String _key(String value) =>
      value.trim().replaceAll(RegExp(r'\\s+'), ' ').toLowerCase();

  static bool sameSection(Class left, Class right) =>
      left.teacherId == right.teacherId &&
      _key(left.className) == _key(right.className) &&
      _key(left.subject) == _key(right.subject) &&
      _key(left.schoolYear) == _key(right.schoolYear) &&
      _key(left.term) == _key(right.term);

  /// Refuse to guess when old data already contains ambiguous duplicates.
  static Class? findUnique(Iterable<Class> existing, Class candidate) {
    final matches = existing.where((c) => sameSection(c, candidate)).toList();
    if (matches.length > 1) {
      throw StateError(
          'Multiple classes match this name, subject and term. '
          'Open the class list and resolve duplicates before importing.');
    }
    return matches.isEmpty ? null : matches.single;
  }
}

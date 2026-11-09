import 'package:gradeflow/models/class.dart';

/// Pick the class shown by premium Home from currently authorized classes.
///
/// The remembered class is a navigation hint only. It must never be trusted
/// as evidence that an account can read another teacher's class.
Class? resolveHomeTeachingClass({
  required List<Class> loadedClasses,
  required List<Class>? snapshotClasses,
  String? selectedClassId,
  String? lastRoutedClassId,
}) {
  final visibleClasses = loadedClasses.isNotEmpty
      ? loadedClasses
      : (snapshotClasses ?? const <Class>[]);
  for (final id in [selectedClassId, lastRoutedClassId]) {
    if (id == null || id.isEmpty) continue;
    for (final classItem in visibleClasses) {
      if (classItem.classId == id) return classItem;
    }
  }
  return visibleClasses.isNotEmpty ? visibleClasses.first : null;
}

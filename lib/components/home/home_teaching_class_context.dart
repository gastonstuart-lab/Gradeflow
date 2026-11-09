import 'package:gradeflow/models/class.dart';

/// Pick the class shown by premium Home from currently authorized classes.
///
/// The remembered class is a navigation hint only. It must never be trusted
/// as evidence that an account can read another teacher's class.
Class? resolveHomeTeachingClass({
  required List<Class> loadedClasses,
  required List<Class>? snapshotClasses,
  required String? signedInTeacherId,
  String? selectedClassId,
  String? lastRoutedClassId,
}) {
  // A cached class list, even a locally loaded one, is not a permission
  // grant. Do not display or route classes owned by a previous account.
  if (signedInTeacherId == null || signedInTeacherId.isEmpty) return null;
  final ownedLoaded = loadedClasses
      .where((c) => c.teacherId == signedInTeacherId).toList();
  final ownedSnapshots = (snapshotClasses ?? const <Class>[])
      .where((c) => c.teacherId == signedInTeacherId).toList();
  final visibleClasses =
      ownedLoaded.isNotEmpty ? ownedLoaded : ownedSnapshots;
  for (final id in [selectedClassId, lastRoutedClassId]) {
    if (id == null || id.isEmpty) continue;
    for (final classItem in visibleClasses) {
      if (classItem.classId == id) return classItem;
    }
  }
  return visibleClasses.isNotEmpty ? visibleClasses.first : null;
}

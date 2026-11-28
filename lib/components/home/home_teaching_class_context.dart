import 'package:gradeflow/models/class.dart';
import 'package:gradeflow/services/home_weekly_timetable_service.dart';
import 'package:gradeflow/services/timetable_import_plan.dart';
import 'package:gradeflow/components/time_slot_timetable.dart';

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

/// Never guess among multiple matching class names or use another account's roster.
Class? resolveScheduledTeachingClass(HomeTeachingMoment? moment,
    List<Class> classes, String? teacherId) {
  if (moment == null || teacherId == null || teacherId.isEmpty) return null;
  final owned = classes.where((c) => c.teacherId == teacherId && !c.isArchived).toList();
  final matches = TimetableImportPlan.candidates(TimeSlotClass(
    title: moment.title, dayOfWeek: moment.startAt.weekday - 1,
    startMinutes: moment.startAt.hour * 60 + moment.startAt.minute,
    endMinutes: moment.endAt.hour * 60 + moment.endAt.minute,
    classId: moment.classId,
  ), owned);
  return matches.length == 1 ? matches.single : null;
}

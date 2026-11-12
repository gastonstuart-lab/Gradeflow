import 'package:gradeflow/components/time_slot_timetable.dart';
import 'package:gradeflow/models/class.dart';
import 'package:gradeflow/models/student.dart';
import 'package:gradeflow/repositories/data_repository.dart';
import 'package:gradeflow/services/home_weekly_timetable_service.dart';

/// Read-only dashboard summary. Null is unknown, never zero.
/// A saved zero score counts as entered, while null stays missing.
class ClassDirectoryInsight {
  const ClassDirectoryInsight({
    required this.classItem,
    this.studentCount,
    this.seatedCount,
    this.scoreCells,
    this.enteredCells,
    this.nextLesson,
    this.studentSearchTokens = const [],
  });

  final Class classItem;
  final int? studentCount;
  final int? seatedCount;
  final int? scoreCells;
  final int? enteredCells;
  final DateTime? nextLesson;
  final List<String> studentSearchTokens;

  int? get unseated => studentCount == null || seatedCount == null
      ? null
      : (studentCount! - seatedCount!).clamp(0, studentCount!);

  int? get missingScores => scoreCells == null || enteredCells == null
      ? null
      : (scoreCells! - enteredCells!).clamp(0, scoreCells!);

  double? get completion => scoreCells == null || scoreCells == 0 ||
          enteredCells == null
      ? null
      : enteredCells! / scoreCells!;

  bool get needsSeating => (unseated ?? 0) > 0;
}

class ClassDirectorySnapshot {
  const ClassDirectorySnapshot({required this.items, required this.hasTimetable});
  final List<ClassDirectoryInsight> items;
  final bool hasTimetable;

  int? get totalStudents => items.any((item) => item.studentCount == null)
      ? null
      : items.fold<int>(0, (sum, item) => sum + item.studentCount!);

  int? get missingScores => items.any((item) => item.missingScores == null)
      ? null
      : items.fold<int>(0, (sum, item) => sum + item.missingScores!);

  int get classesWithSeatingToFinish =>
      items.where((item) => item.needsSeating).length;

  int lessonsToday(DateTime now) => items.where((item) {
        final date = item.nextLesson;
        return date != null && date.year == now.year &&
            date.month == now.month && date.day == now.day;
      }).length;
}

/// Does not create default rooms, categories, grades or any student records.
class ClassDirectoryInsightsLoader {
  const ClassDirectoryInsightsLoader(this.repository);
  final DataRepository repository;

  Future<ClassDirectorySnapshot> load({
    required List<Class> classes,
    required String teacherId,
    HomeWeeklyTimetable? timetable,
    DateTime? now,
  }) async {
    final safe = classes
        .where((item) => !item.isArchived && item.teacherId == teacherId)
        .toList(growable: false);
    final clock = now ?? DateTime.now();
    final summaries = await Future.wait([
      for (final classItem in safe)
        _readClass(classItem, clock,
            timetable?.classes ?? const <TimeSlotClass>[], safe),
    ]);
    return ClassDirectorySnapshot(items: summaries, hasTimetable: timetable != null);
  }

  Future<ClassDirectoryInsight> _readClass(
    Class classItem, DateTime now,
    List<TimeSlotClass> slots, List<Class> allClasses,
  ) async {
    List<Student>? roster;
    int? seatingCount;
    int? possibleCells;
    int? enteredCells;
    try {
      roster = (await repository.loadStudents(classItem.classId))
          .where((student) => student.classId == classItem.classId).toList();
    } catch (_) {
      // Unknown student count is distinct from 0 students.
    }

    if (roster != null) {
      try {
        final layouts = await repository.loadSeatingLayouts(classItem.classId);
        final selectedId = await repository.loadActiveSeatingLayoutId(
            classItem.classId);
        final selected = layouts.where((l) => l.layoutId == selectedId)
            .firstOrNull ?? (layouts.isNotEmpty ? layouts.first : null);
        if (selected == null) {
          seatingCount = 0;
        } else {
          final validIds = roster.map((s) => s.studentId).toSet();
          seatingCount = selected.seats
              .where((seat) => seat.studentId != null &&
                  validIds.contains(seat.studentId))
              .map((seat) => seat.studentId)
              .toSet().length;
        }
      } catch (_) {
        // Keep the card available when its seating cannot be retrieved.
      }

      try {
        final items = (await repository.loadGradeItems(classItem.classId))
            .where((item) => item.classId == classItem.classId && item.isActive)
            .toList(growable: false);
        if (items.isNotEmpty && roster.isNotEmpty) {
          final validIds = roster.map((student) => student.studentId).toSet();
          final lists = await Future.wait([
            for (final item in items)
              repository.loadScores(classItem.classId, item.gradeItemId),
          ]);
          possibleCells = roster.length * items.length;
          enteredCells = 0;
          for (final scores in lists) {
            enteredCells += scores
                .where((score) => validIds.contains(score.studentId) &&
                    score.score != null)
                .map((score) => score.studentId).toSet().length;
          }
        } else {
          possibleCells = 0;
          enteredCells = 0;
        }
      } catch (_) {
        // Unknown grading coverage must never render as 100%.
      }
    }

    return ClassDirectoryInsight(
      classItem: classItem,
      studentCount: roster?.length,
      seatedCount: seatingCount,
      scoreCells: possibleCells,
      enteredCells: enteredCells,
      studentSearchTokens: roster == null ? const [] : [
        for (final student in roster)
          '\${student.englishFullName} \${student.chineseName} \${student.studentId}'
              .toLowerCase(),
      ],
      nextLesson: nextLessonForClass(classItem, allClasses, slots, now),
    );
  }

  /// Only show a next lesson on a unique exact class title/identifier match.
  static DateTime? nextLessonForClass(
    Class classItem, List<Class> allClasses,
    List<TimeSlotClass> slots, DateTime now,
  ) {
    final key = _normalize(classItem.className);
    final id = _normalize(classItem.classId);
    final keys = [key, id].where((v) => v.isNotEmpty).toSet();
    final matched = slots.where((slot) {
      final title = _normalize(slot.title);
      if (!keys.contains(title)) return false;
      final owners = allClasses.where((other) =>
          _normalize(other.className) == title ||
          _normalize(other.classId) == title).length;
      return owners == 1 && slot.dayOfWeek >= 0 && slot.dayOfWeek < 7 &&
          slot.endMinutes > slot.startMinutes;
    }).toList();
    if (matched.isEmpty) return null;

    final monday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    DateTime? next;
    for (final slot in matched) {
      for (final offset in [0, 7, 14]) {
        final start = monday.add(Duration(days: offset + slot.dayOfWeek))
            .add(Duration(minutes: slot.startMinutes));
        final end = monday.add(Duration(days: offset + slot.dayOfWeek))
            .add(Duration(minutes: slot.endMinutes));
        if (!end.isAfter(now)) continue;
        if (next == null || start.isBefore(next)) next = start;
      }
    }
    return next;
  }

  static String _normalize(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
}

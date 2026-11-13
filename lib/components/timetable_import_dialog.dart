import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gradeflow/services/auth_service.dart';
import 'package:gradeflow/services/class_service.dart';
import 'package:gradeflow/services/home_weekly_timetable_service.dart';
import 'package:gradeflow/services/timetable_import_plan.dart';

/// Shared confirmation for Home, Planner and Data Inbox. Inspection and cancel
/// perform no writes. Only existing classes owned by this teacher are offered.
Future<HomeWeeklyTimetable?> confirmTimetableImport(
  BuildContext context, {
  required String filename,
  required Uint8List bytes,
}) async {
  final userId = context.read<AuthService>().currentUser?.userId;
  if (userId == null) throw StateError('Sign in before importing a timetable.');
  final inspected =
      HomeWeeklyTimetableService.inspectBytes(filename: filename, bytes: bytes);
  final plan = TimetableImportPlan(inspected.classes);
  final classes = context
      .read<ClassService>()
      .activeClasses
      .where((c) => c.teacherId == userId)
      .toList();
  final choices = <String, String>{};
  final labels = {
    for (final lesson in plan.lessons)
      TimetableImportPlan.matchKey(lesson): lesson.title
  };
  for (final lesson in plan.lessons) {
    final matches = TimetableImportPlan.candidates(lesson, classes);
    if (matches.length == 1)
      choices[TimetableImportPlan.matchKey(lesson)] = matches.single.classId;
  }
  final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
          builder: (context, update) => AlertDialog(
                title: Text('Review ${plan.lessons.length} timetable periods'),
                content: SizedBox(
                    width: 720,
                    height: 480,
                    child: SingleChildScrollView(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                          const Text(
                              'Saved on this device for your account. Cross-device sync is unavailable. '
                              'Confirm every class match. Existing versions remain available.'),
                          for (final label in labels.keys)
                            Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 6),
                                child: DropdownButtonFormField<String>(
                                  initialValue: choices[label],
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                      labelText: 'Match ${labels[label]}'),
                                  items: [
                                    for (final c in classes)
                                      DropdownMenuItem(
                                          value: c.classId,
                                          child: Text(
                                              '${c.className} · ${c.subject} · ${c.classId}'))
                                  ],
                                  onChanged: (value) => update(() {
                                    if (value != null) choices[label] = value;
                                  }),
                                )),
                          if (classes.isEmpty)
                            const Text(
                                'No owned classes are loaded. Load or create your classes before importing.'),
                          const Divider(),
                          for (final lesson in plan.lessons)
                            ListTile(
                                dense: true,
                                title: Text(
                                    '${TimetableImportPlan.weekdays[lesson.dayOfWeek]} '
                                    '${_clock(lesson.startMinutes)}–${_clock(lesson.endMinutes)} · ${lesson.title}')),
                        ]))),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: choices.length == labels.length
                          ? () => Navigator.pop(dialogContext, true)
                          : null,
                      child: const Text('Confirm and save locally')),
                ],
              )));
  if (confirmed != true) return null;
  if (!context.mounted ||
      context.read<AuthService>().currentUser?.userId != userId) {
    throw StateError('Account changed. Import cancelled without saving.');
  }
  return const HomeWeeklyTimetableService().importForTeacher(
    userId: userId,
    filename: filename,
    bytes: bytes,
    classMatches: choices,
    availableClasses: context.read<ClassService>().activeClasses,
  );
}

String _clock(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

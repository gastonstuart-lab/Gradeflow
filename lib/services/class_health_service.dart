import 'package:gradeflow/models/class.dart';
import 'package:gradeflow/models/class_health_model.dart';
import 'package:gradeflow/models/class_note_item.dart';
import 'package:gradeflow/models/seating_layout.dart';
import 'package:gradeflow/repositories/repository_factory.dart';
import 'package:gradeflow/services/class_note_service.dart';

class ClassHealthService {
  ClassHealthService({
    ClassNoteService? classNoteService,
  }) : _classNoteService = classNoteService ?? ClassNoteService();

  final ClassNoteService _classNoteService;

  Future<Map<String, ClassHealthStaticSignals>> loadStaticSignals({
    required String userId,
    required List<Class> classes,
  }) async {
    final repository = RepositoryFactory.instance;
    final signals = <String, ClassHealthStaticSignals>{};
    final now = DateTime.now();

    for (final classItem in classes) {
      final students = await repository.loadStudents(classItem.classId);
      final gradeItems = await repository.loadGradeItems(classItem.classId);
      final layouts = await repository.loadSeatingLayouts(classItem.classId);
      final activeLayoutId =
          await repository.loadActiveSeatingLayoutId(classItem.classId);
      final assignedRoomSetupId =
          await repository.loadAssignedRoomSetupId(classItem.classId);
      final notes = await _classNoteService.load(
        classId: classItem.classId,
        userId: userId,
      );

      final activeLayout = _resolveActiveLayout(layouts, activeLayoutId);
      final hasSeatingPlan = layouts.any(
        (layout) => layout.tables.isNotEmpty || layout.seats.isNotEmpty,
      );
      final seatingAttentionCount = activeLayout == null
          ? 0
          : activeLayout.seats.where((seat) {
              return seat.reminder ||
                  seat.note.trim().isNotEmpty ||
                  seat.statusColor != SeatStatusColor.none;
            }).length;

      final openNotes =
          notes.where((item) => !item.isDone).toList(growable: false);
      final overdueNotes = _countOpenNotesBefore(notes, now);
      final dueNotes = _countOpenNotesWithin(notes, now, days: 7);

      signals[classItem.classId] = ClassHealthStaticSignals(
        classId: classItem.classId,
        className: classItem.className,
        classUpdatedAt: classItem.updatedAt,
        studentCount: students.length,
        gradeItemCount: gradeItems.where((item) => item.isActive).length,
        hasSyllabusPlan: (classItem.syllabus?.entries.isNotEmpty ?? false) ||
            (classItem.syllabus?.headerLines.isNotEmpty ?? false),
        syllabusEntryCount: classItem.syllabus?.entries.length ?? 0,
        openNoteCount: openNotes.length,
        dueNoteCount: dueNotes,
        overdueNoteCount: overdueNotes,
        hasSeatingPlan: hasSeatingPlan,
        hasAssignedRoomSetup: assignedRoomSetupId != null &&
            assignedRoomSetupId.trim().isNotEmpty,
        seatingSeatCount: activeLayout?.seats.length ?? 0,
        seatingAssignedCount: activeLayout == null
            ? 0
            : activeLayout.seats.where((seat) {
                final studentId = seat.studentId?.trim() ?? '';
                return studentId.isNotEmpty;
              }).length,
        seatingAttentionCount: seatingAttentionCount,
      );
    }

    return signals;
  }

  ClassHealthRecord build({
    required ClassHealthStaticSignals staticSignals,
    required ClassHealthRuntimeSignals runtimeSignals,
  }) {
    final startsIn = _positiveDifference(
      runtimeSignals.nextClassStartsAt,
      runtimeSignals.now,
    );
    final startsWithinHour =
        startsIn != null && startsIn <= const Duration(hours: 1);
    final startsWithinDay =
        startsIn != null && startsIn <= const Duration(hours: 24);
    final totalOverdue =
        runtimeSignals.overdueReminderCount + staticSignals.overdueNoteCount;
    final totalDueSoon =
        runtimeSignals.dueSoonReminderCount + staticSignals.dueNoteCount;
    final missingSeatAssignments =
        staticSignals.studentCount - staticSignals.seatingAssignedCount;

    final issues = <_ClassHealthIssue>[
      if (staticSignals.studentCount == 0)
        _missingRosterIssue(
          staticSignals: staticSignals,
          runtimeSignals: runtimeSignals,
          startsWithinDay: startsWithinDay,
        ),
      if (totalOverdue > 0)
        _overdueFollowUpIssue(
          staticSignals: staticSignals,
          runtimeSignals: runtimeSignals,
          overdueCount: totalOverdue,
          startsWithinHour: startsWithinHour,
        ),
      if ((runtimeSignals.isLiveNow || startsWithinHour) &&
          !staticSignals.hasSeatingPlan &&
          staticSignals.studentCount > 0)
        _missingSeatingIssue(
          staticSignals: staticSignals,
          runtimeSignals: runtimeSignals,
          startsIn: startsIn,
        ),
      if (staticSignals.hasSeatingPlan &&
          staticSignals.studentCount > 0 &&
          missingSeatAssignments > 0 &&
          (runtimeSignals.isLiveNow || startsWithinDay))
        _incompleteSeatingIssue(
          staticSignals: staticSignals,
          runtimeSignals: runtimeSignals,
          missingSeatAssignments: missingSeatAssignments,
          startsIn: startsIn,
        ),
      if (staticSignals.seatingAttentionCount > 0 &&
          (runtimeSignals.isLiveNow || startsWithinDay))
        _seatingAttentionIssue(
          staticSignals: staticSignals,
          runtimeSignals: runtimeSignals,
        ),
      if (staticSignals.hasSeatingPlan &&
          !staticSignals.hasAssignedRoomSetup &&
          staticSignals.studentCount > 0 &&
          (runtimeSignals.isLiveNow || startsWithinDay))
        _missingRoomLinkIssue(
          staticSignals: staticSignals,
          runtimeSignals: runtimeSignals,
          startsIn: startsIn,
        ),
      if (staticSignals.studentCount > 0 &&
          !runtimeSignals.hasSelectedTimetable)
        _missingDashboardTimetableIssue(staticSignals: staticSignals),
      if (staticSignals.studentCount > 0 &&
          runtimeSignals.hasSelectedTimetable &&
          !runtimeSignals.hasTimetableContext)
        _missingClassTimetableIssue(staticSignals: staticSignals),
      if (staticSignals.studentCount > 0 &&
          staticSignals.gradeItemCount == 0 &&
          (runtimeSignals.isLiveNow || startsWithinDay))
        _missingGradebookIssue(
          staticSignals: staticSignals,
          runtimeSignals: runtimeSignals,
          startsIn: startsIn,
        ),
      if (totalDueSoon > 0)
        _dueSoonIssue(
          staticSignals: staticSignals,
          runtimeSignals: runtimeSignals,
          dueSoonCount: totalDueSoon,
        ),
      if (staticSignals.studentCount > 0 &&
          !staticSignals.hasSyllabusPlan &&
          staticSignals.openNoteCount == 0)
        _planningThinIssue(staticSignals: staticSignals),
    ];

    issues.sort((left, right) => right.priority.compareTo(left.priority));
    final issue = issues.isNotEmpty
        ? issues.first
        : _readyIssue(
            staticSignals: staticSignals,
            runtimeSignals: runtimeSignals,
            startsIn: startsIn,
          );

    return ClassHealthRecord(
      classId: staticSignals.classId,
      level: issue.level,
      levelLabel: _levelLabel(issue.level),
      primaryReason: issue.primaryReason,
      secondaryDetail: issue.secondaryDetail,
      recommendedLabel: issue.primaryAction.label,
      recommendedDetail: issue.primaryAction.detail,
      primaryAction: issue.primaryAction,
      secondaryAction: issue.secondaryAction,
      metrics: _buildMetrics(
        staticSignals: staticSignals,
        runtimeSignals: runtimeSignals,
        startsIn: startsIn,
      ),
    );
  }

  _ClassHealthIssue _missingRosterIssue({
    required ClassHealthStaticSignals staticSignals,
    required ClassHealthRuntimeSignals runtimeSignals,
    required bool startsWithinDay,
  }) {
    final urgent = runtimeSignals.isLiveNow || startsWithinDay;
    return _ClassHealthIssue(
      priority: urgent ? 100 : 78,
      level: urgent ? ClassHealthLevel.urgent : ClassHealthLevel.attention,
      primaryReason: runtimeSignals.isLiveNow
          ? 'Live now and the roster is still empty'
          : startsWithinDay && runtimeSignals.nextClassStartsAt != null
              ? '${_startsInLabel(runtimeSignals.nextClassStartsAt!, runtimeSignals.now)} and the roster is still empty'
              : 'Roster still missing for this class',
      secondaryDetail:
          'Import students before using gradebook, seating, and export workflows for ${staticSignals.className}.',
      primaryAction: const ClassHealthAction(
        label: 'Import roster',
        detail: 'Open the classes workspace and bring this roster in.',
        type: ClassHealthActionType.openClassesWorkspace,
      ),
      secondaryAction: const ClassHealthAction(
        label: 'Open class',
        detail: 'Jump into the class workspace for setup context.',
        type: ClassHealthActionType.openClassWorkspace,
      ),
    );
  }

  _ClassHealthIssue _overdueFollowUpIssue({
    required ClassHealthStaticSignals staticSignals,
    required ClassHealthRuntimeSignals runtimeSignals,
    required int overdueCount,
    required bool startsWithinHour,
  }) {
    final urgent = runtimeSignals.isLiveNow || startsWithinHour;
    return _ClassHealthIssue(
      priority: urgent ? 98 : 90,
      level: urgent ? ClassHealthLevel.urgent : ClassHealthLevel.attention,
      primaryReason:
          '$overdueCount follow-up item${overdueCount == 1 ? '' : 's'} overdue',
      secondaryDetail: runtimeSignals.isLiveNow
          ? 'Clear the overdue reminders before this lesson gets away from you.'
          : 'Review the overdue reminders and class note dates tied to ${staticSignals.className}.',
      primaryAction: const ClassHealthAction(
        label: 'Review reminders',
        detail: 'Open reminders and clear the overdue follow-up items first.',
        type: ClassHealthActionType.reviewPlanning,
      ),
      secondaryAction: const ClassHealthAction(
        label: 'Open class',
        detail: 'Jump into the class workspace to review local notes.',
        type: ClassHealthActionType.openClassWorkspace,
      ),
    );
  }

  _ClassHealthIssue _missingSeatingIssue({
    required ClassHealthStaticSignals staticSignals,
    required ClassHealthRuntimeSignals runtimeSignals,
    required Duration? startsIn,
  }) {
    return _ClassHealthIssue(
      priority: runtimeSignals.isLiveNow ? 92 : 84,
      level: runtimeSignals.isLiveNow
          ? ClassHealthLevel.urgent
          : ClassHealthLevel.attention,
      primaryReason: runtimeSignals.isLiveNow
          ? 'In progress now and seating is still missing'
          : startsIn == null
              ? 'Seating plan is still missing'
              : '${_durationLabel(startsIn)} away and seating is still missing',
      secondaryDetail:
          'A saved seating plan keeps attendance, interventions, and room flow fast when ${staticSignals.className} meets.',
      primaryAction: const ClassHealthAction(
        label: 'Open seating',
        detail: 'Create or load a seating plan for this class.',
        type: ClassHealthActionType.openSeating,
      ),
      secondaryAction: const ClassHealthAction(
        label: 'Open class',
        detail: 'Review the rest of the class setup before the lesson starts.',
        type: ClassHealthActionType.openClassWorkspace,
      ),
    );
  }

  _ClassHealthIssue _seatingAttentionIssue({
    required ClassHealthStaticSignals staticSignals,
    required ClassHealthRuntimeSignals runtimeSignals,
  }) {
    return _ClassHealthIssue(
      priority: runtimeSignals.isLiveNow ? 82 : 70,
      level: ClassHealthLevel.attention,
      primaryReason:
          '${staticSignals.seatingAttentionCount} seating note${staticSignals.seatingAttentionCount == 1 ? '' : 's'} need a look',
      secondaryDetail:
          'Seat reminders or annotations are already attached to ${staticSignals.className} and may affect today\'s room flow.',
      primaryAction: const ClassHealthAction(
        label: 'Review seating',
        detail: 'Open seating to inspect seat notes and reminders.',
        type: ClassHealthActionType.openSeating,
      ),
      secondaryAction: const ClassHealthAction(
        label: 'Open class',
        detail: 'Keep the wider class context close while you review seats.',
        type: ClassHealthActionType.openClassWorkspace,
      ),
    );
  }

  _ClassHealthIssue _incompleteSeatingIssue({
    required ClassHealthStaticSignals staticSignals,
    required ClassHealthRuntimeSignals runtimeSignals,
    required int missingSeatAssignments,
    required Duration? startsIn,
  }) {
    return _ClassHealthIssue(
      priority: runtimeSignals.isLiveNow ? 86 : 76,
      level: runtimeSignals.isLiveNow
          ? ClassHealthLevel.urgent
          : ClassHealthLevel.attention,
      primaryReason: runtimeSignals.isLiveNow
          ? '$missingSeatAssignments student${missingSeatAssignments == 1 ? '' : 's'} still need seats'
          : startsIn == null
              ? 'Seat assignments are still incomplete'
              : '${_durationLabel(startsIn)} away and $missingSeatAssignments seat${missingSeatAssignments == 1 ? '' : 's'} still need assigning',
      secondaryDetail:
          '${staticSignals.seatingAssignedCount} of ${staticSignals.studentCount} students are placed, which can slow attendance and interventions when ${staticSignals.className} starts.',
      primaryAction: const ClassHealthAction(
        label: 'Finish seating',
        detail: 'Open seating and place the remaining students before class.',
        type: ClassHealthActionType.openSeating,
      ),
      secondaryAction: const ClassHealthAction(
        label: 'Open class',
        detail: 'Keep the full class context visible while you finish seating.',
        type: ClassHealthActionType.openClassWorkspace,
      ),
    );
  }

  _ClassHealthIssue _missingRoomLinkIssue({
    required ClassHealthStaticSignals staticSignals,
    required ClassHealthRuntimeSignals runtimeSignals,
    required Duration? startsIn,
  }) {
    return _ClassHealthIssue(
      priority: runtimeSignals.isLiveNow ? 66 : 56,
      level: ClassHealthLevel.attention,
      primaryReason: runtimeSignals.isLiveNow
          ? 'Seating is live, but the room layout is still not linked'
          : startsIn == null
              ? 'Seating exists, but the room layout is still missing'
              : '${_durationLabel(startsIn)} away and room layout is still missing',
      secondaryDetail:
          'Link a room setup so seating reflects the real classroom flow for ${staticSignals.className}.',
      primaryAction: const ClassHealthAction(
        label: 'Link room setup',
        detail: 'Open seating and connect the active layout to a room setup.',
        type: ClassHealthActionType.openSeating,
      ),
      secondaryAction: const ClassHealthAction(
        label: 'Open class',
        detail:
            'Review the class workspace while classroom setup is still incomplete.',
        type: ClassHealthActionType.openClassWorkspace,
      ),
    );
  }

  _ClassHealthIssue _missingDashboardTimetableIssue({
    required ClassHealthStaticSignals staticSignals,
  }) {
    return _ClassHealthIssue(
      priority: 72,
      level: ClassHealthLevel.attention,
      primaryReason: 'Dashboard timetable is still missing',
      secondaryDetail:
          'Add or select a timetable so ${staticSignals.className} can appear in Today, Next class, and daily timing cues.',
      primaryAction: const ClassHealthAction(
        label: 'Fix timetable',
        detail: 'Upload or select the active timetable for the dashboard.',
        type: ClassHealthActionType.openTimetable,
      ),
      secondaryAction: const ClassHealthAction(
        label: 'Open class',
        detail: 'Review class setup while timetable context is still missing.',
        type: ClassHealthActionType.openClassWorkspace,
      ),
    );
  }

  _ClassHealthIssue _missingClassTimetableIssue({
    required ClassHealthStaticSignals staticSignals,
  }) {
    return _ClassHealthIssue(
      priority: 68,
      level: ClassHealthLevel.attention,
      primaryReason: 'Roster imported, but timetable context is still missing',
      secondaryDetail:
          '${staticSignals.className} is not mapping into the active timetable yet, so dashboard timing cues cannot anchor it reliably.',
      primaryAction: const ClassHealthAction(
        label: 'Fix timetable',
        detail:
            'Review the active timetable so this class is properly represented.',
        type: ClassHealthActionType.openTimetable,
      ),
      secondaryAction: const ClassHealthAction(
        label: 'Open class',
        detail:
            'Keep the class workspace open while you resolve schedule context.',
        type: ClassHealthActionType.openClassWorkspace,
      ),
    );
  }

  _ClassHealthIssue _missingGradebookIssue({
    required ClassHealthStaticSignals staticSignals,
    required ClassHealthRuntimeSignals runtimeSignals,
    required Duration? startsIn,
  }) {
    return _ClassHealthIssue(
      priority: runtimeSignals.isLiveNow ? 74 : 62,
      level: ClassHealthLevel.attention,
      primaryReason: runtimeSignals.isLiveNow
          ? 'This class is live and gradebook setup is still empty'
          : startsIn == null
              ? 'Gradebook setup is still empty'
              : '${_startsInLabel(runtimeSignals.nextClassStartsAt!, runtimeSignals.now)} and no grade items are ready yet',
      secondaryDetail:
          'Add grade items so daily assessment, reporting, and export workflows are ready when ${staticSignals.className} needs them.',
      primaryAction: const ClassHealthAction(
        label: 'Open gradebook',
        detail: 'Create grade items or review the class scoring structure.',
        type: ClassHealthActionType.openGradebook,
      ),
      secondaryAction: const ClassHealthAction(
        label: 'Open class',
        detail: 'Review the wider class setup before grading begins.',
        type: ClassHealthActionType.openClassWorkspace,
      ),
    );
  }

  _ClassHealthIssue _dueSoonIssue({
    required ClassHealthStaticSignals staticSignals,
    required ClassHealthRuntimeSignals runtimeSignals,
    required int dueSoonCount,
  }) {
    return _ClassHealthIssue(
      priority: 58,
      level: ClassHealthLevel.attention,
      primaryReason:
          '$dueSoonCount follow-up item${dueSoonCount == 1 ? '' : 's'} due soon',
      secondaryDetail: runtimeSignals.nextReminderText != null &&
              runtimeSignals.nextReminderText!.trim().isNotEmpty
          ? 'Next: ${runtimeSignals.nextReminderText!.trim()}'
          : 'Review the upcoming reminders and class note dates before they stack up for ${staticSignals.className}.',
      primaryAction: const ClassHealthAction(
        label: 'Review reminders',
        detail: 'Open reminders and clear the next due follow-up items.',
        type: ClassHealthActionType.reviewPlanning,
      ),
      secondaryAction: const ClassHealthAction(
        label: 'Open class',
        detail: 'Keep the class context visible while you handle the follow-up.',
        type: ClassHealthActionType.openClassWorkspace,
      ),
    );
  }

  _ClassHealthIssue _planningThinIssue({
    required ClassHealthStaticSignals staticSignals,
  }) {
    return _ClassHealthIssue(
      priority: 42,
      level: ClassHealthLevel.attention,
      primaryReason: 'Teaching context is still thin',
      secondaryDetail:
          'Add a syllabus import or class notes so ${staticSignals.className} carries more teaching context than the roster alone.',
      primaryAction: const ClassHealthAction(
        label: 'Open class',
        detail: 'Review the class workspace and add notes or syllabus context.',
        type: ClassHealthActionType.openClassWorkspace,
      ),
      secondaryAction: const ClassHealthAction(
        label: 'Open gradebook',
        detail:
            'If the lesson is already mapped out, at least anchor grading structure.',
        type: ClassHealthActionType.openGradebook,
      ),
    );
  }

  _ClassHealthIssue _readyIssue({
    required ClassHealthStaticSignals staticSignals,
    required ClassHealthRuntimeSignals runtimeSignals,
    required Duration? startsIn,
  }) {
    final hasStrongSetup = staticSignals.hasSeatingPlan &&
        staticSignals.gradeItemCount > 0 &&
        staticSignals.hasSyllabusPlan;
    final primaryAction = hasStrongSetup && staticSignals.gradeItemCount >= 3
        ? const ClassHealthAction(
            label: 'Open export',
            detail: 'Open export for a final review or reporting pass.',
            type: ClassHealthActionType.openExport,
          )
        : staticSignals.gradeItemCount > 0
            ? const ClassHealthAction(
                label: 'Open gradebook',
                detail: 'Jump straight into grading for this class.',
                type: ClassHealthActionType.openGradebook,
              )
            : staticSignals.hasSeatingPlan
                ? const ClassHealthAction(
                    label: 'Open seating',
                    detail:
                        'Seat changes and attendance flow are ready to review.',
                    type: ClassHealthActionType.openSeating,
                  )
                : const ClassHealthAction(
                    label: 'Open class',
                    detail: 'Keep the full class workspace within reach.',
                    type: ClassHealthActionType.openClassWorkspace,
                  );

    return _ClassHealthIssue(
      priority: 10,
      level: ClassHealthLevel.ready,
      primaryReason: runtimeSignals.isLiveNow
          ? 'Live now and ready to run'
          : startsIn != null && startsIn <= const Duration(hours: 24)
              ? '${_startsInLabel(runtimeSignals.nextClassStartsAt!, runtimeSignals.now)} and ready for class'
              : 'Ready for today and no immediate follow-up is needed',
      secondaryDetail: hasStrongSetup
          ? 'Roster, seating, gradebook, and teaching context are already in place for ${staticSignals.className}.'
          : 'The core setup is stable, and there is no urgent follow-up blocking ${staticSignals.className} right now.',
      primaryAction: primaryAction,
      secondaryAction: const ClassHealthAction(
        label: 'Open class',
        detail:
            'Review notes, students, and tools in the full class workspace.',
        type: ClassHealthActionType.openClassWorkspace,
      ),
    );
  }

  List<ClassHealthMetric> _buildMetrics({
    required ClassHealthStaticSignals staticSignals,
    required ClassHealthRuntimeSignals runtimeSignals,
    required Duration? startsIn,
  }) {
    final metrics = <ClassHealthMetric>[
      ClassHealthMetric(
        label: 'Roster',
        value: staticSignals.studentCount == 0
            ? 'Missing'
            : '${staticSignals.studentCount} students',
      ),
    ];

    if (runtimeSignals.isLiveNow) {
      metrics.add(
        const ClassHealthMetric(label: 'Timing', value: 'Live now'),
      );
    } else if (runtimeSignals.nextClassStartsAt != null && startsIn != null) {
      metrics.add(
        ClassHealthMetric(
          label: 'Timing',
          value: startsIn <= const Duration(hours: 24)
              ? _shortTime(runtimeSignals.nextClassStartsAt!)
              : 'This week',
        ),
      );
    } else if (!runtimeSignals.hasSelectedTimetable) {
      metrics.add(
        const ClassHealthMetric(label: 'Timing', value: 'No timetable'),
      );
    } else if (!runtimeSignals.hasTimetableContext) {
      metrics.add(
        const ClassHealthMetric(label: 'Timing', value: 'Off timetable'),
      );
    }

    if (runtimeSignals.overdueReminderCount + staticSignals.overdueNoteCount >
        0) {
      metrics.add(
        ClassHealthMetric(
          label: 'Follow-up',
          value:
              '${runtimeSignals.overdueReminderCount + staticSignals.overdueNoteCount} overdue',
        ),
      );
    } else if (runtimeSignals.dueSoonReminderCount +
            staticSignals.dueNoteCount >
        0) {
      metrics.add(
        ClassHealthMetric(
          label: 'Follow-up',
          value:
              '${runtimeSignals.dueSoonReminderCount + staticSignals.dueNoteCount} due soon',
        ),
      );
    } else if (staticSignals.hasSeatingPlan &&
        staticSignals.studentCount > 0 &&
        staticSignals.seatingAssignedCount < staticSignals.studentCount) {
      final unassigned =
          staticSignals.studentCount - staticSignals.seatingAssignedCount;
      metrics.add(
        ClassHealthMetric(
          label: 'Setup',
          value: '$unassigned seat${unassigned == 1 ? '' : 's'} open',
        ),
      );
    } else if (!staticSignals.hasSeatingPlan) {
      metrics.add(
        const ClassHealthMetric(label: 'Setup', value: 'Seating missing'),
      );
    } else if (staticSignals.seatingAttentionCount > 0) {
      metrics.add(
        ClassHealthMetric(
          label: 'Setup',
          value:
              '${staticSignals.seatingAttentionCount} seat note${staticSignals.seatingAttentionCount == 1 ? '' : 's'}',
        ),
      );
    } else if (staticSignals.gradeItemCount > 0) {
      metrics.add(
        ClassHealthMetric(
          label: 'Gradebook',
          value:
              '${staticSignals.gradeItemCount} item${staticSignals.gradeItemCount == 1 ? '' : 's'}',
        ),
      );
      } else if (staticSignals.hasSyllabusPlan) {
        metrics.add(
          const ClassHealthMetric(label: 'Context', value: 'Notes ready'),
        );
      }

    if (staticSignals.hasAssignedRoomSetup &&
        metrics.length < 4 &&
        !metrics.any((metric) => metric.label == 'Room')) {
      metrics.add(
        const ClassHealthMetric(label: 'Room', value: 'Layout linked'),
      );
    } else if (!staticSignals.hasAssignedRoomSetup &&
        staticSignals.hasSeatingPlan &&
        metrics.length < 4 &&
        !metrics.any((metric) => metric.label == 'Room')) {
      metrics.add(
        const ClassHealthMetric(label: 'Room', value: 'Link room'),
      );
    }

    return metrics.take(4).toList(growable: false);
  }

  SeatingLayout? _resolveActiveLayout(
    List<SeatingLayout> layouts,
    String? activeLayoutId,
  ) {
    if (layouts.isEmpty) return null;
    if (activeLayoutId != null && activeLayoutId.trim().isNotEmpty) {
      for (final layout in layouts) {
        if (layout.layoutId == activeLayoutId) {
          return layout;
        }
      }
    }
    return layouts.first;
  }

  int _countOpenNotesBefore(
    List<ClassNoteItem> notes,
    DateTime now,
  ) {
    final today = DateTime(now.year, now.month, now.day);
    return notes.where((item) {
      if (item.isDone || item.remindAt == null) {
        return false;
      }
      final dueAt = DateTime(
        item.remindAt!.year,
        item.remindAt!.month,
        item.remindAt!.day,
      );
      return dueAt.isBefore(today);
    }).length;
  }

  int _countOpenNotesWithin(
    List<ClassNoteItem> notes,
    DateTime now, {
    required int days,
  }) {
    final today = DateTime(now.year, now.month, now.day);
    final end = today.add(Duration(days: days));
    return notes.where((item) {
      if (item.isDone || item.remindAt == null) {
        return false;
      }
      final dueAt = DateTime(
        item.remindAt!.year,
        item.remindAt!.month,
        item.remindAt!.day,
      );
      return !dueAt.isBefore(today) && !dueAt.isAfter(end);
    }).length;
  }

  Duration? _positiveDifference(DateTime? candidate, DateTime now) {
    if (candidate == null) return null;
    final difference = candidate.difference(now);
    if (difference.isNegative) {
      return null;
    }
    return difference;
  }

  String _levelLabel(ClassHealthLevel level) {
    switch (level) {
      case ClassHealthLevel.ready:
        return 'Ready';
      case ClassHealthLevel.attention:
        return 'Attention';
      case ClassHealthLevel.urgent:
        return 'Urgent';
    }
  }

  String _startsInLabel(DateTime startAt, DateTime now) {
    final difference = startAt.difference(now);
    if (difference.inMinutes <= 0) {
      return 'Starting now';
    }
    return 'Starts in ${_durationLabel(difference)}';
  }

  String _durationLabel(Duration duration) {
    if (duration.inMinutes < 60) {
      return '${duration.inMinutes} min';
    }
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (minutes == 0) {
      return '$hours hr';
    }
    return '$hours hr ${minutes} min';
  }

  String _shortTime(DateTime value) {
    final hour =
        value.hour == 0 ? 12 : (value.hour > 12 ? value.hour - 12 : value.hour);
    final minute = value.minute.toString().padLeft(2, '0');
    final period = value.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}

class _ClassHealthIssue {
  final int priority;
  final ClassHealthLevel level;
  final String primaryReason;
  final String secondaryDetail;
  final ClassHealthAction primaryAction;
  final ClassHealthAction secondaryAction;

  const _ClassHealthIssue({
    required this.priority,
    required this.level,
    required this.primaryReason,
    required this.secondaryDetail,
    required this.primaryAction,
    required this.secondaryAction,
  });
}

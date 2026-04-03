enum ClassHealthLevel {
  ready,
  attention,
  urgent,
}

enum ClassHealthActionType {
  openClassWorkspace,
  openClassesWorkspace,
  openGradebook,
  openSeating,
  openTimetable,
  reviewPlanning,
  openExport,
}

class ClassHealthMetric {
  final String label;
  final String value;

  const ClassHealthMetric({
    required this.label,
    required this.value,
  });
}

class ClassHealthAction {
  final String label;
  final String detail;
  final ClassHealthActionType type;

  const ClassHealthAction({
    required this.label,
    required this.detail,
    required this.type,
  });
}

class ClassHealthStaticSignals {
  final String classId;
  final String className;
  final DateTime classUpdatedAt;
  final int studentCount;
  final int gradeItemCount;
  final bool hasSyllabusPlan;
  final int syllabusEntryCount;
  final int openNoteCount;
  final int dueNoteCount;
  final int overdueNoteCount;
  final bool hasSeatingPlan;
  final bool hasAssignedRoomSetup;
  final int seatingSeatCount;
  final int seatingAssignedCount;
  final int seatingAttentionCount;

  const ClassHealthStaticSignals({
    required this.classId,
    required this.className,
    required this.classUpdatedAt,
    required this.studentCount,
    required this.gradeItemCount,
    required this.hasSyllabusPlan,
    required this.syllabusEntryCount,
    required this.openNoteCount,
    required this.dueNoteCount,
    required this.overdueNoteCount,
    required this.hasSeatingPlan,
    required this.hasAssignedRoomSetup,
    required this.seatingSeatCount,
    required this.seatingAssignedCount,
    required this.seatingAttentionCount,
  });

  factory ClassHealthStaticSignals.fallback({
    required String classId,
    required String className,
    required int studentCount,
    required DateTime classUpdatedAt,
  }) {
    return ClassHealthStaticSignals(
      classId: classId,
      className: className,
      classUpdatedAt: classUpdatedAt,
      studentCount: studentCount,
      gradeItemCount: 0,
      hasSyllabusPlan: false,
      syllabusEntryCount: 0,
      openNoteCount: 0,
      dueNoteCount: 0,
      overdueNoteCount: 0,
      hasSeatingPlan: false,
      hasAssignedRoomSetup: false,
      seatingSeatCount: 0,
      seatingAssignedCount: 0,
      seatingAttentionCount: 0,
    );
  }
}

class ClassHealthRuntimeSignals {
  final DateTime now;
  final bool isFocused;
  final bool hasSelectedTimetable;
  final bool hasTimetableContext;
  final bool isLiveNow;
  final DateTime? currentClassEndsAt;
  final DateTime? nextClassStartsAt;
  final int openReminderCount;
  final int dueSoonReminderCount;
  final int overdueReminderCount;
  final String? nextReminderText;
  final DateTime? nextReminderAt;

  const ClassHealthRuntimeSignals({
    required this.now,
    required this.isFocused,
    required this.hasSelectedTimetable,
    required this.hasTimetableContext,
    required this.isLiveNow,
    required this.currentClassEndsAt,
    required this.nextClassStartsAt,
    required this.openReminderCount,
    required this.dueSoonReminderCount,
    required this.overdueReminderCount,
    required this.nextReminderText,
    required this.nextReminderAt,
  });
}

class ClassHealthRecord {
  final String classId;
  final ClassHealthLevel level;
  final String levelLabel;
  final String primaryReason;
  final String secondaryDetail;
  final String recommendedLabel;
  final String recommendedDetail;
  final ClassHealthAction primaryAction;
  final ClassHealthAction secondaryAction;
  final List<ClassHealthMetric> metrics;

  const ClassHealthRecord({
    required this.classId,
    required this.level,
    required this.levelLabel,
    required this.primaryReason,
    required this.secondaryDetail,
    required this.recommendedLabel,
    required this.recommendedDetail,
    required this.primaryAction,
    required this.secondaryAction,
    required this.metrics,
  });
}

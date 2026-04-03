import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/models/class_health_model.dart';
import 'package:gradeflow/services/class_health_service.dart';

void main() {
  final service = ClassHealthService();
  final now = DateTime(2026, 4, 3, 8, 0);

  ClassHealthStaticSignals buildStatic({
    required int studentCount,
    int gradeItemCount = 0,
    bool hasSyllabusPlan = false,
    bool hasSeatingPlan = false,
    bool hasAssignedRoomSetup = false,
    int seatingAssignedCount = -1,
    int seatingAttentionCount = 0,
    int dueNoteCount = 0,
    int overdueNoteCount = 0,
  }) {
    final assignedCount = seatingAssignedCount >= 0
        ? seatingAssignedCount
        : (hasSeatingPlan ? studentCount : 0);
    return ClassHealthStaticSignals(
      classId: 'class-a',
      className: 'Grade 10A',
      classUpdatedAt: now,
      studentCount: studentCount,
      gradeItemCount: gradeItemCount,
      hasSyllabusPlan: hasSyllabusPlan,
      syllabusEntryCount: hasSyllabusPlan ? 6 : 0,
      openNoteCount: dueNoteCount + overdueNoteCount,
      dueNoteCount: dueNoteCount,
      overdueNoteCount: overdueNoteCount,
      hasSeatingPlan: hasSeatingPlan,
      hasAssignedRoomSetup: hasAssignedRoomSetup,
      seatingSeatCount: hasSeatingPlan ? studentCount : 0,
      seatingAssignedCount: hasSeatingPlan ? assignedCount : 0,
      seatingAttentionCount: seatingAttentionCount,
    );
  }

  ClassHealthRuntimeSignals buildRuntime({
    bool hasSelectedTimetable = true,
    bool hasTimetableContext = true,
    bool isLiveNow = false,
    DateTime? nextClassStartsAt,
    int dueSoonReminderCount = 0,
    int overdueReminderCount = 0,
  }) {
    return ClassHealthRuntimeSignals(
      now: now,
      isFocused: false,
      hasSelectedTimetable: hasSelectedTimetable,
      hasTimetableContext: hasTimetableContext,
      isLiveNow: isLiveNow,
      currentClassEndsAt:
          isLiveNow ? now.add(const Duration(minutes: 40)) : null,
      nextClassStartsAt: nextClassStartsAt,
      openReminderCount: dueSoonReminderCount + overdueReminderCount,
      dueSoonReminderCount: dueSoonReminderCount,
      overdueReminderCount: overdueReminderCount,
      nextReminderText:
          dueSoonReminderCount > 0 ? 'Review progress check' : null,
      nextReminderAt:
          dueSoonReminderCount > 0 ? now.add(const Duration(hours: 2)) : null,
    );
  }

  test('flags a missing roster as urgent when class time is close', () {
    final record = service.build(
      staticSignals: buildStatic(studentCount: 0),
      runtimeSignals: buildRuntime(
        nextClassStartsAt: now.add(const Duration(minutes: 45)),
      ),
    );

    expect(record.level, ClassHealthLevel.urgent);
    expect(record.primaryReason.toLowerCase(), contains('roster'));
    expect(
        record.primaryAction.type, ClassHealthActionType.openClassesWorkspace);
  });

  test('pushes seating as the next action when a live class has no layout', () {
    final record = service.build(
      staticSignals: buildStatic(
        studentCount: 18,
        gradeItemCount: 3,
        hasSyllabusPlan: true,
        hasSeatingPlan: false,
      ),
      runtimeSignals: buildRuntime(isLiveNow: true),
    );

    expect(record.level, ClassHealthLevel.urgent);
    expect(record.primaryReason.toLowerCase(), contains('seating'));
    expect(record.primaryAction.type, ClassHealthActionType.openSeating);
  });

  test('calls out incomplete seating when some students are still unplaced',
      () {
    final record = service.build(
      staticSignals: buildStatic(
        studentCount: 22,
        gradeItemCount: 2,
        hasSyllabusPlan: true,
        hasSeatingPlan: true,
        seatingAssignedCount: 18,
      ),
      runtimeSignals: buildRuntime(
        nextClassStartsAt: now.add(const Duration(minutes: 35)),
      ),
    );

    expect(record.level, ClassHealthLevel.attention);
    expect(record.primaryReason.toLowerCase(), contains('seat'));
    expect(record.primaryAction.type, ClassHealthActionType.openSeating);
    expect(
        record.metrics.any((metric) => metric.value.contains('open')), isTrue);
  });

  test('surfaces due-soon planning work before a class feels blocked', () {
    final record = service.build(
      staticSignals: buildStatic(
        studentCount: 20,
        gradeItemCount: 2,
        hasSyllabusPlan: true,
        hasSeatingPlan: true,
      ),
      runtimeSignals: buildRuntime(
        nextClassStartsAt: now.add(const Duration(hours: 3)),
        dueSoonReminderCount: 2,
      ),
    );

    expect(record.level, ClassHealthLevel.attention);
    expect(record.primaryReason.toLowerCase(), contains('due soon'));
    expect(record.primaryAction.type, ClassHealthActionType.reviewPlanning);
  });

  test('marks a fully prepared class as ready and commercially actionable', () {
    final record = service.build(
      staticSignals: buildStatic(
        studentCount: 16,
        gradeItemCount: 4,
        hasSyllabusPlan: true,
        hasSeatingPlan: true,
        hasAssignedRoomSetup: true,
      ),
      runtimeSignals: buildRuntime(
        nextClassStartsAt: now.add(const Duration(minutes: 50)),
      ),
    );

    expect(record.level, ClassHealthLevel.ready);
    expect(record.primaryAction.type, ClassHealthActionType.openExport);
    expect(record.metrics.any((metric) => metric.label == 'Gradebook'), isTrue);
  });

  test(
      'prompts room linking when seating exists but classroom context is missing',
      () {
    final record = service.build(
      staticSignals: buildStatic(
        studentCount: 16,
        gradeItemCount: 3,
        hasSyllabusPlan: true,
        hasSeatingPlan: true,
        hasAssignedRoomSetup: false,
      ),
      runtimeSignals: buildRuntime(
        nextClassStartsAt: now.add(const Duration(minutes: 55)),
      ),
    );

    expect(record.level, ClassHealthLevel.attention);
    expect(record.primaryReason.toLowerCase(), contains('room layout'));
    expect(record.primaryAction.type, ClassHealthActionType.openSeating);
    expect(record.metrics.any((metric) => metric.label == 'Room'), isTrue);
  });
}

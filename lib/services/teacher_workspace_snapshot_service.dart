import 'package:gradeflow/models/class.dart';
import 'package:gradeflow/models/user.dart';
import 'package:gradeflow/repositories/repository_factory.dart';
import 'package:gradeflow/services/dashboard_preferences_service.dart';

class TeacherWorkspaceReminderSnapshot {
  final String text;
  final DateTime timestamp;
  final bool done;
  final List<String> classIds;

  const TeacherWorkspaceReminderSnapshot({
    required this.text,
    required this.timestamp,
    required this.done,
    required this.classIds,
  });

  bool get isSchoolWide => classIds.isEmpty;
}

class TeacherWorkspaceSnapshot {
  final User user;
  final List<Class> activeClasses;
  final List<Class> archivedClasses;
  final int totalStudents;
  final List<TeacherWorkspaceReminderSnapshot> reminders;

  const TeacherWorkspaceSnapshot({
    required this.user,
    required this.activeClasses,
    required this.archivedClasses,
    required this.totalStudents,
    required this.reminders,
  });

  List<TeacherWorkspaceReminderSnapshot> get pendingReminders =>
      reminders.where((reminder) => !reminder.done).toList()
        ..sort((left, right) => left.timestamp.compareTo(right.timestamp));

  List<TeacherWorkspaceReminderSnapshot> get schoolWidePendingReminders =>
      pendingReminders.where((reminder) => reminder.isSchoolWide).toList();
}

class TeacherWorkspaceSnapshotService {
  const TeacherWorkspaceSnapshotService({
    DashboardPreferencesService dashboardPreferencesService =
        const DashboardPreferencesService(),
  }) : _dashboardPreferencesService = dashboardPreferencesService;

  final DashboardPreferencesService _dashboardPreferencesService;

  Future<TeacherWorkspaceSnapshot> loadForUser(User user) async {
    final repository = RepositoryFactory.instance;
    final allClasses = await repository.loadClasses();
    final teacherClasses =
        allClasses.where((item) => item.teacherId == user.userId).toList();
    final activeClasses =
        teacherClasses.where((item) => !item.isArchived).toList();
    final archivedClasses =
        teacherClasses.where((item) => item.isArchived).toList();

    int totalStudents = 0;
    for (final classItem in activeClasses) {
      final students = await repository.loadStudents(classItem.classId);
      totalStudents += students.length;
    }

    final reminders = await _loadReminders(user.userId);

    return TeacherWorkspaceSnapshot(
      user: user,
      activeClasses: activeClasses,
      archivedClasses: archivedClasses,
      totalStudents: totalStudents,
      reminders: reminders,
    );
  }

  Future<List<TeacherWorkspaceReminderSnapshot>> _loadReminders(
    String userId,
  ) async {
    final scopedKey = _dashboardPreferencesService.scopedKey(
      baseKey: 'dashboard_reminders_v1',
      userId: userId,
    );

    final list = await _dashboardPreferencesService.readScopedJsonList(
      scopedKey: scopedKey,
      legacyKey: 'dashboard_reminders',
      migrationFlagKey: 'dashboard_reminders_migrated_v1',
    );

    return list.whereType<Map>().map((rawItem) {
      final item = Map<String, dynamic>.from(rawItem);
      final classIds = (item['classIds'] as List?)
              ?.map((value) => value?.toString() ?? '')
              .where((value) => value.trim().isNotEmpty)
              .toList() ??
          const <String>[];

      return TeacherWorkspaceReminderSnapshot(
        text: (item['text'] ?? '').toString(),
        timestamp: DateTime.tryParse((item['timestamp'] ?? '').toString()) ??
            DateTime.now(),
        done: (item['done'] as bool?) ?? false,
        classIds: classIds,
      );
    }).toList();
  }
}

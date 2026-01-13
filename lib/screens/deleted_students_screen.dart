import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gradeflow/services/student_trash_service.dart';
import 'package:gradeflow/services/student_service.dart';
import 'package:gradeflow/services/student_score_service.dart';
import 'package:gradeflow/services/final_exam_service.dart';
import 'package:gradeflow/models/deleted_student_entry.dart';
import 'package:gradeflow/theme.dart';

class DeletedStudentsScreen extends StatefulWidget {
  final String classId;
  const DeletedStudentsScreen({super.key, required this.classId});

  @override
  State<DeletedStudentsScreen> createState() => _DeletedStudentsScreenState();
}

class _DeletedStudentsScreenState extends State<DeletedStudentsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async =>
      context.read<StudentTrashService>().loadTrash(classId: widget.classId);

  Future<void> _restore(DeletedStudentEntry entry) async {
    final studentSvc = context.read<StudentService>();
    final scoreSvc = context.read<StudentScoreService>();
    final examSvc = context.read<FinalExamService>();
    final trashSvc = context.read<StudentTrashService>();
    try {
      await studentSvc.addStudent(entry.student);
      if (entry.scores.isNotEmpty) {
        await scoreSvc.restoreScoresForStudent(widget.classId, entry.scores);
      }
      if (entry.exam != null) {
        await examSvc.restoreExam(widget.classId, entry.exam!);
      }
      await trashSvc.removeFromTrash(entry.student.studentId);
      if (!context.mounted) return;
      _toast('Restored ${entry.student.chineseName}');
    } catch (e) {
      debugPrint('Restore failed: $e');
      if (mounted) _error('Failed to restore');
    }
  }

  Future<void> _deleteForever(String studentId) async {
    await context.read<StudentTrashService>().removeFromTrash(studentId);
    if (!context.mounted) return;
    _toast('Removed from bin');
  }

  Future<void> _emptyBin() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Empty Bin'),
        content:
            const Text('Permanently delete all items in this class\'s bin?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Empty')),
        ],
      ),
    );
    if (confirmed == true) {
      final removed = await context
          .read<StudentTrashService>()
          .emptyTrash(classId: widget.classId);
      if (!context.mounted) return;
      _toast('Deleted $removed item(s)');
    }
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  void _error(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(m), backgroundColor: Theme.of(context).colorScheme.error));

  @override
  Widget build(BuildContext context) {
    final trashSvc = context.watch<StudentTrashService>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Restore Bin'),
        actions: [
          IconButton(
              onPressed: _emptyBin,
              icon: const Icon(Icons.delete_forever),
              tooltip: 'Empty Bin'),
        ],
      ),
      body: trashSvc.isLoading
          ? const Center(child: CircularProgressIndicator())
          : trashSvc.trash.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.restore_from_trash,
                          size: 64,
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant),
                      const SizedBox(height: AppSpacing.md),
                      const Text('Nothing in the bin'),
                      const SizedBox(height: AppSpacing.sm),
                      const Text(
                          'Deleted students appear here for manual restore'),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: AppSpacing.paddingMd,
                  itemCount: trashSvc.trash.length,
                  itemBuilder: (context, index) {
                    final entry = trashSvc.trash[index];
                    final student = entry.student;
                    return Card(
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: ListTile(
                        leading: const Icon(Icons.person_off),
                        title: Text(
                            '${student.chineseName} (${student.englishFullName})'),
                        subtitle: Text(
                            'ID: ${student.studentId} • Deleted: ${_format(entry.deletedAt)} • Scores: ${entry.scores.length}${entry.exam != null ? ' • Exam' : ''}'),
                        trailing: Wrap(spacing: 8, children: [
                          TextButton.icon(
                              onPressed: () => _restore(entry),
                              icon: const Icon(Icons.restore),
                              label: const Text('Restore')),
                          IconButton(
                              onPressed: () =>
                                  _deleteForever(student.studentId),
                              icon: const Icon(Icons.delete_outline),
                              tooltip: 'Delete forever'),
                        ]),
                      ),
                    );
                  },
                ),
    );
  }

  String _format(DateTime dt) {
    final d =
        '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    final t =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    return '$d $t';
  }
}

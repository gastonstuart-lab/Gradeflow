import 'package:flutter/material.dart';
import 'package:gradeflow/models/deleted_class_entry.dart';
import 'package:gradeflow/services/auth_service.dart';
import 'package:gradeflow/services/class_service.dart';
import 'package:gradeflow/services/class_trash_service.dart';
import 'package:gradeflow/services/grade_item_service.dart';
import 'package:gradeflow/services/grading_category_service.dart';
import 'package:gradeflow/services/student_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gradeflow/theme.dart';

class DeletedClassesScreen extends StatefulWidget {
  const DeletedClassesScreen({super.key});

  @override
  State<DeletedClassesScreen> createState() => _DeletedClassesScreenState();
}

class _DeletedClassesScreenState extends State<DeletedClassesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final auth = context.read<AuthService>();
    final user = auth.currentUser;
    if (user == null) return;
    final trashSvc = context.read<ClassTrashService>();
    await trashSvc.loadTrash(teacherId: user.userId);
  }

  Future<void> _restore(DeletedClassEntry entry) async {
    final classSvc = context.read<ClassService>();
    final trashSvc = context.read<ClassTrashService>();

    try {
      await classSvc.addClass(entry.classItem);
      await trashSvc.removeFromTrash(entry.classItem.classId);
      if (mounted) _toast('Restored ${entry.classItem.className}');
    } catch (e) {
      debugPrint('Restore class failed: $e');
      if (mounted) _error('Failed to restore');
    }
  }

  Future<void> _deleteForever(DeletedClassEntry entry) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete forever?'),
        content: const Text('This permanently deletes the class and its data (students, categories, grade items).'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (!mounted) return;
    if (ok != true) return;

    final classId = entry.classItem.classId;

    final classSvc = context.read<ClassService>();
    final trashSvc = context.read<ClassTrashService>();
    final studentSvc = context.read<StudentService>();
    final categorySvc = context.read<GradingCategoryService>();
    final gradeItemSvc = context.read<GradeItemService>();

    try {
      await studentSvc.loadStudents(classId);
      for (final s in List.of(studentSvc.students)) {
        await studentSvc.deleteStudent(s.studentId);
      }

      await gradeItemSvc.loadGradeItems(classId);
      for (final gi in List.of(gradeItemSvc.gradeItems)) {
        await gradeItemSvc.deleteGradeItem(gi.gradeItemId);
      }

      await categorySvc.loadCategories(classId);
      for (final c in List.of(categorySvc.categories)) {
        await categorySvc.deleteCategory(c.categoryId);
      }

      // Clear per-class schedule storage (if any)
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('class_schedule_v1:$classId');

      // Ensure the class itself is gone
      await classSvc.deleteClass(classId);

      await trashSvc.removeFromTrash(classId);

      if (mounted) _toast('Deleted permanently');
    } catch (e) {
      debugPrint('Permanent delete failed: $e');
      if (mounted) _error('Failed to delete');
    }
  }

  Future<void> _emptyBin() async {
    final auth = context.read<AuthService>();
    final user = auth.currentUser;
    if (user == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Empty Bin'),
        content: const Text('Permanently delete all classes in the bin?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Empty')),
        ],
      ),
    );
    if (!mounted) return;

    if (confirmed == true) {
      final trashSvc = context.read<ClassTrashService>();
      final removed = await trashSvc.emptyTrash(teacherId: user.userId);
      if (mounted) _toast('Deleted $removed item(s)');
    }
  }

  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  void _error(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: Theme.of(context).colorScheme.error));

  @override
  Widget build(BuildContext context) {
    final trashSvc = context.watch<ClassTrashService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Class Recycle Bin'),
        actions: [
          IconButton(onPressed: _emptyBin, icon: const Icon(Icons.delete_forever), tooltip: 'Empty Bin'),
        ],
      ),
      body: trashSvc.isLoading
          ? const Center(child: CircularProgressIndicator())
          : trashSvc.trash.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.restore_from_trash, size: 64, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      const SizedBox(height: AppSpacing.md),
                      const Text('Nothing in the bin'),
                      const SizedBox(height: AppSpacing.sm),
                      const Text('Deleted classes appear here for manual restore'),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: AppSpacing.paddingMd,
                  itemCount: trashSvc.trash.length,
                  itemBuilder: (context, index) {
                    final entry = trashSvc.trash[index];
                    final c = entry.classItem;
                    return Card(
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: ListTile(
                        leading: const Icon(Icons.class_),
                        title: Text(c.className),
                        subtitle: Text('${c.subject} • ${c.schoolYear} • ${c.term} • Deleted: ${_format(entry.deletedAt)}'),
                        trailing: Wrap(spacing: 8, children: [
                          TextButton.icon(onPressed: () => _restore(entry), icon: const Icon(Icons.restore), label: const Text('Restore')),
                          IconButton(onPressed: () => _deleteForever(entry), icon: const Icon(Icons.delete_outline), tooltip: 'Delete forever'),
                        ]),
                      ),
                    );
                  },
                ),
    );
  }

  String _format(DateTime dt) {
    final d = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    final t = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    return '$d $t';
  }
}

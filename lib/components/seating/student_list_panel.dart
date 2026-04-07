import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gradeflow/components/seating/seating_canvas.dart';
import 'package:gradeflow/models/student.dart';

enum StudentListSortMode { studentIdAsc, nameAsc }

class StudentListPanel extends StatefulWidget {
  final List<Student> students;
  final Set<String> assignedStudentIds;
  final bool compact;
  final StudentListSortMode initialSortMode;

  const StudentListPanel({
    super.key,
    required this.students,
    required this.assignedStudentIds,
    required this.compact,
    this.initialSortMode = StudentListSortMode.studentIdAsc,
  });

  @override
  State<StudentListPanel> createState() => _StudentListPanelState();
}

class _StudentListPanelState extends State<StudentListPanel> {
  late StudentListSortMode _sortMode;

  @override
  void initState() {
    super.initState();
    _sortMode = widget.initialSortMode;
  }

  @override
  Widget build(BuildContext context) {
    final unassigned = widget.students
        .where((s) => !widget.assignedStudentIds.contains(s.studentId))
        .toList();
    final sortedUnassigned = _sortStudents(unassigned);
    final assignedCount = widget.students.length - unassigned.length;
    final listBody = _buildStudentList(sortedUnassigned);

    return Container(
      width: widget.compact ? double.infinity : 280,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cramped = constraints.maxHeight.isFinite &&
              constraints.maxHeight < 180;

          if (cramped) {
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context, unassigned.length, assignedCount),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 180,
                    child: listBody,
                  ),
                ],
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, unassigned.length, assignedCount),
              const SizedBox(height: 12),
              Expanded(child: listBody),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, int unassignedCount, int assignedCount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Students',
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            PopupMenuButton<StudentListSortMode>(
              onSelected: (value) => setState(() => _sortMode = value),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: StudentListSortMode.studentIdAsc,
                  child: Text('Student ID (Ascending)'),
                ),
                const PopupMenuItem(
                  value: StudentListSortMode.nameAsc,
                  child: Text('Name (A-Z)'),
                ),
              ],
              child: Tooltip(
                message: 'Sort students',
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.sort,
                        size: 18,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _sortMode == StudentListSortMode.studentIdAsc
                            ? 'ID asc'
                            : 'Name',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Text(
                '$unassignedCount unassigned | $assignedCount placed',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
            Text(
              _sortMode == StudentListSortMode.studentIdAsc
                  ? 'Sorted by ID'
                  : 'Sorted by name',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStudentList(List<Student> sortedUnassigned) {
    if (sortedUnassigned.isEmpty) {
      return const _StudentPanelEmptyState();
    }

    return ListView.separated(
      itemCount: sortedUnassigned.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final student = sortedUnassigned[index];
        final chip = _StudentChip(
          title: '${student.chineseName} (${student.englishFullName})',
          subtitle: 'ID: ${student.studentId}',
        );
        final feedback = Material(
          color: Colors.transparent,
          child: _StudentChip(
            title: '${student.chineseName} (${student.englishFullName})',
            subtitle: 'ID: ${student.studentId}',
            expand: false,
          ),
        );

        if (_usesImmediateMouseDrag) {
          return Draggable<StudentDragData>(
            data: StudentDragData(studentId: student.studentId),
            feedback: feedback,
            childWhenDragging: Opacity(opacity: 0.35, child: chip),
            child: chip,
          );
        }

        return LongPressDraggable<StudentDragData>(
          data: StudentDragData(studentId: student.studentId),
          feedback: feedback,
          childWhenDragging: Opacity(opacity: 0.35, child: chip),
          child: chip,
        );
      },
    );
  }

  List<Student> _sortStudents(List<Student> students) {
    final sorted = List<Student>.from(students);
    switch (_sortMode) {
      case StudentListSortMode.studentIdAsc:
        sorted.sort(_compareStudentsByStudentId);
        break;
      case StudentListSortMode.nameAsc:
        sorted.sort(_compareStudentsByName);
        break;
    }
    return sorted;
  }

  int _compareStudentsByStudentId(Student left, Student right) {
    final idCompare = _naturalCompare(
      left.studentId.toLowerCase(),
      right.studentId.toLowerCase(),
    );
    if (idCompare != 0) return idCompare;
    return _compareStudentsByName(left, right);
  }

  int _compareStudentsByName(Student left, Student right) {
    final chineseCompare =
        left.chineseName.toLowerCase().compareTo(right.chineseName.toLowerCase());
    if (chineseCompare != 0) return chineseCompare;

    final englishCompare = left.englishFullName
        .toLowerCase()
        .compareTo(right.englishFullName.toLowerCase());
    if (englishCompare != 0) return englishCompare;

    return _naturalCompare(
      left.studentId.toLowerCase(),
      right.studentId.toLowerCase(),
    );
  }

  int _naturalCompare(String left, String right) {
    final leftParts = RegExp(r'\d+|\D+')
        .allMatches(left)
        .map((match) => match.group(0)!)
        .toList();
    final rightParts = RegExp(r'\d+|\D+')
        .allMatches(right)
        .map((match) => match.group(0)!)
        .toList();
    final limit =
        leftParts.length < rightParts.length ? leftParts.length : rightParts.length;

    for (int i = 0; i < limit; i++) {
      final leftPart = leftParts[i];
      final rightPart = rightParts[i];
      final leftNumber = int.tryParse(leftPart);
      final rightNumber = int.tryParse(rightPart);
      final compare = leftNumber != null && rightNumber != null
          ? leftNumber.compareTo(rightNumber)
          : leftPart.compareTo(rightPart);
      if (compare != 0) return compare;
    }

    return leftParts.length.compareTo(rightParts.length);
  }
}

class _StudentPanelEmptyState extends StatelessWidget {
  const _StudentPanelEmptyState();

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.onSurfaceVariant;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.task_alt,
              size: 28,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 10),
            Text(
              'Everyone is seated',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tap any seat to review, recolor, or clear it.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: textColor,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

bool get _usesImmediateMouseDrag {
  if (kIsWeb) return true;
  switch (defaultTargetPlatform) {
    case TargetPlatform.macOS:
    case TargetPlatform.windows:
    case TargetPlatform.linux:
      return true;
    case TargetPlatform.android:
    case TargetPlatform.iOS:
    case TargetPlatform.fuchsia:
      return false;
  }
}

class _StudentChip extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool expand;

  const _StudentChip({
    required this.title,
    required this.subtitle,
    this.expand = true,
  });

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).colorScheme.primaryContainer;
    final fg = Theme.of(context).colorScheme.onPrimaryContainer;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.person, size: 16, color: fg),
          const SizedBox(width: 6),
          if (expand)
            Expanded(
              child: _StudentChipText(
                title: title,
                subtitle: subtitle,
                color: fg,
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: _StudentChipText(
                title: title,
                subtitle: subtitle,
                color: fg,
              ),
            ),
        ],
      ),
    );
  }
}

class _StudentChipText extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;

  const _StudentChipText({
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context)
              .textTheme
              .labelMedium
              ?.copyWith(color: color),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: color.withValues(alpha: 0.85),
              ),
        ),
      ],
    );
  }
}

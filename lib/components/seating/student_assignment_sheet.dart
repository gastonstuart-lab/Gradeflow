import 'package:flutter/material.dart';
import 'package:gradeflow/models/seating_layout.dart';
import 'package:gradeflow/models/student.dart';

class StudentAssignmentSheet extends StatefulWidget {
  final List<Student> students;
  final List<SeatingSeat> seats;
  final String targetSeatId;
  final ValueChanged<Student> onSelected;

  const StudentAssignmentSheet({
    super.key,
    required this.students,
    required this.seats,
    required this.targetSeatId,
    required this.onSelected,
  });

  @override
  State<StudentAssignmentSheet> createState() => _StudentAssignmentSheetState();
}

class _StudentAssignmentSheetState extends State<StudentAssignmentSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sortedStudents = _sortedStudents(widget.students);
    final filteredStudents = sortedStudents
        .where((student) => _matchesQuery(student, _query))
        .toList();
    final currentSeat =
        widget.seats.firstWhere((seat) => seat.seatId == widget.targetSeatId);
    final currentStudentId = currentSeat.studentId;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, bottomInset + 16),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.72,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                currentStudentId == null
                    ? 'Assign student'
                    : 'Swap or replace student',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Choose anyone from the roster. If they already have a seat, the placements swap.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _searchController,
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Search by name, seat number, or ID',
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(Icons.close),
                          tooltip: 'Clear search',
                        ),
                ),
                onChanged: (value) => setState(() => _query = value.trim()),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: filteredStudents.isEmpty
                    ? const _StudentAssignmentEmptyState()
                    : ListView.separated(
                        itemCount: filteredStudents.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final student = filteredStudents[index];
                          final assignedSeat =
                              widget.seats.cast<SeatingSeat?>().firstWhere(
                                    (seat) =>
                                        seat?.studentId == student.studentId,
                                    orElse: () => null,
                                  );
                          final isCurrentStudent =
                              student.studentId == currentStudentId;

                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: _SeatBadge(seatNo: student.seatNo),
                            title: Text(
                              '${student.chineseName} (${student.englishFullName})',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              _studentSubtitle(
                                student: student,
                                assignedSeat: assignedSeat,
                                isCurrentStudent: isCurrentStudent,
                              ),
                            ),
                            trailing: Icon(
                              isCurrentStudent
                                  ? Icons.check_circle
                                  : assignedSeat == null
                                      ? Icons.person_add_alt_1_outlined
                                      : Icons.swap_horiz,
                              color: isCurrentStudent
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                            ),
                            onTap: () => widget.onSelected(student),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _matchesQuery(Student student, String query) {
    if (query.isEmpty) return true;
    final normalized = query.toLowerCase();
    return student.chineseName.toLowerCase().contains(normalized) ||
        student.englishFullName.toLowerCase().contains(normalized) ||
        (student.seatNo ?? '').toLowerCase().contains(normalized) ||
        student.studentId.toLowerCase().contains(normalized);
  }

  List<Student> _sortedStudents(List<Student> students) {
    final sorted = List<Student>.from(students);
    sorted.sort((a, b) {
      final idCompare = _naturalCompare(
        a.studentId.toLowerCase(),
        b.studentId.toLowerCase(),
      );
      if (idCompare != 0) return idCompare;
      return a.englishFullName
          .toLowerCase()
          .compareTo(b.englishFullName.toLowerCase());
    });
    return sorted;
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

  String _studentSubtitle({
    required Student student,
    required SeatingSeat? assignedSeat,
    required bool isCurrentStudent,
  }) {
    if (isCurrentStudent) {
      return 'ID ${student.studentId} | Currently in this seat';
    }
    if (assignedSeat != null) {
      final seatNumber = widget.seats
              .indexWhere((seat) => seat.seatId == assignedSeat.seatId) +
          1;
      return 'ID ${student.studentId} | Currently in seat $seatNumber';
    }
    if (student.seatNo != null && student.seatNo!.trim().isNotEmpty) {
      return 'ID ${student.studentId} | Roster seat ${student.seatNo}';
    }
    return 'ID ${student.studentId} | Not placed yet';
  }
}

class _SeatBadge extends StatelessWidget {
  final String? seatNo;

  const _SeatBadge({
    required this.seatNo,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final label = (seatNo ?? '').trim();

    return CircleAvatar(
      radius: 18,
      backgroundColor: colorScheme.primaryContainer,
      foregroundColor: colorScheme.onPrimaryContainer,
      child: label.isEmpty
          ? const Icon(Icons.person, size: 18)
          : Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
    );
  }
}

class _StudentAssignmentEmptyState extends StatelessWidget {
  const _StudentAssignmentEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off,
              size: 30,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 10),
            Text(
              'No matching students',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Try a different name, seat number, or student ID.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:gradeflow/models/student.dart';

class StudentPickerEntry {
  final Student student;
  final String? seatLabel;

  const StudentPickerEntry({
    required this.student,
    this.seatLabel,
  });
}

class StudentPickerSheet extends StatefulWidget {
  final List<StudentPickerEntry> entries;

  const StudentPickerSheet({
    super.key,
    required this.entries,
  });

  @override
  State<StudentPickerSheet> createState() => _StudentPickerSheetState();
}

class _StudentPickerSheetState extends State<StudentPickerSheet> {
  final math.Random _random = math.Random();
  final Set<String> _pickedStudentIds = {};
  Timer? _animationTimer;
  int _activeIndex = 0;
  bool _isPicking = false;
  bool _avoidRepeats = true;

  @override
  void dispose() {
    _animationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pool = _availableEntries();
    final activeEntry = pool.isEmpty
        ? null
        : pool[_activeIndex.clamp(0, math.max(0, pool.length - 1))];

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.72,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pick a student',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Use the seating plan as a quick randomizer for questions, reading turns, or checks for understanding.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 16),
              _PickerCard(
                entry: activeEntry,
                isPicking: _isPicking,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: pool.isEmpty || _isPicking ? null : _pickStudent,
                    icon: Icon(_isPicking ? Icons.hourglass_top : Icons.casino),
                    label: Text(_isPicking ? 'Picking...' : 'Pick student'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _pickedStudentIds.isEmpty && !_avoidRepeats
                        ? null
                        : () {
                            setState(() {
                              _pickedStudentIds.clear();
                              _activeIndex = 0;
                            });
                          },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reset round'),
                  ),
                  FilterChip(
                    label: const Text('Avoid repeats'),
                    selected: _avoidRepeats,
                    onSelected: (value) {
                      setState(() {
                        _avoidRepeats = value;
                        if (!_avoidRepeats) {
                          _pickedStudentIds.clear();
                        }
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                _avoidRepeats
                    ? '${_pickedStudentIds.length} already picked this round'
                    : 'Repeats allowed',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: pool.isEmpty
                    ? const _PickerEmptyState()
                    : ListView.separated(
                        itemCount: widget.entries.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final entry = widget.entries[index];
                          final isPicked = _pickedStudentIds
                              .contains(entry.student.studentId);
                          final isActive = activeEntry?.student.studentId ==
                              entry.student.studentId;
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isActive
                                  ? Theme.of(context)
                                      .colorScheme
                                      .primaryContainer
                                  : Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                              foregroundColor: isActive
                                  ? Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer
                                  : Theme.of(context).colorScheme.onSurface,
                              child: Text(
                                '${index + 1}',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                            title: Text(
                              '${entry.student.chineseName} (${entry.student.englishFullName})',
                            ),
                            subtitle: Text(
                              entry.seatLabel ?? 'Not currently seated',
                            ),
                            trailing: isPicked
                                ? Icon(
                                    Icons.check_circle,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  )
                                : null,
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

  List<StudentPickerEntry> _availableEntries() {
    if (!_avoidRepeats) {
      return widget.entries;
    }

    final remaining = widget.entries
        .where((entry) => !_pickedStudentIds.contains(entry.student.studentId))
        .toList();
    return remaining.isNotEmpty ? remaining : widget.entries;
  }

  Future<void> _pickStudent() async {
    final pool = _availableEntries();
    if (pool.isEmpty) return;

    _animationTimer?.cancel();
    setState(() {
      _isPicking = true;
      _activeIndex = 0;
    });

    final stopIndex = _random.nextInt(pool.length);
    var ticks = 0;
    final totalTicks = 18 + _random.nextInt(10);
    final completer = Completer<void>();

    _animationTimer = Timer.periodic(const Duration(milliseconds: 90), (timer) {
      if (!mounted) {
        timer.cancel();
        if (!completer.isCompleted) completer.complete();
        return;
      }

      setState(() {
        _activeIndex = (_activeIndex + 1) % pool.length;
      });
      ticks++;

      if (ticks >= totalTicks) {
        timer.cancel();
        setState(() {
          _activeIndex = stopIndex;
          _isPicking = false;
          if (_avoidRepeats) {
            _pickedStudentIds.add(pool[stopIndex].student.studentId);
          }
        });
        if (!completer.isCompleted) completer.complete();
      }
    });

    await completer.future;
  }
}

class _PickerCard extends StatelessWidget {
  final StudentPickerEntry? entry;
  final bool isPicking;

  const _PickerCard({
    required this.entry,
    required this.isPicking,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isPicking ? scheme.primaryContainer : scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isPicking ? scheme.primary : scheme.outlineVariant,
          width: isPicking ? 2 : 1,
        ),
      ),
      child: entry == null
          ? Text(
              'No students are available to pick.',
              style: Theme.of(context).textTheme.titleMedium,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPicking ? 'Choosing...' : 'Selected student',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: isPicking
                            ? scheme.onPrimaryContainer
                            : scheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 10),
                Text(
                  entry!.student.chineseName,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: isPicking
                            ? scheme.onPrimaryContainer
                            : scheme.onSurface,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  entry!.student.englishFullName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: isPicking
                            ? scheme.onPrimaryContainer
                            : scheme.onSurface,
                      ),
                ),
                if (entry!.seatLabel != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    entry!.seatLabel!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: isPicking
                              ? scheme.onPrimaryContainer
                              : scheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ],
            ),
    );
  }
}

class _PickerEmptyState extends StatelessWidget {
  const _PickerEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.groups_2_outlined,
              size: 30,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 10),
            Text(
              'Seat a few students first',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'The picker works best once your seating plan has students placed in it.',
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

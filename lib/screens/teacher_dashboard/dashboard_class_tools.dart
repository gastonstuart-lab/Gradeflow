// ignore_for_file: invalid_use_of_protected_member, library_private_types_in_public_api

part of '../teacher_dashboard_screen.dart';

extension TeacherDashboardClassTools on _TeacherDashboardScreenState {
  void _openSeatingPlan() {
    _openSelectedClassRouteSafely(context, 'seating');
  }

  // ===== Class Tools UI builder =====
  Widget _buildClassToolsBody(BuildContext context) {
    switch (_selectedToolTab) {
      case 0:
        return _buildNamePicker(context);
      case 1:
        return _buildGroups(context);
      case 2:
        return _buildParticipation(context);
      case 3:
        return _buildScheduleTool(context);
      case 4:
        return _buildQuickPoll(context);
      case 5:
        return _buildTimerTool(context);
      case 6:
        return _buildQrTool(context);
      case 7:
        return _buildWhiteboardTool(context, compact: true);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildScheduleTool(BuildContext context) {
    final classId = _selectedClassId;
    if (classId == null) {
      return Text('Select a class to view its schedule.',
          style: context.textStyles.bodySmall
              ?.withColor(Theme.of(context).colorScheme.onSurfaceVariant));
    }

    final className = _classes
        .firstWhere((c) => c.id == classId,
            orElse: () => _ClassBrief(id: classId, name: 'Class', subtitle: ''))
        .name;
    final items = _scheduleByClass[classId] ?? const <ClassScheduleItem>[];

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final upcoming = items.where((i) {
      if (i.date == null) return false;
      final d = DateTime(i.date!.year, i.date!.month, i.date!.day);
      return !d.isBefore(today);
    }).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.menu_book_outlined),
        const SizedBox(width: 8),
        Expanded(
            child: Text('Schedule - $className',
                style: context.textStyles.titleSmall?.semiBold)),
        OutlinedButton.icon(
          onPressed: _scheduleBusy ? null : _importClassSchedule,
          icon: const Icon(Icons.drive_folder_upload_outlined),
          label: Text(_scheduleBusy ? 'Importing...' : 'Upload'),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: _scheduleBusy ? null : _importClassScheduleFromDrive,
          icon: const Icon(Icons.folder_shared_outlined),
          label: const Text('Google Drive'),
        ),
      ]),
      const SizedBox(height: 10),
      if (items.isEmpty)
        Text(
            'No schedule saved for this class yet. Upload the class plan (CSV/XLSX) to view it neatly here.',
            style: context.textStyles.bodySmall
                ?.withColor(Theme.of(context).colorScheme.onSurfaceVariant))
      else ...[
        Text('Next up', style: context.textStyles.titleSmall?.semiBold),
        const SizedBox(height: 6),
        if (upcoming.isEmpty)
          Text(
              'No upcoming dated items found. (If your file uses weeks instead of dates, scroll down to Semester.)',
              style: context.textStyles.bodySmall
                  ?.withColor(Theme.of(context).colorScheme.onSurfaceVariant))
        else
          ...upcoming.take(5).map((i) => _scheduleTile(context, i)),
        const SizedBox(height: 12),
        Text('Semester', style: context.textStyles.titleSmall?.semiBold),
        const SizedBox(height: 6),
        ..._buildSemesterScheduleList(context, items),
      ]
    ]);
  }

  Widget _scheduleTile(BuildContext context, ClassScheduleItem item) {
    final when = item.date != null
        ? _formatDate(item.date!)
        : (item.week != null ? 'Week ${item.week}' : '');

    final subtitleParts = <String>[];
    final book = item.details['Book'];
    final unit = item.details['Chapter/Unit'];
    final hw = item.details['Homework'];
    final assess = item.details['Assessment'];
    if (book != null && book.trim().isNotEmpty) subtitleParts.add(book.trim());
    if (unit != null && unit.trim().isNotEmpty) subtitleParts.add(unit.trim());
    if (hw != null && hw.trim().isNotEmpty) {
      subtitleParts.add('HW: ${hw.trim()}');
    }
    if (assess != null && assess.trim().isNotEmpty) {
      subtitleParts.add('Assess: ${assess.trim()}');
    }

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: when.isEmpty
          ? null
          : SizedBox(
              width: 86,
              child: Text(when,
                  style: context.textStyles.labelMedium?.withColor(
                      Theme.of(context).colorScheme.onSurfaceVariant))),
      title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: subtitleParts.isEmpty
          ? null
          : Text(subtitleParts.join(' • '),
              maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: () => _showScheduleItemDetails(item),
    );
  }

  List<Widget> _buildSemesterScheduleList(
      BuildContext context, List<ClassScheduleItem> items) {
    final hasDates = items.any((i) => i.date != null);
    final widgets = <Widget>[];

    if (hasDates) {
      final byMonth = <String, List<ClassScheduleItem>>{};
      for (final i in items) {
        if (i.date == null) continue;
        final key = '${i.date!.year}-${_two(i.date!.month)}';
        byMonth.putIfAbsent(key, () => []).add(i);
      }
      final keys = byMonth.keys.toList()..sort();
      for (final k in keys) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 2),
          child: Text(k, style: context.textStyles.labelLarge?.semiBold),
        ));
        for (final i in byMonth[k]!
          ..sort((a, b) => a.date!.compareTo(b.date!))) {
          widgets.add(_scheduleTile(context, i));
        }
      }
      return widgets;
    }

    final byWeek = <int, List<ClassScheduleItem>>{};
    final unknown = <ClassScheduleItem>[];
    for (final i in items) {
      if (i.week != null) {
        byWeek.putIfAbsent(i.week!, () => []).add(i);
      } else {
        unknown.add(i);
      }
    }
    final weeks = byWeek.keys.toList()..sort();
    for (final w in weeks) {
      widgets.add(Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 2),
        child: Text('Week $w', style: context.textStyles.labelLarge?.semiBold),
      ));
      for (final i in byWeek[w]!) {
        widgets.add(_scheduleTile(context, i));
      }
    }
    if (unknown.isNotEmpty) {
      widgets.add(Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 2),
        child: Text('Other', style: context.textStyles.labelLarge?.semiBold),
      ));
      for (final i in unknown) {
        widgets.add(_scheduleTile(context, i));
      }
    }
    return widgets;
  }

  Future<void> _showScheduleItemDetails(ClassScheduleItem item) async {
    final when = item.date != null
        ? _formatDate(item.date!)
        : (item.week != null ? 'Week ${item.week}' : '');

    final detailsLines = <String>[];
    for (final entry in item.details.entries) {
      if (entry.key.trim().isEmpty || entry.value.trim().isEmpty) continue;
      detailsLines.add('${entry.key}: ${entry.value}');
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(item.title),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: SelectableText(
              [
                if (when.isNotEmpty) when,
                if (detailsLines.isNotEmpty) detailsLines.join('\n'),
              ].where((s) => s.trim().isNotEmpty).join('\n\n'),
            ),
          ),
        ),
        actions: [
          FilledButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Close'))
        ],
      ),
    );
  }

  Future<void> _openPresent() async {
    // Full-screen overlay to present the currently selected Class Tool
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return Scaffold(
              backgroundColor: Colors.transparent,
              body: SafeArea(
                child: Stack(children: [
                  // Center content
                  Positioned.fill(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Theme.of(ctx).colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      margin: const EdgeInsets.all(16),
                      child: _buildPresentBody(ctx, setDialogState),
                    ),
                  ),
                  // Close button
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton(
                      style: IconButton.styleFrom(
                          backgroundColor: Theme.of(ctx).colorScheme.surface),
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ),
                ]),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPresentBody(BuildContext ctx, StateSetter setDialogState) {
    switch (_selectedToolTab) {
      // Name picker: giant text and a big Next button
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(children: [
              const Icon(Icons.casino_outlined),
              const SizedBox(width: 8),
              Text('Name Picker', style: Theme.of(ctx).textTheme.titleLarge)
            ]),
            const SizedBox(height: 24),
            Expanded(
              child: Center(
                child: Text(
                  _pickedName == null
                      ? 'Tap Next to pick a student'
                      : _pickedName!,
                  textAlign: TextAlign.center,
                  style: Theme.of(ctx)
                      .textTheme
                      .displaySmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              FilledButton.icon(
                onPressed: () {
                  _pickRandomName();
                  setDialogState(() {});
                },
                icon: const Icon(Icons.play_arrow),
                label: const Text('Next Student'),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                  onPressed: () => Navigator.of(ctx).pop(),
                  icon: const Icon(Icons.close),
                  label: const Text('Close')),
            ]),
          ],
        );

      // Groups: show groups big; allow regenerate and quick pairs
      case 1:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.groups_outlined),
            const SizedBox(width: 8),
            Text('Group Maker', style: Theme.of(ctx).textTheme.titleLarge)
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            SizedBox(
              width: 120,
              child: TextField(
                decoration: const InputDecoration(
                    labelText: 'Group Size', isDense: true),
                keyboardType: TextInputType.number,
                onChanged: (v) =>
                    setState(() => _groupSize = int.tryParse(v) ?? 2),
              ),
            ),
            FilledButton.icon(
              onPressed: () {
                _makeGroups();
                setDialogState(() {});
              },
              icon: const Icon(Icons.grid_view),
              label: const Text('Generate'),
            ),
            OutlinedButton.icon(
              onPressed: () {
                setState(() => _groupSize = 2);
                _makeGroups();
                setDialogState(() {});
              },
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Pairs'),
            ),
          ]),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: Wrap(spacing: 12, runSpacing: 12, children: [
                for (int i = 0; i < _groups.length; i++)
                  Container(
                    width: 360,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(ctx).colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: Theme.of(ctx).colorScheme.outlineVariant),
                    ),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Group ${i + 1}',
                              style: Theme.of(ctx)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          ..._groups[i].map((n) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(n,
                                    style: Theme.of(ctx).textTheme.titleSmall),
                              )),
                        ]),
                  ),
              ]),
            ),
          ),
          Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                  onPressed: () => Navigator.of(ctx).pop(),
                  icon: const Icon(Icons.close),
                  label: const Text('Close'))),
        ]);

      // Participation: allow increment/reset in present mode
      case 2:
        final part = _participationForClass();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.emoji_people_outlined),
            const SizedBox(width: 8),
            Text('Participation', style: Theme.of(ctx).textTheme.titleLarge)
          ]),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: Wrap(spacing: 12, runSpacing: 12, children: [
                for (final n in _currentNames)
                  Container(
                    width: 360,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Theme.of(ctx).colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: Theme.of(ctx).colorScheme.outlineVariant),
                    ),
                    child: Row(children: [
                      Expanded(
                        child: Text(
                          n,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(ctx).textTheme.titleSmall,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Theme.of(ctx).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${part[n] ?? 0}',
                          style: Theme.of(ctx)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: () {
                          setState(() => part[n] = (part[n] ?? 0) + 1);
                          setDialogState(() {});
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Add'),
                      ),
                      const SizedBox(width: 4),
                      OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            final current = part[n] ?? 0;
                            if (current > 0) {
                              part[n] = current - 1;
                            }
                          });
                          setDialogState(() {});
                        },
                        icon: const Icon(Icons.remove),
                        label: const Text('Remove'),
                      ),
                    ]),
                  ),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  for (final n in _currentNames) {
                    part[n] = 0;
                  }
                });
                setDialogState(() {});
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Reset'),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => Navigator.of(ctx).pop(),
              icon: const Icon(Icons.close),
              label: const Text('Close'),
            ),
          ]),
        ]);

      // Schedule: not presented full-screen (keeps tab mapping consistent)
      case 3:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.event_note_outlined),
            const SizedBox(width: 8),
            Text('Schedule', style: Theme.of(ctx).textTheme.titleLarge)
          ]),
          const SizedBox(height: 16),
          Expanded(
            child: Center(
              child: Text(
                'Schedule is available on the dashboard (Calendar).',
                style: Theme.of(ctx).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => Navigator.of(ctx).pop(),
              icon: const Icon(Icons.close),
              label: const Text('Close'),
            ),
          ),
        ]);

      // Quick Poll: large buttons and bars
      case 4:
        final map = _pollCountsForClass();
        int total = (map['A'] ?? 0) +
            (map['B'] ?? 0) +
            (map['C'] ?? 0) +
            (map['D'] ?? 0);
        Widget bigButton(String label) => FilledButton(
              onPressed: () {
                _vote(label);
                setDialogState(() {});
              },
              child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  child: Text(label,
                      style: Theme.of(ctx)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700))),
            );
        Widget bar(String label) {
          final v = map[label] ?? 0;
          final pct = total == 0 ? 0.0 : v / total;
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$label  ($v)', style: Theme.of(ctx).textTheme.titleSmall),
                const SizedBox(height: 6),
                LayoutBuilder(builder: (c, s) {
                  return Stack(children: [
                    Container(
                        height: 14,
                        width: s.maxWidth,
                        decoration: BoxDecoration(
                            color: Theme.of(ctx).colorScheme.surfaceContainer,
                            borderRadius: BorderRadius.circular(10))),
                    AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 14,
                        width: s.maxWidth * pct,
                        decoration: BoxDecoration(
                            color: Theme.of(ctx).colorScheme.primary,
                            borderRadius: BorderRadius.circular(10))),
                  ]);
                }),
              ]);
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.poll_outlined),
            const SizedBox(width: 8),
            Text('Quick Poll', style: Theme.of(ctx).textTheme.titleLarge)
          ]),
          const SizedBox(height: 16),
          Wrap(spacing: 12, children: [
            bigButton('A'),
            bigButton('B'),
            bigButton('C'),
            bigButton('D'),
            OutlinedButton.icon(
              onPressed: () {
                _resetPoll();
                setDialogState(() {});
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Reset'),
            ),
          ]),
          const SizedBox(height: 16),
          bar('A'),
          const SizedBox(height: 10),
          bar('B'),
          const SizedBox(height: 10),
          bar('C'),
          const SizedBox(height: 10),
          bar('D'),
          const Spacer(),
          Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                  onPressed: () => Navigator.of(ctx).pop(),
                  icon: const Icon(Icons.close),
                  label: const Text('Close'))),
        ]);

      // Timer: large stopwatch/countdown
      case 5:
        String fmt(int s) {
          final m = s ~/ 60;
          final r = s % 60;
          return '${_two(m)}:${_two(r)}';
        }
        return SingleChildScrollView(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Row(children: [
              const Icon(Icons.timer_outlined),
              const SizedBox(width: 8),
              Text('Timer & Stopwatch',
                  style: Theme.of(ctx).textTheme.titleLarge)
            ]),
            const SizedBox(height: 24),
            Text('Stopwatch', style: Theme.of(ctx).textTheme.titleSmall),
            const SizedBox(height: 8),
            StreamBuilder<int>(
              stream: Stream.periodic(const Duration(seconds: 1), (i) => i),
              builder: (context, _) => Text(fmt(_stopwatchSeconds),
                  style: Theme.of(ctx)
                      .textTheme
                      .displaySmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 12),
            Wrap(spacing: 8, alignment: WrapAlignment.center, children: [
              if (!_stopwatchRunning)
                FilledButton.icon(
                    onPressed: () {
                      _startStopwatch();
                      setDialogState(() {});
                    },
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start'))
              else
                FilledButton.icon(
                    onPressed: () {
                      _stopStopwatch();
                      setDialogState(() {});
                    },
                    icon: const Icon(Icons.pause),
                    label: const Text('Pause')),
              OutlinedButton.icon(
                  onPressed: () {
                    _resetStopwatch();
                    setDialogState(() {});
                  },
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Reset')),
            ]),
            const SizedBox(height: 28),
            Text('Countdown', style: Theme.of(ctx).textTheme.titleSmall),
            const SizedBox(height: 8),
            StreamBuilder<int>(
              stream: Stream.periodic(const Duration(seconds: 1), (i) => i),
              builder: (context, _) => Text(fmt(_countdownSeconds),
                  style: Theme.of(ctx)
                      .textTheme
                      .displaySmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 8),
            Wrap(spacing: 8, alignment: WrapAlignment.center, children: [
              FilledButton.icon(
                  onPressed: () {
                    _startCountdown();
                    setDialogState(() {});
                  },
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start')),
              OutlinedButton.icon(
                  onPressed: () {
                    _stopCountdown();
                    setDialogState(() {});
                  },
                  icon: const Icon(Icons.stop),
                  label: const Text('Stop')),
            ]),
            const SizedBox(height: 24),
            TextButton.icon(
                onPressed: () => Navigator.of(ctx).pop(),
                icon: const Icon(Icons.close),
                label: const Text('Close')),
          ]),
        );

      // QR: present large QR if available
      case 6:
        final text = _qrCtrl.text.trim();
        return Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Row(children: [
            const Icon(Icons.qr_code_2_outlined),
            const SizedBox(width: 8),
            Text('QR Code', style: Theme.of(ctx).textTheme.titleLarge)
          ]),
          const SizedBox(height: 16),
          if (text.isEmpty)
            Expanded(
                child: Center(
                    child: Text('Enter text/URL in the QR tool first',
                        style: Theme.of(ctx).textTheme.titleMedium)))
          else
            Expanded(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                      color: Theme.of(ctx).colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: Theme.of(ctx).colorScheme.outlineVariant)),
                  child: QrImageView(
                      data: text,
                      size: 360,
                      backgroundColor: Colors.transparent),
                ),
              ),
            ),
          Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                  onPressed: () => Navigator.of(ctx).pop(),
                  icon: const Icon(Icons.close),
                  label: const Text('Close'))),
        ]);

      case 7:
        return TeacherWhiteboardWorkspace(
          controller: _dashboardWhiteboardController,
          title: 'Presenting whiteboard',
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildNamePicker(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.casino_outlined),
        const SizedBox(width: 8),
        Text('Name Picker', style: context.textStyles.titleSmall?.semiBold)
      ]),
      const SizedBox(height: 8),
      Text('${_currentNames.length} students loaded',
          style: context.textStyles.bodySmall
              ?.withColor(Theme.of(context).colorScheme.onSurfaceVariant)),
      const SizedBox(height: 8),
      FilledButton.icon(
          onPressed: _pickRandomName,
          icon: const Icon(Icons.play_arrow),
          label: const Text('Pick Random')),
      if (_pickedName != null) ...[
        const SizedBox(height: 8),
        Text('Picked: $_pickedName',
            style: context.textStyles.titleMedium?.semiBold),
      ],
    ]);
  }

  Widget _buildGroups(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.groups_outlined),
        const SizedBox(width: 8),
        Text('Group Maker', style: context.textStyles.titleSmall?.semiBold)
      ]),
      const SizedBox(height: 8),
      Row(children: [
        SizedBox(
          width: 140,
          child: TextField(
            decoration:
                const InputDecoration(labelText: 'Group Size', isDense: true),
            keyboardType: TextInputType.number,
            onChanged: (v) => setState(() => _groupSize = int.tryParse(v) ?? 2),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: () {
            setState(() => _groupSize = 2);
            _makeGroups();
          },
          icon: const Icon(Icons.auto_awesome),
          label: const Text('Pairs'),
        ),
      ]),
      const SizedBox(height: 8),
      FilledButton.icon(
          onPressed: _makeGroups,
          icon: const Icon(Icons.grid_view),
          label: const Text('Generate Groups')),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (int i = 0; i < _groups.length; i++)
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(12)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Group ${i + 1}',
                  style: context.textStyles.labelLarge?.semiBold),
              ..._groups[i].map((n) => Text(n)),
            ]),
          ),
      ]),
    ]);
  }

  Widget _buildParticipation(BuildContext context) {
    final part = _participationForClass();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.emoji_people_outlined),
        const SizedBox(width: 8),
        Text('Participation', style: context.textStyles.titleSmall?.semiBold)
      ]),
      const SizedBox(height: 8),
      Wrap(spacing: 4, runSpacing: 8, children: [
        for (final n in _currentNames)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(12)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Flexible(
                child: Text(n, overflow: TextOverflow.ellipsis, maxLines: 1),
              ),
              const SizedBox(width: 4),
              Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(6)),
                  child: Text(
                    '${part[n] ?? 0}',
                    style: context.textStyles.labelSmall,
                  )),
              SizedBox(
                width: 28,
                child: IconButton(
                  icon: const Icon(Icons.add_circle_outline, size: 16),
                  color: Theme.of(context).colorScheme.primary,
                  onPressed: () => setState(() => part[n] = (part[n] ?? 0) + 1),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ),
              SizedBox(
                width: 28,
                child: IconButton(
                  icon: const Icon(Icons.remove_circle_outline, size: 16),
                  color: Theme.of(context).colorScheme.error,
                  onPressed: () => setState(() {
                    final current = part[n] ?? 0;
                    if (current > 0) {
                      part[n] = current - 1;
                    }
                  }),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ),
            ]),
          ),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        FilledButton.icon(
            onPressed: _pickRandomName,
            icon: const Icon(Icons.casino_outlined),
            label: const Text('Cold Call')),
        const SizedBox(width: 8),
        OutlinedButton.icon(
            onPressed: () => setState(() {
                  for (final n in _currentNames) {
                    part[n] = 0;
                  }
                }),
            icon: const Icon(Icons.refresh),
            label: const Text('Reset')),
      ]),
      if (_pickedName != null) ...[
        const SizedBox(height: 8),
        Text('Next up: $_pickedName',
            style: context.textStyles.titleSmall?.semiBold),
      ],
    ]);
  }

  Widget _buildQuickPoll(BuildContext context) {
    final map = _pollCountsForClass();
    int total =
        (map['A'] ?? 0) + (map['B'] ?? 0) + (map['C'] ?? 0) + (map['D'] ?? 0);
    double pct(int v) => total == 0 ? 0 : v / total;
    Widget bar(String label) => LayoutBuilder(builder: (ctx, c) {
          final v = map[label] ?? 0;
          final w = (c.maxWidth * pct(v)).clamp(0, c.maxWidth).toDouble();
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$label  ($v)'),
                const SizedBox(height: 4),
                Stack(children: [
                  Container(
                      height: 10,
                      width: c.maxWidth,
                      decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(8))),
                  AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 10,
                      width: w,
                      decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(8))),
                ]),
              ]);
        });
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.poll_outlined),
        const SizedBox(width: 8),
        Text('Quick Poll', style: context.textStyles.titleSmall?.semiBold)
      ]),
      const SizedBox(height: 12),
      // Question display/input
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Question:', style: context.textStyles.bodySmall?.semiBold),
            const SizedBox(height: 6),
            TextField(
              decoration: InputDecoration(
                hintText: 'Enter poll question...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                isDense: true,
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            Text('Answer Options:',
                style: context.textStyles.bodySmall?.semiBold),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Option A',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Option B',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Option C',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Option D',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Wrap(spacing: 8, children: [
        FilledButton(onPressed: () => _vote('A'), child: const Text('A')),
        FilledButton(onPressed: () => _vote('B'), child: const Text('B')),
        FilledButton(onPressed: () => _vote('C'), child: const Text('C')),
        FilledButton(onPressed: () => _vote('D'), child: const Text('D')),
        OutlinedButton.icon(
            onPressed: _resetPoll,
            icon: const Icon(Icons.refresh),
            label: const Text('Reset')),
      ]),
      const SizedBox(height: 12),
      bar('A'),
      const SizedBox(height: 6),
      bar('B'),
      const SizedBox(height: 6),
      bar('C'),
      const SizedBox(height: 6),
      bar('D'),
    ]);
  }

  Widget _buildTimerTool(BuildContext context) {
    String fmt(int s) {
      final m = s ~/ 60;
      final r = s % 60;
      return '${_two(m)}:${_two(r)}';
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.timer_outlined),
        const SizedBox(width: 8),
        Text('Timer & Stopwatch',
            style: context.textStyles.titleSmall?.semiBold)
      ]),
      const SizedBox(height: 8),
      // Stopwatch
      Row(children: [
        Text('Stopwatch: ', style: context.textStyles.titleSmall),
        const SizedBox(width: 6),
        Text(fmt(_stopwatchSeconds),
            style: context.textStyles.titleMedium?.semiBold),
        const Spacer(),
        if (!_stopwatchRunning)
          FilledButton.icon(
              onPressed: _startStopwatch,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start'))
        else
          FilledButton.icon(
              onPressed: _stopStopwatch,
              icon: const Icon(Icons.pause),
              label: const Text('Pause')),
        const SizedBox(width: 8),
        OutlinedButton.icon(
            onPressed: _resetStopwatch,
            icon: const Icon(Icons.restart_alt),
            label: const Text('Reset')),
      ]),
      const SizedBox(height: 12),
      // Countdown
      Row(children: [
        Text('Countdown: ', style: context.textStyles.titleSmall),
        const SizedBox(width: 8),
        SizedBox(
            width: 60,
            child: TextField(
                controller: _cdMinCtrl,
                decoration:
                    const InputDecoration(labelText: 'min', isDense: true),
                keyboardType: TextInputType.number)),
        const SizedBox(width: 8),
        SizedBox(
            width: 60,
            child: TextField(
                controller: _cdSecCtrl,
                decoration:
                    const InputDecoration(labelText: 'sec', isDense: true),
                keyboardType: TextInputType.number)),
        const SizedBox(width: 12),
        Text(fmt(_countdownSeconds),
            style: context.textStyles.titleMedium?.semiBold),
        const Spacer(),
        FilledButton.icon(
            onPressed: _startCountdown,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start')),
        const SizedBox(width: 8),
        OutlinedButton.icon(
            onPressed: _stopCountdown,
            icon: const Icon(Icons.stop),
            label: const Text('Stop')),
      ]),
    ]);
  }

  Widget _buildWhiteboardTool(
    BuildContext context, {
    required bool compact,
  }) {
    return TeacherWhiteboardWorkspace(
      controller: _dashboardWhiteboardController,
      compact: compact,
      title: 'Classroom whiteboard',
      onOpenFullscreen: () =>
          context.push(AppRoutes.whiteboard, extra: _dashboardWhiteboardController),
    );
  }
}

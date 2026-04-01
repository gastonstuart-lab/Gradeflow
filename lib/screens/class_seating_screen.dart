import 'dart:math' as math;
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:gradeflow/components/animated_glow_border.dart';
import 'package:gradeflow/components/pdf_web_viewer.dart';
import 'package:gradeflow/components/pilot_feedback_dialog.dart';
import 'package:gradeflow/components/seating/seating_designer_view.dart';
import 'package:gradeflow/models/class.dart';
import 'package:gradeflow/models/room_setup.dart';
import 'package:gradeflow/nav.dart';
import 'package:gradeflow/platform/browser_file_actions.dart';
import 'package:gradeflow/services/auth_service.dart';
import 'package:gradeflow/services/class_service.dart';
import 'package:gradeflow/services/export_service.dart';
import 'package:gradeflow/services/seating_service.dart';
import 'package:gradeflow/services/student_service.dart';
import 'package:gradeflow/theme.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

class ClassSeatingScreen extends StatefulWidget {
  final String classId;

  const ClassSeatingScreen({super.key, required this.classId});

  @override
  State<ClassSeatingScreen> createState() => _ClassSeatingScreenState();
}

class _ClassSeatingScreenState extends State<ClassSeatingScreen> {
  final ExportService _exportService = ExportService();
  bool _isBootstrapping = true;
  bool _isBuildingHandout = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_loadData());
    });
  }

  @override
  void didUpdateWidget(covariant ClassSeatingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.classId != widget.classId) {
      setState(() => _isBootstrapping = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_loadData());
      });
    }
  }

  Future<void> _loadData() async {
    final auth = context.read<AuthService>();
    final classService = context.read<ClassService>();
    final studentService = context.read<StudentService>();
    final seatingService = context.read<SeatingService>();

    try {
      final user = auth.currentUser;
      if (user != null && classService.getClassById(widget.classId) == null) {
        await classService.loadClasses(user.userId);
      }

      await studentService.loadStudents(widget.classId);
      await seatingService.loadRoomSetups();
      await seatingService.loadLayouts(
        widget.classId,
        studentCount: studentService.students.length,
      );
    } finally {
      if (mounted) {
        setState(() => _isBootstrapping = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final classService = context.watch<ClassService>();
    final studentService = context.watch<StudentService>();
    final seatingService = context.watch<SeatingService>();
    final classItem = classService.getClassById(widget.classId);
    final availableClasses = classService.classes;

    if (_isBootstrapping) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (classItem == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_outlined),
            tooltip: 'Back to class',
            onPressed: _goBackToClassDetail,
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.home_outlined),
              tooltip: 'Home',
              onPressed: _goHome,
            ),
          ],
        ),
        body: const Center(child: Text('Class not found')),
      );
    }

    final students = studentService.students;
    final activeLayout = seatingService.activeLayout(widget.classId);
    final layouts = seatingService.layoutsForClass(widget.classId);
    final assignedRoomSetup = seatingService.assignedRoomSetup(widget.classId);
    final assignedCount = activeLayout?.seats
            .where(
                (seat) => seat.studentId != null && seat.studentId!.isNotEmpty)
            .length ??
        0;
    final seatCount = activeLayout?.seats.length ?? 0;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_outlined),
          tooltip: 'Back to class',
          onPressed: _goBackToClassDetail,
        ),
        title: Text(
          '${classItem.className} Seating',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.home_outlined),
            tooltip: 'Home',
            onPressed: _goHome,
          ),
          PilotFeedbackIconButton(
            initialArea: 'Seating',
            initialRoute: '/class/${widget.classId}/seating',
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 980;
          final verticalPadding = isCompact ? 24.0 : 32.0;
          final estimatedHeaderHeight = isCompact ? 420.0 : 330.0;
          final designerHeight = math.max(
            isCompact ? 880.0 : 740.0,
            constraints.maxHeight - estimatedHeaderHeight,
          );

          return SingleChildScrollView(
            padding:
                isCompact ? const EdgeInsets.all(12) : AppSpacing.paddingLg,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - verticalPadding,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AnimatedGlowBorder(
                    child: Card(
                      child: Padding(
                        padding: isCompact
                            ? const EdgeInsets.all(16)
                            : AppSpacing.paddingLg,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (isCompact) ...[
                              _SeatingHeaderIntro(classItem: classItem),
                              const SizedBox(height: AppSpacing.md),
                              _SeatingHeaderActions(
                                classes: availableClasses,
                                currentClassId: widget.classId,
                                onSwitchClass: _switchClass,
                                assignedRoomName: assignedRoomSetup?.name,
                                onOpenRoomSetups: activeLayout == null
                                    ? null
                                    : _showRoomSetupsDialog,
                              ),
                            ] else
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: _SeatingHeaderIntro(
                                      classItem: classItem,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.lg),
                                  SizedBox(
                                    width: 320,
                                    child: _SeatingHeaderActions(
                                      classes: availableClasses,
                                      currentClassId: widget.classId,
                                      onSwitchClass: _switchClass,
                                      assignedRoomName: assignedRoomSetup?.name,
                                      onOpenRoomSetups: activeLayout == null
                                          ? null
                                          : _showRoomSetupsDialog,
                                    ),
                                  ),
                                ],
                              ),
                            const SizedBox(height: AppSpacing.lg),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                _InfoCard(
                                    label: 'Students',
                                    value: '${students.length}'),
                                _InfoCard(
                                    label: 'Layouts',
                                    value: '${layouts.length}'),
                                _InfoCard(label: 'Seats', value: '$seatCount'),
                                _InfoCard(
                                    label: 'Placed', value: '$assignedCount'),
                                _InfoCard(
                                  label: 'Active Layout',
                                  value: activeLayout?.name ?? 'None',
                                  wide: true,
                                ),
                                _InfoCard(
                                  label: 'Room',
                                  value:
                                      assignedRoomSetup?.name ?? 'Not linked',
                                  wide: true,
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            Text(
                              'Print the active seating plan together with the current roster for substitute teachers.',
                              style: context.textStyles.bodyMedium?.withColor(
                                Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                FilledButton.icon(
                                  onPressed: _isBuildingHandout
                                      ? null
                                      : () => _withHandoutPdf(_previewPdf),
                                  icon:
                                      const Icon(Icons.picture_as_pdf_outlined),
                                  label: Text(
                                      kIsWeb ? 'Preview Handout' : 'Build PDF'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: _isBuildingHandout
                                      ? null
                                      : () => _withHandoutPdf(_printPdf),
                                  icon: const Icon(Icons.print_outlined),
                                  label: const Text('Print'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: _isBuildingHandout
                                      ? null
                                      : () =>
                                          _withHandoutPdf(_downloadOrSharePdf),
                                  icon: Icon(
                                    kIsWeb
                                        ? Icons.download_outlined
                                        : Icons.share_outlined,
                                  ),
                                  label: Text(
                                      kIsWeb ? 'Download PDF' : 'Share PDF'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SizedBox(
                    height: designerHeight,
                    child: SeatingDesignerView(
                      classId: widget.classId,
                      students: students,
                      autoLoad: false,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _switchClass(String classId) {
    if (classId == widget.classId) return;
    context.go('/class/$classId/seating');
  }

  void _goBackToClassDetail() {
    context.go('${AppRoutes.classDetail}/${widget.classId}');
  }

  void _goHome() {
    context.go(AppRoutes.dashboard);
  }

  Future<void> _showRoomSetupsDialog() async {
    final seatingService = context.read<SeatingService>();
    final activeLayout = seatingService.activeLayout(widget.classId);
    if (activeLayout == null) {
      _showMessage('Build a layout first, then save it as a room setup.');
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: FractionallySizedBox(
            heightFactor: 0.86,
            child: Consumer<SeatingService>(
              builder: (context, seatingService, _) {
                final roomSetups =
                    List<RoomSetup>.from(seatingService.roomSetups)
                      ..sort((a, b) => a.name.toLowerCase().compareTo(
                            b.name.toLowerCase(),
                          ));
                final linkedRoom = seatingService.assignedRoomSetup(
                  widget.classId,
                );

                return Padding(
                  padding: AppSpacing.paddingLg,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Room setups',
                        style: context.textStyles.headlineSmall?.semiBold,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Save this room once, then reuse it across classes. Applying a room setup keeps the physical furniture consistent and gives the class a fresh arrangement to work from.',
                        style: context.textStyles.bodyMedium?.withColor(
                          Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          FilledButton.icon(
                            onPressed: () => _showSaveRoomSetupDialog(),
                            icon: const Icon(Icons.add_home_work_outlined),
                            label: const Text('Save current room'),
                          ),
                          OutlinedButton.icon(
                            onPressed: linkedRoom == null
                                ? null
                                : () => _showSaveRoomSetupDialog(
                                      existingRoomSetup: linkedRoom,
                                    ),
                            icon: const Icon(Icons.sync_outlined),
                            label: const Text('Update linked room'),
                          ),
                          OutlinedButton.icon(
                            onPressed: linkedRoom == null
                                ? null
                                : () => _refreshLinkedRoomForClass(linkedRoom),
                            icon: const Icon(Icons.refresh_outlined),
                            label: const Text('Refresh this class'),
                          ),
                          OutlinedButton.icon(
                            onPressed: linkedRoom == null
                                ? null
                                : _detachLinkedRoomFromClass,
                            icon: const Icon(Icons.link_off_outlined),
                            label: const Text('Detach this class'),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      if (roomSetups.isEmpty)
                        Expanded(
                          child: Center(
                            child: Text(
                              'No room setups yet. Save the current room and it will be ready for your other classes.',
                              textAlign: TextAlign.center,
                              style: context.textStyles.bodyMedium?.withColor(
                                Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        )
                      else
                        Expanded(
                          child: ListView.separated(
                            itemCount: roomSetups.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: AppSpacing.sm),
                            itemBuilder: (context, index) {
                              final roomSetup = roomSetups[index];
                              final isLinked = linkedRoom?.roomSetupId ==
                                  roomSetup.roomSetupId;
                              return Card(
                                child: Padding(
                                  padding: AppSpacing.paddingMd,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              roomSetup.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: context.textStyles
                                                  .titleMedium?.semiBold,
                                            ),
                                          ),
                                          if (isLinked)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 6,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .primaryContainer,
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                              ),
                                              child: Text(
                                                'Linked here',
                                                style: context
                                                    .textStyles.labelSmall
                                                    ?.withColor(
                                                  Theme.of(context)
                                                      .colorScheme
                                                      .onPrimaryContainer,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: AppSpacing.sm),
                                      Text(
                                        '${roomSetup.tables.length} tables • ${roomSetup.seats.length} seats',
                                        style: context.textStyles.bodyMedium
                                            ?.withColor(
                                          Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                      ),
                                      const SizedBox(height: AppSpacing.md),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          FilledButton.tonalIcon(
                                            onPressed: () async {
                                              final result =
                                                  await seatingService
                                                      .applyRoomSetupToClass(
                                                classId: widget.classId,
                                                roomSetupId:
                                                    roomSetup.roomSetupId,
                                              );
                                              if (!mounted || result == null) {
                                                return;
                                              }
                                              Navigator.of(sheetContext).pop();
                                              _showMessage(
                                                result.createdNewLayout
                                                    ? 'Applied "${roomSetup.name}" to a fresh layout for this class.'
                                                    : 'Applied "${roomSetup.name}" to this class.',
                                              );
                                            },
                                            icon: const Icon(
                                              Icons.meeting_room_outlined,
                                            ),
                                            label: const Text(
                                              'Use for this class',
                                            ),
                                          ),
                                          OutlinedButton.icon(
                                            onPressed: () =>
                                                _showSaveRoomSetupDialog(
                                              existingRoomSetup: roomSetup,
                                            ),
                                            icon:
                                                const Icon(Icons.edit_outlined),
                                            label:
                                                const Text('Rename / update'),
                                          ),
                                          OutlinedButton.icon(
                                            onPressed: () => _deleteRoomSetup(
                                              roomSetup,
                                            ),
                                            icon: const Icon(
                                                Icons.delete_outline),
                                            label: const Text('Delete'),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _showSaveRoomSetupDialog({
    RoomSetup? existingRoomSetup,
  }) async {
    final seatingService = context.read<SeatingService>();
    final activeLayout = seatingService.activeLayout(widget.classId);
    if (activeLayout == null) {
      _showMessage('Build a layout first, then save it as a room setup.');
      return;
    }

    final nameController = TextEditingController(
      text: existingRoomSetup?.name ?? activeLayout.name,
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            existingRoomSetup == null ? 'Save room setup' : 'Update room setup',
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Room name',
                    hintText: 'Science Lab, Room 101, English groups',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'This saves the physical room only: tables, chairs, and canvas size. Student placements, notes, reminders, and locks stay class-specific.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                existingRoomSetup == null ? 'Save room' : 'Update room',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final roomSetup = await seatingService.saveRoomSetupFromLayout(
      classId: widget.classId,
      sourceLayoutId: activeLayout.layoutId,
      name: nameController.text,
      roomSetupId: existingRoomSetup?.roomSetupId,
    );
    if (roomSetup == null) {
      _showMessage('Could not save this room setup right now.');
      return;
    }

    _showMessage(
      existingRoomSetup == null
          ? 'Saved "${roomSetup.name}" for reuse in other classes.'
          : 'Updated "${roomSetup.name}".',
    );

    if (existingRoomSetup != null) {
      final refreshedCount =
          await seatingService.refreshLinkedClassesFromRoomSetup(
        roomSetup.roomSetupId,
      );
      if (!mounted) return;
      _showMessage(
        'Updated "${roomSetup.name}" and refreshed $refreshedCount linked class${refreshedCount == 1 ? '' : 'es'}.',
      );
    }
  }

  Future<void> _deleteRoomSetup(RoomSetup roomSetup) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete room setup?'),
          content: Text(
            'Delete "${roomSetup.name}" from your reusable room setups? Existing class layouts will stay as they are.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;
    await context.read<SeatingService>().deleteRoomSetup(roomSetup.roomSetupId);
    _showMessage('Deleted "${roomSetup.name}".');
  }

  Future<void> _refreshLinkedRoomForClass(RoomSetup roomSetup) async {
    final layout = await context
        .read<SeatingService>()
        .refreshClassFromAssignedRoom(widget.classId);
    if (!mounted || layout == null) return;
    Navigator.of(context).pop();
    _showMessage('Refreshed this class from "${roomSetup.name}".');
  }

  Future<void> _detachLinkedRoomFromClass() async {
    final linkedRoom =
        context.read<SeatingService>().assignedRoomSetup(widget.classId);
    if (linkedRoom == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Detach this class from the room?'),
          content: Text(
            'This class will keep its current layouts, but future room updates from "${linkedRoom.name}" will no longer apply here.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Detach'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;
    await context
        .read<SeatingService>()
        .detachRoomSetupFromClass(widget.classId);
    if (!mounted) return;
    Navigator.of(context).pop();
    _showMessage('This class now keeps its own room layout.');
  }

  Future<void> _withHandoutPdf(
    Future<void> Function(Uint8List bytes, String filename) action,
  ) async {
    if (_isBuildingHandout) return;

    final classItem = context.read<ClassService>().getClassById(widget.classId);
    final students = List.of(context.read<StudentService>().students);
    final layout = context.read<SeatingService>().activeLayout(widget.classId);

    if (classItem == null) {
      _showMessage('Class details are still loading.');
      return;
    }

    if (layout == null) {
      _showMessage('No seating layout is available yet.');
      return;
    }

    setState(() => _isBuildingHandout = true);
    if (!mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Building substitute handout...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final bytes = await _exportService.generateSubstitutePacketPdf(
        classItem: classItem,
        students: students,
        layout: layout,
      );
      if (mounted) Navigator.of(context).pop();
      await action(bytes, _handoutFilename(classItem));
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      _showMessage('Could not build handout: $e');
    } finally {
      if (mounted) {
        setState(() => _isBuildingHandout = false);
      }
    }
  }

  Future<void> _previewPdf(Uint8List bytes, String filename) async {
    if (!kIsWeb) {
      _showMessage(
          'Preview is only available on web. Use Print or Share instead.');
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.9,
            child: Padding(
              padding: AppSpacing.paddingLg,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Substitute Handout Preview',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: ctx.textStyles.titleLarge?.semiBold,
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _downloadOrSharePdf(bytes, filename),
                        icon: const Icon(Icons.download_outlined),
                        label: const Text('Download PDF'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: PdfWebViewer(bytes: bytes),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _printPdf(Uint8List bytes, String filename) async {
    await Printing.layoutPdf(
      name: filename,
      onLayout: (_) async => bytes,
    );
  }

  Future<void> _downloadOrSharePdf(Uint8List bytes, String filename) async {
    if (kIsWeb) {
      final started = await downloadBrowserBytes(
        bytes,
        filename,
        'application/pdf',
      );
      _showMessage(
        started
            ? 'PDF download started.'
            : 'Download blocked or failed. Please allow downloads and try again.',
      );
      return;
    }

    await Printing.sharePdf(bytes: bytes, filename: filename);
  }

  String _handoutFilename(Class classItem) {
    final safeName = classItem.className
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return '${safeName.isEmpty ? widget.classId : safeName}_sub_handout.pdf';
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String label;
  final String value;
  final bool wide;

  const _InfoCard({
    required this.label,
    required this.value,
    this.wide = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: wide ? 220 : 140,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: context.textStyles.labelMedium?.withColor(
                Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.textStyles.titleMedium?.semiBold,
            ),
          ],
        ),
      ),
    );
  }
}

class _SeatingHeaderIntro extends StatelessWidget {
  final Class classItem;

  const _SeatingHeaderIntro({
    required this.classItem,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          classItem.subject,
          style: context.textStyles.headlineSmall?.semiBold,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '${classItem.schoolYear} | ${classItem.term}',
          style: context.textStyles.bodyMedium,
        ),
      ],
    );
  }
}

class _SeatingHeaderActions extends StatelessWidget {
  final List<Class> classes;
  final String currentClassId;
  final String? assignedRoomName;
  final ValueChanged<String> onSwitchClass;
  final VoidCallback? onOpenRoomSetups;

  const _SeatingHeaderActions({
    required this.classes,
    required this.currentClassId,
    required this.assignedRoomName,
    required this.onSwitchClass,
    required this.onOpenRoomSetups,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          initialValue: currentClassId,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Class',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          items: [
            for (final classItem in classes)
              DropdownMenuItem(
                value: classItem.classId,
                child: Text(
                  classItem.className,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (value) {
            if (value != null) onSwitchClass(value);
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        if (assignedRoomName != null) ...[
          Text(
            'Using room: $assignedRoomName',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textStyles.bodySmall?.withColor(
              Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        OutlinedButton.icon(
          onPressed: onOpenRoomSetups,
          icon: const Icon(Icons.meeting_room_outlined),
          label: const Text('Room setups'),
        ),
      ],
    );
  }
}

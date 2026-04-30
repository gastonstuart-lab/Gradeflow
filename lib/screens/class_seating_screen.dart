import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:gradeflow/components/animated_page_background.dart';
import 'package:gradeflow/components/pdf_web_viewer.dart';
import 'package:gradeflow/components/pilot_feedback_dialog.dart';
import 'package:gradeflow/components/command_surface.dart';
import 'package:gradeflow/components/seating/seating_designer_view.dart';
import 'package:gradeflow/components/workspace_shell.dart';
import 'package:gradeflow/models/class.dart';
import 'package:gradeflow/models/room_setup.dart';
import 'package:gradeflow/models/seating_layout.dart';
import 'package:gradeflow/os/os_palette.dart';
import 'package:gradeflow/platform/browser_file_actions.dart';
import 'package:gradeflow/services/auth_service.dart';
import 'package:gradeflow/services/class_service.dart';
import 'package:gradeflow/services/export_service.dart';
import 'package:gradeflow/services/seating_service.dart';
import 'package:gradeflow/services/student_service.dart';
import 'package:gradeflow/nav.dart';
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

  void _goToClassWorkspace() {
    context.go('${AppRoutes.osClass}/${widget.classId}');
  }

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

    if (_isBootstrapping) {
      return const WorkspaceScaffold(
        eyebrow: 'Class seating',
        title: 'Seating planner',
        subtitle: 'Loading the room layout, roster, and active seating plan.',
        child: WorkspaceLoadingState(
          title: 'Loading seating workspace',
          subtitle:
              'Preparing the roster, room layouts, and current seating plan.',
        ),
      );
    }

    if (classItem == null) {
      return const WorkspaceScaffold(
        eyebrow: 'Class seating',
        title: 'Seating planner',
        subtitle: 'This class could not be loaded into the seating workspace.',
        child: WorkspaceEmptyState(
          icon: Icons.event_seat_outlined,
          title: 'Class not found',
          subtitle: 'Open another class workspace to continue seating work.',
        ),
      );
    }

    final students = studentService.students;
    final activeLayout = seatingService.activeLayout(widget.classId);
    final linkedRoom = seatingService.assignedRoomSetup(widget.classId);
    final placedSeatCount = activeLayout?.seats
            .where((seat) => (seat.studentId ?? '').trim().isNotEmpty)
            .length ??
        0;
    final seatCount = activeLayout?.seats.length ?? 0;
    final tableCount = activeLayout?.tables.length ?? 0;

    return _SeatingNativeSurface(
      eyebrow: 'Class workspace',
      title: classItem.className,
      toolLabel: 'Classroom Map',
      subtitle:
          '${classItem.subject} - ${classItem.schoolYear} - ${classItem.term}',
      leading: IconButton(
        onPressed: _goToClassWorkspace,
        icon: const Icon(Icons.arrow_back_rounded),
        tooltip: 'Back to class workspace',
      ),
      trailing: [
        PilotFeedbackIconButton(
          initialArea: 'Seating',
          initialRoute: AppRoutes.osClassSeating(widget.classId),
        ),
      ],
      contextStrip: _SeatingContextStrip(
        studentCount: students.length,
        layoutCount: seatingService.layoutsForClass(widget.classId).length,
        tableCount: tableCount,
        seatCount: seatCount,
        placedSeatCount: placedSeatCount,
        roomName: linkedRoom?.name,
      ),
      insightRail: _SeatingInsightRail(
        studentCount: students.length,
        layoutCount: seatingService.layoutsForClass(widget.classId).length,
        tableCount: tableCount,
        seatCount: seatCount,
        placedSeatCount: placedSeatCount,
        roomName: linkedRoom?.name,
        activeLayout: activeLayout,
      ),
      workspace: LayoutBuilder(
        builder: (context, constraints) {
          final crampedHeight = constraints.maxHeight < 540;
          final designer = SeatingDesignerView(
            classId: widget.classId,
            students: students,
            autoLoad: false,
            showStudentPanel: false,
            showUseHint: false,
            onOpenRoomSetups:
                activeLayout == null ? null : _showRoomSetupsDialog,
            onPreviewPdf:
                _isBuildingHandout ? null : () => _withHandoutPdf(_previewPdf),
            onPrint:
                _isBuildingHandout ? null : () => _withHandoutPdf(_printPdf),
            onDownload: _isBuildingHandout
                ? null
                : () => _withHandoutPdf(_downloadOrSharePdf),
            webMode: kIsWeb,
          );

          if (!crampedHeight) return SizedBox.expand(child: designer);

          return SingleChildScrollView(
            child: SizedBox(
              height: 560,
              child: designer,
            ),
          );
        },
      ),
    );
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
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return FractionallySizedBox(
          heightFactor: 0.86,
          child: Consumer<SeatingService>(
            builder: (context, seatingService, _) {
              final roomSetups = List<RoomSetup>.from(seatingService.roomSetups)
                ..sort((a, b) =>
                    a.name.toLowerCase().compareTo(b.name.toLowerCase()));
              final linkedRoom =
                  seatingService.assignedRoomSetup(widget.classId);

              return WorkspaceSheetScaffold(
                title: 'Room setups',
                subtitle:
                    'Save this room once, then reuse it across classes to keep furniture layouts aligned.',
                icon: Icons.meeting_room_outlined,
                bodyCanExpand: true,
                headerAction: IconButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  icon: const Icon(Icons.close),
                  tooltip: 'Close',
                  style: WorkspaceButtonStyles.icon(context),
                ),
                body: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed: () => _showSaveRoomSetupDialog(),
                          icon: const Icon(Icons.add_home_work_outlined),
                          label: const Text('Save current room'),
                          style: WorkspaceButtonStyles.filled(context),
                        ),
                        OutlinedButton.icon(
                          onPressed: linkedRoom == null
                              ? null
                              : () => _showSaveRoomSetupDialog(
                                    existingRoomSetup: linkedRoom,
                                  ),
                          icon: const Icon(Icons.sync_outlined),
                          label: const Text('Update linked room'),
                          style: WorkspaceButtonStyles.outlined(context),
                        ),
                        OutlinedButton.icon(
                          onPressed: linkedRoom == null
                              ? null
                              : () => _refreshLinkedRoomForClass(linkedRoom),
                          icon: const Icon(Icons.refresh_outlined),
                          label: const Text('Refresh this class'),
                          style: WorkspaceButtonStyles.outlined(context),
                        ),
                        OutlinedButton.icon(
                          onPressed: linkedRoom == null
                              ? null
                              : _detachLinkedRoomFromClass,
                          icon: const Icon(Icons.link_off_outlined),
                          label: const Text('Detach this class'),
                          style: WorkspaceButtonStyles.outlined(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: roomSetups.isEmpty
                          ? Center(
                              child: ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 340),
                                child: WorkspaceInlineState(
                                  icon: Icons.meeting_room_outlined,
                                  title: 'No room setups yet',
                                  subtitle:
                                      'Save the current room once and it will be ready for your other classes.',
                                  action: FilledButton.icon(
                                    onPressed: () => _showSaveRoomSetupDialog(),
                                    icon: const Icon(
                                        Icons.add_home_work_outlined),
                                    label: const Text('Save room'),
                                    style:
                                        WorkspaceButtonStyles.filled(context),
                                  ),
                                ),
                              ),
                            )
                          : ListView.separated(
                              itemCount: roomSetups.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: AppSpacing.sm),
                              itemBuilder: (context, index) {
                                final roomSetup = roomSetups[index];
                                final isLinked = linkedRoom?.roomSetupId ==
                                    roomSetup.roomSetupId;
                                return Semantics(
                                  container: true,
                                  label: isLinked
                                      ? '${roomSetup.name}, Linked here'
                                      : roomSetup.name,
                                  child: _SeatingFlatSurface(
                                    padding: const EdgeInsets.all(14),
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
                                                style: context
                                                    .textStyles.titleSmall
                                                    ?.copyWith(
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                            if (isLinked)
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 5,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .primaryContainer,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          WorkspaceRadius.pill),
                                                ),
                                                child: Text(
                                                  'Linked here',
                                                  style: WorkspaceTypography
                                                          .utility(context)
                                                      ?.withColor(
                                                    Theme.of(context)
                                                        .colorScheme
                                                        .onPrimaryContainer,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          '${roomSetup.tables.length} tables - ${roomSetup.seats.length} seats',
                                          style: context.textStyles.bodySmall
                                              ?.withColor(
                                            Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
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
                                                if (!mounted ||
                                                    result == null) {
                                                  return;
                                                }
                                                Navigator.of(sheetContext)
                                                    .pop();
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
                                              style:
                                                  WorkspaceButtonStyles.tonal(
                                                context,
                                                compact: true,
                                              ),
                                            ),
                                            OutlinedButton.icon(
                                              onPressed: () =>
                                                  _showSaveRoomSetupDialog(
                                                existingRoomSetup: roomSetup,
                                              ),
                                              icon: const Icon(
                                                Icons.edit_outlined,
                                              ),
                                              label:
                                                  const Text('Rename / update'),
                                              style: WorkspaceButtonStyles
                                                  .outlined(
                                                context,
                                                compact: true,
                                              ),
                                            ),
                                            OutlinedButton.icon(
                                              onPressed: () =>
                                                  _deleteRoomSetup(roomSetup),
                                              icon: const Icon(
                                                  Icons.delete_outline),
                                              label: const Text('Delete'),
                                              style: WorkspaceButtonStyles
                                                  .outlined(
                                                context,
                                                compact: true,
                                              ),
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
        return WorkspaceDialogScaffold(
          title: existingRoomSetup == null
              ? 'Save room setup'
              : 'Update room setup',
          subtitle:
              'This saves the physical room only. Student placements remain class-specific.',
          icon: Icons.meeting_room_outlined,
          body: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Room name',
                    hintText: 'Science Lab, Room 101, English groups',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Tables, chairs, and canvas size are saved here. Student placements, notes, reminders, and locks stay with the class.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              style: WorkspaceButtonStyles.text(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: WorkspaceButtonStyles.filled(dialogContext),
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
        return WorkspaceDialogScaffold(
          title: 'Delete room setup?',
          subtitle: 'Remove this reusable room from the shared setup list.',
          icon: Icons.delete_outline,
          body: Text(
            'Delete "${roomSetup.name}" from your reusable room setups? Existing class layouts will stay as they are.',
            style: Theme.of(dialogContext).textTheme.bodySmall?.copyWith(
                  color: Theme.of(dialogContext).colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              style: WorkspaceButtonStyles.text(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: WorkspaceButtonStyles.filled(dialogContext),
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
        return WorkspaceDialogScaffold(
          title: 'Detach this class from the room?',
          subtitle:
              'Keep the current layouts, but stop future room-sync updates.',
          icon: Icons.link_off_outlined,
          body: Text(
            'This class will keep its current layouts, but future room updates from "${linkedRoom.name}" will no longer apply here.',
            style: Theme.of(dialogContext).textTheme.bodySmall?.copyWith(
                  color: Theme.of(dialogContext).colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              style: WorkspaceButtonStyles.text(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: WorkspaceButtonStyles.filled(dialogContext),
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
      builder: (ctx) => const WorkspaceProgressDialog(
        title: 'Building substitute handout',
        subtitle: 'Preparing the PDF for preview, print, or download.',
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
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.9,
          child: WorkspaceSheetScaffold(
            title: 'Substitute handout preview',
            subtitle:
                'Review the PDF before printing, downloading, or sharing it.',
            icon: Icons.picture_as_pdf_outlined,
            bodyCanExpand: true,
            maxWidth: 1180,
            headerAction: OverflowBar(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _downloadOrSharePdf(bytes, filename),
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Download PDF'),
                  style: WorkspaceButtonStyles.outlined(ctx),
                ),
                IconButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  icon: const Icon(Icons.close),
                  tooltip: 'Close',
                  style: WorkspaceButtonStyles.icon(ctx),
                ),
              ],
            ),
            body: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: PdfWebViewer(bytes: bytes),
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
    showWorkspaceSnackBar(
      context,
      message: message,
      tone: WorkspaceFeedbackTone.info,
    );
  }
}

class _SeatingNativeSurface extends StatelessWidget {
  const _SeatingNativeSurface({
    required this.eyebrow,
    required this.title,
    required this.toolLabel,
    required this.workspace,
    this.subtitle,
    this.leading,
    this.trailing = const [],
    this.contextStrip,
    this.insightRail,
  });

  final String eyebrow;
  final String title;
  final String toolLabel;
  final String? subtitle;
  final Widget? leading;
  final List<Widget> trailing;
  final Widget? contextStrip;
  final Widget? insightRail;
  final Widget workspace;

  @override
  Widget build(BuildContext context) {
    final bottomClearance =
        MediaQuery.paddingOf(context).bottom + OSSpacing.dockBottomMargin;
    final shellMargin = EdgeInsets.fromLTRB(
      WorkspaceSpacing.shellMargin.left,
      WorkspaceSpacing.shellMargin.top,
      WorkspaceSpacing.shellMargin.right,
      WorkspaceSpacing.shellMargin.bottom + bottomClearance,
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedPageBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final shellHeight = (constraints.maxHeight - shellMargin.vertical)
                  .clamp(0.0, double.infinity);

              return Padding(
                padding: shellMargin,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1480),
                    child: SizedBox(
                      width: double.infinity,
                      height: shellHeight,
                      child: WorkspaceShellFrame(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                        radius: WorkspaceRadius.shell,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _SeatingNativeHeader(
                              eyebrow: eyebrow,
                              title: title,
                              toolLabel: toolLabel,
                              subtitle: subtitle,
                              leading: leading,
                              trailing: trailing,
                              contextStrip: contextStrip,
                            ),
                            const SizedBox(height: WorkspaceSpacing.sm),
                            Expanded(
                              child: _SeatingWorkspaceLayout(
                                workspace: workspace,
                                insightRail: insightRail,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SeatingWorkspaceLayout extends StatelessWidget {
  const _SeatingWorkspaceLayout({
    required this.workspace,
    this.insightRail,
  });

  final Widget workspace;
  final Widget? insightRail;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final showRail = insightRail != null && constraints.maxWidth >= 1120;
        final mapSurface = GradeFlowPanel(
          variant: GradeFlowPanelVariant.stage,
          padding: const EdgeInsets.all(12),
          radius: WorkspaceRadius.card,
          expandChild: true,
          child: workspace,
        );

        if (showRail) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: mapSurface),
              const SizedBox(width: WorkspaceSpacing.sm),
              SizedBox(
                width: 260,
                child: SingleChildScrollView(
                  child: insightRail!,
                ),
              ),
            ],
          );
        }

        return SingleChildScrollView(
          child: Column(
            children: [
              SizedBox(
                height: constraints.maxHeight,
                child: mapSurface,
              ),
              if (insightRail != null) ...[
                const SizedBox(height: WorkspaceSpacing.sm),
                insightRail!,
              ],
            ],
          ),
        );
      },
    );
  }
}

class _SeatingNativeHeader extends StatelessWidget {
  const _SeatingNativeHeader({
    required this.eyebrow,
    required this.title,
    required this.toolLabel,
    this.subtitle,
    this.leading,
    this.trailing = const [],
    this.contextStrip,
  });

  final String eyebrow;
  final String title;
  final String toolLabel;
  final String? subtitle;
  final Widget? leading;
  final List<Widget> trailing;
  final Widget? contextStrip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final toolBadge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: theme.colorScheme.primary.withValues(alpha: 0.11),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.20),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.event_seat_rounded,
            size: 16,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Text(
            toolLabel,
            style: context.textStyles.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );

    final iconTile = Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: theme.colorScheme.primary.withValues(alpha: 0.12),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.20),
        ),
      ),
      child: Icon(
        Icons.chair_alt_outlined,
        color: theme.colorScheme.primary,
        size: 23,
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 900;
        final copy = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  eyebrow.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: WorkspaceTypography.eyebrow(context),
                ),
                toolBadge,
              ],
            ),
            const SizedBox(height: 7),
            Text(
              'Classroom Map',
              maxLines: narrow ? 2 : 1,
              overflow: TextOverflow.ellipsis,
              style: context.textStyles.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
            if ((subtitle ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                '$title - $subtitle',
                maxLines: narrow ? 2 : 1,
                overflow: TextOverflow.ellipsis,
                style: context.textStyles.bodyMedium?.copyWith(
                  color: WorkspaceChrome.mutedText(context),
                  height: 1.35,
                ),
              ),
            ],
          ],
        );

        final leadingCluster = Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: WorkspaceSpacing.sm),
            ],
            iconTile,
          ],
        );
        final trailingActions = Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: trailing,
        );

        if (narrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  leadingCluster,
                  const Spacer(),
                  if (trailing.isNotEmpty) trailingActions,
                ],
              ),
              const SizedBox(height: WorkspaceSpacing.sm),
              copy,
              if (contextStrip != null) ...[
                const SizedBox(height: WorkspaceSpacing.xs),
                contextStrip!,
              ],
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            leadingCluster,
            const SizedBox(width: WorkspaceSpacing.md),
            Expanded(child: copy),
            if (contextStrip != null) ...[
              const SizedBox(width: WorkspaceSpacing.md),
              Flexible(child: contextStrip!),
            ],
            if (trailing.isNotEmpty) ...[
              const SizedBox(width: WorkspaceSpacing.sm),
              trailingActions,
            ],
          ],
        );
      },
    );
  }
}

class _SeatingInsightRail extends StatelessWidget {
  const _SeatingInsightRail({
    required this.studentCount,
    required this.layoutCount,
    required this.tableCount,
    required this.seatCount,
    required this.placedSeatCount,
    required this.activeLayout,
    this.roomName,
  });

  final int studentCount;
  final int layoutCount;
  final int tableCount;
  final int seatCount;
  final int placedSeatCount;
  final SeatingLayout? activeLayout;
  final String? roomName;

  @override
  Widget build(BuildContext context) {
    final seats = activeLayout?.seats ?? const <SeatingSeat>[];
    final emptySeatCount = (seatCount - placedSeatCount).clamp(0, seatCount);
    final reminderCount = seats.where((seat) => seat.reminder).length;
    final lockedCount = seats.where((seat) => seat.locked).length;
    final greenCount =
        seats.where((seat) => seat.statusColor == SeatStatusColor.green).length;
    final yellowCount = seats
        .where((seat) => seat.statusColor == SeatStatusColor.yellow)
        .length;
    final redCount =
        seats.where((seat) => seat.statusColor == SeatStatusColor.red).length;
    final blueCount =
        seats.where((seat) => seat.statusColor == SeatStatusColor.blue).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GradeFlowPanel(
          variant: GradeFlowPanelVariant.tool,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const GradeFlowSectionHeader(
                title: 'Class map',
                subtitle: 'Live seating coverage',
              ),
              const SizedBox(height: WorkspaceSpacing.sm),
              GridView.count(
                crossAxisCount: 2,
                childAspectRatio: 1.3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                children: [
                  _RailMetric(label: 'Students', value: '$studentCount'),
                  _RailMetric(label: 'Placed', value: '$placedSeatCount'),
                  _RailMetric(label: 'Empty', value: '$emptySeatCount'),
                  _RailMetric(label: 'Seats', value: '$seatCount'),
                ],
              ),
              const SizedBox(height: WorkspaceSpacing.sm),
              _RailLine(
                icon: Icons.table_bar_outlined,
                label: 'Tables',
                value: '$tableCount',
              ),
              _RailLine(
                icon: Icons.layers_outlined,
                label: 'Layouts',
                value: '$layoutCount',
              ),
              _RailLine(
                icon: Icons.meeting_room_outlined,
                label: 'Room setup',
                value:
                    (roomName ?? '').trim().isEmpty ? 'Not linked' : roomName!,
              ),
            ],
          ),
        ),
        const SizedBox(height: WorkspaceSpacing.sm),
        GradeFlowPanel(
          variant: GradeFlowPanelVariant.tool,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const GradeFlowSectionHeader(
                title: 'Seat signals',
                subtitle: 'Existing seat status only',
              ),
              const SizedBox(height: WorkspaceSpacing.sm),
              _StatusLegendRow(
                color: Colors.green.shade600,
                label: 'Green',
                value: '$greenCount',
              ),
              _StatusLegendRow(
                color: Colors.amber.shade700,
                label: 'Yellow',
                value: '$yellowCount',
              ),
              _StatusLegendRow(
                color: Colors.red.shade600,
                label: 'Red',
                value: '$redCount',
              ),
              _StatusLegendRow(
                color: Colors.blue.shade600,
                label: 'Blue',
                value: '$blueCount',
              ),
              const SizedBox(height: WorkspaceSpacing.xs),
              _RailLine(
                icon: Icons.notifications_active_outlined,
                label: 'Reminders',
                value: '$reminderCount',
              ),
              _RailLine(
                icon: Icons.lock_outline,
                label: 'Locked seats',
                value: '$lockedCount',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RailMetric extends StatelessWidget {
  const _RailMetric({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return WorkspaceFlatSurface(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textStyles.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: WorkspaceTypography.metadata(context),
          ),
        ],
      ),
    );
  }
}

class _RailLine extends StatelessWidget {
  const _RailLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final color = WorkspaceChrome.mutedText(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: WorkspaceTypography.metadata(context),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: context.textStyles.labelMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusLegendRow extends StatelessWidget {
  const _StatusLegendRow({
    required this.color,
    required this.label,
    required this.value,
  });

  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: WorkspaceTypography.metadata(context),
            ),
          ),
          Text(
            value,
            style: context.textStyles.labelMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SeatingContextStrip extends StatelessWidget {
  const _SeatingContextStrip({
    required this.studentCount,
    required this.layoutCount,
    required this.tableCount,
    required this.seatCount,
    required this.placedSeatCount,
    this.roomName,
  });

  final int studentCount;
  final int layoutCount;
  final int tableCount;
  final int seatCount;
  final int placedSeatCount;
  final String? roomName;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          WorkspaceContextPill(
            icon: Icons.people_alt_outlined,
            label: 'Students',
            value: '$studentCount',
          ),
          const SizedBox(width: 8),
          WorkspaceContextPill(
            icon: Icons.layers_outlined,
            label: 'Layouts',
            value: '$layoutCount',
          ),
          const SizedBox(width: 8),
          WorkspaceContextPill(
            icon: Icons.table_bar_outlined,
            label: 'Room',
            value: '$tableCount / $seatCount',
          ),
          const SizedBox(width: 8),
          WorkspaceContextPill(
            icon: Icons.event_available_outlined,
            label: 'Placed',
            value: '$placedSeatCount',
            emphasized: true,
          ),
          if ((roomName ?? '').trim().isNotEmpty) ...[
            const SizedBox(width: 8),
            WorkspaceContextPill(
              icon: Icons.meeting_room_outlined,
              label: 'Setup',
              value: roomName!,
              accent: Theme.of(context).colorScheme.primary,
              emphasized: true,
            ),
          ],
        ],
      ),
    );
  }
}

class _SeatingFlatSurface extends StatelessWidget {
  const _SeatingFlatSurface({
    required this.child,
    this.padding = const EdgeInsets.all(12),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return WorkspaceFlatSurface(
      padding: padding,
      child: child,
    );
  }
}

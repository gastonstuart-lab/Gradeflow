import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gradeflow/components/seating/seating_canvas.dart';
import 'package:gradeflow/components/seating/seating_toolbar.dart';
import 'package:gradeflow/components/seating/student_assignment_sheet.dart';
import 'package:gradeflow/components/seating/student_picker_sheet.dart';
import 'package:gradeflow/components/seating/student_list_panel.dart';
import 'package:gradeflow/models/seating_layout.dart';
import 'package:gradeflow/models/student.dart';
import 'package:gradeflow/services/seating_service.dart';

class SeatingDesignerView extends StatefulWidget {
  final String classId;
  final List<Student> students;
  final bool autoLoad;
  final bool presentationMode;
  final bool showToolbar;
  final bool showStudentPanel;
  final bool showFullScreenButton;
  final bool showUseHint;
  final VoidCallback? onOpenRoomSetups;
  final VoidCallback? onPreviewPdf;
  final VoidCallback? onPrint;
  final VoidCallback? onDownload;
  final bool webMode;

  const SeatingDesignerView({
    super.key,
    required this.classId,
    required this.students,
    this.autoLoad = true,
    this.presentationMode = false,
    this.showToolbar = true,
    this.showStudentPanel = true,
    this.showFullScreenButton = true,
    this.showUseHint = true,
    this.onOpenRoomSetups,
    this.onPreviewPdf,
    this.onPrint,
    this.onDownload,
    this.webMode = true,
  });

  @override
  State<SeatingDesignerView> createState() => _SeatingDesignerViewState();
}

class _SeatingDesignerViewState extends State<SeatingDesignerView> {
  bool _designMode = false;
  String? _loadedClassId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _ensureLoaded();
    });
  }

  @override
  void didUpdateWidget(covariant SeatingDesignerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.classId != widget.classId ||
        oldWidget.autoLoad != widget.autoLoad) {
      _loadedClassId = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _ensureLoaded();
      });
    }
  }

  void _ensureLoaded() {
    if (!widget.autoLoad) return;
    final service = context.read<SeatingService>();
    if (_loadedClassId == widget.classId) return;
    if (service.layoutsForClass(widget.classId).isNotEmpty) {
      _loadedClassId = widget.classId;
      return;
    }
    _loadedClassId = widget.classId;
    service.loadLayouts(widget.classId, studentCount: widget.students.length);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SeatingService>(
      builder: (context, service, _) {
        final layouts = service.layoutsForClass(widget.classId);
        final active = service.activeLayout(widget.classId);
        final studentsById = {for (final s in widget.students) s.studentId: s};

        if (service.isLoading && active == null) {
          return const Center(child: CircularProgressIndicator());
        }

        if (active == null) {
          return Center(
            child: Text(
              'No seating layout yet.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          );
        }

        final assignedStudentIds = active.seats
            .where((s) => s.studentId != null)
            .map((s) => s.studentId!)
            .toSet();

        return LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 900;
            final crampedHeight = constraints.maxHeight < 460;
            final showStudentPanel = widget.showStudentPanel && !crampedHeight;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.showToolbar)
                  _SeatingDesignerToolBand(
                    child: SeatingToolbar(
                      layouts: layouts,
                      activeLayoutId: active.layoutId,
                      designMode: _designMode,
                      onToggleDesignMode: () =>
                          setState(() => _designMode = !_designMode),
                      onSelectLayout: (id) =>
                          service.selectLayout(widget.classId, id),
                      onAddLayout: () => _promptNewLayout(context, service),
                      onDuplicateLayout: () =>
                          _duplicateLayout(service, active),
                      onApplyTemplate: (template) => service.applyTemplate(
                          widget.classId, template, widget.students.length),
                      onAddRectTable: () => service.addTable(
                          widget.classId, SeatingTableType.rectangular,
                          seatCount: 4),
                      onAddSquareTable: () => service.addTable(
                          widget.classId, SeatingTableType.square,
                          seatCount: 4),
                      onAddDesk: () => service.addTable(
                          widget.classId, SeatingTableType.singleDesk,
                          seatCount: 1),
                      onAddTeacherDesk: () => service.addTable(
                          widget.classId, SeatingTableType.teacherDesk,
                          seatCount: 0),
                      onRenameLayout: () =>
                          _promptRenameLayout(context, service, active),
                      onClearRoom: () =>
                          _confirmClearRoom(context, service, active),
                      onDeleteLayout: () => _confirmDeleteLayout(
                          context, service, layouts, active),
                      onRoomSettings: () =>
                          _promptRoomSettings(context, service, active),
                      onAutoAssign: () =>
                          _autoAssignStudents(context, service, active),
                      onShuffleSeating: () =>
                          _shuffleSeating(context, service, active),
                      onClearAssignments: () =>
                          _confirmClearAssignments(context, service, active),
                      onPickStudent: () => _showStudentPicker(
                          context, service, active, studentsById),
                      onOpenRoomSetups: widget.onOpenRoomSetups,
                      onPreviewPdf: widget.onPreviewPdf,
                      onPrint: widget.onPrint,
                      onDownload: widget.onDownload,
                      webMode: widget.webMode,
                      showFullScreenButton: widget.showFullScreenButton,
                      onFullScreen: () =>
                          Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => _FullScreenSeatingRoute(
                          classId: widget.classId,
                          students: widget.students,
                        ),
                      )),
                    ),
                  ),
                if (widget.showUseHint && _designMode) ...[
                  const SizedBox(height: 6),
                  _EditRoomHint(
                    hasSeats: active.seats.isNotEmpty,
                  ),
                ] else if (widget.showUseHint &&
                    active.seats.isNotEmpty &&
                    widget.students.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  const _SeatingUseHint(),
                ],
                SizedBox(
                  height: widget.showToolbar || widget.showUseHint ? 8 : 0,
                ),
                Expanded(
                  child: !showStudentPanel
                      ? _buildCanvas(context, service, active, studentsById)
                      : isNarrow
                          ? Column(
                              children: [
                                Expanded(
                                  child: _buildCanvas(
                                      context, service, active, studentsById),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  height: 220,
                                  child: StudentListPanel(
                                    students: widget.students,
                                    assignedStudentIds: assignedStudentIds,
                                    compact: true,
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              children: [
                                Expanded(
                                  child: _buildCanvas(
                                      context, service, active, studentsById),
                                ),
                                const SizedBox(width: 12),
                                StudentListPanel(
                                  students: widget.students,
                                  assignedStudentIds: assignedStudentIds,
                                  compact: false,
                                ),
                              ],
                            ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildCanvas(
    BuildContext context,
    SeatingService service,
    SeatingLayout active,
    Map<String, Student> studentsById,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(
          alpha: isDark ? 0.26 : 0.56,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(
            alpha: isDark ? 0.26 : 0.18,
          ),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SeatingCanvas(
          layout: active,
          studentsById: studentsById,
          designMode: _designMode,
          interactive: true,
          presentationMode: widget.presentationMode,
          onMoveTable: (tableId, delta) =>
              service.moveTable(widget.classId, tableId, delta.dx, delta.dy),
          onRemoveTable: (tableId) =>
              service.removeTable(widget.classId, tableId),
          onUpdateTable: (tableId, type, seatCount) => service.updateTable(
              widget.classId, tableId,
              type: type, seatCount: seatCount),
          onRotateTable: (tableId) =>
              service.rotateTable(widget.classId, tableId),
          onResizeTable: (tableId, delta) =>
              service.resizeTable(widget.classId, tableId, delta.dx, delta.dy),
          onMoveSeat: (seatId, delta) =>
              service.moveSeat(widget.classId, seatId, delta.dx, delta.dy),
          onEditTable: (tableId) => _promptEditTable(
            context,
            service,
            active,
            tableId,
          ),
          onDuplicateTable: (tableId) =>
              service.duplicateTable(widget.classId, tableId),
          onTableDrop: (tableId, data) {
            service
                .assignStudentToTable(
              widget.classId,
              tableId,
              data.studentId,
              fromSeatId: data.fromSeatId,
            )
                .then((assigned) {
              if (assigned || !context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'That table is full. Drop onto a specific seat to swap students.',
                  ),
                ),
              );
            });
          },
          onSeatDrop: (seatId, data) => service.assignStudentToSeat(
            widget.classId,
            seatId,
            data.studentId,
            fromSeatId: data.fromSeatId,
          ),
          onSeatTap: (seatId) => _showSeatActions(
            context,
            service,
            active,
            seatId,
            studentsById,
          ),
        ),
      ),
    );
  }

  Future<void> _promptNewLayout(
      BuildContext context, SeatingService service) async {
    final controller = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New layout'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Layout name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (created != true) return;
    final name = controller.text.trim().isEmpty
        ? 'Layout ${DateTime.now().month}/${DateTime.now().day}'
        : controller.text.trim();
    await service.createLayout(widget.classId, name);
  }

  Future<void> _duplicateLayout(
      SeatingService service, SeatingLayout active) async {
    final name = '${active.name} copy';
    await service.createLayout(widget.classId, name, from: active);
  }

  Future<void> _promptRenameLayout(
    BuildContext context,
    SeatingService service,
    SeatingLayout active,
  ) async {
    final controller = TextEditingController(text: active.name);
    final renamed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename layout'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Layout name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (renamed != true) return;

    final name = controller.text.trim();
    if (name.isEmpty) return;
    await service.renameLayout(widget.classId, active.layoutId, name);
  }

  Future<void> _confirmDeleteLayout(
    BuildContext context,
    SeatingService service,
    List<SeatingLayout> layouts,
    SeatingLayout active,
  ) async {
    if (layouts.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Keep at least one seating layout.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete layout'),
        content: Text(
          'Delete "${active.name}"? The student placements in this layout will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await service.deleteLayout(widget.classId, active.layoutId);
  }

  Future<void> _confirmClearRoom(
    BuildContext context,
    SeatingService service,
    SeatingLayout active,
  ) async {
    if (active.tables.isEmpty && active.seats.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This layout is already blank.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear room'),
        content: const Text(
          'Remove all tables and seats from this layout and start from a blank canvas?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear room'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await service.clearRoom(widget.classId);
  }

  Future<void> _promptRoomSettings(
    BuildContext context,
    SeatingService service,
    SeatingLayout active,
  ) async {
    final widthController =
        TextEditingController(text: active.canvasWidth.round().toString());
    final heightController =
        TextEditingController(text: active.canvasHeight.round().toString());

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Room size'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: widthController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Canvas width',
                helperText: 'Recommended 600 to 2400',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: heightController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Canvas height',
                helperText: 'Recommended 400 to 1800',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (saved != true) return;

    final width = double.tryParse(widthController.text.trim());
    final height = double.tryParse(heightController.text.trim());
    if (width == null || height == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter valid room dimensions.')),
      );
      return;
    }

    await service.updateCanvasSize(
      widget.classId,
      width: width,
      height: height,
    );
  }

  Future<void> _promptEditTable(
    BuildContext context,
    SeatingService service,
    SeatingLayout active,
    String tableId,
  ) async {
    final table = active.tables.firstWhere((entry) => entry.tableId == tableId);
    final labelController = TextEditingController(text: table.label);
    final widthController =
        TextEditingController(text: table.width.round().toString());
    final heightController =
        TextEditingController(text: table.height.round().toString());
    final seatController =
        TextEditingController(text: table.seatCount.toString());
    SeatingTableType selectedType = table.type;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('Edit table'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<SeatingTableType>(
                  initialValue: selectedType,
                  decoration: const InputDecoration(labelText: 'Table type'),
                  items: _editableTableTypes
                      .map(
                        (type) => DropdownMenuItem(
                          value: type,
                          child: Text(_tableTypeLabel(type)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setLocalState(() {
                      selectedType = value;
                      labelController.text = service.rebuiltLabel(value);
                      widthController.text =
                          service.buildDefaultWidth(value).round().toString();
                      heightController.text =
                          service.buildDefaultHeight(value).round().toString();
                      seatController.text = switch (value) {
                        SeatingTableType.teacherDesk => '0',
                        SeatingTableType.singleDesk => '1',
                        SeatingTableType.rectangular => '4',
                        SeatingTableType.square => '4',
                        SeatingTableType.round => '4',
                        SeatingTableType.pairedRect => '6',
                        SeatingTableType.longDouble => '8',
                      };
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: labelController,
                  decoration: const InputDecoration(labelText: 'Label'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: seatController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Seat count'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: widthController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Width'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: heightController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Height'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (saved != true) return;

    final seatCount = int.tryParse(seatController.text.trim());
    final width = double.tryParse(widthController.text.trim());
    final height = double.tryParse(heightController.text.trim());
    if (seatCount == null || width == null || height == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter valid table details.')),
      );
      return;
    }

    final normalizedSeatCount = selectedType == SeatingTableType.teacherDesk
        ? 0
        : seatCount.clamp(1, 12);

    await service.updateTable(
      widget.classId,
      tableId,
      type: selectedType,
      seatCount: normalizedSeatCount,
      label: labelController.text.trim(),
      width: width.clamp(40, 600).toDouble(),
      height: height.clamp(40, 400).toDouble(),
    );
  }

  Future<void> _autoAssignStudents(
    BuildContext context,
    SeatingService service,
    SeatingLayout active,
  ) async {
    if (active.seats.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Add seats to the layout before auto-filling.')),
      );
      return;
    }

    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Auto-fill seating plan'),
        content: const Text(
          'Fill seats from the class roster using seat number order when available? Existing placements in this layout will be replaced.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Auto-fill'),
          ),
        ],
      ),
    );
    if (proceed != true) return;

    await service.autoAssignStudents(widget.classId, widget.students);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Seating plan filled from roster order.')),
    );
  }

  Future<void> _confirmClearAssignments(
    BuildContext context,
    SeatingService service,
    SeatingLayout active,
  ) async {
    final hasAssignedSeats = active.seats
        .any((seat) => seat.studentId != null && seat.studentId!.isNotEmpty);
    if (!hasAssignedSeats) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('This layout has no student placements to clear.')),
      );
      return;
    }

    final cleared = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear student placements'),
        content: const Text(
          'Remove all students from the current layout but keep the room design?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (cleared != true) return;

    await service.clearAssignments(widget.classId);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Student placements cleared.')),
    );
  }

  Future<void> _shuffleSeating(
    BuildContext context,
    SeatingService service,
    SeatingLayout active,
  ) async {
    final assignedUnlockedStudents = active.seats
        .where((seat) =>
            !seat.locked &&
            seat.studentId != null &&
            seat.studentId!.isNotEmpty)
        .length;
    final lockedSeats = active.seats.where((seat) => seat.locked).length;

    if (active.seats.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Add at least two seats before shuffling the seating plan.'),
        ),
      );
      return;
    }

    if (widget.students.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Add at least two students before shuffling the seating plan.'),
        ),
      );
      return;
    }

    if (active.seats.any(
          (seat) => seat.studentId != null && seat.studentId!.isNotEmpty,
        ) &&
        assignedUnlockedStudents < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unlock at least two placed students before shuffling again.',
          ),
        ),
      );
      return;
    }

    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Shuffle seating'),
        content: Text(
          lockedSeats > 0
              ? 'Randomize student placements across the current seating plan? Locked seats will stay exactly where they are.'
              : 'Randomize student placements across the current seating plan? This replaces the current arrangement.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Shuffle'),
          ),
        ],
      ),
    );
    if (proceed != true) return;

    await service.shuffleStudentPlacements(widget.classId, widget.students);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Seating plan shuffled.')),
    );
  }

  String _tableTypeLabel(SeatingTableType type) {
    switch (type) {
      case SeatingTableType.rectangular:
        return 'Rectangular';
      case SeatingTableType.square:
        return 'Square';
      case SeatingTableType.round:
        return 'Round';
      case SeatingTableType.singleDesk:
        return 'Single desk';
      case SeatingTableType.teacherDesk:
        return 'Teacher desk';
      case SeatingTableType.pairedRect:
        return 'Paired tables';
      case SeatingTableType.longDouble:
        return 'Long double';
    }
  }

  Future<void> _showSeatActions(
    BuildContext context,
    SeatingService service,
    SeatingLayout layout,
    String seatId,
    Map<String, Student> studentsById,
  ) async {
    final seat = layout.seats.firstWhere((s) => s.seatId == seatId);
    final table =
        layout.tables.firstWhere((entry) => entry.tableId == seat.tableId);
    final student =
        seat.studentId == null ? null : studentsById[seat.studentId];
    final canEditSeatStructure = _canEditSeatStructure(table.type);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        final hasAnnotation = seat.note.trim().isNotEmpty || seat.reminder;
        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student == null
                      ? 'Empty seat'
                      : '${student.chineseName} (${student.englishFullName})',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (hasAnnotation) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (seat.reminder)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.notifications_active_outlined,
                                size: 16,
                                color: Colors.deepOrange.shade600,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Reminder on',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        if (seat.note.trim().isNotEmpty) ...[
                          if (seat.reminder) const SizedBox(height: 8),
                          Text(
                            seat.note.trim(),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _StatusChip(
                      label: 'Green',
                      color: Colors.green.shade600,
                      selected: seat.statusColor == SeatStatusColor.green,
                      onTap: () {
                        service.setSeatStatus(
                            widget.classId, seatId, SeatStatusColor.green);
                        Navigator.of(context).pop();
                      },
                    ),
                    _StatusChip(
                      label: 'Yellow',
                      color: Colors.amber.shade700,
                      selected: seat.statusColor == SeatStatusColor.yellow,
                      onTap: () {
                        service.setSeatStatus(
                            widget.classId, seatId, SeatStatusColor.yellow);
                        Navigator.of(context).pop();
                      },
                    ),
                    _StatusChip(
                      label: 'Red',
                      color: Colors.red.shade600,
                      selected: seat.statusColor == SeatStatusColor.red,
                      onTap: () {
                        service.setSeatStatus(
                            widget.classId, seatId, SeatStatusColor.red);
                        Navigator.of(context).pop();
                      },
                    ),
                    _StatusChip(
                      label: 'Blue',
                      color: Colors.blue.shade600,
                      selected: seat.statusColor == SeatStatusColor.blue,
                      onTap: () {
                        service.setSeatStatus(
                            widget.classId, seatId, SeatStatusColor.blue);
                        Navigator.of(context).pop();
                      },
                    ),
                    _StatusChip(
                      label: 'Clear',
                      color: Theme.of(context).colorScheme.outlineVariant,
                      selected: seat.statusColor == SeatStatusColor.none,
                      onTap: () {
                        service.setSeatStatus(
                            widget.classId, seatId, SeatStatusColor.none);
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    student == null
                        ? Icons.person_add_alt_1_outlined
                        : Icons.swap_horiz,
                  ),
                  title: Text(
                    student == null
                        ? 'Assign student'
                        : 'Swap or replace student',
                  ),
                  subtitle: Text(
                    widget.students.isEmpty
                        ? 'Add students to the class roster first.'
                        : student == null
                            ? 'Choose from the roster for this seat.'
                            : 'Pick another student or swap with an occupied seat.',
                  ),
                  enabled: widget.students.isNotEmpty,
                  onTap: widget.students.isEmpty
                      ? null
                      : () {
                          Navigator.of(context).pop();
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (!mounted) return;
                            _showStudentAssignmentSheet(
                              context,
                              service,
                              layout,
                              seatId,
                            );
                          });
                        },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    seat.reminder
                        ? Icons.notifications_active_outlined
                        : Icons.sticky_note_2_outlined,
                  ),
                  title: Text(
                    hasAnnotation
                        ? 'Edit note or reminder'
                        : 'Add note or reminder',
                  ),
                  subtitle: Text(
                    seat.note.trim().isNotEmpty
                        ? seat.note.trim()
                        : seat.reminder
                            ? 'Reminder is on for this seat.'
                            : 'Keep a quick note for this student or seat.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      _editSeatNote(
                        context,
                        service,
                        seat,
                      );
                    });
                  },
                ),
                if (_designMode && canEditSeatStructure)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.content_copy_outlined),
                    title: const Text('Duplicate chair'),
                    subtitle: const Text('Copy this seat and place it nearby.'),
                    onTap: () async {
                      await service.duplicateSeat(widget.classId, seatId);
                      if (!context.mounted) return;
                      Navigator.of(context).pop();
                    },
                  ),
                if (_designMode && canEditSeatStructure)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.delete_outline),
                    title: const Text('Remove chair'),
                    subtitle: Text(
                      table.seatCount <= 1
                          ? 'Keep at least one seat on this table.'
                          : 'Delete this seat from the table.',
                    ),
                    enabled: table.seatCount > 1,
                    onTap: table.seatCount <= 1
                        ? null
                        : () async {
                            await service.removeSeat(widget.classId, seatId);
                            if (!context.mounted) return;
                            Navigator.of(context).pop();
                          },
                  ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    seat.locked ? Icons.lock_open_outlined : Icons.lock_outline,
                  ),
                  title: Text(
                    seat.locked
                        ? 'Unlock seat for shuffle'
                        : 'Lock seat for shuffle',
                  ),
                  subtitle: Text(
                    student == null
                        ? seat.locked
                            ? 'Let shuffles fill this seat again.'
                            : 'Keep this chair empty during shuffles.'
                        : seat.locked
                            ? 'Allow this student to move again when shuffling.'
                            : 'Keep this student in place when shuffling.',
                  ),
                  onTap: () async {
                    await service.setSeatLocked(
                      widget.classId,
                      seatId,
                      !seat.locked,
                    );
                    if (!context.mounted) return;
                    Navigator.of(context).pop();
                  },
                ),
                if (student != null)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.clear),
                    title: const Text('Clear seat'),
                    subtitle: const Text(
                        'Remove the current student from this seat.'),
                    onTap: () {
                      service.clearSeat(widget.classId, seatId);
                      Navigator.of(context).pop();
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _editSeatNote(
    BuildContext context,
    SeatingService service,
    SeatingSeat seat,
  ) async {
    final controller = TextEditingController(text: seat.note);
    var reminderEnabled = seat.reminder;

    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Seat note or reminder'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: controller,
                      autofocus: true,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Note',
                        hintText: 'Needs front row, check in after class, etc.',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Show reminder'),
                      subtitle: const Text(
                        'Add a visual reminder icon to this seat.',
                      ),
                      value: reminderEnabled,
                      onChanged: (value) {
                        setDialogState(() => reminderEnabled = value);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                if (seat.note.trim().isNotEmpty || seat.reminder)
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop('clear'),
                    child: const Text('Clear'),
                  ),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop('cancel'),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop('save'),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (action == null || action == 'cancel') return;

    await service.updateSeatNote(
      widget.classId,
      seat.seatId,
      note: action == 'clear' ? '' : controller.text,
      reminder: action == 'clear' ? false : reminderEnabled,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          action == 'clear' ? 'Seat note cleared.' : 'Seat note updated.',
        ),
      ),
    );
  }

  Future<void> _showStudentAssignmentSheet(
    BuildContext context,
    SeatingService service,
    SeatingLayout layout,
    String seatId,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StudentAssignmentSheet(
          students: widget.students,
          seats: layout.seats,
          targetSeatId: seatId,
          onSelected: (student) async {
            final currentLayout =
                service.activeLayout(widget.classId) ?? layout;
            final fromSeat =
                currentLayout.seats.cast<SeatingSeat?>().firstWhere(
                      (seat) => seat?.studentId == student.studentId,
                      orElse: () => null,
                    );
            await service.assignStudentToSeat(
              widget.classId,
              seatId,
              student.studentId,
              fromSeatId: fromSeat?.seatId,
            );
            if (!sheetContext.mounted) return;
            Navigator.of(sheetContext).pop();
          },
        );
      },
    );
  }

  Future<void> _showStudentPicker(
    BuildContext context,
    SeatingService service,
    SeatingLayout layout,
    Map<String, Student> studentsById,
  ) async {
    final orderedSeats = service.orderedSeatsForLayout(layout);
    final entries = orderedSeats
        .asMap()
        .entries
        .where((entry) {
          final studentId = entry.value.studentId;
          return studentId != null && studentId.isNotEmpty;
        })
        .map((entry) {
          final student = studentsById[entry.value.studentId];
          if (student == null) return null;
          return StudentPickerEntry(
            student: student,
            seatLabel: 'Seat ${entry.key + 1}',
          );
        })
        .whereType<StudentPickerEntry>()
        .toList();

    if (entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Place a few students first, then use the picker.'),
        ),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => StudentPickerSheet(entries: entries),
    );
  }

  bool _canEditSeatStructure(SeatingTableType type) {
    switch (type) {
      case SeatingTableType.rectangular:
      case SeatingTableType.square:
      case SeatingTableType.round:
      case SeatingTableType.pairedRect:
      case SeatingTableType.longDouble:
        return true;
      case SeatingTableType.singleDesk:
      case SeatingTableType.teacherDesk:
        return false;
    }
  }
}

const List<SeatingTableType> _editableTableTypes = [
  SeatingTableType.rectangular,
  SeatingTableType.square,
  SeatingTableType.round,
  SeatingTableType.singleDesk,
  SeatingTableType.teacherDesk,
  SeatingTableType.pairedRect,
  SeatingTableType.longDouble,
];

class _SeatingDesignerToolBand extends StatelessWidget {
  const _SeatingDesignerToolBand({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: theme.colorScheme.surface.withValues(
            alpha: isDark ? 0.24 : 0.48,
          ),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(
              alpha: isDark ? 0.24 : 0.18,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          child: child,
        ),
      ),
    );
  }
}

class _SeatingHintShell extends StatelessWidget {
  const _SeatingHintShell({
    required this.icon,
    required this.child,
  });

  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: scheme.outline.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: scheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _StatusChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: color.withValues(alpha: 0.2),
      side: BorderSide(color: color.withValues(alpha: 0.7)),
      onSelected: (_) => onTap(),
    );
  }
}

class _EditRoomHint extends StatelessWidget {
  final bool hasSeats;

  const _EditRoomHint({
    required this.hasSeats,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _SeatingHintShell(
      icon: Icons.tune,
      child: Text(
        hasSeats
            ? 'Edit room is on. Use Add furniture for new items, duplicate from the seat or table menus, and drag handles to place everything.'
            : 'Edit room is on. Use Add furniture to start building the room, then drag tables and seats where you want them.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
      ),
    );
  }
}

class _SeatingUseHint extends StatelessWidget {
  const _SeatingUseHint();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _SeatingHintShell(
      icon: Icons.swap_horiz,
      child: Text(
        'Drag a student onto any seat to swap places, or onto a table to use its next empty seat. Tap a seat to lock it before shuffling.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
      ),
    );
  }
}

class _FullScreenSeatingRoute extends StatelessWidget {
  final String classId;
  final List<Student> students;

  const _FullScreenSeatingRoute({
    required this.classId,
    required this.students,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seating chart'),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Close',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SeatingDesignerView(
          classId: classId,
          students: students,
          autoLoad: false,
          presentationMode: true,
          showStudentPanel: false,
          showFullScreenButton: false,
        ),
      ),
    );
  }
}

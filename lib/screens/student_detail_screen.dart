import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:gradeflow/components/workspace_shell.dart';
import 'package:gradeflow/services/class_service.dart';
import 'package:gradeflow/services/student_service.dart';
import 'package:gradeflow/services/grading_category_service.dart';
import 'package:gradeflow/services/grade_item_service.dart';
import 'package:gradeflow/services/student_score_service.dart';
import 'package:gradeflow/services/final_exam_service.dart';
import 'package:gradeflow/services/calculation_service.dart';
import 'package:gradeflow/services/auth_service.dart';
import 'package:gradeflow/nav.dart';
import 'package:gradeflow/theme.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';

class StudentDetailScreen extends StatefulWidget {
  final String classId;
  final String studentId;

  const StudentDetailScreen(
      {super.key, required this.classId, required this.studentId});

  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen> {
  final CalculationService _calcService = CalculationService();
  Map<String, double?>? _grades;
  bool _updatingPhoto = false;

  void _goToStudentList() {
    context.go('${AppRoutes.classDetail}/${widget.classId}/students');
  }

  void _showFeedback(
    String message, {
    WorkspaceFeedbackTone tone = WorkspaceFeedbackTone.info,
    String? title,
  }) {
    if (!mounted) return;
    showWorkspaceSnackBar(
      context,
      message: message,
      tone: tone,
      title: title,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadData();
    });
  }

  Future<void> _ensureClassContextLoaded() async {
    final classService = context.read<ClassService>();
    if (classService.getClassById(widget.classId) != null) return;

    final user = context.read<AuthService>().currentUser;
    if (user != null) {
      await classService.loadClasses(user.userId);
    }
  }

  Future<void> _loadData() async {
    final studentService = context.read<StudentService>();
    final categoryService = context.read<GradingCategoryService>();
    final gradeItemService = context.read<GradeItemService>();
    final scoreService = context.read<StudentScoreService>();
    final examService = context.read<FinalExamService>();

    await _ensureClassContextLoaded();
    await studentService.loadStudents(widget.classId);
    await categoryService.loadCategories(widget.classId);
    await gradeItemService.loadGradeItems(widget.classId);

    final gradeItemIds =
        gradeItemService.gradeItems.map((g) => g.gradeItemId).toList();
    await scoreService.loadScores(widget.classId, gradeItemIds);
    await examService.loadExams(widget.classId, [widget.studentId]);

    final exam = examService.getExam(widget.studentId);
    final grades = _calcService.calculateStudentGrades(
      widget.studentId,
      categoryService.categories,
      gradeItemService.gradeItems,
      scoreService.scores,
      exam,
    );

    setState(() => _grades = grades);
  }

  Future<void> _changePhoto() async {
    if (_updatingPhoto) return;
    final isWeb = kIsWeb;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (!isWeb)
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Take Photo'),
              onTap: () => Navigator.of(ctx).pop('camera'),
            ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from device'),
            onTap: () => Navigator.of(ctx).pop('device'),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (action == null) return;
    setState(() => _updatingPhoto = true);
    try {
      Uint8List? bytes;
      if (action == 'camera') {
        final picker = ImagePicker();
        final xfile = await picker.pickImage(
            source: ImageSource.camera, maxWidth: 1600, imageQuality: 85);
        if (xfile != null) bytes = await xfile.readAsBytes();
      } else {
        final picked = await FilePicker.platform.pickFiles(
            type: FileType.custom,
            allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
            withData: true);
        if (picked != null && picked.files.single.bytes != null) {
          bytes = picked.files.single.bytes!;
        }
      }
      if (bytes == null || !mounted) return;
      final base64 = base64Encode(bytes);
      final studentService = context.read<StudentService>();
      final student = studentService.students
          .firstWhere((s) => s.studentId == widget.studentId);
      final updated =
          student.copyWith(photoBase64: base64, updatedAt: DateTime.now());
      await studentService.updateStudent(updated);
      _showFeedback(
        'Profile photo updated',
        tone: WorkspaceFeedbackTone.success,
      );
    } catch (e) {
      debugPrint('Failed to set profile photo: $e');
      _showFeedback(
        'Could not set photo',
        tone: WorkspaceFeedbackTone.error,
        title: 'Photo update failed',
      );
    } finally {
      if (mounted) setState(() => _updatingPhoto = false);
    }
  }

  Widget _buildContextBar(
    BuildContext context, {
    required String className,
    required String classContextLine,
    required String? seatNo,
    required String? classCode,
    required int categoryCount,
  }) {
    return WorkspaceContextBar(
      title: 'Student record context',
      subtitle: classContextLine,
      leading: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          WorkspaceContextPill(
            icon: Icons.class_outlined,
            label: 'Class',
            value: className,
            emphasized: true,
          ),
          if (seatNo?.isNotEmpty ?? false)
            WorkspaceContextPill(
              icon: Icons.event_seat_outlined,
              label: 'Seat',
              value: seatNo!,
            ),
          if (classCode?.isNotEmpty ?? false)
            WorkspaceContextPill(
              icon: Icons.badge_outlined,
              label: 'Code',
              value: classCode!,
            ),
          WorkspaceContextPill(
            icon: Icons.category_outlined,
            label: 'Categories',
            value: '$categoryCount',
          ),
        ],
      ),
      trailing: WorkspaceContextPill(
        icon: Icons.summarize_outlined,
        label: 'Final grade',
        value: _grades?['finalGrade']?.toStringAsFixed(1) ?? 'N/A',
        accent: Theme.of(context).colorScheme.primary,
        emphasized: true,
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context, dynamic student) {
    final theme = Theme.of(context);
    return WorkspaceSurfaceCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              CircleAvatar(
                radius: 42,
                backgroundColor: theme.colorScheme.primaryContainer,
                backgroundImage: (student.photoBase64 != null &&
                        student.photoBase64!.isNotEmpty)
                    ? MemoryImage(
                        const Base64Decoder().convert(student.photoBase64!),
                      )
                    : null,
                child: (student.photoBase64 == null ||
                        student.photoBase64!.isEmpty)
                    ? Text(
                        student.englishFirstName[0],
                        style: context.textStyles.displayMedium?.withColor(
                          theme.colorScheme.onPrimaryContainer,
                        ),
                      )
                    : null,
              ),
              IconButton(
                onPressed: _updatingPhoto ? null : _changePhoto,
                tooltip: 'Update photo',
                style: WorkspaceButtonStyles.icon(context),
                icon: _updatingPhoto
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      )
                    : const Icon(Icons.camera_alt_outlined),
              ),
            ],
          ),
          const SizedBox(height: WorkspaceSpacing.md),
          Text(
            student.chineseName,
            style: context.textStyles.headlineSmall?.semiBold,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            student.englishFullName,
            style: context.textStyles.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: WorkspaceSpacing.sm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              WorkspaceContextPill(
                icon: Icons.badge_outlined,
                label: 'Student ID',
                value: student.studentId,
              ),
              if (student.seatNo?.isNotEmpty ?? false)
                WorkspaceContextPill(
                  icon: Icons.event_seat_outlined,
                  label: 'Seat',
                  value: student.seatNo!,
                ),
              if (student.classCode?.isNotEmpty ?? false)
                WorkspaceContextPill(
                  icon: Icons.school_outlined,
                  label: 'Class code',
                  value: student.classCode!,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownCard(
      BuildContext context, dynamic student, List<dynamic> categories) {
    return WorkspaceSurfaceCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const WorkspaceSectionHeader(
            title: 'Grade breakdown',
            subtitle:
                'Process, exam, and final values stay visible inside one calm student summary.',
          ),
          const SizedBox(height: WorkspaceSpacing.md),
          ...categories.map((category) {
            final score = _grades![category.categoryId];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      '${category.name} (${category.weightPercent}%)',
                      style: context.textStyles.bodyMedium,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    score != null ? score.toStringAsFixed(1) : 'N/A',
                    style: context.textStyles.titleMedium?.semiBold,
                  ),
                ],
              ),
            );
          }),
          const Divider(height: WorkspaceSpacing.xl),
          _ScoreSummaryRow(
            label: 'Process score (40%)',
            value: _grades!['processScore'],
          ),
          const SizedBox(height: WorkspaceSpacing.sm),
          _ScoreSummaryRow(
            label: 'Exam score (60%)',
            value: _grades!['examScore'],
          ),
          const Divider(height: WorkspaceSpacing.xl),
          _ScoreSummaryRow(
            label: 'Final grade',
            value: _grades!['finalGrade'],
            highlight: true,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final studentService = context.watch<StudentService>();
    final categoryService = context.watch<GradingCategoryService>();
    final classItem =
        context.watch<ClassService>().getClassById(widget.classId);
    dynamic student;
    for (final candidate in studentService.students) {
      if (candidate.studentId == widget.studentId) {
        student = candidate;
        break;
      }
    }
    final className = classItem?.className ?? 'Class';
    final classContextParts = <String>[
      if (classItem?.subject.trim().isNotEmpty ?? false) classItem!.subject,
      if (classItem?.schoolYear.trim().isNotEmpty ?? false)
        classItem!.schoolYear,
      if (classItem?.term.trim().isNotEmpty ?? false) classItem!.term,
    ];
    final classContextLine = classContextParts.isEmpty
        ? 'Current class context'
        : classContextParts.join(' / ');

    return WorkspaceScaffold(
      title: student?.chineseName ?? 'Student record',
      subtitle:
          student == null ? 'Loading student profile' : student.englishFullName,
      eyebrow: 'Student Record',
      leadingActions: [
        IconButton(
          onPressed: _goToStudentList,
          tooltip: 'Back to students',
          style: WorkspaceButtonStyles.icon(context),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ],
      trailingActions: [
        IconButton(
          onPressed: _loadData,
          tooltip: 'Refresh',
          style: WorkspaceButtonStyles.icon(context),
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      contextBar: student == null
          ? null
          : _buildContextBar(
              context,
              className: className,
              classContextLine: classContextLine,
              seatNo: student.seatNo,
              classCode: student.classCode,
              categoryCount: categoryService.categories.length,
            ),
      child: student == null || _grades == null
          ? const WorkspaceLoadingState(
              title: 'Loading student record',
              subtitle: 'Bringing profile, category, and exam data into view.',
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: WorkspaceSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildProfileCard(context, student),
                  const SizedBox(height: WorkspaceSpacing.md),
                  _buildBreakdownCard(
                    context,
                    student,
                    categoryService.categories,
                  ),
                ],
              ),
            ),
    );
  }
}

class _ScoreSummaryRow extends StatelessWidget {
  const _ScoreSummaryRow({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final double? value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final resolvedValue = value == null ? 'N/A' : value!.toStringAsFixed(1);
    final accent = highlight
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurface;
    final labelStyle = highlight
        ? context.textStyles.headlineSmall?.bold
        : context.textStyles.titleMedium?.semiBold;
    final valueStyle = highlight
        ? context.textStyles.headlineMedium?.bold.withColor(accent)
        : context.textStyles.titleLarge?.bold;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: labelStyle),
        Text(
          resolvedValue,
          style: highlight ? valueStyle : valueStyle?.withColor(accent),
        ),
      ],
    );
  }
}

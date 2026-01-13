import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:gradeflow/services/student_service.dart';
import 'package:gradeflow/services/grading_category_service.dart';
import 'package:gradeflow/services/grade_item_service.dart';
import 'package:gradeflow/services/student_score_service.dart';
import 'package:gradeflow/services/final_exam_service.dart';
import 'package:gradeflow/services/calculation_service.dart';
import 'package:gradeflow/theme.dart';
import 'package:gradeflow/components/animated_glow_border.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:typed_data';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final studentService = context.read<StudentService>();
    final categoryService = context.read<GradingCategoryService>();
    final gradeItemService = context.read<GradeItemService>();
    final scoreService = context.read<StudentScoreService>();
    final examService = context.read<FinalExamService>();

    await studentService.loadStudents(widget.classId);
    await categoryService.loadCategories(widget.classId);
    await gradeItemService.loadGradeItems(widget.classId);

    final gradeItemIds =
        gradeItemService.gradeItems.map((g) => g.gradeItemId).toList();
    await scoreService.loadScores(widget.classId, gradeItemIds);
    await examService.loadExams([widget.studentId]);

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
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile photo updated')));
    } catch (e) {
      debugPrint('Failed to set profile photo: $e');
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('Could not set photo'),
            backgroundColor: Theme.of(context).colorScheme.error));
    } finally {
      if (mounted) setState(() => _updatingPhoto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final studentService = context.watch<StudentService>();
    final categoryService = context.watch<GradingCategoryService>();
    final student = studentService.students.firstWhere(
      (s) => s.studentId == widget.studentId,
      orElse: () => throw Exception('Student not found'),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(student.chineseName),
      ),
      body: _grades == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: AppSpacing.paddingLg,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AnimatedGlowBorder(
                    child: Card(
                      child: Padding(
                        padding: AppSpacing.paddingLg,
                        child: Column(
                          children: [
                            Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                CircleAvatar(
                                  radius: 40,
                                  backgroundColor: Theme.of(context)
                                      .colorScheme
                                      .primaryContainer,
                                  backgroundImage:
                                      (student.photoBase64 != null &&
                                              student.photoBase64!.isNotEmpty)
                                          ? MemoryImage(const Base64Decoder()
                                              .convert(student.photoBase64!))
                                          : null,
                                  child: (student.photoBase64 == null ||
                                          student.photoBase64!.isEmpty)
                                      ? Text(student.englishFirstName[0],
                                          style: context
                                              .textStyles.displayMedium
                                              ?.withColor(Theme.of(context)
                                                  .colorScheme
                                                  .onPrimaryContainer))
                                      : null,
                                ),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: InkWell(
                                    onTap: _updatingPhoto ? null : _changePhoto,
                                    child: Container(
                                      decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .surface,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                              color: Theme.of(context)
                                                  .dividerColor,
                                              width: 0.5)),
                                      padding: const EdgeInsets.all(6),
                                      child: Icon(Icons.camera_alt,
                                          size: 18,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text(student.chineseName,
                                style:
                                    context.textStyles.headlineSmall?.semiBold),
                            Text(student.englishFullName,
                                style: context.textStyles.bodyLarge),
                            const SizedBox(height: AppSpacing.sm),
                            Text('ID: ${student.studentId}',
                                style: context.textStyles.bodySmall),
                            const SizedBox(height: AppSpacing.xs),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (student.seatNo != null &&
                                    student.seatNo!.isNotEmpty) ...[
                                  Icon(Icons.event_seat,
                                      size: 16,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant),
                                  const SizedBox(width: 4),
                                  Text('Seat ${student.seatNo}',
                                      style: context.textStyles.bodySmall
                                          ?.withColor(Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant)),
                                ],
                                if ((student.seatNo != null &&
                                        student.seatNo!.isNotEmpty) &&
                                    (student.classCode != null &&
                                        student.classCode!.isNotEmpty))
                                  const SizedBox(width: AppSpacing.md),
                                if (student.classCode != null &&
                                    student.classCode!.isNotEmpty) ...[
                                  Icon(Icons.school,
                                      size: 16,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant),
                                  const SizedBox(width: 4),
                                  Text('Class ${student.classCode}',
                                      style: context.textStyles.bodySmall
                                          ?.withColor(Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant)),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AnimatedGlowBorder(
                    child: Card(
                      child: Padding(
                        padding: AppSpacing.paddingLg,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Grade Breakdown',
                                style: context.textStyles.titleLarge?.semiBold),
                            const SizedBox(height: AppSpacing.md),
                            ...categoryService.categories.map((category) {
                              final score = _grades![category.categoryId];
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: AppSpacing.xs),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                        '${category.name} (${category.weightPercent}%)'),
                                    Text(
                                      score != null
                                          ? score.toStringAsFixed(1)
                                          : 'N/A',
                                      style: context
                                          .textStyles.titleMedium?.semiBold,
                                    ),
                                  ],
                                ),
                              );
                            }),
                            const Divider(height: AppSpacing.lg),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Process Score (40%)',
                                    style: context
                                        .textStyles.titleMedium?.semiBold),
                                Text(
                                  _grades!['processScore'] != null
                                      ? _grades!['processScore']!
                                          .toStringAsFixed(1)
                                      : 'N/A',
                                  style: context.textStyles.titleLarge?.bold,
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Exam Score (60%)',
                                    style: context
                                        .textStyles.titleMedium?.semiBold),
                                Text(
                                  _grades!['examScore'] != null
                                      ? _grades!['examScore']!
                                          .toStringAsFixed(1)
                                      : 'N/A',
                                  style: context.textStyles.titleLarge?.bold,
                                ),
                              ],
                            ),
                            const Divider(height: AppSpacing.lg),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Final Grade',
                                    style:
                                        context.textStyles.headlineSmall?.bold),
                                Text(
                                  _grades!['finalGrade'] != null
                                      ? _grades!['finalGrade']!
                                          .toStringAsFixed(1)
                                      : 'N/A',
                                  style: context.textStyles.headlineMedium?.bold
                                      .withColor(
                                    Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gradeflow/components/tool_first_app_surface.dart';
import 'package:gradeflow/components/workspace_shell.dart';
import 'package:gradeflow/models/student.dart';
import 'package:gradeflow/services/student_service.dart';
import 'package:gradeflow/services/grading_category_service.dart';
import 'package:gradeflow/services/grade_item_service.dart';
import 'package:gradeflow/services/student_score_service.dart';
import 'package:gradeflow/services/final_exam_service.dart';
import 'package:gradeflow/services/calculation_service.dart';
import 'package:gradeflow/services/class_service.dart';
import 'package:gradeflow/theme.dart';

class FinalResultsScreen extends StatefulWidget {
  final String classId;
  const FinalResultsScreen({super.key, required this.classId});

  @override
  State<FinalResultsScreen> createState() => _FinalResultsScreenState();
}

class _FinalResultsScreenState extends State<FinalResultsScreen> {
  final CalculationService _calc = CalculationService();
  bool _loading = false;
  Map<String, Map<String, double?>> _grades = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final students = context.read<StudentService>();
    final cats = context.read<GradingCategoryService>();
    final items = context.read<GradeItemService>();
    final scores = context.read<StudentScoreService>();
    final exams = context.read<FinalExamService>();

    await students.loadStudents(widget.classId);
    await cats.loadCategories(widget.classId);
    await items.loadGradeItems(widget.classId);

    final studentIds = students.students.map((s) => s.studentId).toList();
    final gradeItemIds = items.gradeItems.map((g) => g.gradeItemId).toList();

    await scores.loadScores(widget.classId, gradeItemIds);
    await exams.loadExams(widget.classId, studentIds);

    final map = <String, Map<String, double?>>{};
    for (final s in students.students) {
      final exam = exams.getExam(s.studentId);
      map[s.studentId] = _calc.calculateStudentGrades(
        s.studentId,
        cats.categories,
        items.gradeItems,
        scores.scores,
        exam,
      );
    }
    setState(() {
      _grades = map;
      _loading = false;
    });
  }

  Widget _buildContextStrip(
    BuildContext context, {
    required String className,
    required String classContextLine,
    required int studentCount,
  }) {
    return WorkspaceContextBar(
      title: className,
      subtitle: classContextLine,
      leading: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          WorkspaceContextPill(
            icon: Icons.people_alt_outlined,
            label: 'Roster',
            value: '$studentCount students',
          ),
          const WorkspaceContextPill(
            icon: Icons.auto_graph_outlined,
            label: 'Process',
            value: '40%',
          ),
          const WorkspaceContextPill(
            icon: Icons.fact_check_outlined,
            label: 'Exam',
            value: '60%',
          ),
        ],
      ),
      trailing: WorkspaceContextPill(
        icon: Icons.verified_outlined,
        label: 'View',
        value: 'Final grades',
        accent: Theme.of(context).colorScheme.primary,
        emphasized: true,
      ),
    );
  }

  Widget _buildResultRow(
    BuildContext context, {
    required Student student,
    required Map<String, double?> grades,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: WorkspaceSpacing.sm),
      child: WorkspaceSurfaceCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 860;
            final info = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.chineseName,
                  style: context.textStyles.titleMedium?.semiBold,
                ),
                const SizedBox(height: 2),
                Text(
                  student.englishFullName,
                  style: WorkspaceTypography.metadata(context),
                ),
                const SizedBox(height: 6),
                Text(
                  student.seatNo?.isNotEmpty == true
                      ? 'ID ${student.studentId} / Seat ${student.seatNo}'
                      : 'ID ${student.studentId}',
                  style: context.textStyles.labelSmall?.withColor(
                    Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            );
            final metrics = Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                _ScorePill(label: 'Process 40%', value: grades['processScore']),
                _ScorePill(label: 'Exam 60%', value: grades['examScore']),
                _ScorePill(
                  label: 'Final grade',
                  value: grades['finalGrade'],
                  highlight: true,
                ),
              ],
            );

            if (narrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  info,
                  const SizedBox(height: WorkspaceSpacing.md),
                  metrics,
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: info),
                const SizedBox(width: WorkspaceSpacing.md),
                metrics,
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final students = context.watch<StudentService>();
    final classItem = context.watch<ClassService>().getClassById(widget.classId);
    final className = classItem?.className ?? 'Class';
    final studentCount = students.students.length;
    final classContextParts = <String>[
      if (classItem?.subject.trim().isNotEmpty ?? false) classItem!.subject,
      if (classItem?.schoolYear.trim().isNotEmpty ?? false)
        classItem!.schoolYear,
      if (classItem?.term.trim().isNotEmpty ?? false) classItem!.term,
      '$studentCount student${studentCount == 1 ? '' : 's'}',
    ];
    final classContextLine = classContextParts.isEmpty
        ? 'Current class context'
        : classContextParts.join(' / ');

    return ToolFirstAppSurface(
      title: 'Final Results',
      eyebrow: 'Student Reporting',
      subtitle:
          'Review weighted process, exam, and final grades in one aligned view.',
      leading: IconButton(
        onPressed: () => Navigator.of(context).pop(),
        tooltip: 'Back',
        style: WorkspaceButtonStyles.icon(context),
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      trailing: [
        IconButton(
          onPressed: _load,
          tooltip: 'Refresh',
          style: WorkspaceButtonStyles.icon(context),
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      contextStrip: _buildContextStrip(
        context,
        className: className,
        classContextLine: classContextLine,
        studentCount: studentCount,
      ),
      workspace: _loading
          ? const WorkspaceLoadingState(
              title: 'Calculating final results',
              subtitle: 'Loading the roster, exam scores, and weighted grades.',
            )
          : students.students.isEmpty
              ? const WorkspaceEmptyState(
                  icon: Icons.summarize_outlined,
                  title: 'No students in this class',
                  subtitle:
                      'Add students and exam scores before reviewing final results.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: WorkspaceSpacing.md),
                  itemCount: students.students.length,
                  itemBuilder: (context, index) {
                    final student = students.students[index];
                    final grades = _grades[student.studentId] ?? {};
                    return _buildResultRow(
                      context,
                      student: student,
                      grades: grades,
                    );
                  },
                ),
    );
  }
}

class _ScorePill extends StatelessWidget {
  final String label;
  final double? value;
  final bool highlight;
  const _ScorePill(
      {required this.label, required this.value, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    final bg = highlight
        ? Theme.of(context).colorScheme.primaryContainer
        : Theme.of(context).colorScheme.surfaceContainerHighest;
    final fg = highlight
        ? Theme.of(context).colorScheme.onPrimaryContainer
        : Theme.of(context).colorScheme.onSurface;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(label, style: context.textStyles.labelSmall?.withColor(fg)),
          Text(value == null ? 'N/A' : value!.toStringAsFixed(1),
              style: context.textStyles.titleMedium?.bold.withColor(fg)),
        ],
      ),
    );
  }
}

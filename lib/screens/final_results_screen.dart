import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:gradeflow/components/animated_page_background.dart';
import 'package:gradeflow/components/workspace_shell.dart';
import 'package:gradeflow/models/student.dart';
import 'package:gradeflow/services/student_service.dart';
import 'package:gradeflow/services/grading_category_service.dart';
import 'package:gradeflow/services/grade_item_service.dart';
import 'package:gradeflow/services/student_score_service.dart';
import 'package:gradeflow/services/final_exam_service.dart';
import 'package:gradeflow/services/calculation_service.dart';
import 'package:gradeflow/services/auth_service.dart';
import 'package:gradeflow/services/class_service.dart';
import 'package:gradeflow/nav.dart';
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

  void _goToClassWorkspace() {
    context.go('${AppRoutes.osClass}/${widget.classId}');
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _ensureClassContextLoaded() async {
    final classService = context.read<ClassService>();
    if (classService.getClassById(widget.classId) != null) return;

    final user = context.read<AuthService>().currentUser;
    if (user != null) {
      await classService.loadClasses(user.userId);
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final students = context.read<StudentService>();
    final cats = context.read<GradingCategoryService>();
    final items = context.read<GradeItemService>();
    final scores = context.read<StudentScoreService>();
    final exams = context.read<FinalExamService>();

    await _ensureClassContextLoaded();
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
    return _ResultsFlatSurface(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 900;
          final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                className,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textStyles.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                classContextLine,
                maxLines: narrow ? 2 : 1,
                overflow: TextOverflow.ellipsis,
                style: WorkspaceTypography.metadata(context),
              ),
            ],
          );
          final pills = Wrap(
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
              WorkspaceContextPill(
                icon: Icons.verified_outlined,
                label: 'View',
                value: 'Final grades',
                accent: Theme.of(context).colorScheme.primary,
                emphasized: true,
              ),
            ],
          );

          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                copy,
                const SizedBox(height: WorkspaceSpacing.xs),
                pills,
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: copy),
              const SizedBox(width: WorkspaceSpacing.sm),
              Flexible(flex: 2, child: pills),
            ],
          );
        },
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
      child: _ResultsFlatSurface(
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
    final classItem =
        context.watch<ClassService>().getClassById(widget.classId);
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

    return _ResultsNativeSurface(
      title: className,
      toolLabel: 'Final Results',
      eyebrow: 'Class workspace',
      subtitle: classContextLine,
      leading: IconButton(
        onPressed: _goToClassWorkspace,
        tooltip: 'Back to class workspace',
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

class _ResultsNativeSurface extends StatelessWidget {
  const _ResultsNativeSurface({
    required this.eyebrow,
    required this.title,
    required this.toolLabel,
    required this.workspace,
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
  final Widget workspace;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedPageBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1480),
              child: Padding(
                padding: WorkspaceSpacing.shellMargin,
                child: WorkspaceShellFrame(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                  radius: WorkspaceRadius.shell,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _ResultsNativeHeader(
                        eyebrow: eyebrow,
                        title: title,
                        toolLabel: toolLabel,
                        subtitle: subtitle,
                        leading: leading,
                        trailing: trailing,
                      ),
                      const SizedBox(height: WorkspaceSpacing.sm),
                      if (contextStrip != null) ...[
                        contextStrip!,
                        const SizedBox(height: WorkspaceSpacing.md),
                      ],
                      Expanded(child: workspace),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultsNativeHeader extends StatelessWidget {
  const _ResultsNativeHeader({
    required this.eyebrow,
    required this.title,
    required this.toolLabel,
    this.subtitle,
    this.leading,
    this.trailing = const [],
  });

  final String eyebrow;
  final String title;
  final String toolLabel;
  final String? subtitle;
  final Widget? leading;
  final List<Widget> trailing;

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
            Icons.assessment_outlined,
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
        Icons.verified_outlined,
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
              title,
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
                subtitle!,
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
        final actions = Wrap(
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
                  if (trailing.isNotEmpty) actions,
                ],
              ),
              const SizedBox(height: WorkspaceSpacing.sm),
              copy,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            leadingCluster,
            const SizedBox(width: WorkspaceSpacing.md),
            Expanded(child: copy),
            if (trailing.isNotEmpty) ...[
              const SizedBox(width: WorkspaceSpacing.sm),
              actions,
            ],
          ],
        );
      },
    );
  }
}

class _ResultsFlatSurface extends StatelessWidget {
  const _ResultsFlatSurface({
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

class _ScorePill extends StatelessWidget {
  final String label;
  final double? value;
  final bool highlight;
  const _ScorePill(
      {required this.label, required this.value, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = highlight
        ? theme.colorScheme.primary.withValues(alpha: 0.12)
        : theme.colorScheme.surface.withValues(alpha: 0.34);
    final border = highlight
        ? theme.colorScheme.primary.withValues(alpha: 0.24)
        : theme.colorScheme.outline.withValues(alpha: 0.16);
    final fg = highlight
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface.withValues(alpha: 0.88);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            label,
            style: context.textStyles.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
          Text(
            value == null ? 'N/A' : value!.toStringAsFixed(1),
            style: context.textStyles.titleMedium?.copyWith(
              color: fg,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

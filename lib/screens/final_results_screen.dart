import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gradeflow/services/student_service.dart';
import 'package:gradeflow/services/grading_category_service.dart';
import 'package:gradeflow/services/grade_item_service.dart';
import 'package:gradeflow/services/student_score_service.dart';
import 'package:gradeflow/services/final_exam_service.dart';
import 'package:gradeflow/services/calculation_service.dart';
import 'package:gradeflow/theme.dart';
import 'package:gradeflow/components/animated_glow_border.dart';

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

  @override
  Widget build(BuildContext context) {
    final students = context.watch<StudentService>();
    return Scaffold(
      appBar: AppBar(title: const Text('Final Results')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : students.students.isEmpty
              ? const Center(child: Text('No students in this class'))
              : ListView.builder(
                  padding: AppSpacing.paddingMd,
                  itemCount: students.students.length,
                  itemBuilder: (context, index) {
                    final s = students.students[index];
                    final g = _grades[s.studentId] ?? {};
                    return AnimatedGlowBorder(
                      child: Card(
                        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: Padding(
                          padding: AppSpacing.paddingMd,
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(s.chineseName,
                                        style: context.textStyles.titleMedium),
                                    Text(s.englishFullName,
                                        style: context.textStyles.bodySmall),
                                    Text('ID: ${s.studentId}',
                                        style: context.textStyles.labelSmall),
                                  ],
                                ),
                              ),
                              _ScorePill(
                                  label: 'Process 40%',
                                  value: g['processScore']),
                              const SizedBox(width: AppSpacing.md),
                              _ScorePill(
                                  label: 'Exam 60%', value: g['examScore']),
                              const SizedBox(width: AppSpacing.md),
                              _ScorePill(
                                  label: 'Final',
                                  value: g['finalGrade'],
                                  highlight: true),
                            ],
                          ),
                        ),
                      ),
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

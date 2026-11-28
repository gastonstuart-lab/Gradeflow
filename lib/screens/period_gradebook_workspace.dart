import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/class.dart';
import '../models/user.dart' as domain;
import '../repositories/period_gradebook_adapter.dart';
import '../services/grading_period_ui_controller.dart';
import '../services/student_service.dart';
import '../services/grade_item_service.dart';
import '../services/grading_category_service.dart';
import '../services/student_score_service.dart';
import '../services/auth_service.dart';
import '../services/class_service.dart';
import '../services/historical_grade_export_adapter.dart';
import 'gradebook_screen.dart';

class PeriodGradebookWorkspace extends StatefulWidget {
  final GradingPeriodUiController session;
  final Class classRecord;
  final Future<void> Function(Uint8List bytes, String name) export;
  const PeriodGradebookWorkspace(
      {super.key,
      required this.session,
      required this.classRecord,
      required this.export});
  @override
  State<PeriodGradebookWorkspace> createState() => _WorkspaceState();
}

class _WorkspaceState extends State<PeriodGradebookWorkspace> {
  late final adapter =
      PeriodGradebookAdapter(widget.session, widget.classRecord);
  late final students = StudentService(repository: adapter);
  late final items = GradeItemService(repository: adapter);
  late final categories = GradingCategoryService(repository: adapter);
  late final scores = StudentScoreService(repository: adapter);
  late final classes = _PreviewClasses(widget.classRecord);
  late final auth = _PreviewAuth(widget.classRecord.teacherId);
  @override
  void dispose() {
    for (final service in [
      students,
      items,
      categories,
      scores,
      classes,
      auth
    ]) {
      service.dispose();
    }
    super.dispose();
  }

  Future<void> _start() async {
    var name = '';
    final confirmed = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Start a new grading period'),
              content: SizedBox(
                  width: 420,
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                            'The current period will become read only. The class and roster stay the same. Your new period will contain 2 quizzes and 6 each of classwork, homework and participation.'),
                        const SizedBox(height: 16),
                        TextField(
                            onChanged: (value) => name = value.trim(),
                            autofocus: true,
                            maxLength: 80,
                            decoration: const InputDecoration(
                                labelText: 'New period name',
                                border: OutlineInputBorder())),
                      ])),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () {
                      if (name.isNotEmpty) Navigator.pop(context, name);
                    },
                    child: const Text('Archive current & start'))
              ],
            ));
    if (mounted && confirmed != null) await widget.session.start(confirmed);
  }

  Widget _header() {
    final session = widget.session;
    return Padding(
        padding: const EdgeInsets.only(top: 10),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                    width: 320,
                    child: DropdownButtonFormField<String>(
                      initialValue: session.selectedId,
                      key: ValueKey('period-${session.selectedId}'),
                      decoration: const InputDecoration(
                          labelText: 'Grading period',
                          isDense: true,
                          border: OutlineInputBorder()),
                      items: [
                        for (final p in session.book!.periods)
                          DropdownMenuItem(
                              value: p.periodId,
                              child: Text(
                                  '${p.label} · ${p.isSealed ? "Archived" : "Active"}',
                                  overflow: TextOverflow.ellipsis))
                      ],
                      onChanged: session.busy
                          ? null
                          : (id) {
                              if (id != null) session.select(id);
                            },
                    )),
                if (!session.selected.isSealed)
                  OutlinedButton.icon(
                      onPressed: session.locked ? null : _start,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('New grading period')),
                if (session.selected.isSealed)
                  OutlinedButton.icon(
                      onPressed: session.busy
                          ? null
                          : () async {
                              try {
                                final bytes = HistoricalGradeExportAdapter()
                                    .generateXlsx(session.selected,
                                        ownerId: session.repository.ownerId,
                                        classId: session.classId);
                                await widget.export(bytes,
                                    'historical_${session.classId}_${session.selected.periodId}.xlsx');
                                if (mounted)
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'Historical Excel exported')));
                              } catch (_) {
                                if (mounted)
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'Export failed. Reload and try again.')));
                              }
                            },
                      icon: const Icon(Icons.download, size: 18),
                      label: const Text('Export historical Excel')),
                if (session.pending != null)
                  FilledButton.tonal(
                      onPressed: session.busy ? null : session.recover,
                      child: const Text('Recover rollover')),
                if (session.error != null || session.pending == null)
                  TextButton(
                      onPressed: session.busy ? null : session.initialize,
                      child: const Text('Reload')),
              ]),
          const SizedBox(height: 5),
          Semantics(
              liveRegion: true,
              child: Text(session.error ?? session.message,
                  style: TextStyle(
                      fontSize: 12,
                      color: session.error == null
                          ? null
                          : Theme.of(context).colorScheme.error))),
          if (session.busy) const LinearProgressIndicator(minHeight: 2),
        ]));
  }

  Widget _history() {
    final p = widget.session.selected;
    final data = p.dataset;
    final grades = HistoricalGradeExportAdapter().calculate(p);
    final activeItems = data.assessments.where((a) => a.isActive).toList();
    final activeCategories = data.categories.where((c) => c.isActive).toList();
    String value(double? v) => v == null ? '—' : v.toStringAsFixed(2);
    return Card(
        child: SingleChildScrollView(
            child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(columns: [
        const DataColumn(label: Text('Student')),
        for (final c in activeCategories)
          DataColumn(label: Text('${c.name} (${c.weightPercent}%)')),
        const DataColumn(label: Text('Process')),
        const DataColumn(label: Text('Exam')),
        const DataColumn(label: Text('Final')),
        for (final a in activeItems)
          DataColumn(label: Text('${a.name}\n/${a.maxScore}')),
      ], rows: [
        for (final s in data.students)
          DataRow(cells: [
            DataCell(Text('${s.studentId} · ${s.englishFullName}')),
            for (final c in activeCategories)
              DataCell(Text(value(grades[s.studentId]![c.categoryId]))),
            for (final key in ['processScore', 'examScore', 'finalGrade'])
              DataCell(Text(value(grades[s.studentId]![key]))),
            for (final a in activeItems)
              DataCell(Text(value(() {
                final score = data.scores
                    .where((v) =>
                        v.studentId == s.studentId &&
                        v.gradeItemId == a.gradeItemId)
                    .firstOrNull;
                return score == null ? a.maxScore : score.score;
              }()))),
          ])
      ]),
    )));
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: widget.session,
      builder: (context, _) {
        final session = widget.session;
        if (session.book == null)
          return Scaffold(
              body: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(session.error ?? session.message),
            TextButton(
                onPressed: session.busy ? null : session.initialize,
                child: const Text('Reload')),
          ])));
        return MultiProvider(
            providers: [
              ChangeNotifierProvider<StudentService>.value(value: students),
              ChangeNotifierProvider<GradeItemService>.value(value: items),
              ChangeNotifierProvider<GradingCategoryService>.value(
                  value: categories),
              ChangeNotifierProvider<StudentScoreService>.value(value: scores),
              ChangeNotifierProvider<ClassService>.value(value: classes),
              ChangeNotifierProvider<AuthService>.value(value: auth),
            ],
            child: GradebookScreen(
                key: ValueKey('${session.selectedId}-${session.viewEpoch}'),
                classId: session.classId,
                periodHeader: _header(),
                editingLocked: session.locked,
                historicalWorkspace:
                    session.selected.isSealed ? _history() : null,
                onLeave: () {}));
      });
}

class _PreviewClasses extends ClassService {
  final Class record;
  _PreviewClasses(this.record);
  @override
  Class? getClassById(String id) => id == record.classId ? record : null;
}

class _PreviewAuth extends AuthService {
  final String owner;
  _PreviewAuth(this.owner);
  @override
  domain.User get currentUser => domain.User(
      userId: owner,
      email: 'synthetic@example.invalid',
      fullName: 'Preview teacher',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026));
}

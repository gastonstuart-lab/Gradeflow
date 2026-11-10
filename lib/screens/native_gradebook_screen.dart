import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:gradeflow/nav.dart';
import 'package:gradeflow/models/grade_item.dart';
import 'package:gradeflow/models/student.dart';
import 'package:gradeflow/repositories/repository_factory.dart';
import 'package:gradeflow/services/auth_service.dart';
import 'package:gradeflow/services/class_service.dart';
import 'package:gradeflow/services/gradebook_workspace.dart';
import 'package:gradeflow/services/gradebook_import_plan.dart';
import 'package:file_picker/file_picker.dart';
import 'package:gradeflow/platform/browser_file_actions.dart';

class NativeGradebookScreen extends StatefulWidget {
  static final Map<String, Future<bool> Function()> _leaveGuards = {};
  static Future<bool> canLeave(String classId) async =>
      await _leaveGuards[classId]?.call() ?? true;
  const NativeGradebookScreen({
    super.key,
    required this.classId,
    this.studentId,
    this.initialCategory,
  });
  final String classId;
  final String? studentId;
  final String? initialCategory;
  @override
  State<NativeGradebookScreen> createState() => _NativeGradebookScreenState();
}

class _NativeGradebookScreenState extends State<NativeGradebookScreen> {
  late GradebookWorkspace book;
  String? category;
  bool summary = true;
  String search = '';
  String? loadError;
  final Map<String, TextEditingController> fields = {};
  final Set<String> dirty = {};
  bool working = false;
  @override
  void initState() {
    super.initState();
    _open();
  }

  void _open() {
    if (widget.studentId == null)
      NativeGradebookScreen._leaveGuards[widget.classId] = leave;
    book = GradebookWorkspace(RepositoryFactory.instance, widget.classId);
    book.addListener(_changed);
    book.load().then((_) {
      if (mounted)
        setState(() {
          summary = widget.studentId == null;
          category = book.categories
                .where((c) =>
                    GradebookWorkspace.canonical(c.name) ==
                    widget.initialCategory)
                .firstOrNull
                ?.categoryId ??
            book.categories.firstOrNull?.categoryId;
        });
    }).catchError((Object e) {
      if (mounted) setState(() => loadError = e.toString());
    });
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant NativeGradebookScreen old) {
    super.didUpdateWidget(old);
    if (old.classId != widget.classId) {
      book.removeListener(_changed);
      book.dispose();
      for (final c in fields.values) {
        c.dispose();
      }
      fields.clear();
      dirty.clear();
      category = null;
      summary = true;
      loadError = null;
      _open();
    }
  }

  @override
  void dispose() {
    if (widget.studentId == null)
      NativeGradebookScreen._leaveGuards.remove(widget.classId);
    book.removeListener(_changed);
    book.dispose();
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  String fmt(double? n) =>
      n == null ? '—' : n.toStringAsFixed(2).replaceFirst(RegExp(r'\.00$'), '');
  void message(String s) {
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  Future<bool> leave() async {
    if (working || book.saveState == GradebookSaveState.saving) {
      message('Wait for the current save to finish.');
      return false;
    }
    if (dirty.isEmpty) return true;
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Keep your unfinished scores?'),
            content: const Text(
              'Some entries have not been saved. Stay to save or correct them, or discard those unfinished entries.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Stay'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Discard unfinished entries'),
              ),
            ],
          ),
        ) ??
        false;
  }

  TextEditingController controller(String key, double? value) =>
      fields.putIfAbsent(
        key,
        () => TextEditingController(text: value == null ? '' : fmt(value)),
      );
  double? parse(String text, double maximum) {
    if (text.trim().isEmpty) return null;
    final n = double.tryParse(text.trim());
    if (n == null || !n.isFinite || n < 0 || n > maximum)
      throw FormatException(
        'Enter a score from 0 to $maximum, or leave it blank.',
      );
    return n;
  }

  Future<void> commit(Student s, GradeItem? item) async {
    final key = book.key(s.studentId, item?.gradeItemId ?? 'exam');
    if (!dirty.contains(key) || working) return;
    try {
      final n = parse(fields[key]!.text, item?.maxScore ?? 100);
      final teacher = context.read<AuthService>().currentUser?.userId;
      if (teacher == null) throw StateError('Sign in before saving scores.');
      setState(() => working = true);
      if (item == null) {
        await book.saveExam(s.studentId, n);
      } else {
        await book.saveScore(s.studentId, item, n, teacher);
      }
      dirty.remove(key);
      if (book.saveState == GradebookSaveState.historyIncomplete)
        message(book.error!);
    } catch (e) {
      message(
        'Not saved: $e. Your entry is still in the field; submit it again to retry.',
      );
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  Widget scoreField(Student s, GradeItem? item) {
    final key = book.key(s.studentId, item?.gradeItemId ?? 'exam');
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _gradeStepButton(s, item, -1),
        const SizedBox(width: 2),
        SizedBox(
          width: 68,
          child: TextField(
        key: ValueKey(key),
        controller: controller(
          key,
          item == null
              ? book.exam(s.studentId)
              : book.score(s.studentId, item.gradeItemId),
        ),
        enabled: !working,
        textAlign: TextAlign.right,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: '${s.englishFullName} ${item?.name ?? 'Exam'}',
          floatingLabelBehavior: FloatingLabelBehavior.never,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          filled: true,
          fillColor: dirty.contains(key)
              ? const Color(0xfffff1d5)
              : Theme.of(context).colorScheme.surface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onChanged: (_) => setState(() => dirty.add(key)),
        onSubmitted: (_) => commit(s, item),
        onTapOutside: (_) {
          FocusManager.instance.primaryFocus?.unfocus();
          commit(s, item);
        },
        onEditingComplete: () {
          commit(s, item);
          FocusScope.of(context).nextFocus();
        },
          ),
        ),
        const SizedBox(width: 2),
        _gradeStepButton(s, item, 1),
      ],
    );
  }

  Widget _gradeStepButton(Student student, GradeItem? item, int delta) {
    final key = book.key(student.studentId, item?.gradeItemId ?? 'exam');
    return SizedBox(
      width: 26,
      height: 32,
      child: IconButton(
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints(minWidth: 26, minHeight: 32),
        tooltip: delta > 0 ? 'Increase score by 1' : 'Decrease score by 1',
        onPressed: working || dirty.contains(key)
            ? null
            : () async {
                final field = controller(
                  key,
                  item == null
                      ? book.exam(student.studentId)
                      : book.score(student.studentId, item.gradeItemId),
                );
                final value = double.tryParse(field.text.trim()) ?? 0;
                final next = (value + delta).clamp(0, item?.maxScore ?? 100);
                if (next == value && field.text.trim().isNotEmpty) return;
                field.text = fmt(next.toDouble());
                setState(() => dirty.add(key));
                await commit(student, item);
              },
        icon: Icon(delta > 0 ? Icons.add : Icons.remove, size: 16),
      ),
    );
  }

  Future<void> editOverallWeights() async {
    if (working || dirty.isNotEmpty) {
      message('Save unfinished scores before changing grading weights.');
      return;
    }
    final input = TextEditingController(text: fmt(book.courseworkWeightPercent));
    final chosen = await showDialog<double>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, refresh) {
          final percent = double.tryParse(input.text.trim());
          final valid = percent != null &&
              percent.isFinite && percent >= 0 && percent <= 100;
          final coursework = valid ? percent : 40.0;
          return AlertDialog(
            title: const Text('Overall grade weighting'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Coursework (GPA) and exam must total 100%. '
                      'This changes calculated final grades but does not edit saved student scores.'),
                  const SizedBox(height: 14),
                  TextField(
                    controller: input,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Coursework / GPA percentage',
                      suffixText: '%',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => refresh(() {}),
                  ),
                  const SizedBox(height: 10),
                  Text('Exam percentage: ${valid ? fmt(100 - coursework) : '—'}%'),
                  const SizedBox(height: 10),
                  if (valid)
                    Text('Example: coursework 90 and exam 70 → final '
                         '${fmt(90 * coursework / 100 + 70 * (100 - coursework) / 100)}'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: valid ? () => Navigator.pop(ctx, percent) : null,
                child: const Text('Apply to this class'),
              ),
            ],
          );
        },
      ),
    );
    input.dispose();
    if (chosen == null || !mounted) return;
    setState(() => working = true);
    try {
      await book.setCourseworkWeightPercent(chosen);
      message('Class weights saved. Student scores were not changed.');
    } catch (e) {
      message('Weights not changed: $e');
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  Future<void> addAssessment() async {
    if (category == null) return;
    final name = TextEditingController(),
        max = TextEditingController(text: '100');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add assessment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Assessment name'),
            ),
            TextField(
              controller: max,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Maximum score'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await book.addAssessment(
          category!,
          name.text,
          double.tryParse(max.text) ?? 0,
        );
      } catch (e) {
        message('Assessment not saved: $e');
      }
    }
  }

  List<Student> get visible => book.students
      .where(
        (s) =>
            (widget.studentId == null || s.studentId == widget.studentId) &&
            ('${s.englishFullName} ${s.chineseName} ${s.studentId} ${s.seatNo}'
                .toLowerCase()
                .contains(search.toLowerCase())),
      )
      .toList();
  Future<void> importBackup() async {
    if (dirty.isNotEmpty) {
      message('Save unfinished entries before importing.');
      return;
    }
    try {
      final picked = await FilePicker.platform.pickFiles(
          type: FileType.custom, allowedExtensions: ['json'], withData: true);
      if (picked == null || !mounted) return;
      final bytes = picked.files.single.bytes;
      if (bytes == null || bytes.length > 5000000)
        throw const FormatException(
            'Choose a gradebook JSON backup under 5 MB.');
      final data = jsonDecode(utf8.decode(bytes));
      if (data is! Map || data['version'] != 1 || data['classes'] is! List)
        throw const FormatException(
            'This is not a supported standalone gradebook backup.');
      final sources = (data['classes'] as List)
          .whereType<Map>()
          .where((c) =>
              c['sheet'] is String && c['scores'] is Map && c['columns'] is Map)
          .toList();
      if (sources.isEmpty)
        throw const FormatException(
            'This file contains no standalone gradebook class records.');
      var selection = 0;
      var replace = false;
      final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => StatefulBuilder(
              builder: (ctx, update) => AlertDialog(
                      title: const Text('Import scores into this class'),
                      content: SizedBox(
                          width: 480,
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                            Text(
                                'Destination: ${context.read<ClassService>().getClassById(widget.classId)?.className ?? widget.classId}'),
                            DropdownButtonFormField<int>(
                                initialValue: 0,
                                decoration: const InputDecoration(
                                    labelText: 'Source class in backup'),
                                items: [
                                  for (var i = 0; i < sources.length; i++)
                                    DropdownMenuItem(
                                        value: i,
                                        child:
                                            Text(sources[i]['sheet'] as String))
                                ],
                                onChanged: (v) => selection = v!),
                            const SizedBox(height: 12),
                            const Text(
                                'Every student ID must belong to this class. Missing source scores do not erase existing marks. Assessment names are matched within their category. This applies the confirmed 20/30/30/20 GPA weights.'),
                            CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                value: replace,
                                onChanged: (v) => update(() => replace = v!),
                                title: const Text(
                                    'Replace conflicting existing scores'))
                          ])),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel')),
                        FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Validate and import'))
                      ])));
      if (confirmed != true || !mounted) return;
      final plan = GradebookImportPlan.parse(
          Map<String, dynamic>.from(sources[selection]),
          book.students.map((s) => s.studentId).toSet());
      if (book.categories.isNotEmpty &&
          (book.categories.length != 4 ||
              !GradebookWorkspace.processWeights.keys.every((k) =>
                  book.categories
                      .where((c) => GradebookWorkspace.canonical(c.name) == k)
                      .length ==
                  1)))
        throw const FormatException(
            'Existing categories need review before importing.');
      // Validate the entire plan and every conflict before any policy/item/score writes.
      for (final k in plan.columns.keys) {
        final cat = book.categories
            .where((c) => GradebookWorkspace.canonical(c.name) == k)
            .firstOrNull;
        for (var j = 0; j < plan.columns[k]!.length; j++) {
          final matches = cat == null
              ? <GradeItem>[]
              : book
                  .categoryItems(cat.categoryId)
                  .where((i) => i.name == plan.columns[k]![j])
                  .toList();
          if (matches.length > 1 || matches.any((i) => i.maxScore != 100))
            throw const FormatException(
                'An assessment name or maximum score conflicts. Nothing imported.');
          if (!replace && matches.isNotEmpty) {
            for (final id in plan.scores.keys) {
              final old = book.score(id, matches.single.gradeItemId),
                  v = plan.scores[id]![k]![j];
              if (old != null && v != null && old != v)
                throw const FormatException(
                    'Existing scores conflict. Review the source or explicitly choose replacement.');
            }
          }
        }
      }
      if (!replace &&
          plan.exams.entries.any((e) =>
              e.value != null &&
              book.exam(e.key) != null &&
              e.value != book.exam(e.key)))
        throw const FormatException(
            'Existing exam scores conflict. Nothing imported.');
      final teacher = context.read<AuthService>().currentUser?.userId;
      if (teacher == null) throw StateError('Sign in before importing.');
      setState(() => working = true);
      await book.setUpCategories();
      var historyFailures = 0;
      for (final k in plan.columns.keys) {
        final cat = book.categories
            .singleWhere((c) => GradebookWorkspace.canonical(c.name) == k);
        for (var j = 0; j < plan.columns[k]!.length; j++) {
          final name = plan.columns[k]![j];
          if (!book.categoryItems(cat.categoryId).any((i) => i.name == name))
            await book.addAssessment(cat.categoryId, name, 100);
          final item = book
              .categoryItems(cat.categoryId)
              .singleWhere((i) => i.name == name);
          for (final id in plan.scores.keys) {
            final v = plan.scores[id]![k]![j];
            if (v != null) {
              await book.saveScore(id, item, v, teacher);
              if (book.saveState == GradebookSaveState.historyIncomplete)
                historyFailures++;
            }
          }
        }
      }
      for (final e in plan.exams.entries) {
        if (e.value != null) await book.saveExam(e.key, e.value);
      }
      for (final f in fields.values) {
        f.dispose();
      }
      fields.clear();
      category = book.categories.first.categoryId;
      message(
          '${plan.entered} supplied scores imported.${historyFailures > 0 ? ' $historyFailures history entries need review.' : ''}');
    } catch (e) {
      message(
          'Import stopped: $e. Keep your source backup; completed records can be matched on retry.');
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  Future<void> paste() async {
    final items = book.categoryItems(category!);
    if (items.isEmpty) return;
    final input = TextEditingController();
    String startStudent = visible.first.studentId,
        startItem = items.first.gradeItemId;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Paste assessment scores'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Paste numbers only, in the displayed student order. Tabs separate assessment columns. Existing cells in this block will be replaced; blanks clear a score.',
                ),
                DropdownButtonFormField<String>(
                  initialValue: startStudent,
                  decoration: const InputDecoration(labelText: 'First student'),
                  items: visible
                      .map(
                        (s) => DropdownMenuItem(
                          value: s.studentId,
                          child: Text(s.englishFullName),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => startStudent = v!,
                ),
                DropdownButtonFormField<String>(
                  initialValue: startItem,
                  decoration: const InputDecoration(
                    labelText: 'First assessment',
                  ),
                  items: items
                      .map(
                        (i) => DropdownMenuItem(
                          value: i.gradeItemId,
                          child: Text(i.name),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => startItem = v!,
                ),
                TextField(
                  controller: input,
                  minLines: 5,
                  maxLines: 10,
                  decoration: const InputDecoration(
                    labelText: 'Scores from Excel',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Validate and enter'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final rows = input.text
          .replaceAll('\r\n', '\n')
          .replaceAll('\r', '\n')
          .replaceFirst(RegExp(r'\n+$'), '')
          .split('\n')
          .map((s) => s.split('\t'))
          .toList();
      final students = visible;
      final r0 = students.indexWhere((s) => s.studentId == startStudent),
          c0 = items.indexWhere((i) => i.gradeItemId == startItem);
      if (r0 + rows.length > students.length ||
          rows.any((r) => c0 + r.length > items.length))
        throw const FormatException(
          'The block extends past the displayed students or assessments.',
        );
      final edits = <(Student, GradeItem, double?)>[];
      for (var r = 0; r < rows.length; r++) {
        for (var c = 0; c < rows[r].length; c++) {
          edits.add((
            students[r0 + r],
            items[c0 + c],
            parse(rows[r][c], items[c0 + c].maxScore),
          ));
        }
      }
      final teacher = context.read<AuthService>().currentUser?.userId;
      if (teacher == null) throw StateError('Sign in before saving.');
      // Stage every field first. If one save fails, all unconfirmed values remain recoverable.
      for (final (s, i, v) in edits) {
        final k = book.key(s.studentId, i.gradeItemId);
        controller(k, null).text = v == null ? '' : fmt(v);
        dirty.add(k);
      }
      setState(() => working = true);
      var done = 0;
      var historyFailures = 0;
      for (final (s, i, v) in edits) {
        await book.saveScore(s.studentId, i, v, teacher);
        if (book.saveState == GradebookSaveState.historyIncomplete)
          historyFailures++;
        dirty.remove(book.key(s.studentId, i.gradeItemId));
        done++;
      }
      message(
        '$done scores saved.${historyFailures > 0 ? ' History is incomplete for $historyFailures scores.' : ''}',
      );
    } catch (e) {
      message('Paste stopped: $e. Unsaved entries remain visible for retry.');
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  Future<void> backup() async {
    if (dirty.isNotEmpty) {
      message('Save or correct unfinished entries before exporting.');
      return;
    }
    try {
      final repo = book.repository,
          classes = await repo.loadClasses(),
          output = <Map<String, dynamic>>[];
      for (final c in classes.where((c) => !c.isArchived)) {
        final w = GradebookWorkspace(repo, c.classId);
        await w.load();
        output.add({
          'class': c.toJson(),
          'students': w.students.map((s) => s.toJson()).toList(),
          'categories': w.categories.map((c) => c.toJson()).toList(),
          'items': w.items.map((i) => i.toJson()).toList(),
          'scores': w.values,
          'exams': w.exams.map((e) => e.toJson()).toList(),
        });
        w.dispose();
      }
      if (!await downloadBrowserText(
        jsonEncode({
          'version': 1,
          'format': 'instructos-gradebook',
          'classes': output,
        }),
        'InstructOS-gradebook-backup.json',
        'application/json',
      )) throw StateError('Download is unavailable on this platform.');
      message('Backup downloaded.');
    } catch (e) {
      message('Backup failed: $e');
    }
  }

  Future<void> export() async {
    if (dirty.isNotEmpty) {
      message('Save or correct unfinished entries before exporting.');
      return;
    }
    try {
      final excel = Excel.createExcel(), sheet = excel['All Classes'];
      excel.delete('Sheet1');
      final headers = [
        'Class',
        'Subject',
        'School Year',
        'Term',
        'Student ID',
        'Chinese Name',
        'English Name',
        'Homework',
        'Quiz',
        'Classwork',
        'Participation',
        'Process Score (40%)',
        'Exam Score (60%)',
        'Final Grade',
      ];
      sheet.appendRow(headers.map(TextCellValue.new).toList());
      final classes = await book.repository.loadClasses();
      for (final c in classes.where((c) => !c.isArchived)) {
        final w = GradebookWorkspace(book.repository, c.classId);
        await w.load();
        for (final s in w.students) {
          double? avg(String name) {
            final cats = w.categories
                .where((c) => GradebookWorkspace.canonical(c.name) == name)
                .toList();
            return cats.length == 1
                ? w.average(s.studentId, cats.single.categoryId)
                : null;
          }

          CellValue? number(double? v) => v == null ? null : DoubleCellValue(v);
          final n = sheet.maxRows + 1;
          sheet.appendRow([
            TextCellValue(c.className),
            TextCellValue(c.subject),
            TextCellValue(c.schoolYear),
            TextCellValue(c.term),
            TextCellValue(s.studentId),
            TextCellValue(s.chineseName),
            TextCellValue(s.englishFullName),
            ...[
              'Homework',
              'Quizzes',
              'Classwork',
              'Participation',
            ].map((k) => number(avg(k))),
            w.process(s.studentId) == null
                ? null
                : FormulaCellValue(
                    'IF(COUNT(H$n:K$n)=4,H$n*0.3+I$n*0.3+J$n*0.2+K$n*0.2,"")',
                  ),
            number(w.exam(s.studentId)),
            FormulaCellValue('IF(COUNT(L$n:M$n)=2,L$n*0.4+M$n*0.6,"")'),
          ]);
        }
        w.dispose();
      }
      final detail = excel['Assessments'];
      detail.appendRow(
        [
          'Class ID',
          'Student ID',
          'Student',
          'Category',
          'Assessment',
          'Maximum',
          'Score',
        ].map(TextCellValue.new).toList(),
      );
      for (final c in classes.where((c) => !c.isArchived)) {
        final w = GradebookWorkspace(book.repository, c.classId);
        await w.load();
        for (final s in w.students) {
          for (final i in w.items) {
            final v = w.score(s.studentId, i.gradeItemId);
            detail.appendRow([
              TextCellValue(c.classId),
              TextCellValue(s.studentId),
              TextCellValue(s.englishFullName),
              TextCellValue(
                w.categories
                        .where((c) => c.categoryId == i.categoryId)
                        .firstOrNull
                        ?.name ??
                    '',
              ),
              TextCellValue(i.name),
              DoubleCellValue(i.maxScore),
              v == null ? null : DoubleCellValue(v),
            ]);
          }
        }
        w.dispose();
      }
      final bytes = excel.encode();
      if (bytes == null ||
          !await downloadBrowserBytes(
            Uint8List.fromList(bytes),
            'grades_all_classes.xlsx',
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          )) throw StateError('Download unavailable.');
      message('Excel downloaded. Missing scores remain blank.');
    } catch (e) {
      message('Export failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), dark = theme.brightness == Brightness.dark;
    final item = context.watch<ClassService>().getClassById(widget.classId);
    final rows = visible,
        assessments =
            category == null ? <GradeItem>[] : book.categoryItems(category!);
    final status = working
        ? 'Saving…'
        : dirty.isNotEmpty
            ? 'Unfinished entries'
            : switch (book.saveState) {
                GradebookSaveState.ready => 'Ready',
                GradebookSaveState.saving => 'Saving…',
                GradebookSaveState.saved => 'Saved',
                GradebookSaveState.failed => 'Save failed — retry your entry',
                GradebookSaveState.historyIncomplete =>
                  'Score saved — history incomplete',
              };
    return Theme(
        data: theme,
        child: PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) async {
            if (!didPop && await leave() && context.mounted) {
              if (widget.studentId != null) {
                Navigator.pop(context);
              } else {
                context.go(AppRoutes.osClassroom(widget.classId));
              }
            }
          },
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: dark
                      ? const [Color(0xff07131f), Color(0xff0c1d29)]
                      : const [
                          Color(0xffe5eff9),
                          Color(0xfff6f9fc),
                          Color(0xffeaf5f3),
                        ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1380),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 16,
                            runSpacing: 12,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: widget.studentId == null
                                        ? 'Back to Classroom'
                                        : 'Close',
                                    onPressed: () async {
                                      if (await leave() && context.mounted) {
                                        if (widget.studentId != null) {
                                          Navigator.pop(context);
                                        } else {
                                          context.go(
                                            AppRoutes.osClassroom(
                                                widget.classId),
                                          );
                                        }
                                      }
                                    },
                                    icon: const Icon(Icons.arrow_back),
                                  ),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.studentId == null
                                            ? 'Gradebook'
                                            : 'Quick score',
                                        style: theme.textTheme.headlineSmall
                                            ?.copyWith(
                                                fontWeight: FontWeight.w800),
                                      ),
                                      Text(
                                        item?.className ?? 'Class',
                                        style: theme.textTheme.bodyMedium,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Wrap(
                                spacing: 8,
                                children: [
                                  if (widget.studentId != null)
                                    FilledButton.tonal(
                                      onPressed: () async {
                                        if (await leave() && context.mounted) {
                                          Navigator.pop(context);
                                          context.go(
                                            AppRoutes.osClassGradebook(
                                              widget.classId,
                                            ),
                                          );
                                        }
                                      },
                                      child: const Text('Open full gradebook'),
                                    ),
                                  if (widget.studentId == null) ...[
                                    OutlinedButton.icon(
                                        onPressed:
                                            working ? null : importBackup,
                                        icon: const Icon(Icons.upload_file),
                                        label: const Text('Import scores')),
                                    OutlinedButton.icon(
                                      onPressed: working ? null : backup,
                                      icon: const Icon(Icons.backup_outlined),
                                      label: const Text('Backup'),
                                    ),
                                    FilledButton.icon(
                                      onPressed: working ? null : export,
                                      icon: const Icon(Icons.download),
                                      label: const Text('Export Excel'),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xff133c67), Color(0xff14817b)],
                              ),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Wrap(
                              spacing: 24,
                              runSpacing: 10,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  '${book.students.length} students',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  status,
                                  style: const TextStyle(color: Colors.white),
                                ),
                                Text(
                                  'GPA ${fmt(book.courseworkWeightPercent)}% + Exam ${fmt(100 - book.courseworkWeightPercent)}%',
                                  style: const TextStyle(color: Colors.white),
                                ),
                                const Text(
                                  'Participation 20% · Homework 30% · Quizzes 30% · Classwork 20%',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (loadError != null)
                            Text('Could not load grades: $loadError'),
                          if (!book.loaded && loadError == null)
                            const LinearProgressIndicator(),
                          if (book.loaded)
                            Expanded(
                              child: Card(
                                margin: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        children: [
                                          ...book.categories.map(
                                            (c) => ChoiceChip(
                                              label: Text(c.name),
                                              selected: !summary &&
                                                  category == c.categoryId,
                                              onSelected: working
                                                  ? null
                                                  : (_) => setState(() {
                                                        summary = false;
                                                        category = c.categoryId;
                                                      }),
                                            ),
                                          ),
                                          TextButton.icon(
                                              onPressed: working ||
                                                      dirty.isNotEmpty ||
                                                      !book.canUndo
                                                  ? null
                                                  : () async {
                                                      setState(
                                                          () => working = true);
                                                      try {
                                                        await book
                                                            .undoLastEdit();
                                                        for (final f
                                                            in fields.values) {
                                                          f.dispose();
                                                        }
                                                        fields.clear();
                                                      } catch (e) {
                                                        message(
                                                            'Undo failed: $e');
                                                      } finally {
                                                        if (mounted)
                                                          setState(() =>
                                                              working = false);
                                                      }
                                                    },
                                              icon: const Icon(Icons.undo),
                                              label:
                                                  const Text('Undo last edit')),
                                          if (widget.studentId == null)
                                            OutlinedButton.icon(
                                              onPressed: working || dirty.isNotEmpty
                                                  ? null
                                                  : editOverallWeights,
                                              icon: const Icon(Icons.pie_chart_outline, size: 18),
                                              label: const Text('GPA / Exam split'),
                                            ),
                                          if (widget.studentId == null)
                                            OutlinedButton.icon(
                                              onPressed: working || dirty.isNotEmpty
                                                  ? null
                                                  : () async {
                                                      await context.push<void>(
                                                        AppRoutes.osClassCategories(widget.classId),
                                                      );
                                                      if (!mounted) return;
                                                      try {
                                                        await book.load();
                                                        if (mounted) setState(() {});
                                                      } catch (e) {
                                                        message('Could not reload weights: $e');
                                                      }
                                                    },
                                              icon: const Icon(Icons.tune, size: 18),
                                              label: const Text('Edit category weights'),
                                            ),
                                          ChoiceChip(
                                            label: const Text('Summary'),
                                            selected: summary,
                                            onSelected: working
                                                ? null
                                                : (_) => setState(
                                                      () => summary = true,
                                                    ),
                                          ),
                                          if (!summary && category != null)
                                            OutlinedButton.icon(
                                              onPressed: working
                                                  ? null
                                                  : addAssessment,
                                              icon: const Icon(Icons.add),
                                              label:
                                                  const Text('Add assessment'),
                                            ),
                                          if (!summary &&
                                              assessments.isNotEmpty &&
                                              rows.isNotEmpty)
                                            TextButton.icon(
                                              onPressed:
                                                  working || dirty.isNotEmpty
                                                      ? null
                                                      : paste,
                                              icon: const Icon(
                                                  Icons.content_paste),
                                              label: const Text('Paste scores'),
                                            ),
                                          if (dirty.isNotEmpty)
                                            TextButton(
                                              onPressed: working
                                                  ? null
                                                  : () async {
                                                      for (final s
                                                          in book.students) {
                                                        for (final i
                                                            in book.items) {
                                                          await commit(s, i);
                                                        }
                                                        await commit(s, null);
                                                      }
                                                    },
                                              child: const Text(
                                                'Save unfinished entries',
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        'Enter scores, then press Enter or click outside to save. Blank means missing; zero counts as zero.',
                                        style: theme.textTheme.bodySmall,
                                      ),
                                      if (!book.policyMatches)
                                        TextButton(
                                          onPressed: working
                                              ? null
                                              : () async {
                                                  final ok = await showDialog<
                                                          bool>(
                                                      context: context,
                                                      builder: (ctx) =>
                                                          AlertDialog(
                                                              title: const Text(
                                                                  'Use the confirmed syllabus weights?'),
                                                              content: const Text(
                                                                  'Apply Participation 20%, Homework 30%, Quizzes 30%, Classwork 20% within GPA. Existing assessment scores remain unchanged.'),
                                                              actions: [
                                                                TextButton(
                                                                    onPressed: () =>
                                                                        Navigator.pop(
                                                                            ctx,
                                                                            false),
                                                                    child: const Text(
                                                                        'Cancel')),
                                                                FilledButton(
                                                                    onPressed: () =>
                                                                        Navigator.pop(
                                                                            ctx,
                                                                            true),
                                                                    child: const Text(
                                                                        'Apply weights'))
                                                              ]));
                                                  if (ok != true) return;
                                                  try {
                                                    await book
                                                        .setUpCategories();
                                                    if (mounted)
                                                      setState(
                                                        () => category = book
                                                            .categories
                                                            .first
                                                            .categoryId,
                                                      );
                                                  } catch (e) {
                                                    message('$e');
                                                  }
                                                },
                                          child: const Text(
                                            'Apply confirmed GPA weights: 20% / 30% / 30% / 20%',
                                          ),
                                        ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        child: TextField(
                                          decoration: const InputDecoration(
                                            prefixIcon: Icon(Icons.search),
                                            labelText: 'Find student',
                                            isDense: true,
                                            border: OutlineInputBorder(),
                                          ),
                                          onChanged: (v) =>
                                              setState(() => search = v),
                                        ),
                                      ),
                                      Expanded(
                                        child: SingleChildScrollView(
                                          child: SingleChildScrollView(
                                            scrollDirection: Axis.horizontal,
                                            child: ConstrainedBox(
                                              constraints: BoxConstraints(
                                                minWidth: (MediaQuery.sizeOf(context).width - 96)
                                                    .clamp(0, 1320).toDouble(),
                                              ),
                                              child: DataTable(
                                                dataRowMinHeight: 50,
                                                dataRowMaxHeight: 50,
                                                columnSpacing: 14,
                                              headingRowColor:
                                                  WidgetStatePropertyAll(
                                                theme.colorScheme.primary
                                                    .withValues(alpha: .07),
                                              ),
                                              columns: [
                                                const DataColumn(
                                                  label: Text('Student'),
                                                ),
                                                const DataColumn(
                                                  label: Text('Class / Seat'),
                                                ),
                                                if (summary) ...[
                                                  ...GradebookWorkspace
                                                      .processWeights.keys
                                                      .map(
                                                    (k) => DataColumn(
                                                      label: Text(k),
                                                    ),
                                                  ),
                                                  const DataColumn(
                                                    label: Text('GPA'),
                                                  ),
                                                  const DataColumn(
                                                    label: Text('Exam'),
                                                  ),
                                                  const DataColumn(
                                                    label: Text('Final'),
                                                  ),
                                                ] else ...[
                                                  ...assessments.map(
                                                    (i) => DataColumn(
                                                      label: Column(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(i.name),
                                                          Text(
                                                            'out of ${fmt(i.maxScore)}',
                                                            style: theme
                                                                .textTheme
                                                                .bodySmall,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                  const DataColumn(
                                                    label: Text('Average'),
                                                  ),
                                                ],
                                              ],
                                              rows: rows
                                                  .map(
                                                    (s) => DataRow(
                                                      cells: [
                                                        DataCell(
                                                          Column(
                                                            mainAxisAlignment:
                                                                MainAxisAlignment
                                                                    .center,
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              Text(
                                                                s.englishFullName,
                                                                style:
                                                                    const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                ),
                                                              ),
                                                              Text(
                                                                '${s.chineseName} · ${s.studentId}',
                                                                style: theme
                                                                    .textTheme
                                                                    .bodySmall,
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        DataCell(
                                                          Text(
                                                            '${s.classCode ?? ''} / ${s.seatNo ?? ''}',
                                                          ),
                                                        ),
                                                        if (summary) ...[
                                                          ...GradebookWorkspace
                                                              .processWeights
                                                              .keys
                                                              .map((k) {
                                                            final cats =
                                                                book.categories
                                                                    .where(
                                                                      (c) =>
                                                                          GradebookWorkspace
                                                                              .canonical(
                                                                            c.name,
                                                                          ) ==
                                                                          k,
                                                                    )
                                                                    .toList();
                                                            return DataCell(
                                                              Text(
                                                                fmt(
                                                                  cats.length ==
                                                                          1
                                                                      ? book
                                                                          .average(
                                                                          s.studentId,
                                                                          cats.single
                                                                              .categoryId,
                                                                        )
                                                                      : null,
                                                                ),
                                                              ),
                                                            );
                                                          }),
                                                          DataCell(
                                                            Text(
                                                              fmt(
                                                                book.process(
                                                                  s.studentId,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                          DataCell(
                                                            scoreField(s, null),
                                                          ),
                                                          DataCell(
                                                            Text(
                                                              fmt(
                                                                book.finalGrade(
                                                                  s.studentId,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ] else ...[
                                                          ...assessments.map(
                                                            (i) => DataCell(
                                                              scoreField(s, i),
                                                            ),
                                                          ),
                                                          DataCell(
                                                            Text(
                                                              fmt(
                                                                category == null
                                                                    ? null
                                                                    : book
                                                                        .average(
                                                                        s.studentId,
                                                                        category!,
                                                                      ),
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ],
                                                    ),
                                                  )
                                                  .toList(),
                                            ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        '${rows.length} students shown · Category averages require all assessment scores. Final grades require all four categories and an exam.',
                                        style: theme.textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ));
  }
}

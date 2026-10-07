import 'package:flutter/material.dart';
import 'package:gradeflow/models/grade_item.dart';
import 'package:gradeflow/models/grading_category.dart';
import 'package:gradeflow/models/student_score.dart';
import 'package:gradeflow/services/calculation_service.dart';

/// In-memory assessment fixture. Uses the existing engine without writing scores.
class PreviewQuizBook extends ChangeNotifier {
  final _engine = CalculationService();
  final List<GradeItem> items = [];
  final Map<String, Map<String, String>> _drafts = {};
  late String selectedId;

  PreviewQuizBook() {
    add('Food webs quiz', 20);
    add('Ecosystems exit quiz', 10);
    selectedId = items.first.gradeItemId;
  }

  GradeItem get selected =>
      items.firstWhere((item) => item.gradeItemId == selectedId);
  String get maximumLabel =>
      selected.maxScore == selected.maxScore.truncateToDouble()
          ? selected.maxScore.toStringAsFixed(0)
          : selected.maxScore.toString();
  void add(String name, double maximum) {
    if (name.trim().isEmpty || !maximum.isFinite || maximum <= 0) {
      throw ArgumentError('A quiz needs a name and a positive maximum.');
    }
    final now = DateTime.now();
    selectedId = 'preview-quiz-${items.length + 1}';
    items.add(GradeItem(
        gradeItemId: selectedId,
        classId: 'preview-class',
        categoryId: 'preview-quizzes',
        name: name.trim(),
        maxScore: maximum,
        isActive: true,
        createdAt: now,
        updatedAt: now));
    notifyListeners();
  }

  void select(String id) {
    selectedId = id;
    notifyListeners();
  }

  String text(String student) => _drafts[selectedId]?[student] ?? '';
  void enter(String student, String text) {
    (_drafts[selectedId] ??= {})[student] = text;
    notifyListeners();
  }

  double? mark(String student) {
    final value = double.tryParse(text(student).trim());
    return value != null &&
            value.isFinite &&
            value >= 0 &&
            value <= selected.maxScore
        ? value
        : null;
  }

  String? error(String student) =>
      text(student).trim().isEmpty || mark(student) != null
          ? null
          : 'Enter 0–${maximumLabel}';

  double? percentage(String student) {
    final value = mark(student);
    // Blank/invalid drafts are not submitted to the engine as missing score rows.
    if (value == null) return null;
    final now = DateTime.now();
    return _engine.calculateCategoryScore(
      GradingCategory(
          categoryId: 'preview-quizzes',
          classId: 'preview-class',
          name: 'Quizzes',
          weightPercent: 100,
          aggregationMethod: AggregationMethod.average,
          isActive: true,
          createdAt: now,
          updatedAt: now),
      [selected],
      [
        StudentScore(
            studentId: student,
            gradeItemId: selectedId,
            score: value,
            createdAt: now,
            updatedAt: now)
      ],
    );
  }

  int entered(Iterable<String> students) =>
      students.where((id) => mark(id) != null).length;
}

class PreviewQuizPanel extends StatefulWidget {
  final PreviewQuizBook book;
  final Map<String, String> students;
  const PreviewQuizPanel(
      {super.key, required this.book, required this.students});
  @override
  State<PreviewQuizPanel> createState() => _PreviewQuizPanelState();
}

class _PreviewQuizPanelState extends State<PreviewQuizPanel> {
  final _controllers = <String, TextEditingController>{};
  final _focus = <String, FocusNode>{};

  @override
  void initState() {
    super.initState();
    for (final id in widget.students.keys) {
      _controllers[id] = TextEditingController(text: widget.book.text(id));
      _focus[id] = FocusNode();
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    for (final node in _focus.values) {
      node.dispose();
    }
    super.dispose();
  }

  void _sync() {
    for (final id in widget.students.keys) {
      _controllers[id]!.text = widget.book.text(id);
    }
    setState(() {});
  }

  Future<void> _create() async {
    final title = TextEditingController();
    final max = TextEditingController(text: '20');
    String? error;
    final result = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
              builder: (context, refresh) => AlertDialog(
                title: const Text('New demo quiz'),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(
                      controller: title,
                      decoration:
                          const InputDecoration(labelText: 'Quiz name')),
                  TextField(
                      controller: max,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration:
                          const InputDecoration(labelText: 'Maximum marks')),
                  if (error != null)
                    Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(error!,
                            style: const TextStyle(color: Colors.red))),
                ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () {
                        final value = double.tryParse(max.text);
                        if (title.text.trim().isEmpty ||
                            value == null ||
                            !value.isFinite ||
                            value <= 0) {
                          refresh(() =>
                              error = 'Enter a name and a positive maximum.');
                          return;
                        }
                        widget.book.add(title.text, value);
                        Navigator.pop(dialogContext, true);
                      },
                      child: const Text('Create quiz'))
                ],
              ),
            ));
    // Wait until the dialog route has released its fields before disposing.
    if (result == true && mounted) _sync();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    title.dispose();
    max.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: widget.book,
      builder: (context, _) {
        final book = widget.book;
        final ids = widget.students.keys.toList();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Quiz scores',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600)),
          const SizedBox(height: 18),
          DropdownButtonFormField<String>(
            key: ValueKey(book.selectedId),
            initialValue: book.selectedId,
            isExpanded: true,
            decoration: const InputDecoration(
                labelText: 'Assessment', border: OutlineInputBorder()),
            items: book.items
                .map((item) => DropdownMenuItem(
                    value: item.gradeItemId,
                    child: Text(item.name, overflow: TextOverflow.ellipsis)))
                .toList(),
            onChanged: (id) {
              if (id != null) {
                book.select(id);
                _sync();
              }
            },
          ),
          TextButton.icon(
              onPressed: _create,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('New demo quiz')),
          Text(
              'Out of ${book.maximumLabel} · ${book.entered(ids)} of ${ids.length} entered'),
          const SizedBox(height: 8),
          const Text(
              'Enter moves to the next student. Blank means not entered; zero is a score.',
              style: TextStyle(
                  fontSize: 12, color: Color(0xff657975), height: 1.5)),
          const SizedBox(height: 18),
          for (var i = 0; i < ids.length; i++)
            Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(children: [
                  Expanded(
                      child: Text(widget.students[ids[i]]!,
                          style: const TextStyle(fontWeight: FontWeight.w600))),
                  SizedBox(
                      width: 110,
                      child: TextField(
                        key: ValueKey('quiz-score-${ids[i]}'),
                        controller: _controllers[ids[i]],
                        focusNode: _focus[ids[i]],
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        textInputAction: i == ids.length - 1
                            ? TextInputAction.done
                            : TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: 'Mark',
                          semanticCounterText:
                              '${widget.students[ids[i]]} score',
                          border: const OutlineInputBorder(),
                          errorText: book.error(ids[i]),
                          helperText: book.percentage(ids[i]) == null
                              ? 'Not entered'
                              : '${book.percentage(ids[i])!.toStringAsFixed(1)}%',
                        ),
                        onChanged: (value) => book.enter(ids[i], value),
                        onSubmitted: (_) {
                          if (book.error(ids[i]) == null &&
                              i < ids.length - 1) {
                            _focus[ids[i + 1]]!.requestFocus();
                          }
                        },
                      )),
                ])),
          const Text(
              'Demo marks only · Held in this preview until refresh. Percentages use GradeFlow’s calculation engine.',
              style: TextStyle(
                  fontSize: 12, color: Color(0xff657975), height: 1.5)),
        ]);
      });
}

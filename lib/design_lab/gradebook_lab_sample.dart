import 'package:flutter/material.dart';
import 'package:gradeflow/components/gradebook/gradeflow_quick_score_stepper.dart';

/// This is a demo of the proposed dense grade-entry interaction, NOT a
/// production gradebook and never linked to Firebase or student records.
class GradeFlowGradebookLabSample extends StatefulWidget {
  const GradeFlowGradebookLabSample({super.key});

  @override
  State<GradeFlowGradebookLabSample> createState() =>
      _GradeFlowGradebookLabSampleState();
}

class _GradeFlowGradebookLabSampleState
    extends State<GradeFlowGradebookLabSample> {
  static const categories = ['Homework', 'Classwork', 'Participation'];
  final List<List<double?>> _scores = List.generate(16, (index) => [
    index == 3 ? 85 : index == 7 ? 95 : 100,
    index == 3 ? 87 : index == 5 ? 90 : 100,
    index == 0 ? 97 : index == 3 ? 92 : 98,
  ]);
  int category = 0;
  bool condensed = true;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text('Quick-entry category',
              style: TextStyle(fontWeight: FontWeight.w700)),
          for (int index = 0; index < categories.length; index++)
            ChoiceChip(
              key: ValueKey('lab-category-$index'),
              label: Text(categories[index]),
              selected: category == index,
              onSelected: (_) => setState(() => category = index),
            ),
          FilterChip(
            label: const Text('Compact rows'),
            selected: condensed,
            onSelected: (value) => setState(() => condensed = value),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: scheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          Container(
            color: scheme.surfaceContainerHighest.withValues(alpha: .6),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            child: Row(children: [
              const Expanded(flex: 3, child: Text('STUDENT',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900))),
              Expanded(flex: 3, child: Text(categories[category].toUpperCase(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900))),
              const Expanded(flex: 2, child: Text('AVG.',
                  textAlign: TextAlign.end,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900))),
            ]),
          ),
          for (int row = 0; row < _scores.length; row++) ...[
            Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: 12, vertical: condensed ? 3 : 8),
              child: Row(children: [
                Expanded(flex: 3, child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Student ${(row + 1).toString().padLeft(2, '0')}',
                      style: const TextStyle(fontWeight: FontWeight.w700,
                        fontSize: 12.5)),
                    Text('Seat ${row + 1}',
                        style: TextStyle(
                          color: scheme.onSurfaceVariant, fontSize: 10.5)),
                  ],
                )),
                Expanded(flex: 3, child: Center(
                  child: GradeFlowQuickScoreStepper(
                    key: ValueKey('lab-score-row-$row'),
                    score: _scores[row][category],
                    compact: true,
                    onChanged: (score) =>
                        setState(() => _scores[row][category] = score),
                  ),
                )),
                Expanded(flex: 2, child: Text(
                  _average(_scores[row]),
                  textAlign: TextAlign.end,
                  style: const TextStyle(fontSize: 12.5,
                      fontWeight: FontWeight.w800),
                )),
              ]),
            ),
            if (row < _scores.length - 1)
              Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: .5)),
          ],
        ]),
      ),
      const SizedBox(height: 10),
      Text(
        'Demo scores only. +/- changes the local preview; tap a score to type '
        'or clear it. Nothing is saved to any class.',
        style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
      ),
    ]);
  }

  static String _average(List<double?> values) {
    final available = values.whereType<double>().toList();
    if (available.isEmpty) return '—';
    final average = available.reduce((a, b) => a + b) / available.length;
    return average.toStringAsFixed(1);
  }
}

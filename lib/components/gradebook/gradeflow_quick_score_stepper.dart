import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Candidate reusable quick grade-entry control.
///
/// This widget only emits values through [onChanged]. It does not access a
/// repository, save a grade or know student identities. It is first evaluated
/// with demo records in GradeFlow Design Lab before production integration.
class GradeFlowQuickScoreStepper extends StatelessWidget {
  const GradeFlowQuickScoreStepper({
    super.key,
    required this.score,
    required this.onChanged,
    this.maxScore = 100,
    this.step = 1,
    this.compact = true,
  }) : assert(maxScore > 0),
       assert(step > 0);

  final double? score;
  final double maxScore;
  final double step;
  final ValueChanged<double?> onChanged;
  final bool compact;

  static String format(double? score) {
    if (score == null) return '—';
    return score == score.roundToDouble()
        ? score.toInt().toString()
        : score.toStringAsFixed(1);
  }

  void _change(double direction) {
    final next = ((score ?? 0) + (step * direction)).clamp(0.0, maxScore);
    onChanged(next);
  }

  Future<void> _edit(BuildContext context) async {
    final input = TextEditingController(text: score == null ? '' : format(score));
    String? error;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit score'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Allowed range: 0 to ${format(maxScore)}'),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('quick-grade-score-input'),
              controller: input,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: InputDecoration(
                labelText: 'Score',
                border: const OutlineInputBorder(),
                errorText: error,
              ),
              onSubmitted: (_) {
                final value = double.tryParse(input.text.trim());
                if (value == null || !value.isFinite ||
                    value < 0 || value > maxScore) {
                  setDialogState(() => error = 'Enter a score from 0 to ${format(maxScore)}');
                  return;
                }
                onChanged(value);
                Navigator.of(context).pop();
              },
            ),
          ]),
          actions: [
            TextButton(
              onPressed: () {
                onChanged(null);
                Navigator.of(context).pop();
              },
              child: const Text('Clear'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final value = double.tryParse(input.text.trim());
                if (value == null || !value.isFinite ||
                    value < 0 || value > maxScore) {
                  setDialogState(() => error = 'Enter a score from 0 to ${format(maxScore)}');
                  return;
                }
                onChanged(value);
                Navigator.of(context).pop();
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
    input.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('gradeflow-quick-score-stepper'),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: scheme.surfaceContainerHighest.withValues(alpha: .5),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: .5)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _control(
          context, icon: Icons.remove_rounded,
          label: 'Decrease score', enabled: (score ?? 0) > 0,
          onPressed: () => _change(-1),
        ),
        InkWell(
          onTap: () => _edit(context),
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: compact ? 42 : 55,
            height: compact ? 35 : 39,
            child: Center(
              child: Text(
                format(score),
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: compact ? 13.5 : 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
        _control(
          context, icon: Icons.add_rounded,
          label: 'Increase score', enabled: (score ?? 0) < maxScore,
          onPressed: () => _change(1),
        ),
      ]),
    );
  }

  Widget _control(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool enabled,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      tooltip: label,
      onPressed: enabled ? onPressed : null,
      icon: Icon(icon, size: compact ? 17 : 19),
      iconSize: compact ? 17 : 19,
      constraints: BoxConstraints(
        minWidth: compact ? 30 : 38,
        minHeight: compact ? 32 : 38,
      ),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }
}

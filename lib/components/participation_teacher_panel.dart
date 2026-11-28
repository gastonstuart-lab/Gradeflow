import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/lesson_participation_ledger.dart';

/// Teacher-side controls for the isolated lesson participation prototype.
/// The caller must provide a genuinely private teacher surface; this flag
/// is not authorization. Never mount on a classroom projector or student view.
/// The callback must publish the confirmed ledger to [ledger] before returning.
/// Persistent receipt recovery, authorization and seating/gradebook integration
/// are deliberately not part of this standalone panel.
class ParticipationTeacherPanel extends StatefulWidget {
  const ParticipationTeacherPanel({
    super.key,
    required this.teacherPrivate,
    required this.ledger,
    required this.studentId,
    required this.studentLabel,
    required this.policy,
    required this.newOperationId,
    required this.clock,
    required this.onSubmit,
  });

  final bool teacherPrivate;
  final ValueListenable<LessonParticipationLedger> ledger;
  final String studentId;
  final String studentLabel;
  final BehaviourPolicy policy;
  final String Function() newOperationId;
  final DateTime Function() clock;
  final Future<void> Function(ParticipationEvent event) onSubmit;

  @override
  State<ParticipationTeacherPanel> createState() => _PanelState();
}

class _PanelState extends State<ParticipationTeacherPanel> {
  ParticipationEvent? _pending;
  bool _saving = false;
  String? _message;
  final _score = TextEditingController();
  final _reason = TextEditingController();

  bool get _locked => _saving || _pending != null;

  @override
  void dispose() {
    _score.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _send(ParticipationEvent event) async {
    if (!widget.teacherPrivate || _saving ||
        event.scope != widget.ledger.value.scope ||
        event.studentId != widget.studentId) return;
    setState(() {
      _pending = event;
      _saving = true;
      _message = 'Confirming change…';
    });
    try {
      await widget.onSubmit(event);
      if (!mounted) return;
      final confirmed = widget.ledger.value;
      if (confirmed.scope != event.scope ||
          !confirmed.events.any((e) => e.sameIntent(event))) {
        throw StateError('No matching confirmed receipt');
      }
      setState(() {
        _pending = null;
        _message = 'Change confirmed';
      });
    } catch (_) {
      if (mounted) {
        setState(() => _message =
            'Save unconfirmed. Retry the same change before recording another.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _deduct(BehaviourReason reason) {
    if (_locked) return;
    final event = ParticipationEvent.deduction(
      scope: widget.ledger.value.scope,
      operationId: widget.newOperationId(),
      studentId: widget.studentId,
      at: widget.clock(),
      reason: reason,
      policy: widget.policy,
    );
    _send(event);
  }

  void _undo(ParticipationEvent target) {
    if (_locked) return;
    _send(ParticipationEvent.undo(
      scope: widget.ledger.value.scope,
      operationId: widget.newOperationId(),
      studentId: widget.studentId,
      at: widget.clock(),
      targetOperationId: target.operationId,
    ));
  }

  void _override() {
    if (_locked) return;
    final value = int.tryParse(_score.text.trim());
    if (value == null || value < 0 || value > 100 ||
        _reason.text.trim().isEmpty) {
      setState(() => _message = 'Enter a whole score from 0 to 100 and a reason.');
      return;
    }
    _send(ParticipationEvent.overrideScore(
      scope: widget.ledger.value.scope,
      operationId: widget.newOperationId(),
      studentId: widget.studentId,
      at: widget.clock(),
      score: value,
      explanation: _reason.text,
    ));
  }

  String _description(ParticipationEvent event) => switch (event.kind) {
    ParticipationEventKind.deduction =>
      '${event.reason!.label} (−${event.points})',
    ParticipationEventKind.overrideScore =>
      'Set score to ${event.points}: ${event.note}',
    ParticipationEventKind.undo => 'Undo ${event.targetOperationId}',
  };

  @override
  Widget build(BuildContext context) {
    if (!widget.teacherPrivate) return const SizedBox.shrink();
    return ValueListenableBuilder<LessonParticipationLedger>(
      valueListenable: widget.ledger,
      builder: (context, ledger, _) {
        if (!ledger.studentIds.contains(widget.studentId)) {
          return const Text('Student not in this lesson.');
        }
        final history = ledger.historyFor(widget.studentId);
        final undone = history.where((e) => e.kind == ParticipationEventKind.undo)
            .map((e) => e.targetOperationId).toSet();
        final undoable = history.reversed.where((e) =>
            e.kind != ParticipationEventKind.undo &&
            !undone.contains(e.operationId)).firstOrNull;
        final pending = _pending;
        final canRetry = pending != null && !_saving &&
            pending.scope == ledger.scope && pending.studentId == widget.studentId;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Private teacher controls',
                  style: Theme.of(context).textTheme.titleMedium),
              const Text('Do not display on the classroom projector.'),
              const SizedBox(height: 12),
              Text(widget.studentLabel,
                  style: Theme.of(context).textTheme.titleLarge),
              Semantics(
                liveRegion: true,
                child: Text('${ledger.scoreFor(widget.studentId)} / 100',
                    key: const ValueKey('participation-score'),
                    style: Theme.of(context).textTheme.headlineMedium),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final reason in BehaviourReason.values)
                    OutlinedButton(
                      key: ValueKey('incident-${reason.name}'),
                      onPressed: _locked ? null : () => _deduct(reason),
                      child: Text('${reason.label}  −${widget.policy.points[reason]}'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _locked || undoable == null ? null : () => _undo(undoable),
                icon: const Icon(Icons.undo),
                label: const Text('Undo last change'),
              ),
              if (_message != null)
                Semantics(liveRegion: true, child: Text(_message!)),
              if (pending != null)
                FilledButton(
                  onPressed: canRetry ? () => _send(pending) : null,
                  child: const Text('Retry saving'),
                ),
              ExpansionTile(
                title: const Text('Manual correction'),
                children: [
                  TextField(
                    key: const ValueKey('correction-score'),
                    controller: _score,
                    enabled: !_locked,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Corrected score (0–100)'),
                  ),
                  TextField(
                    key: const ValueKey('correction-reason'),
                    controller: _reason,
                    enabled: !_locked,
                    decoration: const InputDecoration(labelText: 'Reason for correction'),
                  ),
                  FilledButton(
                    onPressed: _locked ? null : _override,
                    child: const Text('Save correction'),
                  ),
                ],
              ),
              ExpansionTile(
                title: Text('Private incident history (${history.length})'),
                children: [
                  if (history.isEmpty) const ListTile(title: Text('No incidents recorded')),
                  for (final event in history.reversed)
                    ListTile(
                      title: Text(_description(event)),
                      subtitle: Text('${event.at.toLocal().toIso8601String()}'
                          '${undone.contains(event.operationId) ? ' · Undone' : ''}'),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

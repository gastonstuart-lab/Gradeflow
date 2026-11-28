import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/grading_period.dart';
import '../repositories/grading_period_repository.dart';
import '../services/grading_period_service.dart';
import '../services/historical_grade_export_adapter.dart';
import '../platform/browser_file_actions.dart';

/// Isolated session review; never installed in RepositoryFactory.
/// A new period is created only in this dialog's fictional copy.
class NativePeriodReviewDialog extends StatefulWidget {
  const NativePeriodReviewDialog({super.key, required this.snapshot});
  final GradebookDataset snapshot;
  @override
  State<NativePeriodReviewDialog> createState() => _State();
}
class _State extends State<NativePeriodReviewDialog> {
  late final repository = InMemoryGradingPeriodRepository(ownerId: widget.snapshot.ownerId);
  late final service = GradingPeriodService(repository);
  final archive = HistoricalGradeExportAdapter();
  GradingPeriodBook? book;
  String? selectedId, error;
  bool busy = true;
  @override
  void initState() { super.initState(); _open(); }
  Future<void> _open() async {
    try {
      final result = await service.adoptLegacy(dataset: widget.snapshot,
          periodId: 'demo-original', label: 'Current period',
          at: DateTime.now().toUtc());
      if (mounted) setState(() {book = result; selectedId = result.activePeriodId; busy = false;});
    } catch (e) {
      if (mounted) setState(() {error = e.toString(); busy = false;});
    }
  }
  Future<void> _rollover() async {
    var label = '';
    final confirmed = await showDialog<String>(context: context,
      builder: (ctx) => AlertDialog(title: const Text('Archive current & start'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('The current fictional marks become read only. The new period starts with 20 blank assessments.'),
          TextField(autofocus: true, maxLength: 80, onChanged: (v) => label = v.trim(),
            decoration: const InputDecoration(labelText: 'New period name')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () {if (label.isNotEmpty) Navigator.pop(ctx, label);},
            child: const Text('Archive & start')),
        ]));
    if (!mounted || confirmed == null || busy || book == null) return;
    setState(() {busy = true; error = null;});
    try {
      final before = book!;
      final next = await service.rollover(classId: before.classId,
          periodId: before.activePeriodId, expectedRevision: before.revision,
          nextPeriodId: const Uuid().v4(), label: confirmed, at: DateTime.now().toUtc());
      if (mounted) setState(() {book = next; selectedId = next.activePeriodId;});
    } catch (e) {if (mounted) setState(() => error = e.toString());}
    finally {if (mounted) setState(() => busy = false);}
  }
  Future<void> _export(GradingPeriod p) async {
    setState(() {busy = true; error = null;});
    try {
      final bytes = archive.generateXlsx(p, ownerId: widget.snapshot.ownerId,
          classId: widget.snapshot.classId);
      if (!await downloadBrowserBytes(bytes, 'fictional-historical-${p.periodId}.xlsx',
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')) {
        throw StateError('Download unavailable');
      }
    } catch (e) {if (mounted) setState(() => error = e.toString());}
    finally {if (mounted) setState(() => busy = false);}
  }
  @override
  Widget build(BuildContext context) {
    final current = book;
    final p = current?.periods.where((v) => v.periodId == selectedId).firstOrNull;
    final data = p?.dataset;
    final grades = p == null ? null : archive.calculate(p);
    String fmt(double? v) => v?.toStringAsFixed(2) ?? '—';
    return Dialog(child: SizedBox(width: 1000, height: MediaQuery.sizeOf(context).height * .85,
      child: Padding(padding: const EdgeInsets.all(16), child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Expanded(child: Text('Grading periods demo', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
            IconButton(tooltip: 'Close grading periods demo', onPressed: busy ? null : () => Navigator.pop(context), icon: const Icon(Icons.close)),
          ]),
          const Text('Fictional copy only · Read-only review · Resets on closing. Your existing gradebook is unchanged.'),
          if (busy) const LinearProgressIndicator(),
          if (error != null) Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          if (current != null && p != null && data != null && grades != null) ...[
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
              SizedBox(width: 280, child: DropdownButtonFormField<String>(
                key: ValueKey(p.periodId), initialValue: p.periodId, isExpanded: true,
                decoration: const InputDecoration(labelText: 'Grading period', border: OutlineInputBorder()),
                items: [for (final period in current.periods) DropdownMenuItem(
                  value: period.periodId, child: Text('${period.label} · ${period.isSealed ? "Archived" : "Active"}', overflow: TextOverflow.ellipsis))],
                onChanged: busy ? null : (id) => setState(() => selectedId = id),
              )),
              if (!p.isSealed) FilledButton.icon(onPressed: busy ? null : _rollover, icon: const Icon(Icons.add), label: const Text('New grading period')),
              if (p.isSealed) OutlinedButton.icon(onPressed: busy ? null : () => _export(p), icon: const Icon(Icons.download), label: const Text('Export historical Excel')),
            ]),
            const SizedBox(height: 12),
            Text('${data.students.length} students · ${data.assessments.where((a) => a.isActive).length} assessments · Coursework ${fmt(data.courseworkWeightPercent)}% · ${p.isSealed ? "Archived · Read only" : "Active demo · Read only"}'),
            Expanded(child: SingleChildScrollView(child: SingleChildScrollView(scrollDirection: Axis.horizontal,
              child: DataTable(columns: [
                const DataColumn(label: Text('Student')),
                for (final c in data.categories.where((c) => c.isActive)) DataColumn(label: Text(c.name)),
                const DataColumn(label: Text('Coursework')), const DataColumn(label: Text('Exam')), const DataColumn(label: Text('Final')),
              ], rows: [
                for (final student in data.students) DataRow(cells: [
                  DataCell(Text(student.englishFullName)),
                  for (final c in data.categories.where((c) => c.isActive)) DataCell(Text(fmt(grades[student.studentId]?[c.categoryId]))),
                  for (final k in ['processScore','examScore','finalGrade']) DataCell(Text(fmt(grades[student.studentId]?[k]))),
                ])
              ])))),
          ],
        ],
      )),
    ));
  }
}

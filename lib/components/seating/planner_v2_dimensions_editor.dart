import 'package:flutter/material.dart';
import 'package:gradeflow/models/seating_layout.dart';

/// Precise, local-unit table geometry for synthetic Planner V2 Arrange Mode.
///
/// A room unit is not a centimetre. The editor keeps the furniture centre
/// whenever possible and only adjusts it to avoid clipping after a resize.
/// No seat identity, assignment or furniture type is changed by this panel.
class PlannerV2DimensionsEditor extends StatefulWidget {
  const PlannerV2DimensionsEditor({
    super.key,
    required this.table,
    required this.room,
    required this.onSave,
  });

  final SeatingTable table;
  final Size room;
  final Future<void> Function(SeatingTable proposal) onSave;

  @override
  State<PlannerV2DimensionsEditor> createState() =>
      _PlannerV2DimensionsEditorState();
}

class _PlannerV2DimensionsEditorState
    extends State<PlannerV2DimensionsEditor> {
  late final TextEditingController _width;
  late final TextEditingController _depth;
  bool _saving = false;
  bool _edited = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _width = TextEditingController(text: _number(widget.table.width));
    _depth = TextEditingController(text: _number(widget.table.height));
  }

  static String _number(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);

  @override
  void didUpdateWidget(covariant PlannerV2DimensionsEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The selected table and its current data may change after undo/redo.
    // Never silently discard edits while the user is typing.
    if (oldWidget.table.tableId != widget.table.tableId ||
        (!_edited &&
            (oldWidget.table.width != widget.table.width ||
                oldWidget.table.height != widget.table.height))) {
      _width.text = _number(widget.table.width);
      _depth.text = _number(widget.table.height);
      _edited = false;
      _error = null;
    }
  }

  @override
  void dispose() {
    _width.dispose();
    _depth.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final width = double.tryParse(_width.text.trim());
    final depth = double.tryParse(_depth.text.trim());
    if (width == null ||
        depth == null ||
        !width.isFinite ||
        !depth.isFinite ||
        width < 40 ||
        depth < 40 ||
        width > widget.room.width ||
        depth > widget.room.height) {
      setState(() {
        _error = 'Enter width and depth of at least 40, within the room '
            '(${_number(widget.room.width)} × ${_number(widget.room.height)} units).';
      });
      return;
    }
    // Resizing must not move furniture unnecessarily, but the entire table
    // must remain accessible inside the saved physical room.
    final x = widget.table.x.clamp(
        width / 2, widget.room.width - width / 2).toDouble();
    final y = widget.table.y.clamp(
        depth / 2, widget.room.height - depth / 2).toDouble();
    final proposed = widget.table.copyWith(
      x: x,
      y: y,
      width: width,
      height: depth,
    );
    if (!mounted) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(proposed);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _edited = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not save. The previous table size is still stored.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('TABLE DIMENSIONS',
              style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 5),
          Text('Layout units · not centimetres',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('planner-v2-width'),
                  controller: _width,
                  enabled: !_saving,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Width',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {
                    _edited = true;
                    _error = null;
                  }),
                  onSubmitted: (_) => _save(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  key: const ValueKey('planner-v2-depth'),
                  controller: _depth,
                  enabled: !_saving,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Depth',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {
                    _edited = true;
                    _error = null;
                  }),
                  onSubmitted: (_) => _save(),
                ),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!,
                key: const ValueKey('planner-v2-dimension-error'),
                style: TextStyle(
                    color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 9),
          FilledButton.icon(
            key: const ValueKey('planner-v2-save-dimensions'),
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.check),
            label: Text(_saving ? 'Saving…' : 'Apply dimensions'),
          ),
        ],
      ),
    );
  }
}

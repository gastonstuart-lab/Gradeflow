import 'dart:math';
import 'package:flutter/material.dart';

class PreviewRoomLayout {
  final int tables;
  final int columns;
  const PreviewRoomLayout(this.tables, this.columns);
}

/// Local layout draft. Nothing changes in the lesson until Apply is pressed.
class PreviewRoomBuilder extends StatefulWidget {
  final PreviewRoomLayout initial;
  final int students;
  const PreviewRoomBuilder(
      {super.key, required this.initial, required this.students});

  @override
  State<PreviewRoomBuilder> createState() => _PreviewRoomBuilderState();
}

class _PreviewRoomBuilderState extends State<PreviewRoomBuilder> {
  late int _tables = widget.initial.tables;
  late int _columns = widget.initial.columns;

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Build your classroom'),
        content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                    'Choose a table layout, then arrange individual students in the room.'),
                const SizedBox(height: 24),
                Text('$_tables tables · ${_tables * 4} seats',
                    style: Theme.of(context).textTheme.titleMedium),
                Slider(
                    key: const ValueKey('builder-tables'),
                    label: '$_tables tables',
                    value: _tables.toDouble(),
                    min: max(1, (widget.students / 4).ceil()).toDouble(),
                    max: 10,
                    divisions: 10 - max(1, (widget.students / 4).ceil()),
                    onChanged: (value) =>
                        setState(() => _tables = value.round())),
                const Text('Tables across'),
                const SizedBox(height: 8),
                Wrap(spacing: 8, children: [
                  for (var n = 1; n <= 3; n++)
                    ChoiceChip(
                        label: Text('$n across'),
                        selected: _columns == n,
                        onSelected: (_) => setState(() => _columns = n))
                ]),
                const SizedBox(height: 20),
                Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: const Color(0xffeff3ec),
                        borderRadius: BorderRadius.circular(20)),
                    child: Column(children: [
                      const Text('FRONT OF CLASSROOM',
                          style: TextStyle(fontSize: 10, letterSpacing: 1.5)),
                      const SizedBox(height: 16),
                      LayoutBuilder(
                          builder: (context, size) =>
                              Wrap(spacing: 8, runSpacing: 8, children: [
                                for (var i = 0; i < _tables; i++)
                                  SizedBox(
                                      width:
                                          (size.maxWidth - (_columns - 1) * 8) /
                                              _columns,
                                      child: Container(
                                          height: 48,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                              color: const Color(0xffd5e2d8),
                                              borderRadius:
                                                  BorderRadius.circular(10)),
                                          child: Text('Table ${i + 1}')))
                              ])),
                    ])),
                const SizedBox(height: 18),
                Text(
                    '${widget.students} students will be spread across the new tables. Each table has four seats. Notes, homework checks and quiz marks stay with each student.',
                    style: const TextStyle(height: 1.5)),
                const SizedBox(height: 8),
                const Text(
                    'This demo layout lasts until refresh. Smaller screens fit fewer tables across.',
                    style: TextStyle(fontSize: 12, color: Color(0xff657975))),
              ],
            ))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () =>
                  Navigator.pop(context, PreviewRoomLayout(_tables, _columns)),
              child: const Text('Apply room layout'))
        ],
      );
}

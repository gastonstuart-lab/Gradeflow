import 'package:flutter/material.dart';
import 'package:gradeflow/components/seating/seating_canvas.dart';
import 'package:gradeflow/models/seating_layout.dart';
import 'package:gradeflow/models/student.dart';

class FullScreenSeatingView extends StatelessWidget {
  final SeatingLayout layout;
  final Map<String, Student> studentsById;

  const FullScreenSeatingView({
    super.key,
    required this.layout,
    required this.studentsById,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seating chart'),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Close',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SeatingCanvas(
          layout: layout,
          studentsById: studentsById,
          designMode: false,
          interactive: false,
          presentationMode: true,
        ),
      ),
    );
  }
}

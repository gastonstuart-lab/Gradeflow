import 'package:flutter/material.dart';
import 'package:gradeflow/components/animated_page_background.dart';
import 'package:gradeflow/components/teacher_whiteboard.dart';

class TeacherWhiteboardScreen extends StatelessWidget {
  final TeacherWhiteboardController? controller;

  const TeacherWhiteboardScreen({
    super.key,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedPageBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1440),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: TeacherWhiteboardWorkspace(
                  controller: controller,
                  title: 'Teacher whiteboard',
                  showStatusChips: false,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

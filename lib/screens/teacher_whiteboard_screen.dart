import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gradeflow/components/animated_page_background.dart';
import 'package:gradeflow/components/teacher_whiteboard.dart';
import 'package:gradeflow/nav.dart';
import 'package:gradeflow/os/os_controller.dart';
import 'package:provider/provider.dart';

class TeacherWhiteboardScreen extends StatelessWidget {
  final TeacherWhiteboardController? controller;
  final bool showCloseButton;

  const TeacherWhiteboardScreen({
    super.key,
    this.controller,
    this.showCloseButton = true,
  });

  void _closeWhiteboard(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      context.pop();
      return;
    }

    final os = context.read<GradeFlowOSController>();
    switch (os.activeSurface) {
      case OSSurface.classWorkspace:
        final classId = os.activeClassId;
        if (classId != null && classId.trim().isNotEmpty) {
          context.go('${AppRoutes.osClass}/$classId');
          return;
        }
        context.go(AppRoutes.osHome);
        return;
      case OSSurface.teach:
        context.go(AppRoutes.osTeach);
        return;
      case OSSurface.planner:
        context.go(AppRoutes.osPlanner);
        return;
      case OSSurface.home:
      case OSSurface.other:
        context.go(AppRoutes.osHome);
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedPageBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: TeacherWhiteboardWorkspace(
              controller: controller,
              title: 'Teacher whiteboard',
              showStatusChips: false,
              fillAvailableHeight: true,
              onClose: showCloseButton ? () => _closeWhiteboard(context) : null,
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
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
    if (kIsWeb) return const _TeachingStudioDestination();
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedPageBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              children: [
                Expanded(child: TeacherWhiteboardWorkspace(
              controller: controller,
              title: 'Teacher whiteboard',
              showStatusChips: false,
              fillAvailableHeight: true,
              onClose: showCloseButton ? () => _closeWhiteboard(context) : null,
                )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TeachingStudioDestination extends StatefulWidget {
  const _TeachingStudioDestination();

  @override
  State<_TeachingStudioDestination> createState() => _TeachingStudioDestinationState();
}

class _TeachingStudioDestinationState extends State<_TeachingStudioDestination> {
  bool _started = false;
  bool _failed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _open(); });
  }

  Future<void> _open() async {
    final classId = context.read<GradeFlowOSController>().activeClassId;
    final uri = Uri.base.resolve('/teaching-studio/').replace(
      queryParameters: classId == null ? null : {'classId': classId},
    );
    try {
      final opened = await launchUrl(uri, webOnlyWindowName: '_self');
      if (!opened && mounted) setState(() => _failed = true);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: _failed
        ? FilledButton.icon(
            onPressed: _open,
            icon: const Icon(Icons.draw_rounded),
            label: const Text('Open Whiteboard & PDF'),
          )
        : const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Opening Whiteboard & PDF…'),
            ],
          ),
    ),
  );
}

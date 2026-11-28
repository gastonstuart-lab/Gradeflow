// Teacher-facing demonstration with a fresh fictional gradebook per page.
import 'dart:js_interop';
import 'package:uuid/uuid.dart';
import 'package:web/web.dart' as web;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'models/class.dart';
import 'models/student.dart';
import 'models/student_score.dart';
import 'models/final_exam.dart';
import 'models/grading_period.dart';
import 'repositories/grading_period_repository.dart';
import 'services/grading_period_service.dart';
import 'services/grading_period_template.dart';
import 'services/grading_period_ui_controller.dart';
import 'screens/period_gradebook_workspace.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  RendererBinding.instance.ensureSemantics();
  GoogleFonts.config.allowRuntimeFetching = false;
  runApp(MaterialApp(
    title: 'GradeFlow · Grading period demonstration',
    debugShowCheckedModeBanner: false,
    theme: lightTheme,
    builder: (context, child) => Column(
      children: [
        Material(
          color: Theme.of(context).colorScheme.secondaryContainer,
          child: SafeArea(
            bottom: false,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text(
                'Demonstration · Synthetic data · Changes reset on page refresh',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
        Expanded(child: child!),
      ],
    ),
    home: const _Preview(),
  ));
}

class _Preview extends StatefulWidget {
  const _Preview();
  @override
  State<_Preview> createState() => _PreviewState();
}

class _PreviewState extends State<_Preview> {
  GradingPeriodUiController? session;
  Class? record;
  String? error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final repo = InMemoryGradingPeriodRepository(
        ownerId: 'synthetic-teacher-${const Uuid().v4()}',
      );
      const cid = 'synthetic-preview-gradebook';
      final stamp = DateTime.utc(2026, 11, 1);
      record = Class(
          classId: cid,
          className: 'English · Synthetic Grade 10A',
          subject: 'English Language',
          schoolYear: '2026–2027',
          term: 'Semester 1',
          teacherId: repo.ownerId,
          createdAt: stamp,
          updatedAt: stamp);
      const names = [
        'Alex',
        'Bailey',
        'Casey',
        'Dana',
        'Elliot',
        'Finley',
        'Jamie',
        'Kai',
        'Morgan',
        'Quinn',
        'Riley',
        'Sam'
      ];
      final context =
          GradebookDataset.fromLegacy(classRecord: record!, students: [
        for (var n = 0; n < names.length; n++)
          Student(
              studentId: 'S${(n + 1).toString().padLeft(2, "0")}',
              chineseName: 'Synthetic ${n + 1}',
              englishFirstName: names[n],
              englishLastName: 'Example',
              classId: cid,
              seatNo: '${n + 1}',
              createdAt: stamp,
              updatedAt: stamp),
      ], categories: [], assessments: [], scores: [], exams: []);
      final first = GradingPeriodTemplate.create(
          context: context,
          periodId: 'preview-period-1',
          label: 'November',
          at: stamp);
      final json = first.dataset.toJson();
      json['scores'] = [
        StudentScore(
                studentId: 'S01',
                gradeItemId: first.dataset.assessments.first.gradeItemId,
                score: 68,
                createdAt: stamp,
                updatedAt: stamp)
            .toJson()
      ];
      json['exams'] = [
        for (final s in context.students)
          FinalExam(
                  studentId: s.studentId,
                  examScore: 88,
                  createdAt: stamp,
                  updatedAt: stamp)
              .toJson()
      ];
      await GradingPeriodService(repo).adoptLegacy(
          dataset: GradebookDataset.fromJson(json),
          periodId: first.periodId,
          label: first.label,
          at: stamp);
      await GradingPeriodService(repo).rollover(
          classId: cid,
          periodId: first.periodId,
          expectedRevision: 0,
          nextPeriodId: 'preview-period-2',
          label: 'December',
          at: DateTime.utc(2026, 11, 27));
      final controller = GradingPeriodUiController(repo, cid);
      await controller.initialize();
      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() => session = controller);
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Could not open the demonstration. Refresh to try again.');
      }
    }
  }

  @override
  void dispose() {
    session?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (session == null)
      return Scaffold(
          body: Center(
              child: Text(error ?? 'Preparing the synthetic gradebook…')));
    return PeriodGradebookWorkspace(
        session: session!,
        classRecord: record!,
        export: (bytes, name) async {
          final blob = web.Blob(
              [bytes.toJS].toJS,
              web.BlobPropertyBag(
                  type:
                      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'));
          final url = web.URL.createObjectURL(blob);
          web.HTMLAnchorElement()
            ..href = url
            ..download = name
            ..click();
          web.URL.revokeObjectURL(url);
        });
  }
}

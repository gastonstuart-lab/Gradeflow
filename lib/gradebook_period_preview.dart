// Separate opt-in entrypoint: production main.dart never imports this preview.
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'models/class.dart';
import 'models/student.dart';
import 'models/student_score.dart';
import 'models/final_exam.dart';
import 'models/grading_period.dart';
import 'repositories/firestore_grading_period_repository.dart';
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
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      home: const _Preview()));
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
    // The preview uses only loopback demo emulators. Refuse a hosted
    // copy before Firebase initializes or a cached account is restored.
    final host = web.window.location.hostname;
    if (host != 'localhost' && host != '127.0.0.1') {
      if (mounted) {
        setState(() => error = 'This synthetic gradebook preview is local-only.');
      }
      return;
    }
    try {
      final app = await Firebase.initializeApp(
          options: const FirebaseOptions(
              apiKey: 'synthetic-emulator-key',
              appId: '1:123:web:synthetic',
              messagingSenderId: '123',
              projectId: 'demo-gradeflow-periods',
              authDomain: 'demo-gradeflow-periods.firebaseapp.com'));
      final auth = fb.FirebaseAuth.instanceFor(app: app);
      await auth.useAuthEmulator('127.0.0.1', 9095);
      const email = 'gradebook-preview@example.invalid';
      const password = 'synthetic-preview-only';
      try {
        await auth.createUserWithEmailAndPassword(
            email: email, password: password);
      } on fb.FirebaseAuthException catch (e) {
        if (e.code != 'email-already-in-use') rethrow;
        await auth.signInWithEmailAndPassword(email: email, password: password);
      }
      final repo = FirestoreGradingPeriodRepository.emulator(
          firestore: FirebaseFirestore.instanceFor(app: app), auth: auth);
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
      if (await repo.load(cid) == null) {
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
      }
      session = GradingPeriodUiController(repo, cid);
      await session!.initialize();
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted)
        setState(() => error =
            'Start the demo emulators and trusted coordinator, then reload this preview.');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (session == null)
      return Scaffold(
          body: Center(
              child: Text(error ?? 'Connecting to synthetic gradebook…')));
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

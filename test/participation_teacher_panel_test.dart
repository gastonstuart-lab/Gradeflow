import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/components/participation_teacher_panel.dart';
import 'package:gradeflow/services/lesson_participation_ledger.dart';

void main() {
  final start = DateTime.utc(2026, 11, 28, 1);
  final scope = (ownerId: 'teacher', classId: 'class', periodId: 'period',
      occurrenceId: 'lesson', startsAt: start);
  const eating = ValueKey('incident-eating');
  const score = ValueKey('participation-score');
  late ValueNotifier<LessonParticipationLedger> ledger;
  var seq = 0;
  setUp(() {
    ledger = ValueNotifier(LessonParticipationLedger(scope: scope, studentIds: ['a', 'b']));
    seq = 0;
  });
  tearDown(() => ledger.dispose());
  Widget harness({bool private = true,
      Future<void> Function(ParticipationEvent)? save}) =>
      MaterialApp(home: Scaffold(body: ParticipationTeacherPanel(
        teacherPrivate: private,
        ledger: ledger, studentId: 'a', studentLabel: 'Fictional student',
        policy: BehaviourPolicy(),
        newOperationId: () => 'op-${seq++}',
        clock: () => start.add(const Duration(minutes: 1)),
        onSubmit: save ?? (event) async { ledger.value = ledger.value.append(event); },
      )));
  String displayed(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(score)).data!;

  testWidgets('private seat controls record repeated deductions and undo',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(harness());
    expect(displayed(tester), '100 / 100');
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.byKey(eating));
      await tester.pumpAndSettle();
    }
    expect(displayed(tester), '80 / 100');
    expect(ledger.value.scoreFor('b'), 100);
    await tester.ensureVisible(find.text('Undo last change'));
    await tester.tap(find.text('Undo last change'));
    await tester.pumpAndSettle();
    expect(displayed(tester), '90 / 100');
    expect(ledger.value.historyFor('a'), hasLength(3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('retry keeps the same operation after acknowledgement is lost',
      (tester) async {
    final submitted = <ParticipationEvent>[];
    await tester.pumpWidget(harness(save: (event) async {
      submitted.add(event);
      ledger.value = ledger.value.append(event);
      if (submitted.length == 1) throw StateError('Fictional lost acknowledgement');
    }));
    await tester.tap(find.byKey(eating));
    await tester.pumpAndSettle();
    expect(find.textContaining('Save unconfirmed'), findsOneWidget);
    expect(tester.widget<OutlinedButton>(find.byKey(eating)).onPressed, isNull);
    await tester.ensureVisible(find.text('Retry saving'));
    await tester.tap(find.text('Retry saving'));
    await tester.pumpAndSettle();
    expect(submitted, hasLength(2));
    expect(identical(submitted.first, submitted.last), isTrue);
    expect(ledger.value.events, hasLength(1));
    expect(displayed(tester), '90 / 100');
    expect(find.text('Change confirmed'), findsOneWidget);
  });

  testWidgets('projector context shows no scores, reasons or history',
      (tester) async {
    await tester.pumpWidget(harness(private: false));
    expect(find.byKey(score), findsNothing);
    expect(find.byKey(eating), findsNothing);
    expect(find.text('Fictional student'), findsNothing);
    expect(find.textContaining('Private incident history'), findsNothing);
    expect(ledger.value.events, isEmpty);
  });
}

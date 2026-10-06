import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/models/user.dart';
import 'package:gradeflow/os/os_controller.dart';
import 'package:gradeflow/providers/app_providers.dart';
import 'package:gradeflow/repositories/repository_factory.dart';
import 'package:gradeflow/services/auth_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('provider observes restored identity, account switch and logout',
      (tester) async {
    final now = DateTime(2026, 10, 6);
    final teacherA = User(
      userId: 'synthetic-teacher-a',
      email: 'teacher-a@example.com',
      fullName: 'Synthetic Teacher A',
      schoolName: 'Synthetic School',
      createdAt: now,
      updatedAt: now,
    );
    SharedPreferences.setMockInitialValues({
      'current_user': jsonEncode(teacherA.toJson()),
    });
    RepositoryFactory.useLocal();
    late AuthService auth;
    late GradeFlowOSController controller;
    await tester.pumpWidget(AppProviders(
      child: MaterialApp(
        home: Builder(builder: (context) {
          auth = context.read<AuthService>();
          controller = context.watch<GradeFlowOSController>();
          return Text(controller.activeClassId ?? 'No working class');
        }),
      ),
    ));
    await auth.initialize();
    await tester.pump();
    await tester.pump();
    controller.setSurface(OSSurface.classWorkspace, classId: 'synthetic-a');
    controller.setSurface(OSSurface.planner);
    controller.setSurface(OSSurface.home);
    await tester.pump();
    expect(find.text('synthetic-a'), findsOneWidget);

    // Updating the same teacher must not release the active class.
    await auth.updateCurrentUser(teacherA);
    await tester.pump();
    expect(controller.activeClassId, 'synthetic-a');

    final teacherB = User(
      userId: 'synthetic-teacher-b',
      email: 'teacher-b@example.com',
      fullName: 'Synthetic Teacher B',
      schoolName: 'Synthetic School',
      createdAt: now,
      updatedAt: now,
    );
    await auth.updateCurrentUser(teacherB);
    await tester.pump();
    expect(controller.activeClassId, isNull);
    controller.selectWorkingClass('synthetic-b');
    controller.openAssistant();
    await auth.logout();
    await tester.pump();
    expect(controller.activeClassId, isNull);
    expect(controller.assistantOpen, isFalse);
    expect(find.text('No working class'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

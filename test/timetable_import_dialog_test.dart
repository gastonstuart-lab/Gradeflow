import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gradeflow/components/timetable_import_dialog.dart';
import 'package:gradeflow/models/user.dart';
import 'package:gradeflow/models/class.dart' as school;
import 'package:gradeflow/services/auth_service.dart';
import 'package:gradeflow/services/class_service.dart';
import 'package:gradeflow/services/home_weekly_timetable_service.dart';
import 'timetable_reliability_test.dart'
    show timetableClasses, timetableGrid, csvBytes;

class TimetableAuth extends AuthService {
  String id = 'teacher-a';
  @override
  User get currentUser => User(
      userId: id,
      email: '$id@example.invalid',
      fullName: 'Synthetic teacher',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026));
}

class TimetableClasses extends ClassService {
  TimetableClasses({this.ambiguous = false});
  final bool ambiguous;
  @override
  List<school.Class> get activeClasses {
    final classes = timetableClasses('teacher-a');
    return [
      ...classes,
      if (ambiguous)
        school.Class.fromJson(
            {...classes.first.toJson(), 'classId': 'ambiguous'})
    ];
  }
}

void main() {
  for (final action in ['cancel', 'confirm', 'account-change', 'ambiguous']) {
    testWidgets(
        'complete preview and $action preserve the correct teacher state',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1400, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final auth = TimetableAuth();
      final owned = timetableClasses('teacher-a');
      await const HomeWeeklyTimetableService().importForTeacher(
          userId: 'teacher-a',
          filename: 'existing.csv',
          bytes: csvBytes(timetableGrid()),
          classMatches: {for (final c in owned) c.className: c.classId},
          availableClasses: owned);
      HomeWeeklyTimetable? saved;
      Object? error;
      await tester.pumpWidget(MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthService>.value(value: auth),
            ChangeNotifierProvider<ClassService>(
                create: (_) =>
                    TimetableClasses(ambiguous: action == 'ambiguous')),
          ],
          child: MaterialApp(
              home: Scaffold(
                  body: Builder(
                      builder: (context) => TextButton(
                          onPressed: () async {
                            try {
                              saved = await confirmTimetableImport(context,
                                  filename: 'school.csv',
                                  bytes: csvBytes(timetableGrid()));
                            } catch (e) {
                              error = e;
                            }
                          },
                          child: const Text('Import')))))));
      await tester.tap(find.text('Import'));
      await tester.pumpAndSettle();
      expect(find.text('Review 24 timetable periods'), findsOneWidget);
      expect(find.byType(ListTile), findsNWidgets(24));
      expect(find.byType(DropdownButtonFormField<String>), findsNWidgets(8));
      expect(
          (await const HomeWeeklyTimetableService().loadSelected('teacher-a'))!
              .name,
          'existing.csv');
      if (action == 'account-change') auth.id = 'teacher-b';
      if (action == 'ambiguous') {
        expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
            isNull);
      }
      await tester.tap(find.text(action == 'cancel' || action == 'ambiguous'
          ? 'Cancel'
          : 'Confirm and save locally'));
      await tester.pumpAndSettle();
      if (action == 'confirm') {
        expect(saved!.classes, hasLength(24));
        expect(
            (await const HomeWeeklyTimetableService()
                    .loadSelected('teacher-a'))!
                .classes,
            hasLength(24));
      } else {
        expect(saved, isNull);
        expect(
            (await const HomeWeeklyTimetableService()
                    .loadSelected('teacher-a'))!
                .name,
            'existing.csv');
      }
      expect(await const HomeWeeklyTimetableService().loadSelected('teacher-b'),
          isNull);
      expect(error != null, action == 'account-change');
      await tester.pumpWidget(const SizedBox());
      auth.dispose();
    });
  }
}

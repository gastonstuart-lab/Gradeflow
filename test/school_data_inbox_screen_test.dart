import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/providers/app_providers.dart';
import 'package:gradeflow/screens/school_data_inbox_screen.dart';
import 'package:gradeflow/services/auth_service.dart';
import 'package:gradeflow/services/class_service.dart';
import 'package:gradeflow/services/google_auth_service.dart';
import 'package:gradeflow/services/google_drive_service.dart';
import 'package:gradeflow/theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('school calendar parser reads dated CSV events', () {
    final bytes = Uint8List.fromList(utf8.encode(
      'Date,Event,Notes\n'
      '2026-05-20,Assembly,Auditorium\n'
      '2026-05-21,Exam week starts,Block schedule\n',
    ));

    final result = parseSchoolCalendarInboxImport(
      bytes,
      filename: '2026-school-calendar.csv',
    );

    expect(result.events, hasLength(2));
    expect(result.events.first.title, 'Assembly');
    expect(result.events.first.date, DateTime(2026, 5, 20));
    expect(result.events.first.details, 'Auditorium');
  });

  testWidgets('SchoolDataInboxScreen renders source and import cards',
      (tester) async {
    final auth = AuthService();
    await auth.initialize();
    addTearDown(auth.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<GoogleAuthService>(create: (_) => GoogleAuthService()),
          Provider<GoogleDriveService>(
            create: (_) => GoogleDriveService(),
          ),
          ChangeNotifierProvider<AuthService>.value(value: auth),
          ChangeNotifierProvider<ClassService>(create: (_) => ClassService()),
          ChangeNotifierProvider<ThemeModeNotifier>(
            create: (_) => ThemeModeNotifier(),
          ),
        ],
        child: MaterialApp(
          theme: darkTheme,
          home: const SchoolDataInboxScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('School Data Inbox'), findsOneWidget);
    expect(find.text('Upload from computer'), findsOneWidget);
    expect(find.text('Import from Google Drive'), findsOneWidget);
    expect(find.text('Class schedule'), findsOneWidget);
    expect(find.text('Teacher timetable'), findsOneWidget);
    expect(find.text('Roster'), findsOneWidget);
    expect(find.text('Scores'), findsOneWidget);
    expect(find.text('Recent imports'), findsOneWidget);
  });
}

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

  test('school calendar parser handles Taiwan and UK-style dates safely', () {
    final bytes = Uint8List.fromList(utf8.encode(
      'Date,Event\n'
      '2026-05-20,ISO event\n'
      '20/05/2026,Slash day-month event\n'
      '20-05-2026,Dash day-month event\n'
      '05/06/2026,Ambiguous day-month event\n'
      '31/02/2026,Impossible event\n'
      '20/20/2026,Overflow event\n',
    ));

    final result = parseSchoolCalendarInboxImport(
      bytes,
      filename: '2026-school-calendar.csv',
    );

    expect(
      result.events.map((event) => event.title),
      containsAll([
        'ISO event',
        'Slash day-month event',
        'Dash day-month event',
        'Ambiguous day-month event',
      ]),
    );
    expect(
      result.events.firstWhere((event) => event.title == 'ISO event').date,
      DateTime(2026, 5, 20),
    );
    expect(
      result.events
          .firstWhere((event) => event.title == 'Slash day-month event')
          .date,
      DateTime(2026, 5, 20),
    );
    expect(
      result.events
          .firstWhere((event) => event.title == 'Dash day-month event')
          .date,
      DateTime(2026, 5, 20),
    );
    expect(
      result.events
          .firstWhere((event) => event.title == 'Ambiguous day-month event')
          .date,
      DateTime(2026, 6, 5),
    );
    expect(
      result.events.map((event) => event.title),
      isNot(contains('Impossible event')),
    );
    expect(
      result.events.map((event) => event.title),
      isNot(contains('Overflow event')),
    );
  });

  testWidgets('SchoolDataInboxScreen renders premium upload station',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

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
    expect(find.text('Choose from Google Drive'), findsOneWidget);
    expect(
      find.text(
        'Opens a Drive file picker list. Choose a file first; extracted data is previewed before saving.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Choose a file first. InstructOS will detect what it probably is, then show a preview. Nothing is saved, printed, shared, or sent until you review and confirm.',
      ),
      findsOneWidget,
    );
    expect(find.text('Connect school shared folder'), findsOneWidget);
    expect(
      find.text(
        'Later, connect a shared Drive folder for calendars, timetables, quizzes, worksheets, rosters, and teaching documents.',
      ),
      findsOneWidget,
    );
    expect(find.text('Choose file'), findsOneWidget);
    expect(find.text('Detect'), findsOneWidget);
    expect(find.text('Confirm'), findsOneWidget);
    expect(find.text('Preview before saving'), findsOneWidget);
    expect(
      find.text('Your preview will appear here after you choose a file.'),
      findsOneWidget,
    );
    expect(
      find.text('Nothing is saved until you review and confirm.'),
      findsOneWidget,
    );
    expect(find.text('Detected type'), findsOneWidget);
    expect(find.text('Items found'), findsOneWidget);
    expect(find.text('Warnings'), findsOneWidget);
    expect(find.text('Action before saving'), findsOneWidget);
    expect(
      find.text(
        'Future Ask InstructOS support can search approved school folders only after teacher/admin permission.',
      ),
      findsOneWidget,
    );
    expect(find.text('Class schedule'), findsWidgets);
    expect(find.text('School calendar'), findsWidgets);

    await tester.scrollUntilVisible(
      find.text('Teacher timetable'),
      700,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();

    expect(find.text('Teacher timetable'), findsOneWidget);
    expect(find.text('Roster'), findsOneWidget);
    expect(find.text('Scores'), findsOneWidget);
    expect(find.text('Recent imports'), findsOneWidget);
    expect(find.text('Ask InstructOS over approved folders'), findsOneWidget);
  });
}

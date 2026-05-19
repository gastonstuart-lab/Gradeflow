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

  testWidgets('SchoolDataInboxScreen renders School Knowledge Hub layout',
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

    expect(find.text('School Knowledge Hub'), findsOneWidget);
    expect(
      find.text(
        'Upload and connect school data to power smarter insights, planning, and support.',
      ),
      findsOneWidget,
    );
    expect(find.text('Secure & private'), findsOneWidget);
    expect(find.text('Add school data'), findsOneWidget);
    expect(
      find.text(
        'Choose a source to get started. InstructOS will detect what it likely is, show a preview, and you confirm before anything is imported.',
      ),
      findsOneWidget,
    );
    expect(find.text('Upload from computer'), findsOneWidget);
    expect(find.text('Choose from Google Drive'), findsOneWidget);
    expect(find.text('Drag & drop files'), findsOneWidget);
    expect(find.text('Choose file'), findsOneWidget);
    expect(find.text('Choose from Drive'), findsOneWidget);
    expect(find.text('Browse files'), findsOneWidget);
    expect(
      find.text(
        'Upload CSV, Excel, Word, or ICS files up to 250 MB.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Browse and select files from your Drive.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Drag files here to upload from your computer.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        "We'll detect what it is, show a preview, and you confirm what to import.",
      ),
      findsOneWidget,
    );
    expect(find.text('Preview'), findsOneWidget);
    expect(
      find.text('See a quick preview before you confirm.'),
      findsOneWidget,
    );
    expect(find.text('Choose a file to preview'), findsOneWidget);
    expect(
      find.text(
        'A preview of your data will appear here.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Nothing is saved until you review and confirm.'),
      findsWidgets,
    );
    expect(find.text('School shared folder'), findsOneWidget);
    expect(find.text('Coming soon'), findsOneWidget);
    expect(
      find.text(
        'Access approved shared resources like calendars, quizzes, worksheets, rosters, and teaching docs.',
      ),
      findsOneWidget,
    );
    expect(find.text('Calendars'), findsOneWidget);
    expect(find.text('Quizzes'), findsOneWidget);
    expect(find.text('Worksheets'), findsOneWidget);
    expect(find.text('Rosters'), findsOneWidget);
    expect(find.text('Teaching docs'), findsOneWidget);
    expect(
      find.text('Visible only after your school approves access.'),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(
      find.text(
        'Ask InstructOS can later search approved school folders — only with permission.',
      ),
      360,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Ask InstructOS can later search approved school folders — only with permission.',
      ),
      findsOneWidget,
    );
    expect(find.text('Learn more'), findsOneWidget);
    expect(find.text('School Data Inbox'), findsNothing);
    expect(find.text('Import destination'), findsNothing);
    expect(find.text('Class schedule'), findsNothing);
    expect(find.text('School calendar'), findsNothing);
    expect(find.text('Teacher timetable'), findsNothing);
    expect(find.text('Roster'), findsNothing);
    expect(find.text('Scores'), findsNothing);
    expect(find.text('Recent imports'), findsNothing);
    expect(find.text('Ask InstructOS over approved folders'), findsNothing);
    expect(find.text('Detected type'), findsNothing);
    expect(find.text('Items found'), findsNothing);
    expect(find.text('Warnings'), findsNothing);
    expect(find.text('Action before saving'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('Choose file'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Choose file'));
    await tester.pumpAndSettle();

    expect(find.text('What are you importing?'), findsOneWidget);
    expect(find.text('Class schedule'), findsOneWidget);
    expect(find.text('School calendar'), findsOneWidget);
  });
}

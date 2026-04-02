import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:gradeflow/services/auth_service.dart';
import 'package:gradeflow/services/class_service.dart';
import 'package:gradeflow/services/student_service.dart';
import 'package:gradeflow/services/class_schedule_service.dart';
import 'package:gradeflow/models/class_schedule_item.dart';
import 'package:gradeflow/theme.dart';
import 'package:gradeflow/components/school_banner.dart';
import 'package:gradeflow/components/animated_glow_border.dart';
import 'package:gradeflow/components/animated_page_background.dart';
import 'package:gradeflow/components/dashboard_story_carousel.dart';
import 'package:gradeflow/components/drive_file_picker_dialog.dart';
import 'package:gradeflow/components/pilot_feedback_card.dart';
import 'package:gradeflow/components/pilot_feedback_dialog.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:gradeflow/services/file_import_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gradeflow/providers/app_providers.dart';
import 'package:gradeflow/nav.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:gradeflow/services/google_drive_service.dart';
import 'package:gradeflow/services/google_auth_service.dart';
import 'package:gradeflow/services/ai_import_service.dart';
import 'package:gradeflow/services/dashboard_news_service.dart';
import 'package:gradeflow/services/dashboard_weather_service.dart';
import 'package:gradeflow/openai/openai_config.dart';
import 'package:gradeflow/components/ai_analyze_import_dialog.dart';
import 'package:gradeflow/components/time_slot_timetable.dart';

class TeacherDashboardScreen extends StatefulWidget {
  const TeacherDashboardScreen({super.key});

  @override
  State<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen> {
  static const String _defaultAttendancePortalUrl =
      'https://fsis.hn.thu.edu.tw/csn1t/permain.asp';
  static const String _legacyRemindersPrefsKey = 'dashboard_reminders';
  static const String _legacyAttendanceUrlPrefsKey = 'attendance_url';
  static const String _legacyQuickLinksPrefsKey = 'custom_quick_links';
  static const String _remindersMigrationFlagKey =
      'dashboard_reminders_migrated_v1';
  static const String _attendanceUrlMigrationFlagKey =
      'dashboard_attendance_url_migrated_v1';
  static const String _quickLinksMigrationFlagKey =
      'dashboard_quick_links_migrated_v1';
  static const String _worldHeroImageAsset =
      'assets/images/dashboard_world.jpg';
  static const String _weatherHeroImageAsset =
      'assets/images/dashboard_weather.jpg';
  static const String _eventsHeroImageAsset =
      'assets/images/dashboard_events.jpg';

  Timer? _timer;
  Timer? _liveCarouselRefreshTimer;
  final ValueNotifier<DateTime> _nowNotifier = ValueNotifier(DateTime.now());
  final GlobalKey _classToolsSectionKey = GlobalKey();
  final GlobalKey _calendarSectionKey = GlobalKey();

  String? _selectedClassId;
  List<_ClassBrief> _classes = [];
  int _totalStudents = 0;

  // Simple local reminders (no backend)
  final List<_Reminder> _reminders = [];
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _selectedDate;
  final TextEditingController _reminderCtrl = TextEditingController();
  // Attendance link (simple local URL field)
  final TextEditingController _attendanceUrlCtrl = TextEditingController();
  final TextEditingController _googleSearchCtrl = TextEditingController();
  final TextEditingController _askAiCtrl = TextEditingController();

  // Quick Links (default + user-added)
  final List<_QuickLink> _customLinks = [];

  // Timetable uploads (per user; stored locally)
  final List<_Timetable> _timetables = [];
  String? _selectedTimetableId;

  // Name picker / group maker
  List<String> _currentNames = [];
  String? _pickedName;
  int _groupSize = 2;
  List<List<String>> _groups = [];
  bool _updatingTeacherPhoto = false;

  // Class Tools tabs
  final List<String> _toolTabs = [
    'Name Picker',
    'Groups',
    'Participation',
    'Schedule',
    'Quick Poll',
    'Timer',
    'QR Code'
  ];
  int _selectedToolTab = 0;

  // Summary range for reminders panel (Week or Month)
  _SummaryRange _summaryRange = _SummaryRange.week;

  // Participation counters (per class)
  final Map<String, Map<String, int>> _participation =
      {}; // classId -> { name: count }

  // Quick Poll (single session, per class)
  final Map<String, Map<String, int>> _pollCountsByClass =
      {}; // classId -> {'A':..,'B':..,'C':..,'D':..}

  // Timer/Stopwatch
  Timer? _stopwatchTimer;
  int _stopwatchSeconds = 0;
  bool _stopwatchRunning = false;
  Timer? _countdownTimer;
  int _countdownSeconds = 0;
  final TextEditingController _cdMinCtrl = TextEditingController(text: '0');
  final TextEditingController _cdSecCtrl = TextEditingController(text: '30');

  // QR Code
  final TextEditingController _qrCtrl = TextEditingController();

  // Per-class schedule (semester plan)
  final ClassScheduleService _classScheduleService = ClassScheduleService();
  final Map<String, List<ClassScheduleItem>> _scheduleByClass = {};
  bool _scheduleBusy = false;
  String? _dashboardPrefsUserId;
  final DashboardNewsService _dashboardNewsService = DashboardNewsService();
  final DashboardWeatherService _dashboardWeatherService =
      DashboardWeatherService();
  List<DashboardNewsStory> _worldNewsStories = [];
  List<DashboardNewsStory> _localNewsStories = [];
  DashboardWeatherSnapshot? _weatherSnapshot;
  bool _newsBusy = false;
  bool _weatherBusy = false;
  String? _newsError;
  String? _weatherError;

  Future<void> _showImportDiagnosticsDialog({
    required String title,
    required String filename,
    required Uint8List bytes,
    String? hint,
  }) async {
    if (!mounted) return;
    final diagnostics =
        FileImportService().diagnosticsForFile(bytes, filename: filename);

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: SelectableText(
              [
                if (hint != null && hint.trim().isNotEmpty) hint.trim(),
                diagnostics,
              ].join('\n\n'),
            ),
          ),
        ),
        actions: [
          if (OpenAIConfig.isConfigured)
            TextButton(
              onPressed: () async {
                final rows = FileImportService().rowsFromAnyBytes(bytes);

                try {
                  final result = await showDialog<Map<String, dynamic>>(
                    context: context,
                    builder: (_) => AiAnalyzeImportDialog(
                      title: 'Analyze calendar with AI',
                      filename: filename,
                      confirmLabel: 'Import events',
                      hint:
                          'If this looks correct, press Import events to add reminders.',
                      analyze: () =>
                          AiImportService().analyzeSchoolCalendarFromRows(
                        rows,
                        filename: filename,
                      ),
                    ),
                  );
                  if (result == null || !context.mounted) return;

                  final events = result['events'];
                  if (events is! List) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text(
                              'AI did not return valid events. Please try a different file format.')));
                    }
                    return;
                  }

                  final remindersToAdd = <_Reminder>[];
                  for (final e in events) {
                    if (e is! Map) continue;
                    final dateStr = (e['date'] ?? '').toString().trim();
                    final titleStr = (e['title'] ?? '').toString().trim();
                    if (dateStr.isEmpty || titleStr.isEmpty) continue;
                    final d = DateTime.tryParse(dateStr);
                    if (d == null) continue;
                    final details = (e['details'] ?? '').toString().trim();
                    final t =
                        details.isEmpty ? titleStr : '$titleStr - $details';
                    remindersToAdd.add(_Reminder(t, d, done: false));
                  }

                  if (remindersToAdd.isEmpty) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text(
                              'No valid events found. Try a file with Date and Title columns.')));
                    }
                    return;
                  }

                  if (mounted) {
                    setState(() => _reminders.addAll(remindersToAdd));
                  }
                  await _saveReminders();
                  if (!context.mounted) return;
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(
                          'Imported ${remindersToAdd.length} events from AI')));
                } catch (e) {
                  // AI failed - show helpful error message
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(
                          'AI analysis failed: ${e.toString().contains('quota') ? 'API quota exceeded' : 'Connection error'}'),
                      duration: const Duration(seconds: 4),
                    ));
                  }
                }
              },
              child: const Text('Analyze with AI'),
            ),
          TextButton(
            onPressed: () async {
              final nav = Navigator.of(ctx);
              final messenger = ScaffoldMessenger.of(context);
              await Clipboard.setData(ClipboardData(text: diagnostics));
              if (!context.mounted) return;
              nav.pop();
              messenger.showSnackBar(
                  const SnackBar(content: Text('Diagnostics copied')));
            },
            child: const Text('Copy diagnostics'),
          ),
          FilledButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _nowNotifier.value = DateTime.now();
    });
    // Default to the school attendance portal unless the teacher overrides it.
    _attendanceUrlCtrl.text = _defaultAttendancePortalUrl;
    // Do not prefill QR text; leave empty so teacher enters student-targeted content
    // _qrCtrl.text = _attendanceUrlCtrl.text;
    unawaited(_refreshLiveCarouselData());
    _liveCarouselRefreshTimer = Timer.periodic(
      const Duration(minutes: 20),
      (_) => unawaited(_refreshLiveCarouselData()),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final userId = _dashboardStorageUserId();
    if (_dashboardPrefsUserId == userId) return;
    _dashboardPrefsUserId = userId;
    unawaited(_loadData());
    unawaited(_loadReminders());
    unawaited(_loadQuickLinks());
    unawaited(_loadTimetables());
  }

  Widget _buildQrTool(BuildContext context) {
    final text = _qrCtrl.text.trim();
    final isUrl = _isLikelyUrl(text);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.qr_code_2_outlined),
        const SizedBox(width: 8),
        Text('QR Code', style: context.textStyles.titleSmall?.semiBold)
      ]),
      const SizedBox(height: 8),
      TextField(
        controller: _qrCtrl,
        decoration: InputDecoration(
          labelText: 'Text or URL',
          isDense: true,
          suffixIcon: IconButton(
            tooltip: 'Clear',
            icon: const Icon(Icons.clear),
            onPressed: () => setState(() => _qrCtrl.clear()),
          ),
        ),
        onChanged: (_) => setState(() {}),
      ),
      // Removed teacher quick-fill link chips under the QR input; the QR content is
      // intended for students' devices, so the teacher enters it explicitly.
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: [
        FilledButton.icon(
            onPressed: _showQrFullScreen,
            icon: const Icon(Icons.fullscreen),
            label: const Text('Full screen')),
        OutlinedButton.icon(
          onPressed: text.isEmpty
              ? null
              : () async {
                  await Clipboard.setData(ClipboardData(text: text));
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Text copied')));
                  }
                },
          icon: const Icon(Icons.copy_all_outlined),
          label: const Text('Copy text'),
        ),
        if (isUrl)
          OutlinedButton.icon(
            onPressed: () => _openExternal(text),
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open link'),
          ),
      ]),
      const SizedBox(height: 12),
      Center(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
            border:
                Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          ),
          child: text.isEmpty
              ? Text('Enter text to generate QR',
                  style: context.textStyles.bodySmall?.withColor(
                      Theme.of(context).colorScheme.onSurfaceVariant))
              : QrImageView(
                  data: text,
                  size: 220,
                  backgroundColor: Colors.transparent,
                ),
        ),
      ),
    ]);
  }

  bool _isLikelyUrl(String s) {
    if (s.isEmpty) return false;
    final t = s.toLowerCase();
    return t.startsWith('http://') ||
        t.startsWith('https://') ||
        (t.contains('.') && !t.contains(' '));
  }

  Future<void> _showQrFullScreen() async {
    final text = _qrCtrl.text.trim();
    if (text.isEmpty) return;
    await showModalBottomSheet(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                const Icon(Icons.qr_code_2_outlined),
                const SizedBox(width: 8),
                Expanded(
                    child: Text('QR Code',
                        style: Theme.of(ctx).textTheme.titleLarge)),
                IconButton(
                    icon: const Icon(Icons.copy_all_outlined),
                    tooltip: 'Copy text',
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: text));
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Text copied')));
                      }
                    }),
                if (_isLikelyUrl(text))
                  IconButton(
                      icon: const Icon(Icons.open_in_new),
                      tooltip: 'Open',
                      onPressed: () => _openExternal(text)),
              ]),
              const SizedBox(height: 16),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Theme.of(ctx).colorScheme.outlineVariant),
                  ),
                  child: QrImageView(
                      data: text,
                      size: 320,
                      backgroundColor: Colors.transparent),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loadData() async {
    final auth = context.read<AuthService>();
    final classService = context.read<ClassService>();
    final studentService = context.read<StudentService>();

    final user = auth.currentUser;
    if (user == null) return;

    await classService.loadClasses(user.userId);
    final classes = classService.classes
        .map((c) => _ClassBrief(
            id: c.classId,
            name: c.className,
            subtitle: '${c.subject} • ${c.schoolYear} ${c.term}'))
        .toList();

    int totalStudents = 0;
    for (final c in classService.classes) {
      await studentService.loadStudents(c.classId);
      totalStudents += studentService.students.length;
    }

    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _classes = classes;
        _totalStudents = totalStudents;
        _selectedClassId = classes.isNotEmpty ? classes.first.id : null;
      });
      _refreshNames();
    });
  }

  void _refreshNames() async {
    final studentService = context.read<StudentService>();
    final classId = _selectedClassId;
    if (classId == null) {
      _safeSetState(() => _currentNames = []);
      return;
    }
    await studentService.loadStudents(classId);
    if (!mounted || _selectedClassId != classId) return;
    final names = studentService.students
        .map((s) => '${s.chineseName} (${s.englishFullName})')
        .toList();
    _safeSetState(() => _currentNames = names);

    // Load schedule for this class (async, cached)
    if (_selectedClassId != null) {
      unawaited(_loadClassSchedule(classId));
    }
    // Initialize participation counts for this class
    if (_selectedClassId != null) {
      _participation.putIfAbsent(classId, () => {});
      for (final n in names) {
        _participation[classId]!.putIfAbsent(n, () => 0);
      }
      // Initialize poll counts for this class
      _pollCountsByClass.putIfAbsent(
          classId, () => {'A': 0, 'B': 0, 'C': 0, 'D': 0});
    }
  }

  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  Future<void> _refreshLiveCarouselData() async {
    await Future.wait([
      _loadWorldNews(),
      _loadWeatherForecast(),
    ]);
  }

  Future<void> _loadWorldNews() async {
    if (_newsBusy) return;
    if (mounted) {
      setState(() {
        _newsBusy = true;
        _newsError = null;
      });
    }

    try {
      final bundle = await _dashboardNewsService.fetchNewsBundle();
      if (!mounted) return;
      setState(() {
        _worldNewsStories = bundle.world;
        _localNewsStories = bundle.local;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _newsError = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _newsBusy = false;
        });
      }
    }
  }

  Future<void> _loadWeatherForecast() async {
    if (_weatherBusy) return;
    if (mounted) {
      setState(() {
        _weatherBusy = true;
        _weatherError = null;
      });
    }

    try {
      final snapshot = await _dashboardWeatherService.fetchForecast();
      if (!mounted) return;
      setState(() {
        _weatherSnapshot = snapshot;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _weatherError = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _weatherBusy = false;
        });
      }
    }
  }

  Future<bool> _ensureDriveReady() async {
    final result = await context
        .read<GoogleAuthService>()
        .ensureAccessTokenDetailed(interactive: true);
    if (!mounted) return result.ok;
    if (!result.ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.userMessage())),
      );
      return false;
    }
    return true;
  }

  Future<void> _loadClassSchedule(String classId) async {
    if (_scheduleByClass.containsKey(classId)) return;
    try {
      final items = await _classScheduleService.load(classId);
      if (!mounted) return;
      setState(() => _scheduleByClass[classId] = items);
    } catch (e) {
      debugPrint('Failed to load schedule for class=$classId: $e');
    }
  }

  Future<void> _saveClassSchedule(
      String classId, List<ClassScheduleItem> items) async {
    await _classScheduleService.save(classId, items);
    if (!mounted) return;
    setState(() => _scheduleByClass[classId] = items);
  }

  Future<void> _importClassSchedule() async {
    if (_selectedClassId == null) return;
    if (_scheduleBusy) return;

    setState(() => _scheduleBusy = true);
    try {
      final picked = await FilePicker.platform.pickFiles(
        withData: true,
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'csv'],
      );
      if (picked == null || picked.files.single.bytes == null || !mounted) {
        setState(() => _scheduleBusy = false);
        return;
      }

      final bytes = picked.files.single.bytes!;
      final filename = picked.files.single.name;
      await _importClassScheduleFromBytes(bytes, filename);
    } catch (e) {
      debugPrint('Import class schedule failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to import class schedule')));
      }
    } finally {
      if (mounted) setState(() => _scheduleBusy = false);
    }
  }

  Future<void> _importClassScheduleFromDrive() async {
    if (_selectedClassId == null) return;
    if (_scheduleBusy) return;

    setState(() => _scheduleBusy = true);
    try {
      if (!await _ensureDriveReady()) return;
      final drive = context.read<GoogleDriveService>();
      final picked = await showDialog<DriveFile>(
        context: context,
        builder: (ctx) => DriveFilePickerDialog(
          driveService: drive,
          allowedExtensions: const ['xlsx', 'csv', 'docx'],
          title: 'Import class schedule from Google Drive',
        ),
      );
      if (picked == null) return;

      final bytes = await drive.downloadFileBytesFor(
        picked,
        preferredExportMimeType: GoogleDriveService.exportXlsxMimeType,
      );
      await _importClassScheduleFromBytes(bytes, picked.name);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Drive schedule import failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _scheduleBusy = false);
    }
  }

  Future<void> _importClassScheduleFromBytes(
      Uint8List bytes, String filename) async {
    if (!await _enforceImportType(
      bytes: bytes,
      filename: filename,
      allowed: {ImportFileType.calendar},
      destinationLabel: 'Class schedule',
    )) {
      return;
    }

    var items = _classScheduleService.parseFromBytes(bytes);
    if (items.isEmpty && OpenAIConfig.isConfigured) {
      final aiOutput = await AiImportService()
          .analyzeScheduleFromBytes(bytes, filename: filename);
      if (aiOutput != null && aiOutput.items.isNotEmpty) {
        items = aiOutput.items;
      }
    }

    if (items.isEmpty) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('No schedule detected'),
          content: Text(
            'Could not detect schedule items in "$filename". Try CSV/XLSX export with clear Date/Title or Week/Topic columns.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            )
          ],
        ),
      );
      return;
    }

    final dateItems = items.where((i) => i.date != null).toList();
    DateTime? start;
    DateTime? end;
    if (dateItems.isNotEmpty) {
      start =
          dateItems.map((e) => e.date!).reduce((a, b) => a.isBefore(b) ? a : b);
      end =
          dateItems.map((e) => e.date!).reduce((a, b) => a.isAfter(b) ? a : b);
    }

    if (!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import class schedule'),
        content: SizedBox(
          width: 560,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('File: $filename',
                  style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Items found: ${items.length}',
                        style: Theme.of(context).textTheme.bodySmall),
                    if (start != null && end != null)
                      Text(
                        'Date range: ${_formatDate(start)} -> ${_formatDate(end)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text('Preview (first 6):',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 6),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: items.take(6).map((i) {
                      final when = i.date != null
                          ? _formatDate(i.date!)
                          : (i.week != null ? 'Week ${i.week}' : '');
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(i.title,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: i.details.isEmpty
                            ? null
                            : Text(
                                i.details.values.take(2).join(' • '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                        leading: when.isEmpty
                            ? null
                            : Text(when,
                                style: Theme.of(context).textTheme.labelMedium),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Import'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await _saveClassSchedule(_selectedClassId!, items);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved schedule (${items.length} items)')),
        );
      }
    }
  }

  void _pickRandomName() {
    if (_currentNames.isEmpty) return;
    _currentNames.shuffle();
    setState(() => _pickedName = _currentNames.first);
  }

  void _makeGroups() {
    final names = List<String>.from(_currentNames);
    names.shuffle();

    // Ensure a sensible minimum group size (avoid singles when possible)
    final size = _groupSize <= 1 ? 2 : _groupSize;

    final groups = <List<String>>[];
    if (names.isEmpty) {
      setState(() => _groups = groups);
      return;
    }

    // Robust balanced distribution: create base groups of `size` and
    // spread the remainder across the first groups to avoid any singletons.
    final n = names.length;
    if (n <= size) {
      groups.add(List<String>.from(names));
    } else {
      final base = n ~/ size; // number of full groups
      final rem = n % size; // extras to distribute
      int idx = 0;
      // Create `base` groups with size `size` initially
      for (int g = 0; g < base; g++) {
        final take =
            size + (g < rem ? 1 : 0); // distribute extras to first `rem` groups
        groups.add(names.sublist(idx, idx + take));
        idx += take;
      }
      // If for some reason there are leftover names (e.g., base==0), put them all in one group
      if (idx < n) groups.add(names.sublist(idx));
    }

    setState(() => _groups = groups);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _reminderCtrl.dispose();
    _attendanceUrlCtrl.dispose();
    _googleSearchCtrl.dispose();
    _askAiCtrl.dispose();
    _cdMinCtrl.dispose();
    _cdSecCtrl.dispose();
    _qrCtrl.dispose();
    _stopwatchTimer?.cancel();
    _countdownTimer?.cancel();
    _liveCarouselRefreshTimer?.cancel();
    _nowNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    final themeMode = context.watch<ThemeModeNotifier>().themeMode;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final compactMasthead = screenWidth < 900;
    final mastheadWidth = screenWidth >= 1400
        ? 760.0
        : screenWidth >= 1100
            ? 680.0
            : screenWidth >= 820
                ? 560.0
                : 420.0;
    final storySlides = _dashboardStorySlides(context);
    debugPrint(
        'TeacherDashboard.build | classes=${_classes.length} reminders=${_reminders.length} width=${MediaQuery.of(context).size.width}');
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        toolbarHeight: compactMasthead ? 152 : 174,
        titleSpacing: 0,
        automaticallyImplyLeading: false,
        flexibleSpace: ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? const [
                            Color(0xFF060F1C),
                            Color(0xFF0E2744),
                            Color(0xFF1D4A72),
                          ]
                        : const [
                            Color(0xFF0B2440),
                            Color(0xFF17497B),
                            Color(0xFF3A80C0),
                          ],
                  ),
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.white.withValues(alpha: 0.16),
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.22),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                    BoxShadow(
                      color: const Color(0xFF1A5294).withValues(alpha: 0.18),
                      blurRadius: 40,
                      spreadRadius: -8,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: -48,
                right: -12,
                child: IgnorePointer(
                  child: Container(
                    width: 280,
                    height: 280,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.18),
                          const Color(0xFF5AB4E8).withValues(alpha: 0.08),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 120,
                bottom: -72,
                child: IgnorePointer(
                  child: Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFF8BE0FF).withValues(alpha: 0.18),
                          const Color(0xFF8BE0FF).withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.08),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.06),
                    ],
                    stops: const [0.0, 0.45, 1.0],
                  ),
                ),
              ),
              SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    // ── Main header row ──────────────────────────────────
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                          20, compactMasthead ? 8 : 10, 20, 0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // User identity chip (desktop only)
                          if (!compactMasthead) ...[
                            _AppBarUserChip(
                              name: user?.fullName ?? 'Teacher',
                              photoBase64: user?.photoBase64,
                            ),
                            const SizedBox(width: 10),
                          ],
                          // School masthead centred
                          Expanded(
                            child: Center(
                              child: SchoolHeroMasthead(
                                compact: compactMasthead,
                                maxWidth: mastheadWidth,
                              ),
                            ),
                          ),
                          if (!compactMasthead) const SizedBox(width: 10),
                          // Premium action buttons
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const PilotFeedbackIconButton(
                                initialArea: 'Dashboard',
                                initialRoute: '/dashboard',
                              ),
                              const SizedBox(width: 6),
                              _AppBarIconBtn(
                                icon: themeMode == ThemeMode.dark
                                    ? Icons.light_mode_rounded
                                    : Icons.dark_mode_rounded,
                                tooltip: themeMode == ThemeMode.dark
                                    ? 'Switch to light mode'
                                    : 'Switch to dark mode',
                                onPressed: () => context
                                    .read<ThemeModeNotifier>()
                                    .toggleTheme(),
                              ),
                              const SizedBox(width: 6),
                              _AppBarIconBtn(
                                icon: Icons.logout_rounded,
                                tooltip: 'Log out',
                                onPressed: () async {
                                  await context
                                      .read<GoogleAuthService>()
                                      .signOut();
                                  await context
                                      .read<AuthService>()
                                      .logout();
                                  if (!context.mounted) return;
                                  context.go(AppRoutes.home);
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // ── Navigation strip ─────────────────────────────────
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                          20,
                          compactMasthead ? 5 : 7,
                          20,
                          compactMasthead ? 6 : 8),
                      child: Row(
                        children: [
                          _NavChipItem(
                            label: 'Dashboard',
                            icon: Icons.dashboard_rounded,
                            // Always selected on this screen (current route)
                            isSelected: true,
                          ),
                          const SizedBox(width: 8),
                          _NavChipItem(
                            label: 'My Classes',
                            icon: Icons.school_rounded,
                            isSelected: false,
                            onTap: () => context.go(AppRoutes.classes),
                          ),
                          const Spacer(),
                          // Live clock chip
                          ValueListenableBuilder<DateTime>(
                            valueListenable: _nowNotifier,
                            builder: (ctx, now, _) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color:
                                      Colors.white.withValues(alpha: 0.14),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.schedule_rounded,
                                    size: 13,
                                    color: Colors.white
                                        .withValues(alpha: 0.72),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    _formatTime(now),
                                    style: TextStyle(
                                      color: Colors.white
                                          .withValues(alpha: 0.86),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: AnimatedPageBackground(
        child: Builder(builder: (context) {
          final isNarrow = MediaQuery.of(context).size.width < 720;
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: AppSpacing.paddingLg,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ValueListenableBuilder<DateTime>(
                    valueListenable: _nowNotifier,
                    builder: (context, now, _) => DashboardStoryCarousel(
                      slides: storySlides,
                      headlines: _liveDashboardHeadlines(referenceTime: now),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Top stats row (responsive)
                  if (isNarrow)
                    Column(children: [
                      _Card(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Stack(children: [
                                      CircleAvatar(
                                        radius: 28,
                                        backgroundColor: Theme.of(context)
                                            .colorScheme
                                            .primaryContainer,
                                        backgroundImage: (user?.photoBase64 !=
                                                    null &&
                                                user!.photoBase64!.isNotEmpty)
                                            ? MemoryImage(const Base64Decoder()
                                                .convert(user.photoBase64!))
                                            : null,
                                        child: (user?.photoBase64 == null ||
                                                (user?.photoBase64?.isEmpty ??
                                                    true))
                                            ? Text(
                                                (user?.fullName.isNotEmpty ??
                                                        false)
                                                    ? user!.fullName[0]
                                                        .toUpperCase()
                                                    : 'T',
                                                style: context
                                                    .textStyles.titleLarge
                                                    ?.withColor(Theme.of(
                                                            context)
                                                        .colorScheme
                                                        .onPrimaryContainer),
                                              )
                                            : null,
                                      ),
                                      Positioned(
                                        right: 0,
                                        bottom: 0,
                                        child: InkWell(
                                          onTap: _updatingTeacherPhoto
                                              ? null
                                              : _changeTeacherPhoto,
                                          child: Container(
                                            decoration: BoxDecoration(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .surface,
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                    color: Theme.of(context)
                                                        .dividerColor,
                                                    width: 0.5)),
                                            padding: const EdgeInsets.all(6),
                                            child: Icon(Icons.camera_alt,
                                                size: 18,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .primary),
                                          ),
                                        ),
                                      ),
                                    ]),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                                'Welcome, ${user?.fullName ?? 'Teacher'} 👋',
                                                style: context.textStyles
                                                    .titleMedium?.semiBold,
                                                overflow:
                                                    TextOverflow.ellipsis),
                                            const SizedBox(height: 6),
                                            ValueListenableBuilder<DateTime>(
                                              valueListenable: _nowNotifier,
                                              builder: (context, now, _) =>
                                                  Text(
                                                '${_formatDate(now)} • ${_formatTime(now)}',
                                                style: context
                                                    .textStyles.bodySmall
                                                    ?.withColor(
                                                        Theme.of(context)
                                                            .colorScheme
                                                            .onSurfaceVariant),
                                              ),
                                            ),
                                          ]),
                                    ),
                                  ]),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                icon: Icon(_selectedTimetableId == null
                                    ? Icons.upload_file
                                    : Icons.table_chart),
                                label: Text(_selectedTimetableId == null
                                    ? 'Upload Timetable'
                                    : 'Timetable'),
                                onPressed: _openTimetableDialog,
                              ),
                            ]),
                      ),
                      const SizedBox(height: 12),
                      _Card(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Quick Stats',
                                  style:
                                      context.textStyles.titleMedium?.semiBold),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 12,
                                runSpacing: 6,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.class_,
                                          size: 20,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary),
                                      const SizedBox(width: 6),
                                      Text('${_classes.length} classes'),
                                    ],
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.people_alt,
                                          size: 20,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary),
                                      const SizedBox(width: 6),
                                      Text('$_totalStudents students'),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Center(
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.class_),
                                  label: const Text('My Classes'),
                                  onPressed: () => context.go('/classes'),
                                ),
                              ),
                            ]),
                      ),
                    ])
                  else
                    IntrinsicHeight(
                      child: Row(children: [
                        Expanded(
                          child: _Card(
                            child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Stack(children: [
                                    CircleAvatar(
                                      radius: 32,
                                      backgroundColor: Theme.of(context)
                                          .colorScheme
                                          .primaryContainer,
                                      backgroundImage: (user?.photoBase64 !=
                                                  null &&
                                              user!.photoBase64!.isNotEmpty)
                                          ? MemoryImage(const Base64Decoder()
                                              .convert(user.photoBase64!))
                                          : null,
                                      child: (user?.photoBase64 == null ||
                                              (user?.photoBase64?.isEmpty ??
                                                  true))
                                          ? Text(
                                              (user?.fullName.isNotEmpty ??
                                                      false)
                                                  ? user!.fullName[0]
                                                      .toUpperCase()
                                                  : 'T',
                                              style: context
                                                  .textStyles.headlineMedium
                                                  ?.withColor(Theme.of(context)
                                                      .colorScheme
                                                      .onPrimaryContainer),
                                            )
                                          : null,
                                    ),
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: InkWell(
                                        onTap: _updatingTeacherPhoto
                                            ? null
                                            : _changeTeacherPhoto,
                                        child: Container(
                                          decoration: BoxDecoration(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .surface,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                  color: Theme.of(context)
                                                      .dividerColor,
                                                  width: 0.5)),
                                          padding: const EdgeInsets.all(6),
                                          child: Icon(Icons.camera_alt,
                                              size: 18,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary),
                                        ),
                                      ),
                                    ),
                                  ]),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                              'Welcome, ${user?.fullName ?? 'Teacher'} 👋',
                                              style: context.textStyles
                                                  .titleLarge?.semiBold),
                                          const SizedBox(height: 8),
                                          ValueListenableBuilder<DateTime>(
                                            valueListenable: _nowNotifier,
                                            builder: (context, now, _) => Text(
                                              '${_formatDate(now)} • ${_formatTime(now)}',
                                              style: context
                                                  .textStyles.bodyMedium
                                                  ?.withColor(Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant),
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          Center(
                                            child: OutlinedButton.icon(
                                              icon: Icon(
                                                  _selectedTimetableId == null
                                                      ? Icons.upload_file
                                                      : Icons.table_chart),
                                              label: Text(
                                                  _selectedTimetableId == null
                                                      ? 'Upload Timetable'
                                                      : 'Timetable'),
                                              onPressed: _openTimetableDialog,
                                            ),
                                          ),
                                        ]),
                                  ),
                                ]),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _Card(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Quick Stats',
                                      style: context
                                          .textStyles.titleLarge?.semiBold),
                                  const SizedBox(height: 8),
                                  Row(children: [
                                    Icon(Icons.class_,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary),
                                    const SizedBox(width: 6),
                                    Text('${_classes.length} classes'),
                                    const SizedBox(width: 16),
                                    Icon(Icons.people_alt,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary),
                                    const SizedBox(width: 6),
                                    Text('$_totalStudents students'),
                                  ]),
                                  const SizedBox(height: 12),
                                  Center(
                                    child: OutlinedButton.icon(
                                      icon: const Icon(Icons.class_),
                                      label: const Text('My Classes'),
                                      onPressed: () => context.go('/classes'),
                                    ),
                                  ),
                                ]),
                          ),
                        ),
                      ]),
                    ),
                  const SizedBox(height: 16),
                  const PilotFeedbackCard(
                    initialArea: 'General pilot',
                    initialRoute: '/dashboard',
                  ),
                  const SizedBox(height: 16),

                  const SizedBox(height: 12),

                  // Quick Links: horizontally scrollable row
                  _Card(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            const Icon(Icons.link_outlined),
                            const SizedBox(width: 8),
                            Text('Quick Links',
                                style:
                                    context.textStyles.titleMedium?.semiBold),
                            const Spacer(),
                            IconButton(
                              tooltip: 'Manage links',
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: _promptEditCustomLinks,
                            ),
                          ]),
                          const SizedBox(height: 8),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(children: [
                              // Attendance (editable URL)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: _LinkPill(
                                  label: 'Attendance',
                                  icon: Icons.how_to_reg_outlined,
                                  onTap: _openAttendancePortal,
                                ),
                              ),
                              // School Google Drive (they sign in with their own account)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: _LinkPill(
                                    label: 'Google Drive',
                                    icon: Icons.drive_folder_upload_outlined,
                                    onTap: () => _openExternal(
                                        'https://drive.google.com/')),
                              ),
                              // ClassroomScreen
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: _LinkPill(
                                  label: 'ClassroomScreen',
                                  icon: Icons.dashboard_customize_outlined,
                                  onTap: () => _openExternal(
                                      'https://classroomscreen.com/'),
                                ),
                              ),
                              // Custom links
                              for (int i = 0; i < _customLinks.length; i++)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: _LinkPill(
                                    label: _customLinks[i].label,
                                    icon: Icons.link,
                                    onTap: () =>
                                        _openExternal(_customLinks[i].url),
                                    onLongPress: () =>
                                        _confirmRemoveCustomLink(i),
                                  ),
                                ),
                              // Add button
                              _AddLinkPill(onTap: _promptAddQuickLink),
                            ]),
                          ),
                        ]),
                  ),

                  const SizedBox(height: 12),

                  _Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.manage_search_outlined),
                            const SizedBox(width: 8),
                            Text('Research Tools',
                                style:
                                    context.textStyles.titleMedium?.semiBold),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            SizedBox(
                              width: 420,
                              child: TextField(
                                controller: _googleSearchCtrl,
                                textInputAction: TextInputAction.search,
                                onSubmitted: (_) => _submitGoogleSearch(),
                                decoration: InputDecoration(
                                  labelText: 'Google Search',
                                  hintText: 'Type and press Enter',
                                  prefixIcon: const Icon(Icons.search),
                                  suffixIcon: IconButton(
                                    tooltip: 'Search',
                                    icon: const Icon(Icons.open_in_new),
                                    onPressed: _submitGoogleSearch,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 420,
                              child: TextField(
                                controller: _askAiCtrl,
                                textInputAction: TextInputAction.send,
                                onSubmitted: (_) => _submitAiSearch(),
                                decoration: InputDecoration(
                                  labelText: 'Ask AI',
                                  hintText:
                                      'Type your question and press Enter',
                                  prefixIcon:
                                      const Icon(Icons.auto_awesome_outlined),
                                  suffixIcon: IconButton(
                                    tooltip: 'Open',
                                    icon: const Icon(Icons.open_in_new),
                                    onPressed: _submitAiSearch,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Weekly reminders dropdown (collapsible)
                  _Card(
                    child: Theme(
                      data: Theme.of(context)
                          .copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.event_available_outlined),
                        title: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  _summaryRange == _SummaryRange.week
                                      ? "This Week's To-Dos & Reminders"
                                      : "This Month's To-Dos & Reminders",
                                  style:
                                      context.textStyles.titleMedium?.semiBold),
                              const SizedBox(height: 8),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: SegmentedButton<_SummaryRange>(
                                  segments: const [
                                    ButtonSegment(
                                        value: _SummaryRange.week,
                                        label: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text('Weekly'))),
                                    ButtonSegment(
                                        value: _SummaryRange.month,
                                        label: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text('Monthly'))),
                                  ],
                                  selected: {_summaryRange},
                                  onSelectionChanged: (s) =>
                                      setState(() => _summaryRange = s.first),
                                  style: const ButtonStyle(
                                    padding: WidgetStatePropertyAll(
                                        EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 6)),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                              ),
                            ]),
                        subtitle: Builder(builder: (ctx) {
                          final list = _periodReminders();
                          return Text(
                              '${list.length} item${list.length == 1 ? '' : 's'}',
                              style: context.textStyles.bodySmall?.withColor(
                                  Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant));
                        }),
                        children: [
                          if (_periodReminders().isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                  'No items in this period yet. Add some from the calendar below.',
                                  style: context.textStyles.bodySmall
                                      ?.withColor(Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant)),
                            )
                          else
                            ..._periodReminders().map((r) => ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  leading: Checkbox(
                                    value: r.done,
                                    onChanged: (v) {
                                      setState(() => r.done = v ?? false);
                                      unawaited(_saveReminders());
                                    },
                                  ),
                                  title: Text(
                                    r.text,
                                    overflow: TextOverflow.ellipsis,
                                    style: r.done
                                        ? context.textStyles.bodyMedium
                                            ?.copyWith(
                                                decoration:
                                                    TextDecoration.lineThrough,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurfaceVariant)
                                        : context.textStyles.bodyMedium,
                                  ),
                                  subtitle: Text(
                                      '${_weekdayLabel(r.timestamp)} • ${_formatDate(r.timestamp)}${_optionalTimeInline(r.timestamp)}${_scopeLabel(r)}'),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () {
                                      setState(() => _reminders.remove(r));
                                      unawaited(_saveReminders());
                                    },
                                  ),
                                )),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Class Tools (horizontal selector)
                  KeyedSubtree(
                    key: _classToolsSectionKey,
                    child: _Card(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              const Icon(Icons.widgets_outlined),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text('Class Tools',
                                    style: context
                                        .textStyles.titleMedium?.semiBold,
                                    overflow: TextOverflow.ellipsis),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                      maxWidth: 280, minWidth: 120),
                                  child: DropdownButtonFormField<String>(
                                    key: ValueKey(_selectedClassId),
                                    initialValue: _selectedClassId,
                                    isDense: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Class',
                                      isDense: true,
                                      border: OutlineInputBorder(),
                                    ),
                                    items: _classes
                                        .map((c) => DropdownMenuItem(
                                            value: c.id, child: Text(c.name)))
                                        .toList(),
                                    onChanged: (id) {
                                      if (id == null) return;
                                      setState(() => _selectedClassId = id);
                                      _refreshNames();
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                tooltip: 'Present on projector',
                                icon: const Icon(Icons.fullscreen),
                                onPressed: _openPresent,
                              ),
                            ]),
                            const SizedBox(height: 12),
                            if (_selectedClassId != null) ...[
                              Align(
                                alignment: Alignment.centerLeft,
                                child: OutlinedButton.icon(
                                  onPressed: _openSeatingPlan,
                                  icon: const Icon(Icons.event_seat_outlined),
                                  label: const Text('Open seating plan'),
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(children: [
                                for (int i = 0; i < _toolTabs.length; i++)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: ChoiceChip(
                                      label: Text(_toolTabs[i]),
                                      selected: _selectedToolTab == i,
                                      onSelected: (_) =>
                                          setState(() => _selectedToolTab = i),
                                    ),
                                  ),
                              ]),
                            ),
                            const SizedBox(height: 12),
                            _buildClassToolsBody(context),
                          ]),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Calendar panel - actual month grid with day selection and to-dos/reminders
                  KeyedSubtree(
                    key: _calendarSectionKey,
                    child: _Card(child: _buildCalendar(context)),
                  ),
                ]),
          );
        }),
      ),
    );
  }

  // Calendar helpers and UI
  Widget _buildCalendar(BuildContext context) {
    final monthLabel = _monthYearLabel(_focusedMonth);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final firstDayOfMonth =
        DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final firstWeekday = firstDayOfMonth.weekday; // 1=Mon..7=Sun
    final daysInMonth =
        DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0).day;
    final leadingEmpty = (firstWeekday + 6) % 7; // convert so Mon=0
    final totalCells = leadingEmpty + daysInMonth;
    final rows = (totalCells / 7).ceil();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Title row
      Row(children: [
        const Icon(Icons.event_note_outlined),
        const SizedBox(width: 8),
        Text('Calendar', style: context.textStyles.titleMedium?.semiBold),
      ]),
      const SizedBox(height: 8),
      // Month navigation row
      Row(children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => setState(() => _focusedMonth =
              DateTime(_focusedMonth.year, _focusedMonth.month - 1)),
        ),
        Expanded(
          child: Text(
            monthLabel,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: context.textStyles.titleMedium,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: () => setState(() => _focusedMonth =
              DateTime(_focusedMonth.year, _focusedMonth.month + 1)),
        ),
      ]),
      const SizedBox(height: 8),
      // Actions row (wraps on small screens)
      Wrap(spacing: 8, runSpacing: 8, children: [
        OutlinedButton.icon(
            onPressed: _importSchedule,
            icon: const Icon(Icons.file_upload_outlined),
            label: const Text('Import calendar')),
        OutlinedButton.icon(
            onPressed: _importScheduleFromDrive,
            icon: const Icon(Icons.drive_folder_upload_outlined),
            label: const Text('Google Drive')),
      ]),
      const SizedBox(height: 8),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: const [
        Expanded(child: Center(child: Text('Mon'))),
        Expanded(child: Center(child: Text('Tue'))),
        Expanded(child: Center(child: Text('Wed'))),
        Expanded(child: Center(child: Text('Thu'))),
        Expanded(child: Center(child: Text('Fri'))),
        Expanded(child: Center(child: Text('Sat'))),
        Expanded(child: Center(child: Text('Sun'))),
      ]),
      const SizedBox(height: 8),

      // Month grid
      Column(
        children: [
          for (int rr = 0; rr < rows; rr++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  for (int cc = 0; cc < 7; cc++)
                    Expanded(
                      child: Builder(builder: (ctx) {
                        final cellIndex = rr * 7 + cc;
                        final dayNum = cellIndex - leadingEmpty + 1;
                        if (dayNum < 1 || dayNum > daysInMonth) {
                          return const SizedBox(height: 44);
                        }

                        final date = DateTime(
                            _focusedMonth.year, _focusedMonth.month, dayNum);
                        final isSelected = _selectedDate != null &&
                            _isSameDate(_selectedDate!, date);
                        final isToday = _isSameDate(today, date);
                        final hasItems = _reminders
                            .any((r) => _isSameDate(r.timestamp, date));

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            onTap: () => setState(() => _selectedDate = date),
                            child: Container(
                              height: 44,
                              decoration: BoxDecoration(
                                color: isSelected || isToday
                                    ? Theme.of(context)
                                        .colorScheme
                                        .primaryContainer
                                    : Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.sm),
                                border: isToday && !isSelected
                                    ? Border.all(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                        width: 1.5,
                                      )
                                    : null,
                              ),
                              child: Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text('$dayNum',
                                        style: isToday
                                            ? context.textStyles.bodyMedium
                                                ?.copyWith(
                                                    fontWeight: FontWeight.w700)
                                            : context.textStyles.bodyMedium),
                                    if (hasItems) ...[
                                      const SizedBox(width: 6),
                                      Icon(Icons.circle,
                                          size: 8,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                ],
              ),
            ),
        ],
      ),

      const SizedBox(height: 8),

      // Selected day editor
      Builder(builder: (ctx) {
        final selected = _selectedDate;
        if (selected == null) {
          return Text('Select a day to add to-dos/reminders.',
              style: context.textStyles.bodySmall
                  ?.withColor(Theme.of(context).colorScheme.onSurfaceVariant));
        }

        final items = _reminders
            .where((r) => _isSameDate(r.timestamp, selected))
            .toList()
          ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('Selected: ${_formatDate(selected)}',
                style: context.textStyles.titleSmall?.semiBold),
            const Spacer(),
            TextButton.icon(
              onPressed: () {
                setState(() => _selectedDate = null);
              },
              icon: const Icon(Icons.close),
              label: const Text('Clear'),
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _reminderCtrl,
                decoration: const InputDecoration(
                    labelText: 'Add a reminder',
                    hintText: 'e.g., Quiz, homework, meeting...'),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: () {
                final text = _reminderCtrl.text.trim();
                if (text.isEmpty) return;
                final ts =
                    DateTime(selected.year, selected.month, selected.day);
                setState(() {
                  _reminders.add(_Reminder(text, ts, done: false));
                  _reminderCtrl.clear();
                });
                unawaited(_saveReminders());
              },
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            ),
          ]),
          const SizedBox(height: 8),
          if (items.isEmpty)
            Text('No items for this day.',
                style: context.textStyles.bodySmall
                    ?.withColor(Theme.of(context).colorScheme.onSurfaceVariant))
          else
            ...items.map((r) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Checkbox(
                    value: r.done,
                    onChanged: (v) {
                      setState(() => r.done = v ?? false);
                      unawaited(_saveReminders());
                    },
                  ),
                  title: Text(
                    r.text,
                    overflow: TextOverflow.ellipsis,
                    style: r.done
                        ? context.textStyles.bodyMedium?.copyWith(
                            decoration: TextDecoration.lineThrough,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant)
                        : context.textStyles.bodyMedium,
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () {
                      setState(() => _reminders.remove(r));
                      unawaited(_saveReminders());
                    },
                  ),
                )),
        ]);
      }),
    ]);
  }

  // Week reminders helper (7-day window starting today)
  List<_Reminder> _thisWeekReminders() {
    final anchor = DateTime.now();
    final startOfToday = DateTime(anchor.year, anchor.month, anchor.day);
    final endExclusive = startOfToday.add(const Duration(days: 7));
    bool inRange(DateTime ts) {
      final d = DateTime(ts.year, ts.month, ts.day);
      return !d.isBefore(startOfToday) && d.isBefore(endExclusive);
    }

    return _reminders.where((r) => inRange(r.timestamp)).toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  // Month reminders helper (for the month containing the anchor date)
  List<_Reminder> _thisMonthReminders() {
    final anchor = DateTime.now();
    final start = DateTime(anchor.year, anchor.month, 1);
    final end = DateTime(anchor.year, anchor.month + 1, 1);
    bool inRange(DateTime ts) {
      final d = DateTime(ts.year, ts.month, ts.day);
      return !d.isBefore(start) && d.isBefore(end);
    }

    return _reminders.where((r) => inRange(r.timestamp)).toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  List<_Reminder> _periodReminders() => _summaryRange == _SummaryRange.week
      ? _thisWeekReminders()
      : _thisMonthReminders();

  String _scopeLabel(_Reminder r) {
    if (r.classIds == null || r.classIds!.isEmpty) return ' • All classes';
    if (r.classIds!.length == 1) {
      final id = r.classIds!.first;
      final name = _classes
          .firstWhere((c) => c.id == id,
              orElse: () => _ClassBrief(id: id, name: 'Class', subtitle: ''))
          .name;
      return ' • $name';
    }
    return ' • ${r.classIds!.length} classes';
  }

  Future<void> _loadReminders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = await _readScopedPreference(
        prefs,
        scopedKey: _remindersPrefsKey(),
        legacyKey: _legacyRemindersPrefsKey,
        migrationFlagKey: _remindersMigrationFlagKey,
      );
      final list = raw == null || raw.isEmpty
          ? const <dynamic>[]
          : jsonDecode(raw) as List<dynamic>;
      final parsed = list.map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        final ids = (m['classIds'] as List?)
            ?.map((x) => x?.toString() ?? '')
            .where((s) => s.isNotEmpty)
            .cast<String>()
            .toList();
        return _Reminder(
          (m['text'] ?? '') as String,
          DateTime.tryParse(m['timestamp'] as String? ?? '') ?? DateTime.now(),
          done: (m['done'] as bool?) ?? false,
          classIds: ids == null || ids.isEmpty ? null : ids,
        );
      }).toList();
      if (!mounted) return;
      setState(() {
        _reminders
          ..clear()
          ..addAll(parsed);
      });
    } catch (e) {
      debugPrint('Failed to load reminders: $e');
    }
  }

  Future<void> _saveReminders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = _reminders
          .map((r) => {
                'text': r.text,
                'timestamp': r.timestamp.toIso8601String(),
                'done': r.done,
                'classIds': r.classIds,
              })
          .toList();
      await prefs.setString(_remindersPrefsKey(), jsonEncode(data));
    } catch (e) {
      debugPrint('Failed to save reminders: $e');
    }
  }

  String _dashboardStorageUserId() {
    return context.read<AuthService>().currentUser?.userId ?? 'local';
  }

  String _remindersPrefsKey() =>
      'dashboard_reminders_v1:${_dashboardStorageUserId()}';

  String _timetablePrefsKey() {
    final userId = _dashboardStorageUserId();
    return 'dashboard_timetables_v1:$userId';
  }

  String _selectedTimetablePrefsKey() {
    final userId = _dashboardStorageUserId();
    return 'dashboard_selected_timetable_v1:$userId';
  }

  String _attendanceUrlPrefsKey() =>
      'attendance_url_v1:${_dashboardStorageUserId()}';

  String _quickLinksPrefsKey() =>
      'custom_quick_links_v1:${_dashboardStorageUserId()}';

  Future<String?> _readScopedPreference(
    SharedPreferences prefs, {
    required String scopedKey,
    required String legacyKey,
    required String migrationFlagKey,
  }) async {
    final scopedValue = prefs.getString(scopedKey);
    if (scopedValue != null) return scopedValue;

    final alreadyMigrated = prefs.getBool(migrationFlagKey) ?? false;
    if (alreadyMigrated) return null;

    final legacyValue = prefs.getString(legacyKey);
    if (legacyValue == null) return null;

    await prefs.setString(scopedKey, legacyValue);
    await prefs.setBool(migrationFlagKey, true);
    await prefs.remove(legacyKey);
    return legacyValue;
  }

  Future<void> _loadTimetables() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_timetablePrefsKey());
      final selectedId = prefs.getString(_selectedTimetablePrefsKey());

      final parsed = <_Timetable>[];
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List<dynamic>;
        for (final e in list) {
          parsed.add(_Timetable.fromJson(Map<String, dynamic>.from(e as Map)));
        }
      }

      if (!mounted) return;
      setState(() {
        _timetables
          ..clear()
          ..addAll(parsed);
        _selectedTimetableId = selectedId;
        if (_selectedTimetableId != null &&
            !_timetables.any((t) => t.id == _selectedTimetableId)) {
          _selectedTimetableId = null;
        }
      });
    } catch (e) {
      debugPrint('Failed to load timetables: $e');
    }
  }

  Future<void> _saveTimetables() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = _timetables.map((t) => t.toJson()).toList();
      await prefs.setString(_timetablePrefsKey(), jsonEncode(data));
      if (_selectedTimetableId == null) {
        await prefs.remove(_selectedTimetablePrefsKey());
      } else {
        await prefs.setString(
            _selectedTimetablePrefsKey(), _selectedTimetableId!);
      }
    } catch (e) {
      debugPrint('Failed to save timetables: $e');
    }
  }

  Future<void> _openTimetableDialog() async {
    // If user has a selected timetable, open it directly
    if (_selectedTimetableId != null) {
      final timetable = _timetables.firstWhere(
        (t) => t.id == _selectedTimetableId,
        orElse: () => _timetables.first,
      );
      if (timetable.grid != null && timetable.grid!.isNotEmpty) {
        await _openTimetableViewer(timetable);
        return;
      }
    }

    // Otherwise show management/upload dialog
    await _showTimetableManagementDialog();
  }

  Future<void> _showTimetableManagementDialog() async {
    final theme = Theme.of(context);
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) {
          final currentSelectedId = _selectedTimetableId;
          Future<void> saveTimetableFromBytes(
              Uint8List bytes, String name, String? mimeType) async {
            final id = DateTime.now().microsecondsSinceEpoch.toString();
            List<List<String>>? grid;
            final ext = (mimeType ?? '').toLowerCase();
            if (ext == 'docx') {
              try {
                final rawGrid =
                    FileImportService().extractDocxBestTableGrid(bytes);
                grid = FileImportService().cleanTimetableGrid(rawGrid);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Could not parse DOCX timetable: $e')),
                  );
                }
              }
            } else if (ext == 'xlsx' || ext == 'csv') {
              try {
                final rows = FileImportService().rowsFromAnyBytes(bytes);
                if (rows.isNotEmpty) {
                  grid = FileImportService().cleanTimetableGrid(rows);
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Could not parse timetable table: $e')),
                  );
                }
              }
            }

            final timetable = _Timetable(
              id: id,
              name: name,
              base64: base64Encode(bytes),
              mimeType: mimeType,
              uploadedAt: DateTime.now(),
              grid: grid,
            );

            if (!mounted) return;
            setState(() {
              _timetables.add(timetable);
              _selectedTimetableId = id;
            });
            await _saveTimetables();
            if (!mounted) return;
            setLocalState(() {});
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Timetable "$name" uploaded.')),
              );
            }
          }

          return AlertDialog(
            title: const Text('Timetable Management'),
            content: SizedBox(
              width: 560,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Upload section - always visible
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer
                          .withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.upload_file,
                                color: theme.colorScheme.primary, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Upload New Timetable',
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Upload from local file or Google Drive',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton.icon(
                              icon: const Icon(Icons.add),
                              label: const Text('Choose File'),
                              onPressed: () async {
                                final picked =
                                    await FilePicker.platform.pickFiles(
                                  withData: true,
                                  type: FileType.custom,
                                  allowedExtensions: [
                                    'xlsx',
                                    'csv',
                                    'pdf',
                                    'png',
                                    'jpg',
                                    'jpeg',
                                    'docx'
                                  ],
                                );
                                if (picked == null ||
                                    picked.files.single.bytes == null) {
                                  return;
                                }
                                final bytes = picked.files.single.bytes!;
                                final name = picked.files.single.name;
                                final mimeType = picked.files.single.extension;
                                await saveTimetableFromBytes(
                                    bytes, name, mimeType);
                              },
                            ),
                            OutlinedButton.icon(
                              icon: const Icon(
                                  Icons.drive_folder_upload_outlined),
                              label: const Text('Google Drive'),
                              onPressed: () async {
                                try {
                                  if (!await _ensureDriveReady()) return;
                                  final drive =
                                      context.read<GoogleDriveService>();
                                  final picked = await showDialog<DriveFile>(
                                    context: context,
                                    builder: (ctx) => DriveFilePickerDialog(
                                      driveService: drive,
                                      allowedExtensions: const [
                                        'xlsx',
                                        'csv',
                                        'docx'
                                      ],
                                      title:
                                          'Import timetable from Google Drive',
                                    ),
                                  );
                                  if (picked == null) return;
                                  final bytes =
                                      await drive.downloadFileBytesFor(
                                    picked,
                                    preferredExportMimeType:
                                        GoogleDriveService.exportXlsxMimeType,
                                  );
                                  final ext = picked.name.contains('.')
                                      ? picked.name.split('.').last
                                      : null;
                                  await saveTimetableFromBytes(
                                      bytes, picked.name, ext);
                                } catch (e) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          'Drive timetable import failed: $e'),
                                    ),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (_timetables.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 12),
                    Text(
                      'My Timetables',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _timetables.length,
                        itemBuilder: (context, index) {
                          final t = _timetables[index];
                          final isSelected = t.id == currentSelectedId;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? theme.colorScheme.primaryContainer
                                      .withValues(alpha: 0.4)
                                  : theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected
                                    ? theme.colorScheme.primary
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              leading: Icon(
                                isSelected
                                    ? Icons.check_circle
                                    : Icons.table_chart_outlined,
                                color: isSelected
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                              title: Text(
                                t.name,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                              subtitle: Text(
                                'Uploaded ${_formatDate(t.uploadedAt)}${t.mimeType == null ? '' : ' • ${t.mimeType}'}',
                                style: theme.textTheme.bodySmall,
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (t.grid != null)
                                    IconButton(
                                      icon: const Icon(Icons.visibility),
                                      tooltip: 'View/Edit',
                                      onPressed: () async {
                                        Navigator.pop(ctx);
                                        await _openTimetableViewer(t);
                                      },
                                    ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    tooltip: 'Delete',
                                    onPressed: () async {
                                      final confirm = await showDialog<bool>(
                                        context: ctx,
                                        builder: (ctx2) => AlertDialog(
                                          title: const Text('Delete Timetable'),
                                          content: Text(
                                              'Are you sure you want to delete "${t.name}"?'),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx2, false),
                                              child: const Text('Cancel'),
                                            ),
                                            FilledButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx2, true),
                                              child: const Text('Delete'),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirm == true) {
                                        setState(() {
                                          _timetables.removeAt(index);
                                          if (_selectedTimetableId == t.id) {
                                            _selectedTimetableId = null;
                                          }
                                        });
                                        await _saveTimetables();
                                        setLocalState(() {});
                                      }
                                    },
                                  ),
                                ],
                              ),
                              onTap: () {
                                setState(() => _selectedTimetableId = t.id);
                                unawaited(_saveTimetables());
                                setLocalState(() {});
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }

  List<TimeSlotClass> _parseGridToTimeSlots(List<List<String>> grid) {
    final slots = <TimeSlotClass>[];
    if (grid.isEmpty) return slots;

    final dayMap = {
      'mon': 0,
      'monday': 0,
      'm': 0,
      'tue': 1,
      'tuesday': 1,
      'tu': 1,
      'wed': 2,
      'wednesday': 2,
      'w': 2,
      'thu': 3,
      'thursday': 3,
      'th': 3,
      'fri': 4,
      'friday': 4,
      'f': 4,
      '\u4e00': 0,
      '\u661f\u671f\u4e00': 0,
      '\u9031\u4e00': 0,
      '\u4e8c': 1,
      '\u661f\u671f\u4e8c': 1,
      '\u9031\u4e8c': 1,
      '\u4e09': 2,
      '\u661f\u671f\u4e09': 2,
      '\u9031\u4e09': 2,
      '\u56db': 3,
      '\u661f\u671f\u56db': 3,
      '\u9031\u56db': 3,
      '\u4e94': 4,
      '\u661f\u671f\u4e94': 4,
      '\u9031\u4e94': 4,
    };

    String normalizeCell(String value) =>
        value.toLowerCase().replaceAll('\u00a0', ' ').trim();

    ({int? start, int? end}) parseTimeRange(String value) {
      final match = RegExp(
        r'(\d{1,2})\s*:\s*(\d{2})(?:\s*(?:-|~)\s*(\d{1,2})\s*:\s*(\d{2}))?',
      ).firstMatch(value.replaceAll('\u00a0', ' ').trim());
      if (match == null) {
        return (start: null, end: null);
      }

      final startH = int.tryParse(match.group(1) ?? '');
      final startM = int.tryParse(match.group(2) ?? '');
      if (startH == null || startM == null) {
        return (start: null, end: null);
      }

      final start = startH * 60 + startM;
      final endH = int.tryParse(match.group(3) ?? '');
      final endM = int.tryParse(match.group(4) ?? '');
      final end = endH != null && endM != null ? (endH * 60 + endM) : null;
      return (start: start, end: end);
    }

    Map<int, int> headerDays = {};
    int headerRowIndex = -1;
    final headerScanLimit = grid.length < 4 ? grid.length : 4;
    for (int r = 0; r < headerScanLimit; r++) {
      final row = grid[r];
      final rowDays = <int, int>{};
      for (int c = 0; c < row.length; c++) {
        final norm = normalizeCell(row[c]);
        final day = dayMap[norm];
        if (day != null) {
          rowDays[c] = day;
        }
      }
      if (rowDays.length >= 3) {
        headerDays = rowDays;
        headerRowIndex = r;
        break;
      }
    }

    if (headerDays.isEmpty || headerRowIndex == -1) return slots;

    bool rowHasClassData(List<String> row) {
      for (final col in headerDays.keys) {
        if (col < row.length && row[col].trim().isNotEmpty) {
          return true;
        }
      }
      return false;
    }

    final maxCols = grid.fold<int>(
      0,
      (max, row) => row.length > max ? row.length : max,
    );
    int timeColumn = 0;
    int timeMatchCount = -1;
    for (int c = 0; c < maxCols; c++) {
      if (headerDays.containsKey(c)) continue;
      int matches = 0;
      for (int r = headerRowIndex + 1; r < grid.length; r++) {
        if (c >= grid[r].length) continue;
        if (parseTimeRange(grid[r][c]).start != null) {
          matches++;
        }
      }
      if (matches > timeMatchCount) {
        timeMatchCount = matches;
        timeColumn = c;
      }
    }

    int inferEndMinutes(int rowIndex, int startMinutes) {
      for (int r = rowIndex + 1; r < grid.length; r++) {
        final row = grid[r];
        if (timeColumn >= row.length) {
          if (rowHasClassData(row)) break;
          continue;
        }

        final candidate = parseTimeRange(row[timeColumn]).start;
        if (candidate != null && candidate > startMinutes) {
          return candidate;
        }
      }
      return startMinutes + 50;
    }

    for (int r = headerRowIndex + 1; r < grid.length; r++) {
      final row = grid[r];
      if (row.isEmpty || !rowHasClassData(row)) continue;
      if (timeColumn >= row.length) continue;

      final timeRange = parseTimeRange(row[timeColumn]);
      final startMin = timeRange.start;
      if (startMin == null) continue;
      final inferredEnd = timeRange.end ?? inferEndMinutes(r, startMin);
      final endMin = inferredEnd > startMin ? inferredEnd : startMin + 50;

      for (final entry in headerDays.entries) {
        final c = entry.key;
        if (c >= row.length) continue;
        final className = row[c].trim();
        if (className.isEmpty) continue;
        slots.add(TimeSlotClass(
          title: className,
          dayOfWeek: entry.value,
          startMinutes: startMin,
          endMinutes: endMin,
        ));
      }
    }

    return slots;
  }

  Future<void> _openTimetableViewer(_Timetable timetable) async {
    final initialGrid = timetable.grid;
    if (initialGrid == null || initialGrid.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('This timetable has no readable table grid yet.')));
      return;
    }

    // Build controllers for editing.
    final controllers = <List<TextEditingController>>[];
    for (final row in initialGrid) {
      controllers
          .add(row.map((cell) => TextEditingController(text: cell)).toList());
    }

    // Parse grid to time slots for visual display
    final timeSlots = _parseGridToTimeSlots(initialGrid);
    bool showVisual = timeSlots.isNotEmpty;

    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        child: Container(
          width: MediaQuery.of(ctx).size.width * 0.9,
          height: MediaQuery.of(ctx).size.height * 0.85,
          constraints: const BoxConstraints(maxWidth: 1200),
          child: StatefulBuilder(
            builder: (ctx, setLocalState) {
              final rows = controllers.length;
              final cols = controllers.isEmpty
                  ? 0
                  : controllers
                      .map((r) => r.length)
                      .reduce((a, b) => a > b ? a : b);

              Widget cellField(int r, int c) {
                // Bounds check to prevent IndexError
                if (r >= controllers.length || c >= controllers[r].length) {
                  return const SizedBox.shrink();
                }
                final isHeader = r == 0;
                final isFirstCol = c == 0;
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isHeader
                        ? Theme.of(ctx)
                            .colorScheme
                            .primaryContainer
                            .withValues(alpha: 0.6)
                        : isFirstCol
                            ? Theme.of(ctx).colorScheme.surfaceContainerHighest
                            : null,
                    border: Border(
                      right: BorderSide(
                        color: Theme.of(ctx)
                            .colorScheme
                            .outlineVariant
                            .withValues(alpha: 0.5),
                        width: 1,
                      ),
                      bottom: BorderSide(
                        color: Theme.of(ctx)
                            .colorScheme
                            .outlineVariant
                            .withValues(alpha: 0.5),
                        width: 1,
                      ),
                    ),
                  ),
                  child: TextField(
                    controller: controllers[r][c],
                    maxLines: isFirstCol ? 1 : 3,
                    minLines: 1,
                    textAlign: isHeader || isFirstCol
                        ? TextAlign.center
                        : TextAlign.center,
                    style: isHeader
                        ? Theme.of(ctx).textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color:
                                  Theme.of(ctx).colorScheme.onPrimaryContainer,
                              fontSize: 13,
                            )
                        : isFirstCol
                            ? Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                )
                            : Theme.of(ctx).textTheme.bodySmall?.copyWith(
                                  fontSize: 11,
                                  height: 1.3,
                                ),
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: isHeader
                          ? 'Day'
                          : isFirstCol
                              ? 'Time'
                              : 'Class',
                      hintStyle: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                            color: Theme.of(ctx)
                                .colorScheme
                                .onSurfaceVariant
                                .withValues(alpha: 0.3),
                            fontSize: 10,
                          ),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                );
              }

              return Column(
                children: [
                  // Header with toggle
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                      border: Border(
                        bottom: BorderSide(
                          color: Theme.of(ctx).colorScheme.outlineVariant,
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          showVisual ? Icons.grid_on : Icons.table_chart,
                          color: Theme.of(ctx).colorScheme.primary,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                timetable.name,
                                style: Theme.of(ctx)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                showVisual
                                    ? 'Visual timetable preview'
                                    : 'Edit cells to update your timetable',
                                style:
                                    Theme.of(ctx).textTheme.bodySmall?.copyWith(
                                          color: Theme.of(ctx)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                              ),
                            ],
                          ),
                        ),
                        if (timeSlots.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: SegmentedButton<bool>(
                              segments: const [
                                ButtonSegment(
                                    label: Text('Visual'), value: true),
                                ButtonSegment(
                                    label: Text('Edit'), value: false),
                              ],
                              selected: {showVisual},
                              onSelectionChanged: (newSelection) {
                                setLocalState(() {
                                  showVisual = newSelection.first;
                                });
                              },
                            ),
                          ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                          tooltip: 'Close',
                        ),
                      ],
                    ),
                  ),
                  // Content area
                  Expanded(
                    child: showVisual
                        ? SingleChildScrollView(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: SizedBox(
                                height: 500,
                                child: TimeSlotTimetable(
                                  classes: timeSlots,
                                  weekStart: DateTime.now(),
                                ),
                              ),
                            ),
                          )
                        : Container(
                            color: Theme.of(ctx).colorScheme.surface,
                            padding: const EdgeInsets.all(20),
                            child: Card(
                              elevation: 2,
                              clipBehavior: Clip.antiAlias,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minWidth:
                                        MediaQuery.of(ctx).size.width * 0.8,
                                  ),
                                  child: SingleChildScrollView(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        // Header row with day names
                                        if (cols > 1)
                                          IntrinsicHeight(
                                            child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.stretch,
                                              children: [
                                                for (var c = 0; c < cols; c++)
                                                  SizedBox(
                                                    width: c == 0 ? 100 : 180,
                                                    child: Container(
                                                      decoration: BoxDecoration(
                                                        color: Theme.of(ctx)
                                                            .colorScheme
                                                            .surfaceContainerHighest,
                                                        border: Border.all(
                                                          color: Theme.of(ctx)
                                                              .colorScheme
                                                              .outlineVariant,
                                                        ),
                                                      ),
                                                      padding:
                                                          const EdgeInsets.all(
                                                              8),
                                                      child: Center(
                                                        child: Text(
                                                          c == 0
                                                              ? 'Time'
                                                              : _getDayName(
                                                                  c - 1),
                                                          style: Theme.of(ctx)
                                                              .textTheme
                                                              .labelSmall
                                                              ?.copyWith(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        for (var r = 0; r < rows; r++)
                                          IntrinsicHeight(
                                            child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.stretch,
                                              children: [
                                                for (var c = 0; c < cols; c++)
                                                  SizedBox(
                                                    width: c == 0 ? 100 : 180,
                                                    child: cellField(r, c),
                                                  ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                  ),
                  // Actions
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                      border: Border(
                        top: BorderSide(
                          color: Theme.of(ctx).colorScheme.outlineVariant,
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 16,
                              color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${controllers.length} rows × ${controllers.isEmpty ? 0 : controllers.map((r) => r.length).reduce((a, b) => a > b ? a : b)} columns',
                              style:
                                  Theme.of(ctx).textTheme.bodySmall?.copyWith(
                                        color: Theme.of(ctx)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                            ),
                          ],
                        ),
                        Wrap(
                          spacing: 6,
                          alignment: WrapAlignment.end,
                          children: [
                            OutlinedButton.icon(
                              icon: const Icon(Icons.settings, size: 18),
                              label: const Text('Manage'),
                              onPressed: () async {
                                Navigator.pop(ctx);
                                await _showTimetableManagementDialog();
                              },
                            ),
                            TextButton.icon(
                              icon: const Icon(Icons.close, size: 18),
                              label: const Text('Cancel'),
                              onPressed: () => Navigator.pop(ctx),
                            ),
                            FilledButton.icon(
                              icon: const Icon(Icons.save, size: 18),
                              label: const Text('Save'),
                              onPressed: () async {
                                final newGrid = <List<String>>[];
                                for (final rowCtrls in controllers) {
                                  newGrid.add(
                                      rowCtrls.map((c) => c.text).toList());
                                }
                                if (!mounted) return;
                                setState(() {
                                  final idx = _timetables
                                      .indexWhere((t) => t.id == timetable.id);
                                  if (idx != -1) {
                                    _timetables[idx] = _Timetable(
                                      id: _timetables[idx].id,
                                      name: _timetables[idx].name,
                                      base64: _timetables[idx].base64,
                                      mimeType: _timetables[idx].mimeType,
                                      uploadedAt: _timetables[idx].uploadedAt,
                                      grid: newGrid,
                                    );
                                  }
                                });
                                await _saveTimetables();
                                if (ctx.mounted) Navigator.pop(ctx);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Timetable saved successfully')),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );

    for (final rowCtrls in controllers) {
      for (final c in rowCtrls) {
        c.dispose();
      }
    }
  }

  String _weekdayLabel(DateTime d) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[(d.weekday + 6) % 7];
  }

  String _getDayName(int columnIndex) {
    const names = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    if (columnIndex >= 0 && columnIndex < names.length) {
      return names[columnIndex];
    }
    return 'Day ${columnIndex + 1}';
  }

  bool _isSameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
  String _monthYearLabel(DateTime d) => '${_monthName(d.month)} ${d.year}';
  String _monthName(int m) {
    const names = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return names[m - 1];
  }

  String _formatDate(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';
  String _formatTime(DateTime d) =>
      '${_two(d.hour)}:${_two(d.minute)}:${_two(d.second)}';
  String _two(int v) => v.toString().padLeft(2, '0');
  String _shortMonthDay(DateTime d) =>
      '${_monthName(d.month).substring(0, 3)} ${d.day}';

  // Show HH:MM only when a specific time is set; hide when all-day (00:00)
  String _formatHourMinute(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';
  String _optionalTimeInline(DateTime d) =>
      (d.hour == 0 && d.minute == 0 && d.second == 0)
          ? ''
          : '  ${_formatHourMinute(d)}';

  _ClassBrief? _selectedClassBrief() {
    final classId = _selectedClassId;
    if (classId == null) return null;
    for (final classItem in _classes) {
      if (classItem.id == classId) return classItem;
    }
    return null;
  }

  _Reminder? _nextOpenReminder() {
    final pending = _reminders.where((r) => !r.done).toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return pending.isEmpty ? null : pending.first;
  }

  List<_Reminder> _pendingReminders() {
    final pending = _reminders.where((r) => !r.done).toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return pending;
  }

  bool _isSchoolWideReminder(_Reminder reminder) =>
      reminder.classIds == null || reminder.classIds!.isEmpty;

  List<_Reminder> _schoolWideReminders() =>
      _pendingReminders().where(_isSchoolWideReminder).toList();

  _Reminder? _nextSchoolWideReminder() {
    final schoolWide = _schoolWideReminders();
    return schoolWide.isEmpty ? null : schoolWide.first;
  }

  ClassScheduleItem? _nextUpcomingScheduleItem() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final candidates =
        _scheduleByClass.values.expand((items) => items).where((item) {
      if (item.date == null) return false;
      final date = DateTime(item.date!.year, item.date!.month, item.date!.day);
      return !date.isBefore(today);
    }).toList()
          ..sort((a, b) => a.date!.compareTo(b.date!));
    return candidates.isEmpty ? null : candidates.first;
  }

  _Timetable? _selectedTimetable() {
    final timetableId = _selectedTimetableId;
    if (timetableId == null) return null;
    for (final timetable in _timetables) {
      if (timetable.id == timetableId) return timetable;
    }
    return null;
  }

  List<TimeSlotClass> _selectedTimetableClasses() {
    final grid = _selectedTimetable()?.grid;
    if (grid == null || grid.isEmpty) return const <TimeSlotClass>[];
    return _parseGridToTimeSlots(grid);
  }

  List<_TimetableSlotMoment> _timetableMoments(DateTime referenceTime) {
    final classes = _selectedTimetableClasses();
    if (classes.isEmpty) return const <_TimetableSlotMoment>[];

    final today = DateTime(
      referenceTime.year,
      referenceTime.month,
      referenceTime.day,
    );
    final monday = today.subtract(Duration(days: referenceTime.weekday - 1));
    final moments = <_TimetableSlotMoment>[];

    for (final timetableClass in classes) {
      for (final weekOffset in const [0, 7]) {
        final day =
            monday.add(Duration(days: timetableClass.dayOfWeek + weekOffset));
        final dayStart = DateTime(day.year, day.month, day.day);
        final startAt = dayStart.add(
          Duration(minutes: timetableClass.startMinutes),
        );
        final endAt = dayStart.add(
          Duration(minutes: timetableClass.endMinutes),
        );
        moments.add(
          _TimetableSlotMoment(
            timetableClass: timetableClass,
            startAt: startAt,
            endAt: endAt,
          ),
        );
      }
    }

    moments.sort((a, b) => a.startAt.compareTo(b.startAt));
    return moments;
  }

  _TimetableSlotMoment? _currentTimetableClass(DateTime referenceTime) {
    for (final moment in _timetableMoments(referenceTime)) {
      if (!referenceTime.isBefore(moment.startAt) &&
          referenceTime.isBefore(moment.endAt)) {
        return moment;
      }
    }
    return null;
  }

  _TimetableSlotMoment? _nextTimetableClass(DateTime referenceTime) {
    for (final moment in _timetableMoments(referenceTime)) {
      if (!moment.startAt.isBefore(referenceTime)) {
        return moment;
      }
    }
    return null;
  }

  String _relativeTimetableTime(DateTime target, DateTime referenceTime) {
    final targetDay = DateTime(target.year, target.month, target.day);
    final referenceDay = DateTime(
      referenceTime.year,
      referenceTime.month,
      referenceTime.day,
    );
    final dayDifference = targetDay.difference(referenceDay).inDays;
    final timeLabel = _formatHourMinute(target);
    if (dayDifference == 0) return 'today at $timeLabel';
    if (dayDifference == 1) return 'tomorrow at $timeLabel';
    return '${_weekdayLabel(target)} at $timeLabel';
  }

  String _reminderScopeText(_Reminder reminder) {
    if (_isSchoolWideReminder(reminder)) return 'School-wide';
    if (reminder.classIds!.length == 1) {
      final classId = reminder.classIds!.first;
      return _classes
          .firstWhere(
            (c) => c.id == classId,
            orElse: () => _ClassBrief(id: classId, name: 'Class', subtitle: ''),
          )
          .name;
    }
    return '${reminder.classIds!.length} classes';
  }

  String _headlineSafe(String value, {int maxLength = 86}) {
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= maxLength) return normalized;
    return '${normalized.substring(0, maxLength - 1)}...';
  }

  String _relativeFromNow(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    if (difference.inMinutes < 1) return 'just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return _shortMonthDay(dateTime);
  }

  String _weatherCodeLabel(int code) {
    if (code == 0) return 'Clear';
    if (code == 1) return 'Mostly clear';
    if (code == 2) return 'Partly cloudy';
    if (code == 3) return 'Cloudy';
    if (code == 45 || code == 48) return 'Fog';
    if (code >= 51 && code <= 57) return 'Drizzle';
    if (code >= 61 && code <= 67) return 'Rain';
    if (code >= 71 && code <= 77) return 'Snow';
    if (code >= 80 && code <= 82) return 'Showers';
    if (code >= 85 && code <= 86) return 'Snow showers';
    if (code >= 95) return 'Thunderstorms';
    return 'Forecast';
  }

  IconData _weatherCodeIcon(int code) {
    if (code == 0) return Icons.wb_sunny_rounded;
    if (code == 1 || code == 2) return Icons.wb_cloudy_outlined;
    if (code == 3) return Icons.cloud_rounded;
    if (code == 45 || code == 48) return Icons.blur_on_rounded;
    if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82)) {
      return Icons.water_drop_outlined;
    }
    if (code >= 71 && code <= 86) return Icons.ac_unit_rounded;
    if (code >= 95) return Icons.thunderstorm_rounded;
    return Icons.cloud_queue_rounded;
  }

  String _forecastChip(DashboardForecastDay day) {
    return '${_weekdayLabel(day.date)} ${day.maxTempC.round()}°/${day.minTempC.round()}°';
  }

  Future<void> _scrollToSection(GlobalKey key) async {
    final targetContext = key.currentContext;
    if (targetContext == null) return;
    await Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeInOutCubic,
      alignment: 0.08,
    );
  }

  List<DashboardStorySlide> _dashboardStorySlides(BuildContext context) {
    final worldLead =
        _worldNewsStories.isNotEmpty ? _worldNewsStories.first : null;
    final localLead =
        _localNewsStories.isNotEmpty ? _localNewsStories.first : null;
    final leadStory = worldLead ?? localLead;
    final weather = _weatherSnapshot;
    final pendingReminders = _pendingReminders();
    final nextReminder =
        pendingReminders.isNotEmpty ? pendingReminders.first : null;
    final nextSchoolEvent = _nextSchoolWideReminder();
    final nextScheduleItem = _nextUpcomingScheduleItem();
    final openReminders = pendingReminders.length;
    final schoolWideCount = _schoolWideReminders().length;
    final forecast = weather?.forecast ?? const <DashboardForecastDay>[];
    final weatherDetailsUrl = _dashboardWeatherService.detailsUrl(
      locationName: weather?.locationName ?? 'Taichung City',
    );
    final weatherChips = <String>[
      if (forecast.isNotEmpty) _forecastChip(forecast[0]),
      if (forecast.length > 1) _forecastChip(forecast[1]),
      if (forecast.length > 2) _forecastChip(forecast[2]),
    ];
    final eventLead = nextSchoolEvent ?? nextReminder;
    final eventDate = eventLead?.timestamp ?? nextScheduleItem?.date;
    final followUpReminder =
        pendingReminders.length > 1 ? pendingReminders[1] : null;

    return [
      DashboardStorySlide(
        overline: 'World & Local News',
        title: _newsBusy && leadStory == null
            ? 'Loading the live news desk...'
            : leadStory != null
                ? _headlineSafe(leadStory.title, maxLength: 92)
                : 'World and local headlines will appear here as soon as the live feeds respond.',
        description: leadStory != null
            ? [
                if (worldLead != null && localLead != null)
                  'The world desk is live, and the Taiwan desk is tracking "${_headlineSafe(localLead.title, maxLength: 84)}".',
                if (worldLead != null && localLead == null)
                  'The world desk is live now with fresh international coverage.',
                if (localLead != null && worldLead == null)
                  'The local desk is live now with Taiwan-facing headlines.',
                'Use the story buttons below or tap the visual panel to open the full article.',
              ].join(' ')
            : (_newsError != null
                ? 'The news feeds are temporarily unavailable. This panel will keep retrying automatically in the background.'
                : 'This panel blends world coverage with local Taiwan headlines so the dashboard feels useful the moment it opens.'),
        chips: [
          if (worldLead != null) 'World • ${worldLead.source}',
          if (localLead != null) 'Local • ${localLead.source}',
          if (leadStory != null) _relativeFromNow(leadStory.publishedAt),
          if (leadStory != null && leadStory.commentCount > 0)
            '${leadStory.commentCount} comments',
          if (leadStory != null &&
              leadStory.commentCount == 0 &&
              leadStory.score == 0)
            'Live desk',
          if (leadStory == null && _newsBusy) 'Refreshing',
        ],
        visualLabel: leadStory != null
            ? (leadStory.desk == DashboardNewsDesk.local
                ? 'Local desk'
                : 'World desk')
            : 'Status',
        visualValue: leadStory != null ? leadStory.source : 'Stand by',
        visualCaption: leadStory != null
            ? worldLead != null && localLead != null
                ? 'Primary story opens the world desk. Use the second button for the local desk.'
                : leadStory.score > 0
                    ? '${leadStory.score} upvotes • tap through for the full story'
                    : 'Tap through for the latest coverage from this news desk.'
            : 'Live world and local updates will fill this panel automatically when the feeds return.',
        icon: Icons.public_rounded,
        visual: DashboardStoryVisual.spotlight,
        imageAssetPath: _worldHeroImageAsset,
        imageUrl: leadStory?.imageUrl ?? localLead?.imageUrl,
        ctaLabel: worldLead != null
            ? 'Open world story'
            : (localLead != null ? 'Open story' : null),
        secondaryCtaLabel:
            worldLead != null && localLead != null ? 'Open local story' : null,
        onTap: worldLead != null
            ? () => _openExternal(worldLead.url)
            : (localLead != null ? () => _openExternal(localLead.url) : null),
        onSecondaryTap: worldLead != null && localLead != null
            ? () => _openExternal(localLead.url)
            : null,
      ),
      DashboardStorySlide(
        overline: 'Weather & Forecast',
        title: weather == null
            ? (_weatherBusy
                ? 'Loading campus weather...'
                : 'Campus forecast is standing by.')
            : '${weather.locationName} is ${weather.temperatureC.round()}° right now with ${_weatherCodeLabel(weather.weatherCode).toLowerCase()}.',
        description: weather == null
            ? (_weatherError != null
                ? 'The local forecast is temporarily unavailable. This panel refreshes automatically, so it should recover on the next pass.'
                : 'Current temperature, feel-like temperature, wind, and the next few days will live here.')
            : 'Feels like ${weather.apparentTempC.round()}°, wind ${weather.windSpeedKph.round()} km/h, with the next days ready for quick planning before class starts. Tap through for the fuller forecast.',
        chips: weatherChips.isNotEmpty
            ? weatherChips
            : [
                if (_weatherBusy) 'Refreshing',
                if (!_weatherBusy) 'Forecast pending',
              ],
        visualLabel: weather != null ? 'Current' : 'Forecast',
        visualValue:
            weather != null ? '${weather.temperatureC.round()}°' : '--',
        visualCaption: weather != null
            ? '${_weatherCodeLabel(weather.weatherCode)} • updated ${_relativeFromNow(weather.observedAt)}'
            : 'Open-Meteo forecast for Taichung refreshes automatically in the background.',
        icon: _weatherCodeIcon(weather?.weatherCode ?? 1),
        visual: DashboardStoryVisual.campus,
        imageAssetPath: _weatherHeroImageAsset,
        ctaLabel: 'View full forecast',
        secondaryCtaLabel: 'Refresh',
        onTap: () => _openExternal(weatherDetailsUrl),
        onSecondaryTap: _loadWeatherForecast,
      ),
      DashboardStorySlide(
        overline: 'Upcoming Events',
        title: eventLead != null
            ? _headlineSafe(eventLead.text, maxLength: 86)
            : nextScheduleItem != null
                ? _headlineSafe(nextScheduleItem.title, maxLength: 86)
                : 'Upcoming events and school moments will appear here.',
        description: eventLead != null
            ? [
                'Next up on ${_shortMonthDay(eventLead.timestamp)}${_optionalTimeInline(eventLead.timestamp)} for ${_reminderScopeText(eventLead)}.',
                if (nextSchoolEvent != null &&
                    nextReminder != null &&
                    nextSchoolEvent != nextReminder)
                  'The next school-wide moment is "${_headlineSafe(nextSchoolEvent.text, maxLength: 72)}".',
                if (nextScheduleItem != null && nextScheduleItem.date != null)
                  'Class timeline: ${_shortMonthDay(nextScheduleItem.date!)} ${_headlineSafe(nextScheduleItem.title, maxLength: 64)}.',
              ].join(' ')
            : nextScheduleItem != null && nextScheduleItem.date != null
                ? 'The next dated class timeline item lands on ${_shortMonthDay(nextScheduleItem.date!)}. Open the calendar below to keep the broader school plan in view.'
                : 'Use the calendar and reminder tools below to pin personal reminders, school events, and things coming up. This panel will keep the next important item in view.',
        chips: [
          '$openReminders upcoming',
          if (schoolWideCount > 0) '$schoolWideCount school-wide',
          if (nextScheduleItem?.date != null)
            _shortMonthDay(nextScheduleItem!.date!),
          'Calendar',
        ],
        visualLabel: nextSchoolEvent != null
            ? 'School-wide'
            : eventLead != null
                ? _reminderScopeText(eventLead)
                : nextScheduleItem != null
                    ? 'Class timeline'
                    : 'Events',
        visualValue: eventDate != null ? _shortMonthDay(eventDate) : 'Clear',
        visualCaption: followUpReminder != null
            ? 'After that: ${_shortMonthDay(followUpReminder.timestamp)} ${_headlineSafe(followUpReminder.text, maxLength: 62)}'
            : nextScheduleItem != null
                ? _headlineSafe(nextScheduleItem.title, maxLength: 70)
                : 'A clear runway gives you room to teach, improvise, and still stay ahead of what is coming up.',
        icon: Icons.event_note_rounded,
        visual: DashboardStoryVisual.studio,
        imageAssetPath: _eventsHeroImageAsset,
        ctaLabel: 'Open calendar',
        secondaryCtaLabel: nextScheduleItem != null ? 'Class timeline' : null,
        onTap: () => _scrollToSection(_calendarSectionKey),
        onSecondaryTap: nextScheduleItem != null
            ? () => _scrollToSection(_classToolsSectionKey)
            : null,
      ),
    ];
  }

  List<String> _liveDashboardHeadlines({DateTime? referenceTime}) {
    final now = referenceTime ?? DateTime.now();
    final items = <String>[];
    final selectedClass = _selectedClassBrief();
    final nextReminder = _nextOpenReminder();
    final nextSchoolEvent = _nextSchoolWideReminder();
    final nextScheduleItem = _nextUpcomingScheduleItem();
    final currentTimetableClass = _currentTimetableClass(now);
    final nextTimetableClass = _nextTimetableClass(now);
    final weather = _weatherSnapshot;

    if (currentTimetableClass != null) {
      final nextLabel = nextTimetableClass != null
          ? ' • next ${_headlineSafe(nextTimetableClass.timetableClass.title, maxLength: 42)} ${_relativeTimetableTime(nextTimetableClass.startAt, now)}'
          : '';
      items.add(
        'Now teaching • ${_headlineSafe(currentTimetableClass.timetableClass.title, maxLength: 54)} until ${_formatHourMinute(currentTimetableClass.endAt)}$nextLabel',
      );
    } else if (nextTimetableClass != null) {
      items.add(
        'Next class • ${_relativeTimetableTime(nextTimetableClass.startAt, now)} • ${_headlineSafe(nextTimetableClass.timetableClass.title, maxLength: 68)}',
      );
    }

    if (_worldNewsStories.isNotEmpty) {
      for (final story in _worldNewsStories.take(2)) {
        items.add(
          'World news • ${story.source} • ${_headlineSafe(story.title)}',
        );
      }
    }

    if (_localNewsStories.isNotEmpty) {
      for (final story in _localNewsStories.take(2)) {
        items.add(
          'Local news • ${story.source} • ${_headlineSafe(story.title)}',
        );
      }
    } else if (_worldNewsStories.isEmpty && _newsBusy) {
      items.add('World news panel is refreshing the latest headlines...');
    } else if (_worldNewsStories.isEmpty && _newsError != null) {
      items.add(
        'World and local news feeds are temporarily offline. Auto-refresh will retry.',
      );
    }

    if (weather != null) {
      final nextDay = weather.forecast.length > 1 ? weather.forecast[1] : null;
      items.add(
        'Weather • ${weather.locationName} ${weather.temperatureC.round()}° • ${_weatherCodeLabel(weather.weatherCode)}${nextDay != null ? ' • ${_weekdayLabel(nextDay.date)} ${nextDay.maxTempC.round()}°/${nextDay.minTempC.round()}°' : ''}',
      );
    } else if (_weatherBusy) {
      items.add(
        'Weather panel is refreshing the current forecast for Taichung.',
      );
    } else if (_weatherError != null) {
      items.add(
        'Weather feed is temporarily unavailable. Forecast refresh will retry.',
      );
    }

    if (nextSchoolEvent != null) {
      items.add(
        'School event • ${_shortMonthDay(nextSchoolEvent.timestamp)} • ${_headlineSafe(nextSchoolEvent.text)}',
      );
    }

    if (nextReminder != null) {
      items.add(
        'Coming up • ${_shortMonthDay(nextReminder.timestamp)} • ${_headlineSafe(nextReminder.text)}',
      );
    } else if (nextScheduleItem?.date != null) {
      items.add(
        'Class timeline • ${_shortMonthDay(nextScheduleItem!.date!)} • ${_headlineSafe(nextScheduleItem.title)}',
      );
    } else {
      items.add(
        'Upcoming events • no urgent reminders right now • add messages from the calendar below',
      );
    }

    if (_classes.isNotEmpty || _totalStudents > 0) {
      items.add(
        '${_classes.length} classes live across $_totalStudents students in your workspace',
      );
    }

    if (selectedClass != null) {
      items.add(
        'Focused class • ${selectedClass.name} • ready for tools, seating, and schedule work',
      );
    }

    items.add(
      'Quick polls, QR, timers, groups, and reminders are all one jump below the hero rail',
    );
    return items;
  }

  void _openSeatingPlan() {
    final classId = _selectedClassId;
    if (classId == null) return;
    context.push('/class/$classId/seating');
  }

  // ===== Class Tools UI builder =====
  Widget _buildClassToolsBody(BuildContext context) {
    switch (_selectedToolTab) {
      case 0:
        return _buildNamePicker(context);
      case 1:
        return _buildGroups(context);
      case 2:
        return _buildParticipation(context);
      case 3:
        return _buildScheduleTool(context);
      case 4:
        return _buildQuickPoll(context);
      case 5:
        return _buildTimerTool(context);
      case 6:
        return _buildQrTool(context);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildScheduleTool(BuildContext context) {
    final classId = _selectedClassId;
    if (classId == null) {
      return Text('Select a class to view its schedule.',
          style: context.textStyles.bodySmall
              ?.withColor(Theme.of(context).colorScheme.onSurfaceVariant));
    }

    final className = _classes
        .firstWhere((c) => c.id == classId,
            orElse: () => _ClassBrief(id: classId, name: 'Class', subtitle: ''))
        .name;
    final items = _scheduleByClass[classId] ?? const <ClassScheduleItem>[];

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final upcoming = items.where((i) {
      if (i.date == null) return false;
      final d = DateTime(i.date!.year, i.date!.month, i.date!.day);
      return !d.isBefore(today);
    }).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.menu_book_outlined),
        const SizedBox(width: 8),
        Expanded(
            child: Text('Schedule - $className',
                style: context.textStyles.titleSmall?.semiBold)),
        OutlinedButton.icon(
          onPressed: _scheduleBusy ? null : _importClassSchedule,
          icon: const Icon(Icons.drive_folder_upload_outlined),
          label: Text(_scheduleBusy ? 'Importing...' : 'Upload'),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: _scheduleBusy ? null : _importClassScheduleFromDrive,
          icon: const Icon(Icons.folder_shared_outlined),
          label: const Text('Google Drive'),
        ),
      ]),
      const SizedBox(height: 10),
      if (items.isEmpty)
        Text(
            'No schedule saved for this class yet. Upload the class plan (CSV/XLSX) to view it neatly here.',
            style: context.textStyles.bodySmall
                ?.withColor(Theme.of(context).colorScheme.onSurfaceVariant))
      else ...[
        Text('Next up', style: context.textStyles.titleSmall?.semiBold),
        const SizedBox(height: 6),
        if (upcoming.isEmpty)
          Text(
              'No upcoming dated items found. (If your file uses weeks instead of dates, scroll down to Semester.)',
              style: context.textStyles.bodySmall
                  ?.withColor(Theme.of(context).colorScheme.onSurfaceVariant))
        else
          ...upcoming.take(5).map((i) => _scheduleTile(context, i)),
        const SizedBox(height: 12),
        Text('Semester', style: context.textStyles.titleSmall?.semiBold),
        const SizedBox(height: 6),
        ..._buildSemesterScheduleList(context, items),
      ]
    ]);
  }

  Widget _scheduleTile(BuildContext context, ClassScheduleItem item) {
    final when = item.date != null
        ? _formatDate(item.date!)
        : (item.week != null ? 'Week ${item.week}' : '');

    final subtitleParts = <String>[];
    final book = item.details['Book'];
    final unit = item.details['Chapter/Unit'];
    final hw = item.details['Homework'];
    final assess = item.details['Assessment'];
    if (book != null && book.trim().isNotEmpty) subtitleParts.add(book.trim());
    if (unit != null && unit.trim().isNotEmpty) subtitleParts.add(unit.trim());
    if (hw != null && hw.trim().isNotEmpty) {
      subtitleParts.add('HW: ${hw.trim()}');
    }
    if (assess != null && assess.trim().isNotEmpty) {
      subtitleParts.add('Assess: ${assess.trim()}');
    }

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: when.isEmpty
          ? null
          : SizedBox(
              width: 86,
              child: Text(when,
                  style: context.textStyles.labelMedium?.withColor(
                      Theme.of(context).colorScheme.onSurfaceVariant))),
      title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: subtitleParts.isEmpty
          ? null
          : Text(subtitleParts.join(' • '),
              maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: () => _showScheduleItemDetails(item),
    );
  }

  List<Widget> _buildSemesterScheduleList(
      BuildContext context, List<ClassScheduleItem> items) {
    final hasDates = items.any((i) => i.date != null);
    final widgets = <Widget>[];

    if (hasDates) {
      final byMonth = <String, List<ClassScheduleItem>>{};
      for (final i in items) {
        if (i.date == null) continue;
        final key = '${i.date!.year}-${_two(i.date!.month)}';
        byMonth.putIfAbsent(key, () => []).add(i);
      }
      final keys = byMonth.keys.toList()..sort();
      for (final k in keys) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 2),
          child: Text(k, style: context.textStyles.labelLarge?.semiBold),
        ));
        for (final i in byMonth[k]!
          ..sort((a, b) => a.date!.compareTo(b.date!))) {
          widgets.add(_scheduleTile(context, i));
        }
      }
      return widgets;
    }

    final byWeek = <int, List<ClassScheduleItem>>{};
    final unknown = <ClassScheduleItem>[];
    for (final i in items) {
      if (i.week != null) {
        byWeek.putIfAbsent(i.week!, () => []).add(i);
      } else {
        unknown.add(i);
      }
    }
    final weeks = byWeek.keys.toList()..sort();
    for (final w in weeks) {
      widgets.add(Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 2),
        child: Text('Week $w', style: context.textStyles.labelLarge?.semiBold),
      ));
      for (final i in byWeek[w]!) {
        widgets.add(_scheduleTile(context, i));
      }
    }
    if (unknown.isNotEmpty) {
      widgets.add(Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 2),
        child: Text('Other', style: context.textStyles.labelLarge?.semiBold),
      ));
      for (final i in unknown) {
        widgets.add(_scheduleTile(context, i));
      }
    }
    return widgets;
  }

  Future<void> _showScheduleItemDetails(ClassScheduleItem item) async {
    final when = item.date != null
        ? _formatDate(item.date!)
        : (item.week != null ? 'Week ${item.week}' : '');

    final detailsLines = <String>[];
    for (final entry in item.details.entries) {
      if (entry.key.trim().isEmpty || entry.value.trim().isEmpty) continue;
      detailsLines.add('${entry.key}: ${entry.value}');
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(item.title),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: SelectableText(
              [
                if (when.isNotEmpty) when,
                if (detailsLines.isNotEmpty) detailsLines.join('\n'),
              ].where((s) => s.trim().isNotEmpty).join('\n\n'),
            ),
          ),
        ),
        actions: [
          FilledButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Close'))
        ],
      ),
    );
  }

  Future<void> _openPresent() async {
    // Full-screen overlay to present the currently selected Class Tool
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return Scaffold(
              backgroundColor: Colors.transparent,
              body: SafeArea(
                child: Stack(children: [
                  // Center content
                  Positioned.fill(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Theme.of(ctx).colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      margin: const EdgeInsets.all(16),
                      child: _buildPresentBody(ctx, setDialogState),
                    ),
                  ),
                  // Close button
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton(
                      style: IconButton.styleFrom(
                          backgroundColor: Theme.of(ctx).colorScheme.surface),
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ),
                ]),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPresentBody(BuildContext ctx, StateSetter setDialogState) {
    switch (_selectedToolTab) {
      // Name picker: giant text and a big Next button
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(children: [
              const Icon(Icons.casino_outlined),
              const SizedBox(width: 8),
              Text('Name Picker', style: Theme.of(ctx).textTheme.titleLarge)
            ]),
            const SizedBox(height: 24),
            Expanded(
              child: Center(
                child: Text(
                  _pickedName == null
                      ? 'Tap Next to pick a student'
                      : _pickedName!,
                  textAlign: TextAlign.center,
                  style: Theme.of(ctx)
                      .textTheme
                      .displaySmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              FilledButton.icon(
                onPressed: () {
                  _pickRandomName();
                  setDialogState(() {});
                },
                icon: const Icon(Icons.play_arrow),
                label: const Text('Next Student'),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                  onPressed: () => Navigator.of(ctx).pop(),
                  icon: const Icon(Icons.close),
                  label: const Text('Close')),
            ]),
          ],
        );

      // Groups: show groups big; allow regenerate and quick pairs
      case 1:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.groups_outlined),
            const SizedBox(width: 8),
            Text('Group Maker', style: Theme.of(ctx).textTheme.titleLarge)
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            SizedBox(
              width: 120,
              child: TextField(
                decoration: const InputDecoration(
                    labelText: 'Group Size', isDense: true),
                keyboardType: TextInputType.number,
                onChanged: (v) =>
                    setState(() => _groupSize = int.tryParse(v) ?? 2),
              ),
            ),
            FilledButton.icon(
              onPressed: () {
                _makeGroups();
                setDialogState(() {});
              },
              icon: const Icon(Icons.grid_view),
              label: const Text('Generate'),
            ),
            OutlinedButton.icon(
              onPressed: () {
                setState(() => _groupSize = 2);
                _makeGroups();
                setDialogState(() {});
              },
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Pairs'),
            ),
          ]),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: Wrap(spacing: 12, runSpacing: 12, children: [
                for (int i = 0; i < _groups.length; i++)
                  Container(
                    width: 360,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(ctx).colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: Theme.of(ctx).colorScheme.outlineVariant),
                    ),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Group ${i + 1}',
                              style: Theme.of(ctx)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          ..._groups[i].map((n) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(n,
                                    style: Theme.of(ctx).textTheme.titleSmall),
                              )),
                        ]),
                  ),
              ]),
            ),
          ),
          Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                  onPressed: () => Navigator.of(ctx).pop(),
                  icon: const Icon(Icons.close),
                  label: const Text('Close'))),
        ]);

      // Participation: allow increment/reset in present mode
      case 2:
        final part = _participationForClass();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.emoji_people_outlined),
            const SizedBox(width: 8),
            Text('Participation', style: Theme.of(ctx).textTheme.titleLarge)
          ]),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: Wrap(spacing: 12, runSpacing: 12, children: [
                for (final n in _currentNames)
                  Container(
                    width: 360,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Theme.of(ctx).colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: Theme.of(ctx).colorScheme.outlineVariant),
                    ),
                    child: Row(children: [
                      Expanded(
                        child: Text(
                          n,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(ctx).textTheme.titleSmall,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Theme.of(ctx).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${part[n] ?? 0}',
                          style: Theme.of(ctx)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: () {
                          setState(() => part[n] = (part[n] ?? 0) + 1);
                          setDialogState(() {});
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Add'),
                      ),
                      const SizedBox(width: 4),
                      OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            final current = part[n] ?? 0;
                            if (current > 0) {
                              part[n] = current - 1;
                            }
                          });
                          setDialogState(() {});
                        },
                        icon: const Icon(Icons.remove),
                        label: const Text('Remove'),
                      ),
                    ]),
                  ),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  for (final n in _currentNames) {
                    part[n] = 0;
                  }
                });
                setDialogState(() {});
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Reset'),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => Navigator.of(ctx).pop(),
              icon: const Icon(Icons.close),
              label: const Text('Close'),
            ),
          ]),
        ]);

      // Schedule: not presented full-screen (keeps tab mapping consistent)
      case 3:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.event_note_outlined),
            const SizedBox(width: 8),
            Text('Schedule', style: Theme.of(ctx).textTheme.titleLarge)
          ]),
          const SizedBox(height: 16),
          Expanded(
            child: Center(
              child: Text(
                'Schedule is available on the dashboard (Calendar).',
                style: Theme.of(ctx).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => Navigator.of(ctx).pop(),
              icon: const Icon(Icons.close),
              label: const Text('Close'),
            ),
          ),
        ]);

      // Quick Poll: large buttons and bars
      case 4:
        final map = _pollCountsForClass();
        int total = (map['A'] ?? 0) +
            (map['B'] ?? 0) +
            (map['C'] ?? 0) +
            (map['D'] ?? 0);
        Widget bigButton(String label) => FilledButton(
              onPressed: () {
                _vote(label);
                setDialogState(() {});
              },
              child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  child: Text(label,
                      style: Theme.of(ctx)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700))),
            );
        Widget bar(String label) {
          final v = map[label] ?? 0;
          final pct = total == 0 ? 0.0 : v / total;
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$label  ($v)', style: Theme.of(ctx).textTheme.titleSmall),
                const SizedBox(height: 6),
                LayoutBuilder(builder: (c, s) {
                  return Stack(children: [
                    Container(
                        height: 14,
                        width: s.maxWidth,
                        decoration: BoxDecoration(
                            color: Theme.of(ctx).colorScheme.surfaceContainer,
                            borderRadius: BorderRadius.circular(10))),
                    AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 14,
                        width: s.maxWidth * pct,
                        decoration: BoxDecoration(
                            color: Theme.of(ctx).colorScheme.primary,
                            borderRadius: BorderRadius.circular(10))),
                  ]);
                }),
              ]);
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.poll_outlined),
            const SizedBox(width: 8),
            Text('Quick Poll', style: Theme.of(ctx).textTheme.titleLarge)
          ]),
          const SizedBox(height: 16),
          Wrap(spacing: 12, children: [
            bigButton('A'),
            bigButton('B'),
            bigButton('C'),
            bigButton('D'),
            OutlinedButton.icon(
              onPressed: () {
                _resetPoll();
                setDialogState(() {});
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Reset'),
            ),
          ]),
          const SizedBox(height: 16),
          bar('A'),
          const SizedBox(height: 10),
          bar('B'),
          const SizedBox(height: 10),
          bar('C'),
          const SizedBox(height: 10),
          bar('D'),
          const Spacer(),
          Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                  onPressed: () => Navigator.of(ctx).pop(),
                  icon: const Icon(Icons.close),
                  label: const Text('Close'))),
        ]);

      // Timer: large stopwatch/countdown
      case 5:
        String fmt(int s) {
          final m = s ~/ 60;
          final r = s % 60;
          return '${_two(m)}:${_two(r)}';
        }
        return SingleChildScrollView(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Row(children: [
              const Icon(Icons.timer_outlined),
              const SizedBox(width: 8),
              Text('Timer & Stopwatch',
                  style: Theme.of(ctx).textTheme.titleLarge)
            ]),
            const SizedBox(height: 24),
            Text('Stopwatch', style: Theme.of(ctx).textTheme.titleSmall),
            const SizedBox(height: 8),
            StreamBuilder<int>(
              stream: Stream.periodic(const Duration(seconds: 1), (i) => i),
              builder: (context, _) => Text(fmt(_stopwatchSeconds),
                  style: Theme.of(ctx)
                      .textTheme
                      .displaySmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 12),
            Wrap(spacing: 8, alignment: WrapAlignment.center, children: [
              if (!_stopwatchRunning)
                FilledButton.icon(
                    onPressed: () {
                      _startStopwatch();
                      setDialogState(() {});
                    },
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start'))
              else
                FilledButton.icon(
                    onPressed: () {
                      _stopStopwatch();
                      setDialogState(() {});
                    },
                    icon: const Icon(Icons.pause),
                    label: const Text('Pause')),
              OutlinedButton.icon(
                  onPressed: () {
                    _resetStopwatch();
                    setDialogState(() {});
                  },
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Reset')),
            ]),
            const SizedBox(height: 28),
            Text('Countdown', style: Theme.of(ctx).textTheme.titleSmall),
            const SizedBox(height: 8),
            StreamBuilder<int>(
              stream: Stream.periodic(const Duration(seconds: 1), (i) => i),
              builder: (context, _) => Text(fmt(_countdownSeconds),
                  style: Theme.of(ctx)
                      .textTheme
                      .displaySmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 8),
            Wrap(spacing: 8, alignment: WrapAlignment.center, children: [
              FilledButton.icon(
                  onPressed: () {
                    _startCountdown();
                    setDialogState(() {});
                  },
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start')),
              OutlinedButton.icon(
                  onPressed: () {
                    _stopCountdown();
                    setDialogState(() {});
                  },
                  icon: const Icon(Icons.stop),
                  label: const Text('Stop')),
            ]),
            const SizedBox(height: 24),
            TextButton.icon(
                onPressed: () => Navigator.of(ctx).pop(),
                icon: const Icon(Icons.close),
                label: const Text('Close')),
          ]),
        );

      // QR: present large QR if available
      case 6:
        final text = _qrCtrl.text.trim();
        return Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Row(children: [
            const Icon(Icons.qr_code_2_outlined),
            const SizedBox(width: 8),
            Text('QR Code', style: Theme.of(ctx).textTheme.titleLarge)
          ]),
          const SizedBox(height: 16),
          if (text.isEmpty)
            Expanded(
                child: Center(
                    child: Text('Enter text/URL in the QR tool first',
                        style: Theme.of(ctx).textTheme.titleMedium)))
          else
            Expanded(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                      color: Theme.of(ctx).colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: Theme.of(ctx).colorScheme.outlineVariant)),
                  child: QrImageView(
                      data: text,
                      size: 360,
                      backgroundColor: Colors.transparent),
                ),
              ),
            ),
          Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                  onPressed: () => Navigator.of(ctx).pop(),
                  icon: const Icon(Icons.close),
                  label: const Text('Close'))),
        ]);

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildNamePicker(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.casino_outlined),
        const SizedBox(width: 8),
        Text('Name Picker', style: context.textStyles.titleSmall?.semiBold)
      ]),
      const SizedBox(height: 8),
      Text('${_currentNames.length} students loaded',
          style: context.textStyles.bodySmall
              ?.withColor(Theme.of(context).colorScheme.onSurfaceVariant)),
      const SizedBox(height: 8),
      FilledButton.icon(
          onPressed: _pickRandomName,
          icon: const Icon(Icons.play_arrow),
          label: const Text('Pick Random')),
      if (_pickedName != null) ...[
        const SizedBox(height: 8),
        Text('Picked: $_pickedName',
            style: context.textStyles.titleMedium?.semiBold),
      ],
    ]);
  }

  Widget _buildGroups(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.groups_outlined),
        const SizedBox(width: 8),
        Text('Group Maker', style: context.textStyles.titleSmall?.semiBold)
      ]),
      const SizedBox(height: 8),
      Row(children: [
        SizedBox(
          width: 140,
          child: TextField(
            decoration:
                const InputDecoration(labelText: 'Group Size', isDense: true),
            keyboardType: TextInputType.number,
            onChanged: (v) => setState(() => _groupSize = int.tryParse(v) ?? 2),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: () {
            setState(() => _groupSize = 2);
            _makeGroups();
          },
          icon: const Icon(Icons.auto_awesome),
          label: const Text('Pairs'),
        ),
      ]),
      const SizedBox(height: 8),
      FilledButton.icon(
          onPressed: _makeGroups,
          icon: const Icon(Icons.grid_view),
          label: const Text('Generate Groups')),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (int i = 0; i < _groups.length; i++)
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(12)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Group ${i + 1}',
                  style: context.textStyles.labelLarge?.semiBold),
              ..._groups[i].map((n) => Text(n)),
            ]),
          ),
      ]),
    ]);
  }

  Widget _buildParticipation(BuildContext context) {
    final part = _participationForClass();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.emoji_people_outlined),
        const SizedBox(width: 8),
        Text('Participation', style: context.textStyles.titleSmall?.semiBold)
      ]),
      const SizedBox(height: 8),
      Wrap(spacing: 4, runSpacing: 8, children: [
        for (final n in _currentNames)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(12)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Flexible(
                child: Text(n, overflow: TextOverflow.ellipsis, maxLines: 1),
              ),
              const SizedBox(width: 4),
              Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(6)),
                  child: Text(
                    '${part[n] ?? 0}',
                    style: context.textStyles.labelSmall,
                  )),
              SizedBox(
                width: 28,
                child: IconButton(
                  icon: const Icon(Icons.add_circle_outline, size: 16),
                  color: Theme.of(context).colorScheme.primary,
                  onPressed: () => setState(() => part[n] = (part[n] ?? 0) + 1),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ),
              SizedBox(
                width: 28,
                child: IconButton(
                  icon: const Icon(Icons.remove_circle_outline, size: 16),
                  color: Theme.of(context).colorScheme.error,
                  onPressed: () => setState(() {
                    final current = part[n] ?? 0;
                    if (current > 0) {
                      part[n] = current - 1;
                    }
                  }),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ),
            ]),
          ),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        FilledButton.icon(
            onPressed: _pickRandomName,
            icon: const Icon(Icons.casino_outlined),
            label: const Text('Cold Call')),
        const SizedBox(width: 8),
        OutlinedButton.icon(
            onPressed: () => setState(() {
                  for (final n in _currentNames) {
                    part[n] = 0;
                  }
                }),
            icon: const Icon(Icons.refresh),
            label: const Text('Reset')),
      ]),
      if (_pickedName != null) ...[
        const SizedBox(height: 8),
        Text('Next up: $_pickedName',
            style: context.textStyles.titleSmall?.semiBold),
      ],
    ]);
  }

  Widget _buildQuickPoll(BuildContext context) {
    final map = _pollCountsForClass();
    int total =
        (map['A'] ?? 0) + (map['B'] ?? 0) + (map['C'] ?? 0) + (map['D'] ?? 0);
    double pct(int v) => total == 0 ? 0 : v / total;
    Widget bar(String label) => LayoutBuilder(builder: (ctx, c) {
          final v = map[label] ?? 0;
          final w = (c.maxWidth * pct(v)).clamp(0, c.maxWidth).toDouble();
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$label  ($v)'),
                const SizedBox(height: 4),
                Stack(children: [
                  Container(
                      height: 10,
                      width: c.maxWidth,
                      decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(8))),
                  AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 10,
                      width: w,
                      decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(8))),
                ]),
              ]);
        });
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.poll_outlined),
        const SizedBox(width: 8),
        Text('Quick Poll', style: context.textStyles.titleSmall?.semiBold)
      ]),
      const SizedBox(height: 12),
      // Question display/input
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Question:', style: context.textStyles.bodySmall?.semiBold),
            const SizedBox(height: 6),
            TextField(
              decoration: InputDecoration(
                hintText: 'Enter poll question...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                isDense: true,
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            Text('Answer Options:',
                style: context.textStyles.bodySmall?.semiBold),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Option A',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Option B',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Option C',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Option D',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Wrap(spacing: 8, children: [
        FilledButton(onPressed: () => _vote('A'), child: const Text('A')),
        FilledButton(onPressed: () => _vote('B'), child: const Text('B')),
        FilledButton(onPressed: () => _vote('C'), child: const Text('C')),
        FilledButton(onPressed: () => _vote('D'), child: const Text('D')),
        OutlinedButton.icon(
            onPressed: _resetPoll,
            icon: const Icon(Icons.refresh),
            label: const Text('Reset')),
      ]),
      const SizedBox(height: 12),
      bar('A'),
      const SizedBox(height: 6),
      bar('B'),
      const SizedBox(height: 6),
      bar('C'),
      const SizedBox(height: 6),
      bar('D'),
    ]);
  }

  Widget _buildTimerTool(BuildContext context) {
    String fmt(int s) {
      final m = s ~/ 60;
      final r = s % 60;
      return '${_two(m)}:${_two(r)}';
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.timer_outlined),
        const SizedBox(width: 8),
        Text('Timer & Stopwatch',
            style: context.textStyles.titleSmall?.semiBold)
      ]),
      const SizedBox(height: 8),
      // Stopwatch
      Row(children: [
        Text('Stopwatch: ', style: context.textStyles.titleSmall),
        const SizedBox(width: 6),
        Text(fmt(_stopwatchSeconds),
            style: context.textStyles.titleMedium?.semiBold),
        const Spacer(),
        if (!_stopwatchRunning)
          FilledButton.icon(
              onPressed: _startStopwatch,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start'))
        else
          FilledButton.icon(
              onPressed: _stopStopwatch,
              icon: const Icon(Icons.pause),
              label: const Text('Pause')),
        const SizedBox(width: 8),
        OutlinedButton.icon(
            onPressed: _resetStopwatch,
            icon: const Icon(Icons.restart_alt),
            label: const Text('Reset')),
      ]),
      const SizedBox(height: 12),
      // Countdown
      Row(children: [
        Text('Countdown: ', style: context.textStyles.titleSmall),
        const SizedBox(width: 8),
        SizedBox(
            width: 60,
            child: TextField(
                controller: _cdMinCtrl,
                decoration:
                    const InputDecoration(labelText: 'min', isDense: true),
                keyboardType: TextInputType.number)),
        const SizedBox(width: 8),
        SizedBox(
            width: 60,
            child: TextField(
                controller: _cdSecCtrl,
                decoration:
                    const InputDecoration(labelText: 'sec', isDense: true),
                keyboardType: TextInputType.number)),
        const SizedBox(width: 12),
        Text(fmt(_countdownSeconds),
            style: context.textStyles.titleMedium?.semiBold),
        const Spacer(),
        FilledButton.icon(
            onPressed: _startCountdown,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start')),
        const SizedBox(width: 8),
        OutlinedButton.icon(
            onPressed: _stopCountdown,
            icon: const Icon(Icons.stop),
            label: const Text('Stop')),
      ]),
    ]);
  }

  // Attendance portal open handler
  Future<void> _openAttendancePortal() async {
    final raw = _attendanceUrlCtrl.text.trim().isEmpty
        ? _defaultAttendancePortalUrl
        : _attendanceUrlCtrl.text.trim();
    // Add https scheme if missing
    final normalized = raw.contains('://') ? raw : 'https://$raw';
    Uri? uri;
    try {
      uri = Uri.parse(normalized);
    } catch (e) {
      debugPrint('Invalid URL: $raw');
      return;
    }
    try {
      // Explicitly open in a new tab on web; external application on other platforms
      final ok = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_blank',
      );
      if (!ok) debugPrint('Failed to launch attendance URL: $uri');
    } catch (e) {
      debugPrint('Error launching attendance URL: $e');
      // In Dreamflow Preview, opening external tabs can be sandboxed. Offer a friendly fallback.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text(
              'Cannot open external link in Preview. URL copied to clipboard.'),
          duration: const Duration(seconds: 3),
        ));
        await Clipboard.setData(ClipboardData(text: normalized));
      }
    }
  }

  Future<void> _openExternal(String url) async {
    final normalized = url.contains('://') ? url : 'https://$url';
    try {
      final ok = await launchUrl(Uri.parse(normalized),
          mode: LaunchMode.externalApplication, webOnlyWindowName: '_blank');
      if (!ok) debugPrint('Failed to launch: $normalized');
    } catch (e) {
      debugPrint('Error launching external URL: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Cannot open link in Preview; URL copied.')));
        await Clipboard.setData(ClipboardData(text: normalized));
      }
    }
  }

  Future<void> _submitGoogleSearch() async {
    final q = _googleSearchCtrl.text.trim();
    if (q.isEmpty) return;
    final url =
        'https://www.google.com/search?q=${Uri.encodeQueryComponent(q)}';
    await _openExternal(url);
  }

  Future<void> _submitAiSearch() async {
    final q = _askAiCtrl.text.trim();
    if (q.isEmpty) return;
    final url = 'https://chat.openai.com/?q=${Uri.encodeQueryComponent(q)}';
    await _openExternal(url);
  }

  Future<bool> _enforceImportType({
    required Uint8List bytes,
    required String filename,
    required Set<ImportFileType> allowed,
    required String destinationLabel,
  }) async {
    final detection =
        FileImportService().detectFileType(bytes, filename: filename);
    if (allowed.contains(detection.type) ||
        detection.type == ImportFileType.unknown) {
      return true;
    }
    if (!mounted) return false;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Wrong import destination'),
        content: Text(
          '${detection.message}\n\nThis import is for $destinationLabel.\n\n${detection.suggestion}',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    return false;
  }

  // ===== Schedule import (Excel/CSV) -> Reminders =====
  Future<void> _importSchedule() async {
    try {
      final pick = await FilePicker.platform.pickFiles(
          withData: true,
          type: FileType.custom,
          allowedExtensions: ['xlsx', 'csv']);
      if (pick == null || pick.files.single.bytes == null || !mounted) return;
      final bytes = pick.files.single.bytes!;
      final filename = pick.files.single.name;
      await _importScheduleFromBytes(bytes, filename);
    } catch (e) {
      debugPrint('Import schedule failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to import schedule')));
      }
    }
  }

  Future<void> _importScheduleFromDrive() async {
    if (!mounted) return;
    try {
      if (!await _ensureDriveReady()) return;
      final drive = context.read<GoogleDriveService>();
      final picked = await showDialog<DriveFile>(
        context: context,
        builder: (ctx) => DriveFilePickerDialog(
          driveService: drive,
          allowedExtensions: const ['xlsx', 'csv'],
          title: 'Import calendar from Google Drive',
        ),
      );
      if (picked == null || !mounted) return;

      final bytes = await drive.downloadFileBytesFor(picked,
          preferredExportMimeType: GoogleDriveService.exportXlsxMimeType);
      await _importScheduleFromBytes(bytes, picked.name);
    } catch (e) {
      debugPrint('Import schedule from Drive failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Drive import failed: $e')));
      }
    }
  }

  Future<void> _importScheduleFromBytes(
      Uint8List bytes, String filename) async {
    if (!await _enforceImportType(
      bytes: bytes,
      filename: filename,
      allowed: {ImportFileType.calendar},
      destinationLabel: 'Dashboard calendar',
    )) {
      return;
    }

    // **Show loading dialog immediately**
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Processing Calendar...'),
        content: SizedBox(
          width: 400,
          height: 100,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Analyzing your file...'),
            ],
          ),
        ),
      ),
    );

    try {
      final rows = FileImportService().rowsFromAnyBytes(bytes);
      if (rows.isEmpty) {
        if (mounted) Navigator.pop(context);
        await _showImportDiagnosticsDialog(
          title: 'Could not read schedule file',
          filename: filename,
          bytes: bytes,
          hint: 'Try exporting as CSV (UTF-8) and retry.',
        );
        return;
      }
      final headerRowIndex = _pickLikelyCalendarHeaderRow(rows);
      final header = rows[headerRowIndex].map((e) => _normalize(e)).toList();
      int dateIdx = _findHeaderIndex(header, ['date', '日期', 'day']);
      int titleIdx = _findHeaderIndex(header,
          ['title', 'event', 'subject', 'description', 'task', '內容', '事項']);
      int detailsIdx = _findHeaderIndex(header, [
        'details',
        'detail',
        'notes',
        'note',
        'remarks',
        'memo',
        'location',
        'room',
        'place',
        '備註',
        '地點',
        '詳情',
        '说明',
        '說明'
      ]);
      int classIdx = _findHeaderIndex(
          header, ['class', 'class name', 'class code', 'section', '班別', '班級']);
      int timeIdx =
          _findHeaderIndex(header, ['time', 'start', 'start time', '開始']);
      final yearGuess = _inferYearFromFilename(filename) ?? DateTime.now().year;

      // If this is a "school calendar" style sheet (Month/Week grid + a combined Date: Event cell),
      // parse it even when it doesn't have explicit Date/Title columns.
      if (dateIdx == -1 || titleIdx == -1) {
        int monthIdx = _findHeaderIndex(header, ['month']);
        int dateEventIdx = _findHeaderIndex(
            header, ['date: event', 'date event', 'event', 'events']);
        if (monthIdx == -1) {
          int bestIdx = -1;
          int bestHits = 0;
          final sampleEnd = rows.length < (headerRowIndex + 13)
              ? rows.length
              : (headerRowIndex + 13);
          final maxCols = rows.fold<int>(
            0,
            (max, row) => row.length > max ? row.length : max,
          );
          for (int c = 0; c < maxCols; c++) {
            int hits = 0;
            for (int r = headerRowIndex + 1; r < sampleEnd; r++) {
              final row = rows[r];
              if (c >= row.length) continue;
              if (_monthFromToken(row[c]) != null) hits++;
            }
            if (hits > bestHits) {
              bestHits = hits;
              bestIdx = c;
            }
          }
          if (bestHits > 0) {
            monthIdx = bestIdx;
          }
        }
        if (dateEventIdx == -1 && rows.length > headerRowIndex + 1) {
          // Some school templates use a date stamp as header (e.g. "(2025.01.05)")
          // and keep all event text in that column.
          final sampleStart = headerRowIndex + 1;
          final sampleEnd =
              (sampleStart + 8) < rows.length ? (sampleStart + 8) : rows.length;
          int bestIdx = -1;
          int bestScore = 0;
          for (int c = 0; c < header.length; c++) {
            int score = 0;
            for (int r = sampleStart; r < sampleEnd; r++) {
              final row = rows[r];
              if (c >= row.length) continue;
              final v = row[c].toString().trim();
              if (v.isEmpty) continue;
              if (v.contains(':')) score += 2; // "23: Opening ceremony"
              if (v.contains('\n')) score += 1; // multi-line events
              if (RegExp(r'\d{1,2}\s*-\s*\d{1,2}').hasMatch(v)) score += 1;
            }
            if (score > bestScore) {
              bestScore = score;
              bestIdx = c;
            }
          }
          if (bestScore >= 3) {
            dateEventIdx = bestIdx;
          }
        }
        if (monthIdx != -1 && dateEventIdx != -1) {
          int imported = 0;
          String lastMonthToken = '';
          final remindersToAdd = <_Reminder>[];

          for (int i = headerRowIndex + 1; i < rows.length; i++) {
            final row = rows[i];
            if (row.isEmpty) continue;

            String cellAt(int idx) =>
                (idx != -1 && idx < row.length ? row[idx].toString() : '')
                    .trim();
            final monthToken = cellAt(monthIdx);
            if (monthToken.isNotEmpty) lastMonthToken = monthToken;

            final eventCell = cellAt(dateEventIdx);
            if (eventCell.isEmpty) continue;

            final monthNumber = _monthFromToken(lastMonthToken);
            final pieces = eventCell
                .split(RegExp(r'\r?\n'))
                .expand((l) => l.split(RegExp(r'\s{2,}')))
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .toList();

            for (final p in pieces) {
              String token = '';
              String title = '';

              final colon = RegExp(r'^(.+?)\s*[:：]\s*(.+)$').firstMatch(p);
              if (colon != null) {
                token = colon.group(1)!.trim();
                title = colon.group(2)!.trim();
              } else {
                // Fallback for lines like "22-23 H1 Civil Training Camp"
                final leadDate = RegExp(
                        r'^(\d{1,2}(?:\s*-\s*\d{1,2}(?:\s*/\s*\d{1,2})?)?)\s+(.+)$')
                    .firstMatch(p);
                if (leadDate == null) continue;
                token = leadDate.group(1)!.trim();
                title = leadDate.group(2)!.trim();
              }

              if (title.isEmpty) continue;

              final d = _parseSchoolCalendarDateToken(token,
                  year: yearGuess, month: monthNumber);
              if (d == null) continue;
              remindersToAdd.add(_Reminder(title, d, done: false));
              imported++;
            }
          }

          if (imported > 0) {
            if (mounted) {
              setState(() => _reminders.addAll(remindersToAdd));
              Navigator.pop(context); // Close loading dialog
            }
            await _saveReminders();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(
                      'Imported $imported calendar event${imported == 1 ? '' : 's'}')));
            }
            return;
          }
        }

        if (mounted) Navigator.pop(context); // Close loading dialog
        await _showImportDiagnosticsDialog(
          title: 'Missing required columns',
          filename: filename,
          bytes: bytes,
          hint:
              'This import expects columns like Date/日期 and Title/Event/內容, or a Month + "Date: Event" style calendar sheet.',
        );
        return;
      }

      if (mounted) Navigator.pop(context); // Close loading dialog

      int imported = 0;
      final remindersToAdd = <_Reminder>[];
      for (int i = headerRowIndex + 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.isEmpty) continue;
        String getCell(int idx) =>
            (idx != -1 && idx < row.length ? row[idx].toString() : '').trim();
        final dateStr = getCell(dateIdx);
        final title = getCell(titleIdx);
        if (dateStr.isEmpty || title.isEmpty) continue;
        final details = getCell(detailsIdx);
        final displayTitle = details.isEmpty ? title : '$title - $details';
        DateTime? d = _parseDateFlexible(dateStr);
        if (d == null) continue;
        if (timeIdx != -1) {
          final tStr = getCell(timeIdx);
          final t = _parseTimeFlexible(tStr);
          if (t != null) {
            d = DateTime(d.year, d.month, d.day, t.hour, t.minute);
          }
        }
        List<String>? classIds;
        if (classIdx != -1) {
          final v = getCell(classIdx);
          final mapped = _mapClassIdsFromValue(v);
          if (mapped.isNotEmpty) classIds = mapped.toList();
        }
        remindersToAdd
            .add(_Reminder(displayTitle, d, done: false, classIds: classIds));
        imported++;
      }
      if (remindersToAdd.isNotEmpty) {
        setState(() => _reminders.addAll(remindersToAdd));
      }
      await _saveReminders();
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Imported $imported reminders')));
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text('Calendar import error: ${e.toString().substring(0, 80)}'),
          duration: const Duration(seconds: 5),
        ));
      }
      debugPrint('[CALENDAR] Import error: $e');
    }
  }

  int? _inferYearFromFilename(String filename) {
    final m = RegExp(r'^(\d{4})').firstMatch(filename.trim());
    if (m == null) return null;
    return int.tryParse(m.group(1)!);
  }

  int? _monthFromToken(String token) {
    final t = token.trim().toLowerCase();
    if (t.isEmpty) return null;
    final compact = t
        .replaceAll(RegExp(r'[^a-z]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (compact.isEmpty) return null;
    const map = {
      'jan': 1,
      'january': 1,
      'feb': 2,
      'february': 2,
      'mar': 3,
      'march': 3,
      'apr': 4,
      'april': 4,
      'may': 5,
      'jun': 6,
      'june': 6,
      'jul': 7,
      'july': 7,
      'aug': 8,
      'august': 8,
      'sep': 9,
      'sept': 9,
      'september': 9,
      'oct': 10,
      'october': 10,
      'nov': 11,
      'november': 11,
      'dec': 12,
      'december': 12,
    };
    for (final e in map.entries) {
      if (compact == e.key || compact.startsWith('${e.key} ')) return e.value;
    }
    return null;
  }

  DateTime? _parseSchoolCalendarDateToken(String token,
      {required int year, int? month}) {
    var t = token.trim();
    if (t.isEmpty) return null;

    // Strip weekday/notes in parentheses (English or Chinese full-width)
    t = t.replaceAll(RegExp(r'[\(（].*?[\)）]'), '').trim();
    // Strip trailing weekday words if present
    t = t
        .replaceAll(
            RegExp(r'\b(mon|tue|wed|thu|fri|sat|sun)\b', caseSensitive: false),
            '')
        .trim();

    // M/D or M/D-M/D
    final md = RegExp(
            r'^(\d{1,2})\s*/\s*(\d{1,2})(?:\s*-\s*(\d{1,2})\s*/\s*(\d{1,2}))?$')
        .firstMatch(t);
    if (md != null) {
      final m = int.tryParse(md.group(1)!);
      final d = int.tryParse(md.group(2)!);
      if (m != null && d != null) return DateTime(year, m, d);
    }

    // D-D (range within current month)
    final dd = RegExp(r'^(\d{1,2})\s*-\s*(\d{1,2})$').firstMatch(t);
    if (dd != null && month != null) {
      final d1 = int.tryParse(dd.group(1)!);
      if (d1 != null) return DateTime(year, month, d1);
    }

    // D-M/D (range crossing month, keep start day in current month context)
    final dmd =
        RegExp(r'^(\d{1,2})\s*-\s*(\d{1,2})\s*/\s*(\d{1,2})$').firstMatch(t);
    if (dmd != null) {
      final d1 = int.tryParse(dmd.group(1)!);
      final m2 = int.tryParse(dmd.group(2)!);
      if (d1 != null) {
        final resolvedMonth = month ?? m2;
        if (resolvedMonth != null) {
          return DateTime(year, resolvedMonth, d1);
        }
      }
    }

    // Single day number
    final dOnly = int.tryParse(t);
    if (dOnly != null && month != null) {
      return DateTime(year, month, dOnly);
    }

    // As a last resort, try existing flexible parser (handles YYYY-MM-DD too).
    return _parseDateFlexible(t);
  }

  int _pickLikelyCalendarHeaderRow(List<List<String>> rows) {
    if (rows.isEmpty) return 0;
    final limit = rows.length < 12 ? rows.length : 12;
    int bestIndex = 0;
    int bestScore = -1;

    const keywords = <String>[
      'date',
      'day',
      'title',
      'event',
      'month',
      'week',
      'time',
      'class',
      'details',
      'notes',
      '日期',
      '事項',
      '內容',
      '月',
      '週',
    ];
    const weekdayTokens = <String>{
      'sun',
      'mon',
      'tue',
      'wed',
      'thu',
      'fri',
      'sat',
    };

    for (int i = 0; i < limit; i++) {
      final normalized =
          rows[i].map((e) => _normalize(e)).where((e) => e.isNotEmpty).toList();
      if (normalized.length < 2) continue;

      int score = 0;
      for (final cell in normalized) {
        for (final keyword in keywords) {
          final key = _normalize(keyword);
          if (cell == key || cell.contains(key)) {
            score++;
            break;
          }
        }
      }

      final weekdayCount = normalized.where((cell) {
        final compact = cell.replaceAll(' ', '');
        return weekdayTokens.contains(compact);
      }).length;
      final hasWeek = normalized.contains('week');
      final hasMonth = normalized.contains('month');
      final hasDateStamp = normalized.any(
        (cell) => RegExp(r'^\d{4}\s+\d{1,2}\s+\d{1,2}$').hasMatch(cell),
      );
      if (hasWeek && weekdayCount >= 5) score += 8;
      if (hasMonth) score += 3;
      if (hasDateStamp) score += 2;

      if (score > bestScore) {
        bestScore = score;
        bestIndex = i;
      }
    }

    return bestScore >= 1 ? bestIndex : 0;
  }

  String _normalize(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[_\-\./\\()\[\]:]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  int _findHeaderIndex(List<String> headers, List<String> options) {
    for (final raw in options) {
      final n = _normalize(raw);
      final exact = headers.indexWhere((h) => h == n);
      if (exact != -1) return exact;
      final contains = headers.indexWhere((h) => h.contains(n));
      if (contains != -1) return contains;
    }
    return -1;
  }

  DateTime? _parseDateFlexible(String input) {
    if (input.isEmpty) return null;
    // Try ISO or common formats
    final iso = DateTime.tryParse(input);
    if (iso != null) return DateTime(iso.year, iso.month, iso.day);
    // Try dd/MM/yyyy or MM/dd/yyyy heuristics
    final m =
        RegExp(r'^(\d{1,2})[\-/](\d{1,2})[\-/](\d{2,4})').firstMatch(input);
    if (m != null) {
      final a = int.tryParse(m.group(1)!);
      final b = int.tryParse(m.group(2)!);
      final y = int.tryParse(m.group(3)!);
      if (a != null && b != null && y != null) {
        final year = y < 100 ? (2000 + y) : y;
        // Heuristic: if a > 12, then a = day else assume first token is month
        if (a > 12) return DateTime(year, b, a);
        return DateTime(year, a, b);
      }
    }
    // Excel serial? (as string number)
    final numVal = double.tryParse(input);
    if (numVal != null) {
      final epoch = DateTime(1899, 12, 30);
      return epoch.add(Duration(days: numVal.floor()));
    }
    return null;
  }

  TimeOfDay? _parseTimeFlexible(String input) {
    if (input.isEmpty) return null;
    final t = input.trim().toLowerCase();
    final m1 = RegExp(r'^(\d{1,2}):(\d{2})\s*(am|pm)?').firstMatch(t);
    if (m1 != null) {
      int h = int.parse(m1.group(1)!);
      final mm = int.parse(m1.group(2)!);
      final ap = m1.group(3);
      if (ap == 'pm' && h < 12) h += 12;
      if (ap == 'am' && h == 12) h = 0;
      return TimeOfDay(hour: h.clamp(0, 23), minute: mm.clamp(0, 59));
    }
    // e.g., 900 -> 09:00
    final numVal = int.tryParse(t);
    if (numVal != null) {
      final h = (numVal ~/ 100).clamp(0, 23);
      final m = (numVal % 100).clamp(0, 59);
      return TimeOfDay(hour: h, minute: m);
    }
    return null;
  }

  Set<String> _mapClassIdsFromValue(String value) {
    final out = <String>{};
    if (value.isEmpty) return out;
    final parts = value
        .split(RegExp(r'[,&/|]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    for (final p in parts) {
      final norm = _normalize(p);
      for (final c in _classes) {
        final nName = _normalize(c.name);
        if (nName == norm || nName.contains(norm) || norm.contains(nName)) {
          out.add(c.id);
        }
      }
    }
    return out;
  }

  Future<void> _promptEditCustomLinks() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Manage Quick Links'),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Attendance URL
                TextField(
                  controller: _attendanceUrlCtrl,
                  decoration: InputDecoration(
                    labelText: 'Attendance Portal URL',
                    hintText: _defaultAttendancePortalUrl,
                    helperText: 'Defaults to the school attendance portal URL.',
                  ),
                  onChanged: (_) {
                    _saveQuickLinks();
                  },
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Text('Custom Links', style: Theme.of(ctx).textTheme.titleSmall),
                const SizedBox(height: 8),
                if (_customLinks.isEmpty)
                  Text('No custom links yet. Add one below.',
                      style: Theme.of(ctx).textTheme.bodySmall)
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _customLinks.length,
                      itemBuilder: (context, i) {
                        final link = _customLinks[i];
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(link.label),
                          subtitle: Text(link.url,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              setState(() => _customLinks.removeAt(i));
                              await _saveQuickLinks();
                              setDialogState(() {});
                            },
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Add Custom Link'),
                  onPressed: () async {
                    await _promptAddQuickLink();
                    setDialogState(() {});
                  },
                ),
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _promptAddQuickLink() async {
    final nameCtrl = TextEditingController();
    final urlCtrl = TextEditingController(text: 'https://');
    final added = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Quick Link'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                  labelText: 'Label', hintText: 'e.g., Class Slides')),
          const SizedBox(height: 8),
          TextField(
              controller: urlCtrl,
              decoration: const InputDecoration(
                  labelText: 'URL', hintText: 'https://example.com')),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Add')),
        ],
      ),
    );
    if (added != true) return;
    final label = nameCtrl.text.trim();
    final url = urlCtrl.text.trim();
    if (label.isEmpty || url.isEmpty) return;
    setState(() => _customLinks.add(_QuickLink(label: label, url: url)));
    await _saveQuickLinks();
  }

  Future<void> _confirmRemoveCustomLink(int index) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove link?'),
        content:
            Text('Remove "${_customLinks[index].label}" from Quick Links?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Remove')),
        ],
      ),
    );
    if (ok == true) {
      setState(() => _customLinks.removeAt(index));
      await _saveQuickLinks();
    }
  }

  Future<void> _loadQuickLinks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final attendanceUrl = await _readScopedPreference(
        prefs,
        scopedKey: _attendanceUrlPrefsKey(),
        legacyKey: _legacyAttendanceUrlPrefsKey,
        migrationFlagKey: _attendanceUrlMigrationFlagKey,
      );
      final raw = await _readScopedPreference(
        prefs,
        scopedKey: _quickLinksPrefsKey(),
        legacyKey: _legacyQuickLinksPrefsKey,
        migrationFlagKey: _quickLinksMigrationFlagKey,
      );
      final parsed = raw == null || raw.isEmpty
          ? const <Map<String, dynamic>>[]
          : (jsonDecode(raw) as List)
              .map((entry) => Map<String, dynamic>.from(entry as Map))
              .toList();
      if (!mounted) return;
      setState(() {
        _attendanceUrlCtrl.text =
            (attendanceUrl == null || attendanceUrl.trim().isEmpty)
                ? _defaultAttendancePortalUrl
                : attendanceUrl.trim();
        _customLinks
          ..clear()
          ..addAll(parsed.map((m) => _QuickLink(
                label: (m['label'] ?? '') as String,
                url: (m['url'] ?? '') as String,
              )));
      });
    } catch (e) {
      debugPrint('Failed to load quick links: $e');
    }
  }

  Future<void> _saveQuickLinks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final attendanceUrl = _attendanceUrlCtrl.text.trim().isEmpty
          ? _defaultAttendancePortalUrl
          : _attendanceUrlCtrl.text.trim();
      await prefs.setString(_attendanceUrlPrefsKey(), attendanceUrl);
      await prefs.setString(
          _quickLinksPrefsKey(),
          jsonEncode(_customLinks
              .map((e) => {'label': e.label, 'url': e.url})
              .toList()));
    } catch (e) {
      debugPrint('Failed to save quick links: $e');
    }
  }

  // Teacher photo change handlers
  Future<void> _changeTeacherPhoto() async {
    if (_updatingTeacherPhoto) return;
    final isWeb = kIsWeb;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (!isWeb)
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Take Photo'),
              onTap: () => Navigator.of(ctx).pop('camera'),
            ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from device'),
            onTap: () => Navigator.of(ctx).pop('device'),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );

    if (action == null) return;
    setState(() => _updatingTeacherPhoto = true);
    try {
      Uint8List? bytes;
      if (action == 'camera') {
        final picker = ImagePicker();
        final xfile = await picker.pickImage(
            source: ImageSource.camera, maxWidth: 1600, imageQuality: 85);
        if (xfile != null) bytes = await xfile.readAsBytes();
      } else {
        final picked = await FilePicker.platform.pickFiles(
            type: FileType.custom,
            allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
            withData: true);
        if (picked != null && picked.files.single.bytes != null) {
          bytes = picked.files.single.bytes!;
        }
      }
      if (bytes == null) return;
      final base64 = base64Encode(bytes);

      if (!context.mounted) return;
      final auth = context.read<AuthService>();
      final u = auth.currentUser;
      if (u == null) return;
      final updated =
          u.copyWith(photoBase64: base64, updatedAt: DateTime.now());
      await auth.updateCurrentUser(updated);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Profile photo updated')));
    } catch (e) {
      debugPrint('Failed to set teacher photo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('Could not set photo'),
            backgroundColor: Theme.of(context).colorScheme.error));
      }
    } finally {
      if (mounted) setState(() => _updatingTeacherPhoto = false);
    }
  }

  Map<String, int> _participationForClass() {
    if (_selectedClassId == null) return {};
    return _participation.putIfAbsent(_selectedClassId!, () => {});
  }

  Map<String, int> _pollCountsForClass() {
    if (_selectedClassId == null) return {'A': 0, 'B': 0, 'C': 0, 'D': 0};
    return _pollCountsByClass.putIfAbsent(
        _selectedClassId!, () => {'A': 0, 'B': 0, 'C': 0, 'D': 0});
  }

  void _vote(String option) => setState(() {
        final map = _pollCountsForClass();
        map[option] = (map[option] ?? 0) + 1;
      });

  void _resetPoll() => setState(() {
        if (_selectedClassId == null) return;
        _pollCountsByClass[_selectedClassId!] = {
          'A': 0,
          'B': 0,
          'C': 0,
          'D': 0
        };
      });

  void _startStopwatch() {
    if (_stopwatchRunning) return;
    setState(() => _stopwatchRunning = true);
    _stopwatchTimer?.cancel();
    _stopwatchTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _stopwatchSeconds += 1);
    });
  }

  void _stopStopwatch() {
    _stopwatchTimer?.cancel();
    setState(() => _stopwatchRunning = false);
  }

  void _resetStopwatch() => setState(() => _stopwatchSeconds = 0);

  void _startCountdown() {
    _countdownTimer?.cancel();
    setState(() {
      final mins = int.tryParse(_cdMinCtrl.text.trim()) ?? 0;
      final secs = int.tryParse(_cdSecCtrl.text.trim()) ?? 0;
      _countdownSeconds = mins * 60 + secs;
    });
    if (_countdownSeconds <= 0) return;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        _countdownSeconds -= 1;
        if (_countdownSeconds <= 0) {
          t.cancel();
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text("Time's up!")));
        }
      });
    });
  }

  void _stopCountdown() {
    _countdownTimer?.cancel();
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});
  @override
  Widget build(BuildContext context) {
    return AnimatedGlowBorder(
      borderWidth: 2,
      radius: AppRadius.lg,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 140),
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: Padding(padding: AppSpacing.paddingLg, child: child),
        ),
      ),
    );
  }
}

class _ClassBrief {
  final String id;
  final String name;
  final String subtitle;
  _ClassBrief({required this.id, required this.name, required this.subtitle});
}

class _Reminder {
  final String text;
  final DateTime timestamp;
  bool done;
  final List<String>? classIds; // null or empty -> all classes
  _Reminder(this.text, this.timestamp, {this.done = false, this.classIds});
}

class _Timetable {
  final String id;
  final String name;
  final String base64;
  final String? mimeType;
  final DateTime uploadedAt;
  final List<List<String>>? grid;

  _Timetable({
    required this.id,
    required this.name,
    required this.base64,
    required this.uploadedAt,
    this.mimeType,
    this.grid,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'base64': base64,
        'mimeType': mimeType,
        'grid': grid,
        'uploadedAt': uploadedAt.toIso8601String(),
      };

  factory _Timetable.fromJson(Map<String, dynamic> json) => _Timetable(
        id: (json['id'] ?? '') as String,
        name: (json['name'] ?? '') as String,
        base64: (json['base64'] ?? '') as String,
        mimeType: json['mimeType'] as String?,
        grid: (json['grid'] is List)
            ? (json['grid'] as List)
                .map((r) =>
                    (r as List?)?.map((c) => c?.toString() ?? '').toList() ??
                    const <String>[])
                .toList()
            : null,
        uploadedAt: DateTime.tryParse(json['uploadedAt'] as String? ?? '') ??
            DateTime.now(),
      );
}

class _TimetableSlotMoment {
  final TimeSlotClass timetableClass;
  final DateTime startAt;
  final DateTime endAt;

  const _TimetableSlotMoment({
    required this.timetableClass,
    required this.startAt,
    required this.endAt,
  });
}

class _QuickLink {
  final String label;
  final String url;
  _QuickLink({required this.label, required this.url});
}

class _LinkPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  const _LinkPill(
      {required this.label,
      required this.icon,
      required this.onTap,
      this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).colorScheme.primaryContainer;
    final fg = Theme.of(context).colorScheme.onPrimaryContainer;
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(24)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: 6),
          Text(label,
              style:
                  Theme.of(context).textTheme.labelLarge?.copyWith(color: fg)),
        ]),
      ),
    );
  }
}

class _AddLinkPill extends StatelessWidget {
  final VoidCallback onTap;
  const _AddLinkPill({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fg = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).colorScheme.primary),
            borderRadius: BorderRadius.circular(24)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.add_link, size: 18, color: fg),
          const SizedBox(width: 6),
          Text('Add link',
              style:
                  Theme.of(context).textTheme.labelLarge?.copyWith(color: fg)),
        ]),
      ),
    );
  }
}

enum _SummaryRange { week, month }

// ─── AppBar helper widgets ────────────────────────────────────────────────────

/// A compact icon button with glassmorphic styling used in the dashboard AppBar.
class _AppBarIconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  const _AppBarIconBtn({
    required this.icon,
    required this.tooltip,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
            border:
                Border.all(color: Colors.white.withValues(alpha: 0.20)),
          ),
          child: Icon(icon, color: Colors.white, size: 19),
        ),
      ),
    );
  }
}

/// User identity chip displayed on the left side of the AppBar.
class _AppBarUserChip extends StatelessWidget {
  final String name;
  final String? photoBase64;

  const _AppBarUserChip({
    required this.name,
    this.photoBase64,
  });

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'T';
    final hasPhoto = photoBase64 != null && photoBase64!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.fromLTRB(6, 4, 14, 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 13,
            backgroundColor: Colors.white.withValues(alpha: 0.22),
            backgroundImage: hasPhoto
                ? MemoryImage(const Base64Decoder().convert(photoBase64!))
                : null,
            child: !hasPhoto
                ? Text(
                    initial,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140),
            child: Text(
              // Show first name only; for single-word names the full name is used
              name.contains(' ') ? name.split(' ').first : name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.1,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Navigation chip for the horizontal nav strip inside the AppBar.
class _NavChipItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback? onTap;

  const _NavChipItem({
    required this.label,
    required this.icon,
    required this.isSelected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: onTap != null
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white
                .withValues(alpha: isSelected ? 0.18 : 0.06),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: Colors.white
                  .withValues(alpha: isSelected ? 0.30 : 0.12),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: Colors.white
                    .withValues(alpha: isSelected ? 1.0 : 0.70),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white
                      .withValues(alpha: isSelected ? 1.0 : 0.70),
                  fontSize: 13,
                  fontWeight: isSelected
                      ? FontWeight.w600
                      : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

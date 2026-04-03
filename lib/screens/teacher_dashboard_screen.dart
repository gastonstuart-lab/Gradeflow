import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:gradeflow/config/gradeflow_product_config.dart';
import 'package:gradeflow/services/auth_service.dart';
import 'package:gradeflow/services/class_service.dart';
import 'package:gradeflow/services/student_service.dart';
import 'package:gradeflow/services/class_schedule_service.dart';
import 'package:gradeflow/models/class_schedule_item.dart';
import 'package:gradeflow/models/communication_models.dart';
import 'package:gradeflow/repositories/repository_factory.dart';
import 'package:gradeflow/theme.dart';
import 'package:gradeflow/components/dashboard_story_carousel.dart';
import 'package:gradeflow/components/drive_file_picker_dialog.dart';
import 'package:gradeflow/components/pilot_feedback_card.dart';
import 'package:gradeflow/components/pilot_feedback_dialog.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:gradeflow/services/file_import_service.dart';
import 'package:gradeflow/providers/app_providers.dart';
import 'package:gradeflow/nav.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:gradeflow/services/google_drive_service.dart';
import 'package:gradeflow/services/google_auth_service.dart';
import 'package:gradeflow/services/ai_import_service.dart';
import 'package:gradeflow/services/dashboard_preferences_service.dart';
import 'package:gradeflow/services/dashboard_news_service.dart';
import 'package:gradeflow/services/dashboard_weather_service.dart';
import 'package:gradeflow/services/communication_service.dart';
import 'package:gradeflow/services/communication_workspace_service.dart';
import 'package:gradeflow/openai/openai_config.dart';
import 'package:gradeflow/components/ai_analyze_import_dialog.dart';
import 'package:gradeflow/components/time_slot_timetable.dart';

part 'teacher_dashboard/dashboard_class_tools.dart';
part 'teacher_dashboard/dashboard_imports.dart';
part 'teacher_dashboard/dashboard_live_brief.dart';
part 'teacher_dashboard/dashboard_persistence.dart';
part 'teacher_dashboard/dashboard_redesign_sections.dart';
part 'teacher_dashboard/dashboard_shell.dart';
part 'teacher_dashboard/dashboard_timetable.dart';
part 'teacher_dashboard/dashboard_workspace_sections.dart';

class TeacherDashboardScreen extends StatefulWidget {
  const TeacherDashboardScreen({super.key});

  @override
  State<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen> {
  static const String _defaultAttendancePortalUrl =
      GradeFlowProductConfig.defaultAttendancePortalUrl;
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
  final DashboardPreferencesService _dashboardPreferencesService =
      const DashboardPreferencesService();
  final GlobalKey _summarySectionKey = GlobalKey();
  final GlobalKey _classStatusSectionKey = GlobalKey();
  final GlobalKey _quickActionsSectionKey = GlobalKey();
  final GlobalKey _insightsSectionKey = GlobalKey();
  final GlobalKey _planningSectionKey = GlobalKey();
  final GlobalKey _classToolsSectionKey = GlobalKey();
  final GlobalKey _calendarSectionKey = GlobalKey();
  final GlobalKey _workspaceSectionKey = GlobalKey();
  final GlobalKey _livePanelSectionKey = GlobalKey();

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
  DashboardWorkspaceSection _workspaceSection = DashboardWorkspaceSection.today;
  int _mobileDashboardIndex = 0;

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
  final CommunicationWorkspaceService _communicationWorkspaceService =
      const CommunicationWorkspaceService();
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
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
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
    final classes = <_ClassBrief>[];
    int totalStudents = 0;
    for (final c in classService.classes) {
      await studentService.loadStudents(c.classId);
      final studentCount = studentService.students.length;
      totalStudents += studentCount;
      classes.add(
        _ClassBrief(
          id: c.classId,
          name: c.className,
          subtitle: '${c.subject} • ${c.schoolYear} ${c.term}',
          studentCount: studentCount,
        ),
      );
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
    return Theme(
      data: _dashboardTheme(context),
      child: Builder(
        builder: (context) => Scaffold(
          backgroundColor: _DashboardPalette.background,
          body: _buildResponsiveDashboard(context),
        ),
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
  const _Card({
    required this.child,
  });
  @override
  Widget build(BuildContext context) {
    return DashboardPanelCard(
      minHeight: 140,
      padding: AppSpacing.paddingLg,
      child: child,
    );
  }
}

class _ClassBrief {
  final String id;
  final String name;
  final String subtitle;
  final int studentCount;
  _ClassBrief({
    required this.id,
    required this.name,
    required this.subtitle,
    this.studentCount = 0,
  });
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

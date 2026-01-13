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
import 'package:gradeflow/components/drive_file_picker_dialog.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:gradeflow/services/file_import_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gradeflow/providers/app_providers.dart';
import 'package:gradeflow/nav.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:math' as math;
import 'package:gradeflow/services/google_drive_service.dart';
import 'package:gradeflow/services/google_auth_service.dart';
import 'package:gradeflow/services/ai_import_service.dart';
import 'package:gradeflow/openai/openai_config.dart';
import 'package:gradeflow/components/ai_analyze_import_dialog.dart';

class TeacherDashboardScreen extends StatefulWidget {
  const TeacherDashboardScreen({super.key});

  @override
  State<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen> {
  Timer? _timer;
  final ValueNotifier<DateTime> _nowNotifier = ValueNotifier(DateTime.now());

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
    'Seating',
    'Participation',
    'Schedule',
    'Quick Poll',
    'Timer',
    'QR Code'
  ];
  int _selectedToolTab = 0;

  // Summary range for reminders panel (Week or Month)
  _SummaryRange _summaryRange = _SummaryRange.week;

  // Seating designer: freeform tables with multiple seats, per class
  final Map<String, List<_SeatTable>> _seatingByClass = {}; // classId -> tables
  bool _seatDesignMode = false; // Design tables layout vs Assign students (default: Assign mode)
  int _newTableSeats = 4; // Default capacity for newly added tables

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
                      analyze: () => AiImportService().analyzeSchoolCalendarFromRows(
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
                          content: Text('AI did not return valid events. Please try a different file format.')));
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
                    final t = details.isEmpty ? titleStr : '$titleStr — $details';
                    remindersToAdd.add(_Reminder(t, d, done: false));
                  }

                  if (remindersToAdd.isEmpty) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('No valid events found. Try a file with Date and Title columns.')));
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
                      content:
                          Text('Imported ${remindersToAdd.length} events from AI')));
                } catch (e) {
                  // AI failed - show helpful error message
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('AI analysis failed: ${e.toString().contains('quota') ? 'API quota exceeded' : 'Connection error'}'),
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
    // Initialize attendance portal URL (customizable by teacher - empty by default)
    _attendanceUrlCtrl.text = '';
    _loadData();
    // Load saved reminders so weekly panel reflects calendar changes immediately
    unawaited(_loadReminders());
    // Load quick links (attendance URL and custom)
    unawaited(_loadQuickLinks());

    // Load timetables (upload + select)
    unawaited(_loadTimetables());
    // Do not prefill QR text; leave empty so teacher enters student-targeted content
    // _qrCtrl.text = _attendanceUrlCtrl.text;
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
    if (_selectedClassId == null) {
      setState(() => _currentNames = []);
      return;
    }
    await studentService.loadStudents(_selectedClassId!);
    final names = studentService.students
        .map((s) => '${s.chineseName} (${s.englishFullName})')
        .toList();
    setState(() => _currentNames = names);

    // Load schedule for this class (async, cached)
    if (_selectedClassId != null) {
      unawaited(_loadClassSchedule(_selectedClassId!));
    }
    // Initialize participation counts for this class
    if (_selectedClassId != null) {
      _participation.putIfAbsent(_selectedClassId!, () => {});
      for (final n in names) {
        _participation[_selectedClassId!]!.putIfAbsent(n, () => 0);
      }
      // Initialize poll counts for this class
      _pollCountsByClass.putIfAbsent(
          _selectedClassId!, () => {'A': 0, 'B': 0, 'C': 0, 'D': 0});
      // Load seating layout for this class
      unawaited(_loadSeatingLayoutForClass());
    }
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
        return;
      }

      final bytes = picked.files.single.bytes!;
      final filename = picked.files.single.name;
      final items = _classScheduleService.parseFromBytes(bytes);

      if (items.isEmpty) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Could not read schedule'),
            content: Text('No schedule items were detected in "$filename".'),
            actions: [
              FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close'))
            ],
          ),
        );
        return;
      }

      final dateItems = items.where((i) => i.date != null).toList();
      DateTime? start;
      DateTime? end;
      if (dateItems.isNotEmpty) {
        start = dateItems
            .map((e) => e.date!)
            .reduce((a, b) => a.isBefore(b) ? a : b);
        end = dateItems
            .map((e) => e.date!)
            .reduce((a, b) => a.isAfter(b) ? a : b);
      }

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
                Text('File: $filename'),
                const SizedBox(height: 8),
                Text('Items found: ${items.length}'),
                if (start != null && end != null)
                  Text(
                      'Date range: ${_formatDate(start)} → ${_formatDate(end)}'),
                const SizedBox(height: 12),
                Text('Preview (first 5):',
                    style: Theme.of(ctx).textTheme.titleSmall),
                const SizedBox(height: 6),
                ...items.take(5).map((i) {
                  final when = i.date != null
                      ? _formatDate(i.date!)
                      : (i.week != null ? 'Week ${i.week}' : '');
                  final subtitleParts = <String>[];
                  if (i.details['Book']?.isNotEmpty == true) {
                    subtitleParts.add(i.details['Book']!);
                  }
                  if (i.details['Chapter/Unit']?.isNotEmpty == true) {
                    subtitleParts.add(i.details['Chapter/Unit']!);
                  }
                  if (i.details['Homework']?.isNotEmpty == true) {
                    subtitleParts.add('HW: ${i.details['Homework']!}');
                  }
                  final subtitle =
                      subtitleParts.isEmpty ? null : subtitleParts.join(' • ');
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(i.title,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: subtitle == null
                        ? null
                        : Text(subtitle,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                    leading: when.isEmpty
                        ? null
                        : Text(when,
                            style: Theme.of(ctx).textTheme.labelMedium),
                  );
                }),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Save')),
          ],
        ),
      );

      if (confirm == true && mounted) {
        await _saveClassSchedule(_selectedClassId!, items);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Saved schedule (${items.length} items)')));
        }
      }
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
    _cdMinCtrl.dispose();
    _cdSecCtrl.dispose();
    _qrCtrl.dispose();
    _stopwatchTimer?.cancel();
    _countdownTimer?.cancel();
    _nowNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    final themeMode = context.watch<ThemeModeNotifier>().themeMode;
    debugPrint(
        'TeacherDashboard.build | classes=${_classes.length} reminders=${_reminders.length} width=${MediaQuery.of(context).size.width}');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Teacher Dashboard'),
        actions: [
          IconButton(
            tooltip: themeMode == ThemeMode.dark
                ? 'Switch to light mode'
                : 'Switch to dark mode',
            icon: Icon(themeMode == ThemeMode.dark
                ? Icons.light_mode
                : Icons.dark_mode),
            onPressed: () => context.read<ThemeModeNotifier>().toggleTheme(),
          ),
          IconButton(
            tooltip: 'Log out',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await context.read<GoogleAuthService>().signOut();
              await context.read<AuthService>().logout();
              if (!context.mounted) return;
              context.go(AppRoutes.home);
            },
          ),
        ],
        bottom: const SchoolBannerBar(height: 56),
      ),
      body: Builder(builder: (context) {
        final isNarrow = MediaQuery.of(context).size.width < 720;
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: AppSpacing.paddingLg,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
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
                                  backgroundColor:
                                      Theme.of(context).colorScheme.primaryContainer,
                                  backgroundImage: (user?.photoBase64 != null &&
                                          user!.photoBase64!.isNotEmpty)
                                      ? MemoryImage(const Base64Decoder()
                                          .convert(user.photoBase64!))
                                      : null,
                                  child: (user?.photoBase64 == null ||
                                          (user?.photoBase64?.isEmpty ?? true))
                                      ? Text(
                                          (user?.fullName.isNotEmpty ?? false)
                                              ? user!.fullName[0].toUpperCase()
                                              : 'T',
                                          style: context.textStyles.titleLarge
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
                                          color:
                                              Theme.of(context).colorScheme.surface,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                              color: Theme.of(context).dividerColor,
                                              width: 0.5)),
                                      padding: const EdgeInsets.all(6),
                                      child: Icon(Icons.camera_alt,
                                          size: 18,
                                          color:
                                              Theme.of(context).colorScheme.primary),
                                    ),
                                  ),
                                ),
                              ]),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                          'Welcome, ${user?.fullName ?? 'Teacher'} 👋',
                                          style: context
                                              .textStyles.titleMedium?.semiBold,
                                          overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 6),
                                      ValueListenableBuilder<DateTime>(
                                        valueListenable: _nowNotifier,
                                        builder: (context, now, _) => Text(
                                          '${_formatDate(now)} • ${_formatTime(now)}',
                                          style: context.textStyles.bodySmall
                                              ?.withColor(Theme.of(context)
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
                            style: context.textStyles.titleMedium?.semiBold),
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
                                    color: Theme.of(context).colorScheme.primary),
                                const SizedBox(width: 6),
                                Text('${_classes.length} classes'),
                              ],
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.people_alt,
                                    size: 20,
                                    color: Theme.of(context).colorScheme.primary),
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
                                backgroundImage: (user?.photoBase64 != null &&
                                        user!.photoBase64!.isNotEmpty)
                                    ? MemoryImage(const Base64Decoder()
                                        .convert(user.photoBase64!))
                                    : null,
                                child: (user?.photoBase64 == null ||
                                        (user?.photoBase64?.isEmpty ?? true))
                                    ? Text(
                                        (user?.fullName.isNotEmpty ?? false)
                                            ? user!.fullName[0].toUpperCase()
                                            : 'T',
                                        style: context.textStyles.headlineMedium
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
                                            color:
                                                Theme.of(context).dividerColor,
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                        'Welcome, ${user?.fullName ?? 'Teacher'} 👋',
                                        style: context
                                            .textStyles.titleLarge?.semiBold),
                                    const SizedBox(height: 8),
                                    ValueListenableBuilder<DateTime>(
                                      valueListenable: _nowNotifier,
                                      builder: (context, now, _) => Text(
                                        '${_formatDate(now)} • ${_formatTime(now)}',
                                        style: context.textStyles.bodyMedium
                                            ?.withColor(Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Center(
                                      child: OutlinedButton.icon(
                                        icon: Icon(_selectedTimetableId == null 
                                            ? Icons.upload_file 
                                            : Icons.table_chart),
                                        label: Text(_selectedTimetableId == null
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
                                style: context.textStyles.titleLarge?.semiBold),
                            const SizedBox(height: 8),
                            Row(children: [
                              Icon(Icons.class_,
                                  color: Theme.of(context).colorScheme.primary),
                              const SizedBox(width: 6),
                              Text('${_classes.length} classes'),
                              const SizedBox(width: 16),
                              Icon(Icons.people_alt,
                                  color: Theme.of(context).colorScheme.primary),
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
                          style: context.textStyles.titleMedium?.semiBold),
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
                              onTap: () =>
                                  _openExternal('https://drive.google.com/')),
                        ),
                        // ClassroomScreen
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _LinkPill(
                            label: 'ClassroomScreen',
                            icon: Icons.dashboard_customize_outlined,
                            onTap: () =>
                                _openExternal('https://classroomscreen.com/'),
                          ),
                        ),
                        // Custom links
                        for (int i = 0; i < _customLinks.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _LinkPill(
                              label: _customLinks[i].label,
                              icon: Icons.link,
                              onTap: () => _openExternal(_customLinks[i].url),
                              onLongPress: () => _confirmRemoveCustomLink(i),
                            ),
                          ),
                        // Add button
                        _AddLinkPill(onTap: _promptAddQuickLink),
                      ]),
                    ),
                  ]),
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
                                ? "This Week’s To‑Dos & Reminders"
                                : "This Month’s To‑Dos & Reminders",
                            style: context.textStyles.titleMedium?.semiBold),
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
                            Theme.of(context).colorScheme.onSurfaceVariant));
                  }),
                  children: [
                    if (_periodReminders().isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                            'No items in this period yet. Add some from the calendar below.',
                            style: context.textStyles.bodySmall?.withColor(
                                Theme.of(context)
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
                                  ? context.textStyles.bodyMedium?.copyWith(
                                      decoration: TextDecoration.lineThrough,
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
            _Card(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.widgets_outlined),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text('Class Tools',
                            style: context.textStyles.titleMedium?.semiBold,
                            overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 280, minWidth: 120),
                          child: DropdownButtonFormField<String>(
                            value: _selectedClassId,
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

            const SizedBox(height: 12),

            // Calendar panel — actual month grid with day selection and to‑dos/reminders
            _Card(child: _buildCalendar(context)),
          ]),
        );
      }),
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
                                                    fontWeight:
                                                        FontWeight.w700)
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
          return Text('Select a day to add to‑dos/reminders.',
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
                    hintText: 'e.g., Quiz, homework, meeting…'),
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
      final raw = prefs.getString('dashboard_reminders');
      if (raw == null || raw.isEmpty) return;
      final list = jsonDecode(raw) as List<dynamic>;
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
      await prefs.setString('dashboard_reminders', jsonEncode(data));
    } catch (e) {
      debugPrint('Failed to save reminders: $e');
    }
  }

  String _timetablePrefsKey() {
    final userId = context.read<AuthService>().currentUser?.userId ?? 'local';
    return 'dashboard_timetables_v1:$userId';
  }

  String _selectedTimetablePrefsKey() {
    final userId = context.read<AuthService>().currentUser?.userId ?? 'local';
    return 'dashboard_selected_timetable_v1:$userId';
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
                      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
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
                          'Supports DOCX files with table structures',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text('Choose File'),
                          onPressed: () async {
                            final picked = await FilePicker.platform.pickFiles(
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
                            final id = DateTime.now()
                                .microsecondsSinceEpoch
                                .toString();

                            List<List<String>>? grid;
                            if ((mimeType ?? '').toLowerCase() == 'docx') {
                              try {
                                final rawGrid = FileImportService()
                                    .extractDocxBestTableGrid(bytes);
                                // Clean up the grid to remove duplicates and merge periods
                                grid = FileImportService().cleanTimetableGrid(rawGrid);
                              } catch (e) {
                                grid = null;
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text(
                                            'Could not parse DOCX timetable: $e')),
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
                                SnackBar(
                                    content: Text(
                                        'Timetable "$name" uploaded.')),
                              );
                            }
                          },
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
      controllers.add(
          row.map((cell) => TextEditingController(text: cell)).toList());
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        child: Container(
          width: MediaQuery.of(ctx).size.width * 0.9,
          height: MediaQuery.of(ctx).size.height * 0.85,
          constraints: const BoxConstraints(maxWidth: 1200),
          child: StatefulBuilder(
            builder: (ctx, setLocalState) {
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
                        ? Theme.of(ctx).colorScheme.primaryContainer.withValues(alpha: 0.6)
                        : isFirstCol
                            ? Theme.of(ctx).colorScheme.surfaceContainerHighest
                            : null,
                    border: Border(
                      right: BorderSide(
                        color: Theme.of(ctx).colorScheme.outlineVariant.withValues(alpha: 0.5),
                        width: 1,
                      ),
                      bottom: BorderSide(
                        color: Theme.of(ctx).colorScheme.outlineVariant.withValues(alpha: 0.5),
                        width: 1,
                      ),
                    ),
                  ),
                  child: TextField(
                    controller: controllers[r][c],
                    maxLines: isFirstCol ? 1 : 3,
                    minLines: 1,
                    textAlign: isHeader || isFirstCol ? TextAlign.center : TextAlign.center,
                    style: isHeader
                        ? Theme.of(ctx).textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Theme.of(ctx).colorScheme.onPrimaryContainer,
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
                      hintText: isHeader ? 'Day' : isFirstCol ? 'Time' : 'Class',
                      hintStyle: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                            color: Theme.of(ctx).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                            fontSize: 10,
                          ),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                );
              }

              final rows = controllers.length;
              final cols = controllers.isEmpty
                  ? 0
                  : controllers.map((r) => r.length).reduce((a, b) => a > b ? a : b);

              return Column(
                children: [
                  // Header
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
                          Icons.table_chart,
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
                                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Edit your timetable by clicking any cell',
                                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
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
                  // Timetable content
                  Expanded(
                    child: Container(
                      color: Theme.of(ctx).colorScheme.surface,
                      padding: const EdgeInsets.all(20),
                      child: Card(
                        elevation: 2,
                        clipBehavior: Clip.antiAlias,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minWidth: MediaQuery.of(ctx).size.width * 0.8,
                            ),
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Header row with day names
                                  if (cols > 1)
                                    IntrinsicHeight(
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          for (var c = 0; c < cols; c++)
                                            SizedBox(
                                              width: c == 0 ? 100 : 180,
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                                                  border: Border.all(
                                                    color: Theme.of(ctx).colorScheme.outlineVariant,
                                                  ),
                                                ),
                                                padding: const EdgeInsets.all(8),
                                                child: Center(
                                                  child: Text(
                                                    c == 0
                                                        ? 'Time'
                                                        : _getDayName(c - 1),
                                                    style: Theme.of(ctx).textTheme.labelSmall?.copyWith(
                                                      fontWeight: FontWeight.bold,
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
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
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
                              '$rows rows × $cols columns',
                              style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
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
                                  newGrid.add(rowCtrls.map((c) => c.text).toList());
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
                                        content: Text('Timetable saved successfully')),
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
    const names = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
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

  // Show HH:MM only when a specific time is set; hide when all-day (00:00)
  String _formatHourMinute(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';
  String _optionalTimeInline(DateTime d) =>
      (d.hour == 0 && d.minute == 0 && d.second == 0)
          ? ''
          : '  ${_formatHourMinute(d)}';

  // ===== Class Tools UI builder =====
  Widget _buildClassToolsBody(BuildContext context) {
    switch (_selectedToolTab) {
      case 0:
        return _buildNamePicker(context);
      case 1:
        return _buildGroups(context);
      case 2:
        return _buildSeating(context);
      case 3:
        return _buildParticipation(context);
      case 4:
        return _buildScheduleTool(context);
      case 5:
        return _buildQuickPoll(context);
      case 6:
        return _buildTimerTool(context);
      case 7:
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
            child: Text('Schedule • $className',
                style: context.textStyles.titleSmall?.semiBold)),
        OutlinedButton.icon(
          onPressed: _scheduleBusy ? null : _importClassSchedule,
          icon: const Icon(Icons.drive_folder_upload_outlined),
          label: Text(_scheduleBusy ? 'Importing…' : 'Upload'),
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
                onChanged: (v) => setState(() => _groupSize = int.tryParse(v) ?? 2),
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

      // Seating: present read-only seating layout (no toolbar)
      case 2:
        final tables = _seatingForClass();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.event_seat_outlined),
            const SizedBox(width: 8),
            Text('Seating Plan', style: Theme.of(ctx).textTheme.titleLarge)
          ]),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(16),
                border:
                    Border.all(color: Theme.of(ctx).colorScheme.outlineVariant),
              ),
              clipBehavior: Clip.hardEdge,
              child: LayoutBuilder(builder: (ctx2, constraints) {
                return InteractiveViewer(
                  constrained: false,
                  boundaryMargin: const EdgeInsets.all(300),
                  minScale: 0.5,
                  maxScale: 2.5,
                  child: SizedBox(
                    width: math.max(constraints.maxWidth, 900),
                    height: math.max(constraints.maxHeight, 700),
                    child: Stack(children: [
                      for (int i = 0; i < tables.length; i++)
                        _TableWidget(
                          tableIndex: i,
                          table: tables[i],
                          designMode: false,
                          onMove: (_) {},
                          onMoveEnd: () {},
                          onRemove: () {},
                          onCapacityChanged: (_) {},
                          onSeatDrop: (seatIndex, data) {
                            _handleSeatDrop(i, seatIndex, data);
                            setDialogState(() {});
                          },
                          onClearSeat: (seatIndex) {
                            _clearSeat(i, seatIndex);
                            setDialogState(() {});
                          },
                          onTapSeat: (seatIndex) {
                            unawaited(_promptPickStudentForSeat(i, seatIndex)
                                .whenComplete(() => setDialogState(() {})));
                          },
                        ),
                    ]),
                  ),
                );
              }),
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
      case 3:
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
      case 4:
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
      case 5:
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
      case 6:
        String fmt(int s) {
          final m = s ~/ 60;
          final r = s % 60;
          return '${_two(m)}:${_two(r)}';
        }
        return SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Row(children: [
              const Icon(Icons.timer_outlined),
              const SizedBox(width: 8),
              Text('Timer & Stopwatch', style: Theme.of(ctx).textTheme.titleLarge)
            ]),
            const SizedBox(height: 24),
            Text('Stopwatch', style: Theme.of(ctx).textTheme.titleSmall),
            const SizedBox(height: 8),
            Text(fmt(_stopwatchSeconds),
                style: Theme.of(ctx)
                    .textTheme
                    .displaySmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Wrap(spacing: 8, alignment: WrapAlignment.center, children: [
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
              OutlinedButton.icon(
                  onPressed: _resetStopwatch,
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Reset')),
            ]),
            const SizedBox(height: 28),
            Text('Countdown', style: Theme.of(ctx).textTheme.titleSmall),
            const SizedBox(height: 8),
            Text(fmt(_countdownSeconds),
                style: Theme.of(ctx)
                    .textTheme
                    .displaySmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, alignment: WrapAlignment.center, children: [
              FilledButton.icon(
                  onPressed: _startCountdown,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start')),
              OutlinedButton.icon(
                  onPressed: _stopCountdown,
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
      case 7:
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

  Widget _buildSeating(BuildContext context) {
    final tables = _seatingForClass();
    final unassigned = _unassignedStudents();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.event_seat_outlined),
        const SizedBox(width: 8),
        Text('Seating Designer',
            style: context.textStyles.titleSmall?.semiBold),
        const Spacer(),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(
                value: true,
                label: Text('Design'),
                icon: Icon(Icons.design_services_outlined)),
            ButtonSegment(
                value: false,
                label: Text('Assign'),
                icon: Icon(Icons.badge_outlined)),
          ],
          selected: {_seatDesignMode},
          onSelectionChanged: (s) => setState(() => _seatDesignMode = s.first),
        ),
      ]),
      const SizedBox(height: 8),
      // Toolbar
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Wrap(spacing: 8, runSpacing: 4, children: [
          // Seat count selector + single Add button
          Row(mainAxisSize: MainAxisSize.min, children: [
            Text('Seats per table:',
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(width: 8),
            DropdownButton<int>(
              value: _newTableSeats,
              onChanged: (v) => setState(() => _newTableSeats = v ?? 4),
              items: const [2, 3, 4, 5, 6, 8, 10]
                  .map(
                      (n) => DropdownMenuItem<int>(value: n, child: Text('$n')))
                  .toList(),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
                onPressed: () => _addTable(capacity: _newTableSeats),
                icon: const Icon(Icons.add),
                label: const Text('Add table')),
          ]),
          OutlinedButton.icon(
              onPressed: _randomizeAssignments,
              icon: const Icon(Icons.shuffle),
              label: const Text('Randomize')),
          OutlinedButton.icon(
              onPressed: _clearAssignments,
              icon: const Icon(Icons.clear_all),
              label: const Text('Clear assignments')),
          IconButton(
              onPressed: _autoLayoutGrid,
              icon: const Icon(Icons.auto_awesome_mosaic_outlined),
              tooltip: 'Auto‑arrange'),
          IconButton(
              onPressed: _clearLayout,
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Clear layout'),
        ]),
      ),
      const SizedBox(height: 8),
      // Canvas with pan/zoom for mobile
      LayoutBuilder(builder: (ctx, constraints) {
        return Container(
          height: 380,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          ),
          clipBehavior: Clip.hardEdge,
          child: InteractiveViewer(
            constrained: false,
            boundaryMargin: const EdgeInsets.all(240),
            minScale: 0.6,
            maxScale: 2.2,
            child: SizedBox(
              width: math.max(constraints.maxWidth, 900),
              height: 700,
              child: Stack(children: [
                for (int i = 0; i < tables.length; i++)
                  _TableWidget(
                    tableIndex: i,
                    table: tables[i],
                    designMode: _seatDesignMode,
                    onMove: (delta) => _moveTable(i, delta),
                    onMoveEnd: () => _saveSeatingLayoutForClass(),
                    onRemove: () => _removeTable(i),
                    onCapacityChanged: (cap) => _setTableCapacity(i, cap),
                    onSeatDrop: (seatIndex, data) =>
                        _handleSeatDrop(i, seatIndex, data),
                    onClearSeat: (seatIndex) => _clearSeat(i, seatIndex),
                    onTapSeat: (seatIndex) =>
                        _promptPickStudentForSeat(i, seatIndex),
                  ),
              ]),
            ),
          ),
        );
      }),
      const SizedBox(height: 8),
      // Unassigned students tray
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Unassigned students (${unassigned.length})',
            style: context.textStyles.labelLarge?.semiBold),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final name in unassigned) _StudentChip(name: name),
        ]),
      ]),
      const SizedBox(height: 6),
      Text(
          '💡 Tip: Click any seat to assign or change a student. Use the drag handle (⋮⋮) to reposition tables.',
          style: context.textStyles.bodySmall
              ?.withColor(Theme.of(context).colorScheme.onSurfaceVariant)),
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
            Text('Question:',
                style: context.textStyles.bodySmall?.semiBold),
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
    final raw = _attendanceUrlCtrl.text.trim();
    if (raw.isEmpty) return;
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
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Drive import failed: $e')));
      }
    }
  }

  Future<void> _importScheduleFromBytes(Uint8List bytes, String filename) async {
    final rows = FileImportService().rowsFromAnyBytes(bytes);
      if (rows.isEmpty) {
        await _showImportDiagnosticsDialog(
          title: 'Could not read schedule file',
          filename: filename,
          bytes: bytes,
          hint: 'Try exporting as CSV (UTF-8) and retry.',
        );
        return;
      }
      final header = rows.first.map((e) => _normalize(e)).toList();
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
        final monthIdx = _findHeaderIndex(header, ['month']);
        final dateEventIdx = _findHeaderIndex(
            header, ['date: event', 'date event', 'event', 'events']);
        if (monthIdx != -1 && dateEventIdx != -1) {
          int imported = 0;
          String lastMonthToken = '';
          final remindersToAdd = <_Reminder>[];

          for (int i = 1; i < rows.length; i++) {
            final row = rows[i];
            if (row.isEmpty) continue;

            String cellAt(int idx) => (idx != -1 && idx < row.length
                  ? row[idx].toString()
                    : '')
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
              final m = RegExp(r'^(.+?)\s*:\s*(.+)$').firstMatch(p);
              if (m == null) continue;
              final token = m.group(1)!.trim();
              final title = m.group(2)!.trim();
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

        await _showImportDiagnosticsDialog(
          title: 'Missing required columns',
          filename: filename,
          bytes: bytes,
          hint:
              'This import expects columns like Date/日期 and Title/Event/內容, or a Month + "Date: Event" style calendar sheet.',
        );
        return;
      }

      int imported = 0;
      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.isEmpty) continue;
        String getCell(int idx) =>
          (idx != -1 && idx < row.length ? row[idx].toString() : '')
                .trim();
        final dateStr = getCell(dateIdx);
        final title = getCell(titleIdx);
        if (dateStr.isEmpty || title.isEmpty) continue;
        final details = getCell(detailsIdx);
        final displayTitle = details.isEmpty ? title : '$title — $details';
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
        setState(() => _reminders.add(
            _Reminder(displayTitle, d!, done: false, classIds: classIds)));
        imported++;
      }
      await _saveReminders();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Imported $imported reminders')));
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
      if (t == e.key || t.startsWith('${e.key} ')) return e.value;
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

    // Single day number
    final dOnly = int.tryParse(t);
    if (dOnly != null && month != null) {
      return DateTime(year, month, dOnly);
    }

    // As a last resort, try existing flexible parser (handles YYYY-MM-DD too).
    return _parseDateFlexible(t);
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
                  decoration: const InputDecoration(
                    labelText: 'Attendance Portal URL',
                    hintText: 'https://...',
                    helperText: 'URL for the Attendance link',
                  ),
                  onChanged: (_) {
                    _saveQuickLinks();
                  },
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Text('Custom Links',
                    style: Theme.of(ctx).textTheme.titleSmall),
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
      final att = prefs.getString('attendance_url');
      if (att != null && att.isNotEmpty) _attendanceUrlCtrl.text = att;
      final raw = prefs.getString('custom_quick_links');
      if (raw != null && raw.isNotEmpty) {
        final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
        setState(() {
          _customLinks
            ..clear()
            ..addAll(list.map((m) => _QuickLink(
                label: (m['label'] ?? '') as String,
                url: (m['url'] ?? '') as String)));
        });
      }
    } catch (e) {
      debugPrint('Failed to load quick links: $e');
    }
  }

  Future<void> _saveQuickLinks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('attendance_url', _attendanceUrlCtrl.text.trim());
      await prefs.setString(
          'custom_quick_links',
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
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile photo updated')));
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

  // Seating helpers
  List<_SeatTable> _seatingForClass() {
    if (_selectedClassId == null) return [];
    return _seatingByClass.putIfAbsent(_selectedClassId!, () => []);
  }

  Future<void> _loadSeatingLayoutForClass() async {
    if (_selectedClassId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('seating_layout_$_selectedClassId');
      if (raw == null || raw.isEmpty) return;
      final list = jsonDecode(raw) as List<dynamic>;
      final parsed = list
          .map((e) => _SeatTable.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      setState(() => _seatingByClass[_selectedClassId!] = parsed);
    } catch (e) {
      debugPrint('Failed to load seating layout: $e');
    }
  }

  Future<void> _saveSeatingLayoutForClass() async {
    if (_selectedClassId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final tables = _seatingForClass();
      final jsonStr = jsonEncode(tables.map((t) => t.toJson()).toList());
      await prefs.setString('seating_layout_$_selectedClassId', jsonStr);
    } catch (e) {
      debugPrint('Failed to save seating layout: $e');
    }
  }

  void _addTable({required int capacity}) {
    final tables = _seatingForClass();
    final id = 'T${DateTime.now().millisecondsSinceEpoch}-${tables.length + 1}';
    // Place new table at an offset grid to avoid overlap
    final pos = Offset(24.0 + (tables.length % 5) * 120.0,
        24.0 + (tables.length ~/ 5) * 120.0);
    setState(() {
      tables.add(_SeatTable(
          id: id,
          label: 'Table ${tables.length + 1}',
          capacity: capacity,
          position: pos));
    });
    unawaited(_saveSeatingLayoutForClass());
  }

  void _removeTable(int index) {
    final tables = _seatingForClass();
    setState(() => tables.removeAt(index));
    unawaited(_saveSeatingLayoutForClass());
  }

  void _setTableCapacity(int index, int cap) {
    final tables = _seatingForClass();
    setState(() => tables[index] = tables[index].copyWith(capacity: cap));
    unawaited(_saveSeatingLayoutForClass());
  }

  void _moveTable(int index, Offset delta) {
    final tables = _seatingForClass();
    final t = tables[index];
    setState(() => tables[index] = t.copyWith(position: t.position + delta));
    // save lazily not required here for every pan
  }

  void _clearLayout() {
    if (_selectedClassId == null) return;
    setState(() => _seatingByClass[_selectedClassId!] = []);
    unawaited(_saveSeatingLayoutForClass());
  }

  void _autoLayoutGrid() {
    final tables = _seatingForClass();
    const spacingX = 140.0, spacingY = 120.0, pad = 24.0;
    setState(() {
      for (int i = 0; i < tables.length; i++) {
        final row = i ~/ 5;
        final col = i % 5;
        tables[i] = tables[i].copyWith(
            position: Offset(pad + col * spacingX, pad + row * spacingY));
      }
    });
    unawaited(_saveSeatingLayoutForClass());
  }

  List<String> _unassignedStudents() {
    final assigned = <String>{};
    for (final t in _seatingForClass()) {
      for (final s in t.assigned) {
        if (s != null && s.isNotEmpty) assigned.add(s);
      }
    }
    return _currentNames.where((n) => !assigned.contains(n)).toList();
  }

  Future<void> _promptPickStudentForSeat(int tableIndex, int seatIndex) async {
    if (_seatDesignMode) return; // only in Assign mode
    final tables = _seatingForClass();
    final current =
        (seatIndex >= 0 && seatIndex < tables[tableIndex].assigned.length)
            ? tables[tableIndex].assigned[seatIndex]
            : null;
    final all = _currentNames;
    final unassigned = _unassignedStudents();
    final searchCtrl = TextEditingController();
    String query = '';

    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        final bottom = MediaQuery.of(ctx).viewInsets.bottom;
        return StatefulBuilder(builder: (ctx, setModal) {
          List<String> filtered = (query.isEmpty
              ? [
                  ...unassigned,
                  if (current != null && !unassigned.contains(current)) current
                ]
              : all
                  .where((n) => n.toLowerCase().contains(query.toLowerCase()))
                  .toList());
          // Ensure current appears first if present
          if (current != null) {
            filtered.remove(current);
            filtered.insert(0, current);
          }
          return Padding(
            padding: EdgeInsets.only(
                left: 16, right: 16, top: 16, bottom: bottom + 16),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.event_seat_outlined),
                    const SizedBox(width: 8),
                    Text('Assign student to seat',
                        style: Theme.of(ctx).textTheme.titleLarge)
                  ]),
                  const SizedBox(height: 8),
                  TextField(
                    controller: searchCtrl,
                    decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        labelText: 'Search students'),
                    onChanged: (v) => setModal(() => query = v.trim()),
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: filtered.length + (current != null ? 1 : 0),
                      itemBuilder: (ctx, i) {
                        if (current != null && i == 0) {
                          return ListTile(
                            leading: const Icon(Icons.clear),
                            title: const Text('Clear this seat'),
                            onTap: () {
                              _clearSeat(tableIndex, seatIndex);
                              Navigator.of(ctx).pop();
                            },
                          );
                        }
                        final name = filtered[i - (current != null ? 1 : 0)];
                        return ListTile(
                          leading: const Icon(Icons.person),
                          title: Text(name, overflow: TextOverflow.ellipsis),
                          onTap: () {
                            _assignStudentToSeat(tableIndex, seatIndex, name);
                            Navigator.of(ctx).pop();
                          },
                        );
                      },
                    ),
                  ),
                ]),
          );
        });
      },
    );
  }

  void _assignStudentToSeat(int tableIndex, int seatIndex, String student) {
    final tables = _seatingForClass();
    // Remove from any previous seat
    for (int i = 0; i < tables.length; i++) {
      final idx = tables[i].assigned.indexOf(student);
      if (idx != -1) tables[i].assigned[idx] = null;
    }
    setState(() {
      tables[tableIndex].assigned[seatIndex] = student;
    });
    unawaited(_saveSeatingLayoutForClass());
  }

  // Move or swap students when dropping onto a seat.
  void _handleSeatDrop(int tableIndex, int seatIndex, _DragStudent data) {
    final tables = _seatingForClass();
    if (tableIndex < 0 || tableIndex >= tables.length) return;
    final targetTable = tables[tableIndex];
    if (seatIndex < 0 || seatIndex >= targetTable.capacity) return;

    final incoming = data.name;
    final targetCurrent = targetTable.assigned[seatIndex];

    // From unassigned tray -> assign (overwrite if needed)
    if (data.fromTableIndex < 0 || data.fromSeatIndex < 0) {
      setState(() {
        for (final t in tables) {
          final idx = t.assigned.indexOf(incoming);
          if (idx != -1) t.assigned[idx] = null;
        }
        targetTable.assigned[seatIndex] = incoming;
      });
      unawaited(_saveSeatingLayoutForClass());
      return;
    }

    // From another seat -> move or swap
    if (data.fromTableIndex >= 0 && data.fromTableIndex < tables.length) {
      final srcTable = tables[data.fromTableIndex];
      if (data.fromSeatIndex >= 0 &&
          data.fromSeatIndex < srcTable.assigned.length) {
        if (data.fromTableIndex == tableIndex &&
            data.fromSeatIndex == seatIndex) {
          return;
        }
        setState(() {
          if (targetCurrent != null && targetCurrent.isNotEmpty) {
            // Swap
            srcTable.assigned[data.fromSeatIndex] = targetCurrent;
            targetTable.assigned[seatIndex] = incoming;
          } else {
            // Move
            srcTable.assigned[data.fromSeatIndex] = null;
            targetTable.assigned[seatIndex] = incoming;
          }
        });
        unawaited(_saveSeatingLayoutForClass());
      }
    }
  }

  void _clearSeat(int tableIndex, int seatIndex) {
    final tables = _seatingForClass();
    setState(() => tables[tableIndex].assigned[seatIndex] = null);
    unawaited(_saveSeatingLayoutForClass());
  }

  void _clearAssignments() {
    final tables = _seatingForClass();
    setState(() {
      for (final t in tables) {
        for (int i = 0; i < t.assigned.length; i++) {
          t.assigned[i] = null;
        }
      }
    });
    unawaited(_saveSeatingLayoutForClass());
  }

  void _randomizeAssignments() {
    final tables = _seatingForClass();
    final names = List<String>.from(_currentNames)..shuffle();
    final totalSeats = tables.fold<int>(0, (p, t) => p + t.capacity);
    if (names.length > totalSeats) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Not enough seats for ${names.length} students'),
          backgroundColor: Theme.of(context).colorScheme.error));
      return;
    }
    int idx = 0;
    setState(() {
      for (final t in tables) {
        for (int i = 0; i < t.capacity; i++) {
          t.assigned[i] = idx < names.length ? names[idx++] : null;
        }
      }
    });
    unawaited(_saveSeatingLayoutForClass());
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
          .map((r) => (r as List?)
              ?.map((c) => c?.toString() ?? '')
              .toList() ??
            const <String>[])
          .toList()
        : null,
        uploadedAt: DateTime.tryParse(json['uploadedAt'] as String? ?? '') ??
            DateTime.now(),
      );
}

// Seating data model and widgets
class _SeatTable {
  final String id;
  final String label;
  final int capacity;
  final Offset position;
  final List<String?> assigned;

  _SeatTable(
      {required this.id,
      required this.label,
      required this.capacity,
      required this.position})
      : assigned = List<String?>.filled(capacity, null);

  _SeatTable._(
      {required this.id,
      required this.label,
      required this.capacity,
      required this.position,
      required this.assigned});

  _SeatTable copyWith(
      {String? id, String? label, int? capacity, Offset? position}) {
    final newCapacity = capacity ?? this.capacity;
    List<String?> newAssigned = List<String?>.from(assigned);
    if (newCapacity != assigned.length) {
      // Resize keeping existing assignments
      newAssigned = List<String?>.filled(newCapacity, null);
      for (int i = 0; i < newCapacity && i < assigned.length; i++) {
        newAssigned[i] = assigned[i];
      }
    }
    return _SeatTable._(
        id: id ?? this.id,
        label: label ?? this.label,
        capacity: newCapacity,
        position: position ?? this.position,
        assigned: newAssigned);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'capacity': capacity,
        'x': position.dx,
        'y': position.dy,
        'assigned': assigned,
      };

  static _SeatTable fromJson(Map<String, dynamic> map) {
    int cap;
    final rawCap = map['capacity'];
    if (rawCap is num) {
      cap = rawCap.toInt();
    } else if (rawCap is String) {
      cap = int.tryParse(rawCap) ?? 2;
    } else {
      cap = 2;
    }
    final assigned = (map['assigned'] as List?)
            ?.map((e) => e?.toString())
            .toList() ??
        List<String?>.filled(cap, null);
    // Ensure list length equals capacity
    final normalized = List<String?>.filled(cap, null);
    for (int i = 0; i < cap && i < assigned.length; i++) {
      normalized[i] = assigned[i];
    }
    return _SeatTable._(
      id: (map['id'] ?? '') as String,
      label: (map['label'] ?? '') as String,
      capacity: cap,
      position: Offset(
        (map['x'] is num)
            ? (map['x'] as num).toDouble()
            : double.tryParse(map['x']?.toString() ?? '') ?? 24.0,
        (map['y'] is num)
            ? (map['y'] as num).toDouble()
            : double.tryParse(map['y']?.toString() ?? '') ?? 24.0,
      ),
      assigned: normalized,
    );
  }
}

class _TableWidget extends StatelessWidget {
  final int tableIndex;
  final _SeatTable table;
  final bool designMode;
  final void Function(Offset delta) onMove;
  final VoidCallback onMoveEnd;
  final VoidCallback onRemove;
  final void Function(int capacity) onCapacityChanged;
  final void Function(int seatIndex, _DragStudent data) onSeatDrop;
  final void Function(int seatIndex) onClearSeat;
  final void Function(int seatIndex) onTapSeat;

  const _TableWidget(
      {required this.tableIndex,
      required this.table,
      required this.designMode,
      required this.onMove,
      required this.onMoveEnd,
      required this.onRemove,
      required this.onCapacityChanged,
      required this.onSeatDrop,
      required this.onClearSeat,
      required this.onTapSeat});

  int get _columns =>
      table.capacity <= 2 ? table.capacity : (table.capacity <= 4 ? 2 : 3);

  @override
  Widget build(BuildContext context) {
    final cardColor = Theme.of(context).colorScheme.surface;
    return Positioned(
      left: table.position.dx,
      top: table.position.dy,
      child: GestureDetector(
        onPanUpdate: designMode ? (d) => onMove(d.delta) : null,
        onPanEnd: designMode ? (_) => onMoveEnd() : null,
        child: Container(
          width: 160,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Header row with table info
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Table name and seat count
                Expanded(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Table ${tableIndex + 1}',
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge
                            ?.copyWith(fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${table.assigned.where((s) => s != null && s.isNotEmpty).length}/${table.capacity}',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onPrimaryContainer,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Control buttons row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              mainAxisSize: MainAxisSize.max,
              children: [
                // Drag handle
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanUpdate: (d) => onMove(d.delta),
                  onPanEnd: (_) => onMoveEnd(),
                  child: Icon(Icons.drag_indicator,
                      size: 18,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                // Capacity controls in design mode
                if (designMode)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 28,
                          child: IconButton(
                              tooltip: 'Decrease seats',
                              icon: const Icon(Icons.remove_circle_outline,
                                  size: 16),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: table.capacity > 1
                                  ? () => onCapacityChanged(table.capacity - 1)
                                  : null),
                        ),
                        Text('${table.capacity}',
                            style: Theme.of(context).textTheme.labelSmall),
                        SizedBox(
                          width: 28,
                          child: IconButton(
                              tooltip: 'Increase seats',
                              icon: const Icon(Icons.add_circle_outline,
                                  size: 16),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () =>
                                  onCapacityChanged(table.capacity + 1)),
                        ),
                        SizedBox(
                          width: 28,
                          child: IconButton(
                              tooltip: 'Remove table',
                              icon: const Icon(Icons.delete_outline, size: 16),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: onRemove),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            _SeatGrid(
              capacity: table.capacity,
              columns: _columns,
              assigned: table.assigned,
              designMode: designMode,
              tableIndex: tableIndex,
              onSeatDrop: onSeatDrop,
              onClearSeat: onClearSeat,
              onTapSeat: onTapSeat,
            ),
          ]),
        ),
      ),
    );
  }
}

class _SeatGrid extends StatelessWidget {
  final int capacity;
  final int columns;
  final List<String?> assigned;
  final bool designMode;
  final int tableIndex;
  final void Function(int seatIndex, _DragStudent data) onSeatDrop;
  final void Function(int seatIndex) onClearSeat;
  final void Function(int seatIndex) onTapSeat;

  const _SeatGrid(
      {required this.capacity,
      required this.columns,
      required this.assigned,
      required this.designMode,
      required this.tableIndex,
      required this.onSeatDrop,
      required this.onClearSeat,
      required this.onTapSeat});

  @override
  Widget build(BuildContext context) {
    final rows = (capacity / columns).ceil();
    return Column(children: [
      for (int r = 0; r < rows; r++)
        Row(children: [
          for (int c = 0; c < columns; c++)
            Expanded(
                child: _SeatCell(
                    index: r * columns + c,
                    tableIndex: tableIndex,
                    assigned: r * columns + c < assigned.length
                        ? assigned[r * columns + c]
                        : null,
                    designMode: designMode,
                    onSeatDrop: onSeatDrop,
                    onClearSeat: onClearSeat,
                    onTapSeat: onTapSeat)),
        ]),
    ]);
  }
}

class _SeatCell extends StatelessWidget {
  final int index;
  final int tableIndex;
  final String? assigned;
  final bool designMode;
  final void Function(int seatIndex, _DragStudent data) onSeatDrop;
  final void Function(int seatIndex) onClearSeat;
  final void Function(int seatIndex) onTapSeat;

  const _SeatCell(
      {required this.index,
      required this.tableIndex,
      required this.assigned,
      required this.designMode,
      required this.onSeatDrop,
      required this.onClearSeat,
      required this.onTapSeat});

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).colorScheme.surfaceContainer;
    final border = Theme.of(context).colorScheme.outlineVariant;
    final canInteract = !designMode;

    return MouseRegion(
      cursor: canInteract ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: canInteract ? () => onTapSeat(index) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.all(4),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          height: 42,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: canInteract
                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)
                  : border,
              width: canInteract ? 1.5 : 1,
            ),
          ),
          child: assigned == null
              ? Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.event_seat_outlined,
                        size: 14,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant
                            .withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          '${index + 1}',
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant
                                        .withValues(alpha: 0.7),
                                  ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                )
              : Align(
                  alignment: Alignment.centerLeft,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.person,
                          size: 14,
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          assigned!,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onPrimaryContainer,
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _StudentChip extends StatelessWidget {
  final String name;

  const _StudentChip({required this.name});

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).colorScheme.primaryContainer;
    final fg = Theme.of(context).colorScheme.onPrimaryContainer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.person, size: 14),
        const SizedBox(width: 4),
        ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(name,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: fg))),
      ]),
    );
  }
}

// Drag payload for seating moves/swaps
class _DragStudent {
  final String name;
  final int fromTableIndex; // -1 for unassigned tray
  final int fromSeatIndex; // -1 for unassigned tray
  const _DragStudent(
      {required this.name,
      required this.fromTableIndex,
      required this.fromSeatIndex});
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

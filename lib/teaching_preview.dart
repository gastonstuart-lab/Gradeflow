import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:gradeflow/components/teaching_preview_room.dart';
import 'package:gradeflow/components/teaching_preview_quiz.dart';
import 'package:gradeflow/components/teaching_preview_room_builder.dart';
import 'package:gradeflow/components/teaching_preview_desktop.dart';
import 'package:gradeflow/components/teaching_preview_clock.dart';
import 'package:url_launcher/url_launcher.dart';

void main() => runApp(const TeachingPreview());

const _ink = Color(0xff173457);
const _muted = Color(0xff60758c);
const _paper = Color(0xfff0f5fa);
const _green = Color(0xff1769ce);
const _schoolAttendanceUrl = String.fromEnvironment('SCHOOL_ATTENDANCE_URL');

/// Isolated interaction preview. No services, accounts or durable writes.
class TeachingPreview extends StatefulWidget {
  const TeachingPreview({super.key});

  @override
  State<TeachingPreview> createState() => _TeachingPreviewState();
}

class _TeachingPreviewState extends State<TeachingPreview> {
  bool _darkMode = false;

  ThemeData _theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xff1769ce),
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor:
          dark ? const Color(0xff07131f) : const Color(0xfff0f5fa),
      colorScheme: scheme,
      textTheme: (dark ? ThemeData.dark() : ThemeData.light()).textTheme.apply(
            bodyColor:
                dark ? const Color(0xffe7f0f8) : const Color(0xff173457),
            displayColor:
                dark ? const Color(0xfff2f7fb) : const Color(0xff173457),
          ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor:
              dark ? const Color(0xff1b8cff) : const Color(0xff1769ce),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'InstructOS · Teaching preview',
        theme: _theme(Brightness.light),
        darkTheme: _theme(Brightness.dark),
        themeMode: _darkMode ? ThemeMode.dark : ThemeMode.light,
        home: TeachingJourney(
          darkMode: _darkMode,
          onDarkModeChanged: (value) => setState(() => _darkMode = value),
        ),
      );
}

class TeachingJourney extends StatefulWidget {
  final bool darkMode;
  final ValueChanged<bool> onDarkModeChanged;

  const TeachingJourney({
    super.key,
    this.darkMode = false,
    required this.onDarkModeChanged,
  });

  @override
  State<TeachingJourney> createState() => _TeachingJourneyState();
}

class _TeachingJourneyState extends State<TeachingJourney> {
  // Stable synthetic identities; display names never serve as record keys.
  static const _students = <String, String>{
    's1': 'Alex',
    's2': 'Bella',
    's3': 'Charlie',
    's4': 'Dara',
    's5': 'Eli',
    's6': 'Freya',
    's7': 'George',
    's8': 'Hana',
    's9': 'Isaac',
    's10': 'Jules',
    's11': 'Kai',
    's12': 'Lena',
  };
  final List<String?> _seats = List.generate(
      24, (i) => i % 4 < 2 ? 's${(i ~/ 4) * 2 + i % 4 + 1}' : null);
  final Map<String, String> _homework = {};
  int _tableColumns = 3;
  bool _customRoom = false;
  int _roomRevision = 0;

  Future<void> _buildRoom() async {
    setState(_cancelChooser);
    final layout = await showDialog<PreviewRoomLayout>(
        context: context,
        builder: (_) => PreviewRoomBuilder(
            initial: PreviewRoomLayout(_seats.length ~/ 4, _tableColumns),
            students: _students.length));
    if (!mounted || layout == null) return;
    setState(() {
      final occupants = _seats.whereType<String>().toList();
      _seats.clear();
      _seats.addAll(List<String?>.filled(layout.tables * 4, null));
      for (var i = 0; i < occupants.length; i++) {
        _seats[(i % layout.tables) * 4 + i ~/ layout.tables] = occupants[i];
      }
      _tableColumns = layout.columns;
      _customRoom = true;
      _roomRevision++;
      _panel = null;
    });
  }

  final Map<String, String> _notes = {};
  final Set<String> _followUps = {};
  final Map<String, int> _participation = {};
  final Map<String, int> _behaviour = {};
  final Map<String, int> _classwork = {};
  final Map<String, String> _attendance = {};
  final Map<String, int> _groups = {};
  final List<String> _lessonLog = [];
  final _note = TextEditingController();
  final _classNote = TextEditingController();
  final _continuation = TextEditingController();
  bool _teaching = false;
  bool _started = false;
  bool _finished = false;
  bool _checking = false;
  bool _quizzing = false;
  bool _attendanceMode = false;
  bool _groupMode = false;
  bool _presentationMode = false;
  bool _toolsDrawerOpen = false;
  String _toolsSection = 'Class';
  List<int>? _lastSeatSwap;
  final _quiz = PreviewQuizBook();
  final _desktop = PreviewDesktopBook();
  String? _panel;
  String? _student;
  DateTime? _timerEnd;
  int _seconds = 300;
  Timer? _ticker;
  int _timerDuration = 300;
  bool _timerExpanded = false;
  Timer? _chooserTimer;
  bool _choosing = false;
  String? _spotlightStudent;
  int? _spotlightTable;
  String? _choiceResult;
  final _random = Random();
  static final _numbers = {
    for (var i = 1; i <= 12; i++) 's$i': i.toString().padLeft(2, '0')
  };

  void _cancelChooser() {
    _chooserTimer?.cancel();
    _choosing = false;
    _spotlightStudent = null;
    _spotlightTable = null;
    _choiceResult = null;
  }

  void _pick(bool table) {
    _cancelChooser();
    final candidates = table
        ? [
            for (var i = 0; i < _seats.length ~/ 4; i++)
              if (_seats.skip(i * 4).take(4).any((id) => id != null)) '$i'
          ]
        : _seats.whereType<String>().toList();
    if (candidates.isEmpty) return;
    final winner = candidates[_random.nextInt(candidates.length)];
    var tick = 0;
    final reduced = MediaQuery.disableAnimationsOf(context);
    void step() {
      if (!mounted) return;
      final complete = reduced || tick >= 18;
      final candidate =
          complete ? winner : candidates[_random.nextInt(candidates.length)];
      setState(() {
        _choosing = !complete;
        _panel = null;
        _spotlightStudent = table ? null : candidate;
        _spotlightTable = table ? int.parse(candidate) : null;
        final label = table
            ? 'Table ${int.parse(candidate) + 1}'
            : '${_numbers[candidate]} · ${_students[candidate]}';
        _choiceResult = complete ? 'Selected: $label' : 'Choosing… $label';
      });
      if (!complete) {
        tick++;
        _chooserTimer = Timer(Duration(milliseconds: 75 + tick * 11), step);
      }
    }

    step();
  }

  void _toggleTimer() => setState(() {
        _timerEnd = _timerEnd == null
            ? DateTime.now().add(Duration(seconds: _seconds))
            : null;
      });

  void _leaveToToday() => setState(() {
        _cancelChooser();
        _teaching = false;
        _panel = null;
      });

  @override
  void initState() {
    super.initState();
    _quiz.addListener(_quizChanged);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_timerEnd == null) return;
      setState(() {
        _seconds =
            ((_timerEnd!.difference(DateTime.now()).inMilliseconds + 999) ~/
                    1000)
                .clamp(0, 3600);
        if (_seconds == 0) _timerEnd = null;
      });
    });
  }

  @override
  void dispose() {
    _quiz.removeListener(_quizChanged);
    _quiz.dispose();
    _desktop.dispose();
    _ticker?.cancel();
    _chooserTimer?.cancel();
    _note.dispose();
    _classNote.dispose();
    _continuation.dispose();
    super.dispose();
  }

  String get _clock =>
      '${(_seconds ~/ 60).toString().padLeft(2, '0')}:${(_seconds % 60).toString().padLeft(2, '0')}';
  int get _checked => _homework.values.where((v) => v != 'Unchecked').length;
  int get _presentCount =>
      _attendance.values.where((v) => v == 'Present').length;
  List<String> get _unseatedStudents => _students.keys
      .where((id) => !_seats.contains(id))
      .toList(growable: false);

  void _log(String message) {
    final now = DateTime.now();
    final time =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    _lessonLog.insert(0, '$time · $message');
    if (_lessonLog.length > 20) _lessonLog.removeLast();
  }

  void _adjustMetric(Map<String, int> metric, String id, int amount, String label) {
    setState(() {
      metric[id] = (metric[id] ?? 0) + amount;
      _log('${_students[id]} · $label ${amount > 0 ? '+' : ''}$amount');
    });
  }

  void _setAttendance(String id, String status) {
    setState(() {
      _attendance[id] = status;
      _log('${_students[id]} · attendance: $status');
    });
  }

  void _makeGroups() {
    final ids = _seats.whereType<String>().toList()..shuffle(_random);
    setState(() {
      _groups.clear();
      for (var i = 0; i < ids.length; i++) {
        _groups[ids[i]] = i % 3 + 1;
      }
      _groupMode = true;
      _log('Made 3 quick groups');
    });
  }

  void _undoSeatSwap() {
    final swap = _lastSeatSwap;
    if (swap == null) return;
    setState(() {
      final from = swap[0];
      final to = swap[1];
      final displaced = _seats[to];
      _seats[to] = _seats[from];
      _seats[from] = displaced;
      _lastSeatSwap = null;
      _log('Undid last seat move');
    });
  }

  void _openStudent(String id) {
    setState(() {
      _toolsDrawerOpen = false;
      _student = id;
      _note.text = _notes[id] ?? '';
      _panel = _quizzing ? 'quiz-student' : 'student';
    });
  }

  void _openToolsDrawer() => setState(() {
        _panel = null;
        _toolsDrawerOpen = true;
      });

  void _closeToolsDrawer() => setState(() => _toolsDrawerOpen = false);

  void _showPanel(String panel) => setState(() {
        _toolsDrawerOpen = false;
        _panel = panel;
      });

  void _quizChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _openAttendance() async {
    try {
      final opened = await launchUrl(Uri.parse(_schoolAttendanceUrl),
          mode: LaunchMode.externalApplication, webOnlyWindowName: '_blank');
      if (opened) return;
    } catch (_) {
      // Keep the teaching context when a browser blocks a new tab.
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Could not open attendance. Allow the new tab and try again.')));
    }
  }

  void _startQuiz() {
    _start();
    setState(() {
      _toolsDrawerOpen = false;
      _quizzing = true;
      _checking = false;
      _panel = 'quiz';
    });
  }

  void _start() => setState(() {
        _started = true;
        _finished = false;
        _teaching = true;
        _panel = null;
      });

  Color get _surface =>
      widget.darkMode ? const Color(0xff0b1b2a) : const Color(0xfffbfdff);
  Color get _surfaceSoft =>
      widget.darkMode ? const Color(0xff102334) : const Color(0xfff6f9fc);
  Color get _line =>
      widget.darkMode ? const Color(0xff29445e) : const Color(0xffdce7ef);
  Color get _primaryText =>
      widget.darkMode ? const Color(0xffeef6ff) : const Color(0xff173457);
  Color get _secondaryText =>
      widget.darkMode ? const Color(0xff9fb4c7) : const Color(0xff60758c);

  Widget _label(String text) => Text(text,
      style: TextStyle(
          fontSize: 12,
          letterSpacing: 1.6,
          fontWeight: FontWeight.w700,
          color: widget.darkMode ? const Color(0xff9fb4c7) : _muted));

  Widget _themeToggle() => Container(
        height: 38,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: widget.darkMode
              ? const Color(0xff102235)
              : const Color(0xffedf4fa),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: widget.darkMode
                ? const Color(0xff29445e)
                : const Color(0xffd7e4ee),
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          _themeChoice(
            icon: Icons.light_mode_rounded,
            selected: !widget.darkMode,
            tooltip: 'Light mode',
            onTap: () => widget.onDarkModeChanged(false),
          ),
          _themeChoice(
            icon: Icons.dark_mode_rounded,
            selected: widget.darkMode,
            tooltip: 'Dark mode',
            onTap: () => widget.onDarkModeChanged(true),
          ),
        ]),
      );

  Widget _themeChoice({
    required IconData icon,
    required bool selected,
    required String tooltip,
    required VoidCallback onTap,
  }) =>
      Tooltip(
        message: tooltip,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            width: 34,
            height: 30,
            decoration: BoxDecoration(
              color: selected
                  ? (widget.darkMode
                      ? const Color(0xff1d4f86)
                      : Colors.white)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
              boxShadow: selected
                  ? const [
                      BoxShadow(
                          color: Color(0x181b416a),
                          blurRadius: 8,
                          offset: Offset(0, 2))
                    ]
                  : null,
            ),
            child: Icon(
              icon,
              size: 17,
              color: selected
                  ? (widget.darkMode
                      ? const Color(0xffdceeff)
                      : const Color(0xff1769ce))
                  : const Color(0xff8295a8),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        bottomNavigationBar:
            _timerExpanded || _presentationMode ? null : _dock(),
        body: _timerExpanded
            ? _timerFocus()
            : _presentationMode
                ? _presentationClassroom()
                : SafeArea(
                child: Column(children: [
                  Container(
                    width: double.infinity,
                    color: widget.darkMode
                        ? const Color(0xff091724)
                        : const Color(0xffe4eef8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 7),
                    child: Text(
                        'INTERACTIVE PREVIEW  ·  Fictional class · Changes last until you refresh',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 10.5,
                            letterSpacing: .25,
                            fontWeight: FontWeight.w600,
                            color: _secondaryText)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 26, vertical: 12),
                    decoration: BoxDecoration(
                      color: _surface,
                      boxShadow: [
                        BoxShadow(
                            color: widget.darkMode
                                ? Colors.black.withValues(alpha: .28)
                                : const Color(0x0b123a62),
                            blurRadius: 18,
                            offset: const Offset(0, 4))
                      ],
                    ),
                    child: Row(children: [
                      Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                  colors: [
                                    Color(0xff1769ce),
                                    Color(0xff158d8a)
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight),
                              borderRadius: BorderRadius.circular(13),
                              boxShadow: const [
                                BoxShadow(
                                    color: Color(0x251769ce),
                                    blurRadius: 14,
                                    offset: Offset(0, 5))
                              ]),
                          child: const Icon(Icons.layers_rounded,
                              color: Colors.white, size: 23)),
                      const SizedBox(width: 11),
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('InstructOS',
                                style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -.35,
                                    fontSize: 20,
                                    color: _primaryText)),
                            Text('Teacher workspace',
                                style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: _secondaryText)),
                          ]),
                      const Spacer(),
                      if (MediaQuery.sizeOf(context).width >= 720)
                        Container(
                          margin: const EdgeInsets.only(right: 14),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                              color: widget.darkMode
                                  ? (_teaching
                                      ? const Color(0xff103c39)
                                      : const Color(0xff102b45))
                                  : (_teaching
                                      ? const Color(0xffe2f4f1)
                                      : const Color(0xffeaf3ff)),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                  color: widget.darkMode
                                      ? const Color(0xff28536c)
                                      : (_teaching
                                          ? const Color(0xffbfe4dd)
                                          : const Color(0xffcfe1f4)))),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(
                                _teaching
                                    ? Icons.radio_button_checked_rounded
                                    : Icons.home_rounded,
                                size: 13,
                                color: _teaching
                                    ? const Color(0xff148c8a)
                                    : const Color(0xff1769ce)),
                            const SizedBox(width: 6),
                            Text(_teaching ? 'LIVE CLASS' : 'TODAY',
                                style: TextStyle(
                                    fontSize: 9.5,
                                    letterSpacing: 1.1,
                                    fontWeight: FontWeight.w900,
                                    color: _teaching
                                        ? const Color(0xff148c8a)
                                        : const Color(0xff1769ce))),
                          ]),
                        ),
                      if (_teaching)
                        TextButton.icon(
                          onPressed: _leaveToToday,
                          icon: const Icon(Icons.arrow_back_rounded, size: 18),
                          label: const Text('Today'),
                        ),
                      const SizedBox(width: 8),
                      _themeToggle(),
                      const SizedBox(width: 10),
                      TeachingPreviewClock(
                          color: widget.darkMode
                              ? const Color(0xffdce9f4)
                              : const Color(0xff173457),
                          showDate: MediaQuery.sizeOf(context).width >= 600),
                    ]),
                  ),
                  const Divider(height: 1),
                  Expanded(
                      child: AnimatedSwitcher(
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 180),
                    layoutBuilder: (current, previous) => Stack(
                        fit: StackFit.expand,
                        children: [...previous, if (current != null) current]),
                    child: KeyedSubtree(
                        key: ValueKey(_teaching),
                        child: _teaching ? _classroom() : _today()),
                  )),
                ]),
              ),
      );

  void _openTool(String tool) {
    if (tool == 'home') {
      _leaveToToday();
      return;
    }
    _cancelChooser();
    if (tool == 'quiz') {
      _startQuiz();
      return;
    }
    _start();
    if (tool == 'room') {
      _buildRoom();
      return;
    }
    if (tool == 'timer') _showPanel('timer');
  }

  Widget _dock() => SafeArea(
      top: false,
      child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Container(
                margin:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: _line),
                    boxShadow: [
                      BoxShadow(
                          color: widget.darkMode
                              ? Colors.black.withValues(alpha: .35)
                              : const Color(0x181b416a),
                          blurRadius: 24,
                          offset: const Offset(0, 6))
                    ]),
                child: Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      PopupMenuButton<String>(
                        tooltip: 'Start menu',
                        onSelected: _openTool,
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                              value: 'home', child: Text('Teacher desktop')),
                          PopupMenuItem(
                              value: 'class', child: Text('Demo classroom')),
                          PopupMenuItem(
                              value: 'quiz', child: Text('Quiz entry')),
                          PopupMenuItem(
                              value: 'timer', child: Text('Focus timer')),
                          PopupMenuItem(
                              value: 'room', child: Text('Room builder'))
                        ],
                        child: Container(
                            decoration: BoxDecoration(
                                color: const Color(0xff153858),
                                borderRadius: BorderRadius.circular(16)),
                            padding: const EdgeInsets.all(12),
                            child:
                                Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.apps, size: 20, color: Colors.white),
                              SizedBox(width: 6),
                              Text('Start',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600))
                            ])),
                      ),
                      TextButton.icon(
                          style: TextButton.styleFrom(
                              backgroundColor: !_teaching
                                  ? (widget.darkMode
                                      ? const Color(0xff17395d)
                                      : const Color(0xffe9f2ff))
                                  : null),
                          onPressed: _leaveToToday,
                          icon: const Icon(Icons.home_outlined, size: 20),
                          label: const Text('Home')),
                      TextButton.icon(
                          style: TextButton.styleFrom(
                              backgroundColor: _teaching
                                  ? (widget.darkMode
                                      ? const Color(0xff17395d)
                                      : const Color(0xffe9f2ff))
                                  : null),
                          onPressed: () => _openTool('class'),
                          icon: const Icon(Icons.groups_outlined, size: 20),
                          label: const Text('Classroom')),
                    ]),
              ))));

  Widget _today() => TeachingPreviewDesktop(
        teacherName: 'Stuart',
        book: _desktop,
        classCard: _classCard(),
        onClass: _start,
        onQuiz: _startQuiz,
        onTimer: () => _openTool('timer'),
        onRoom: () => _openTool('room'),
        onAttendance: _schoolAttendanceUrl.isEmpty ? null : _openAttendance,
      );

  Widget _heroLabel(String text) => Text(text,
      style: const TextStyle(
          color: Color(0xffaee3e1),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.8));

  Widget _classCard() => Container(
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [
              Color(0xff103553),
              Color(0xff1a5875),
              Color(0xff148b88)
            ], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x35234b74),
                  blurRadius: 34,
                  offset: Offset(0, 14))
            ],
            border: Border.all(color: const Color(0xff3a8093))),
        child: Stack(children: [
          Positioned(
            right: -18,
            top: -22,
            child: IgnorePointer(
              child: Opacity(
                opacity: .15,
                child: SizedBox(
                  width: 330,
                  height: 250,
                  child: Stack(children: [
                    Positioned(
                      right: 18,
                      top: 16,
                      child: Icon(Icons.eco_rounded,
                          size: 150, color: Colors.white),
                    ),
                    Positioned(
                      right: 130,
                      top: 78,
                      child: Icon(Icons.water_drop_rounded,
                          size: 88, color: Colors.white),
                    ),
                    Positioned(
                      right: 72,
                      top: 138,
                      child: Icon(Icons.hub_rounded,
                          size: 112, color: Colors.white),
                    ),
                  ]),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(34),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: _heroLabel(_finished
                          ? 'LESSON WRAPPED UP'
                          : _started
                              ? 'YOUR CLASS IS STILL HERE'
                              : 'UP NEXT · 10:10–11:00'),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .11),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: .18))),
                      child: const Text('ECOSYSTEMS',
                          style: TextStyle(
                              color: Color(0xffd7f3ee),
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.15)),
                    ),
                  ]),
                  const SizedBox(height: 18),
                  const Text('J2 Science',
                      style: TextStyle(
                          fontSize: 48,
                          height: 1,
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.4)),
                  const SizedBox(height: 9),
                  const Text('Room 204 · 12 students · Ecosystems',
                      style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xffd6e6ef))),
                  const SizedBox(height: 28),
                  Text(_finished
                      ? 'Ready for next time'
                      : 'Pick up where you left off',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                          color: Colors.white)),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 650),
                    child: Text(
                        _finished && _continuation.text.trim().isNotEmpty
                            ? _continuation.text.trim()
                            : 'Continue food webs. Ask students what happens when one species disappears.',
                        style: const TextStyle(
                            height: 1.55,
                            fontSize: 15.5,
                            color: Color(0xffe0edf3))),
                  ),
                  const SizedBox(height: 22),
                  Wrap(spacing: 20, runSpacing: 12, children: [
                    _signal(
                        Icons.assignment_outlined,
                        _finished
                            ? '$_checked of 12 homework checks'
                            : 'Food web worksheet · Homework'),
                    _signal(Icons.chat_bubble_outline,
                        '${_followUps.length} student follow-ups'),
                  ]),
                  const SizedBox(height: 30),
                  Wrap(spacing: 10, runSpacing: 10, children: [
                    FilledButton.icon(
                        style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xff164f72),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 16)),
                        onPressed: _start,
                        icon: const Icon(Icons.arrow_forward_rounded),
                        label: Text(_finished
                            ? 'Reopen demo lesson'
                            : _started
                                ? 'Return to class'
                                : 'Start class')),
                    OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(
                                color:
                                    Colors.white.withValues(alpha: .42)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 16)),
                        onPressed: _startQuiz,
                        icon: const Icon(Icons.edit_note),
                        label: const Text('Enter quiz scores')),
                  ]),
                  if (_finished) ...[
                    const SizedBox(height: 16),
                    const Text(
                        'Lesson summary kept in this preview session only.',
                        style: TextStyle(
                            color: Color(0xffd6e6ef), fontSize: 12)),
                  ],
                ]),
          ),
        ]),
      );

  Widget _signal(IconData icon, String text) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 18, color: Color(0xffaee3e1)),
        const SizedBox(width: 8),
        Flexible(
            child:
                Text(text, style: const TextStyle(color: Color(0xffd6e6ef)))),
      ]);

  Widget _presentationClassroom() => Material(
        color: const Color(0xffeef5f8),
        child: SafeArea(
          child: Stack(children: [
            Positioned.fill(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 24, 28, 110),
                child: Column(children: [
                  Row(children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [Color(0xff1769ce), Color(0xff158d8a)]),
                          borderRadius: BorderRadius.circular(14)),
                      child: const Icon(Icons.science_rounded,
                          color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('J2 Science',
                                style: TextStyle(
                                    fontSize: 27,
                                    height: 1,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xff173457))),
                            SizedBox(height: 5),
                            Text('Ecosystems · Room 204',
                                style: TextStyle(
                                    color: _muted,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600)),
                          ]),
                    ),
                    if (_timerEnd != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 15, vertical: 9),
                        decoration: BoxDecoration(
                            color: const Color(0xff173457),
                            borderRadius: BorderRadius.circular(999)),
                        child: Text(_clock,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w900)),
                      ),
                  ]),
                  const SizedBox(height: 22),
                  Container(
                    width: 235,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                        color: const Color(0xffddeae7),
                        borderRadius: BorderRadius.circular(999)),
                    child: const Text('FRONT OF CLASSROOM',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Color(0xff58736e),
                            fontSize: 10,
                            letterSpacing: 1.8,
                            fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(height: 20),
                  TeachingPreviewRoom(
                    tableColumns: _tableColumns,
                    allSideSeats: _customRoom,
                    studentNumbers: _numbers,
                    spotlightStudent: _spotlightStudent,
                    spotlightTable: _spotlightTable,
                    choosing: _choosing,
                    students: _students,
                    seats: _seats,
                    homework: _homework,
                    attendance: _attendance,
                    groups: _groups,
                    checking: _checking,
                    attendanceMode: false,
                    groupMode: _groupMode,
                    presentation: true,
                    selectedStudent: null,
                    onStudent: (id) =>
                        setState(() => _spotlightStudent = id),
                    onDone: (id) => setState(() {
                      _homework[id] = 'Done';
                      _log('${_students[id]} · homework done');
                    }),
                    onMove: (_, __) {},
                  ),
                ]),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                margin: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xffd7e4ed)),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0x24163f65),
                          blurRadius: 24,
                          offset: Offset(0, 8))
                    ]),
                child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    alignment: WrapAlignment.center,
                    children: [
                      TextButton.icon(
                          onPressed: () =>
                              setState(() => _timerExpanded = true),
                          icon: const Icon(Icons.timer_outlined, size: 18),
                          label: Text(_timerEnd == null ? 'Timer' : _clock)),
                      TextButton.icon(
                          onPressed: _choosing ? null : () => _pick(false),
                          icon:
                              const Icon(Icons.person_search_outlined, size: 18),
                          label: const Text('Random')),
                      TextButton.icon(
                          onPressed: _choosing ? null : () => _pick(true),
                          icon: const Icon(Icons.groups_outlined, size: 18),
                          label: const Text('Table')),
                      TextButton.icon(
                          onPressed: () {
                            if (_groups.isEmpty) {
                              _makeGroups();
                            } else {
                              setState(() => _groupMode = !_groupMode);
                            }
                          },
                          icon: const Icon(Icons.groups_2_outlined, size: 18),
                          label: const Text('Groups')),
                      TextButton.icon(
                          onPressed: () => setState(() {
                            _checking = !_checking;
                            _quizzing = false;
                          }),
                          icon:
                              const Icon(Icons.assignment_outlined, size: 18),
                          label: const Text('Check')),
                      const SizedBox(width: 4),
                      FilledButton.icon(
                          onPressed: () =>
                              setState(() => _presentationMode = false),
                          icon:
                              const Icon(Icons.fullscreen_exit_rounded, size: 18),
                          label: const Text('Exit presentation')),
                    ]),
              ),
            ),
          ]),
        ),
      );

  Widget _classroom() => LayoutBuilder(builder: (context, size) {
        final wide = size.maxWidth >= 1050;
        const motion = Duration(milliseconds: 260);
        const curve = Curves.easeOutCubic;

        if (wide) {
          return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            AnimatedContainer(
              duration: motion,
              curve: curve,
              width: _toolsDrawerOpen ? 318 : 0,
              child: ClipRect(
                child: Align(
                  alignment: Alignment.centerLeft,
                  widthFactor: _toolsDrawerOpen ? 1 : 0,
                  child: SizedBox(width: 318, child: _leftToolsDrawer()),
                ),
              ),
            ),
            Expanded(child: _map()),
            AnimatedContainer(
              duration: motion,
              curve: curve,
              width: _panel != null ? 372 : 0,
              child: ClipRect(
                child: Align(
                  alignment: Alignment.centerRight,
                  widthFactor: _panel != null ? 1 : 0,
                  child: SizedBox(width: 372, child: _panelBody()),
                ),
              ),
            ),
          ]);
        }

        return Stack(children: [
          Positioned.fill(child: _map()),
          if (_toolsDrawerOpen || _panel != null)
            Positioned.fill(
              child: AnimatedOpacity(
                duration: motion,
                opacity: .22,
                child: GestureDetector(
                  onTap: () => setState(() {
                    _toolsDrawerOpen = false;
                    _panel = null;
                  }),
                  child: Container(color: Colors.black),
                ),
              ),
            ),
          AnimatedPositioned(
            duration: motion,
            curve: curve,
            left: _toolsDrawerOpen ? 0 : -340,
            top: 0,
            bottom: 0,
            width: min(330.0, size.maxWidth * .88),
            child: _leftToolsDrawer(),
          ),
          AnimatedPositioned(
            duration: motion,
            curve: curve,
            right: _panel != null ? 0 : -400,
            top: 0,
            bottom: 0,
            width: min(380.0, size.maxWidth * .92),
            child: _panelBody(),
          ),
        ]);
      });

  Widget _leftToolsDrawer() => Material(
        color: widget.darkMode
            ? const Color(0xff0b1b2a)
            : const Color(0xfffbfdff),
        elevation: 12,
        shadowColor: Colors.black26,
        child: SafeArea(
          right: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 30),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [Color(0xff1769ce), Color(0xff158d8a)]),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.tune_rounded,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Text('Class tools',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: widget.darkMode
                                  ? const Color(0xffeef6ff)
                                  : const Color(0xff173457))),
                    ),
                    IconButton(
                      tooltip: 'Close class tools',
                      onPressed: _closeToolsDrawer,
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Text(
                    'Everything you need, without leaving the room.',
                    style: TextStyle(
                        color: widget.darkMode
                            ? const Color(0xff9fb4c7)
                            : _muted,
                        fontSize: 12,
                        height: 1.4),
                  ),
                  const SizedBox(height: 18),
                  ..._toolsPanel(),
                ]),
          ),
        ),
      );

  Widget _map() => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xff123a62), Color(0xff17666f)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x24163f65),
                    blurRadius: 24,
                    offset: Offset(0, 9))
              ],
            ),
            child: Row(children: [
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const Text('TEACHING · ROOM 204',
                        style: TextStyle(
                            color: Color(0xffbfe8e4),
                            fontSize: 10.5,
                            letterSpacing: 1.8,
                            fontWeight: FontWeight.w900)),
                    const SizedBox(height: 7),
                    const Text('J2 Science',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            height: 1,
                            letterSpacing: -.7,
                            fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    Text(
                      _checking
                          ? 'Homework check · $_checked of 12 checked'
                          : _quizzing
                              ? '${_quiz.selected.name} · ${_quiz.entered(_students.keys)} of 12 entered'
                              : 'Your classroom · Select a student when you need them',
                      style: const TextStyle(
                          color: Color(0xffd8e8ee),
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                  ])),
              const SizedBox(width: 16),
              FilledButton.icon(
                  style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xff164f72),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 15)),
                  onPressed: () => _showPanel('finish'),
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                  label: const Text('Finish class')),
            ]),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: widget.darkMode
                    ? const Color(0xff0d1f2f)
                    : Colors.white.withValues(alpha: .92),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _line),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x0c163f65),
                      blurRadius: 16,
                      offset: Offset(0, 5))
                ]),
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              ActionChip(
                  label: const Text('Room setup'),
                  avatar:
                      const Icon(Icons.dashboard_customize_outlined, size: 18),
                  onPressed: _buildRoom),
              ActionChip(
                  label: const Text('Pick student'),
                  avatar: const Icon(Icons.person_search_outlined, size: 18),
                  onPressed: _choosing ? null : () => _pick(false)),
              ActionChip(
                  label: const Text('Pick table'),
                  avatar: const Icon(Icons.groups_outlined, size: 18),
                  onPressed: _choosing ? null : () => _pick(true)),
              if (_choosing)
                ActionChip(
                    label: const Text('Stop chooser'),
                    onPressed: () => setState(_cancelChooser)),
              FilterChip(
                  label: const Text('Homework check'),
                  selected: _checking,
                  showCheckmark: false,
                  selectedColor: const Color(0xffe2f3f1),
                  avatar: const Icon(Icons.assignment_outlined, size: 18),
                  onSelected: (value) => setState(() {
                        _checking = value;
                        _quizzing = false;
                        _panel = null;
                      })),
              FilterChip(
                  label: const Text('Quiz scores'),
                  selected: _quizzing,
                  showCheckmark: false,
                  selectedColor: const Color(0xffe8f1ff),
                  avatar: const Icon(Icons.edit_note, size: 18),
                  onSelected: (value) => setState(() {
                        _quizzing = value;
                        _checking = false;
                        _panel = value ? 'quiz' : null;
                      })),
              if (_schoolAttendanceUrl.isNotEmpty)
                Tooltip(
                  message: 'School attendance · opens a new tab',
                  child: ActionChip(
                    label: const Text('School attendance'),
                    avatar: const Icon(Icons.open_in_new, size: 18),
                    onPressed: _openAttendance,
                  ),
                ),
              ActionChip(
                  label: Text(_timerEnd != null ? _clock : 'Timer'),
                  avatar: const Icon(Icons.timer_outlined, size: 18),
                  onPressed: () => _showPanel('timer')),
              ActionChip(
                  label: const Text('Lesson focus'),
                  avatar: const Icon(Icons.menu_book_outlined, size: 18),
                  onPressed: () => _showPanel('lesson')),
              ActionChip(
                  label: const Text('Class tools'),
                  avatar: const Icon(Icons.tune_rounded, size: 18),
                  onPressed: _openToolsDrawer),
              ActionChip(
                  label: const Text('Present'),
                  avatar: const Icon(Icons.present_to_all_rounded, size: 18),
                  onPressed: () => setState(() {
                        _panel = null;
                        _presentationMode = true;
                      })),
              if (_lastSeatSwap != null)
                ActionChip(
                    label: const Text('Undo move'),
                    avatar: const Icon(Icons.undo_rounded, size: 18),
                    onPressed: _undoSeatSwap),
            ]),
          ),
          const SizedBox(height: 10),
          if (_choiceResult != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Semantics(
                  liveRegion: !_choosing,
                  child: Container(
                    key: const ValueKey('chooser-result'),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xfffff4d8),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xffe7bf66)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(
                        _choosing
                            ? Icons.casino_outlined
                            : Icons.check_circle_outline_rounded,
                        size: 15,
                        color: const Color(0xff95691f),
                      ),
                      const SizedBox(width: 6),
                      Text(_choiceResult!,
                          style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xff95691f))),
                    ]),
                  ),
                ),
              ),
            ),
          if (_checking)
            _modeNotice(
                icon: Icons.assignment_turned_in_outlined,
                title: 'Food web worksheet',
                detail:
                    '$_checked of 12 checked · Tap Done at a seat. Select a student for other statuses.')
          else if (_quizzing)
            _modeNotice(
                icon: Icons.edit_note_rounded,
                title: _quiz.selected.name,
                detail:
                    'Out of ${_quiz.maximumLabel} · ${_quiz.entered(_students.keys)} of 12 entered',
                action: TextButton(
                    onPressed: () => setState(() => _panel = 'quiz'),
                    child: const Text('Open full class entry')))
          else
            _modeNotice(
                icon: Icons.touch_app_outlined,
                title: 'Teaching view',
                detail:
                    'Select a student for private notes, homework status, or follow-up.'),
          const SizedBox(height: 12),
          Center(
              child: Container(
                  width: 230,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  decoration: BoxDecoration(
                      color: const Color(0xffe6efec),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xffd4e3df))),
                  child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.present_to_all_rounded,
                            size: 14, color: Color(0xff60758c)),
                        SizedBox(width: 8),
                        Text('FRONT OF CLASSROOM',
                            style: TextStyle(
                                fontSize: 9.5,
                                letterSpacing: 1.7,
                                fontWeight: FontWeight.w800,
                                color: _muted)),
                      ]))),
          const SizedBox(height: 12),
          TeachingPreviewRoom(
            key: ValueKey('room-$_roomRevision'),
            tableColumns: _tableColumns,
            allSideSeats: _customRoom,
            studentNumbers: _numbers,
            spotlightStudent: _spotlightStudent,
            spotlightTable: _spotlightTable,
            choosing: _choosing,
            students: _students,
            seats: _seats,
            homework: _homework,
            quizMarks: _quizzing
                ? {
                    for (final id in _students.keys)
                      id: _quiz.mark(id) == null
                          ? 'Not entered'
                          : '${_quiz.mark(id)} / ${_quiz.maximumLabel}'
                  }
                : null,
            attendance: _attendance,
            groups: _groups,
            checking: _checking,
            attendanceMode: _attendanceMode,
            groupMode: _groupMode,
            selectedStudent: _panel == 'student' || _panel == 'quiz-student'
                ? _student
                : null,
            onStudent: _openStudent,
            onDone: (id) => setState(() {
              _homework[id] = 'Done';
              _log('${_students[id]} · homework done');
            }),
            onPresent: (id) => _setAttendance(id, 'Present'),
            onMove: (from, to) => setState(() {
              final displaced = _seats[to];
              _seats[to] = _seats[from];
              _seats[from] = displaced;
              _lastSeatSwap = [from, to];
              _log('Moved seat assignment');
            }),
          ),
          const SizedBox(height: 20),
          const Text(
              'Teacher workspace · Private notes stay here. This is not a projected classroom display.',
              style: TextStyle(fontSize: 11.5, color: _muted)),
        ]),
      );

  Widget _modeNotice({
    required IconData icon,
    required String title,
    required String detail,
    Widget? action,
  }) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
            color: _surfaceSoft,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _line)),
        child: Row(children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
                color: widget.darkMode
                    ? const Color(0xff14394a)
                    : const Color(0xffe4f1f2),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: const Color(0xff176a74), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: TextStyle(
                        color: _primaryText,
                        fontWeight: FontWeight.w800,
                        fontSize: 14)),
                const SizedBox(height: 2),
                Text(detail,
                    style: TextStyle(
                        color: _secondaryText, fontSize: 11.5, height: 1.35)),
              ])),
          if (action != null) ...[
            const SizedBox(width: 10),
            action,
          ],
        ]),
      );

  Widget _panelBody() => Material(
        color: _surface,
        elevation: 8,
        shadowColor: const Color(0x26163f65),
        child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(26, 24, 26, 32),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                    child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                      color: widget.darkMode
                          ? const Color(0xff13283b)
                          : const Color(0xffedf4fa),
                      borderRadius: BorderRadius.circular(999)),
                  child: Text(
                    _panel == 'student'
                        ? 'STUDENT / PRIVATE'
                        : _panel == 'tools'
                            ? 'CLASSROOM TOOLS'
                            : 'IN THIS LESSON',
                    style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.45,
                        fontWeight: FontWeight.w900,
                        color: _secondaryText),
                  ),
                )),
                const SizedBox(width: 10),
                IconButton(
                    tooltip: 'Close panel',
                    style: IconButton.styleFrom(
                        backgroundColor: _surfaceSoft),
                    onPressed: () => setState(() => _panel = null),
                    icon: const Icon(Icons.close_rounded))
              ]),
              const SizedBox(height: 18),
              if (_panel == 'student') ..._studentPanel(),
              if (_panel == 'tools') ..._toolsPanel(),
              if (_panel == 'quiz' || _panel == 'quiz-student') ...[
                if (_panel == 'quiz-student')
                  TextButton(
                      onPressed: () => setState(() => _panel = 'quiz'),
                      child: const Text('All students')),
                PreviewQuizPanel(
                  key: ValueKey(
                      _panel == 'quiz' ? 'quiz-roster' : 'quiz-$_student'),
                  book: _quiz,
                  students: _panel == 'quiz'
                      ? _students
                      : {_student!: _students[_student]!},
                ),
              ],
              if (_panel == 'timer') ..._timerPanel(),
              if (_panel == 'lesson') ...[
                const Text('Food webs',
                    style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -.7)),
                const SizedBox(height: 18),
                const Text('What changes when one species disappears?',
                    style: TextStyle(
                        fontSize: 19,
                        height: 1.45,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 18),
                const Text(
                    '1. Recall a food chain.\n\n2. Connect several chains into a web.\n\n3. Remove one species and discuss the effects.',
                    style: TextStyle(height: 1.6)),
                const SizedBox(height: 24),
                const Text('Example lesson focus for this fictional class.',
                    style: TextStyle(color: _muted)),
              ],
              if (_panel == 'finish') ..._finishPanel(),
            ])),
      );

  List<Widget> _toolsPanel() => [
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: ['Today', 'Students', 'Class', 'Setup']
              .map((section) => ChoiceChip(
                    label: Text(section),
                    selected: _toolsSection == section,
                    onSelected: (_) =>
                        setState(() => _toolsSection = section),
                  ))
              .toList(),
        ),
        const SizedBox(height: 20),
        if (_toolsSection == 'Today') ...[
          _toolAction(
              icon: Icons.timer_outlined,
              title: 'Timer',
              subtitle: _timerEnd == null
                  ? 'Open the classroom timer'
                  : 'Running · $_clock',
              onTap: () => _showPanel('timer')),
          const SizedBox(height: 9),
          _toolAction(
              icon: Icons.assignment_outlined,
              title: 'Homework check',
              subtitle: 'Mark the normal case quickly at each seat',
              onTap: () => setState(() {
                    _checking = true;
                    _quizzing = false;
                    _attendanceMode = false;
                    _panel = null;
                  })),
          const SizedBox(height: 9),
          _toolAction(
              icon: Icons.edit_note_rounded,
              title: 'Quiz scores',
              subtitle: 'Open class score entry',
              onTap: _startQuiz),
          const SizedBox(height: 9),
          _toolAction(
              icon: Icons.menu_book_outlined,
              title: 'Lesson focus',
              subtitle: 'Keep the lesson thread beside the room',
              onTap: () => _showPanel('lesson')),
        ],
        if (_toolsSection == 'Students') ...[
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Attendance mode',
                style: TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text(
                '$_presentCount of 12 marked present · tap Present under a seat',
                style: const TextStyle(fontSize: 11.5)),
            value: _attendanceMode,
            onChanged: (value) => setState(() {
              _attendanceMode = value;
              if (value) {
                _checking = false;
                _quizzing = false;
                _groupMode = false;
                _panel = null;
              }
            }),
          ),
          const SizedBox(height: 8),
          _toolAction(
              icon: Icons.person_search_outlined,
              title: 'Pick student',
              subtitle: 'Animated random student chooser',
              onTap: () {
                setState(() {
                  _toolsDrawerOpen = false;
                  _panel = null;
                });
                _pick(false);
              }),
          const SizedBox(height: 9),
          _toolAction(
              icon: Icons.how_to_reg_rounded,
              title: 'School attendance',
              subtitle: _schoolAttendanceUrl.isEmpty
                  ? 'Not connected in this preview build'
                  : 'Open the school attendance system',
              onTap: _schoolAttendanceUrl.isEmpty ? null : _openAttendance),
          const SizedBox(height: 14),
          const Text(
              'Participation, classwork and behaviour are available in each student card.',
              style: TextStyle(color: _muted, fontSize: 11.5, height: 1.45)),
        ],
        if (_toolsSection == 'Class') ...[
          _toolAction(
              icon: Icons.groups_2_outlined,
              title: 'Make 3 quick groups',
              subtitle: 'Randomly group the students currently seated',
              onTap: () {
                _makeGroups();
                setState(() => _panel = null);
              }),
          const SizedBox(height: 9),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Show group labels',
                style: TextStyle(fontWeight: FontWeight.w800)),
            subtitle: const Text('Display the current group at each seat',
                style: TextStyle(fontSize: 11.5)),
            value: _groupMode,
            onChanged: _groups.isEmpty
                ? null
                : (value) => setState(() => _groupMode = value),
          ),
          const SizedBox(height: 8),
          _toolAction(
              icon: Icons.groups_outlined,
              title: 'Pick table',
              subtitle: 'Animated random table chooser',
              onTap: () {
                setState(() {
                  _toolsDrawerOpen = false;
                  _panel = null;
                });
                _pick(true);
              }),
          const SizedBox(height: 18),
          const Text('Class note',
              style: TextStyle(
                  color: Color(0xff173457),
                  fontWeight: FontWeight.w900,
                  fontSize: 14)),
          const SizedBox(height: 8),
          TextField(
            controller: _classNote,
            maxLines: 3,
            decoration: InputDecoration(
                hintText: 'Something worth remembering about the class…',
                filled: true,
                fillColor: _surfaceSoft,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14))),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: () {
                final text = _classNote.text.trim();
                if (text.isEmpty) return;
                setState(() {
                  _log('Class note · $text');
                  _classNote.clear();
                });
              },
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add to lesson log'),
            ),
          ),
          const SizedBox(height: 18),
          const Text('Lesson log',
              style: TextStyle(
                  color: Color(0xff173457),
                  fontWeight: FontWeight.w900,
                  fontSize: 14)),
          const SizedBox(height: 8),
          if (_lessonLog.isEmpty)
            const Text('No lesson events recorded yet.',
                style: TextStyle(color: _muted, fontSize: 11.5))
          else
            for (final entry in _lessonLog.take(8))
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Text(entry,
                    style: const TextStyle(
                        color: _muted, fontSize: 11.5, height: 1.35)),
              ),
        ],
        if (_toolsSection == 'Setup') ...[
          _toolAction(
              icon: Icons.dashboard_customize_outlined,
              title: 'Room setup',
              subtitle: 'Change table count and room layout',
              onTap: _buildRoom),
          const SizedBox(height: 9),
          _toolAction(
              icon: Icons.present_to_all_rounded,
              title: 'Presentation mode',
              subtitle: 'Clean projector-safe classroom view',
              onTap: () => setState(() {
                    _toolsDrawerOpen = false;
                    _panel = null;
                    _presentationMode = true;
                  })),
          const SizedBox(height: 9),
          _toolAction(
              icon: Icons.undo_rounded,
              title: 'Undo last seat move',
              subtitle: _lastSeatSwap == null
                  ? 'No seat move to undo'
                  : 'Restore the previous seating swap',
              onTap: _lastSeatSwap == null ? null : _undoSeatSwap),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: const Color(0xfff6f9fc),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xffe0e9f0))),
            child: Row(children: [
              const Icon(Icons.event_seat_outlined,
                  color: Color(0xff60758c), size: 20),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(
                      _unseatedStudents.isEmpty
                          ? 'All 12 students are seated'
                          : '${_unseatedStudents.length} students are unseated',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 12.5))),
            ]),
          ),
          const SizedBox(height: 10),
          const Text(
              'Seat editing stays locked during teaching. Use Arrange seats above the map only when you need it.',
              style: TextStyle(color: _muted, fontSize: 11.5, height: 1.45)),
        ],
      ];

  Widget _toolAction({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
  }) =>
      Material(
        color: _surfaceSoft,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _line)),
            child: Row(children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                    color: widget.darkMode
                        ? const Color(0xff15364a)
                        : const Color(0xffe8f2f8),
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(icon,
                    color: onTap == null
                        ? const Color(0xffa7b5c1)
                        : const Color(0xff176a74),
                    size: 19),
              ),
              const SizedBox(width: 11),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(title,
                        style: TextStyle(
                            color: onTap == null
                                ? const Color(0xff8797a6)
                                : _primaryText,
                            fontWeight: FontWeight.w800,
                            fontSize: 12.5)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(
                            color: _secondaryText, fontSize: 10.5, height: 1.3)),
                  ])),
              const Icon(Icons.chevron_right_rounded,
                  color: Color(0xff8da0b1), size: 18),
            ]),
          ),
        ),
      );

  List<Widget> _studentPanel() => [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xff1769ce), Color(0xff158d8a)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(17)),
            child: Center(
                child: Text(_numbers[_student]!,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900))),
          ),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(_students[_student]!,
                    style: const TextStyle(
                        fontSize: 30,
                        height: 1,
                        letterSpacing: -.7,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 7),
                Text('J2 Science · Room 204',
                    style: TextStyle(
                        color: _secondaryText,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600)),
              ])),
        ]),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: _surfaceSoft,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _line)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Quick classroom actions',
                style: TextStyle(
                    color: _primaryText,
                    fontWeight: FontWeight.w800,
                    fontSize: 13)),
            const SizedBox(height: 10),
            _metricRow('Participation', _participation, _student!,
                Icons.record_voice_over_outlined),
            const SizedBox(height: 8),
            _metricRow('Classwork', _classwork, _student!,
                Icons.task_alt_rounded),
            const SizedBox(height: 8),
            _metricRow(
                'Behaviour', _behaviour, _student!, Icons.balance_rounded),
          ]),
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: _surfaceSoft,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _line)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.how_to_reg_rounded,
                  size: 18, color: Color(0xff176a74)),
              const SizedBox(width: 8),
              Text('Attendance',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: _primaryText)),
            ]),
            const SizedBox(height: 10),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: ['Present', 'Late', 'Absent']
                  .map((status) => ChoiceChip(
                        label: Text(status),
                        selected:
                            (_attendance[_student] ?? 'Present') == status,
                        onSelected: (_) => _setAttendance(_student!, status),
                      ))
                  .toList(),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: _surfaceSoft,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _line)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.assignment_outlined,
                  size: 18, color: Color(0xff176a74)),
              const SizedBox(width: 8),
              Text('Food web worksheet',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: _primaryText)),
            ]),
            const SizedBox(height: 12),
            Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ['Done', 'Missing', 'Absent', 'Unchecked']
                    .map((status) => ChoiceChip(
                          label: Text(status),
                          selected:
                              (_homework[_student] ?? 'Unchecked') == status,
                          onSelected: (_) =>
                              setState(() => _homework[_student!] = status),
                        ))
                    .toList()),
            const SizedBox(height: 9),
            Text('Preview check only. Does not change a grade.',
                style: TextStyle(color: _secondaryText, fontSize: 11.5)),
          ]),
        ),
        const SizedBox(height: 16),
        TextField(
            controller: _note,
            maxLines: 5,
            decoration: InputDecoration(
                labelText: 'Private note',
                hintText: 'Something to remember next time…',
                filled: true,
                fillColor: _surfaceSoft,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16))),
            onChanged: (text) => setState(() => _notes[_student!] = text)),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
              color: _surfaceSoft,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _line)),
          child: CheckboxListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              title: const Text('Follow up with this student',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('Bring this student back to your attention.',
                  style: TextStyle(fontSize: 11.5)),
              value: _followUps.contains(_student),
              onChanged: (value) => setState(() {
                    if (value == true) {
                      _followUps.add(_student!);
                    } else {
                      _followUps.remove(_student);
                    }
                  })),
        ),
        const SizedBox(height: 14),
        Text(
            'Notes stay while you explore this preview. Refreshing clears them.',
            style: TextStyle(color: _secondaryText, fontSize: 11.5, height: 1.5)),
      ];

  Widget _metricRow(
    String label,
    Map<String, int> metric,
    String studentId,
    IconData icon,
  ) =>
      Row(children: [
        Icon(icon, size: 17, color: _secondaryText),
        const SizedBox(width: 8),
        Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w700))),
        IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Decrease $label',
            onPressed: () => _adjustMetric(metric, studentId, -1, label),
            icon: const Icon(Icons.remove_circle_outline_rounded, size: 20)),
        Container(
          width: 34,
          alignment: Alignment.center,
          child: Text('${metric[studentId] ?? 0}',
              style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: _primaryText)),
        ),
        IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Increase $label',
            onPressed: () => _adjustMetric(metric, studentId, 1, label),
            icon: const Icon(Icons.add_circle_outline_rounded, size: 20)),
      ]);

  List<Widget> _timerPanel() => [
        const Text('A moment to think',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600)),
        const SizedBox(height: 28),
        Text(_clock,
            style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w300)),
        const SizedBox(height: 20),
        Wrap(
            spacing: 8,
            children: [1, 3, 5]
                .map((minutes) => OutlinedButton(
                    onPressed: () => setState(() {
                          _timerEnd = null;
                          _seconds = minutes * 60;
                          _timerDuration = _seconds;
                        }),
                    child: Text('$minutes min')))
                .toList()),
        const SizedBox(height: 16),
        FilledButton(
            onPressed: _seconds == 0 ? null : _toggleTimer,
            child: Text(_timerEnd == null ? 'Start timer' : 'Pause timer')),
        const SizedBox(height: 24),
        OutlinedButton.icon(
            onPressed: () => setState(() => _timerExpanded = true),
            icon: const Icon(Icons.fullscreen),
            label: const Text('Fullscreen timer')),
        const Text(
            'Close this panel and keep teaching. The timer keeps running.',
            style: TextStyle(color: _muted, height: 1.5)),
      ];

  List<Widget> _finishPanel() => [
        const Text('Leave a thread for next time.',
            style: TextStyle(
                fontSize: 28, height: 1.2, fontWeight: FontWeight.w600)),
        const SizedBox(height: 24),
        Text(
            '${_quiz.selected.name}: ${_quiz.entered(_students.keys)} of 12 marks\n$_checked of 12 homework checks\n${_notes.values.where((n) => n.trim().isNotEmpty).length} private notes\n${_followUps.length} student follow-ups',
            style: const TextStyle(fontSize: 16, height: 2)),
        const SizedBox(height: 22),
        TextField(
            controller: _continuation,
            maxLines: 4,
            decoration: const InputDecoration(
                labelText: 'Next lesson, pick up with…',
                border: OutlineInputBorder())),
        const SizedBox(height: 18),
        const Text(
            'This demo summary stays until you refresh. It is not saved to your school account.',
            style: TextStyle(color: _muted, height: 1.5)),
        const SizedBox(height: 24),
        FilledButton(
            onPressed: () => setState(() {
                  _cancelChooser();
                  _finished = true;
                  _teaching = false;
                  _panel = null;
                  _timerEnd = null;
                }),
            child: const Text('Finish demo lesson')),
        const SizedBox(height: 12),
        TextButton(
            onPressed: () => setState(() => _panel = null),
            child: const Text('Keep teaching')),
      ];

  Widget _timerFocus() => SizedBox.expand(
        child: DecoratedBox(
          decoration: const BoxDecoration(
              gradient: RadialGradient(
                  center: Alignment(0, -.08),
                  colors: [Color(0xff245a55), Color(0xff102725)],
                  radius: 1.15)),
          child: SafeArea(
            child: LayoutBuilder(builder: (context, size) {
              final diameter =
                  min(430.0, min(size.maxWidth - 72, size.maxHeight * .52));
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                child: SizedBox(
                  width: size.maxWidth,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: size.maxHeight - 48),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: .08),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: .12))),
                          child: const Text('PROJECTOR TIMER',
                              style: TextStyle(
                                  color: Color(0xffc5e1d7),
                                  fontSize: 10,
                                  letterSpacing: 2.2,
                                  fontWeight: FontWeight.w800)),
                        ),
                        const SizedBox(height: 18),
                        const Text('A MOMENT TO THINK',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                letterSpacing: 3.2,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 18),
                        const TeachingPreviewClock(
                            color: Color(0xffc0d8ca)),
                        const SizedBox(height: 22),
                        SizedBox(
                          width: diameter,
                          height: diameter,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Positioned.fill(
                                child: CircularProgressIndicator(
                                  value: _timerDuration == 0
                                      ? 0
                                      : _seconds / _timerDuration,
                                  strokeWidth: diameter < 320 ? 7 : 9,
                                  strokeCap: StrokeCap.round,
                                  backgroundColor: Colors.white12,
                                  color: const Color(0xffb9d4a4),
                                ),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(_clock,
                                      style: TextStyle(
                                          fontSize:
                                              diameter < 320 ? 56 : 78,
                                          height: 1,
                                          fontWeight: FontWeight.w300,
                                          letterSpacing: -2,
                                          color: Colors.white)),
                                  const SizedBox(height: 12),
                                  Text(
                                    _seconds == 0
                                        ? 'Time to come back together'
                                        : _timerEnd == null
                                            ? 'Ready when you are'
                                            : 'Space to focus',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        color: Color(0xffc0d8ca),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          alignment: WrapAlignment.center,
                          children: [
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xff1d73d2),
                                  foregroundColor: Colors.white),
                              onPressed:
                                  _seconds == 0 ? null : _toggleTimer,
                              icon: Icon(_timerEnd == null
                                  ? Icons.play_arrow_rounded
                                  : Icons.pause_rounded),
                              label: Text(_timerEnd == null
                                  ? 'Start timer'
                                  : 'Pause timer'),
                            ),
                            FilledButton.tonal(
                              onPressed: () => setState(() {
                                _timerEnd = null;
                                _seconds = _timerDuration;
                              }),
                              child: const Text('Reset timer'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                              foregroundColor: Colors.white),
                          onPressed: () =>
                              setState(() => _timerExpanded = false),
                          icon: const Icon(Icons.fullscreen_exit_rounded),
                          label: Text(_presentationMode
                              ? 'Return to presentation'
                              : 'Return to classroom'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      );

}

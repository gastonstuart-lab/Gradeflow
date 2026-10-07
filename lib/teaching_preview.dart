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
class TeachingPreview extends StatelessWidget {
  const TeachingPreview({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'InstructOS · Teaching preview',
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: _paper,
          colorScheme: ColorScheme.fromSeed(seedColor: _green),
          textTheme: ThemeData.light().textTheme.apply(
                bodyColor: _ink,
                displayColor: _ink,
              ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              backgroundColor: _green,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            ),
          ),
        ),
        home: const TeachingJourney(),
      );
}

class TeachingJourney extends StatefulWidget {
  const TeachingJourney({super.key});

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
  final _note = TextEditingController();
  final _continuation = TextEditingController();
  bool _teaching = false;
  bool _started = false;
  bool _finished = false;
  bool _checking = false;
  bool _quizzing = false;
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
    _continuation.dispose();
    super.dispose();
  }

  String get _clock =>
      '${(_seconds ~/ 60).toString().padLeft(2, '0')}:${(_seconds % 60).toString().padLeft(2, '0')}';
  int get _checked => _homework.values.where((v) => v != 'Unchecked').length;

  void _openStudent(String id) {
    setState(() {
      _student = id;
      _note.text = _notes[id] ?? '';
      _panel = _quizzing ? 'quiz-student' : 'student';
    });
  }

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

  Widget _label(String text) => Text(text,
      style: const TextStyle(
          fontSize: 12,
          letterSpacing: 1.6,
          fontWeight: FontWeight.w700,
          color: _muted));

  @override
  Widget build(BuildContext context) => Scaffold(
        bottomNavigationBar: _timerExpanded ? null : _dock(),
        body: _timerExpanded
            ? _timerFocus()
            : SafeArea(
                child: Column(children: [
                  Container(
                    width: double.infinity,
                    color: const Color(0xffe4eef8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 7),
                    child: const Text(
                        'INTERACTIVE PREVIEW  ·  Fictional class · Changes last until you refresh',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 10.5,
                            letterSpacing: .25,
                            fontWeight: FontWeight.w600,
                            color: _muted)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 26, vertical: 12),
                    decoration: const BoxDecoration(
                      color: Color(0xfffbfdff),
                      boxShadow: [
                        BoxShadow(
                            color: Color(0x0b123a62),
                            blurRadius: 18,
                            offset: Offset(0, 4))
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
                      const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('InstructOS',
                                style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -.35,
                                    fontSize: 20,
                                    color: Color(0xff123a62))),
                            Text('Teacher workspace',
                                style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: _muted)),
                          ]),
                      const Spacer(),
                      if (MediaQuery.sizeOf(context).width >= 720)
                        Container(
                          margin: const EdgeInsets.only(right: 14),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                              color: _teaching
                                  ? const Color(0xffe2f4f1)
                                  : const Color(0xffeaf3ff),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                  color: _teaching
                                      ? const Color(0xffbfe4dd)
                                      : const Color(0xffcfe1f4))),
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
                      const SizedBox(width: 10),
                      TeachingPreviewClock(
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
    if (tool == 'timer') setState(() => _panel = 'timer');
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
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xffd9e5f1)),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0x181b416a),
                          blurRadius: 24,
                          offset: Offset(0, 6))
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
                              backgroundColor:
                                  !_teaching ? const Color(0xffe9f2ff) : null),
                          onPressed: _leaveToToday,
                          icon: const Icon(Icons.home_outlined, size: 20),
                          label: const Text('Home')),
                      TextButton.icon(
                          style: TextButton.styleFrom(
                              backgroundColor:
                                  _teaching ? const Color(0xffe9f2ff) : null),
                          onPressed: () => _openTool('class'),
                          icon: const Icon(Icons.groups_outlined, size: 20),
                          label: const Text('Classroom')),
                    ]),
              ))));

  Widget _today() => TeachingPreviewDesktop(
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
        padding: const EdgeInsets.all(34),
        decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [
              Color(0xff103553),
              Color(0xff1a5875),
              Color(0xff148b88)
            ], begin: Alignment.topLeft, end: Alignment.bottomRight),
            image: const DecorationImage(
                image: AssetImage('assets/images/dashboard_world.jpg'),
                fit: BoxFit.cover,
                alignment: Alignment.centerRight,
                opacity: .13),
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x35234b74),
                  blurRadius: 34,
                  offset: Offset(0, 14))
            ],
            border: Border.all(color: const Color(0xff3a8093))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: _heroLabel(_finished
                  ? 'LESSON WRAPPED UP'
                  : _started
                      ? 'YOUR CLASS IS STILL HERE'
                      : 'UP NEXT · 10:10–11:00'),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
          Text(_finished ? 'Ready for next time' : 'Pick up where you left off',
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
                        color: Colors.white.withValues(alpha: .42)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 16)),
                onPressed: _startQuiz,
                icon: const Icon(Icons.edit_note),
                label: const Text('Enter quiz scores')),
          ]),
          if (_finished) ...[
            const SizedBox(height: 16),
            const Text('Lesson summary kept in this preview session only.',
                style: TextStyle(color: Color(0xffd6e6ef), fontSize: 12)),
          ],
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

  Widget _classroom() => LayoutBuilder(builder: (context, size) {
        final wide = size.maxWidth >= 1000;
        return Stack(children: [
          Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: _map()),
            if (wide && _panel != null)
              SizedBox(width: 360, child: _panelBody()),
          ]),
          if (!wide && _panel != null) ...[
            Positioned.fill(
                child: GestureDetector(
                    onTap: () => setState(() => _panel = null),
                    child: Container(color: Colors.black26))),
            Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                    width: size.maxWidth < 420 ? size.maxWidth : 380,
                    height: double.infinity,
                    child: _panelBody())),
          ],
        ]);
      });

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
                  onPressed: () => setState(() => _panel = 'finish'),
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                  label: const Text('Finish class')),
            ]),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .92),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xffdbe7f0)),
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
                  onPressed: () => setState(() => _panel = 'timer')),
              ActionChip(
                  label: const Text('Lesson focus'),
                  avatar: const Icon(Icons.menu_book_outlined, size: 18),
                  onPressed: () => setState(() => _panel = 'lesson')),
            ]),
          ),
          const SizedBox(height: 16),
          if (_choiceResult != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Semantics(
                  liveRegion: !_choosing,
                  child: Text(_choiceResult!,
                      key: const ValueKey('chooser-result'),
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Color(0xff95691f)))),
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
          const SizedBox(height: 18),
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
          const SizedBox(height: 18),
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
            checking: _checking,
            selectedStudent: _panel == 'student' || _panel == 'quiz-student'
                ? _student
                : null,
            onStudent: _openStudent,
            onDone: (id) => setState(() => _homework[id] = 'Done'),
            onMove: (from, to) => setState(() {
              final displaced = _seats[to];
              _seats[to] = _seats[from];
              _seats[from] = displaced;
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
            color: const Color(0xfff7fbfd),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xffdbe8ef))),
        child: Row(children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
                color: const Color(0xffe4f1f2),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: const Color(0xff176a74), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: const TextStyle(
                        color: Color(0xff173457),
                        fontWeight: FontWeight.w800,
                        fontSize: 14)),
                const SizedBox(height: 2),
                Text(detail,
                    style: const TextStyle(
                        color: _muted, fontSize: 11.5, height: 1.35)),
              ])),
          if (action != null) ...[
            const SizedBox(width: 10),
            action,
          ],
        ]),
      );

  Widget _panelBody() => Material(
        color: const Color(0xfffbfdff),
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
                      color: const Color(0xffedf4fa),
                      borderRadius: BorderRadius.circular(999)),
                  child: Text(
                    _panel == 'student'
                        ? 'STUDENT / PRIVATE'
                        : 'IN THIS LESSON',
                    style: const TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.45,
                        fontWeight: FontWeight.w900,
                        color: Color(0xff60758c)),
                  ),
                )),
                const SizedBox(width: 10),
                IconButton(
                    tooltip: 'Close panel',
                    style: IconButton.styleFrom(
                        backgroundColor: const Color(0xfff1f5f8)),
                    onPressed: () => setState(() => _panel = null),
                    icon: const Icon(Icons.close_rounded))
              ]),
              const SizedBox(height: 18),
              if (_panel == 'student') ..._studentPanel(),
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
                const Text('J2 Science · Room 204',
                    style: TextStyle(
                        color: _muted,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600)),
              ])),
        ]),
        const SizedBox(height: 26),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xffdce7ef))),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Icon(Icons.assignment_outlined,
                  size: 18, color: Color(0xff176a74)),
              SizedBox(width: 8),
              Text('Food web worksheet',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xff173457))),
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
            const Text('Preview check only. Does not change a grade.',
                style: TextStyle(color: _muted, fontSize: 11.5)),
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
                fillColor: Colors.white,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16))),
            onChanged: (text) => setState(() => _notes[_student!] = text)),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
              color: const Color(0xfff6f9fc),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xffe0e9f0))),
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
        const Text(
            'Notes stay while you explore this preview. Refreshing clears them.',
            style: TextStyle(color: _muted, fontSize: 11.5, height: 1.5)),
      ];

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

  Widget _timerFocus() => Container(
        decoration: const BoxDecoration(
            gradient: RadialGradient(
                colors: [Color(0xff244c48), Color(0xff102725)], radius: 1.1)),
        child: SafeArea(
            child: LayoutBuilder(
                builder: (context, size) => SingleChildScrollView(
                      child: ConstrainedBox(
                          constraints:
                              BoxConstraints(minHeight: size.maxHeight),
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text('A MOMENT TO THINK',
                                      style: TextStyle(
                                          color: Color(0xffc0d8ca),
                                          letterSpacing: 3)),
                                  const SizedBox(height: 32),
                                  const TeachingPreviewClock(
                                      color: Color(0xffc0d8ca)),
                                  const SizedBox(height: 20),
                                  SizedBox(
                                      width: min(340, size.maxWidth - 48),
                                      height: min(340, size.maxWidth - 48),
                                      child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            Positioned.fill(
                                                child:
                                                    CircularProgressIndicator(
                                                        value: _seconds /
                                                            _timerDuration,
                                                        strokeWidth: 8,
                                                        strokeCap:
                                                            StrokeCap.round,
                                                        backgroundColor:
                                                            Colors.white12,
                                                        color: const Color(
                                                            0xffb9d4a4))),
                                            Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(_clock,
                                                      style: const TextStyle(
                                                          fontSize: 68,
                                                          fontWeight:
                                                              FontWeight.w300,
                                                          color: Colors.white)),
                                                  Text(
                                                      _seconds == 0
                                                          ? 'Time to come back together'
                                                          : _timerEnd == null
                                                              ? 'Ready when you are'
                                                              : 'Space to focus',
                                                      style: const TextStyle(
                                                          color: Color(
                                                              0xffc0d8ca))),
                                                ]),
                                          ])),
                                  const SizedBox(height: 32),
                                  Wrap(
                                      spacing: 12,
                                      runSpacing: 12,
                                      alignment: WrapAlignment.center,
                                      children: [
                                        FilledButton.icon(
                                            onPressed: _seconds == 0
                                                ? null
                                                : _toggleTimer,
                                            icon: Icon(_timerEnd == null
                                                ? Icons.play_arrow
                                                : Icons.pause),
                                            label: Text(_timerEnd == null
                                                ? 'Start timer'
                                                : 'Pause timer')),
                                        FilledButton.tonal(
                                            onPressed: () => setState(() {
                                                  _timerEnd = null;
                                                  _seconds = _timerDuration;
                                                }),
                                            child: const Text('Reset timer')),
                                      ]),
                                  const SizedBox(height: 20),
                                  TextButton.icon(
                                      style: TextButton.styleFrom(
                                          foregroundColor: Colors.white),
                                      onPressed: () => setState(
                                          () => _timerExpanded = false),
                                      icon: const Icon(Icons.fullscreen_exit),
                                      label: const Text('Return to classroom')),
                                ]),
                          )),
                    ))),
      );
}

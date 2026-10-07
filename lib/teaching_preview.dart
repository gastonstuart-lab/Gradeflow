import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gradeflow/components/teaching_preview_room.dart';
import 'package:gradeflow/components/teaching_preview_quiz.dart';
import 'package:url_launcher/url_launcher.dart';

void main() => runApp(const TeachingPreview());

const _ink = Color(0xff203c39);
const _muted = Color(0xff657975);
const _paper = Color(0xfff4f5ef);
const _green = Color(0xff23675c);
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
  String? _panel;
  String? _student;
  DateTime? _timerEnd;
  int _seconds = 300;
  Timer? _ticker;

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
    _ticker?.cancel();
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
        body: SafeArea(
          child: Column(children: [
            Container(
              width: double.infinity,
              color: const Color(0xffe5ebe2),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: const Text(
                  'INTERACTIVE PREVIEW  ·  Fictional class · Changes last until you refresh',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: _ink)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              child: Row(children: [
                const Icon(Icons.blur_on_rounded, color: _green, size: 30),
                const SizedBox(width: 10),
                const Expanded(
                    child: Text('InstructOS',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 21))),
                if (_teaching)
                  TextButton.icon(
                    onPressed: () => setState(() {
                      _teaching = false;
                      _panel = null;
                    }),
                    icon: const Icon(Icons.arrow_back_rounded, size: 18),
                    label: const Text('Today'),
                  )
                else if (MediaQuery.sizeOf(context).width >= 600)
                  const Text('Your teaching day',
                      style: TextStyle(color: _muted)),
              ]),
            ),
            const Divider(height: 1),
            Expanded(child: _teaching ? _classroom() : _today()),
          ]),
        ),
      );

  Widget _today() => SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Center(
            child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 34),
            _label('TODAY / DEMO TEACHING DAY'),
            const SizedBox(height: 16),
            const Text('A little less to carry.',
                style: TextStyle(
                    fontSize: 42,
                    height: 1.12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -1.4)),
            const SizedBox(height: 14),
            const Text(
                'Your class, your next step, and the things worth remembering.',
                style: TextStyle(fontSize: 17, color: _muted)),
            const SizedBox(height: 38),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: const Color(0xffdde5dc))),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label(_finished
                        ? 'LESSON WRAPPED UP'
                        : _started
                            ? 'YOUR CLASS IS STILL HERE'
                            : 'UP NEXT · 10:10–11:00'),
                    const SizedBox(height: 18),
                    const Text('J2 Science',
                        style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -1)),
                    const SizedBox(height: 8),
                    const Text('Room 204 · 12 students · Ecosystems',
                        style: TextStyle(fontSize: 16, color: _muted)),
                    const SizedBox(height: 26),
                    Text(
                        _finished
                            ? 'Ready for next time'
                            : 'Pick up where you left off',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 17)),
                    const SizedBox(height: 8),
                    Text(
                        _finished && _continuation.text.trim().isNotEmpty
                            ? _continuation.text.trim()
                            : 'Continue food webs. Ask students what happens when one species disappears.',
                        style: const TextStyle(height: 1.6, fontSize: 16)),
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
                    FilledButton.icon(
                        onPressed: _start,
                        icon: const Icon(Icons.arrow_forward_rounded),
                        label: Text(_finished
                            ? 'Reopen demo lesson'
                            : _started
                                ? 'Return to class'
                                : 'Start class')),
                    const SizedBox(height: 8),
                    TextButton.icon(
                        onPressed: _startQuiz,
                        icon: const Icon(Icons.edit_note),
                        label: const Text('Enter quiz scores')),
                    if (_finished) ...[
                      const SizedBox(height: 14),
                      const Text(
                          'Lesson summary kept in this preview session only.',
                          style: TextStyle(color: _muted, fontSize: 12)),
                    ],
                  ]),
            ),
            const SizedBox(height: 30),
            _label('LATER'),
            const SizedBox(height: 14),
            const Text('11:10  ·  Preparation time',
                style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            const Text('Nothing else needs your attention right now.',
                style: TextStyle(color: _muted)),
          ]),
        )),
      );

  Widget _signal(IconData icon, String text) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 18, color: _green),
        const SizedBox(width: 8),
        Flexible(child: Text(text, style: const TextStyle(color: _muted))),
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
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  _label('TEACHING · ROOM 204'),
                  const SizedBox(height: 8),
                  const Text('J2 Science',
                      style:
                          TextStyle(fontSize: 30, fontWeight: FontWeight.w600)),
                ])),
            OutlinedButton(
                onPressed: () => setState(() => _panel = 'finish'),
                child: const Text('Finish class')),
          ]),
          const SizedBox(height: 22),
          Wrap(spacing: 10, runSpacing: 10, children: [
            FilterChip(
                label: const Text('Homework check'),
                selected: _checking,
                avatar: const Icon(Icons.assignment_outlined, size: 18),
                onSelected: (value) => setState(() {
                      _checking = value;
                      _quizzing = false;
                      _panel = null;
                    })),
            FilterChip(
                label: const Text('Quiz scores'),
                selected: _quizzing,
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
          const SizedBox(height: 22),
          if (_checking) ...[
            const Text('Food web worksheet',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            Text(
                '$_checked of 12 checked · Tap Done at a seat. Select a student for other statuses.',
                style: const TextStyle(color: _muted, height: 1.5)),
          ] else if (_quizzing) ...[
            Text(_quiz.selected.name,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            Text(
                'Out of ${_quiz.maximumLabel} · ${_quiz.entered(_students.keys)} of 12 entered',
                style: const TextStyle(color: _muted)),
            TextButton(
                onPressed: () => setState(() => _panel = 'quiz'),
                child: const Text('Open full class entry')),
          ] else
            const Text('Your classroom. Select a student when you need them.',
                style: TextStyle(color: _muted, height: 1.5)),
          const SizedBox(height: 26),
          Center(
              child: Container(
                  width: 210,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: const Color(0xffe2e8df),
                      borderRadius: BorderRadius.circular(8)),
                  child: const Text('FRONT OF CLASSROOM',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 10, letterSpacing: 2, color: _muted)))),
          const SizedBox(height: 22),
          TeachingPreviewRoom(
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
              style: TextStyle(fontSize: 12, color: _muted)),
        ]),
      );

  Widget _panelBody() => Material(
        color: Colors.white,
        elevation: 3,
        child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                    child: _label(_panel == 'student'
                        ? 'STUDENT / PRIVATE'
                        : 'IN THIS LESSON')),
                IconButton(
                    tooltip: 'Close panel',
                    onPressed: () => setState(() => _panel = null),
                    icon: const Icon(Icons.close))
              ]),
              const SizedBox(height: 14),
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
                    style:
                        TextStyle(fontSize: 28, fontWeight: FontWeight.w600)),
                const SizedBox(height: 20),
                const Text('What changes when one species disappears?',
                    style: TextStyle(fontSize: 21, height: 1.5)),
                const SizedBox(height: 20),
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
        Text(_students[_student]!,
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        const Text('J2 Science · Same student, same classroom',
            style: TextStyle(color: _muted)),
        const SizedBox(height: 26),
        const Text('Food web worksheet',
            style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['Done', 'Missing', 'Absent', 'Unchecked']
                .map((status) => ChoiceChip(
                      label: Text(status),
                      selected: (_homework[_student] ?? 'Unchecked') == status,
                      onSelected: (_) =>
                          setState(() => _homework[_student!] = status),
                    ))
                .toList()),
        const SizedBox(height: 10),
        const Text('Preview check only. Does not change a grade.',
            style: TextStyle(color: _muted, fontSize: 12)),
        const SizedBox(height: 26),
        TextField(
            controller: _note,
            maxLines: 4,
            decoration: const InputDecoration(
                labelText: 'Private note',
                hintText: 'Something to remember next time…',
                border: OutlineInputBorder()),
            onChanged: (text) => setState(() => _notes[_student!] = text)),
        const SizedBox(height: 12),
        CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Follow up with this student'),
            value: _followUps.contains(_student),
            onChanged: (value) => setState(() {
                  if (value == true) {
                    _followUps.add(_student!);
                  } else {
                    _followUps.remove(_student);
                  }
                })),
        const SizedBox(height: 14),
        const Text(
            'Notes stay while you explore this preview. Refreshing clears them.',
            style: TextStyle(color: _muted, fontSize: 12, height: 1.5)),
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
                        }),
                    child: Text('$minutes min')))
                .toList()),
        const SizedBox(height: 16),
        FilledButton(
            onPressed: _seconds == 0
                ? null
                : () => setState(() {
                      _timerEnd = _timerEnd == null
                          ? DateTime.now().add(Duration(seconds: _seconds))
                          : null;
                    }),
            child: Text(_timerEnd == null ? 'Start timer' : 'Pause timer')),
        const SizedBox(height: 24),
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
}

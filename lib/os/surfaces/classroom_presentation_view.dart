import 'dart:async';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gradeflow/services/browser_fullscreen_stub.dart'
    if (dart.library.js_interop) 'package:gradeflow/services/browser_fullscreen_web.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gradeflow/components/seating/classroom_picker_animator.dart';
import 'package:gradeflow/components/seating/seating_designer_view.dart';
import 'package:gradeflow/services/seating_service.dart';
import 'package:gradeflow/services/student_service.dart';
import 'package:gradeflow/os/os_palette.dart';

/// Projector-friendly view: retains the real saved room without exposing
/// private notes, scores, editing controls, or student-assignment actions.
class ClassroomPresentationView extends StatefulWidget {
  const ClassroomPresentationView({
    super.key,
    required this.classId,
    required this.className,
    required this.subject,
    this.picker,
    this.cleanCanvas = false,
    this.plannerV2 = false,
  });

  final String classId;
  final String className;
  final String subject;
  final ClassroomPickerAnimator? picker;
  final bool cleanCanvas;
  final bool plannerV2;

  @override
  State<ClassroomPresentationView> createState() =>
      _ClassroomPresentationViewState();
}

class _ClassroomPresentationViewState extends State<ClassroomPresentationView> {
  late final _picker = widget.picker ?? ClassroomPickerAnimator();
  String? _highlightedStudent;
  String? _highlightedTable;
  String? _selectedLabel;

  @override
  void dispose() {
    _picker.cancel();
    super.dispose();
  }

  void _pick({bool table = false}) {
    unawaited(_runPick(table: table));
  }

  Future<void> _runPick({bool table = false}) async {
    final layout = context.read<SeatingService>().activeLayout(widget.classId);
    if (layout == null) return;
    final students = context.read<StudentService>().students;
    final eligibleTables = layout.tables
        .where((t) => layout.seats.any((s) =>
            s.tableId == t.tableId &&
            students.any((student) => student.studentId == s.studentId)))
        .toList();
    final eligibleStudents = students
        .where((s) => layout.seats.any((seat) => seat.studentId == s.studentId))
        .toList();
    final ids = table
        ? eligibleTables.map((t) => t.tableId).toList()
        : eligibleStudents.map((s) => s.studentId).toList();
    if (ids.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(table
            ? 'No occupied tables to pick.'
            : 'Seat students on the map before picking.'),
      ));
      return;
    }

    final chosen = await _picker.animate(
      candidateIds: ids,
      nonRepeatingStudents: !table,
      reduceMotion: MediaQuery.disableAnimationsOf(context),
      onHighlight: (id) {
        if (!mounted) return;
        setState(() {
          _highlightedStudent = table ? null : id;
          _highlightedTable = table ? id : null;
          _selectedLabel = 'Choosing…';
        });
      },
    );
    if (!mounted || chosen == null) return;

    setState(() {
      if (table) {
        final selected = eligibleTables.firstWhere((t) => t.tableId == chosen);
        _selectedLabel =
            selected.label.isEmpty ? 'Selected table' : selected.label;
      } else {
        final selected =
            eligibleStudents.firstWhere((s) => s.studentId == chosen);
        _selectedLabel =
            '${selected.englishFirstName} ${selected.englishLastName}'.trim();
      }
    });
  }

  void _clearSelection() {
    _picker.cancel();
    setState(() {
      _highlightedStudent = null;
      _highlightedTable = null;
      _selectedLabel = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final students = context.watch<StudentService>().students;
    return Scaffold(
      backgroundColor: OSColors.teachBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(7, 5, 7, 6),
          child: Column(
            children: [
              LayoutBuilder(
                builder: (context, width) {
                  final title = Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.className,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Colors.white)),
                      Text(widget.subject,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: OSColors.teachAccent)),
                    ],
                  );
                  final controls = Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _pick(),
                        icon: const Icon(Icons.person_search_outlined),
                        label: const Text('Pick student'),
                        style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white),
                      ),
                      const SizedBox(width: 6),
                      OutlinedButton.icon(
                        onPressed: () => _pick(table: true),
                        icon: const Icon(Icons.table_restaurant_outlined),
                        label: const Text('Pick table'),
                        style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white),
                      ),
                      const SizedBox(width: 6),
                      const ClassroomTimer(),
                      if (_selectedLabel != null) ...[
                        const SizedBox(width: 6),
                        InputChip(
                          label: Text(_selectedLabel!),
                          avatar: const Icon(Icons.auto_awesome, size: 16),
                          onDeleted: _clearSelection,
                        ),
                      ],
                    ],
                  );
                  final exit = OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_fullscreen_rounded,
                        size: 17),
                    label: const Text('Exit presentation'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.24),
                      ),
                    ),
                  );
                  if (width.maxWidth < 900) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(children: [
                          Expanded(child: title),
                          exit,
                        ]),
                        const SizedBox(height: 4),
                        SizedBox(
                          height: 42,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: controls,
                          ),
                        ),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      SizedBox(
                        width: width.maxWidth < 1150 ? 230 : 320,
                        child: title,
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: controls,
                        ),
                      ),
                      const SizedBox(width: 8),
                      exit,
                    ],
                  );
                },
              ),
              const SizedBox(height: 5),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: OSColors.teachSurface,
                    borderRadius: OSRadius.mdBr,
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.10)),
                  ),
                  child: SeatingDesignerView(
                    classId: widget.classId,
                    students: students,
                    autoLoad: false,
                    presentationMode: true,
                    premiumAppearance: true,
                    simplifiedArrange: widget.cleanCanvas,
                    plannerV2: widget.plannerV2,
                    interactive: false,
                    editRoomMode: false,
                    highlightedStudentId: _highlightedStudent,
                    highlightedTableId: _highlightedTable,
                    showToolbar: false,
                    showStudentPanel: false,
                    showFullScreenButton: false,
                    showUseHint: false,
                    webMode: kIsWeb,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// One timer state shared by the classroom toolbar and presentation route.
class ClassroomTimer extends StatefulWidget {
  const ClassroomTimer({super.key, this.fullPage = false});
  final bool fullPage;

  @override
  State<ClassroomTimer> createState() => ClassroomTimerState();
}

class _ClassroomClock extends ChangeNotifier {
  int duration = 180;
  int paused = 180;
  DateTime? deadline;
  String theme = 'Neon';
  String activity = '';
  bool sound = false;
  Timer? _expiry;
  bool _loaded = false;
  Future<void> loadPreferences() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedStyle = prefs.getString('classroom.timer.style');
      if (['Neon', 'Arcade', 'Examination', 'Ocean', 'Sunset'].contains(savedStyle)) theme = savedStyle!;
      activity = prefs.getString('classroom.timer.activity') ?? '';
      sound = prefs.getBool('classroom.timer.sound') ?? false;
      if (deadline == null && paused == duration) {
        duration = (prefs.getInt('classroom.timer.duration') ?? duration).clamp(1, 59999).toInt();
        paused = duration;
      }
      notifyListeners();
    } catch (_) { /* Timer remains usable without preferences. */ }
  }

  Future<void> _savePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('classroom.timer.style', theme);
      await prefs.setString('classroom.timer.activity', activity);
      await prefs.setBool('classroom.timer.sound', sound);
      await prefs.setInt('classroom.timer.duration', duration);
    } catch (_) { /* Timer remains usable without preferences. */ }
  }

  void _scheduleExpiry() {
    _expiry?.cancel();
    if (deadline != null) {
      _expiry = Timer(Duration(milliseconds: max(0, deadline!.difference(DateTime.now()).inMilliseconds) + 1), tick);
    }
  }
  int get remaining => deadline == null
      ? paused
      : max(0, (deadline!.difference(DateTime.now()).inMilliseconds / 1000).ceil());
  bool get running => deadline != null && remaining > 0;

  void tick() {
    if (deadline != null && remaining == 0) {
      deadline = null;
      paused = 0;
      if (sound) unawaited(SystemSound.play(SystemSoundType.alert));
      notifyListeners();
    }
  }

  void configure(int seconds) {
    duration = seconds.clamp(1, 59999).toInt();
    reset();
    unawaited(_savePreferences());
  }

  void reset() {
    deadline = null;
    paused = duration;
    _scheduleExpiry();
    notifyListeners();
  }

  void toggle() {
    tick();
    if (running) {
      paused = remaining;
      deadline = null;
    } else {
      if (paused == 0) paused = duration;
      deadline = DateTime.now().add(Duration(seconds: paused));
    }
    _scheduleExpiry();
    notifyListeners();
  }

  void adjust(int seconds) {
    tick();
    final wasRunning = running;
    final next = (remaining + seconds).clamp(0, 59999).toInt();
    paused = next;
    if (next > duration) duration = next;
    deadline = wasRunning && next > 0
        ? DateTime.now().add(Duration(seconds: next))
        : null;
    _scheduleExpiry();
    if (wasRunning && next == 0 && sound) {
      unawaited(SystemSound.play(SystemSoundType.alert));
    }
    notifyListeners();
  }

  void appearance(String style, String name, bool audible) {
    theme = style;
    activity = name;
    sound = audible;
    unawaited(_savePreferences());
    notifyListeners();
  }
}

final _classroomClock = _ClassroomClock();

class ClassroomTimerState extends State<ClassroomTimer> {
  final _clock = _classroomClock;
  Timer? _ticker;
  static const _styles = ['Neon', 'Arcade', 'Examination', 'Ocean', 'Sunset'];

  @override
  void initState() {
    super.initState();
    _clock.addListener(_refresh);
    unawaited(_clock.loadPreferences());
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      _clock.tick();
      if (_clock.running) _refresh();
    });
    _clock.tick();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _clock.removeListener(_refresh);
    super.dispose();
  }

  Future<void> _customDuration() async {
    int minutes = _clock.duration ~/ 60;
    int seconds = _clock.duration % 60;
    final form = GlobalKey<FormState>();
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set timer duration'),
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: '$minutes',
                decoration: const InputDecoration(labelText: 'Minutes'),
                keyboardType: TextInputType.number,
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  return n == null || n < 0 || n > 999 ? 'Enter 0–999' : null;
                },
                onSaved: (v) => minutes = int.parse(v!),
              ),
              TextFormField(
                initialValue: '$seconds',
                decoration: const InputDecoration(labelText: 'Seconds'),
                keyboardType: TextInputType.number,
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  return n == null || n < 0 || n > 59 ? 'Enter 0–59' : null;
                },
                onSaved: (v) => seconds = int.parse(v!),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (!form.currentState!.validate()) return;
              form.currentState!.save();
              Navigator.pop(ctx, max(1, minutes * 60 + seconds));
            },
            child: const Text('Set duration'),
          ),
        ],
      ),
    );
    if (result != null && mounted) _clock.configure(result);
  }

  void _openFullPage() {
    Navigator.of(context).push(MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => const ClassroomTimer(fullPage: true),
    ));
  }

  Future<void> _settings() async {
    String style = _clock.theme;
    String activity = _clock.activity;
    bool sound = _clock.sound;
    final apply = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Timer appearance'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: style,
                decoration: const InputDecoration(labelText: 'Style'),
                items: _styles.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (s) => update(() => style = s ?? style),
              ),
              TextFormField(
                initialValue: activity,
                decoration: const InputDecoration(labelText: 'Activity or group name'),
                maxLength: 80,
                onChanged: (v) => activity = v,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Sound at end'),
                value: sound,
                onChanged: (v) => update(() => sound = v),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Apply')),
          ],
        ),
      ),
    );
    if (apply == true && mounted) _clock.appearance(style, activity, sound);
  }

  @override
  Widget build(BuildContext context) {
    final remaining = _clock.remaining;
    final mm = (remaining ~/ 60).toString().padLeft(2, '0');
    final ss = (remaining % 60).toString().padLeft(2, '0');
    final text = '$mm:$ss';
    final running = _clock.running;
    final action = running ? 'Pause' : remaining > 0 && remaining < _clock.duration ? 'Resume' : 'Start';
    final controls = Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      children: [
        PopupMenuButton<int>(
          tooltip: 'Set timer duration',
          icon: const Icon(Icons.timer_outlined, color: Colors.white),
          onSelected: (n) {
            if (n == 0) {
              unawaited(_customDuration());
            } else {
              _clock.configure(n * 60);
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 1, child: Text('1 minute')),
            PopupMenuItem(value: 3, child: Text('3 minutes')),
            PopupMenuItem(value: 5, child: Text('5 minutes')),
            PopupMenuItem(value: 10, child: Text('10 minutes')),
            PopupMenuItem(value: 15, child: Text('15 minutes')),
            PopupMenuItem(value: 0, child: Text('Custom minutes and seconds')),
          ],
        ),
        OutlinedButton.icon(
          onPressed: _clock.toggle,
          icon: Icon(running ? Icons.pause_rounded : Icons.play_arrow_rounded),
          label: Text(widget.fullPage ? action : text),
          style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
        ),
        IconButton(
          tooltip: 'Reset timer',
          onPressed: _clock.reset,
          icon: const Icon(Icons.restart_alt_rounded, color: Colors.white),
        ),
        if (widget.fullPage) ...[
          TextButton(onPressed: () => _clock.adjust(-30),
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            child: const Text('−30 sec')),
          TextButton(onPressed: () => _clock.adjust(30),
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            child: const Text('+30 sec')),
        ] else
          IconButton(
            tooltip: 'Full-page timer',
            onPressed: _openFullPage,
            icon: const Icon(Icons.open_in_full, color: Colors.white),
          ),
      ],
    );
    if (!widget.fullPage) return controls;

    final (background, glow, accent) = switch (_clock.theme) {
      'Arcade' => (const Color(0xff080b19), const Color(0xff241443), const Color(0xff30f4a0)),
      'Examination' => (const Color(0xff141414), const Color(0xff141414), Colors.white),
      'Ocean' => (const Color(0xff061821), const Color(0xff164765), const Color(0xff54dded)),
      'Sunset' => (const Color(0xff20101c), const Color(0xff733743), const Color(0xffffb46c)),
      _ => (const Color(0xff090e1c), const Color(0xff242951), const Color(0xff9d92ff)),
    };
    final warning = remaining <= 10 ? const Color(0xffff5252)
        : remaining <= 30 ? const Color(0xffffb648) : accent;
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        foregroundColor: Colors.white,
        title: const Text('Classroom timer'),
        leading: IconButton(
          tooltip: 'Close timer',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close),
        ),
        actions: [
          IconButton(tooltip: 'Timer settings', onPressed: _settings, icon: const Icon(Icons.tune)),
          if (browserFullscreenAvailable)
            IconButton(
              tooltip: 'Toggle browser full screen',
              onPressed: () async {
                final ok = await toggleBrowserFullscreen();
                if (!ok && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Browser full screen is unavailable.')),
                  );
                }
              },
              icon: const Icon(Icons.fullscreen),
            ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(center: Alignment.topCenter, radius: 1.2, colors: [glow, background]),
        ),
        child: LayoutBuilder(
          builder: (context, bounds) {
            final diameter = max(100.0, min(bounds.maxWidth * .8, bounds.maxHeight * .66));
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: diameter,
                      height: diameter,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CircularProgressIndicator(
                            value: remaining / _clock.duration,
                            strokeWidth: max(5, diameter * .026).toDouble(),
                            strokeCap: StrokeCap.round,
                            backgroundColor: Colors.white12,
                            color: warning,
                          ),
                          Padding(
                            padding: EdgeInsets.all(diameter * .10),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Semantics(
                                    liveRegion: remaining == 0,
                                    child: Text(text, style: TextStyle(
                                      fontSize: diameter * .23,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                      fontFeatures: const [FontFeature.tabularFigures()],
                                    )),
                                  ),
                                ),
                                Text(remaining == 0 ? 'TIME IS UP' : running ? 'TIME REMAINING' : 'READY / PAUSED',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: warning, letterSpacing: 2, fontSize: max(9, diameter * .035).toDouble())),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_clock.activity.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 18),
                        child: Text(_clock.activity, textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 24)),
                      ),
                    const SizedBox(height: 16),
                    controls,
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

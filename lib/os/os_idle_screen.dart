import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gradeflow/os/os_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gradeflow/services/browser_fullscreen_stub.dart'
    if (dart.library.js_interop) 'package:gradeflow/services/browser_fullscreen_web.dart';

class ScreensaverPreferences {
  const ScreensaverPreferences({
    this.style = 'Aurora', this.clock = true, this.date = true,
    this.message = '', this.speed = 1,
  });
  static const styles = ['Aurora', 'Space', 'Ocean', 'Sunset', 'Minimal', 'Grid'];
  final String style;
  final bool clock;
  final bool date;
  final String message;
  final double speed;

  static Future<ScreensaverPreferences> load() async {
    final p = await SharedPreferences.getInstance();
    final style = p.getString('screensaver.style');
    return ScreensaverPreferences(
      style: styles.contains(style) ? style! : 'Aurora',
      clock: p.getBool('screensaver.clock') ?? true,
      date: p.getBool('screensaver.date') ?? true,
      message: p.getString('screensaver.message') ?? '',
      speed: (p.getDouble('screensaver.speed') ?? 1).clamp(.5, 2).toDouble(),
    );
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('screensaver.style', style);
    await p.setBool('screensaver.clock', clock);
    await p.setBool('screensaver.date', date);
    await p.setString('screensaver.message', message);
    await p.setDouble('screensaver.speed', speed);
  }
}

/// Settings are device-local. No student or timetable data is shown.
Future<void> showScreensaverSettings(BuildContext context) async {
  final controller = context.read<GradeFlowOSController>();
  ScreensaverPreferences initial;
  try { initial = await ScreensaverPreferences.load(); }
  catch (_) { initial = const ScreensaverPreferences(); }
  if (!context.mounted) return;
  var style = initial.style;
  var clock = initial.clock;
  var date = initial.date;
  var message = initial.message;
  var speed = initial.speed;
  var delay = controller.idleTimeoutMinutes;
  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, update) => AlertDialog(
        title: const Text('Screensaver'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: style,
                decoration: const InputDecoration(labelText: 'Theme'),
                items: ScreensaverPreferences.styles.map((s) =>
                    DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (s) => update(() => style = s ?? style),
              ),
              SwitchListTile(title: const Text('Show clock'), value: clock,
                onChanged: (v) => update(() => clock = v)),
              SwitchListTile(title: const Text('Show date'), value: date,
                onChanged: (v) => update(() => date = v)),
              TextFormField(
                initialValue: message, maxLength: 100,
                decoration: const InputDecoration(labelText: 'Projector-safe message'),
                onChanged: (v) => message = v,
              ),
              Text('Animation speed: ${speed.toStringAsFixed(1)}×'),
              Slider(value: speed, min: .5, max: 2, divisions: 6,
                onChanged: (v) => update(() => speed = v)),
              DropdownButtonFormField<int>(
                initialValue: [0, 1, 3, 5, 10, 15, 30].contains(delay) ? delay : 0,
                decoration: const InputDecoration(labelText: 'Automatic start on Home only'),
                items: [0, 1, 3, 5, 10, 15, 30].map((n) =>
                    DropdownMenuItem(value: n, child: Text(n == 0 ? 'Off' : '$n minutes'))).toList(),
                onChanged: (n) => update(() => delay = n ?? 0),
              ),
              const Padding(padding: EdgeInsets.only(top: 10), child: Text(
                'Automatic start is disabled outside Home. Preferences and messages are saved on this device.',
              )),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, 'preview'), child: const Text('Preview')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, 'save'), child: const Text('Save')),
        ],
      ),
    ),
  );
  if (result == null || !context.mounted) return;
  final preferences = ScreensaverPreferences(style: style, clock: clock, date: date,
      message: message, speed: speed);
  if (result == 'save') {
    try {
      await preferences.save();
      if (context.mounted) controller.setIdleTimeout(delay);
    } catch (_) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save screensaver settings.')));
    }
  } else {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (routeContext) => Scaffold(
        body: OSIdleScreen(preferences: preferences, onDismiss: () => Navigator.pop(routeContext)),
      ),
    ));
  }
}

class OSIdleScreen extends StatefulWidget {
  const OSIdleScreen({super.key, required this.onDismiss, this.preferences});
  final VoidCallback onDismiss;
  final ScreensaverPreferences? preferences;

  @override
  State<OSIdleScreen> createState() => _OSIdleScreenState();
}

class _OSIdleScreenState extends State<OSIdleScreen> with SingleTickerProviderStateMixin {
  late ScreensaverPreferences _preferences = widget.preferences ?? const ScreensaverPreferences();
  late final AnimationController _motion = AnimationController(vsync: this);
  Timer? _clock;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    if (widget.preferences == null) unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final p = await ScreensaverPreferences.load();
      if (!mounted) return;
      setState(() => _preferences = p);
      _configureMotion();
    } catch (_) { /* Keep safe defaults. */ }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _configureMotion();
  }

  void _configureMotion() {
    if (MediaQuery.disableAnimationsOf(context) || _preferences.style == 'Minimal') {
      _motion.stop();
    } else {
      _motion.repeat(period: Duration(milliseconds: (12000 / _preferences.speed).round()));
    }
  }

  @override
  void dispose() {
    _clock?.cancel();
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final time = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(_now), alwaysUse24HourFormat: true);
    final date = MaterialLocalizations.of(context).formatFullDate(_now);
    return Material(
      color: Colors.black,
      child: Stack(fit: StackFit.expand, children: [
        AnimatedBuilder(
          animation: _motion,
          builder: (_, child) => CustomPaint(painter: _SaverPainter(_preferences.style, _motion.value)),
        ),
        GestureDetector(
          behavior: HitTestBehavior.opaque, onTap: widget.onDismiss,
          child: SafeArea(child: Center(child: Padding(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (_preferences.clock) FittedBox(fit: BoxFit.scaleDown, child: Text(time,
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w200,
                  fontSize: math.min(160, MediaQuery.sizeOf(context).width * .24).toDouble()))),
              if (_preferences.date) Text(date, textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 24)),
              if (_preferences.message.isNotEmpty) Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Text(_preferences.message, textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 28))),
            ])),
          ))),
        ),
        SafeArea(child: Align(alignment: Alignment.topRight, child: Row(
          mainAxisSize: MainAxisSize.min, children: [
            if (browserFullscreenAvailable) IconButton(
              tooltip: 'Toggle browser full screen', color: Colors.white,
              onPressed: () async { await toggleBrowserFullscreen(); },
              icon: const Icon(Icons.fullscreen)),
            IconButton(tooltip: 'Dismiss screensaver', color: Colors.white,
              onPressed: widget.onDismiss, icon: const Icon(Icons.close)),
          ],
        ))),
        const SafeArea(child: Align(alignment: Alignment.bottomCenter,
          child: Padding(padding: EdgeInsets.all(16), child: Text('Tap anywhere to return',
            style: TextStyle(color: Colors.white70))))),
      ]),
    );
  }
}

class _SaverPainter extends CustomPainter {
  const _SaverPainter(this.style, this.phase);
  final String style;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final (base, a, b) = switch (style) {
      'Space' => (const Color(0xff050716), const Color(0xff43266a), const Color(0xff173055)),
      'Ocean' => (const Color(0xff041827), const Color(0xff087d96), const Color(0xff174579)),
      'Sunset' => (const Color(0xff210d20), const Color(0xffa54045), const Color(0xffb87127)),
      'Minimal' => (const Color(0xff10131b), const Color(0xff10131b), const Color(0xff10131b)),
      'Grid' => (const Color(0xff07121b), const Color(0xff12464e), const Color(0xff20335e)),
      _ => (const Color(0xff071323), const Color(0xff126c69), const Color(0xff43318b)),
    };
    canvas.drawRect(bounds, Paint()..color = base);
    if (style == 'Minimal') return;
    final angle = phase * math.pi * 2;
    for (var i = 0; i < 2; i++) {
      final center = Offset(size.width * (.25 + i * .5 + .10 * math.sin(angle + i * 2)),
          size.height * (.35 + i * .22 + .12 * math.cos(angle + i * 2)));
      final radius = size.longestSide * .65;
      final color = i == 0 ? a : b;
      canvas.drawCircle(center, radius, Paint()..shader = RadialGradient(
        colors: [color.withValues(alpha: .85), color.withValues(alpha: 0)],
      ).createShader(Rect.fromCircle(center: center, radius: radius)));
    }
    if (style == 'Space') {
      final random = math.Random(41);
      for (var i = 0; i < 100; i++) {
        final p = Offset(random.nextDouble() * size.width, random.nextDouble() * size.height);
        final opacity = .25 + .45 * (.5 + .5 * math.sin(angle + i));
        canvas.drawCircle(p, .7 + random.nextDouble() * 1.5,
          Paint()..color = Colors.white.withValues(alpha: opacity));
      }
    }
    if (style == 'Grid') {
      final p = Paint()..color = Colors.cyanAccent.withValues(alpha: .13)..strokeWidth = 1;
      for (double x = 0; x < size.width; x += 48) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
      }
      for (double y = 0; y < size.height; y += 48) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SaverPainter oldDelegate) =>
      oldDelegate.phase != phase || oldDelegate.style != style;
}

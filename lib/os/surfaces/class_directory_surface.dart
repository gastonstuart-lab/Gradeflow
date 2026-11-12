// ignore_for_file: prefer_interpolation_to_compose_strings
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:gradeflow/models/class.dart' as school;
import 'package:gradeflow/nav.dart';
import 'package:gradeflow/repositories/repository_factory.dart';
import 'package:gradeflow/services/auth_service.dart';
import 'package:gradeflow/services/class_directory_insights_loader.dart';
import 'package:gradeflow/services/class_service.dart';
import 'package:gradeflow/services/home_weekly_timetable_service.dart';

const _navy = Color(0xff173B63);
const _teal = Color(0xff13817C);

/// Authenticated school Classes route. All dashboard reads are non-destructive.
class ClassDirectorySurface extends StatefulWidget {
  const ClassDirectorySurface({super.key});
  @override
  State<ClassDirectorySurface> createState() => _ClassDirectorySurfaceState();
}

class _ClassDirectorySurfaceState extends State<ClassDirectorySurface> {
  ClassDirectorySnapshot? _snapshot;
  String? _requestKey;
  String? _loadedKey;
  int _generation = 0;
  bool _loading = false;

  Future<void> _reload(String teacherId, List<school.Class> classes) async {
    final ticket = ++_generation;
    setState(() => _loading = true);
    try {
      HomeWeeklyTimetable? timetable;
      try {
        timetable = await const HomeWeeklyTimetableService().loadSelected(teacherId);
      } catch (_) {
        // Missing local timetable does not justify invented class times.
      }
      final next = await ClassDirectoryInsightsLoader(
        RepositoryFactory.instance,
      ).load(classes: classes, teacherId: teacherId, timetable: timetable);
      if (!mounted || ticket != _generation) return;
      setState(() {
        _snapshot = next;
        _loadedKey = _requestKey;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || ticket != _generation) return;
      setState(() {
        _snapshot = null;
        _loadedKey = null;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final classService = context.watch<ClassService>();
    final auth = context.watch<AuthService>();
    final teacherId = auth.currentUser?.userId;
    if (teacherId == null) {
      return const Scaffold(body: Center(child: Text('Sign in to see your classes.')));
    }
    final classes = classService.classes;
    final key = teacherId + ':' + classes.map(
      (c) => c.classId + ':' + c.updatedAt.millisecondsSinceEpoch.toString(),
    ).join('|');
    if (_requestKey != key) {
      _requestKey = key;
      _snapshot = null;
      _loadedKey = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && key == _requestKey) _reload(teacherId, classes);
      });
    }
    return ClassDirectoryDashboard(
      classes: classes,
      snapshot: _loadedKey == key ? _snapshot : null,
      loading: _loading || classService.isLoading || _loadedKey != key,
      onRefresh: () => _reload(teacherId, classes),
      onHome: () => context.go(AppRoutes.osHome),
      onImport: () => context.go(AppRoutes.classes),
      onClassroom: (id) => context.go(AppRoutes.osClassroom(id)),
      onGradebook: (id) => context.go(AppRoutes.osClassGradebook(id)),
      onStudents: (id) => context.go(AppRoutes.osClassStudents(id)),
      onAddStudent: (id) => context.go('${AppRoutes.osClassStudents(id)}?add=1'),
    );
  }
}

/// Testable presentation: sample ClassDirectorySnapshot inputs require
/// neither Firebase nor any write-capable academic repository.
class ClassDirectoryDashboard extends StatefulWidget {
  const ClassDirectoryDashboard({
    super.key,
    required this.classes,
    required this.loading,
    required this.onRefresh,
    required this.onHome,
    required this.onImport,
    required this.onClassroom,
    required this.onGradebook,
    required this.onStudents,
    this.snapshot,
    this.now,
  });
  final List<school.Class> classes;
  final ClassDirectorySnapshot? snapshot;
  final bool loading;
  final DateTime? now;
  final VoidCallback onRefresh;
  final VoidCallback onHome;
  final VoidCallback onImport;
  final ValueChanged<String> onClassroom;
  final ValueChanged<String> onGradebook;
  final ValueChanged<String> onStudents;

  @override
  State<ClassDirectoryDashboard> createState() => _ClassDirectoryDashboardState();
}

class _ClassDirectoryDashboardState extends State<ClassDirectoryDashboard> {
  String _query = '';
  String _filter = 'All';
  String _sort = 'Class name';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final now = widget.now ?? DateTime.now();
    final entries = {
      for (final i in widget.snapshot?.items ?? <ClassDirectoryInsight>[])
        i.classItem.classId: i,
    };
    final classes = [...widget.classes]
      ..sort((a,b) => a.className.toLowerCase().compareTo(b.className.toLowerCase()));
    final filtered = classes.where((item) {
      final info = entries[item.classId];
      final show = _filter == 'All' ||
          (_filter == 'Needs seating'
              ? info?.needsSeating == true
              : _kind(item) == _filter);
      if (!show) return false;
      final q = _query.toLowerCase().trim();
      return q.isEmpty || item.className.toLowerCase().contains(q) ||
          item.subject.toLowerCase().contains(q) ||
          (info?.studentSearchTokens.any((name) => name.contains(q)) ?? false);
    }).toList();
    if (_sort == 'Next lesson') {
      filtered.sort((a,b) {
        final x = entries[a.classId]?.nextLesson;
        final y = entries[b.classId]?.nextLesson;
        if (x == null) return y == null ? 0 : 1;
        if (y == null) return -1;
        return x.compareTo(y);
      });
    } else if (_sort == 'Seating to finish') {
      filtered.sort((a,b) => (entries[b.classId]?.unseated ?? -1)
          .compareTo(entries[a.classId]?.unseated ?? -1));
    }
    return Scaffold(
      backgroundColor: dark ? const Color(0xff091725) : const Color(0xffF1F6FA),
      body: SafeArea(child: LayoutBuilder(builder: (context, size) {
        final double margin = size.maxWidth >= 700 ? 24 : 12;
        final bool twoColumns = size.maxWidth >= 1170;
        return CustomScrollView(
          key: const ValueKey('class-command-centre-scroll'),
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(margin, 15, margin, 12),
              sliver: SliverToBoxAdapter(child: _hero(context, now)),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(margin, 0, margin, 14),
              sliver: SliverToBoxAdapter(
                child: Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: size.maxWidth >= 700 ? 292 : size.maxWidth - margin * 2,
                      child: TextField(
                        key: const ValueKey('class-search'),
                        decoration: InputDecoration(
                          hintText: 'Search classes or students',
                          prefixIcon: const Icon(Icons.search_rounded),
                          isDense: true,
                          filled: true,
                          fillColor: scheme.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide(color: scheme.outlineVariant),
                          ),
                        ),
                        onChanged: (value) => setState(() => _query = value),
                      ),
                    ),
                    for (final kind in ['All', 'Science', 'EEP', 'Performance Arts', 'Other', 'Needs seating'])
                      if (kind == 'All' || kind == 'Needs seating' ||
                          classes.any((item) => _kind(item) == kind))
                        ChoiceChip(
                          key: ValueKey('class-filter-' + kind),
                          label: Text(kind == 'All' ? 'All (' + classes.length.toString() + ')' : kind),
                          selected: _filter == kind,
                          onSelected: (_) => setState(() => _filter = kind),
                        ),
                    PopupMenuButton<String>(
                      key: const ValueKey('class-sort'),
                      initialValue: _sort,
                      tooltip: 'Sort classes',
                      onSelected: (sort) => setState(() => _sort = sort),
                      itemBuilder: (_) => [
                        for (final label in ['Class name', 'Next lesson', 'Seating to finish'])
                          PopupMenuItem(value: label, child: Text(label)),
                      ],
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.sort_rounded, size: 18),
                          const SizedBox(width: 7),
                          Text('Sort: ' + _sort, style: const TextStyle(fontSize: 12)),
                          const Icon(Icons.arrow_drop_down_rounded),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (widget.loading)
              const SliverToBoxAdapter(child: LinearProgressIndicator(minHeight: 2)),
            if (!widget.loading && classes.isEmpty)
              const SliverFillRemaining(
                child: Center(child: Text('No classes yet. Import your classes or rosters to begin.'))),
            if (classes.isNotEmpty && filtered.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(padding: EdgeInsets.all(32),
                  child: Center(child: Text('No classes match these filters.')))),
            if (filtered.isNotEmpty)
              SliverPadding(
                padding: EdgeInsets.fromLTRB(margin, 0, margin, 125),
                sliver: SliverGrid.builder(
                  itemCount: filtered.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: twoColumns ? 2 : 1,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    mainAxisExtent: 167,
                  ),
                  itemBuilder: (_, index) {
                    final c = filtered[index];
                    return _card(context, c, entries[c.classId]);
                  },
                ),
              ),
          ],
        );
      })),
    );
  }

  Widget _hero(BuildContext context, DateTime now) {
    final snapshot = widget.snapshot;
    final classes = widget.classes;
    final semester = classes.isEmpty
        ? 'Teaching overview'
        : classes.first.schoolYear + ' ' + classes.first.term;
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_navy, Color(0xff175976), _teal]),
        borderRadius: BorderRadius.circular(26),
      ),
      padding: const EdgeInsets.fromLTRB(19, 15, 19, 17),
      child: Column(children: [
        Row(children: [
          IconButton(
            tooltip: 'Back to Home',
            onPressed: widget.onHome,
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          ),
          const Icon(Icons.school_outlined, color: Colors.white),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Your classes', style: TextStyle(
                fontSize: 25, fontWeight: FontWeight.w900, color: Colors.white)),
              Text(classes.length.toString() + ' active classes · ' + semester,
                style: const TextStyle(color: Color(0xffD7E8F4), fontSize: 12)),
            ])),
          IconButton(
            key: const ValueKey('classes-refresh'),
            tooltip: 'Refresh class information',
            onPressed: widget.onRefresh,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          ),
          OutlinedButton.icon(
            onPressed: widget.onImport,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Color(0xffBDEAE6)),
              padding: const EdgeInsets.symmetric(horizontal: 12)),
            icon: const Icon(Icons.upload_file_outlined, size: 18),
            label: const Text('Import classes / rosters',
              style: TextStyle(fontSize: 12)),
          ),
        ]),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (context, constraints) {
          final tiles = [
            _metric(Icons.groups_outlined, _num(snapshot?.totalStudents),
              'Total students'),
            _metric(Icons.event_seat_outlined,
              snapshot == null ? '—' : snapshot.classesWithSeatingToFinish.toString(),
              'Classes to seat'),
            _metric(Icons.calendar_today_outlined,
              snapshot == null || !snapshot.hasTimetable
                  ? '—' : snapshot.lessonsToday(now).toString(),
              'Lessons today'),
            _metric(Icons.fact_check_outlined, _num(snapshot?.missingScores),
              'Unentered scores'),
          ];
          return constraints.maxWidth >= 800
            ? Row(children: [
                for (var i = 0; i < tiles.length; i++) ...[
                  if (i != 0) const SizedBox(width: 9),
                  Expanded(child: tiles[i]),
                ],
              ])
            : Wrap(spacing: 8, runSpacing: 8, children: [
                for (final tile in tiles)
                  SizedBox(width: (constraints.maxWidth - 8) / 2, child: tile),
              ]);
        }),
      ]),
    );
  }

  Widget _metric(IconData icon, String number, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(14),
      color: Colors.white.withValues(alpha: .09),
      border: Border.all(color: Colors.white.withValues(alpha: .27)),
    ),
    child: Row(children: [
      Icon(icon, size: 24, color: const Color(0xffD5F6F3)),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(number, style: const TextStyle(color: Colors.white,
          fontSize: 21, fontWeight: FontWeight.w900)),
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontSize: 10.5)),
      ])),
    ]),
  );

  Widget _card(BuildContext context, school.Class item,
      ClassDirectoryInsight? info) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final kind = _kind(item);
    final accent = kind == 'Science' ? const Color(0xff1A9F8F)
        : kind == 'Performance Arts' ? const Color(0xff8D70C6)
        : const Color(0xff3281C3);
    final seating = info?.studentCount == null || info?.seatedCount == null
        ? 'Unavailable'
        : _num(info!.seatedCount) + '/' + _num(info.studentCount) + ' seated';
    final grades = info?.scoreCells == null
        ? 'Unavailable'
        : info!.scoreCells == 0 ? 'Not configured'
        : _num(info.enteredCells) + '/' + _num(info.scoreCells) + ' saved';
    final needSeats = info?.needsSeating == true;
    final note = info == null ? 'Loading saved class information'
      : needSeats ? _num(info.unseated) + ' students need seats'
      : (info.missingScores ?? 0) > 0
          ? _num(info.missingScores) + ' score cells not entered'
          : info.studentCount == null ? 'Student records unavailable'
          : info.scoreCells == 0 ? 'No assessments configured'
          : 'Class records ready';

    return Material(
      key: ValueKey('class-card-' + item.classId),
      color: scheme.surface,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: .06),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () => _details(context, item, info),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: scheme.outlineVariant
                .withValues(alpha: .65)),
          ),
          child: Row(children: [
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    width: 37, height: 37,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: .13),
                      borderRadius: BorderRadius.circular(10)),
                    child: Icon(kind == 'Science' ? Icons.science_outlined :
                        kind == 'Performance Arts' ? Icons.theater_comedy_outlined :
                        Icons.menu_book_outlined, color: accent),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.className,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w900,
                          fontSize: 15)),
                      Text(kind + ' · ' + _num(info?.studentCount) + ' students',
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11,
                          color: scheme.onSurfaceVariant)),
                    ])),
                  const Icon(Icons.chevron_right_rounded, size: 17),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _miniStat(context, Icons.event_outlined,
                      'Next lesson', _lesson(info?.nextLesson,
                          widget.snapshot?.hasTimetable == true))),
                  Expanded(child: _miniStat(context, Icons.event_seat_outlined,
                      'Seating', seating)),
                  Expanded(child: _miniStat(context, Icons.donut_small_outlined,
                      'Grading', grades)),
                ]),
                const Spacer(),
                Container(
                  height: 27,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 9),
                  decoration: BoxDecoration(
                    color: needSeats ? const Color(0xffFFF0E5)
                        : accent.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(14)),
                  child: Row(children: [
                    Icon(needSeats ? Icons.warning_amber_rounded
                        : Icons.info_outline_rounded, size: 15,
                        color: needSeats ? const Color(0xffAA4E17) : accent),
                    const SizedBox(width: 6),
                    Expanded(child: Text(note, maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10.5,
                          color: needSeats ? const Color(0xffAA4E17)
                              : theme.colorScheme.onSurface))),
                  ]),
                ),
              ],
            )),
            const SizedBox(width: 9),
            Container(
              width: 133,
              padding: const EdgeInsets.only(left: 9),
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: scheme.outlineVariant))),
              child: Column(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _action(context, 'Gradebook', Icons.grid_on_outlined,
                      () => widget.onGradebook(item.classId)),
                  _action(context, 'Classroom', Icons.meeting_room_outlined,
                      () => widget.onClassroom(item.classId), primary: true),
                  _action(context, 'Students', Icons.groups_outlined,
                      () => widget.onStudents(item.classId)),
                ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _miniStat(BuildContext context, IconData icon,
      String label, String value) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: muted, size: 15),
      const SizedBox(width: 3),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10, color: muted)),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
        ])),
    ]);
  }

  Widget _action(BuildContext context, String label,
    IconData icon, VoidCallback onTap, {bool primary = false}) {
    return SizedBox(
      width: double.infinity, height: 37,
      child: primary
        ? FilledButton.icon(
          onPressed: onTap,
          style: FilledButton.styleFrom(
            backgroundColor: _teal, foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 4)),
          icon: Icon(icon, size: 14),
          label: Text(label, style: const TextStyle(fontSize: 11)),
        )
        : OutlinedButton.icon(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 4)),
          icon: Icon(icon, size: 14),
          label: Text(label, style: const TextStyle(fontSize: 11)),
        ),
    );
  }

  void _details(BuildContext context, school.Class c, ClassDirectoryInsight? info) {
    final width = MediaQuery.sizeOf(context).width;
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close class details',
      barrierColor: Colors.black.withValues(alpha: .22),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (dialogContext, _, __) => SafeArea(child: Align(
        alignment: Alignment.centerRight,
        child: Material(
          elevation: 18,
          color: Theme.of(dialogContext).colorScheme.surface,
          borderRadius: const BorderRadius.horizontal(left: Radius.circular(24)),
          child: SizedBox(
            width: width < 440 ? width : 380,
            height: double.infinity,
            child: SingleChildScrollView(padding: const EdgeInsets.all(22),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    Expanded(child: Text(c.className,
                      style: Theme.of(dialogContext).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w900))),
                    IconButton(
                      tooltip: 'Close class details',
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      icon: const Icon(Icons.close_rounded)),
                  ]),
                  Text(_kind(c) + ' · ' + c.schoolYear + ' ' + c.term),
                  const SizedBox(height: 24),
                  _detailRow('Students', _num(info?.studentCount)),
                  _detailRow('Seated students', _num(info?.seatedCount)),
                  _detailRow('Still to seat', _num(info?.unseated)),
                  _detailRow('Unentered score cells', _num(info?.missingScores)),
                  _detailRow('Next lesson',
                      _lesson(info?.nextLesson, widget.snapshot?.hasTimetable == true)),
                  const SizedBox(height: 20),
                  FilledButton.icon(onPressed: () {
                    Navigator.of(dialogContext).pop();
                    widget.onClassroom(c.classId);
                  }, icon: const Icon(Icons.meeting_room_outlined),
                    label: const Text('Open classroom')),
                  OutlinedButton.icon(onPressed: () {
                    Navigator.of(dialogContext).pop();
                    widget.onGradebook(c.classId);
                  }, icon: const Icon(Icons.grid_on_outlined),
                    label: const Text('Open gradebook')),
                  OutlinedButton.icon(onPressed: () {
                    Navigator.of(dialogContext).pop();
                    widget.onStudents(c.classId);
                  }, icon: const Icon(Icons.groups_outlined),
                    label: const Text('View students')),
                  const SizedBox(height: 20),
                  const Text('Figures reflect saved records only. Missing scores '
                      'are not necessarily overdue assignments.',
                    style: TextStyle(fontSize: 11)),
                ]),
              )),
          ),
        ),
      ),
      transitionBuilder: (_, animation, __, child) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(.15, 0), end: Offset.zero)
            .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
        child: FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  Widget _detailRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(children: [
      Expanded(child: Text(label)),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
    ]),
  );

  static String _kind(school.Class item) {
    final value = (item.subject + ' ' + item.className).toLowerCase();
    if (value.contains('science')) return 'Science';
    if (value.contains('performance') || value.contains('arts')) {
      return 'Performance Arts';
    }
    if (value.contains('eep') || value.contains('english')) return 'EEP';
    return 'Other';
  }

  static String _num(int? number) => number?.toString() ?? '—';

  static String _lesson(DateTime? value, bool hasTimetable) {
    if (value == null) return hasTimetable ? 'Not matched' : 'No timetable';
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    return days[value.weekday - 1] + ' ' + hour.toString() + ':' +
        value.minute.toString().padLeft(2, '0') +
        (value.hour < 12 ? ' AM' : ' PM');
  }
}

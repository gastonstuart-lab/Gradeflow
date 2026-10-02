import 'package:flutter/material.dart';
import 'package:gradeflow/os/os_palette.dart';

enum ClassroomToolsSection {
  today,
  students,
  classInfo,
  setup,
}

class ClassroomToolsDrawer extends StatefulWidget {
  const ClassroomToolsDrawer({
    super.key,
    required this.studentCount,
    required this.placedSeatCount,
    required this.seatCount,
    required this.tableCount,
    required this.setupMode,
    required this.onClose,
    required this.onSetupModeChanged,
    required this.onPickStudent,
    required this.onOpenStudents,
    required this.onOpenGradebook,
    required this.onOpenSchedule,
    required this.onOpenResults,
    required this.onOpenLegacySeating,
  });

  final int studentCount;
  final int placedSeatCount;
  final int seatCount;
  final int tableCount;
  final bool setupMode;
  final VoidCallback onClose;
  final ValueChanged<bool> onSetupModeChanged;
  final VoidCallback onPickStudent;
  final VoidCallback onOpenStudents;
  final VoidCallback onOpenGradebook;
  final VoidCallback onOpenSchedule;
  final VoidCallback onOpenResults;
  final VoidCallback onOpenLegacySeating;

  @override
  State<ClassroomToolsDrawer> createState() => _ClassroomToolsDrawerState();
}

class _ClassroomToolsDrawerState extends State<ClassroomToolsDrawer> {
  ClassroomToolsSection _section = ClassroomToolsSection.today;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: OSColors.panelSurface(dark),
          borderRadius: OSRadius.lgBr,
          border: Border.all(
            color: OSColors.panelBorder(dark).withValues(alpha: 0.9),
          ),
        ),
        child: Column(
          children: [
            _DrawerHeader(onClose: widget.onClose),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: _SectionPicker(
                value: _section,
                onChanged: (value) => setState(() => _section = value),
              ),
            ),
            Divider(
              height: 1,
              color: OSColors.panelBorder(dark).withValues(alpha: 0.72),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: OSMotion.fast,
                child: _buildSection(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context) {
    switch (_section) {
      case ClassroomToolsSection.today:
        return _TodaySection(
          key: const ValueKey('today'),
          studentCount: widget.studentCount,
          placedSeatCount: widget.placedSeatCount,
          seatCount: widget.seatCount,
          tableCount: widget.tableCount,
          onPickStudent: widget.onPickStudent,
        );
      case ClassroomToolsSection.students:
        return _StudentsSection(
          key: const ValueKey('students'),
          studentCount: widget.studentCount,
          placedSeatCount: widget.placedSeatCount,
          onOpenStudents: widget.onOpenStudents,
        );
      case ClassroomToolsSection.classInfo:
        return _ClassSection(
          key: const ValueKey('class'),
          onOpenGradebook: widget.onOpenGradebook,
          onOpenSchedule: widget.onOpenSchedule,
          onOpenResults: widget.onOpenResults,
        );
      case ClassroomToolsSection.setup:
        return _SetupSection(
          key: const ValueKey('setup'),
          setupMode: widget.setupMode,
          onSetupModeChanged: widget.onSetupModeChanged,
          onOpenLegacySeating: widget.onOpenLegacySeating,
        );
    }
  }
}

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
      child: Row(
        children: [
          Icon(Icons.tune_rounded, size: 19, color: OSColors.blueSoft),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Classroom tools',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: OSColors.textPrimary(dark),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Hide tools',
            onPressed: onClose,
            icon: const Icon(Icons.chevron_right_rounded),
            color: OSColors.textSubtle(dark),
          ),
        ],
      ),
    );
  }
}

class _SectionPicker extends StatelessWidget {
  const _SectionPicker({
    required this.value,
    required this.onChanged,
  });

  final ClassroomToolsSection value;
  final ValueChanged<ClassroomToolsSection> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _chip(context, ClassroomToolsSection.today, 'Today'),
        _chip(context, ClassroomToolsSection.students, 'Students'),
        _chip(context, ClassroomToolsSection.classInfo, 'Class'),
        _chip(context, ClassroomToolsSection.setup, 'Setup'),
      ],
    );
  }

  Widget _chip(
    BuildContext context,
    ClassroomToolsSection section,
    String label,
  ) {
    final selected = section == value;
    final dark = context.isDark;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onChanged(section),
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: selected
            ? OSColors.textPrimary(dark)
            : OSColors.textSubtle(dark),
      ),
      selectedColor: OSColors.blue.withValues(alpha: dark ? 0.24 : 0.15),
      backgroundColor:
          OSColors.elevatedPanelSurface(dark).withValues(alpha: 0.44),
      side: BorderSide(
        color: selected
            ? OSColors.blue.withValues(alpha: 0.38)
            : OSColors.panelBorder(dark).withValues(alpha: 0.72),
      ),
      shape: RoundedRectangleBorder(borderRadius: OSRadius.pillBr),
    );
  }
}

class _TodaySection extends StatelessWidget {
  const _TodaySection({
    super.key,
    required this.studentCount,
    required this.placedSeatCount,
    required this.seatCount,
    required this.tableCount,
    required this.onPickStudent,
  });

  final int studentCount;
  final int placedSeatCount;
  final int seatCount;
  final int tableCount;
  final VoidCallback onPickStudent;

  @override
  Widget build(BuildContext context) {
    final unseated = (studentCount - placedSeatCount).clamp(0, studentCount);
    return _DrawerScroll(
      children: [
        const _SectionTitle(
          title: 'Today',
          subtitle: 'Live classroom status from the current room map.',
        ),
        _MetricRow(
          items: [
            _MetricData('Students', '$studentCount'),
            _MetricData('Seated', '$placedSeatCount'),
          ],
        ),
        const SizedBox(height: 10),
        _MetricRow(
          items: [
            _MetricData('Unseated', '$unseated'),
            _MetricData('Tables', '$tableCount'),
          ],
        ),
        const SizedBox(height: 14),
        _ActionButton(
          icon: Icons.casino_rounded,
          label: 'Random student',
          onPressed: onPickStudent,
        ),
        const SizedBox(height: 8),
        _InfoCard(
          icon: Icons.event_seat_outlined,
          title: '$seatCount seats in the active room',
          body: 'The room map and student placements are using the existing InstructOS seating engine.',
        ),
      ],
    );
  }
}

class _StudentsSection extends StatelessWidget {
  const _StudentsSection({
    super.key,
    required this.studentCount,
    required this.placedSeatCount,
    required this.onOpenStudents,
  });

  final int studentCount;
  final int placedSeatCount;
  final VoidCallback onOpenStudents;

  @override
  Widget build(BuildContext context) {
    return _DrawerScroll(
      children: [
        const _SectionTitle(
          title: 'Students',
          subtitle: 'Use the live roster already attached to this class.',
        ),
        _InfoCard(
          icon: Icons.people_alt_outlined,
          title: '$studentCount students',
          body: '$placedSeatCount currently have a seat in this room map.',
        ),
        const SizedBox(height: 12),
        _ActionButton(
          icon: Icons.people_rounded,
          label: 'Open student records',
          onPressed: onOpenStudents,
        ),
      ],
    );
  }
}

class _ClassSection extends StatelessWidget {
  const _ClassSection({
    super.key,
    required this.onOpenGradebook,
    required this.onOpenSchedule,
    required this.onOpenResults,
  });

  final VoidCallback onOpenGradebook;
  final VoidCallback onOpenSchedule;
  final VoidCallback onOpenResults;

  @override
  Widget build(BuildContext context) {
    return _DrawerScroll(
      children: [
        const _SectionTitle(
          title: 'Class',
          subtitle: 'Open existing class systems instead of rebuilding them here.',
        ),
        _ActionButton(
          icon: Icons.menu_book_rounded,
          label: 'Gradebook',
          onPressed: onOpenGradebook,
        ),
        const SizedBox(height: 8),
        _ActionButton(
          icon: Icons.event_note_outlined,
          label: 'Schedule',
          onPressed: onOpenSchedule,
        ),
        const SizedBox(height: 8),
        _ActionButton(
          icon: Icons.assessment_outlined,
          label: 'Results',
          onPressed: onOpenResults,
        ),
      ],
    );
  }
}

class _SetupSection extends StatelessWidget {
  const _SetupSection({
    super.key,
    required this.setupMode,
    required this.onSetupModeChanged,
    required this.onOpenLegacySeating,
  });

  final bool setupMode;
  final ValueChanged<bool> onSetupModeChanged;
  final VoidCallback onOpenLegacySeating;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return _DrawerScroll(
      children: [
        const _SectionTitle(
          title: 'Setup',
          subtitle: 'Furniture and roster-placement controls stay out of normal teaching mode.',
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: OSColors.elevatedPanelSurface(dark).withValues(alpha: 0.52),
            borderRadius: OSRadius.mdBr,
            border: Border.all(
              color: OSColors.panelBorder(dark).withValues(alpha: 0.75),
            ),
          ),
          child: SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Setup room',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: const Text(
              'Show the existing room-building toolbar and unseated-student panel.',
            ),
            value: setupMode,
            onChanged: onSetupModeChanged,
          ),
        ),
        const SizedBox(height: 12),
        _ActionButton(
          icon: Icons.meeting_room_outlined,
          label: 'Open full seating setup',
          onPressed: onOpenLegacySeating,
        ),
        const SizedBox(height: 8),
        Text(
          'Reusable room setup management remains available in the existing seating screen during C1.',
          style: TextStyle(
            fontSize: 11.5,
            height: 1.35,
            color: OSColors.textSubtle(dark),
          ),
        ),
      ],
    );
  }
}

class _DrawerScroll extends StatelessWidget {
  const _DrawerScroll({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: OSColors.textPrimary(dark),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              color: OSColors.textSubtle(dark),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricData {
  const _MetricData(this.label, this.value);

  final String label;
  final String value;
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.items});

  final List<_MetricData> items;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (int index = 0; index < items.length; index++) ...[
          if (index > 0) const SizedBox(width: 8),
          Expanded(child: _MetricCard(data: items[index])),
        ],
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.data});

  final _MetricData data;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: OSColors.elevatedPanelSurface(dark).withValues(alpha: 0.52),
        borderRadius: OSRadius.mdBr,
        border: Border.all(
          color: OSColors.panelBorder(dark).withValues(alpha: 0.75),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data.value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: OSColors.textPrimary(dark),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            data.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: OSColors.textSubtle(dark),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: OSColors.elevatedPanelSurface(dark).withValues(alpha: 0.46),
        borderRadius: OSRadius.mdBr,
        border: Border.all(
          color: OSColors.panelBorder(dark).withValues(alpha: 0.72),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: OSColors.cyan),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: OSColors.textPrimary(dark),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.35,
                    color: OSColors.textSubtle(dark),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Align(
        alignment: Alignment.centerLeft,
        child: Text(label),
      ),
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        minimumSize: const Size.fromHeight(44),
        shape: RoundedRectangleBorder(borderRadius: OSRadius.mdBr),
      ),
    );
  }
}

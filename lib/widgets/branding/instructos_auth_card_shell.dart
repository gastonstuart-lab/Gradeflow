import 'package:flutter/material.dart';
import 'package:gradeflow/config/instructos_design.dart';

class InstructOSAuthCardShell extends StatelessWidget {
  const InstructOSAuthCardShell(
      {super.key, required this.child, required this.compact});
  final Widget child;
  final bool compact;
  @override
  Widget build(BuildContext context) => Container(
      padding: EdgeInsets.all(compact ? 24 : 36),
      decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
              color: InstructOSDesign.dark(context)
                  ? InstructOSDesign.lineDark
                  : InstructOSDesign.line),
          boxShadow: const [
            BoxShadow(
                color: Color(0x0e173b63), blurRadius: 36, offset: Offset(0, 16))
          ]),
      child: child);
}

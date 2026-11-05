import 'package:flutter/material.dart';
import 'package:gradeflow/config/instructos_design.dart';

/// Same calm canvas as the teacher workspace; no continuous decorative motion.
class InstructOSInteractiveAuthBackground extends StatelessWidget {
  const InstructOSInteractiveAuthBackground({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => DecoratedBox(
      decoration: BoxDecoration(
          gradient: InstructOSDesign.backdrop(InstructOSDesign.dark(context))),
      child: child);
}

import 'package:flutter/material.dart';
import 'package:gradeflow/config/instructos_design.dart';

class AnimatedPageBackground extends StatelessWidget {
  const AnimatedPageBackground({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => DecoratedBox(
      decoration: BoxDecoration(
          gradient: InstructOSDesign.backdrop(InstructOSDesign.dark(context))),
      child: child);
}

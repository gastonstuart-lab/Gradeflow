import 'package:flutter/material.dart';

/// Product-wide visual foundation. Status colours keep their semantic meaning.
class InstructOSDesign {
  static const ink = Color(0xff173b63);
  static const teal = Color(0xff187f79);
  static const tealLight = Color(0xff82d5cc);
  static const canvas = Color(0xfff0f5fa);
  static const night = Color(0xff07131f);
  static const surfaceDark = Color(0xff102332);
  static const line = Color(0xffdce6ed);
  static const lineDark = Color(0xff294252);
  static const header = LinearGradient(
      colors: [ink, teal],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight);
  static bool dark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;
  static Color background(BuildContext context) =>
      dark(context) ? night : canvas;
  static LinearGradient backdrop(bool dark) => LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: dark
          ? const [night, Color(0xff0b1c28), Color(0xff102c32)]
          : const [Color(0xffe7eff7), Color(0xfff6f9fc), Color(0xffeaf5f2)]);
}

class InstructOSBrandMark extends StatelessWidget {
  const InstructOSBrandMark({super.key, this.size = 44});
  final double size;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
      child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
              gradient: InstructOSDesign.header,
              borderRadius: BorderRadius.circular(size * .3)),
          child: Icon(Icons.layers_rounded,
              color: Colors.white, size: size * .56)));
}

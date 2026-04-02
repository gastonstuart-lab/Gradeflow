import 'package:flutter/material.dart';

Color timetableColorForClassTitle(String title) {
  final key = title.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  if (key.isEmpty) {
    return Colors.blue;
  }

  var hash = 0;
  for (final codeUnit in key.codeUnits) {
    hash = ((hash * 31) + codeUnit) & 0x7fffffff;
  }

  final hue = (hash % 360).toDouble();
  return HSVColor.fromAHSV(1, hue, 0.68, 0.9).toColor();
}

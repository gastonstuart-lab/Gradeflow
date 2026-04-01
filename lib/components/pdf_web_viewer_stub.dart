import 'dart:typed_data';

import 'package:flutter/widgets.dart';

class PdfWebViewer extends StatelessWidget {
  final Uint8List bytes;

  const PdfWebViewer({super.key, required this.bytes});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

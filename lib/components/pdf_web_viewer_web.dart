import 'dart:js_interop';
import 'dart:ui_web' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

class PdfWebViewer extends StatefulWidget {
  final Uint8List bytes;

  const PdfWebViewer({super.key, required this.bytes});

  @override
  State<PdfWebViewer> createState() => _PdfWebViewerState();
}

class _PdfWebViewerState extends State<PdfWebViewer> {
  late final String _viewType;
  String? _blobUrl;

  @override
  void initState() {
    super.initState();
    _viewType =
        'pdf-viewer-${DateTime.now().microsecondsSinceEpoch}-${widget.hashCode}';
    try {
      final parts = <JSAny>[widget.bytes.toJS];
      final blob = web.Blob(
        parts.toJS,
        web.BlobPropertyBag(type: 'application/pdf'),
      );
      _blobUrl = web.URL.createObjectURL(blob);
      ui.platformViewRegistry.registerViewFactory(_viewType, (int _) {
        final iframe = web.HTMLIFrameElement()
          ..src = _blobUrl!
          ..style.border = 'none'
          ..width = '100%'
          ..height = '100%';
        return iframe;
      });
    } catch (e) {
      debugPrint('PdfWebViewer init failed: $e');
    }
  }

  @override
  void dispose() {
    final blobUrl = _blobUrl;
    if (blobUrl != null) {
      try {
        web.URL.revokeObjectURL(blobUrl);
      } catch (_) {}
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_blobUrl == null) {
      return const SizedBox.shrink();
    }
    return HtmlElementView(viewType: _viewType);
  }
}

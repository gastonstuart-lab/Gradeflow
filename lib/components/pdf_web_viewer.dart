import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
// ignore: depend_on_referenced_packages
import 'dart:ui_web' as ui;
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

/// A simple in-app PDF viewer for Flutter Web that embeds an <iframe>
/// with a blob: URL. This avoids popup/download blockers by rendering
/// the document inside the app instead of opening new tabs.
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
    _viewType = 'pdf-viewer-${DateTime.now().microsecondsSinceEpoch}-${widget.hashCode}';
    if (kIsWeb) {
      try {
        _blobUrl = html.Url.createObjectUrlFromBlob(html.Blob([widget.bytes], 'application/pdf'));
        ui.platformViewRegistry.registerViewFactory(_viewType, (int _) {
          final iframe = html.IFrameElement()
            ..src = _blobUrl
            ..style.border = 'none'
            ..width = '100%'
            ..height = '100%';
          return iframe;
        });
      } catch (e) {
        // Fallback: leave _blobUrl null so build can render empty state.
        debugPrint('PdfWebViewer init failed: $e');
      }
    }
  }

  @override
  void dispose() {
    if (kIsWeb && _blobUrl != null) {
      try {
        html.Url.revokeObjectUrl(_blobUrl!);
      } catch (_) {}
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb || _blobUrl == null) {
      return const SizedBox.shrink();
    }
    return HtmlElementView(viewType: _viewType);
  }
}

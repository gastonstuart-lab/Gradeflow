import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

Future<bool> downloadBrowserBytes(
  Uint8List bytes,
  String filename,
  String mime,
) async {
  if (bytes.isEmpty) return false;

  try {
    final parts = <JSAny>[bytes.toJS];
    final blob = web.Blob(
      parts.toJS,
      web.BlobPropertyBag(type: mime),
    );
    final url = web.URL.createObjectURL(blob);
    final anchor = web.HTMLAnchorElement()
      ..href = url
      ..download = filename;
    anchor.style.display = 'none';
    web.document.body?.append(anchor);
    anchor.click();
    anchor.remove();

    await Future<void>.delayed(const Duration(seconds: 1));
    web.URL.revokeObjectURL(url);
    return true;
  } catch (_) {
    return false;
  }
}

Future<bool> downloadBrowserText(
  String text,
  String filename,
  String mime,
) {
  final bytes = Uint8List.fromList(utf8.encode(text));
  return downloadBrowserBytes(bytes, filename, mime);
}

Future<bool> copyBrowserText(String text) async {
  try {
    await web.window.navigator.clipboard.writeText(text).toDart;
    return true;
  } catch (_) {
    return false;
  }
}

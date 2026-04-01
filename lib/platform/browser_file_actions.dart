import 'dart:typed_data';

import 'browser_file_actions_stub.dart'
    if (dart.library.js_interop) 'browser_file_actions_web.dart' as impl;

Future<bool> downloadBrowserBytes(
  Uint8List bytes,
  String filename,
  String mime,
) {
  return impl.downloadBrowserBytes(bytes, filename, mime);
}

Future<bool> downloadBrowserText(
  String text,
  String filename,
  String mime,
) {
  return impl.downloadBrowserText(text, filename, mime);
}

Future<bool> copyBrowserText(String text) {
  return impl.copyBrowserText(text);
}

import 'dart:js_interop';
import 'package:web/web.dart' as web;

/// Browser security requires a click/tap for entering fullscreen.
/// Do not call automatically after an async login redirect.
bool get browserFullscreenAvailable =>
    web.document.documentElement?.requestFullscreen != null;

Future<bool> toggleBrowserFullscreen() async {
  try {
    if (web.document.fullscreenElement != null) {
      await web.document.exitFullscreen().toDart;
      return true;
    }
    final element = web.document.documentElement;
    if (element == null) return false;
    await element.requestFullscreen().toDart;
    return web.document.fullscreenElement != null;
  } catch (_) {
    return false;
  }
}

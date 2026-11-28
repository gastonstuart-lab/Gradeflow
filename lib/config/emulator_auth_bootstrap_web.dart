import 'package:web/web.dart' as web;

/// Called only after the compile-time staging, demo project, debug mode
/// and loopback guards have passed. Key matches firebase_auth_web 6.3.1's
/// authEmulatorOriginStorageKey for the default app. No credentials stored.
void primeWebAuthEmulator() {
  web.window.sessionStorage.setItem(
    '[DEFAULT]-firebaseEmulatorOrigin', 'http://127.0.0.1:9099',
  );
}

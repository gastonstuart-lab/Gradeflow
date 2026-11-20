import 'package:web/web.dart' as web;

/// FlutterFire reads this per-tab hint during Firebase.initializeApp, before
/// FirebaseService can call useAuthEmulator. New noopener tabs do not inherit
/// sessionStorage, even though Firebase's persisted user is shared across tabs.
/// Called only after the existing loopback/demo-project emulator guard passes.
void prepareLocalAuthEmulatorOrigin() {
  web.window.sessionStorage.setItem(
    '[DEFAULT]-firebaseEmulatorOrigin',
    'http://127.0.0.1:9099',
  );
}

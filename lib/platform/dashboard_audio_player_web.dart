import 'dart:js_interop';

import 'package:web/web.dart' as web;

class DashboardAudioPlayer {
  DashboardAudioPlayer() {
    _audio.preload = 'none';
    _audio.crossOrigin = 'anonymous';
  }

  final web.HTMLAudioElement _audio = web.HTMLAudioElement();
  String? _currentStreamUrl;

  bool get isSupported => true;

  bool get isPlaying => !_audio.paused;

  String? get currentStreamUrl => _currentStreamUrl;

  Future<void> play(String streamUrl) async {
    if (_currentStreamUrl != streamUrl) {
      _currentStreamUrl = streamUrl;
      _audio.src = streamUrl;
      _audio.load();
    }
    await _audio.play().toDart;
  }

  Future<void> pause() async {
    _audio.pause();
  }

  void dispose() {
    _audio.pause();
    _audio.removeAttribute('src');
    _audio.load();
    _currentStreamUrl = null;
  }
}

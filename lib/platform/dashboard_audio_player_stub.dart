class DashboardAudioPlayer {
  bool get isSupported => false;

  bool get isPlaying => false;

  String? get currentStreamUrl => null;

  Future<void> play(String streamUrl) async {
    throw UnsupportedError('Streaming audio is only available on web.');
  }

  Future<void> pause() async {}

  void dispose() {}
}

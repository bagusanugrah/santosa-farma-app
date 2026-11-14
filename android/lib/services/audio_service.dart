import 'package:audioplayers/audioplayers.dart';

class AudioService {
  static final AudioService instance = AudioService._internal();
  AudioService._internal();

  final AudioPlayer _player = AudioPlayer();

  Future<void> playOrderChime() async {
    try {
      // Play high quality chime sound
      await _player.stop();
      // Use remote sound or asset chime
      await _player.play(
        UrlSource('https://cdn.freesound.org/previews/264/264981_4486188-lq.mp3'),
        volume: 1.0,
      );
    } catch (e) {
      // Audio fallback
    }
  }

  void dispose() {
    _player.dispose();
  }
}

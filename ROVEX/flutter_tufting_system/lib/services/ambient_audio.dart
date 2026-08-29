import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Soft ambient bed — quiet, sleepy presence for the whole session.
class AmbientAudio {
  AmbientAudio._();
  static final AmbientAudio instance = AmbientAudio._();

  final AudioPlayer _player = AudioPlayer();
  bool _started = false;
  bool _muted = false;

  bool get isMuted => _muted;

  Future<void> start() async {
    if (_started) {
      if (!_muted) await _player.setVolume(0.28);
      return;
    }
    _started = true;
    try {
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.setVolume(_muted ? 0.0 : 0.28);
      await _player.play(AssetSource('audio/ambient_soft.wav'));
    } catch (e) {
      debugPrint('AmbientAudio failed: $e');
      _started = false;
    }
  }

  Future<void> toggleMute() async {
    _muted = !_muted;
    if (!_started) {
      await start();
      return;
    }
    await _player.setVolume(_muted ? 0.0 : 0.28);
  }

  Future<void> setSleepy(bool on) async {
    if (!_muted) await _player.setVolume(on ? 0.22 : 0.28);
  }

  Future<void> stop() async {
    await _player.stop();
    _started = false;
  }
}

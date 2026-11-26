import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'settings_service.dart';

/// Central game sound effects.
/// Sounds are small synthesized WAVs bundled in assets/sounds/.
/// Respects the user's sound setting and ducks while voice chat is active.
class AudioService {
  static final AudioPlayer _player = AudioPlayer();
  static bool _communicationMode = false;

  /// Widget tests set this to skip platform sound calls entirely; the
  /// audioplayers plugin is not registered there and its async event-channel
  /// errors escape the try/catch below and fail the test.
  static bool mutedForTests = false;

  static Future<void> _play(String file, {double volume = 1.0}) async {
    if (kIsWeb) return;
    if (mutedForTests) return;
    if (_communicationMode) return;
    if (!SettingsService.isSoundEnabled) return;
    try {
      await _player.stop();
      await _player.play(
        AssetSource('sounds/$file'),
        volume: volume,
        mode: PlayerMode.lowLatency,
      );
    } catch (e) {
      debugPrint('AudioService play failed: $e');
    }
  }

  /// Voice chat switches the device into communication mode; game sounds are
  /// muted meanwhile so the voice stays clear.
  static void setCommunicationMode(bool enabled) {
    _communicationMode = enabled;
    if (enabled) stopAll();
  }

  static Future<void> stopAll() async {
    try {
      await _player.stop();
    } catch (_) {}
  }

  static Future<void> playClick() => _play('click.wav', volume: 0.6);
  static Future<void> playTick() => _play('tick.wav', volume: 0.5);
  static Future<void> playSuccess() => _play('success.wav');
  static Future<void> playFailure() => _play('failure.wav', volume: 0.8);
  static Future<void> playExplosion() => _play('explosion.wav');
  static Future<void> playWinVoice() => _play('win.wav');
  static Future<void> playLoseVoice() => _play('lose.wav');
  static Future<void> playEncouragement() => _play('encourage.wav', volume: 0.7);
}

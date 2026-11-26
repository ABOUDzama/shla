import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

/// Input source for تحدّي الإيقاع: detects one clap/tap at a time while a
/// player imitates the pattern.
abstract class ClapDetector {
  /// Called on every detected clap/tap.
  void Function()? onClap;

  /// Starts listening. Returns false when the input is unavailable (no mic,
  /// permission refused, platform unsupported) so the game can say so
  /// truthfully and fall back to the tap mode.
  Future<bool> start();

  Future<void> stop();
}

/// Real-mic clap detector: watches the recorder amplitude and fires on a
/// sharp loud onset, debounced so one clap fires once.
///
/// NOTE: detection thresholds are tuned by ear in the simulator only.
/// Accuracy of clap detection (and therefore mic-mode scoring) still needs
/// validation on a real device, in real café noise, before it is trusted.
class MicClapDetector extends ClapDetector {
  MicClapDetector({AudioRecorder? recorder})
      : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;
  StreamSubscription<Amplitude>? _sub;

  /// dBFS jump over the running floor that counts as a clap onset.
  static const double _onsetDb = 14;

  /// Minimum ms between two detected claps.
  static const int _debounceMs = 140;

  double _floor = -60;
  int _lastFire = 0;

  @override
  Future<bool> start() async {
    if (kIsWeb) return false;
    try {
      if (!await _recorder.hasPermission()) return false;
      // A throwaway stream: we only read amplitude, nothing is kept.
      final stream = await _recorder.startStream(const RecordConfig());
      _floor = -60;
      _lastFire = 0;
      _sub = _recorder
          .onAmplitudeChanged(const Duration(milliseconds: 40))
          .listen((amp) {
        final now = DateTime.now().millisecondsSinceEpoch;
        final db = amp.current;
        // Slow-follow noise floor so a loud café does not self-trigger.
        _floor = _floor * 0.9 + db * 0.1;
        if (db - _floor > _onsetDb &&
            db > -35 &&
            now - _lastFire > _debounceMs) {
          _lastFire = now;
          onClap?.call();
        }
      });
      // Keep the stream referenced; cancellation happens in stop().
      unawaited(stream.drain<void>().catchError((_) {}));
      return true;
    } catch (e) {
      debugPrint('MicClapDetector start failed: $e');
      return false;
    }
  }

  @override
  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    try {
      await _recorder.stop();
    } catch (_) {}
  }

  Future<void> dispose() => stop();
}

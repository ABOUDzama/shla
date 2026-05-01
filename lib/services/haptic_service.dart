import 'package:flutter/foundation.dart';
import 'package:vibration/vibration.dart';

class HapticService {
  static Future<void> vibrate({int duration = 50, List<int>? pattern, int? amplitude}) async {
    if (kIsWeb) return;
    try {
      // Catching potential MissingPluginException during the hasVibrator check
      final hasVibrator = await Vibration.hasVibrator().catchError((_) => false);
      if (hasVibrator == true) {
        if (pattern != null) {
          Vibration.vibrate(pattern: pattern, amplitude: amplitude ?? -1);
        } else {
          Vibration.vibrate(duration: duration, amplitude: amplitude ?? -1);
        }
      }
    } catch (e) {
      debugPrint('HapticService Error: $e');
    }
  }

  static Future<void> lightImpact() async {
    await vibrate(duration: 10);
  }

  static Future<void> success() async {
    await vibrate(pattern: [0, 50, 50, 50]);
  }

  static Future<void> heavyImpact() async {
    await vibrate(duration: 80, amplitude: 255);
  }
}

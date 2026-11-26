import 'audio_service.dart';
import 'haptic_service.dart';

/// One-stop sound + haptics for the ١٢٣٤ arcade games.
/// Every call is fire-and-forget and safe in tests (AudioService.mutedForTests
/// and HapticService's try/catch cover the missing plugins).
class ArcadeJuice {
  /// Any button tap in an arcade game.
  static void tap() {
    AudioService.playClick();
    HapticService.lightImpact();
  }

  /// Player scores a point / pops a target / grabs a coin.
  static void score() {
    AudioService.playSuccess();
    HapticService.lightImpact();
  }

  /// A hit, crash, explosion or snap (croc bite, tank shell, snowball hit).
  static void hit() {
    AudioService.playExplosion();
    HapticService.heavyImpact();
  }

  /// Countdown / warning tick.
  static void tick() {
    AudioService.playTick();
  }

  /// Match ended in a human win.
  static void win() {
    AudioService.playWinVoice();
    HapticService.success();
  }

  /// Match ended in a loss / bots win.
  static void lose() {
    AudioService.playLoseVoice();
    HapticService.heavyImpact();
  }

  /// Small mistake (wrong tap, foul).
  static void fail() {
    AudioService.playFailure();
    HapticService.heavyImpact();
  }
}

import 'dart:math';

/// حرب البطاريق — penguin snowball duel as a pure, testable simulation.
/// Two penguins on ice floes lob snowballs over an iceberg; first direct
/// hit wins the round. Turn-based between two seats on one phone.
class PenguinDuel {
  PenguinDuel({this.worldWidth = 480, this.worldHeight = 300});

  final double worldWidth;
  final double worldHeight;

  static const double gravity = 500;
  static const double penguinR = 16;
  static const double maxPower = 520;

  /// Ice floe height from the bottom; penguins stand on it.
  static const double floeY = 240;

  /// The iceberg in the middle: a triangle peak at (centerX, peakY).
  double get centerX => worldWidth / 2;
  static const double peakY = 150; // y of the iceberg tip
  static const double peakHalfWidth = 46;

  /// Penguin positions (x, y of body center).
  (double, double) penguinPos(int seat) =>
      (seat == 0 ? 40.0 : worldWidth - 40, floeY - penguinR);

  int turn = 0; // seat shooting now
  int? winner;

  /// Simulated ball state during flight.
  double ballX = 0, ballY = 0, vx = 0, vy = 0;
  bool flying = false;

  /// Launch a snowball for the current seat. [angleDeg]: 0 = toward the
  /// rival horizontally, positive = up. [power01]: 0..1.
  void shoot(double angleDeg, double power01) {
    if (flying || winner != null) return;
    final p = penguinPos(turn);
    final dir = turn == 0 ? 1.0 : -1.0;
    final rad = angleDeg * pi / 180;
    final speed = power01.clamp(0.1, 1.0) * maxPower;
    ballX = p.$1;
    ballY = p.$2;
    vx = dir * speed * cos(rad);
    vy = -speed * sin(rad);
    flying = true;
  }

  /// Height of the iceberg surface at x, or null if outside the berg.
  double? bergTopAt(double x) {
    final d = (x - centerX).abs();
    if (d > peakHalfWidth) return null;
    return peakY + d * (floeY - peakY) / peakHalfWidth;
  }

  /// Advances the ball; resolves hit / block / miss and passes the turn.
  /// Returns a string describing the outcome when flight ends.
  String? step(double dt) {
    if (!flying) return null;
    vy += gravity * dt;
    ballX += vx * dt;
    ballY += vy * dt;

    // Hit the rival penguin?
    final rival = penguinPos(1 - turn);
    final dx = ballX - rival.$1;
    final dy = ballY - rival.$2;
    if (dx * dx + dy * dy <= penguinR * penguinR * 1.8) {
      flying = false;
      winner = turn;
      return 'hit';
    }

    // Blocked by the iceberg?
    final berg = bergTopAt(ballX);
    if (berg != null && ballY > berg) {
      flying = false;
      turn = 1 - turn;
      return 'berg';
    }

    // Into the water / off the world?
    if (ballY > worldHeight + 20 || ballX < -20 || ballX > worldWidth + 20) {
      flying = false;
      turn = 1 - turn;
      return 'miss';
    }
    return null;
  }

  /// Bot aim: solve for the angle/power that lands on the rival, with a
  /// seeded error so bots miss sometimes. 45 degrees, speed from range.
  (double, double) botAim({double error = 0}) {
    final me = penguinPos(turn);
    final rival = penguinPos(1 - turn);
    final dist = (rival.$1 - me.$1).abs();
    // Ballistic range at 45 degrees: R = v^2 / g  =>  v = sqrt(R * g).
    var v = sqrt(dist * gravity);
    v *= 1 + error / 100;
    final power = (v / maxPower).clamp(0.15, 1.0);
    return (45.0, power); // 45 degrees maximizes range
  }
}

import 'dart:math';

/// تصويب الشلة — target-tap shooting as a pure, testable simulation.
/// Turn-based: every seat gets the same seeded stream of balls flying up;
/// tap them before they escape. Most hits wins.
class BallShootRound {
  BallShootRound({Random? random, this.ballCount = 12})
      : _random = random ?? Random() {
    _spawnNext();
  }

  final Random _random;

  /// Balls per round (per seat).
  final int ballCount;

  static const double worldWidth = 360;
  static const double worldHeight = 600;
  static const double ballRadius = 26;

  int launched = 0;
  int hits = 0;
  int misses = 0; // escaped balls
  int taps = 0; // shots fired
  bool over = false;

  /// The live ball, or null between balls: (x, y, vx, vy).
  (double, double, double, double)? ball;
  double _pauseLeft = 0;

  double get accuracy => taps == 0 ? 0 : hits / taps;

  void _spawnNext() {
    if (launched >= ballCount) {
      ball = null;
      return;
    }
    launched++;
    final x = 60 + _random.nextDouble() * (worldWidth - 120);
    final vx = (_random.nextDouble() - 0.5) * 90;
    final vy = -(380 + _random.nextDouble() * 140);
    ball = (x, worldHeight + ballRadius, vx, vy);
  }

  void step(double dt) {
    if (over) return;
    final b = ball;
    if (b == null) {
      // Brief pause between balls; round ends after the last one resolves.
      if (launched >= ballCount) {
        over = true;
        return;
      }
      _pauseLeft -= dt;
      if (_pauseLeft <= 0) _spawnNext();
      return;
    }
    var (x, y, vx, vy) = b;
    vy += 260 * dt; // gentle gravity arc
    x += vx * dt;
    y += vy * dt;
    if (x < ballRadius || x > worldWidth - ballRadius) {
      vx = -vx;
      x = x.clamp(ballRadius, worldWidth - ballRadius);
    }
    ball = (x, y, vx, vy);
    // Escaped off the top or fell back below the bottom.
    if ((y < -ballRadius && vy < 0) || y > worldHeight + ballRadius * 2) {
      misses++;
      ball = null;
      _pauseLeft = 0.5;
    }
  }

  /// A tap at world coordinates; returns true when it hits the live ball.
  bool tapAt(double x, double y) {
    if (over) return false;
    taps++;
    final b = ball;
    if (b == null) return false;
    final dx = x - b.$1;
    final dy = y - b.$2;
    if (dx * dx + dy * dy <= ballRadius * ballRadius * 1.44) {
      hits++;
      ball = null;
      _pauseLeft = 0.5;
      return true;
    }
    return false;
  }

  /// Bot behavior: taps the ball's position with a seeded error after a
  /// reaction delay. Returns the tap point or null if it waits.
  (double, double)? botTap({double error = 0, double sinceVisible = 0}) {
    final b = ball;
    if (b == null || over) return null;
    if (sinceVisible < 0.35) return null; // reaction time
    return (b.$1 + error, b.$2 + error * 0.6);
  }
}

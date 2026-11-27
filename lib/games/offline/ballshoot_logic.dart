import 'dart:math';

/// تصويب الشلة — target-tap shooting as a pure, testable simulation.
/// Turn-based: every seat gets the same seeded stream of balls flying up;
/// tap them before they escape. Most hits wins.
/// Up to three balls fly at once so the sky stays busy.
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
  static const int maxActive = 3;
  static const double spawnEvery = 0.55;

  int launched = 0;
  int hits = 0;
  int misses = 0; // escaped balls
  int taps = 0; // shots fired
  bool over = false;

  /// Live balls as (x, y, vx, vy), oldest first.
  final List<(double, double, double, double)> balls = [];
  double _spawnLeft = 0;

  /// The oldest live ball (the most urgent target), or null when none fly.
  (double, double, double, double)? get ball =>
      balls.isEmpty ? null : balls.first;

  double get accuracy => taps == 0 ? 0 : hits / taps;

  void _spawnNext() {
    if (launched >= ballCount) return;
    launched++;
    final x = 60 + _random.nextDouble() * (worldWidth - 120);
    final vx = (_random.nextDouble() - 0.5) * 90;
    final vy = -(380 + _random.nextDouble() * 140);
    balls.add((x, worldHeight + ballRadius, vx, vy));
  }

  void step(double dt) {
    if (over) return;
    // Keep the sky busy: top up to maxActive on a steady cadence.
    if (launched < ballCount && balls.length < maxActive) {
      _spawnLeft -= dt;
      if (_spawnLeft <= 0) {
        _spawnNext();
        _spawnLeft = spawnEvery;
      }
    }
    for (var i = balls.length - 1; i >= 0; i--) {
      var (x, y, vx, vy) = balls[i];
      vy += 260 * dt; // gentle gravity arc
      x += vx * dt;
      y += vy * dt;
      if (x < ballRadius || x > worldWidth - ballRadius) {
        vx = -vx;
        x = x.clamp(ballRadius, worldWidth - ballRadius);
      }
      // Escaped off the top or fell back below the bottom.
      if ((y < -ballRadius && vy < 0) || y > worldHeight + ballRadius * 2) {
        balls.removeAt(i);
        misses++;
        continue;
      }
      balls[i] = (x, y, vx, vy);
    }
    if (launched >= ballCount && balls.isEmpty) over = true;
  }

  /// A tap at world coordinates; returns true when it pops a live ball.
  bool tapAt(double x, double y) {
    if (over) return false;
    taps++;
    for (var i = 0; i < balls.length; i++) {
      final b = balls[i];
      final dx = x - b.$1;
      final dy = y - b.$2;
      if (dx * dx + dy * dy <= ballRadius * ballRadius * 1.44) {
        balls.removeAt(i);
        hits++;
        return true;
      }
    }
    return false;
  }

  /// Bot behavior: taps the oldest ball's position with a seeded error after
  /// a reaction delay. Returns the tap point or null if it waits.
  (double, double)? botTap({double error = 0, double sinceVisible = 0}) {
    final b = ball;
    if (b == null || over) return null;
    if (sinceVisible < 0.35) return null; // reaction time
    return (b.$1 + error, b.$2 + error * 0.6);
  }
}

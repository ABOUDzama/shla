import 'dart:math';

/// سباق العوائق — obstacle-course runner as a pure, testable simulation.
/// Turn-based: every seat runs the same seeded course; fastest finish wins,
/// or furthest distance before crashing.
class ObstacleRun {
  ObstacleRun({Random? random, this.courseLength = 2400})
      : _random = random ?? Random() {
    _generate();
  }

  final Random _random;

  /// Course length in logical pixels; crossing it finishes the run.
  final double courseLength;

  static const double gravity = 2400;
  static const double jumpImpulse = -780;
  static const double runSpeed = 260;
  static const double runnerSize = 34;
  static const double worldHeight = 300;
  static const double groundY = 250;
  static const double runnerX = 90;

  double playerY = groundY;
  double velocity = 0;
  bool onGround = true;
  bool crashed = false;
  bool finished = false;
  double distance = 0;
  double time = 0;

  /// Obstacles as (x, height) sitting on the ground.
  final List<(double, double)> obstacles = [];

  void _generate() {
    var x = 480.0;
    while (x < courseLength - 200) {
      final h = 26 + _random.nextDouble() * 40; // 26..66 tall
      obstacles.add((x, h));
      x += 220 + _random.nextDouble() * 220;
    }
  }

  bool get done => crashed || finished;

  void jump() {
    if (done || !onGround) return;
    velocity = jumpImpulse;
    onGround = false;
  }

  void step(double dt) {
    if (done) return;
    time += dt;
    distance += runSpeed * dt;

    if (!onGround) {
      velocity += gravity * dt;
      playerY += velocity * dt;
      if (playerY >= groundY) {
        playerY = groundY;
        velocity = 0;
        onGround = true;
      }
    }

    // Collision: runner box vs obstacle boxes (worldX = runnerX + distance).
    final rx = runnerX + distance;
    for (final (ox, oh) in obstacles) {
      const half = 14.0; // obstacle half-width
      final overlapX =
          rx + runnerSize / 2 > ox - half && rx - runnerSize / 2 < ox + half;
      if (!overlapX) continue;
      final runnerBottom = playerY + runnerSize / 2;
      final obstacleTop = groundY + runnerSize / 2 - oh;
      if (runnerBottom > obstacleTop) {
        crashed = true;
        return;
      }
    }

    if (distance >= courseLength) {
      finished = true;
    }
  }

  /// Bot jump decision: jump when the next obstacle is at a fixed distance,
  /// with a seeded reaction error so bots are beatable.
  bool botShouldJump({double error = 0}) {
    if (done || !onGround) return false;
    final rx = runnerX + distance;
    for (final (ox, oh) in obstacles) {
      if (ox > rx) {
        final gap = ox - rx;
        return gap < 100 + error;
      }
    }
    return false;
  }
}

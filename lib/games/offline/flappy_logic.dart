import 'dart:math';

/// فلابي الشلة — flappy-bird runs as a pure, testable simulation. Players
/// take turns flying one run each; the furthest score wins the match.
/// A bot flies with a seeded flap heuristic (imperfect on purpose).
class FlappyRun {
  FlappyRun({
    Random? random,
    this.pipeSpacing = 220,
    this.gapHeight = 150,
    this.worldHeight = 600,
    this.birdX = 90,
  }) : _random = random ?? Random();

  final Random _random;

  /// Horizontal distance between pipes (logical pixels).
  final double pipeSpacing;

  /// Vertical gap the bird must pass through.
  final double gapHeight;

  /// Logical world height (ground at worldHeight, ceiling at 0).
  final double worldHeight;

  /// The bird's fixed horizontal position.
  final double birdX;

  static const double gravity = 1500;
  static const double flapImpulse = -420;
  static const double scrollSpeed = 160;
  static const double birdRadius = 14;
  static const double pipeWidth = 56;

  double birdY = 300;
  double velocity = 0;
  bool started = false;
  bool crashed = false;
  int score = 0;

  /// Pipes as (x, gapCenterY). The first pipe spawns well ahead.
  final List<(double, double)> pipes = [];
  double _nextPipeX = 150;

  void flap() {
    if (crashed) return;
    started = true;
    velocity = flapImpulse;
  }

  /// Advances the simulation by [dt] seconds.
  void step(double dt) {
    if (crashed || !started) return;
    velocity += gravity * dt;
    birdY += velocity * dt;

    // Scroll pipes, spawn new ones, score passes.
    for (var i = 0; i < pipes.length; i++) {
      pipes[i] = (pipes[i].$1 - scrollSpeed * dt, pipes[i].$2);
    }
    if (pipes.isNotEmpty && pipes.first.$1 < -pipeWidth - 20) {
      pipes.removeAt(0);
    }
    _nextPipeX -= scrollSpeed * dt;
    if (_nextPipeX < 520) {
      final margin = gapHeight / 2 + 40;
      final gapY =
          margin + _random.nextDouble() * (worldHeight - 2 * margin);
      pipes.add((_nextPipeX + 200, gapY));
      _nextPipeX += pipeSpacing;
    }

    // Ceiling / floor.
    if (birdY < birdRadius) {
      birdY = birdRadius;
      velocity = 0;
    }
    if (birdY > worldHeight - birdRadius) {
      crashed = true;
      return;
    }

    // Pipe collision + scoring.
    for (final (px, gapY) in pipes) {
      final overlapX =
          px - pipeWidth / 2 < birdX + birdRadius && px + pipeWidth / 2 > birdX - birdRadius;
      if (overlapX) {
        final inGap = (birdY - gapY).abs() + birdRadius < gapHeight / 2;
        if (!inGap) {
          crashed = true;
          return;
        }
      }
      // Score once the pipe's right edge crosses behind the bird.
      if ((px + pipeWidth / 2) < birdX &&
          (px + pipeWidth / 2 + scrollSpeed * dt) >= birdX) {
        score++;
      }
    }
  }

  /// Bot flap decision: flap when sinking below the upcoming gap's center,
  /// with a seeded per-run error so bots are beatable.
  bool botShouldFlap({double error = 0}) {
    if (crashed) return false;
    (double, double)? next;
    for (final pipe in pipes) {
      if (pipe.$1 + pipeWidth / 2 >= birdX - birdRadius) {
        next = pipe;
        break;
      }
    }
    final targetY = next == null ? worldHeight * 0.45 : next.$2 + error;
    return birdY > targetY;
  }
}

import 'dart:math';

/// جولف الشلة — minigolf as a pure, testable simulation. Turn-based: every
/// seat plays each hole; fewest total strokes wins. Obstacles are axis-
/// aligned walls the ball bounces off.
class MiniGolfHole {
  MiniGolfHole({
    required this.ballStart,
    required this.holePos,
    this.worldWidth = 360,
    this.worldHeight = 520,
    List<Wall>? walls,
  }) : walls = walls ?? const [] {
    reset();
  }

  /// Logical world size.
  final double worldWidth;
  final double worldHeight;

  /// Tee position and cup position (logical pixels).
  final (double, double) ballStart;
  final (double, double) holePos;

  /// Obstacle walls as (left, top, right, bottom).
  final List<Wall> walls;

  static const double ballRadius = 9;
  static const double holeRadius = 13;
  static const double friction = 140; // px/s^2 deceleration
  static const double stopSpeed = 12; // below this the ball rests
  static const double maxPower = 640; // px/s launch speed
  static const double sinkSpeed = 190; // too fast over the cup = lip out

  double ballX = 0;
  double ballY = 0;
  double vx = 0;
  double vy = 0;
  int strokes = 0;
  bool sunk = false;

  void reset() {
    ballX = ballStart.$1;
    ballY = ballStart.$2;
    vx = 0;
    vy = 0;
    strokes = 0;
    sunk = false;
  }

  bool get resting => !sunk && vx == 0 && vy == 0;

  /// Launch the ball at [angleDeg] (0 = right, 90 = down) with [power01].
  void shoot(double angleDeg, double power01) {
    if (sunk || !resting) return;
    final p = power01.clamp(0.05, 1.0) * maxPower;
    final rad = angleDeg * pi / 180;
    vx = p * cos(rad);
    vy = p * sin(rad);
    strokes++;
  }

  /// Advances the ball; returns when it rests or sinks.
  void step(double dt) {
    if (sunk || resting) return;
    final speed = sqrt(vx * vx + vy * vy);
    final decel = friction * dt;
    if (speed <= decel + stopSpeed) {
      vx = 0;
      vy = 0;
      _checkSink();
      return;
    }
    final ns = speed - decel;
    vx = vx / speed * ns;
    vy = vy / speed * ns;
    ballX += vx * dt;
    ballY += vy * dt;

    // Course bounds bounce.
    if (ballX < ballRadius) {
      ballX = ballRadius;
      vx = -vx * 0.8;
    } else if (ballX > worldWidth - ballRadius) {
      ballX = worldWidth - ballRadius;
      vx = -vx * 0.8;
    }
    if (ballY < ballRadius) {
      ballY = ballRadius;
      vy = -vy * 0.8;
    } else if (ballY > worldHeight - ballRadius) {
      ballY = worldHeight - ballRadius;
      vy = -vy * 0.8;
    }

    // Wall bounces (axis-aligned rectangles).
    for (final w in walls) {
      if (ballX + ballRadius > w.left &&
          ballX - ballRadius < w.right &&
          ballY + ballRadius > w.top &&
          ballY - ballRadius < w.bottom) {
        // Resolve along the axis of least penetration.
        final penLeft = (ballX + ballRadius) - w.left;
        final penRight = w.right - (ballX - ballRadius);
        final penTop = (ballY + ballRadius) - w.top;
        final penBottom = w.bottom - (ballY - ballRadius);
        final minPen =
            [penLeft, penRight, penTop, penBottom].reduce(min);
        if (minPen == penLeft) {
          ballX = w.left - ballRadius;
          vx = -vx.abs() * 0.8;
        } else if (minPen == penRight) {
          ballX = w.right + ballRadius;
          vx = vx.abs() * 0.8;
        } else if (minPen == penTop) {
          ballY = w.top - ballRadius;
          vy = -vy.abs() * 0.8;
        } else {
          ballY = w.bottom + ballRadius;
          vy = vy.abs() * 0.8;
        }
      }
    }
    _checkSink();
  }

  void _checkSink() {
    final d = sqrt(
        (ballX - holePos.$1) * (ballX - holePos.$1) +
            (ballY - holePos.$2) * (ballY - holePos.$2));
    if (d < holeRadius) {
      final speed = sqrt(vx * vx + vy * vy);
      if (speed <= sinkSpeed) {
        sunk = true;
        vx = 0;
        vy = 0;
        ballX = holePos.$1;
        ballY = holePos.$2;
      }
    }
  }
}

/// Axis-aligned rectangle for obstacle walls.
class Wall {
  const Wall(this.left, this.top, this.right, this.bottom);
  final double left, top, right, bottom;
}

/// The three holes of the شلة course, each with its own layout.
List<MiniGolfHole> shellaCourse() => [
      // Hole 1: straight shot, no obstacles.
      MiniGolfHole(ballStart: (180, 460), holePos: (180, 90)),
      // Hole 2: one wall in the middle with a gap on the left.
      MiniGolfHole(
        ballStart: (180, 460),
        holePos: (180, 90),
        walls: const [Wall(110, 250, 360, 268)],
      ),
      // Hole 3: dogleg with two walls.
      MiniGolfHole(
        ballStart: (90, 460),
        holePos: (290, 110),
        walls: const [
          Wall(0, 300, 220, 318),
          Wall(140, 160, 360, 178),
        ],
      ),
    ];

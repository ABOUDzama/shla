import 'dart:math';

/// Pure logic for جري الجون: a faithful clone of the reference's
/// "Goal Rush" (1234playergames.com: "Let go to turn, hold to run, and bump
/// the ball into the other team's goal."). Real-time, one button per player:
/// while held the runner goes straight, while released the runner spins.
/// Bump the ball into another seat's goal to score; own goals reset with no
/// score. First to 3 goals wins. Solo = target practice against the clock.
/// Original code.
class RushRunner {
  RushRunner(this.x, this.y, this.heading);
  double x, y;
  double heading; // radians, 0 = +x
  bool holding = false;
}

class RushGoal {
  RushGoal(this.cx, this.cy, this.halfWidth, this.owner);
  final double cx, cy; // mouth center on a field edge
  final double halfWidth;
  final int owner; // seat defending, -1 = unguarded (practice)
}

class GoalRushMatch {
  GoalRushMatch({required this.seats, Random? random})
      : assert(seats >= 1 && seats <= 4),
        _random = random ?? Random() {
    _setup();
  }

  static const double fieldW = 100;
  static const double fieldH = 140;
  static const double runnerR = 5.5;
  static const double ballR = 4.0;
  static const double goalHalf = 13.0;
  static const double runSpeed = 30.0; // units/s while held
  static const double turnSpeed = 2.8; // rad/s while released
  static const double ballFriction = 0.55; // velocity decay per second
  static const double bumpPower = 1.35; // ball gets runner speed * this
  static const int goalsToWin = 3;
  static const double practiceSeconds = 60;

  final int seats;
  final Random _random;
  final List<RushRunner> runners = [];
  late double ballX, ballY, ballVx, ballVy;
  final List<RushGoal> goals = [];
  final List<int> scores = [];
  int lastToucher = -1;
  double time = 0;
  int? winnerSeat;
  bool practiceOver = false;
  int practiceGoals = 0;

  bool get practice => seats == 1;
  bool get over => winnerSeat != null || practiceOver;
  int? get winner => practice ? null : winnerSeat;
  final Set<int> botSeats = {};

  void _setup() {
    goals.clear();
    switch (seats) {
      case 1:
        goals.add(RushGoal(50, 0, goalHalf, -1));
      case 2:
        goals.add(RushGoal(50, 0, goalHalf, 1));
        goals.add(RushGoal(50, fieldH, goalHalf, 0));
      case 3:
        goals.add(RushGoal(25, 0, goalHalf * 0.8, 1));
        goals.add(RushGoal(75, 0, goalHalf * 0.8, 2));
        goals.add(RushGoal(50, fieldH, goalHalf, 0));
      case 4:
        goals.add(RushGoal(50, 0, goalHalf * 0.8, 2));
        goals.add(RushGoal(50, fieldH, goalHalf * 0.8, 0));
        goals.add(RushGoal(0, fieldH / 2, goalHalf * 0.8, 3));
        goals.add(RushGoal(fieldW, fieldH / 2, goalHalf * 0.8, 1));
    }
    for (var i = 0; i < seats; i++) {
      scores.add(0);
    }
    _kickoff();
  }

  void _kickoff() {
    ballX = 50;
    ballY = fieldH / 2;
    ballVx = 0;
    ballVy = 0;
    lastToucher = -1;
    final spots = <List<double>>[
      [50, fieldH * 0.78, -pi / 2], // bottom, facing up
      [50, fieldH * 0.22, pi / 2], // top (2P) / right (4P), facing down
      [25, fieldH * 0.22, pi / 2],
      [75, fieldH * 0.22, pi / 2],
    ];
    final spots4 = <List<double>>[
      [50, fieldH * 0.78, -pi / 2],
      [fieldW * 0.78, fieldH / 2, pi],
      [50, fieldH * 0.22, pi / 2],
      [fieldW * 0.22, fieldH / 2, 0],
    ];
    final use = seats == 4 ? spots4 : spots;
    runners.clear();
    for (var i = 0; i < seats; i++) {
      runners.add(RushRunner(use[i][0], use[i][1], use[i][2]));
    }
  }

  /// Hold or release the one button for [seat].
  void setHolding(int seat, bool holding) {
    if (over) return;
    runners[seat].holding = holding;
  }

  void step(double dt) {
    if (over) return;
    time += dt;
    // runners: spin when released, run when held
    for (var i = 0; i < runners.length; i++) {
      final r = runners[i];
      if (botSeats.contains(i)) _botControl(i);
      if (r.holding) {
        r.x += cos(r.heading) * runSpeed * dt;
        r.y += sin(r.heading) * runSpeed * dt;
      } else {
        r.heading += turnSpeed * dt;
      }
      // walls: runners bounce back into the field
      r.x = r.x.clamp(runnerR, fieldW - runnerR);
      r.y = r.y.clamp(runnerR, fieldH - runnerR);
      // bump the ball
      final dx = ballX - r.x, dy = ballY - r.y;
      final dist = sqrt(dx * dx + dy * dy);
      final minD = runnerR + ballR;
      if (dist > 0 && dist < minD) {
        final nx = dx / dist, ny = dy / dist;
        ballX = r.x + nx * minD;
        ballY = r.y + ny * minD;
        final speed = r.holding ? runSpeed : runSpeed * 0.4;
        ballVx = nx * speed * bumpPower + (r.holding ? cos(r.heading) * runSpeed * 0.5 : 0);
        ballVy = ny * speed * bumpPower + (r.holding ? sin(r.heading) * runSpeed * 0.5 : 0);
        lastToucher = i;
      }
    }
    // ball physics
    ballX += ballVx * dt;
    ballY += ballVy * dt;
    final decay = pow(ballFriction, dt).toDouble();
    ballVx *= decay;
    ballVy *= decay;
    if (ballVx.abs() < 0.5) ballVx = 0;
    if (ballVy.abs() < 0.5) ballVy = 0;
    _ballWalls();
    _checkGoals();
    if (practice && time >= practiceSeconds) practiceOver = true;
  }

  void _ballWalls() {
    var openTop = false, openBottom = false, openLeft = false, openRight = false;
    for (final g in goals) {
      final horizontal = g.cy == 0 || g.cy == fieldH;
      if (horizontal && (ballX - g.cx).abs() < g.halfWidth) {
        if (g.cy == 0) {
          openTop = true;
        } else {
          openBottom = true;
        }
      } else if (!horizontal && (ballY - g.cy).abs() < g.halfWidth) {
        if (g.cx == 0) {
          openLeft = true;
        } else {
          openRight = true;
        }
      }
    }
    if (ballX < ballR && !openLeft) {
      ballX = ballR;
      ballVx = -ballVx * 0.75;
    }
    if (ballX > fieldW - ballR && !openRight) {
      ballX = fieldW - ballR;
      ballVx = -ballVx * 0.75;
    }
    if (ballY < ballR && !openTop) {
      ballY = ballR;
      ballVy = -ballVy * 0.75;
    }
    if (ballY > fieldH - ballR && !openBottom) {
      ballY = fieldH - ballR;
      ballVy = -ballVy * 0.75;
    }
  }

  void _checkGoals() {
    for (final g in goals) {
      final horizontal = g.cy == 0 || g.cy == fieldH;
      final crossed = horizontal
          ? (g.cy == 0 ? ballY < 0 : ballY > fieldH)
          : (g.cx == 0 ? ballX < 0 : ballX > fieldW);
      if (!crossed) continue;
      final inMouth = horizontal
          ? (ballX - g.cx).abs() < g.halfWidth
          : (ballY - g.cy).abs() < g.halfWidth;
      if (!inMouth) continue;
      if (practice) {
        practiceGoals++;
      } else if (lastToucher >= 0 && g.owner != lastToucher) {
        scores[lastToucher]++;
        if (scores[lastToucher] >= goalsToWin) {
          winnerSeat = lastToucher;
          return;
        }
      }
      _kickoff();
      return;
    }
  }

  /// Bot: release to turn until roughly facing the ball, then hold to run.
  void _botControl(int i) {
    final r = runners[i];
    final want = atan2(ballY - r.y, ballX - r.x);
    var diff = want - r.heading;
    while (diff > pi) {
      diff -= 2 * pi;
    }
    while (diff < -pi) {
      diff += 2 * pi;
    }
    // turn while misaligned (with a little skill slop), run when lined up
    final slop = 0.22 + _random.nextDouble() * 0.05;
    r.holding = diff.abs() < slop;
  }
}

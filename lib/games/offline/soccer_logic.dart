import 'dart:math';

/// Pure logic for Shla Soccer (كورة الشلة), kept apart from the widget so
/// it can be unit-tested without pumping frames.
///
/// Portrait pitch, width 1.0 and height [fieldH]. Team 0 defends the bottom
/// goal and attacks the top one, team 1 the opposite. Everybody auto-runs
/// forward at a constant speed; a player steers by turning left or right.
/// There is no kick button: running into the ball sends it away, harder
/// when the player hits it head-on. A static keeper stands in each goal
/// mouth. First team to [goalsToWin] goals wins, otherwise the timer
/// decides and equal scores are a draw.
class SoccerPlayer {
  SoccerPlayer({
    required this.team,
    required this.x,
    required this.y,
    required this.heading,
    this.isBot = false,
  });

  final int team;
  double x;
  double y;

  /// Radians; 0 points right, pi/2 points down (screen coordinates).
  double heading;
  final bool isBot;
}

class SoccerMatch {
  SoccerMatch({required this.teamSizes, Random? random})
      : assert(teamSizes.length == 2),
        _random = random ?? Random() {
    _kickoff();
  }

  /// Number of players in team 0 and team 1, each 1 or 2.
  final List<int> teamSizes;
  final Random _random;

  static const double fieldH = 1.6;
  static const double goalHalfWidth = 0.18;
  static const double playerR = 0.05;
  static const double ballR = 0.035;
  static const double keeperR = 0.06;
  static const double speed = 0.34;
  static const double turnRate = 3.2; // rad/s
  static const double ballFriction = 0.55; // fraction of speed lost / second
  static const double maxBallSpeed = 1.5;
  static const int goalsToWin = 3;
  static const double matchSeconds = 90;

  late List<SoccerPlayer> players;
  double ballX = 0.5;
  double ballY = fieldH / 2;
  double ballVx = 0;
  double ballVy = 0;

  final List<int> scores = [0, 0];
  double timeLeft = matchSeconds;

  /// Team that scored last, shown briefly as a GOAL banner by the widget.
  int? lastScorer;
  double goalPause = 0;

  /// Keeper positions: index 0 defends the bottom goal, 1 the top goal.
  static const List<Offset2> keepers = [
    Offset2(0.5, fieldH - 0.04),
    Offset2(0.5, 0.04),
  ];

  bool get over => scores.any((s) => s >= goalsToWin) || timeLeft <= 0;

  /// Winning team, or null for a draw / still playing.
  int? get winner {
    if (!over) return null;
    if (scores[0] == scores[1]) return null;
    return scores[0] > scores[1] ? 0 : 1;
  }

  void _kickoff() {
    ballX = 0.5;
    ballY = fieldH / 2;
    ballVx = 0;
    ballVy = 0;
    players = [];
    for (var team = 0; team < 2; team++) {
      final n = teamSizes[team];
      final y = team == 0 ? fieldH * 0.72 : fieldH * 0.28;
      final heading = team == 0 ? -pi / 2 : pi / 2;
      for (var i = 0; i < n; i++) {
        final x = n == 1 ? 0.5 : (i == 0 ? 0.3 : 0.7);
        players.add(SoccerPlayer(
          team: team,
          x: x,
          y: y,
          heading: heading,
        ));
      }
    }
  }

  /// Marks players at [botIndexes] as bot-controlled (rebuilt on kickoff).
  final Set<int> botIndexes = {};

  /// Players that never move (practice mode opponent): still block the ball.
  final Set<int> frozenIndexes = {};

  /// Advances the match by [dt] seconds. [turn] maps a player index to
  /// -1 (turn left), 0 (straight) or 1 (turn right).
  void step(double dt, Map<int, int> turn) {
    if (over) return;
    if (goalPause > 0) {
      goalPause -= dt;
      if (goalPause <= 0) {
        goalPause = 0;
        lastScorer = null;
        _kickoff();
      }
      return;
    }
    timeLeft = max(0, timeLeft - dt);

    for (var i = 0; i < players.length; i++) {
      final p = players[i];
      if (frozenIndexes.contains(i)) continue;
      final t = botIndexes.contains(i) ? _botTurn(p) : (turn[i] ?? 0);
      p.heading += t * turnRate * dt;
      p.x += cos(p.heading) * speed * dt;
      p.y += sin(p.heading) * speed * dt;
      _clampPlayer(p);
    }
    _separatePlayers();

    // Ball movement and friction.
    ballX += ballVx * dt;
    ballY += ballVy * dt;
    final decay = max(0.0, 1 - ballFriction * dt);
    ballVx *= decay;
    ballVy *= decay;

    for (final p in players) {
      _playerHitsBall(p);
    }
    for (final k in keepers) {
      _circleHitsBall(k.x, k.y, keeperR, 0.9);
    }
    _wallsAndGoals();
  }

  int _botTurn(SoccerPlayer p) {
    // Aim at the ball; when behind it, circle round toward it anyway.
    final want = atan2(ballY - p.y, ballX - p.x);
    var diff = want - p.heading;
    while (diff > pi) {
      diff -= 2 * pi;
    }
    while (diff < -pi) {
      diff += 2 * pi;
    }
    // A touch of randomness keeps bots beatable.
    if (diff.abs() < 0.12) return 0;
    if (_random.nextDouble() < 0.06) return 0;
    return diff > 0 ? 1 : -1;
  }

  void _clampPlayer(SoccerPlayer p) {
    p.x = p.x.clamp(playerR, 1 - playerR);
    p.y = p.y.clamp(playerR, fieldH - playerR);
  }

  void _separatePlayers() {
    for (var i = 0; i < players.length; i++) {
      for (var j = i + 1; j < players.length; j++) {
        final a = players[i], b = players[j];
        final dx = b.x - a.x, dy = b.y - a.y;
        final d = sqrt(dx * dx + dy * dy);
        const minD = playerR * 2;
        if (d > 0 && d < minD) {
          final push = (minD - d) / 2;
          a.x -= dx / d * push;
          a.y -= dy / d * push;
          b.x += dx / d * push;
          b.y += dy / d * push;
          _clampPlayer(a);
          _clampPlayer(b);
        }
      }
    }
  }

  void _playerHitsBall(SoccerPlayer p) {
    final dx = ballX - p.x, dy = ballY - p.y;
    final d = sqrt(dx * dx + dy * dy);
    const minD = playerR + ballR;
    if (d >= minD || d == 0) return;
    final nx = dx / d, ny = dy / d;
    // Move the ball out of the player, then kick along the contact normal
    // plus the player's running direction.
    ballX = p.x + nx * minD;
    ballY = p.y + ny * minD;
    final head = cos(p.heading) * nx + sin(p.heading) * ny; // -1..1
    final power = 0.7 + 0.8 * max(0.0, head);
    ballVx = nx * power + cos(p.heading) * 0.25;
    ballVy = ny * power + sin(p.heading) * 0.25;
    _capBall();
  }

  void _circleHitsBall(double cx, double cy, double r, double bounce) {
    final dx = ballX - cx, dy = ballY - cy;
    final d = sqrt(dx * dx + dy * dy);
    final minD = r + ballR;
    if (d >= minD || d == 0) return;
    final nx = dx / d, ny = dy / d;
    ballX = cx + nx * minD;
    ballY = cy + ny * minD;
    final dot = ballVx * nx + ballVy * ny;
    if (dot < 0) {
      ballVx -= (1 + bounce) * dot * nx;
      ballVy -= (1 + bounce) * dot * ny;
    }
  }

  void _capBall() {
    final s = sqrt(ballVx * ballVx + ballVy * ballVy);
    if (s > maxBallSpeed) {
      ballVx *= maxBallSpeed / s;
      ballVy *= maxBallSpeed / s;
    }
  }

  void _wallsAndGoals() {
    final inMouth = (ballX - 0.5).abs() < goalHalfWidth - ballR * 0.5;
    // Side walls.
    if (ballX < ballR) {
      ballX = ballR;
      ballVx = ballVx.abs() * 0.8;
    } else if (ballX > 1 - ballR) {
      ballX = 1 - ballR;
      ballVx = -ballVx.abs() * 0.8;
    }
    // Top end: team 0 scores when the ball enters the top goal.
    if (ballY < ballR) {
      if (inMouth && ballY < -ballR) {
        _score(0);
        return;
      }
      if (!inMouth) {
        ballY = ballR;
        ballVy = ballVy.abs() * 0.8;
      }
    } else if (ballY > fieldH - ballR) {
      if (inMouth && ballY > fieldH + ballR) {
        _score(1);
        return;
      }
      if (!inMouth) {
        ballY = fieldH - ballR;
        ballVy = -ballVy.abs() * 0.8;
      }
    }
  }

  void _score(int team) {
    scores[team] += 1;
    lastScorer = team;
    goalPause = over ? 0 : 1.2;
    ballVx = 0;
    ballVy = 0;
    if (over) goalPause = 0;
  }
}

/// Tiny immutable point so the logic has no Flutter dependency.
class Offset2 {
  const Offset2(this.x, this.y);
  final double x;
  final double y;
}

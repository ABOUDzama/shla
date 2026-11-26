import 'dart:math';

/// Pure logic for فليك الشلة: a faithful clone of JindoBlu's "Flick Soccer"
/// (1234playergames.com: "Pull back one of your players and let go to flick
/// it at the ball. First to 3 goals wins."). Turn-based button football:
/// each player has one star disc guarding their goal; on your turn you drag
/// your disc back and release to flick it. Discs and the ball slide with
/// friction and bounce off the walls; the ball crossing a goal mouth scores
/// for the last flicker (unless it's their own goal - then no one scores and
/// play resets). The player who conceded kicks off. Original code.
class FlickBody {
  FlickBody(this.x, this.y, this.r);
  double x, y;
  double vx = 0, vy = 0;
  final double r;
  bool get moving => vx * vx + vy * vy > 0.05;
}

class FlickGoal {
  FlickGoal(this.cx, this.cy, this.halfWidth, this.nx, this.ny, this.owner);
  final double cx, cy; // mouth center on the field edge
  final double halfWidth;
  final double nx, ny; // inward normal of the goal line
  final int owner; // seat that defends this goal
}

class FlickSoccerMatch {
  FlickSoccerMatch({required this.seats, Random? random})
      : assert(seats >= 1 && seats <= 4),
        _random = random ?? Random() {
    _setup();
  }

  static const double fieldW = 100;
  static const double fieldH = 100;
  static const double discR = 6.5;
  static const double ballR = 4.0;
  static const double goalHalf = 14.0; // goal mouth half width
  static const double friction = 0.99; // per physics tick (120 Hz)
  static const double wallBounce = 0.7;
  static const double hitBounce = 0.92;
  static const double maxPull = 22.0; // max drag distance
  static const double flickPower = 9.5; // pull-to-velocity scale
  static const int goalsToWin = 3;
  static const int practiceFlicks = 10;

  final int seats;
  final Random _random;
  final List<FlickBody> discs = [];
  late FlickBody ball;
  final List<FlickGoal> goals = [];
  final List<int> scores = [];
  int currentSeat = 0;
  int lastFlicker = -1;
  int flicksUsed = 0;
  int? winnerSeat;
  bool practiceOver = false;
  bool _turnPending = false; // a flick happened; pass the turn when motion stops
  int practiceGoals = 0;

  bool get practice => seats == 1;
  bool get over => winnerSeat != null || practiceOver;
  int? get winner => practice ? null : winnerSeat;
  final Set<int> botSeats = {};
  bool get settled => !ball.moving && discs.every((d) => !d.moving);

  /// Goal/disc layout per seat count. Seat 0 defends the bottom goal.
  void _setup() {
    goals.clear();
    switch (seats) {
      case 1:
        goals.add(FlickGoal(50, 0, goalHalf, 0, 1, -1)); // top, unguarded
      case 2:
        goals.add(FlickGoal(50, 0, goalHalf, 0, 1, 1)); // top, seat 1
        goals.add(FlickGoal(50, 100, goalHalf, 0, -1, 0)); // bottom, seat 0
      case 3:
        goals.add(FlickGoal(25, 0, goalHalf * 0.8, 0, 1, 1)); // top-left
        goals.add(FlickGoal(75, 0, goalHalf * 0.8, 0, 1, 2)); // top-right
        goals.add(FlickGoal(50, 100, goalHalf, 0, -1, 0)); // bottom
      case 4:
        goals.add(FlickGoal(50, 0, goalHalf * 0.8, 0, 1, 2)); // top
        goals.add(FlickGoal(50, 100, goalHalf * 0.8, 0, -1, 0)); // bottom
        goals.add(FlickGoal(0, 50, goalHalf * 0.8, 1, 0, 3)); // left
        goals.add(FlickGoal(100, 50, goalHalf * 0.8, -1, 0, 1)); // right
    }
    for (var i = 0; i < seats; i++) {
      scores.add(0);
    }
    _kickoff(0);
  }

  /// Start positions: ball at center, each disc in front of its goal.
  void _kickoff(int firstSeat) {
    ball = FlickBody(50, 50, ballR);
    final spots = <List<double>>[
      [50, 78], // bottom guard (seat 0)
      [50, 22], // top guard (2P) / right-goal guard (4P seat 1)
      [25, 22], // top-left (3P seat 1) / top (4P seat 2)
      [75, 22], // top-right (3P seat 2) / left (4P seat 3)
    ];
    final spots4 = <List<double>>[
      [50, 78], [78, 50], [50, 22], [22, 50],
    ];
    final use = seats == 4 ? spots4 : spots;
    discs.clear();
    for (var i = 0; i < seats; i++) {
      discs.add(FlickBody(use[i][0], use[i][1], discR));
    }
    currentSeat = firstSeat;
  }

  /// Flick the current player's disc: [dx],[dy] is the drag vector from the
  /// disc (pull back); release launches the disc the opposite way.
  void flick(int seat, double dx, double dy) {
    if (over || seat != currentSeat || !settled) return;
    final len = sqrt(dx * dx + dy * dy);
    if (len < 2) return; // too small a pull, ignore
    final capped = min(len, maxPull);
    final d = discs[seat];
    d.vx = -dx / len * capped * flickPower / maxPull * 18;
    d.vy = -dy / len * capped * flickPower / maxPull * 18;
    lastFlicker = seat;
    flicksUsed++;
    _turnPending = true;
  }

  /// Advance the physics by one tick (call at a fixed 120 Hz).
  void step() {
    if (over) return;
    final bodies = [...discs, ball];
    for (final b in bodies) {
      b.x += b.vx / 120;
      b.y += b.vy / 120;
      b.vx *= friction;
      b.vy *= friction;
      if (b.vx.abs() < 0.02) b.vx = 0;
      if (b.vy.abs() < 0.02) b.vy = 0;
    }
    // walls, with goal mouths open
    for (final b in bodies) {
      _wall(b);
    }
    // circle collisions
    for (var i = 0; i < bodies.length; i++) {
      for (var j = i + 1; j < bodies.length; j++) {
        _collide(bodies[i], bodies[j]);
      }
    }
    final scored = _checkGoals();
    if (practice && flicksUsed >= practiceFlicks && settled) {
      practiceOver = true;
    }
    if (scored) return; // fresh kickoff is settled; don't skip the turn
    if (settled && _turnPending && !over) {
      _turnPending = false;
      _nextTurn();
    }
  }

  void _wall(FlickBody b) {
    // The ball may cross the line only through a goal mouth; discs never.
    var openTop = false, openBottom = false, openLeft = false, openRight = false;
    if (identical(b, ball)) {
      for (final g in goals) {
        if (g.ny != 0 && (b.x - g.cx).abs() < g.halfWidth) {
          if (g.cy == 0) {
            openTop = true;
          } else {
            openBottom = true;
          }
        } else if (g.nx != 0 && (b.y - g.cy).abs() < g.halfWidth) {
          if (g.cx == 0) {
            openLeft = true;
          } else {
            openRight = true;
          }
        }
      }
    }
    if (b.x < b.r && !openLeft) {
      b.x = b.r;
      b.vx = -b.vx * wallBounce;
    }
    if (b.x > 100 - b.r && !openRight) {
      b.x = 100 - b.r;
      b.vx = -b.vx * wallBounce;
    }
    if (b.y < b.r && !openTop) {
      b.y = b.r;
      b.vy = -b.vy * wallBounce;
    }
    if (b.y > 100 - b.r && !openBottom) {
      b.y = 100 - b.r;
      b.vy = -b.vy * wallBounce;
    }
  }

  void _collide(FlickBody a, FlickBody b) {
    final dx = b.x - a.x, dy = b.y - a.y;
    final dist = sqrt(dx * dx + dy * dy);
    final minD = a.r + b.r;
    if (dist <= 0 || dist >= minD) return;
    final nx = dx / dist, ny = dy / dist;
    // separate
    final overlap = (minD - dist) / 2;
    a.x -= nx * overlap;
    a.y -= ny * overlap;
    b.x += nx * overlap;
    b.y += ny * overlap;
    // equal-mass elastic response along the normal
    final dvn = (b.vx - a.vx) * nx + (b.vy - a.vy) * ny;
    if (dvn < 0) {
      final imp = -dvn * hitBounce;
      a.vx -= nx * imp;
      a.vy -= ny * imp;
      b.vx += nx * imp;
      b.vy += ny * imp;
    }
  }

  /// Returns true when a goal was scored and positions were reset.
  bool _checkGoals() {
    for (final g in goals) {
      final crossed = g.ny != 0
          ? (g.cy == 0 ? ball.y < 0 : ball.y > 100)
          : (g.cx == 0 ? ball.x < 0 : ball.x > 100);
      if (!crossed) continue;
      final inMouth = g.ny != 0
          ? (ball.x - g.cx).abs() < g.halfWidth
          : (ball.y - g.cy).abs() < g.halfWidth;
      if (!inMouth) continue;
      // goal! last flicker scores unless it is their own goal
      if (practice) {
        practiceGoals++;
      } else if (lastFlicker >= 0 && g.owner != lastFlicker) {
        scores[lastFlicker]++;
        if (scores[lastFlicker] >= goalsToWin) {
          winnerSeat = lastFlicker;
          return true;
        }
      }
      // conceder kicks off (seat 0 in practice)
      _kickoff(practice ? 0 : (g.owner >= 0 ? g.owner : 0));
      return true;
    }
    return false;
  }

  void _nextTurn() {
    if (practice || over) return;
    currentSeat = (currentSeat + 1) % seats;
  }

  /// Bot flick: aim at the ball, biased toward the nearest opponent goal.
  /// Returns the drag vector to pass to [flick].
  List<double> botAim(int seat) {
    final d = discs[seat];
    // nearest opponent goal
    FlickGoal? target;
    var best = double.infinity;
    for (final g in goals) {
      if (g.owner == seat) continue;
      final dd = (g.cx - d.x) * (g.cx - d.x) + (g.cy - d.y) * (g.cy - d.y);
      if (dd < best) {
        best = dd;
        target = g;
      }
    }
    target ??= FlickGoal(50, 50, goalHalf, 0, 1, -1);
    // aim: through the ball toward the target
    var tx = ball.x + (ball.x - target.cx) * -0.35;
    var ty = ball.y + (ball.y - target.cy) * -0.35;
    // noise by "skill"
    tx += (_random.nextDouble() - 0.5) * 14;
    ty += (_random.nextDouble() - 0.5) * 14;
    final dx = d.x - tx, dy = d.y - ty; // drag opposite the launch
    final len = sqrt(dx * dx + dy * dy);
    final pull = maxPull * (0.55 + _random.nextDouble() * 0.4);
    return [dx / len * pull, dy / len * pull];
  }
}

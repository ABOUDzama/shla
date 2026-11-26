import 'dart:math';

/// Pure logic for Shla Tank Battle (دبابات الشلة), rebuilt 2026-11-25 to
/// match the actual reference mechanics (grounded from Stickman Party Tanks
/// gameplay write-ups): tanks auto-drive forward, HOLDING your one button
/// steers (rotates) your tank, RELEASING fires one shell. Shells ricochet
/// off walls and obstacles. One hit destroys a tank; last tank standing
/// wins the round.
///
/// Kept separate from the widget so it can be unit-tested without pumping
/// frames. Fully deterministic with a seeded [Random].
class TankArena {
  const TankArena(this.obstacles);

  /// Obstacle rectangles in unit-square coordinates (x, y, w, h).
  final List<({double x, double y, double w, double h})> obstacles;

  /// Small fixed map rotation (reference cycles arenas; we pick by seed).
  static const List<TankArena> maps = [
    TankArena([
      (x: 0.40, y: 0.40, w: 0.20, h: 0.20), // central block
    ]),
    TankArena([
      (x: 0.20, y: 0.20, w: 0.12, h: 0.12),
      (x: 0.68, y: 0.20, w: 0.12, h: 0.12),
      (x: 0.68, y: 0.68, w: 0.12, h: 0.12),
      (x: 0.20, y: 0.68, w: 0.12, h: 0.12),
    ]),
    TankArena([
      (x: 0.44, y: 0.15, w: 0.12, h: 0.28), // plus-sign
      (x: 0.44, y: 0.57, w: 0.12, h: 0.28),
      (x: 0.15, y: 0.44, w: 0.28, h: 0.12),
      (x: 0.57, y: 0.44, w: 0.28, h: 0.12),
    ]),
  ];
}

class TankShell2 {
  TankShell2(this.x, this.y, this.dx, this.dy, this.owner);
  double x, y, dx, dy;
  final int owner;
  int bounces = 0;
  static const int maxBounces = 3;
}

class TankBattleMatch {
  TankBattleMatch({
    required this.playerCount,
    int? humanCount,
    Random? random,
  })  : assert(playerCount >= 1 && playerCount <= 4),
        humanCount = humanCount ?? playerCount,
        _random = random ?? Random() {
    arena = TankArena.maps[_random.nextInt(TankArena.maps.length)];
    for (var p = 0; p < playerCount; p++) {
      alive.add(true);
      holding.add(false);
      // corner spawns, headings toward center
      final (sx, sy, h) = spawnsFor(playerCount)[p];
      xs.add(sx);
      ys.add(sy);
      headings.add(h);
    }
  }

  final int playerCount;

  /// Players [0, humanCount) are human; the rest are bots steered by
  /// [tick] itself (deterministic under the same seed).
  final int humanCount;
  final Random _random;
  late final TankArena arena;

  /// Corner spawns per player count (each player owns a screen corner,
  /// like the reference). 2P uses diagonal corners, 3P leaves bottom-right
  /// free, 4P uses all four. Heading aims at the arena center.
  static List<(double, double, double)> spawnsFor(int playerCount) {
    switch (playerCount) {
      case 2:
        return [
          (0.08, 0.92, -pi / 4), // bottom-left -> up-right
          (0.92, 0.08, 3 * pi / 4), // top-right -> down-left
        ];
      case 3:
        return [
          (0.08, 0.08, pi / 4),
          (0.92, 0.08, 3 * pi / 4),
          (0.08, 0.92, -pi / 4),
        ];
      default:
        return [
          (0.08, 0.08, pi / 4),
          (0.92, 0.08, 3 * pi / 4),
          (0.92, 0.92, 5 * pi / 4),
          (0.08, 0.92, -pi / 4),
        ];
    }
  }

  static const double tankRadius = 0.06;
  static const double speed = 0.0035; // per tick
  static const double turnRate = pi / 60; // per held tick
  static const double shellSpeed = 0.012;
  static const double shellRadius = 0.012;
  // Ticker fires every 60ms (~16.7 ticks/s), so 1800 ticks ~= 108 seconds.
  static const int maxTicks = 60 * 30;
  static const int tickMillis = 60;

  final List<bool> alive = [];
  final List<bool> holding = [];
  final List<double> xs = [];
  final List<double> ys = [];
  final List<double> headings = [];
  final List<TankShell2> shells = [];

  /// Tick at which each tank was destroyed (for explosion animation).
  final Map<int, int> deathTick = {};

  int tickCount = 0;
  int? winner;

  int get aliveCount => alive.where((a) => a).length;

  /// Solo rounds are practice: no opponents, so no win/loss verdict.
  bool get practice => playerCount == 1;

  /// Seconds left before the safety cap ends the round.
  int get remainingSeconds =>
      ((maxTicks - tickCount) * tickMillis / 1000).ceil().clamp(0, 999);

  bool get isOver =>
      winner != null ||
      (!practice && aliveCount <= 1 && tickCount > 30) ||
      (practice && aliveCount == 0) ||
      tickCount >= maxTicks;

  bool _inObstacle(double x, double y, double pad) {
    for (final o in arena.obstacles) {
      if (x >= o.x - pad && x <= o.x + o.w + pad &&
          y >= o.y - pad && y <= o.y + o.h + pad) {
        return true;
      }
    }
    return false;
  }

  /// Hold the button: [player]'s tank steers (rotates) while held.
  void holdStart(int player) {
    if (isOver || !alive[player]) return;
    holding[player] = true;
  }

  /// Release the button: fires one shell if [player] is alive and has no
  /// live shell on the field (one shell at a time, like the reference).
  bool holdRelease(int player) {
    if (isOver || !alive[player]) return false;
    holding[player] = false;
    if (shells.any((s) => s.owner == player)) return false;
    final h = headings[player];
    shells.add(TankShell2(
      xs[player] + cos(h) * tankRadius * 1.4,
      ys[player] + sin(h) * tankRadius * 1.4,
      cos(h),
      sin(h),
      player,
    ));
    return true;
  }

  void _destroy(int p) {
    alive[p] = false;
    deathTick[p] = tickCount;
    // remove that player's shell so a re-round stays clean
    shells.removeWhere((s) => !alive[s.owner] && s.owner == p && false);
    if (aliveCount == 1) {
      winner = alive.indexOf(true);
    }
  }

  /// Very simple bot brain: steer toward the nearest living opponent,
  /// fire when roughly aimed. Steering is clockwise-only (one button),
  /// so bots hold until the target is within the aim cone. Deterministic
  /// jitter keeps matches varied under a fixed seed.
  void _botThink(int p) {
    var best = -1;
    var bestD = double.infinity;
    for (var q = 0; q < playerCount; q++) {
      if (q == p || !alive[q]) continue;
      final d = pow(xs[q] - xs[p], 2) + pow(ys[q] - ys[p], 2).toDouble();
      if (d < bestD) {
        bestD = d.toDouble();
        best = q;
      }
    }
    if (best < 0) {
      holding[p] = false;
      return;
    }
    final desired = atan2(ys[best] - ys[p], xs[best] - xs[p]);
    var diff = (desired - headings[p]) % (2 * pi);
    if (diff > pi) diff -= 2 * pi;
    if (diff < -pi) diff += 2 * pi;
    if (_random.nextDouble() < 0.02) {
      holding[p] = !holding[p];
      return;
    }
    if (diff > 0.15 || diff < -0.5) {
      holding[p] = true;
    } else {
      holding[p] = false;
      if (!shells.any((s) => s.owner == p)) holdRelease(p);
    }
  }

  void tick() {
    if (isOver) return;
    tickCount++;

    for (var p = humanCount; p < playerCount; p++) {
      if (alive[p]) _botThink(p);
    }

    // tanks: steer while held, always drive forward, slide on obstacles
    for (var p = 0; p < playerCount; p++) {
      if (!alive[p]) continue;
      if (holding[p]) headings[p] += turnRate;
      final h = headings[p];
      var nx = xs[p] + cos(h) * speed;
      var ny = ys[p] + sin(h) * speed;
      // border walls: turn the tank back inside (bounce heading)
      if (nx < tankRadius || nx > 1 - tankRadius) {
        headings[p] = pi - h;
        nx = xs[p] + cos(headings[p]) * speed;
      }
      if (ny < tankRadius || ny > 1 - tankRadius) {
        headings[p] = -headings[p];
        ny = ys[p] + sin(headings[p]) * speed;
      }
      // obstacles: stop at the edge (slide blocked)
      if (_inObstacle(nx, ny, tankRadius * 0.8)) {
        headings[p] += turnRate * 2; // grind around the block
      } else {
        xs[p] = nx.clamp(tankRadius, 1 - tankRadius);
        ys[p] = ny.clamp(tankRadius, 1 - tankRadius);
      }
    }

    // shells: move, ricochet off walls/obstacles, expire after maxBounces
    for (final s in List.of(shells)) {
      var nx = s.x + s.dx * shellSpeed;
      var ny = s.y + s.dy * shellSpeed;
      var bounced = false;
      if (nx < shellRadius || nx > 1 - shellRadius) {
        s.dx = -s.dx;
        bounced = true;
      }
      if (ny < shellRadius || ny > 1 - shellRadius) {
        s.dy = -s.dy;
        bounced = true;
      }
      if (_inObstacle(nx, ny, shellRadius)) {
        // reflect on the axis with deeper penetration
        final ox = s.x + s.dx * shellSpeed;
        if (_inObstacle(ox, s.y, shellRadius)) s.dx = -s.dx;
        final oy = s.y + s.dy * shellSpeed;
        if (_inObstacle(s.x, oy, shellRadius)) s.dy = -s.dy;
        bounced = true;
      }
      if (bounced) s.bounces++;
      if (s.bounces > TankShell2.maxBounces) {
        shells.remove(s);
        continue;
      }
      s.x += s.dx * shellSpeed;
      s.y += s.dy * shellSpeed;

      // hits: one shell destroys one tank (your own ricochet can kill you)
      for (var p = 0; p < playerCount; p++) {
        if (!alive[p]) continue;
        final d = sqrt(pow(xs[p] - s.x, 2) + pow(ys[p] - s.y, 2));
        if (d < tankRadius + shellRadius) {
          shells.remove(s);
          _destroy(p);
          break;
        }
      }
    }

    if (!practice && aliveCount == 1 && winner == null) {
      winner = alive.indexOf(true);
    }
  }
}

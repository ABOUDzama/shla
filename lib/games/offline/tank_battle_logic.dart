import 'dart:math';

/// Pure logic for Shla Tank Battle (دبابات الشلة), kept separate from the
/// widget so it can be unit-tested without pumping frames.
///
/// 2-4 tanks sit fixed at the arena edges. Each turret sweeps back and
/// forth on its own; a player taps ONE button to fire a shell along the
/// current aim. A shell that reaches another tank scores a point. First
/// to [targetScore] points wins.
class TankBattleMatch {
  TankBattleMatch({
    required this.playerCount,
    this.targetScore = 5,
    this.cooldownTicks = 6,
    Random? random,
  })  : assert(playerCount >= 2 && playerCount <= 4),
        _random = random ?? Random() {
    for (var p = 0; p < playerCount; p++) {
      scores.add(0);
      cooldowns.add(0);
      // stagger sweep phases so players are not in sync
      _aims.add(_aimMin + (_aimMax - _aimMin) * p / playerCount);
      _aimDirs.add(p.isEven ? 1 : -1);
    }
    // small deterministic jitter from the injected RNG for variety
    for (var p = 0; p < playerCount; p++) {
      _aims[p] += (_random.nextDouble() - 0.5) * 0.05;
    }
  }

  final int playerCount;
  final int targetScore;
  final int cooldownTicks;
  final Random _random;

  /// Tank anchor points in normalized arena coordinates (0..1), one per
  /// player: bottom, top, left, right.
  static const List<Point<double>> anchors = [
    Point(0.5, 0.92),
    Point(0.5, 0.08),
    Point(0.08, 0.5),
    Point(0.92, 0.5),
  ];

  /// Base direction each anchor fires from, in radians (pointing inward).
  static const List<double> baseAngles = [
    -pi / 2, // bottom fires up
    pi / 2, // top fires down
    0, // left fires right
    pi, // right fires left
  ];

  static const double _aimMin = -0.6; // sweep half-range around base angle
  static const double _aimMax = 0.6;
  static const double sweepStep = 0.035; // radians per tick
  static const double shellSpeed = 0.03; // arena fraction per tick
  static const double tankRadius = 0.05;

  final List<int> scores = [];
  final List<int> cooldowns = [];
  final List<double> _aims = [];
  final List<int> _aimDirs = [];

  /// Live shells: (x, y, dx, dy, owner).
  final List<({double x, double y, double dx, double dy, int owner})> shells =
      [];

  int tickCount = 0;
  int? winner;
  bool get isOver => winner != null;

  /// Current absolute aim angle for [player] (base + sweeping offset).
  double aimAngle(int player) => baseAngles[player] + _aims[player];

  /// Fire a shell for [player] if their cooldown is ready. Returns true
  /// when a shell was actually launched.
  bool fire(int player) {
    if (isOver || cooldowns[player] > 0) return false;
    final a = aimAngle(player);
    final anchor = anchors[player];
    shells.add((
      x: anchor.x + cos(a) * tankRadius,
      y: anchor.y + sin(a) * tankRadius,
      dx: cos(a) * shellSpeed,
      dy: sin(a) * shellSpeed,
      owner: player,
    ));
    cooldowns[player] = cooldownTicks;
    return true;
  }

  /// Advance one tick: sweep turrets, move shells, resolve hits.
  void tick() {
    if (isOver) return;
    tickCount++;
    for (var p = 0; p < playerCount; p++) {
      if (cooldowns[p] > 0) cooldowns[p]--;
      _aims[p] += sweepStep * _aimDirs[p];
      if (_aims[p] > _aimMax) {
        _aims[p] = _aimMax;
        _aimDirs[p] = -1;
      } else if (_aims[p] < _aimMin) {
        _aims[p] = _aimMin;
        _aimDirs[p] = 1;
      }
    }
    final dead = <int>{};
    for (var i = 0; i < shells.length; i++) {
      final s = shells[i];
      final nx = s.x + s.dx;
      final ny = s.y + s.dy;
      if (nx < 0 || nx > 1 || ny < 0 || ny > 1) {
        dead.add(i);
        continue;
      }
      for (var p = 0; p < playerCount; p++) {
        if (p == s.owner) continue;
        final a = anchors[p];
        final d = sqrt(pow(nx - a.x, 2) + pow(ny - a.y, 2));
        if (d <= tankRadius) {
          scores[s.owner]++;
          dead.add(i);
          if (scores[s.owner] >= targetScore) winner = s.owner;
          break;
        }
      }
      shells[i] = (
        x: nx,
        y: ny,
        dx: s.dx,
        dy: s.dy,
        owner: s.owner,
      );
    }
    if (dead.isNotEmpty) {
      shells.removeWhere((s) => dead.contains(shells.indexOf(s)));
    }
  }
}

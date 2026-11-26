import 'dart:math';

/// Pure logic for Shla Snow Brawl (معركة التلج), kept separate from the
/// widget so it can be unit-tested without pumping frames.
///
/// 2-4 forts, one per player. A power meter sweeps on its own; a tap
/// throws a snowball at the next standing fort clockwise. The throw lands
/// only when the power matches the distance (with a seeded wind offset).
/// Each fort has [fortHp] hit points; last fort standing wins.
class SnowBrawlMatch {
  SnowBrawlMatch({
    required this.playerCount,
    this.fortHp = 3,
    Random? random,
  })  : assert(playerCount >= 1 && playerCount <= 4),
        _random = random ?? Random() {
    for (var p = 0; p < playerCount; p++) {
      hp.add(fortHp);
      throws.add(0);
      hits.add(0);
    }
    _rollWind();
  }

  final int playerCount;
  final int fortHp;
  final Random _random;

  final List<int> hp = [];
  final List<int> throws = [];
  final List<int> hits = [];

  bool alive(int p) => hp[p] > 0;
  int get aliveCount => hp.where((h) => h > 0).length;

  /// Power meter phase in [0,1]; sweeps up and down.
  double phase = 0;
  int _phaseDir = 1;
  static const double phaseStep = 0.025;

  /// Required power for the current target plus wind, in [0.2, 0.95].
  double neededPower = 0.6;
  static const double tolerance = 0.09;

  /// Seats thrown by the built-in bot (mostly well-powered throws).
  final Set<int> botSeats = {};

  /// Solo practice: 10 throws at a target dummy, then the round ends.
  static const int practiceThrows = 10;

  int tickCount = 0;
  int? winner;
  bool get isOver {
    if (playerCount == 1) return throws.isNotEmpty && throws[0] >= practiceThrows;
    return winner != null || aliveCount <= 1;
  }

  void _rollWind() {
    neededPower = 0.2 + _random.nextDouble() * 0.75;
  }

  /// Next standing fort clockwise from [player].
  int targetOf(int player) {
    for (var step = 1; step < playerCount; step++) {
      final t = (player + step) % playerCount;
      if (alive(t)) return t;
    }
    return player;
  }

  void tick() {
    if (isOver) return;
    tickCount++;
    phase += phaseStep * _phaseDir;
    if (phase >= 1) {
      phase = 1;
      _phaseDir = -1;
    } else if (phase <= 0) {
      phase = 0;
      _phaseDir = 1;
    }
    // bots throw when the meter is near the needed power
    for (final p in botSeats) {
      if (p >= playerCount || !alive(p)) continue;
      if ((phase - neededPower).abs() <= tolerance * 0.75 &&
          _random.nextDouble() < 0.8) {
        throwSnowball(p);
      }
    }
  }

  /// Throw for [player] at the current power. Returns true on a hit.
  bool throwSnowball(int player) {
    if (isOver || !alive(player)) return false;
    throws[player]++;
    if (playerCount == 1) {
      // practice: a target dummy, no fort damage
      final hit = (phase - neededPower).abs() <= tolerance;
      if (hit) hits[player]++;
      _rollWind();
      return hit;
    }
    final target = targetOf(player);
    final hit = (phase - neededPower).abs() <= tolerance;
    if (hit) {
      hits[player]++;
      hp[target]--;
      if (aliveCount <= 1) {
        winner = hp.indexWhere((h) => h > 0);
      }
    }
    _rollWind();
    return hit;
  }
}

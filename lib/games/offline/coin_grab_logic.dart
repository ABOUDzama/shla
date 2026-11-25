import 'dart:math';

/// Pure logic for لمّ الفلوس (Coin Grab). Core idea is unchanged: every
/// player owns a claw in a screen corner, the claw moves by itself, one tap
/// grabs a coin if the claw tip is on it. Defect fixed in this version: the
/// old claw only spun on a tiny circle around its corner, so most coins were
/// unreachable and a match could never end (probe: 20/20 seeded matches stuck
/// even with infinite taps). Now the claw sweeps its angle AND stretches in
/// and out, so every coin is reachable, and a 60 second clock ends the match.
class CoinGrabCoin {
  CoinGrabCoin(this.x, this.y, this.value);
  final double x, y;
  final int value;
}

class CoinGrabMatch {
  CoinGrabMatch({required this.seats, this.coinCount = 20, Random? random})
      : assert(seats >= 1 && seats <= 4),
        _random = random ?? Random() {
    scores = List.filled(seats, 0);
    grabbed = List.filled(seats, 0);
    cooldown = List.filled(seats, 0.0);
    _spawn();
  }

  static const double arenaH = 1.4;
  static const double reach = 0.09;
  static const double matchSeconds = 60;
  static const double cooldownSeconds = 0.35;
  static const bases = [
    [0.09, arenaH - 0.09],
    [0.91, 0.09],
    [0.91, arenaH - 0.09],
    [0.09, 0.09],
  ];

  final int seats;
  final int coinCount;
  final Random _random;
  final Set<int> botSeats = {};
  late List<int> scores, grabbed;
  late List<double> cooldown;
  final List<CoinGrabCoin> coins = [];
  double time = 0;
  ({int seat, int value, double x, double y, double ttl})? lastGrab;

  double get timeLeft => max(0, matchSeconds - time);
  bool get over => coins.isEmpty || time >= matchSeconds;
  bool get practice => seats == 1;

  void _spawn() {
    while (coins.length < coinCount) {
      final x = 0.1 + _random.nextDouble() * 0.8;
      final y = 0.1 + _random.nextDouble() * (arenaH - 0.2);
      var nearBase = false;
      for (final b in bases) {
        if ((x - b[0]) * (x - b[0]) + (y - b[1]) * (y - b[1]) < 0.2 * 0.2) nearBase = true;
      }
      if (nearBase) continue;
      final roll = _random.nextDouble();
      coins.add(CoinGrabCoin(x, y, roll < 0.6 ? 1 : (roll < 0.9 ? 5 : 10)));
    }
  }

  /// Claw tip of [seat] at time [t]: angle sweeps the inward quarter circle,
  /// length stretches between 0.12 and 1.5 (reaches the far corner).
  ({double x, double y}) tipAt(int seat, double t) {
    final b = bases[seat];
    final toCentre = atan2(arenaH / 2 - b[1], 0.5 - b[0]);
    final a = toCentre + (pi / 2.2) * sin(2 * pi * t / 2.6 + seat * 1.1);
    final r = 0.81 + 0.69 * sin(2 * pi * t / 3.4 + seat * 2.1 - pi / 2);
    // keep the tip on screen (clamped); coins are inside the clamp box so
    // every coin is still hit by the unclamped part of the ray
    return (
      x: (b[0] + r * cos(a)).clamp(0.04, 0.96).toDouble(),
      y: (b[1] + r * sin(a)).clamp(0.04, arenaH - 0.04).toDouble(),
    );
  }

  ({double x, double y}) tip(int seat) => tipAt(seat, time);

  /// Returns the coin value taken, 0 on a miss, -1 when blocked.
  int grab(int seat) {
    if (over || cooldown[seat] > 0) return -1;
    cooldown[seat] = cooldownSeconds;
    final t = tip(seat);
    CoinGrabCoin? best;
    var bd = reach;
    for (final c in coins) {
      final d = sqrt(pow(c.x - t.x, 2) + pow(c.y - t.y, 2));
      if (d <= bd) {
        bd = d.toDouble();
        best = c;
      }
    }
    if (best == null) return 0;
    coins.remove(best);
    scores[seat] += best.value;
    grabbed[seat]++;
    lastGrab = (seat: seat, value: best.value, x: best.x, y: best.y, ttl: 0.6);
    return best.value;
  }

  void step(double dt) {
    if (over) return;
    time += dt;
    final lg = lastGrab;
    if (lg != null) {
      lastGrab = lg.ttl - dt <= 0
          ? null
          : (seat: lg.seat, value: lg.value, x: lg.x, y: lg.y, ttl: lg.ttl - dt);
    }
    for (var i = 0; i < seats; i++) {
      cooldown[i] = max(0, cooldown[i] - dt);
      if (botSeats.contains(i) && cooldown[i] <= 0) {
        final t = tip(i);
        final on = coins.any((c) => sqrt(pow(c.x - t.x, 2) + pow(c.y - t.y, 2)) < reach * 0.8);
        if (on && _random.nextDouble() < 0.3) grab(i);
      }
    }
  }

  /// Seat index of the richest stash, null on a tie for first or practice.
  int? get winner {
    if (!over || seats == 1) return null;
    final best = scores.reduce(max);
    final tops = [for (var i = 0; i < seats; i++) if (scores[i] == best) i];
    return tops.length == 1 ? tops.first : null;
  }
}

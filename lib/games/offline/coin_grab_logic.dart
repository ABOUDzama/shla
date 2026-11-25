import 'dart:math';

/// Pure logic for Shla Coin Grab (لمّ الفلوس), kept separate from the
/// widget so it can be unit-tested without pumping frames.
///
/// 2-4 players share one arena. Coins spawn at seeded positions with
/// values (bronze 1, silver 5, gold 10). Each player has a claw arm that
/// rotates around their own base corner; a tap grabs any coin within
/// reach of the arm tip. When the pile is empty the richest stash wins.
class CoinGrabPoint {
  const CoinGrabPoint(this.x, this.y);
  final double x;
  final double y;
}

class CoinGrabCoin {
  CoinGrabCoin(this.x, this.y, this.value);
  final double x;
  final double y;
  final int value;
}

class CoinGrabMatch {
  CoinGrabMatch({
    required this.playerCount,
    this.coinCount = 24,
    Random? random,
  })  : assert(playerCount >= 2 && playerCount <= 4),
        _random = random ?? Random() {
    for (var p = 0; p < playerCount; p++) {
      scores.add(0);
      grabbed.add(0);
      armAngles.add(_startAngle(p));
    }
    _spawnCoins();
  }

  final int playerCount;
  final int coinCount;
  final Random _random;

  final List<CoinGrabCoin> coins = [];
  final List<int> scores = [];
  final List<int> grabbed = [];
  final List<double> armAngles = [];

  int tickCount = 0;
  bool get isOver => coins.isEmpty;

  /// Arena is the unit square; bases sit in corners used by players.
  static const List<CoinGrabPoint> _bases = [
    CoinGrabPoint(0.12, 0.12),
    CoinGrabPoint(0.88, 0.12),
    CoinGrabPoint(0.88, 0.88),
    CoinGrabPoint(0.12, 0.88),
  ];
  CoinGrabPoint baseOf(int p) => _bases[p];

  /// Arm sweep: each arm spins around its base at a fixed radius.
  static const double armRadius = 0.16;
  static const double armSpeed = pi / 45; // per tick
  static const double grabReach = 0.09;

  /// Different start angle per player so arms never stack.
  double _startAngle(int p) => p * (pi / 2) + pi / 4;

  void _spawnCoins() {
    for (var i = 0; i < coinCount; i++) {
      // keep clear of the corners where bases live
      final x = 0.18 + _random.nextDouble() * 0.64;
      final y = 0.18 + _random.nextDouble() * 0.64;
      final roll = _random.nextDouble();
      final value = roll < 0.6 ? 1 : (roll < 0.9 ? 5 : 10);
      coins.add(CoinGrabCoin(x, y, value));
    }
  }

  CoinGrabPoint armTipOf(int p) {
    final b = baseOf(p);
    return CoinGrabPoint(
      b.x + armRadius * cos(armAngles[p]),
      b.y + armRadius * sin(armAngles[p]),
    );
  }

  void tick() {
    if (isOver) return;
    tickCount++;
    for (var p = 0; p < playerCount; p++) {
      armAngles[p] += armSpeed * (p.isEven ? 1 : -1);
    }
  }

  /// Grab with [player]'s arm. Returns the coin value taken, 0 on a miss.
  int grab(int p) {
    if (isOver) return 0;
    final tip = armTipOf(p);
    CoinGrabCoin? best;
    var bestDist = grabReach;
    for (final c in coins) {
      final d = sqrt(pow(c.x - tip.x, 2) + pow(c.y - tip.y, 2));
      if (d <= bestDist) {
        bestDist = d.toDouble();
        best = c;
      }
    }
    if (best == null) return 0;
    coins.remove(best);
    scores[p] += best.value;
    grabbed[p]++;
    return best.value;
  }

  /// Winner index, or null on a tie for first place.
  int? winner() {
    if (!isOver) return null;
    var top = -1;
    var winners = <int>[];
    for (var p = 0; p < playerCount; p++) {
      if (scores[p] > top) {
        top = scores[p];
        winners = [p];
      } else if (scores[p] == top) {
        winners.add(p);
      }
    }
    return winners.length == 1 ? winners.first : null;
  }
}

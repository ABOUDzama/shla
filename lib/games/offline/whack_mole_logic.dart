import 'dart:math';

/// Pure logic for Shla Whack-a-Mole (اضرب الخلد), kept separate from the
/// widget so it can be unit-tested without pumping frames.
///
/// 1-4 players (1 = practice), each owns a 2x2 grid of holes in their quadrant. Moles
/// pop up on a seeded schedule and stay for [moleUpTicks]; whacking an
/// up mole in YOUR grid scores a point and a small speed-up (that mole
/// pops down early). Most hits when the round timer ends wins; a tie for
/// first has no winner.
class WhackMoleMatch {
  WhackMoleMatch({
    required this.playerCount,
    this.roundTicks = 750, // ~45s at 60ms ticks
    this.moleUpTicks = 26,
    Random? random,
  })  : assert(playerCount >= 1 && playerCount <= 4),
        _random = random ?? Random() {
    for (var p = 0; p < playerCount; p++) {
      scores.add(0);
      for (var h = 0; h < holesPerPlayer; h++) {
        _moles.add(null);
      }
    }
    for (var p = 0; p < playerCount; p++) {
      _nextPopAt.add(0);
      _scheduleNext(p, 0);
    }
  }

  final int playerCount;
  final int roundTicks;
  final int moleUpTicks;
  final Random _random;

  static const int holesPerPlayer = 4;

  final List<int> scores = [];

  /// Remaining up-ticks per hole, indexed player * holesPerPlayer + hole;
  /// null means no mole.
  final List<int?> _moles = [];

  int tickCount = 0;
  /// Each player has their own pop schedule at the same rate, so the
  /// number of moles is equal for everyone (it used to be one global
  /// schedule spread over all grids, which left each grid mostly empty).
  final List<int> _nextPopAt = [];
  final Set<int> botSeats = {};
  final List<int> _upFor = List.filled(16, 0);

  bool get isOver => tickCount >= roundTicks;

  int _index(int player, int hole) => player * holesPerPlayer + hole;

  bool isUp(int player, int hole) {
    final left = _moles[_index(player, hole)];
    return left != null && left > 0;
  }

  void _scheduleNext(int p, int fromTick) {
    _nextPopAt[p] = fromTick + 6 + _random.nextInt(10);
  }

  void tick() {
    if (isOver) return;
    tickCount++;
    for (var i = 0; i < _moles.length; i++) {
      final left = _moles[i];
      if (left != null) {
        _moles[i] = left - 1;
        if (_moles[i] == 0) _moles[i] = null;
      }
    }
    for (var p = 0; p < playerCount; p++) {
      if (tickCount >= _nextPopAt[p]) {
        for (var tries = 0; tries < 6; tries++) {
          final h = _random.nextInt(holesPerPlayer);
          if (!isUp(p, h)) {
            _moles[_index(p, h)] = moleUpTicks;
            _upFor[_index(p, h)] = 0;
            break;
          }
        }
        _scheduleNext(p, tickCount);
      }
      if (botSeats.contains(p)) {
        for (var h = 0; h < holesPerPlayer; h++) {
          if (isUp(p, h)) {
            _upFor[_index(p, h)]++;
            if (_upFor[_index(p, h)] >= 6 && _random.nextDouble() < 0.045) {
              whack(p, h);
            }
          }
        }
      }
    }
  }

  /// Whack [hole] in [player]'s grid. True and a point when a mole was up.
  bool whack(int player, int hole) {
    if (isOver) return false;
    if (isUp(player, hole)) {
      _moles[_index(player, hole)] = null;
      scores[player]++;
      return true;
    }
    return false;
  }

  /// Winner index, or null on a tie for first place.
  int? winner() {
    if (!isOver || playerCount == 1) return null;
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

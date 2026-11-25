import 'dart:math';

/// Pure logic for جري الفراخ (Chicken Run-style gravity runner, one touch).
///
/// Every seat is a chicken running along its own strip. A strip has a floor
/// and a ceiling, both with holes that scroll past. One tap flips gravity:
/// the chicken flies to the other surface (flight takes [flipTime]) and can
/// only flip again once it has landed. Standing on, or landing in, a hole
/// means falling out. Last chicken running wins; if the last ones fall in
/// the same tick it is a draw. All seats share the same hole pattern.
class Hole {
  Hole(this.surface, this.start, this.end);
  final int surface; // 0 floor, 1 ceiling
  final double start, end;
}

class ChickenRunMatch {
  ChickenRunMatch({required this.seats, Random? random})
      : assert(seats >= 1 && seats <= 4),
        _random = random ?? Random() {
    surface = List.filled(seats, 0);
    flightLeft = List.filled(seats, 0.0);
    target = List.filled(seats, 0);
    alive = List.filled(seats, true);
    survived = List.filled(seats, 0.0);
    _lastEnd = 1.1;
    _extendHoles(4);
  }

  static const double flipTime = 0.28;
  static const double chickenX = 0.3; // chicken offset inside the window
  static const double holeMargin = 0.02;
  static const double maxSpeed = 0.62;

  final int seats;
  final Random _random;
  final Set<int> botSeats = {};
  final List<Hole> holes = [];
  late List<int> surface;
  late List<double> flightLeft;
  late List<int> target;
  late List<bool> alive;
  late List<double> survived;
  double scroll = 0;
  double time = 0;
  double _lastEnd = 1.1;
  final Set<int> _botMissed = {};
  final Set<int> _botSeen = {};
  int? _lastFell;
  bool _drawAtEnd = false;

  double get speed => min(maxSpeed, 0.34 + 0.009 * time);
  bool get practice => seats == 1;
  int get aliveCount => alive.where((a) => a).length;

  bool get over => seats == 1 ? !alive[0] : aliveCount <= 1;

  /// Winning seat, or null (draw / still playing / practice).
  int? get winner {
    if (!over || seats == 1) return null;
    if (_drawAtEnd) return null;
    final i = alive.indexOf(true);
    return i < 0 ? null : i;
  }

  void _extendHoles(int minAhead) {
    while (holes.length < minAhead || _lastEnd < scroll + 3.0) {
      final start = _lastEnd + maxSpeed * flipTime + 0.14 + _random.nextDouble() * 0.30;
      final end = start + 0.22 + _random.nextDouble() * 0.12;
      holes.add(Hole(_random.nextInt(2), start, end));
      _lastEnd = end;
      if (holes.length > 60 && holes.first.end < scroll - 1) holes.removeAt(0);
    }
  }

  bool holeAt(int surf, double wx) {
    for (final h in holes) {
      if (h.surface == surf && wx > h.start + holeMargin && wx < h.end - holeMargin) {
        return true;
      }
    }
    return false;
  }

  /// Next hole (start, end) on [surf] whose end is still ahead of [wx].
  Hole? nextHole(int surf, double wx) {
    for (final h in holes) {
      if (h.surface == surf && h.end > wx) return h;
    }
    return null;
  }

  /// A tap from [seat]. Returns true when it started a flip.
  bool flip(int seat) {
    if (over || !alive[seat] || flightLeft[seat] > 0) return false;
    target[seat] = 1 - surface[seat];
    flightLeft[seat] = flipTime;
    return true;
  }

  void step(double dt) {
    if (over) return;
    time += dt;
    scroll += speed * dt;
    _extendHoles(4);
    final cx = scroll + chickenX;
    final fell = <int>[];
    for (var i = 0; i < seats; i++) {
      if (!alive[i]) continue;
      if (botSeats.contains(i)) _bot(i, cx);
      if (flightLeft[i] > 0) {
        flightLeft[i] -= dt;
        if (flightLeft[i] <= 0) {
          flightLeft[i] = 0;
          surface[i] = target[i];
          if (holeAt(surface[i], cx)) fell.add(i);
        }
      } else if (holeAt(surface[i], cx)) {
        fell.add(i);
      }
      if (!fell.contains(i)) survived[i] = time;
    }
    final before = aliveCount;
    for (final i in fell) {
      alive[i] = false;
    }
    if (fell.isNotEmpty && aliveCount == 0 && before > 1) _drawAtEnd = true;
    // Everyone falling together from a multi-seat match is a draw; a lone
    // survivor falling (aliveCount 0 from 1) in a multi match cannot happen
    // because the match is already over at one survivor.
  }

  void _bot(int i, double cx) {
    if (flightLeft[i] > 0) return;
    final h = nextHole(surface[i], cx);
    if (h == null) return;
    final dist = h.start + holeMargin - cx;
    final need = speed * flipTime;
    final key = holes.indexOf(h) * 8 + i;
    if (dist < 0) return;
    if (dist < need + 0.10 + 0.05 * (i % 3) && dist > need + 0.02) {
      // Decide once per hole: bots misjudge some holes (more as it speeds
      // up), so humans can beat them.
      if (_botSeen.add(key) && _random.nextDouble() < 0.07 + 0.25 * (speed - 0.34)) {
        _botMissed.add(key);
      }
      if (_botMissed.contains(key)) return;
      flip(i);
    }
  }

  /// Ranking helper: seats ordered by survival time, best first.
  List<int> get ranking {
    final o = List<int>.generate(seats, (i) => i);
    o.sort((a, b) => survived[b].compareTo(survived[a]));
    return o;
  }
}

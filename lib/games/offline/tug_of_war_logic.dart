import 'dart:math';

/// Pure logic for Shla Tug of War (شد الحبل), kept separate from the
/// widget so it can be unit-tested without pumping frames.
///
/// 2-4 players share one phone. A marker sweeps across a timing bar;
/// tapping your button when the marker sits in the green center pulls the
/// knot toward your anchor. Sloppy timing barely helps; the knot drifts
/// back to center, so only well-timed pulls win. First player to drag the
/// knot past their edge takes the round.
class TugMatch {
  TugMatch({required this.playerCount, Random? random})
      : assert(playerCount >= 2 && playerCount <= 4),
        _random = random ?? Random();

  final int playerCount;
  final Random _random;

  /// Pull directions in normalized space, one per player: left, right,
  /// up, down.
  static const List<Point<double>> pullDirs = [
    Point(-1.0, 0.0),
    Point(1.0, 0.0),
    Point(0.0, -1.0),
    Point(0.0, 1.0),
  ];

  /// Knot position relative to center; a component reaching ±1 wins.
  double _kx = 0, _ky = 0;
  double get kx => _kx;
  double get ky => _ky;

  /// Timing marker phase in [0,1); the green zone sits at 0.5.
  double phase = 0;
  int _phaseDir = 1;
  static const double phaseStep = 0.02;

  /// Grading zones around 0.5: perfect within ±0.06, ok within ±0.16.
  static const double perfectWindow = 0.06;
  static const double okWindow = 0.16;
  static const double perfectPull = 0.09;
  static const double okPull = 0.03;
  static const double centerDrift = 0.004;

  int tickCount = 0;
  int? winner;
  bool get isOver => winner != null;

  final List<int> perfects = [];
  final List<int> misses = [];
  void _initStats() {
    if (perfects.length < playerCount) {
      for (var i = perfects.length; i < playerCount; i++) {
        perfects.add(0);
        misses.add(0);
      }
    }
  }

  /// Advance the timing marker.
  void tick() {
    if (isOver) return;
    _initStats();
    tickCount++;
    phase += phaseStep * _phaseDir;
    if (phase >= 1) {
      phase = 1;
      _phaseDir = -1;
    } else if (phase <= 0) {
      phase = 0;
      _phaseDir = 1;
    }
    // knot drifts toward center
    _kx -= _kx.sign * min(centerDrift, _kx.abs());
    _ky -= _ky.sign * min(centerDrift, _ky.abs());
  }

  /// Grade and apply a tap for [player]. Returns 'perfect', 'ok', 'miss'.
  String tap(int player) {
    if (isOver) return 'miss';
    _initStats();
    final d = (phase - 0.5).abs();
    final dir = pullDirs[player];
    if (d <= perfectWindow) {
      perfects[player]++;
      _kx += dir.x * perfectPull;
      _ky += dir.y * perfectPull;
      // small seeded wobble keeps replays varied without affecting grading
      _kx += (_random.nextDouble() - 0.5) * 0.004;
      _checkWin();
      return 'perfect';
    } else if (d <= okWindow) {
      _kx += dir.x * okPull;
      _ky += dir.y * okPull;
      _checkWin();
      return 'ok';
    }
    misses[player]++;
    return 'miss';
  }

  void _checkWin() {
    for (var p = 0; p < playerCount; p++) {
      final dir = pullDirs[p];
      if ((dir.x != 0 && (_kx * dir.x) >= 1) ||
          (dir.y != 0 && (_ky * dir.y) >= 1)) {
        winner = p;
      }
    }
  }
}

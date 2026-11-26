import 'dart:math';

/// وحش المدار — orbit-dodge survival as a pure, testable simulation.
/// The monster rides two concentric orbits around its planet; meteors rain
/// inward. Tap to hop between orbits. Survive the longest; turn-based per
/// seat with a seeded meteor stream.
class OrbitRun {
  OrbitRun({Random? random}) : _random = random ?? Random();

  final Random _random;

  static const double innerR = 70;
  static const double outerR = 120;
  static const double angularSpeed = 1.9; // rad/s
  static const double meteorSpeed = 55; // px/s inward
  static const double hitAngle = 0.22; // collision cone half-width

  double angle = 0; // monster position on its orbit
  int ring = 0; // 0 = inner, 1 = outer
  double time = 0;
  bool crashed = false;
  int dodged = 0;

  double get ringRadius => ring == 0 ? innerR : outerR;

  /// Meteors: (angle, radius).
  final List<(double, double)> meteors = [];
  double _nextSpawn = 1.2;

  /// Hop between the two orbits.
  void hop() {
    if (crashed) return;
    ring = 1 - ring;
  }

  void step(double dt) {
    if (crashed) return;
    time += dt;
    angle = (angle + angularSpeed * dt) % (2 * pi);

    _nextSpawn -= dt;
    if (_nextSpawn <= 0) {
      meteors.add((_random.nextDouble() * 2 * pi, 200));
      _nextSpawn = 1.0 + _random.nextDouble() * 1.1;
    }

    for (var i = meteors.length - 1; i >= 0; i--) {
      final (ma, mr) = meteors[i];
      final nr = mr - meteorSpeed * dt;
      if (nr < 30) {
        meteors.removeAt(i); // absorbed by the planet
        continue;
      }
      meteors[i] = (ma, nr);
      // Collision: meteor crossing the monster's ring at its angle.
      if ((nr - ringRadius).abs() < meteorSpeed * dt + 6) {
        var d = (ma - angle).abs() % (2 * pi);
        if (d > pi) d = 2 * pi - d;
        if (d < hitAngle) {
          crashed = true;
          return;
        }
        if (nr < ringRadius - 10) dodged++;
      }
    }
  }

  static double _angDiff(double a, double b) {
    var d = (a - b).abs() % (2 * pi);
    return d > pi ? 2 * pi - d : d;
  }

  /// Predictive bot: will a meteor cross [targetRing] where the monster
  /// will be when it gets there?
  bool _ringWillBeHit(int targetRing) {
    final rr = targetRing == 0 ? innerR : outerR;
    for (final (ma, mr) in meteors) {
      final t = (mr - rr) / meteorSpeed;
      if (t < -0.15) continue; // already fully past the ring
      final futureAngle = (angle + angularSpeed * t) % (2 * pi);
      // Cone widened for the monster's sweep during the crossing band.
      if (_angDiff(ma, futureAngle) < hitAngle + 0.3) return true;
    }
    return false;
  }

  /// Bot: hop only when the current ring is doomed and the other is safe.
  bool botShouldHop() {
    if (crashed) return false;
    // Act late enough that the dodge actually changes the outcome.
    for (final (ma, mr) in meteors) {
      final t = (mr - ringRadius) / meteorSpeed;
      if (t > -0.15 && t < 0.55) {
        final futureAngle = (angle + angularSpeed * t) % (2 * pi);
        if (_angDiff(ma, futureAngle) < hitAngle + 0.3 &&
            !_ringWillBeHit(1 - ring)) {
          return true;
        }
      }
    }
    return false;
  }
}

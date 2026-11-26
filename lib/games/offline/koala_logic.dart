import 'dart:math';

/// كوالا الفضاء — koala-with-a-laser survival shooter as a pure, testable
/// simulation. The koala's ship patrols left and right on its own; tap to
/// fire. Meteors rain down on a seeded stream; one hit on the ship ends
/// the run. Turn-based per seat, most hits wins.
class KoalaRun {
  KoalaRun({Random? random}) : _random = random ?? Random();

  final Random _random;

  static const double worldWidth = 360;
  static const double worldHeight = 560;
  static const double shipY = 500;
  static const double shipHalfW = 22;
  static const double shipSpeed = 95;
  static const double laserSpeed = 520;
  static const double meteorR = 16;

  double shipX = worldWidth / 2;
  int shipDir = 1;
  double time = 0;
  int hits = 0;
  bool crashed = false;

  /// Lasers: (x, y) climbing.
  final List<(double, double)> lasers = [];

  /// Meteors: (x, y, vy).
  final List<(double, double, double)> meteors = [];
  double _nextSpawn = 0.8;
  double _cooldown = 0;

  /// Fire a laser from the ship (0.35s cooldown).
  void fire() {
    if (crashed || _cooldown > 0) return;
    lasers.add((shipX, shipY - 14));
    _cooldown = 0.35;
  }

  void step(double dt) {
    if (crashed) return;
    time += dt;
    if (_cooldown > 0) _cooldown -= dt;

    // Ship patrol.
    shipX += shipDir * shipSpeed * dt;
    if (shipX < shipHalfW) {
      shipX = shipHalfW;
      shipDir = 1;
    } else if (shipX > worldWidth - shipHalfW) {
      shipX = worldWidth - shipHalfW;
      shipDir = -1;
    }

    // Lasers climb, expire at the top.
    for (var i = lasers.length - 1; i >= 0; i--) {
      final (lx, ly) = lasers[i];
      final ny = ly - laserSpeed * dt;
      if (ny < -10) {
        lasers.removeAt(i);
      } else {
        lasers[i] = (lx, ny);
      }
    }

    // Meteor spawns get denser over time.
    _nextSpawn -= dt;
    if (_nextSpawn <= 0) {
      meteors.add((_random.nextDouble() * (worldWidth - 40) + 20, -meteorR,
          70 + _random.nextDouble() * 60 + time * 1.2));
      _nextSpawn = (1.1 - time * 0.008).clamp(0.45, 1.1) +
          _random.nextDouble() * 0.5;
    }

    // Meteors fall; laser hits; ship collision.
    for (var i = meteors.length - 1; i >= 0; i--) {
      final (mx, my, mvy) = meteors[i];
      final ny = my + mvy * dt;
      meteors[i] = (mx, ny, mvy);

      // Laser hit?
      var destroyed = false;
      for (var j = lasers.length - 1; j >= 0; j--) {
        final (lx, ly) = lasers[j];
        final dx = lx - mx;
        final dy = ly - ny;
        if (dx * dx + dy * dy < (meteorR + 6) * (meteorR + 6)) {
          lasers.removeAt(j);
          destroyed = true;
          break;
        }
      }
      if (destroyed) {
        meteors.removeAt(i);
        hits++;
        continue;
      }

      // Off the bottom: harmless.
      if (ny > worldHeight + meteorR) {
        meteors.removeAt(i);
        continue;
      }

      // Hits the ship?
      if ((mx - shipX).abs() < shipHalfW + meteorR * 0.6 &&
          (ny - shipY).abs() < meteorR + 10) {
        crashed = true;
        return;
      }
    }
  }

  /// Bot: fire when a meteor is above the ship's lane and close in x.
  bool botShouldFire() {
    if (crashed) return false;
    for (final (mx, my, _) in meteors) {
      if (my < shipY - 60 && my > 40 && (mx - shipX).abs() < 26) return true;
    }
    return false;
  }
}

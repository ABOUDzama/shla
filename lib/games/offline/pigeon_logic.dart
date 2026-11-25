import 'dart:math';

/// Pure logic for أطعم الحمامة (Feed the Pigeon). A hungry pigeon wanders
/// around the middle of the arena. Every player has a slingshot in a screen
/// corner whose aim swings left and right by itself; one tap fires a
/// breadcrumb along the current aim. A crumb that reaches the pigeon's mouth
/// scores. Each player has [shots] crumbs; most fed wins, equal top = draw.
/// Modelled on the reference listing text ("slingshot breadcrumbs into the
/// pigeon's mouth"); the rules here are an original adaptation.
class Crumb {
  Crumb(this.seat, this.x, this.y, this.dx, this.dy);
  final int seat;
  double x, y;
  final double dx, dy;
}

class PigeonMatch {
  PigeonMatch({required this.seats, this.shots = 8, Random? random})
      : assert(seats >= 1 && seats <= 4),
        _random = random ?? Random() {
    left = List.filled(seats, shots);
    fed = List.filled(seats, 0);
    cooldown = List.filled(seats, 0.0);
  }

  static const double arenaH = 1.4;
  static const double crumbSpeed = 0.95;
  static const double mouthR = 0.075;
  static const double swing = 0.62;
  static const double swingPeriod = 1.5;
  static const launchers = [
    [0.09, arenaH - 0.09],
    [0.91, 0.09],
    [0.91, arenaH - 0.09],
    [0.09, 0.09],
  ];

  final int seats;
  final int shots;
  final Random _random;
  final Set<int> botSeats = {};
  late List<int> left;
  late List<int> fed;
  late List<double> cooldown;
  final List<Crumb> crumbs = [];
  double time = 0;
  double gulpFlash = 0;

  bool get practice => seats == 1;
  bool get over => left.every((l) => l == 0) && crumbs.isEmpty;

  int? get winner {
    if (!over || seats == 1) return null;
    final best = fed.reduce(max);
    final tops = [for (var i = 0; i < seats; i++) if (fed[i] == best) i];
    return tops.length == 1 ? tops.first : null;
  }

  ({double x, double y}) get pigeon => (
        x: 0.5 + 0.24 * sin(1.1 * time),
        y: 0.7 + 0.32 * sin(0.7 * time + 1.0),
      );

  /// Aim direction (radians) of [seat]'s slingshot at [t].
  double aimAt(int seat, double t) {
    final l = launchers[seat];
    final centre = atan2(0.7 - l[1], 0.5 - l[0]);
    return centre + swing * sin(2 * pi * t / swingPeriod + seat * 1.3);
  }

  double aim(int seat) => aimAt(seat, time);

  bool fire(int seat) {
    if (over || left[seat] <= 0 || cooldown[seat] > 0) return false;
    final a = aim(seat);
    final l = launchers[seat];
    crumbs.add(Crumb(seat, l[0], l[1], cos(a) * crumbSpeed, sin(a) * crumbSpeed));
    left[seat]--;
    cooldown[seat] = 0.4;
    return true;
  }

  void step(double dt) {
    if (over) return;
    time += dt;
    gulpFlash = max(0, gulpFlash - dt);
    for (var i = 0; i < seats; i++) {
      cooldown[i] = max(0, cooldown[i] - dt);
      if (botSeats.contains(i) && left[i] > 0 && cooldown[i] <= 0) {
        final l = launchers[i];
        final p = pigeon;
        final want = atan2(p.y - l[1], p.x - l[0]);
        var d = aim(i) - want;
        while (d > pi) {
          d -= 2 * pi;
        }
        while (d < -pi) {
          d += 2 * pi;
        }
        if (d.abs() < 0.07 && _random.nextDouble() < 0.25) fire(i);
      }
    }
    final p = pigeon;
    for (final c in crumbs.toList()) {
      c.x += c.dx * dt;
      c.y += c.dy * dt;
      final dx = c.x - p.x, dy = c.y - p.y;
      if (dx * dx + dy * dy <= mouthR * mouthR) {
        fed[c.seat]++;
        gulpFlash = 0.25;
        crumbs.remove(c);
      } else if (c.x < -0.05 || c.x > 1.05 || c.y < -0.05 || c.y > arenaH + 0.05) {
        crumbs.remove(c);
      }
    }
  }
}

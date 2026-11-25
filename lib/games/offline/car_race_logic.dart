import 'dart:math';

/// Pure logic for سباق العربيات: top-down laps on an oval track. Cars
/// auto-drive; each player steers with a left and a right pad. Leaving the
/// track (grass) slows the car. First to [laps] laps wins. Original code,
/// modelled on the reference app's "Racing" screenshot (top-down track,
/// steering from the corners), not on its art.
class Car {
  Car(this.x, this.y, this.heading);
  double x, y, heading;
  double speed = 0;
  double theta = 0; // unwrapped progress angle around the track
  double finishedAt = -1;
}

class CarRaceMatch {
  CarRaceMatch({required this.seats, this.laps = 3, Random? random})
      : assert(seats >= 1 && seats <= 4),
        _random = random ?? Random() {
    for (var i = 0; i < seats; i++) {
      final th = startAngle - 0.10 * (i ~/ 2) - 0.02;
      final rho = i.isEven ? 0.86 : 1.14;
      final car = Car(cx + a * rho * cos(th), cy + b * rho * sin(th), _tangent(th));
      car.theta = th - startAngle; // start line at the right side (theta = 0)
      cars.add(car);
      _skill.add(0.90 + _random.nextDouble() * 0.08);
    }
  }

  static const double arenaH = 1.4;
  static const double startAngle = 0;
  /// Cars never leave the visible arena (car is about 0.08 long).
  static const double edge = 0.06;
  static const double cx = 0.5, cy = 0.7;
  static const double a = 0.33, b = 0.53;
  static const double band = 0.24; // |rho - 1| < band is asphalt
  static const double maxSpeed = 0.42;
  static const double grassSpeed = 0.16;
  static const double turnRate = 2.7;

  final int seats;
  final int laps;
  final Random _random;
  final List<Car> cars = [];
  final List<double> _skill = [];
  final Set<int> botSeats = {};
  double time = 0;
  int? winnerSeat;

  bool get over => winnerSeat != null || (seats == 1 && cars[0].finishedAt >= 0);
  bool get practice => seats == 1;
  int? get winner => seats == 1 ? null : winnerSeat;

  static double _tangent(double th) => atan2(b * cos(th), -a * sin(th));

  static double rho(double x, double y) {
    final dx = (x - cx) / a, dy = (y - cy) / b;
    return sqrt(dx * dx + dy * dy);
  }

  static bool onTrack(double x, double y) => (rho(x, y) - 1).abs() < band;

  int lapOf(int i) => max(0, ((cars[i].theta + startAngle) / (2 * pi)).floor());

  void step(double dt, Map<int, int> turn) {
    if (over) return;
    time += dt;
    for (var i = 0; i < cars.length; i++) {
      final c = cars[i];
      if (c.finishedAt >= 0) continue;
      final t = botSeats.contains(i) ? _botTurn(i) : (turn[i] ?? 0);
      c.heading += t * turnRate * dt;
      final top = onTrack(c.x, c.y) ? maxSpeed : grassSpeed;
      final cap = botSeats.contains(i) ? top * _skill[i] : top;
      c.speed += (cap - c.speed) * min(1.0, 3.0 * dt);
      c.x += cos(c.heading) * c.speed * dt;
      c.y += sin(c.heading) * c.speed * dt;
      c.x = c.x.clamp(edge, 1 - edge);
      c.y = c.y.clamp(edge, arenaH - edge);
      // progress: unwrap the change of the ellipse angle
      final th = atan2((c.y - cy) / b, (c.x - cx) / a);
      var prev = (c.theta + startAngle) % (2 * pi);
      if (prev > pi) prev -= 2 * pi;
      var d = th - prev;
      while (d > pi) {
        d -= 2 * pi;
      }
      while (d < -pi) {
        d += 2 * pi;
      }
      c.theta += d;
      if (c.theta + startAngle >= laps * 2 * pi && c.finishedAt < 0) {
        c.finishedAt = time;
        winnerSeat ??= i;
      }
    }
    // gentle car-to-car push
    for (var i = 0; i < cars.length; i++) {
      for (var j = i + 1; j < cars.length; j++) {
        final p = cars[i], q = cars[j];
        final dx = q.x - p.x, dy = q.y - p.y;
        final d = sqrt(dx * dx + dy * dy);
        if (d > 0 && d < 0.07) {
          final push = (0.07 - d) / 2;
          p.x -= dx / d * push;
          p.y -= dy / d * push;
          q.x += dx / d * push;
          q.y += dy / d * push;
        }
      }
    }
  }

  int _botTurn(int i) {
    final c = cars[i];
    final th = atan2((c.y - cy) / b, (c.x - cx) / a) + 0.32;
    final tx = cx + a * cos(th), ty = cy + b * sin(th);
    var diff = atan2(ty - c.y, tx - c.x) - c.heading;
    while (diff > pi) {
      diff -= 2 * pi;
    }
    while (diff < -pi) {
      diff += 2 * pi;
    }
    if (diff.abs() < 0.05) return 0;
    return diff > 0 ? 1 : -1;
  }
}

import 'dart:math';

/// Pure logic for سباق العربيات: top-down rally on a rounded-rect sandy
/// circuit. Cars auto-accelerate; players steer with left/right pads.
/// Steering hard at speed slides the car (drift) and builds drift charge;
/// a full charge spends as a boost (reference Rally Drifters mechanic).
/// Off the packed-dirt surface the car slows hard. First to [laps] laps
/// wins. Original code and art.
class Car {
  Car(this.x, this.y, this.heading);
  double x, y, heading;
  double speed = 0;
  double theta = 0; // unwrapped progress angle around the circuit
  double slip = 0; // visual drift angle (velocity lags heading)
  double finishedAt = -1;

  /// Drift charge 0..1, built by drifting. Full charge -> boost.
  double energy = 0;

  /// Boost window end (match time); -1 = not boosting.
  double boostUntil = -1;

  /// Recent positions while drifting, for the tire-mark visual.
  final List<Point<double>> driftTrail = [];
}

class CarRaceMatch {
  CarRaceMatch({required this.seats, this.laps = 3, Random? random})
      : assert(seats >= 1 && seats <= 4),
        _random = random ?? Random() {
    for (var i = 0; i < seats; i++) {
      // Grid on the right-side straight, just before the start line.
      final th = -0.035 * (i ~/ 2 + 1);
      final lat = i.isEven ? -0.045 : 0.045;
      final p = centerlinePoint(th);
      final nx = cos(th + pi / 2), ny = sin(th + pi / 2);
      final car = Car(p.x + nx * lat, p.y + ny * lat, _tangentHeading(th));
      car.theta = th;
      cars.add(car);
      _skill.add(0.90 + _random.nextDouble() * 0.08);
      _lastSteer.add(0);
    }
  }

  // ---------------------------------------------------------- geometry ---
  static const double arenaH = 1.4;
  static const double edge = 0.05;
  static const double cx = 0.5, cy = 0.7;
  // Circuit centerline: rounded box half-extents and corner radius.
  static const double bx = 0.40, by = 0.56, cr = 0.24;
  // Half track width: |sdTrack| < band is drivable dirt.
  static const double band = 0.105;

  static const double maxSpeed = 0.40;
  static const double grassSpeed = 0.15;
  static const double boostSpeed = 0.58;
  static const double boostSeconds = 1.3;
  static const double turnRate = 2.9;

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

  /// Signed distance to the circuit centerline (0 on the line, negative
  /// inside the loop). Rounded-box SDF.
  static double sdTrack(double x, double y) {
    final px = (x - cx).abs() - (bx - cr);
    final py = (y - cy).abs() - (by - cr);
    final ax = max(px, 0.0), ay = max(py, 0.0);
    return sqrt(ax * ax + ay * ay) + min(max(px, py), 0.0) - cr;
  }

  static bool onTrack(double x, double y) => sdTrack(x, y).abs() < band;

  /// Point on the centerline seen at angle [th] from the centre
  /// (ray-cast onto the rounded-box outline).
  static Point<double> centerlinePoint(double th) {
    final dx = cos(th), dy = sin(th);
    double lo = 0.0, hi = 1.0;
    for (var i = 0; i < 24; i++) {
      final mid = (lo + hi) / 2;
      final sd = sdTrack(cx + dx * mid, cy + dy * mid);
      if (sd < 0) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    final t = (lo + hi) / 2;
    return Point(cx + dx * t, cy + dy * t);
  }

  /// Heading of travel at angle [th] (increasing th = race direction).
  static double _tangentHeading(double th) {
    const d = 0.01;
    final a = centerlinePoint(th), b = centerlinePoint(th + d);
    return atan2(b.y - a.y, b.x - a.x);
  }

  int lapOf(int i) => max(0, (cars[i].theta / (2 * pi)).floor());

  // ------------------------------------------------------------ inputs ---
  final Set<int> _boostRequests = {};
  final List<int> _lastSteer = [];

  /// Ask to spend a full drift charge as a boost (no-op without one).
  void requestBoost(int seat) => _boostRequests.add(seat);

  bool boosting(int i) => time < cars[i].boostUntil;

  /// True while the car is sliding at speed on the dirt (building charge).
  bool drifting(int i) {
    final c = cars[i];
    return _lastSteer[i] != 0 &&
        c.speed > maxSpeed * 0.5 &&
        onTrack(c.x, c.y) &&
        !boosting(i);
  }

  void step(double dt, Map<int, int> turn) {
    if (over) return;
    time += dt;
    for (var i = 0; i < cars.length; i++) {
      final c = cars[i];
      if (c.finishedAt >= 0) continue;
      final t = botSeats.contains(i) ? _botTurn(i) : (turn[i] ?? 0);
      _lastSteer[i] = t;
      // A bot spends a full charge on the straights.
      if (botSeats.contains(i) && c.energy >= 1 && t == 0) {
        _boostRequests.add(i);
      }
      if (_boostRequests.remove(i) && c.energy >= 1 && c.finishedAt < 0) {
        c.energy = 0;
        c.boostUntil = time + boostSeconds;
      }
      // Steering authority grows with speed.
      c.heading += t * turnRate * dt * (0.45 + 0.55 * (c.speed / maxSpeed).clamp(0.0, 1.0));
      // Drift: at speed, steering makes the velocity lag the heading.
      final targetSlip = drifting(i) ? t * 0.38 : 0.0;
      c.slip += (targetSlip - c.slip) * min(1.0, 6 * dt);
      if (drifting(i)) {
        c.energy = min(1.0, c.energy + 0.30 * dt);
        c.driftTrail.add(Point(c.x, c.y));
        if (c.driftTrail.length > 46) c.driftTrail.removeAt(0);
      } else if (boosting(i) && c.driftTrail.isNotEmpty) {
        c.driftTrail.clear();
      }
      // Speed toward the surface cap.
      var top = onTrack(c.x, c.y) ? maxSpeed : grassSpeed;
      if (boosting(i)) top = max(top, boostSpeed);
      final cap = botSeats.contains(i) ? top * _skill[i] : top;
      c.speed += (cap - c.speed) * min(1.0, 2.6 * dt);
      // Move along heading minus the drift slip.
      final dir = c.heading - c.slip;
      c.x += cos(dir) * c.speed * dt;
      c.y += sin(dir) * c.speed * dt;
      c.x = c.x.clamp(edge, 1 - edge);
      c.y = c.y.clamp(edge, arenaH - edge);
      // Progress: unwrap the centre-angle change.
      final th = atan2(c.y - cy, c.x - cx);
      var prev = c.theta % (2 * pi);
      if (prev > pi) prev -= 2 * pi;
      var d = th - prev;
      while (d > pi) {
        d -= 2 * pi;
      }
      while (d < -pi) {
        d += 2 * pi;
      }
      c.theta += d;
      if (c.theta >= laps * 2 * pi && c.finishedAt < 0) {
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
    final th = atan2(c.y - cy, c.x - cx) + 0.30;
    final target = centerlinePoint(th);
    var diff = atan2(target.y - c.y, target.x - c.x) - c.heading;
    while (diff > pi) {
      diff -= 2 * pi;
    }
    while (diff < -pi) {
      diff += 2 * pi;
    }
    return diff.abs() < 0.12 ? 0 : (diff > 0 ? 1 : -1);
  }
}

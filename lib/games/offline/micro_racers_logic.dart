import 'dart:math';

/// Pure logic for ميكرو ريسرز: a faithful clone of the reference app's
/// "Micro Speed Racers" (store blurb: "Avoid obstacles in this formula
/// racing game"). One button per player cycles the car through three
/// lanes (left -> center -> right -> left). Dodge blocks (big speed
/// loss) and oil (brief stall), collect batteries for score, hit boost
/// pads for a burst. First to the finish distance wins. Every seat sees
/// the same seeded item stream, so the race is fair. Original code.
enum MicroItemType { block, oil, battery, boost }

class MicroItem {
  MicroItem(this.lane, this.type, this.dist);
  final int lane; // 0,1,2
  final MicroItemType type;
  final double dist; // distance along the track where the item sits
  bool taken = false;
}

class MicroCar {
  int lane = 1;
  double dist = 0;
  double speed = 0;
  double slowUntil = -1; // block hit: crawling until this time
  double stallUntil = -1; // oil hit: no lane change until this time
  double boostUntil = -1; // boost pad: burst until this time
  int batteries = 0;
  double finishedAt = -1;
}

class MicroRaceMatch {
  MicroRaceMatch({required this.seats, double? trackLength, Random? random})
      : assert(seats >= 1 && seats <= 4),
        trackLength = trackLength ?? 100.0,
        _random = random ?? Random() {
    for (var i = 0; i < seats; i++) {
      cars.add(MicroCar());
      items.add(_buildStream());
      _skill.add(0.85 + _random.nextDouble() * 0.13);
    }
  }

  static const double baseSpeed = 9.0; // track units per second
  static const double boostSpeed = 15.0;
  static const double slowSpeed = 3.0;
  static const double slowSeconds = 0.9;
  static const double stallSeconds = 0.6;
  static const double boostSeconds = 1.2;
  static const double itemGap = 7.0; // distance between item rows
  static const int itemsPerRow = 1;

  final int seats;
  final double trackLength;
  final Random _random;
  final List<MicroCar> cars = [];
  final List<List<MicroItem>> items = [];
  final List<double> _skill = [];
  final Set<int> botSeats = {};
  double time = 0;
  int? winnerSeat;

  bool get over => winnerSeat != null || (seats == 1 && cars[0].finishedAt >= 0);
  bool get practice => seats == 1;
  int? get winner => seats == 1 ? null : winnerSeat;

  /// One seeded stream, identical for every seat (fair race).
  List<MicroItem> _buildStream() {
    final rng = Random(2026); // same seed for all seats on purpose
    final list = <MicroItem>[];
    var d = 14.0; // first items appear after a runway
    var row = 0;
    while (d < trackLength - 6) {
      final lane = rng.nextInt(3);
      final roll = rng.nextDouble();
      final type = roll < 0.34
          ? MicroItemType.block
          : roll < 0.50
              ? MicroItemType.oil
              : roll < 0.78
                  ? MicroItemType.battery
                  : MicroItemType.boost;
      list.add(MicroItem(lane, type, d));
      // Occasionally a second item on a different lane in the same row.
      if (row % 3 == 1) {
        final other = (lane + 1 + rng.nextInt(2)) % 3;
        list.add(MicroItem(
            other, rng.nextDouble() < 0.6 ? MicroItemType.battery : MicroItemType.block, d));
      }
      d += itemGap * (0.85 + rng.nextDouble() * 0.3);
      row++;
    }
    return list;
  }

  /// Items of [seat] within [ahead] distance in front of the car.
  List<MicroItem> upcoming(int seat, double ahead) {
    final c = cars[seat];
    return items[seat]
        .where((it) => !it.taken && it.dist > c.dist - 1 && it.dist < c.dist + ahead)
        .toList();
  }

  /// One-button control: cycle left -> center -> right -> left.
  void cycleLane(int seat) {
    if (over) return;
    final c = cars[seat];
    if (c.finishedAt >= 0 || time < c.stallUntil) return;
    c.lane = (c.lane + 1) % 3;
  }

  void step(double dt) {
    if (over) return;
    time += dt;
    for (var i = 0; i < cars.length; i++) {
      final c = cars[i];
      if (c.finishedAt >= 0) continue;
      // Bots: dodge the next hazard ahead (reaction window), grab goodies.
      if (botSeats.contains(i)) _botDrive(i);
      // Speed model: burst / crawl / stall / cruise.
      var top = baseSpeed;
      if (time < c.boostUntil) top = boostSpeed;
      if (time < c.slowUntil) top = slowSpeed;
      final cap = botSeats.contains(i) ? top * _skill[i] : top;
      c.speed += (cap - c.speed) * (dt * 4).clamp(0.0, 1.0);
      c.dist += c.speed * dt;
      // Collisions: item row reached, lane matched.
      for (final it in items[i]) {
        if (it.taken || it.dist > c.dist) continue;
        it.taken = true;
        if (it.lane != c.lane) continue;
        switch (it.type) {
          case MicroItemType.block:
            c.slowUntil = time + slowSeconds;
            c.boostUntil = -1;
          case MicroItemType.oil:
            c.stallUntil = time + stallSeconds;
          case MicroItemType.battery:
            c.batteries++;
          case MicroItemType.boost:
            c.boostUntil = time + boostSeconds;
            c.slowUntil = -1;
        }
      }
      if (c.dist >= trackLength && c.finishedAt < 0) {
        c.finishedAt = time;
        winnerSeat ??= i;
      }
    }
  }

  void _botDrive(int i) {
    final c = cars[i];
    if (time < c.stallUntil) return;
    final ahead = upcoming(i, 10);
    if (ahead.isEmpty) return;
    ahead.sort((a, b) => a.dist.compareTo(b.dist));
    final next = ahead.first;
    // Only react close enough (human-like reaction window).
    if (next.dist - c.dist > 7 * _skill[i] + 1.5) return;
    final hazardHere = (next.type == MicroItemType.block || next.type == MicroItemType.oil) &&
        next.lane == c.lane;
    if (hazardHere) {
      cycleLane(i);
      return;
    }
    // Occasional greedy drift toward a battery/boost in the same row.
    final goodie = ahead.firstWhere(
        (it) => (it.type == MicroItemType.battery || it.type == MicroItemType.boost) &&
            it.dist - c.dist < 5,
        orElse: () => ahead.first);
    if ((goodie.type == MicroItemType.battery || goodie.type == MicroItemType.boost) &&
        goodie.lane != c.lane &&
        _random.nextDouble() < 0.5) {
      cycleLane(i);
    }
  }
}

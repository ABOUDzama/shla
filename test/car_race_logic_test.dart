import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:shella/games/offline/car_race_logic.dart';

void main() {
  test('cars start on asphalt facing along the track', () {
    final m = CarRaceMatch(seats: 4, random: Random(1));
    for (final c in m.cars) {
      expect(CarRaceMatch.onTrack(c.x, c.y), true);
    }
  });

  test('steering input turns the car; no input goes straight', () {
    final m = CarRaceMatch(seats: 2, random: Random(1));
    final h = m.cars[0].heading;
    m.step(0.1, {0: 1});
    expect(m.cars[0].heading, greaterThan(h));
    final h2 = m.cars[0].heading;
    m.step(0.1, {});
    expect(m.cars[0].heading, h2);
  });

  test('grass slows the car', () {
    final m = CarRaceMatch(seats: 1, random: Random(1));
    final c = m.cars[0];
    c.x = 0.05; c.y = 0.05; c.speed = CarRaceMatch.maxSpeed; c.heading = 0;
    for (var i = 0; i < 60; i++) { m.step(0.016, {}); }
    expect(c.speed, lessThan(CarRaceMatch.maxSpeed * 0.6));
  });

  test('bot completes 3 laps and wins a 2-bot race (proof of play)', () {
    var wins = 0;
    var total = 0.0;
    for (var seed = 0; seed < 10; seed++) {
      final m = CarRaceMatch(seats: 4, random: Random(seed));
      m.botSeats.addAll({0, 1, 2, 3});
      var guard = 0;
      while (!m.over && guard++ < 60000) { m.step(0.016, {}); }
      if (m.winnerSeat != null) { wins++; total += m.time; }
    }
    // ignore: avoid_print
    print('CARRACE_PROOF finished $wins/10, avg ${total / max(1, wins)} s');
    expect(wins, 10);
  });

  test('driving backwards does not count laps', () {
    final m = CarRaceMatch(seats: 1, random: Random(2));
    final c = m.cars[0];
    c.heading += pi; // reverse direction
    for (var i = 0; i < 400; i++) {
      m.step(0.016, {0: 0});
    }
    expect(m.lapOf(0), 0);
    expect(m.over, false);
  });

  test('practice ends at the lap target with no winner', () {
    final m = CarRaceMatch(seats: 1, random: Random(3));
    m.botSeats.add(0); // autodrive for the test
    var g = 0;
    while (!m.over && g++ < 60000) { m.step(0.016, {}); }
    expect(m.over, true);
    expect(m.winner, isNull);
    expect(m.cars[0].finishedAt, greaterThan(0));
  });
  test('cars stay fully inside the arena and can recover from the edge', () {
    final m = CarRaceMatch(seats: 1, random: Random(5));
    final c = m.cars[0];
    // drive straight into the bottom-right corner and hold
    c.x = 0.9; c.y = 1.3; c.heading = 0.8;
    for (var i = 0; i < 600; i++) {
      m.step(0.016, {});
      expect(c.x, inInclusiveRange(CarRaceMatch.edge, 1 - CarRaceMatch.edge));
      expect(c.y, inInclusiveRange(CarRaceMatch.edge, CarRaceMatch.arenaH - CarRaceMatch.edge));
    }
    // pinned at the wall, steering still turns it and it moves away
    final h = c.heading;
    for (var i = 0; i < 40; i++) { m.step(0.016, {0: 1}); }
    expect(c.heading, greaterThan(h));
    for (var i = 0; i < 100; i++) { m.step(0.016, {0: 1}); }
    expect(c.speed, greaterThan(0.05));
  });
}

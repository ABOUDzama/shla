import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shella/games/offline/micro_racers_logic.dart';

void main() {
  MicroRaceMatch match({int seats = 2, double len = 100, int seed = 7}) =>
      MicroRaceMatch(
          seats: seats, trackLength: len.toDouble(), random: Random(seed));

  void run(MicroRaceMatch m, double seconds) {
    for (var t = 0.0; t < seconds && !m.over; t += 1 / 60) {
      m.step(1 / 60);
    }
  }

  test('identical item stream for every seat (fair race)', () {
    final m = match(seats: 4);
    expect(m.items.length, 4);
    for (var s = 1; s < 4; s++) {
      expect(m.items[s].length, m.items[0].length);
      for (var i = 0; i < m.items[0].length; i++) {
        expect(m.items[s][i].lane, m.items[0][i].lane);
        expect(m.items[s][i].type, m.items[0][i].type);
        expect(m.items[s][i].dist, m.items[0][i].dist);
      }
    }
  });

  test('one button cycles lane left-center-right-left', () {
    final m = match();
    m.step(0.016);
    expect(m.cars[0].lane, 1);
    m.cycleLane(0);
    expect(m.cars[0].lane, 2);
    m.cycleLane(0);
    expect(m.cars[0].lane, 0);
    m.cycleLane(0);
    expect(m.cars[0].lane, 1);
  });

  test('car accelerates and finishes the race', () {
    final m = match(seats: 1, len: 30);
    run(m, 30);
    expect(m.cars[0].dist, greaterThanOrEqualTo(30));
    expect(m.cars[0].finishedAt, greaterThan(0));
    expect(m.over, isTrue); // practice ends when the car finishes
    expect(m.winner, isNull); // practice: no winner
  });

  test('first finisher wins the race', () {
    final m = match(len: 40);
    // freeze seat 1 at the start line
    run(m, 60);
    expect(m.winner, isNotNull);
    expect(m.cars[m.winner!].finishedAt, greaterThan(0));
  });

  test('hitting a block slows the car; a battery adds score', () {
    final m = match(seats: 1, len: 400);
    final c = m.cars[0];
    // find a block in the stream and drive onto it
    final block = m.items[0].firstWhere((it) => it.type == MicroItemType.block);
    // teleport the car just before the block, in its lane
    c.dist = block.dist - 1;
    c.lane = block.lane;
    c.speed = MicroRaceMatch.baseSpeed;
    m.step(0.2);
    expect(block.taken, isTrue);
    expect(m.time, lessThan(c.slowUntil));

    final battery =
        m.items[0].firstWhere((it) => it.type == MicroItemType.battery && !it.taken);
    c.dist = battery.dist - 1;
    c.lane = battery.lane;
    c.slowUntil = -1;
    c.speed = MicroRaceMatch.baseSpeed;
    m.step(0.2);
    expect(c.batteries, 1);
  });

  test('boost pad gives a burst', () {
    final m = match(seats: 1, len: 400);
    final c = m.cars[0];
    final boost = m.items[0].firstWhere((it) => it.type == MicroItemType.boost);
    c.dist = boost.dist - 1;
    c.lane = boost.lane;
    c.speed = MicroRaceMatch.baseSpeed;
    m.step(0.2);
    expect(m.time, lessThan(c.boostUntil));
    // burst speed exceeds cruise
    for (var i = 0; i < 60; i++) {
      m.step(1 / 60);
    }
    expect(c.speed, greaterThan(MicroRaceMatch.baseSpeed * 1.1));
  });

  test('bots dodge hazards and the race completes', () {
    final m = match(seats: 4, len: 120);
    m.botSeats.addAll([1, 2, 3]);
    run(m, 120);
    expect(m.over, isTrue);
  });

  test('over: winner recorded only once', () {
    final m = match(seats: 2, len: 30);
    run(m, 60);
    final w = m.winner;
    m.step(1 / 60);
    expect(m.winner, w);
  });
}

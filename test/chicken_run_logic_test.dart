import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:shella/games/offline/chicken_run_logic.dart';

void main() {
  test('flip sends the chicken to the other surface and blocks mid-air flips', () {
    final m = ChickenRunMatch(seats: 2, random: Random(1));
    expect(m.surface[0], 0);
    expect(m.flip(0), true);
    expect(m.flip(0), false, reason: 'cannot flip while flying');
    for (var i = 0; i < 12; i++) { m.step(0.033); if (!m.alive[0]) break; }
    expect(m.surface[0], 1);
    expect(m.flip(0), true);
  });

  test('standing on a hole falls out, flipping in time survives', () {
    final m = ChickenRunMatch(seats: 2, random: Random(2));
    // force the first hole on the floor
    m.holes.insert(0, Hole(0, 0.5, 0.8));
    m.scroll = 0; // chicken at 0.3, hole reaches it after ~0.2 units
    // seat 1 flips early, seat 0 never does
    var flipped = false;
    for (var i = 0; i < 200 && m.alive[0]; i++) {
      if (!flipped && m.nextHole(0, m.scroll + 0.3)!.start - (m.scroll + 0.3) < 0.3) {
        m.flip(1); flipped = true;
      }
      m.step(0.016);
    }
    expect(m.alive[0], false);
    expect(m.alive[1], true);
    expect(m.over, true);
    expect(m.winner, 1);
  });

  test('landing inside a hole on the target surface also falls out', () {
    final m = ChickenRunMatch(seats: 2, random: Random(3));
    m.holes.clear();
    m.holes.add(Hole(1, 0.2, 0.9));
    m.scroll = 0.1;
    m.flip(0);
    for (var i = 0; i < 20; i++) { m.step(0.016); }
    expect(m.alive[0], false);
  });

  test('practice ends when the only chicken falls, no winner', () {
    final m = ChickenRunMatch(seats: 1, random: Random(4));
    while (!m.over) { m.step(0.033); }
    expect(m.winner, isNull);
    expect(m.survived[0], greaterThan(0));
  });

  test('speed rises and is capped', () {
    final m = ChickenRunMatch(seats: 1, random: Random(1));
    final s0 = m.speed;
    m.time = 20;
    expect(m.speed, greaterThan(s0));
    m.time = 500;
    expect(m.speed, ChickenRunMatch.maxSpeed);
  });

  test('every generated hole is separated enough to react (fair pattern)', () {
    final m = ChickenRunMatch(seats: 1, random: Random(9));
    m.scroll = 100; m.step(0.001);
    for (var i = 1; i < m.holes.length; i++) {
      expect(m.holes[i].start - m.holes[i - 1].end,
          greaterThanOrEqualTo(ChickenRunMatch.maxSpeed * ChickenRunMatch.flipTime));
    }
  });

  test('bots play: a 4-bot match lasts several holes (proof of play)', () {
    var total = 0.0;
    for (var seed = 0; seed < 20; seed++) {
      final m = ChickenRunMatch(seats: 4, random: Random(seed));
      m.botSeats.addAll({0, 1, 2, 3});
      var guard = 0;
      while (!m.over && guard++ < 40000) { m.step(0.016); }
      total += m.survived.reduce(max);
    }
    // ignore: avoid_print
    print('CHICKENRUN_PROOF best survival avg = ${total / 20}s');
    expect(total / 20, greaterThan(5));
  });
}

import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:shella/games/offline/pigeon_logic.dart';

void main() {
  test('a crumb fired straight at the mouth feeds that seat only', () {
    final m = PigeonMatch(seats: 2, random: Random(1));
    // freeze the world around a time when aim points at the pigeon
    final l = PigeonMatch.launchers[0];
    final p = m.pigeon;
    // add a crumb manually aimed at the mouth
    final a = atan2(p.y - l[1], p.x - l[0]);
    m.crumbs.add(Crumb(0, l[0], l[1], cos(a) * 0.001, sin(a) * 0.001));
    // move it onto the mouth
    m.crumbs.first.x = p.x - 0.01; m.crumbs.first.y = p.y;
    m.step(0.001);
    expect(m.fed, [1, 0]);
    expect(m.crumbs, isEmpty);
  });

  test('missed crumb leaves the arena and costs a shot', () {
    final m = PigeonMatch(seats: 1, random: Random(1));
    m.time = 0;
    expect(m.fire(0), true);
    expect(m.left[0], 7);
    expect(m.fire(0), false, reason: 'cooldown');
    for (var i = 0; i < 400; i++) { m.step(0.016); }
    expect(m.crumbs, isEmpty);
  });

  test('match ends when every crumb is shot; winner and draw', () {
    final m = PigeonMatch(seats: 2, shots: 1, random: Random(1));
    m.fire(0); m.fire(1);
    m.fed[0] = 1;
    for (var i = 0; i < 400; i++) { m.step(0.016); }
    expect(m.over, true);
    expect(m.winner, 0);
    m.fed[1] = 1;
    expect(m.winner, isNull);
  });

  test('practice has no winner', () {
    final m = PigeonMatch(seats: 1, shots: 1);
    m.fire(0);
    for (var i = 0; i < 400; i++) { m.step(0.016); }
    expect(m.over, true);
    expect(m.winner, isNull);
  });

  test('aim swings between both sides of the centre line', () {
    final m = PigeonMatch(seats: 1);
    var lo = 99.0, hi = -99.0;
    for (var t = 0.0; t < 3; t += 0.05) {
      final a = m.aimAt(0, t);
      lo = min(lo, a); hi = max(hi, a);
    }
    expect(hi - lo, greaterThan(1.0));
  });

  test('bots feed the pigeon sometimes but not always (proof of play)', () {
    var fedTotal = 0, shotsTotal = 0;
    for (var seed = 0; seed < 20; seed++) {
      final m = PigeonMatch(seats: 4, random: Random(seed));
      m.botSeats.addAll({0, 1, 2, 3});
      var g = 0;
      while (!m.over && g++ < 20000) { m.step(0.016); }
      fedTotal += m.fed.reduce((a, b) => a + b);
      shotsTotal += 32;
    }
    // ignore: avoid_print
    print('PIGEON_PROOF bots fed $fedTotal of $shotsTotal crumbs');
    expect(fedTotal, greaterThan(shotsTotal * 0.10));
    expect(fedTotal, lessThan(shotsTotal * 0.8));
  });
}

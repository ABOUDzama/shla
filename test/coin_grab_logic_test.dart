import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:shella/games/offline/coin_grab_logic.dart';

void main() {
  test('every coin is reachable: perfect-timing taps always clear the pile', () {
    for (var s = 0; s < 20; s++) {
      final m = CoinGrabMatch(seats: 4, random: Random(s));
      // grab every tick (infinite spam ignoring cooldown by resetting it)
      for (var t = 0; t < 4000 && m.coins.isNotEmpty; t++) {
        m.time += 0.02;
        for (var p = 0; p < 4; p++) {
          m.cooldown[p] = 0;
          m.grab(p);
        }
      }
      expect(m.coins, isEmpty, reason: 'seed $s left ${m.coins.length}');
    }
  });

  test('practice seat alone can also reach every coin', () {
    final m = CoinGrabMatch(seats: 1, random: Random(4));
    for (var t = 0; t < 8000 && m.coins.isNotEmpty; t++) {
      m.time += 0.02;
      m.cooldown[0] = 0;
      m.grab(0);
    }
    expect(m.coins, isEmpty);
  });

  test('tap on a coin scores its value, tap on empty is a miss, cooldown blocks', () {
    final m = CoinGrabMatch(seats: 2, random: Random(1));
    final c = m.coins.first;
    // find a time at which seat 0's tip is on that coin
    double? hit;
    for (var t = 0.0; t < 40; t += 0.005) {
      final p = m.tipAt(0, t);
      if (sqrt(pow(p.x - c.x, 2) + pow(p.y - c.y, 2)) < CoinGrabMatch.reach * 0.5) {
        hit = t;
        break;
      }
    }
    expect(hit, isNotNull);
    m.time = hit!;
    expect(m.grab(0), c.value);
    expect(m.scores[0], c.value);
    expect(m.grab(0), -1, reason: 'cooldown');
    expect(m.scores[1], 0);
  });

  test('clock ends the match and richest wins, tie is null', () {
    final m = CoinGrabMatch(seats: 2, random: Random(2));
    m.scores[0] = 6;
    m.scores[1] = 6;
    m.time = CoinGrabMatch.matchSeconds;
    expect(m.over, isTrue);
    expect(m.winner, isNull);
    m.scores[1] = 7;
    expect(m.winner, 1);
  });

  test('practice has no winner', () {
    final m = CoinGrabMatch(seats: 1, random: Random(2));
    m.time = 61;
    expect(m.winner, isNull);
  });

  test('bots grab on their own', () {
    var total = 0;
    for (var s = 0; s < 5; s++) {
      final m = CoinGrabMatch(seats: 2, random: Random(s));
      m.botSeats.addAll([0, 1]);
      for (var t = 0; t < 1800; t++) {
        m.step(0.033);
      }
      total += m.grabbed[0] + m.grabbed[1];
    }
    expect(total, greaterThan(10));
  });
}

import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:shella/games/offline/tug_of_war_logic.dart';

void main() {
  test('2-4 players init centered with no winner', () {
    for (var n = 2; n <= 4; n++) {
      final m = TugMatch(playerCount: n, random: Random(1));
      expect(m.kx, 0);
      expect(m.ky, 0);
      expect(m.isOver, isFalse);
    }
  });

  test('marker sweeps and bounces between 0 and 1', () {
    final m = TugMatch(playerCount: 2, random: Random(1));
    var minP = 1.0, maxP = 0.0;
    for (var i = 0; i < 300; i++) {
      m.tick();
      minP = min(minP, m.phase);
      maxP = max(maxP, m.phase);
      expect(m.phase, inInclusiveRange(0.0, 1.0));
    }
    expect(minP, 0.0);
    expect(maxP, 1.0);
  });

  test('perfect tap pulls toward the player, miss does not', () {
    final m = TugMatch(playerCount: 2, random: Random(1));
    // walk the marker into the green zone
    while ((m.phase - 0.5).abs() > 0.03) { m.tick(); }
    expect(m.tap(0), 'perfect'); // player 0 pulls left
    expect(m.kx, lessThan(0));
    final afterPerfect = m.kx;
    // force a miss: run marker to an edge
    while (m.phase > 0.05) { m.tick(); }
    expect(m.tap(1), 'miss');
    expect(m.kx, greaterThan(afterPerfect - 0.01)); // drift only, no pull
  });

  test('repeated perfects win the round', () {
    final m = TugMatch(playerCount: 2, random: Random(1));
    var guard = 0;
    while (!m.isOver && guard++ < 5000) {
      m.tick();
      if ((m.phase - 0.5).abs() <= 0.03) m.tap(0);
    }
    expect(m.winner, 0);
    expect(m.kx, lessThanOrEqualTo(-1));
  });

  test('deterministic with the same seed', () {
    List<String> run() {
      final m = TugMatch(playerCount: 3, random: Random(4));
      final trace = <String>[];
      for (var i = 0; i < 200 && !m.isOver; i++) {
        m.tick();
        if (i % 9 == 0) trace.add(m.tap(i % 3));
        trace.add('${m.kx},${m.ky},${m.phase}');
      }
      return trace;
    }
    expect(run(), run());
  });
}

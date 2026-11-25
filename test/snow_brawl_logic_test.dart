import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:shella/games/offline/snow_brawl_logic.dart';

void main() {
  test('2-4 players init with full forts and no winner', () {
    for (var n = 2; n <= 4; n++) {
      final m = SnowBrawlMatch(playerCount: n, random: Random(1));
      expect(m.hp, List.filled(n, 3));
      expect(m.isOver, isFalse);
      expect(m.neededPower, inInclusiveRange(0.2, 0.95));
    }
  });

  test('power meter sweeps and bounces', () {
    final m = SnowBrawlMatch(playerCount: 2, random: Random(1));
    var minP = 1.0, maxP = 0.0;
    for (var i = 0; i < 200; i++) {
      m.tick();
      minP = min(minP, m.phase);
      maxP = max(maxP, m.phase);
      expect(m.phase, inInclusiveRange(0.0, 1.0));
    }
    expect(minP, 0.0);
    expect(maxP, 1.0);
  });

  test('matching power hits the target fort, wrong power misses', () {
    final m = SnowBrawlMatch(playerCount: 2, random: Random(1));
    while ((m.phase - m.neededPower).abs() > 0.02) { m.tick(); }
    expect(m.throwSnowball(0), isTrue);
    expect(m.hp[1], 2);
    // far from the new target power -> miss
    m.phase = m.neededPower >= 0.5 ? 0.0 : 1.0;
    expect(m.throwSnowball(0), isFalse);
    expect(m.hp[1], 2);
  });

  test('destroying all forts wins; dead players cannot throw', () {
    final m = SnowBrawlMatch(playerCount: 2, fortHp: 2, random: Random(1));
    var guard = 0;
    while (!m.isOver && guard++ < 5000) {
      while ((m.phase - m.neededPower).abs() > 0.02 && guard++ < 5000) { m.tick(); }
      m.throwSnowball(0);
    }
    expect(m.winner, 0);
    expect(m.hp[1], 0);
    expect(m.throwSnowball(1), isFalse);
  });

  test('targeting skips destroyed forts clockwise', () {
    final m = SnowBrawlMatch(playerCount: 4, random: Random(1));
    m.hp[1] = 0;
    expect(m.targetOf(0), 2);
    m.hp[2] = 0;
    expect(m.targetOf(0), 3);
  });

  test('deterministic with the same seed', () {
    List<String> run() {
      final m = SnowBrawlMatch(playerCount: 3, random: Random(6));
      final trace = <String>[];
      for (var i = 0; i < 200 && !m.isOver; i++) {
        m.tick();
        if (i % 13 == 0) trace.add('${m.throwSnowball(i % 3)}');
        trace.add('${m.phase},${m.neededPower},${m.hp}');
      }
      return trace;
    }
    expect(run(), run());
  });
}

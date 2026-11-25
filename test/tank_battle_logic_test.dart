import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:shella/games/offline/tank_battle_logic.dart';

void main() {
  test('2-4 players init with zero scores and no winner', () {
    for (var n = 2; n <= 4; n++) {
      final m = TankBattleMatch(playerCount: n, random: Random(1));
      expect(m.scores, List.filled(n, 0));
      expect(m.isOver, isFalse);
      expect(m.shells, isEmpty);
    }
  });

  test('fire launches a shell inward and starts cooldown', () {
    final m = TankBattleMatch(playerCount: 2, random: Random(1));
    expect(m.fire(0), isTrue);
    expect(m.shells.length, 1);
    final s = m.shells.first;
    expect(s.owner, 0);
    expect(s.dy, lessThan(0)); // bottom tank fires upward
    // cooldown blocks immediate refire
    expect(m.fire(0), isFalse);
    for (var i = 0; i < m.cooldownTicks; i++) { m.tick(); }
    expect(m.fire(0), isTrue);
  });

  test('turret sweeps within range and reverses', () {
    final m = TankBattleMatch(playerCount: 2, random: Random(1));
    final a0 = m.aimAngle(0);
    var reversed = false;
    var last = a0;
    for (var i = 0; i < 200; i++) {
      m.tick();
      final a = m.aimAngle(0);
      if ((a - last).sign != (last - a0).sign && i > 0) reversed = true;
      expect(a - TankBattleMatch.baseAngles[0], inInclusiveRange(-0.61, 0.61));
      last = a;
    }
    expect(reversed, isTrue);
  });

  test('shell hitting a tank scores and ends at target', () {
    final m = TankBattleMatch(playerCount: 2, targetScore: 2, random: Random(5));
    // player 0 fires straight up at player 1's anchor: force alignment by
    // ticking until aim is near zero offset, then fire repeatedly.
    var guard = 0;
    while (!m.isOver && guard++ < 5000) {
      if ((m.aimAngle(0) - TankBattleMatch.baseAngles[0]).abs() < 0.02) {
        m.fire(0);
      }
      m.tick();
    }
    expect(m.winner, 0);
    expect(m.scores[0], greaterThanOrEqualTo(2));
  });

  test('deterministic with the same seed', () {
    List<String> run() {
      final m = TankBattleMatch(playerCount: 4, random: Random(9));
      final trace = <String>[];
      for (var i = 0; i < 120 && !m.isOver; i++) {
        if (i % 11 == 0) m.fire(i % 4);
        m.tick();
        trace.add(m.shells.map((s) => '${s.x},${s.y}').join(';') + '|${m.scores}');
      }
      return trace;
    }
    expect(run(), run());
  });
}

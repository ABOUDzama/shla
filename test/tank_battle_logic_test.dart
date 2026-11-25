import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shella/games/offline/tank_battle_logic.dart';

void main() {
  group('TankBattleMatch (rebuilt reference mechanics)', () {
    test('2-4 players spawn alive in corners aiming at center', () {
      for (var n = 2; n <= 4; n++) {
        final m = TankBattleMatch(playerCount: n, random: Random(7));
        expect(m.aliveCount, n);
        expect(m.isOver, isFalse);
        expect(m.shells, isEmpty);
        for (var p = 0; p < n; p++) {
          expect(m.xs[p], inInclusiveRange(0.05, 0.95));
          expect(m.ys[p], inInclusiveRange(0.05, 0.95));
        }
      }
    });

    test('tanks auto-drive forward every tick', () {
      final m = TankBattleMatch(playerCount: 2, random: Random(3));
      final x0 = m.xs[0], y0 = m.ys[0];
      m.tick();
      final moved =
          sqrt(pow(m.xs[0] - x0, 2) + pow(m.ys[0] - y0, 2));
      expect(moved, greaterThan(0));
    });

    test('holding steers (rotates), releasing fires one shell', () {
      final m = TankBattleMatch(playerCount: 2, random: Random(5));
      final h0 = m.headings[0];
      m.holdStart(0);
      for (var t = 0; t < 10; t++) {
        m.tick();
      }
      expect(m.headings[0], greaterThan(h0));
      expect(m.holdRelease(0), isTrue);
      expect(m.shells.length, 1);
      expect(m.shells.first.owner, 0);
      // one live shell per player: second release without new shell slot fails
      expect(m.holdRelease(0), isFalse);
      expect(m.shells.length, 1);
    });

    test('shell ricochets off the border wall', () {
      final m = TankBattleMatch(playerCount: 2, random: Random(1));
      // aim player 0 directly at the left wall
      m.headings[0] = pi;
      expect(m.holdRelease(0), isTrue);
      final shell = m.shells.first;
      final dx0 = shell.dx;
      var bounced = false;
      for (var t = 0; t < 200 && !bounced; t++) {
        m.tick();
        if (shell.dx != dx0) bounced = true;
      }
      expect(bounced, isTrue);
      expect(shell.bounces, greaterThan(0));
    });

    test('one hit destroys a tank; last tank standing wins', () {
      final m = TankBattleMatch(playerCount: 2, random: Random(9));
      // teleport a shell right next to player 1 aimed at them
      m.shells.add(TankShell2(m.xs[1] - 0.02, m.ys[1], 1, 0, 0));
      m.tick();
      expect(m.alive[1], isFalse);
      expect(m.aliveCount, 1);
      expect(m.winner, 0);
      expect(m.isOver, isTrue);
    });

    test('obstacles block shells (bounce) and tanks (grind around)', () {
      final m = TankBattleMatch(playerCount: 2, random: Random(2));
      // fire into the arena center from each side; shells must not tunnel
      m.headings[0] = 0; // toward +x
      expect(m.holdRelease(0), isTrue);
      for (var t = 0; t < 400; t++) {
        m.tick();
        for (final s in m.shells) {
          for (final o in m.arena.obstacles) {
            final inside = s.x > o.x + 0.01 &&
                s.x < o.x + o.w - 0.01 &&
                s.y > o.y + 0.01 &&
                s.y < o.y + o.h - 0.01;
            expect(inside, isFalse, reason: 'shell tunneled into obstacle');
          }
        }
      }
    });

    test('bots steer and fire on their own; match resolves', () {
      final m = TankBattleMatch(
          playerCount: 4, humanCount: 1, random: Random(17));
      var botFired = false;
      for (var t = 0; t < 900 && !m.isOver; t++) {
        m.tick();
        if (m.shells.any((s) => s.owner >= 1)) botFired = true;
      }
      expect(botFired, isTrue);
      expect(m.isOver, isTrue);
      expect(m.aliveCount, lessThan(4));
    });

    test('bots deterministic with the same seed', () {
      final a = TankBattleMatch(playerCount: 4, humanCount: 0, random: Random(3));
      final b = TankBattleMatch(playerCount: 4, humanCount: 0, random: Random(3));
      for (var t = 0; t < 300; t++) {
        a.tick();
        b.tick();
      }
      expect(a.xs, b.xs);
      expect(a.ys, b.ys);
      expect(a.shells.length, b.shells.length);
      expect(a.alive, b.alive);
    });

    test('deterministic with the same seed', () {
      final a = TankBattleMatch(playerCount: 4, random: Random(42));
      final b = TankBattleMatch(playerCount: 4, random: Random(42));
      expect(a.arena.obstacles.length, b.arena.obstacles.length);
      a.holdStart(0);
      b.holdStart(0);
      for (var t = 0; t < 25; t++) {
        a.tick();
        b.tick();
      }
      a.holdRelease(0);
      b.holdRelease(0);
      for (var t = 0; t < 75; t++) {
        a.tick();
        b.tick();
      }
      expect(a.xs, b.xs);
      expect(a.ys, b.ys);
      expect(a.headings, b.headings);
      expect(a.shells.length, b.shells.length);
      expect(a.alive, b.alive);
    });
  });
}

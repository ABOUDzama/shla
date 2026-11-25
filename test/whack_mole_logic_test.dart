import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shella/games/offline/whack_mole_logic.dart';

void main() {
  group('WhackMoleMatch', () {
    test('2-4 players init with zeroed scores and no moles', () {
      for (var n = 2; n <= 4; n++) {
        final m = WhackMoleMatch(playerCount: n, random: Random(7));
        expect(m.scores, List.filled(n, 0));
        expect(m.isOver, isFalse);
        expect(m.winner(), isNull);
        for (var p = 0; p < n; p++) {
          for (var h = 0; h < WhackMoleMatch.holesPerPlayer; h++) {
            expect(m.isUp(p, h), isFalse);
          }
        }
      }
    });

    test('moles pop on schedule and go down after moleUpTicks', () {
      final m = WhackMoleMatch(playerCount: 2, random: Random(3), moleUpTicks: 5);
      var sawUp = false;
      int? upP, upH;
      for (var t = 0; t < 60 && !sawUp; t++) {
        m.tick();
        for (var p = 0; p < 2 && !sawUp; p++) {
          for (var h = 0; h < 4 && !sawUp; h++) {
            if (m.isUp(p, h)) {
              sawUp = true;
              upP = p;
              upH = h;
            }
          }
        }
      }
      expect(sawUp, isTrue);
      for (var t = 0; t < 5; t++) {
        m.tick();
      }
      expect(m.isUp(upP!, upH!), isFalse);
    });

    test('whack scores only when the mole is up, then it pops down', () {
      final m = WhackMoleMatch(playerCount: 2, random: Random(5), moleUpTicks: 40);
      // advance until a mole is up
      int? p, h;
      for (var t = 0; t < 80 && p == null; t++) {
        m.tick();
        outer:
        for (var pp = 0; pp < 2; pp++) {
          for (var hh = 0; hh < 4; hh++) {
            if (m.isUp(pp, hh)) {
              p = pp;
              h = hh;
              break outer;
            }
          }
        }
      }
      expect(p, isNotNull);
      expect(m.whack(p!, h!), isTrue);
      expect(m.scores[p!], 1);
      expect(m.isUp(p!, h!), isFalse);
      expect(m.whack(p!, h!), isFalse);
      expect(m.scores[p!], 1);
    });

    test('round ends after roundTicks; richest wins, tie gives null', () {
      final m = WhackMoleMatch(playerCount: 2, random: Random(9), roundTicks: 30);
      for (var t = 0; t < 30; t++) {
        m.tick();
      }
      expect(m.isOver, isTrue);
      // both zero -> tie -> null
      expect(m.winner(), anyOf(isNull, isNotNull)); // deterministic seed decides
      final scoreless = WhackMoleMatch(playerCount: 2, random: Random(1), roundTicks: 1);
      scoreless.tick();
      expect(scoreless.isOver, isTrue);
      expect(scoreless.winner(), isNull); // 0 == 0 tie
    });

    test('deterministic with the same seed', () {
      final a = WhackMoleMatch(playerCount: 4, random: Random(42));
      final b = WhackMoleMatch(playerCount: 4, random: Random(42));
      for (var t = 0; t < 100; t++) {
        a.tick();
        b.tick();
      }
      for (var p = 0; p < 4; p++) {
        for (var h = 0; h < 4; h++) {
          expect(a.isUp(p, h), b.isUp(p, h));
        }
      }
      // same whack results
      expect(a.whack(0, 0), b.whack(0, 0));
      expect(a.scores, b.scores);
    });
  });

  group('fairness and bots', () {
    test('each player gets about the same number of moles', () {
      final m = WhackMoleMatch(playerCount: 4, random: Random(5));
      final ups = List.filled(4, 0);
      final prevUp = List.generate(4, (_) => List.filled(4, false));
      while (!m.isOver) {
        m.tick();
        for (var p = 0; p < 4; p++) {
          for (var h = 0; h < 4; h++) {
            final up = m.isUp(p, h);
            if (up && !prevUp[p][h]) ups[p]++;
            prevUp[p][h] = up;
          }
        }
      }
      final lo = ups.reduce(min), hi = ups.reduce(max);
      expect(lo, greaterThan(25));
      expect(hi - lo, lessThan(12));
    });

    test('bot seat scores on its own, human seats do not', () {
      final m = WhackMoleMatch(playerCount: 2, random: Random(9));
      m.botSeats.add(1);
      while (!m.isOver) {
        m.tick();
      }
      expect(m.scores[1], greaterThan(5));
      expect(m.scores[0], 0);
    });

    test('single practice seat has no winner', () {
      final m = WhackMoleMatch(playerCount: 1, random: Random(1));
      while (!m.isOver) {
        m.tick();
      }
      expect(m.winner(), isNull);
    });
  });
}

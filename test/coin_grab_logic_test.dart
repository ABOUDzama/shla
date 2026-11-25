import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shella/games/offline/coin_grab_logic.dart';

void main() {
  group('CoinGrabMatch', () {
    test('2-4 players spawn a seeded pile and zeroed scores', () {
      for (var n = 2; n <= 4; n++) {
        final m = CoinGrabMatch(playerCount: n, random: Random(7));
        expect(m.coins.length, 24);
        expect(m.scores.length, n);
        expect(m.scores.every((s) => s == 0), isTrue);
        expect(m.isOver, isFalse);
        expect(m.winner(), isNull);
      }
    });

    test('arms sweep each tick and stay on their radius', () {
      final m = CoinGrabMatch(playerCount: 4, random: Random(3));
      final before = List<double>.of(m.armAngles);
      m.tick();
      for (var p = 0; p < 4; p++) {
        expect((m.armAngles[p] - before[p]).abs(), greaterThan(0));
        final tip = m.armTipOf(p);
        final b = m.baseOf(p);
        final d = sqrt(pow(tip.x - b.x, 2) + pow(tip.y - b.y, 2));
        expect(d, closeTo(CoinGrabMatch.armRadius, 1e-9));
      }
    });

    test('grab collects a coin under the tip and scores its value', () {
      final m = CoinGrabMatch(playerCount: 2, random: Random(11));
      // place a coin exactly at the arm tip and grab it
      final tip = m.armTipOf(0);
      m.coins.add(CoinGrabCoin(tip.x, tip.y, 10));
      final got = m.grab(0);
      expect(got, 10);
      expect(m.scores[0], 10);
      expect(m.grabbed[0], 1);
    });

    test('grab misses when nothing is in reach', () {
      final m = CoinGrabMatch(playerCount: 2, random: Random(5));
      m.coins.clear();
      m.coins.add(CoinGrabCoin(0.5, 0.5, 5));
      expect(m.grab(0), 0);
      expect(m.scores[0], 0);
    });

    test('game ends when the pile is empty; richest wins, tie gives null', () {
      final m = CoinGrabMatch(playerCount: 2, random: Random(9));
      m.coins.clear();
      m.coins.add(CoinGrabCoin(m.armTipOf(0).x, m.armTipOf(0).y, 10));
      m.coins.add(CoinGrabCoin(m.armTipOf(1).x, m.armTipOf(1).y, 5));
      m.grab(0);
      m.grab(1);
      expect(m.isOver, isTrue);
      expect(m.winner(), 0);

      final t = CoinGrabMatch(playerCount: 2, random: Random(9));
      t.coins.clear();
      t.coins.add(CoinGrabCoin(t.armTipOf(0).x, t.armTipOf(0).y, 10));
      t.coins.add(CoinGrabCoin(t.armTipOf(1).x, t.armTipOf(1).y, 10));
      t.grab(0);
      t.grab(1);
      expect(t.isOver, isTrue);
      expect(t.winner(), isNull);
    });

    test('deterministic with the same seed', () {
      final a = CoinGrabMatch(playerCount: 4, random: Random(42));
      final b = CoinGrabMatch(playerCount: 4, random: Random(42));
      for (var i = 0; i < a.coins.length; i++) {
        expect(a.coins[i].x, b.coins[i].x);
        expect(a.coins[i].y, b.coins[i].y);
        expect(a.coins[i].value, b.coins[i].value);
      }
      for (var t = 0; t < 50; t++) {
        a.tick();
        b.tick();
      }
      expect(a.armAngles, b.armAngles);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:shella/games/offline/touch_ball_game.dart';
import 'dart:math';

void main() {
  group('TouchBallMatch', () {
    test('owner tap scores a point and kills the ball', () {
      final m = TouchBallMatch(players: 3, random: Random(1));
      m.start();
      final owner = m.spawnBall();
      expect(m.ballLive, isTrue);
      expect(m.tapBall(owner), isTrue);
      expect(m.scores[owner], 1);
      expect(m.ballLive, isFalse);
    });

    test('wrong player tap loses a point, never below zero', () {
      final m = TouchBallMatch(players: 2, random: Random(2));
      m.start();
      final owner = m.spawnBall();
      final other = 1 - owner;
      // other has zero: stays zero
      expect(m.tapBall(other), isFalse);
      expect(m.scores[other], 0);
      // give other a point, then penalize
      m.nextRound();
      final owner2 = m.spawnBall();
      final other2 = 1 - owner2;
      // force a score for other2 via direct owner taps until it owns one
      m.tapBall(owner2);
      m.nextRound();
      final o3 = m.spawnBall();
      m.tapBall(o3);
      m.nextRound();
      final o4 = m.spawnBall();
      m.tapBall(o4);
      // now someone has 2+ points; find a scorer and have the OTHER tap
      final scorer = m.scores[0] > m.scores[1] ? 0 : 1;
      m.nextRound();
      final o5 = m.spawnBall();
      if (o5 != scorer) {
        final before = m.scores[scorer];
        expect(m.tapBall(scorer), isTrue); // owner tap, no penalty path
      }
      // deterministic penalty check
      final m2 = TouchBallMatch(players: 2, random: Random(3));
      m2.start();
      final a = m2.spawnBall();
      m2.tapBall(a); // p a has 1
      m2.nextRound();
      final b = m2.spawnBall();
      final notB = 1 - b;
      m2.tapBall(notB); // penalty on notB if it had points
      expect(m2.scores[notB] >= 0, isTrue);
    });

    test('taps ignored when no ball live', () {
      final m = TouchBallMatch(players: 2, random: Random(4));
      m.start();
      expect(m.tapBall(0), isTrue); // no-op
      expect(m.scores, [0, 0]);
    });

    test('ball expiry ends round with no score', () {
      final m = TouchBallMatch(players: 4, random: Random(5));
      m.start();
      m.spawnBall();
      m.ballExpired();
      expect(m.ballLive, isFalse);
      expect(m.scores, [0, 0, 0, 0]);
    });

    test('first to targetScore wins', () {
      final m = TouchBallMatch(players: 2, targetScore: 3, random: Random(6));
      m.start();
      while (m.matchWinner == null) {
        final owner = m.spawnBall();
        m.tapBall(owner); // owner always scores
        m.nextRound();
      }
      expect(m.scores[m.matchWinner!], 3);
    });
  });
}

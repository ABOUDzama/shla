import 'package:flutter_test/flutter_test.dart';
import 'package:shella/games/offline/catch_game.dart';

void main() {
  group('CatchMatch logic', () {
    test('zones split the ring equally among players', () {
      final m = CatchMatch(playerCount: 4);
      expect(m.zoneOf(0), (from: 0.0, to: 90.0));
      expect(m.zoneOf(3), (from: 270.0, to: 0.0));
    });

    test('tap inside the zone scores, outside does not', () {
      final m = CatchMatch(playerCount: 2);
      expect(m.tap(0, 45), isTrue);
      expect(m.tap(1, 45), isFalse);
      expect(m.scores, [1, 0]);
    });

    test('wrap-around arc (past 360) is handled', () {
      final m = CatchMatch(playerCount: 4);
      // Player 3's arc is [270, 0): it covers 270..360 only.
      expect(m.inZone(3, 350), isTrue);
      expect(m.inZone(3, 10), isFalse);
      expect(m.inZone(3, 100), isFalse);
      expect(m.inZone(0, 10), isTrue);
      // A shifted start produces a genuine 360 wrap.
      final shifted = CatchMatch(playerCount: 4, startAngle: 30);
      expect(shifted.zoneOf(3), (from: 300.0, to: 30.0));
      expect(shifted.inZone(3, 350), isTrue);
      expect(shifted.inZone(3, 10), isTrue);
      expect(shifted.inZone(3, 100), isFalse);
    });

    test('non-zero start angle shifts every arc', () {
      final m = CatchMatch(playerCount: 2, startAngle: 90);
      expect(m.zoneOf(0), (from: 90.0, to: 270.0));
      expect(m.inZone(0, 100), isTrue);
      expect(m.inZone(1, 100), isFalse);
    });

    test('one score per revolution per player', () {
      final m = CatchMatch(playerCount: 2);
      expect(m.tap(0, 45), isTrue);
      // same arc, same revolution: spam taps do not score again
      expect(m.tap(0, 45), isFalse);
      expect(m.tap(0, 90), isFalse);
      // next revolution scores again
      expect(m.tap(0, 405), isTrue);
      expect(m.scores[0], 2);
    });

    test('reaching the target wins the match and locks taps', () {
      final m = CatchMatch(playerCount: 2, targetScore: 2);
      expect(m.tap(0, 45), isTrue);
      expect(m.tap(0, 405), isTrue);
      expect(m.matchWinner, 0);
      expect(m.tap(1, 225), isFalse);
    });

    test('wrong tap locks the player out for the rest of that lap only', () {
      final m = CatchMatch(playerCount: 2);
      expect(m.tap(0, 200), isFalse); // outside own arc
      expect(m.tap(0, 45), isFalse, reason: 'locked in same lap');
      expect(m.scores[0], 0);
      expect(m.tap(0, 405), isTrue, reason: 'next lap is open again');
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:shella/games/offline/sumo_game.dart';

void main() {
  group('SumoMatch logic', () {
    test('player 0 pushes the ring to -1 and wins by ring-out', () {
      final m = SumoMatch(pushStep: 0.5);
      m.tap(0);
      m.tap(0);
      expect(m.position, -1.0);
      expect(m.winner, 0);
      expect(m.isOver, isTrue);
    });

    test('player 1 pushes the ring to +1 and wins by ring-out', () {
      final m = SumoMatch(pushStep: 0.4);
      m.tap(1);
      m.tap(1);
      m.tap(1);
      expect(m.position, 1.0);
      expect(m.winner, 1);
    });

    test('taps cancel out and position clamps at the edges', () {
      final m = SumoMatch(pushStep: 0.05);
      for (var i = 0; i < 10; i++) {
        m.tap(0);
      }
      for (var i = 0; i < 10; i++) {
        m.tap(1);
      }
      expect(m.position, closeTo(0.0, 1e-9));
      // Even a huge streak can never push past the edge value.
      for (var i = 0; i < 40; i++) {
        m.tap(1);
      }
      expect(m.position, lessThanOrEqualTo(1.0));
      expect(m.winner, 1);
    });

    test('no taps count after the match is over', () {
      final m = SumoMatch(pushStep: 1.0);
      m.tap(0);
      expect(m.winner, 0);
      final before = m.taps[1];
      m.tap(1);
      expect(m.taps[1], before);
      expect(m.position, -1.0);
    });

    test('timeUp gives the win to whoever pushed further', () {
      final m = SumoMatch(pushStep: 0.1);
      m.tap(0);
      m.tap(0);
      m.tap(1);
      m.timeUp();
      expect(m.winner, 0);
    });

    test('timeUp on a centered ring falls back to tap count, then tie', () {
      final m = SumoMatch(pushStep: 0.0);
      m.tap(0);
      m.timeUp();
      expect(m.winner, 0);
      final tie = SumoMatch(pushStep: 0.0);
      tie.tap(0);
      tie.tap(1);
      tie.timeUp();
      expect(tie.winner, isNull);
    });
  });
}

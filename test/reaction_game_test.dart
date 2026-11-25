import 'package:flutter_test/flutter_test.dart';
import 'package:shella/games/offline/reaction_game.dart';

void main() {
  group('ReactionMatch logic', () {
    test('tap after green scores a point and ends the round', () {
      final m = ReactionMatch(playerCount: 2);
      expect(m.tap(1, green: true), ReactionOutcome.roundWin);
      expect(m.scores, [0, 1]);
      expect(m.tap(0, green: true), ReactionOutcome.ignored);
    });

    test('false start deducts a point but never below zero', () {
      final m = ReactionMatch(playerCount: 2);
      expect(m.tap(0, green: false), ReactionOutcome.falseStart);
      expect(m.scores[0], 0);
      m.nextRound();
      m.tap(0, green: true);
      expect(m.scores[0], 1);
      m.nextRound();
      m.tap(0, green: false);
      expect(m.scores[0], 0);
    });

    test('reaching the target score wins the match and locks taps', () {
      final m = ReactionMatch(playerCount: 3, targetScore: 2);
      m.tap(2, green: true);
      m.nextRound();
      m.tap(2, green: true);
      expect(m.matchWinner, 2);
      m.nextRound();
      expect(m.tap(0, green: true), ReactionOutcome.ignored);
    });

    test('nextRound re-arms the round only before a match winner', () {
      final m = ReactionMatch(playerCount: 2, targetScore: 1);
      m.tap(1, green: true);
      expect(m.roundActive, isFalse);
      m.nextRound();
      expect(m.roundActive, isFalse);
    });

    test('false start ends the round without a winner', () {
      final m = ReactionMatch(playerCount: 4);
      expect(m.tap(3, green: false), ReactionOutcome.falseStart);
      expect(m.matchWinner, isNull);
      expect(m.tap(0, green: true), ReactionOutcome.ignored);
      m.nextRound();
      expect(m.tap(0, green: true), ReactionOutcome.roundWin);
    });
  });
}

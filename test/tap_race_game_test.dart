import 'package:flutter_test/flutter_test.dart';
import 'package:shella/games/offline/tap_race_game.dart';

void main() {
  group('TapRaceMatch', () {
    test('sprint: most taps wins the round and scores', () {
      final m = TapRaceMatch(players: 3);
      m.start();
      for (int i = 0; i < 10; i++) m.tap(0);
      for (int i = 0; i < 7; i++) m.tap(1);
      for (int i = 0; i < 4; i++) m.tap(2);
      expect(m.endSprint(), 0);
      expect(m.scores, [1, 0, 0]);
    });

    test('taps ignored when sprint not live', () {
      final m = TapRaceMatch(players: 2);
      m.start();
      m.tap(0);
      m.endSprint();
      m.tap(1); // after time: ignored
      expect(m.taps, [1, 0]);
      m.tap(99); // out of range: ignored
      expect(m.taps, [1, 0]);
    });

    test('tie means replay with no points', () {
      final m = TapRaceMatch(players: 2);
      m.start();
      for (int i = 0; i < 5; i++) {
        m.tap(0);
        m.tap(1);
      }
      expect(m.endSprint(), isNull);
      expect(m.scores, [0, 0]);
      m.advance(null);
      expect(m.roundWasTie, isTrue);
      expect(m.round, 2);
      // next sprint live again
      m.tap(1);
      expect(m.endSprint(), 1);
      expect(m.scores, [0, 1]);
    });

    test('zero taps is a tie replay', () {
      final m = TapRaceMatch(players: 2);
      m.start();
      expect(m.endSprint(), isNull);
      expect(m.scores, [0, 0]);
    });

    test('first to roundsToWin points takes the match', () {
      final m = TapRaceMatch(players: 2, roundsToWin: 2);
      m.start();
      for (int r = 0; r < 2; r++) {
        m.tap(1);
        expect(m.endSprint(), 1);
        m.advance(1);
      }
      expect(m.matchWinner, 1);
      expect(m.scores, [0, 2]);
    });

    test('no match winner before threshold', () {
      final m = TapRaceMatch(players: 4, roundsToWin: 3);
      m.start();
      m.tap(2);
      m.endSprint();
      m.advance(2);
      expect(m.matchWinner, isNull);
    });
  });
}

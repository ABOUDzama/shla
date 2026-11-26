import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:shella/games/offline/croc_logic.dart';

class _ScriptedRandom implements Random {
  _ScriptedRandom(this.values);
  final List<int> values;
  int _i = 0;
  @override
  int nextInt(int max) => values[_i++ % values.length] % max;
  @override
  bool nextBool() => false;
  @override
  double nextDouble() => 0.0;
}

void main() {
  test('a safe pull advances the turn to the next player', () {
    // soreTooth = 5
    final g = CrocGame(playerCount: 3, random: _ScriptedRandom([5]));
    expect(g.soreTooth, 5);
    expect(g.pull(0), isFalse);
    expect(g.currentPlayer, 1);
    expect(g.pull(1), isFalse);
    expect(g.currentPlayer, 2);
  });

  test('pulled teeth cannot be pulled again', () {
    final g = CrocGame(playerCount: 2, random: _ScriptedRandom([5]));
    g.pull(0);
    expect(() => g.pull(0), throwsArgumentError);
  });

  test('the sore tooth chomps, eliminates, and resets the round', () {
    final g = CrocGame(playerCount: 3, random: _ScriptedRandom([5, 2]));
    expect(g.pull(5), isTrue); // player 0 chomped
    expect(g.eliminated, {0});
    expect(g.lastChomped, 0);
    expect(g.winner, isNull);
    // Fresh round: teeth reset, new sore tooth (2), next alive player starts.
    expect(g.standing.length, 10);
    expect(g.soreTooth, 2);
    expect(g.currentPlayer, 1);
  });

  test('elimination down to one seat crowns the champion', () {
    final g = CrocGame(playerCount: 2, random: _ScriptedRandom([5]));
    g.pull(5); // player 0 chomped, only player 1 remains
    expect(g.winner, 1);
    expect(g.isOver, isTrue);
    expect(() => g.pull(0), throwsStateError);
  });

  test('clearing every safe tooth starts a fresh round, same player', () {
    // sore 9; pull teeth 0..8 (nine safe pulls)
    final g = CrocGame(playerCount: 2, random: _ScriptedRandom([9, 3]));
    for (var t = 0; t < 9; t++) {
      expect(g.pull(t), isFalse);
    }
    // Fresh round already started with new sore 3; the lucky puller (player
    // 0) keeps the turn.
    expect(g.standing.length, 10);
    expect(g.soreTooth, 3);
    expect(g.currentPlayer, 0);
  });

  test('solo practice counts the streak and ends on the chomp, no winner', () {
    final g = CrocGame(playerCount: 1, random: _ScriptedRandom([2]));
    expect(g.pull(0), isFalse);
    expect(g.practiceStreak, 1);
    expect(g.pull(1), isFalse);
    expect(g.practiceStreak, 2);
    expect(g.pull(2), isTrue);
    expect(g.isOver, isTrue);
    expect(g.winner, isNull);
  });

  test('bot pull picks a standing tooth', () {
    final g = CrocGame(playerCount: 2, botSeats: {1}, random: _ScriptedRandom([5, 0]));
    g.pull(0); // human safe
    expect(g.currentPlayer, 1);
    final pick = g.chooseBotPull();
    expect(g.standing, contains(pick));
  });
}

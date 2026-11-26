import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:shella/games/offline/ludo_logic.dart';

class _ScriptedRandom implements Random {
  _ScriptedRandom(this.rolls);
  final List<int> rolls;
  int _i = 0;
  @override
  int nextInt(int max) => (rolls[_i++ % rolls.length] - 1).clamp(0, max - 1);
  @override
  bool nextBool() => false;
  @override
  double nextDouble() => 0.0;
}

void main() {
  test('a token needs a 6 to leave the yard', () {
    final g = LudoGame(playerCount: 2, random: _ScriptedRandom([3]));
    expect(g.rollDice(), 3);
    expect(g.legalMoves(), isEmpty);
    // No legal move: the turn passed to player 1 automatically.
    expect(g.currentPlayer, 1);
  });

  test('rolling a 6 lets a yard token out and grants another roll', () {
    final g = LudoGame(playerCount: 2, random: _ScriptedRandom([6, 2]));
    expect(g.rollDice(), 6);
    expect(g.legalMoves(), [0, 1, 2, 3]);
    expect(g.moveToken(0), isTrue); // rolls again
    expect(g.tokens[0][0], 0); // on its start square
    expect(g.currentPlayer, 0);
    expect(g.rollDice(), 2);
    expect(g.moveToken(0), isFalse); // turn passes
    expect(g.tokens[0][0], 2);
    expect(g.currentPlayer, 1);
  });

  test('landing on a single opponent on a non-safe square captures it', () {
    final g = LudoGame(playerCount: 2, random: _ScriptedRandom([3]));
    // Player 0 token sits on absolute square 4 (not safe).
    g.tokens[0][0] = 4;
    // Player 1 lands on absolute 4 from steps 40 (13+43=56 -> abs 4).
    g.currentPlayer = 1;
    g.tokens[1][0] = 40;
    g.rollDice(); // 3 -> steps 43 -> abs (13+43)%52 = 4
    expect(g.legalMoves(), contains(0));
    g.moveToken(0);
    expect(g.tokens[0][0], LudoGame.yard); // captured
    expect(g.tokens[1][0], 43);
  });

  test('safe squares protect from capture', () {
    final g = LudoGame(playerCount: 2, random: _ScriptedRandom([3]));
    g.tokens[0][0] = 8; // absolute 8 is a star (safe)
    g.currentPlayer = 1;
    g.tokens[1][0] = 44; // +3 -> 47 steps -> abs (13+47)%52 = 8
    g.rollDice();
    g.moveToken(0);
    expect(g.tokens[0][0], 8); // not captured
    expect(g.tokens[1][0], 47);
  });

  test('a block of two cannot be landed on or passed through', () {
    final g = LudoGame(playerCount: 2, random: _ScriptedRandom([5, 4, 3]));
    // Player 0 blocks absolute 10 with two tokens.
    g.tokens[0][0] = 10;
    g.tokens[0][1] = 10;
    // Player 1 at steps 45 -> abs 6.
    g.currentPlayer = 1;
    g.tokens[1][0] = 45;
    g.rollDice(); // 5 -> would pass through abs 10: illegal
    expect(g.legalMoves(), isNot(contains(0)));
    expect(g.currentPlayer, 0); // no legal move, turn passed back
    g.currentPlayer = 1;
    g.rollDice(); // 4 -> lands exactly on abs 10: illegal
    expect(g.legalMoves(), isNot(contains(0)));
    g.currentPlayer = 1;
    g.rollDice(); // 3 -> abs 9: legal
    expect(g.legalMoves(), contains(0));
  });

  test('a third consecutive 6 forfeits the turn with no move', () {
    final g = LudoGame(playerCount: 2, random: _ScriptedRandom([6, 6, 6]));
    g.rollDice();
    g.moveToken(0); // out of the yard
    g.rollDice();
    g.moveToken(1); // second 6, another token out
    expect(g.consecutiveSixes, 2);
    expect(g.rollDice(), 6); // third six: forfeit
    expect(g.currentPlayer, 1);
    expect(g.dice, isNull);
    expect(g.tokens[0][0], 0); // tokens stayed put
    expect(g.tokens[0][1], 0);
  });

  test('entering the last token with an exact roll wins the game', () {
    final g = LudoGame(playerCount: 2, random: _ScriptedRandom([1]));
    g.tokens[0] = [LudoGame.finished, LudoGame.finished, LudoGame.finished, 56];
    g.rollDice(); // 1
    expect(g.legalMoves(), [3]);
    g.moveToken(3);
    expect(g.winner, 0);
    expect(g.isOver, isTrue);
  });

  test('overshooting home needs an exact roll', () {
    final g = LudoGame(playerCount: 2, random: _ScriptedRandom([4]));
    g.tokens[0] = [LudoGame.finished, LudoGame.finished, LudoGame.finished, 54];
    g.rollDice(); // 4 > 57-54: no legal move
    expect(g.legalMoves(), isEmpty);
  });

  test('bot prefers a capture over leaving the yard', () {
    final g = LudoGame(
        playerCount: 2, botSeats: {1}, random: _ScriptedRandom([5]));
    // Bot is player 1. Its token at steps 40 can land on abs 4 and capture.
    g.tokens[0][0] = 4; // victim on a non-safe square
    g.currentPlayer = 1;
    g.tokens[1][0] = 40;
    g.rollDice(); // 5 -> steps 45 -> abs (13+45)%52 = 6... choose capture target
    // Recompute: token at 39 + 5 = 44 -> abs (13+44)%52 = 5; victim at abs 5.
    g.tokens[0][0] = 5;
    g.tokens[1][0] = 39;
    final pick = g.chooseBotMove();
    expect(pick, 0); // the capturing token, not a yard token
    g.moveToken(pick);
    expect(g.tokens[0][0], LudoGame.yard);
  });
}

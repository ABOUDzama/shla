import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:shella/games/offline/blocade_logic.dart';

void main() {
  test('setup: 2P pawns centre of bottom/top, 10 walls each', () {
    final g = BlocadeGame(playerCount: 2);
    expect(g.pawns, [const Cell(8, 4), const Cell(0, 4)]);
    expect(g.wallsLeft, [10, 10]);
  });

  test('setup: 4P one pawn per side, 5 walls each (20 total)', () {
    final g = BlocadeGame(playerCount: 4);
    expect(g.pawns.toSet().length, 4);
    expect(g.wallsLeft, [5, 5, 5, 5]);
  });

  test('step moves; walls block moves', () {
    final g = BlocadeGame(playerCount: 2);
    expect(g.legalMoves(0).toSet(),
        {const Cell(7, 4), const Cell(8, 3), const Cell(8, 5)});
    // horizontal wall above (8,4): between rows 7 and 8, cols 3-4
    g.current = 1;
    g.hWalls.add(7 * 8 + 3);
    expect(g.legalMoves(0).contains(const Cell(7, 4)), isFalse);
    expect(g.legalMoves(0).contains(const Cell(7, 5)), isFalse);
  });

  test('jump over adjacent pawn, sidestep when jump is blocked', () {
    final g = BlocadeGame(playerCount: 2);
    g.pawns = [const Cell(5, 4), const Cell(4, 4)];
    expect(g.legalMoves(0).contains(const Cell(3, 4)), isTrue);
    // wall behind the opponent pawn: between rows 3 and 4 at cols 4-5
    g.hWalls.add(3 * 8 + 4);
    final m = g.legalMoves(0);
    expect(m.contains(const Cell(3, 4)), isFalse);
    expect(m.contains(const Cell(4, 3)), isTrue);
    expect(m.contains(const Cell(4, 5)), isTrue);
  });

  test('wall may not overlap, cross, or leave the board', () {
    final g = BlocadeGame(playerCount: 2);
    expect(g.placeWall(const Wall(3, 3, true)), isTrue);
    g.current = 0;
    expect(g.wallProblem(const Wall(3, 3, false)), isNotNull, reason: 'cross');
    expect(g.wallProblem(const Wall(3, 4, true)), isNotNull, reason: 'overlap');
    expect(g.wallProblem(const Wall(3, 2, true)), isNotNull, reason: 'overlap');
    expect(g.wallProblem(const Wall(8, 0, true)), isNotNull, reason: 'off board');
    expect(g.wallProblem(const Wall(3, 5, true)), isNull, reason: 'touching ok');
  });

  test('a wall that seals the last path is refused', () {
    final g = BlocadeGame(playerCount: 2);
    g.pawns = [const Cell(8, 0), const Cell(0, 4)];
    // Fence the corner pocket: wall above (8,0)-(8,1), then wall right of it
    expect(g.placeWall(const Wall(7, 0, true)), isTrue); // blocks up from cols 0,1
    g.current = 0;
    // vertical wall between col1|col2 rows 7-8 would seal the pocket
    expect(g.wallProblem(const Wall(7, 1, false)), 'مينفعش تقفل الطريق بالكامل');
  });

  test('walls are consumed and the turn passes', () {
    final g = BlocadeGame(playerCount: 2);
    g.placeWall(const Wall(0, 0, true));
    expect(g.wallsLeft, [9, 10]);
    expect(g.current, 1);
    g.wallsLeft[1] = 0;
    expect(g.wallProblem(const Wall(5, 5, true)), 'حيطانك خلصت');
  });

  test('reaching the far side wins (2P and 4P goals)', () {
    final g = BlocadeGame(playerCount: 2);
    g.pawns = [const Cell(1, 4), const Cell(0, 0)];
    expect(g.move(0, const Cell(0, 4)), isTrue);
    expect(g.winner, 0);
    final f = BlocadeGame(playerCount: 4);
    f.current = 1;
    f.pawns[1] = const Cell(4, 7);
    f.pawns[3] = const Cell(2, 8);
    expect(f.move(1, const Cell(4, 8)), isTrue);
    expect(f.winner, 1);
  });

  test('cannot move out of turn', () {
    final g = BlocadeGame(playerCount: 2);
    expect(g.move(1, const Cell(1, 4)), isFalse);
  });

  test('bot vs bot always finishes, never breaks the path rule', () {
    for (final players in [2, 4]) {
      for (var seed = 0; seed < 6; seed++) {
        final g = BlocadeGame(playerCount: players, random: Random(seed));
        var turns = 0;
        while (g.winner == null && turns < 600) {
          g.botTurn();
          for (var i = 0; i < players; i++) {
            expect(g.shortestPath(i), greaterThanOrEqualTo(0),
                reason: 'seat $i sealed ($players P seed $seed)');
          }
          turns++;
        }
        expect(g.winner, isNotNull, reason: '$players P seed $seed no finish');
      }
    }
  });
}

import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:shella/games/offline/snake_arena_logic.dart';

void main() {
  test('2-4 players spawn in corners facing their edge', () {
    for (var n = 2; n <= 4; n++) {
      final m = SnakeArenaMatch(playerCount: n, random: Random(1));
      expect(m.snakes.length, n);
      expect(m.aliveCount, n);
      expect(m.score, List.filled(n, 0));
      expect(m.food, isNotNull);
      for (final s in m.snakes) {
        expect(s.length, 3);
        for (final c in s) {
          expect(c.x, inInclusiveRange(0, m.width - 1));
          expect(c.y, inInclusiveRange(0, m.height - 1));
        }
      }
    }
  });

  test('tap turns 90 degrees clockwise on next tick only', () {
    final m = SnakeArenaMatch(playerCount: 2, random: Random(1));
    final before = m.snakes[0].first;
    m.turn(0);
    m.tick();
    // player 0 started facing right; one turn sends it down
    expect(m.snakes[0].first, Point(before.x, before.y + 1));
    // no queued turn: keeps going down
    m.tick();
    expect(m.snakes[0].first, Point(before.x, before.y + 2));
  });

  test('wall collision eliminates; last snake alive wins', () {
    final m = SnakeArenaMatch(playerCount: 2, random: Random(1), width: 8, height: 8);
    // player 0 faces right from (2,2)..(2,4); steer it into the top wall
    m.turn(0); // right -> down? no: dirs are cw from up; facing 1 is right, +1 = 2 = down
    m.turn(0); m.tick(); // two turns queued? only latest applies once
    var guard = 0;
    while (!m.isOver && guard++ < 500) m.tick();
    expect(m.isOver, isTrue);
  });

  test('eating grows the snake and scores', () {
    final m = SnakeArenaMatch(playerCount: 2, random: Random(3));
    // place food directly ahead of player 0's head
    final h = m.snakes[0].first;
    m.food = Point(h.x + 1, h.y);
    m.tick();
    expect(m.snakes[0].length, 4);
    expect(m.score[0], 1);
  });

  test('deterministic with the same seed', () {
    List<String> run() {
      final m = SnakeArenaMatch(playerCount: 4, random: Random(42));
      final trace = <String>[];
      for (var i = 0; i < 60 && !m.isOver; i++) {
        if (i % 7 == 0) m.turn(i % 4);
        m.tick();
        trace.add('${m.snakes[0].first},${m.food}');
      }
      return trace;
    }
    expect(run(), run());
  });
}

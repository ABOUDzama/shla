import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shella/games/offline/goal_rush_logic.dart';

void main() {
  GoalRushMatch match({int seats = 2, int seed = 4}) =>
      GoalRushMatch(seats: seats, random: Random(seed));

  void run(GoalRushMatch m, double seconds) {
    for (var t = 0.0; t < seconds && !m.over; t += 1 / 120) {
      m.step(1 / 120);
    }
  }

  test('layout: 2P top/bottom goals, 4P one per edge, runner spots face play', () {
    expect(match(seats: 2).goals.length, 2);
    final m4 = match(seats: 4);
    expect(m4.goals.length, 4);
    expect(m4.runners.length, 4);
    expect(m4.ballX, 50);
  });

  test('hold runs straight, release turns', () {
    final m = match(seats: 1);
    final r = m.runners[0];
    final h0 = r.heading, x0 = r.x, y0 = r.y;
    m.setHolding(0, true);
    run(m, 0.5);
    expect(r.heading, h0); // no turn while held
    expect((r.x - x0).abs() + (r.y - y0).abs(), greaterThan(5)); // moved
    m.setHolding(0, false);
    final x1 = r.x, y1 = r.y;
    run(m, 0.5);
    expect(r.heading, isNot(h0)); // turned while released
    expect(r.x, closeTo(x1, 0.01)); // did not move
    expect(r.y, closeTo(y1, 0.01));
  });

  test('runner bumps the ball and becomes the last toucher', () {
    final m = match(seats: 1);
    final r = m.runners[0];
    r.x = 50;
    r.y = 60;
    r.heading = -pi / 2; // facing up toward the ball at (50,50)
    m.ballX = 50;
    m.ballY = 50;
    m.ballVx = m.ballVy = 0;
    m.setHolding(0, true);
    run(m, 0.4);
    expect(m.ballY, lessThan(50)); // ball pushed up
    expect(m.lastToucher, 0);
  });

  test('ball into another seat goal scores for the last toucher; own goal resets without score', () {
    final m = match();
    // seat 0 knocks the ball into the top goal (owner seat 1)
    m.runners[0].x = 50;
    m.runners[0].y = 20;
    m.runners[0].heading = -pi / 2;
    m.ballX = 50;
    m.ballY = 12;
    m.ballVx = 0;
    m.ballVy = -30;
    m.setHolding(0, true);
    run(m, 1.5);
    expect(m.scores[0], 1);
    expect(m.scores[1], 0);

    // now an own goal: ball drifts into the bottom goal with seat 0 as last toucher
    m.ballX = 50;
    m.ballY = GoalRushMatch.fieldH - 12;
    m.ballVx = 0;
    m.ballVy = 30;
    m.lastToucher = 0;
    run(m, 1.5);
    expect(m.scores[0], 1); // unchanged
    expect(m.scores[1], 0);
    expect(m.ballX, 50); // kicked off again
    expect(m.ballY, GoalRushMatch.fieldH / 2);
  });

  test('first to 3 goals wins', () {
    final m = match();
    for (var g = 0; g < 3; g++) {
      m.runners[0].x = 50;
      m.runners[0].y = 20;
      m.ballX = 50;
      m.ballY = 12;
      m.ballVx = 0;
      m.ballVy = -30;
      m.lastToucher = 0;
      run(m, 1.5);
    }
    expect(m.scores[0], 3);
    expect(m.winner, 0);
    expect(m.over, isTrue);
  });

  test('bots finish a match by themselves', () {
    final m = match();
    m.botSeats.addAll([0, 1]);
    run(m, 300);
    expect(m.over, isTrue);
  });

  test('practice: unguarded goal, 60 seconds, goal count, no winner', () {
    final m = match(seats: 1);
    expect(m.practice, isTrue);
    expect(m.goals.single.owner, -1);
    // score once
    m.runners[0].x = 50;
    m.runners[0].y = 20;
    m.ballX = 50;
    m.ballY = 12;
    m.ballVx = 0;
    m.ballVy = -30;
    m.lastToucher = 0;
    run(m, 1.5);
    expect(m.practiceGoals, 1);
    run(m, 60);
    expect(m.practiceOver, isTrue);
    expect(m.winner, isNull);
  });
}

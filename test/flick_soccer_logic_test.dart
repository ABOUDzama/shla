import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shella/games/offline/flick_soccer_logic.dart';

void main() {
  FlickSoccerMatch match({int seats = 2, int seed = 3}) =>
      FlickSoccerMatch(seats: seats, random: Random(seed));

  void runUntilSettled(FlickSoccerMatch m, [int maxTicks = 12000]) {
    var t = 0;
    while (!m.settled && !m.over && t < maxTicks) {
      m.step();
      t++;
    }
  }

  test('layout: 2P has top/bottom goals, 4P has one per edge', () {
    expect(match(seats: 2).goals.length, 2);
    expect(match(seats: 3).goals.length, 3);
    final m4 = match(seats: 4);
    expect(m4.goals.length, 4);
    expect(m4.discs.length, 4);
    expect(m4.ball.x, 50);
    expect(m4.ball.y, 50);
  });

  test('flick launches the disc opposite the drag and only the current seat', () {
    final m = match();
    expect(m.currentSeat, 0);
    m.flick(1, 0, 10); // wrong seat: ignored
    expect(m.discs[1].moving, isFalse);
    m.flick(0, 0, 12); // pull down -> disc launches up
    expect(m.discs[0].vy, lessThan(0));
    expect(m.discs[0].moving, isTrue);
  });

  test('friction stops everything and the turn passes', () {
    final m = match();
    m.flick(0, 0, 10);
    runUntilSettled(m);
    expect(m.settled, isTrue);
    expect(m.currentSeat, 1);
    m.flick(1, 0, -10);
    runUntilSettled(m);
    expect(m.currentSeat, 0);
  });

  test('disc flicks the ball: ball moves after a collision', () {
    final m = match();
    // put the disc right behind the ball and flick straight at it
    m.discs[0].x = 50;
    m.discs[0].y = 60;
    m.flick(0, 0, 20);
    runUntilSettled(m);
    expect(m.ball.y, isNot(50)); // ball got knocked off center
  });

  test('ball into the top goal scores for the flicker', () {
    final m = match();
    // disc directly below the ball, flick straight up: ball goes into the top
    // goal (keeper moved aside to isolate goal detection from blocking)
    m.discs[1].x = 20;
    m.discs[0].x = 50;
    m.discs[0].y = 58;
    m.flick(0, 0, 22);
    runUntilSettled(m);
    expect(m.scores[0], 1);
    expect(m.scores[1], 0);
    // conceder (seat 1, top goal owner) kicks off
    expect(m.currentSeat, 1);
  });

  test('own goal scores for nobody and play resets', () {
    final m = match();
    m.discs[0].x = 50;
    m.discs[0].y = 42;
    m.flick(0, 0, -22); // flick down: ball toward own bottom goal
    runUntilSettled(m);
    expect(m.scores[0], 0);
    expect(m.scores[1], 0);
    expect(m.ball.x, 50); // reset to center
  });

  test('first to 3 goals wins the match', () {
    final m = match();
    for (var g = 0; g < 3; g++) {
      if (m.currentSeat != 0) {
        // the other seat wastes its turn with a soft sideways flick
        m.flick(m.currentSeat, 6, 0);
        runUntilSettled(m);
      }
      // tee up the same scoring shot for seat 0 (keeper aside)
      m.discs[1].x = 20;
      m.discs[1].y = 22;
      m.ball.x = 50;
      m.ball.y = 50;
      m.ball.vx = m.ball.vy = 0;
      m.discs[0].x = 50;
      m.discs[0].y = 58;
      m.flick(0, 0, 22);
      runUntilSettled(m);
    }
    expect(m.scores[0], 3);
    expect(m.winner, 0);
    expect(m.over, isTrue);
  });

  test('bots can finish a full match', () {
    final m = match(seats: 2);
    m.botSeats.addAll([0, 1]);
    var guard = 0;
    while (!m.over && guard < 400) {
      final aim = m.botAim(m.currentSeat);
      m.flick(m.currentSeat, aim[0], aim[1]);
      runUntilSettled(m);
      guard++;
    }
    expect(m.over, isTrue);
  });

  test('practice: unlimited target shooting, ends after 10 flicks with a goal count', () {
    final m = match(seats: 1);
    expect(m.practice, isTrue);
    expect(m.goals.single.owner, -1);
    for (var i = 0; i < 10; i++) {
      m.discs[0].x = 50;
      m.discs[0].y = 58;
      m.flick(0, 0, 22);
      runUntilSettled(m);
    }
    expect(m.practiceOver, isTrue);
    expect(m.practiceGoals, greaterThan(0));
    expect(m.winner, isNull);
  });
}

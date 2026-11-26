import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:shella/games/offline/obstacle_logic.dart';

void main() {
  test('the same seed generates the same course', () {
    final a = ObstacleRun(random: Random(42));
    final b = ObstacleRun(random: Random(42));
    expect(a.obstacles, b.obstacles);
    expect(a.obstacles.length, greaterThan(3));
  });

  test('running without jumping crashes into an obstacle', () {
    final r = ObstacleRun(random: Random(42));
    var steps = 0;
    while (!r.done && steps < 60 * 30) {
      r.step(1 / 60);
      steps++;
    }
    expect(r.crashed, isTrue);
    expect(r.distance, lessThan(r.courseLength));
  });

  test('a bot-guided run finishes the course', () {
    final r = ObstacleRun(random: Random(42));
    var steps = 0;
    while (!r.done && steps < 60 * 60) {
      if (r.botShouldJump()) r.jump();
      r.step(1 / 60);
      steps++;
    }
    expect(r.finished, isTrue);
    expect(r.time, greaterThan(5));
  });

  test('jumping lifts the runner and lands back', () {
    final r = ObstacleRun(random: Random(42));
    r.jump();
    expect(r.onGround, isFalse);
    var steps = 0;
    while (!r.onGround && steps < 300) {
      r.step(1 / 60);
      steps++;
    }
    expect(r.onGround, isTrue);
    expect(r.playerY, ObstacleRun.groundY);
  });

  test('no double jump while airborne', () {
    final r = ObstacleRun(random: Random(42));
    r.jump();
    final v = r.velocity;
    r.jump(); // ignored
    expect(r.velocity, v);
  });

  test('finishing sets finished and stops the clock', () {
    final r = ObstacleRun(random: Random(42), courseLength: 300);
    var steps = 0;
    while (!r.done && steps < 60 * 10) {
      if (r.botShouldJump()) r.jump();
      r.step(1 / 60);
      steps++;
    }
    expect(r.finished, isTrue);
    final t = r.time;
    r.step(1 / 60);
    expect(r.time, t);
  });
}

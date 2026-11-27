import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:shella/games/offline/ballshoot_logic.dart';

void main() {
  test('balls stream through the round and the round ends after 12', () {
    final r = BallShootRound(random: Random(5));
    expect(r.ball, isNotNull);
    var steps = 0;
    var sawMultiple = false;
    while (!r.over && steps < 60 * 120) {
      r.step(1 / 60);
      steps++;
      if (r.balls.length > 1) sawMultiple = true;
    }
    expect(r.over, isTrue);
    expect(r.launched, 12);
    expect(r.misses, 12); // nobody tapped
    expect(sawMultiple, isTrue); // several targets fly at once
  });

  test('tapping the ball scores a hit', () {
    final r = BallShootRound(random: Random(5));
    // Step until the ball is well inside the world.
    var steps = 0;
    while (steps < 60 * 3) {
      r.step(1 / 60);
      steps++;
      final b = r.ball;
      if (b != null && b.$2 < 400 && b.$2 > 100) {
        expect(r.tapAt(b.$1, b.$2), isTrue);
        expect(r.hits, 1);
        return;
      }
    }
    fail('ball never reached a tappable position');
  });

  test('tapping empty space is a miss, not a hit', () {
    final r = BallShootRound(random: Random(5));
    r.step(1 / 60);
    expect(r.tapAt(10, 10), isFalse);
    expect(r.hits, 0);
    expect(r.taps, 1);
  });

  test('same seed reproduces the same stream', () {
    final a = BallShootRound(random: Random(9));
    final b = BallShootRound(random: Random(9));
    expect(a.balls, b.balls);
  });

  test('a perfect bot hits most balls', () {
    final r = BallShootRound(random: Random(5));
    var steps = 0;
    double visible = 0;
    while (!r.over && steps < 60 * 180) {
      r.step(1 / 60);
      steps++;
      visible = r.ball == null ? 0 : visible + 1 / 60;
      final tap = r.botTap(sinceVisible: visible);
      if (tap != null) r.tapAt(tap.$1, tap.$2);
    }
    expect(r.hits, greaterThanOrEqualTo(9));
  });
}

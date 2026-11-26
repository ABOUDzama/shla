import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:shella/games/offline/flappy_logic.dart';

void main() {
  test('the bird falls and crashes on the ground without flapping', () {
    final r = FlappyRun(random: Random(1));
    r.flap(); // starts the run
    var steps = 0;
    while (!r.crashed && steps < 60 * 10) {
      r.step(1 / 60);
      steps++;
    }
    expect(r.crashed, isTrue);
    expect(r.score, 0);
  });

  test('flapping lifts the bird', () {
    final r = FlappyRun(random: Random(1));
    r.flap();
    final y0 = r.birdY;
    r.step(1 / 60);
    expect(r.birdY, lessThan(y0));
  });

  test('the ceiling clamps the bird instead of crashing', () {
    final r = FlappyRun(random: Random(1));
    r.flap();
    for (var i = 0; i < 30; i++) {
      r.step(1 / 60);
    }
    expect(r.birdY, greaterThanOrEqualTo(FlappyRun.birdRadius));
    expect(r.crashed, isFalse);
  });

  test('a bot-guided run survives and scores at least 2 pipes', () {
    final r = FlappyRun(random: Random(7));
    r.flap();
    var steps = 0;
    while (!r.crashed && r.score < 3 && steps < 60 * 30) {
      r.step(1 / 60);
      if (r.botShouldFlap()) r.flap();
      steps++;
    }
    expect(r.score, greaterThanOrEqualTo(2));
  });

  test('crashing into a pipe ends the run', () {
    // A run where the bird never flaps after start must eventually hit
    // either the ground (asserted above) — here verify a pipe hit: hold the
    // bird steady at a fixed wrong height is not possible, so simulate a
    // run with a scripted mid-height hover that ignores the gaps.
    final r = FlappyRun(random: Random(3), gapHeight: 90);
    r.flap();
    var steps = 0;
    // Flap only to stay aloft, never aligned with gaps: keep bird near top.
    while (!r.crashed && steps < 60 * 30) {
      r.step(1 / 60);
      if (r.birdY > 120) r.flap();
      steps++;
    }
    expect(r.crashed, isTrue);
  });

  test('botShouldFlap is true when the bird is below the gap center', () {
    final r = FlappyRun(random: Random(1));
    r.pipes.add((200, 200));
    r.birdY = 400; // below the gap
    expect(r.botShouldFlap(), isTrue);
    r.birdY = 100; // above the gap
    expect(r.botShouldFlap(), isFalse);
  });
}

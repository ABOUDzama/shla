import 'package:flutter_test/flutter_test.dart';
import 'package:shella/games/offline/minigolf_logic.dart';

void main() {
  test('a straight full-power putt sinks the open hole in one', () {
    final h = MiniGolfHole(ballStart: (180, 460), holePos: (180, 90));
    h.shoot(-90, 0.55); // straight up
    var steps = 0;
    while (!h.sunk && !h.resting && steps < 60 * 10) {
      h.step(1 / 60);
      steps++;
    }
    expect(h.sunk, isTrue);
    expect(h.strokes, 1);
  });

  test('friction stops a weak shot short of the hole', () {
    final h = MiniGolfHole(ballStart: (180, 460), holePos: (180, 90));
    h.shoot(-90, 0.1);
    var steps = 0;
    while (!h.resting && steps < 60 * 10) {
      h.step(1 / 60);
      steps++;
    }
    expect(h.sunk, isFalse);
    expect(h.ballY, greaterThan(150));
  });

  test('walls bounce the ball back', () {
    final h = MiniGolfHole(
      ballStart: (180, 460),
      holePos: (180, 90),
      walls: const [Wall(110, 250, 360, 268)],
    );
    h.shoot(-90, 0.5); // straight into the wall
    var steps = 0;
    while (!h.resting && !h.sunk && steps < 60 * 10) {
      h.step(1 / 60);
      steps++;
    }
    expect(h.sunk, isFalse);
    // Bounced back below the wall.
    expect(h.ballY, greaterThan(268));
  });

  test('bounds keep the ball on the course', () {
    final h = MiniGolfHole(ballStart: (180, 460), holePos: (180, 90));
    h.shoot(0, 1.0); // full power to the right wall
    var steps = 0;
    while (!h.resting && !h.sunk && steps < 60 * 10) {
      h.step(1 / 60);
      steps++;
    }
    expect(h.ballX, lessThanOrEqualTo(360 - MiniGolfHole.ballRadius + 0.01));
  });

  test('shooting is blocked while the ball is moving', () {
    final h = MiniGolfHole(ballStart: (180, 460), holePos: (180, 90));
    h.shoot(-90, 0.5);
    h.shoot(0, 1.0); // ignored: ball in motion
    expect(h.strokes, 1);
  });

  test('the shella course has 3 holes', () {
    expect(shellaCourse().length, 3);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:shella/games/offline/penguins_logic.dart';

void main() {
  test('a flat full-power shot clears nothing and lands in the water', () {
    final d = PenguinDuel();
    d.shoot(0, 1.0);
    String? result;
    var steps = 0;
    while (result == null && steps < 60 * 10) {
      result = d.step(1 / 60);
      steps++;
    }
    expect(result, isNotNull);
    expect(d.winner, isNull);
  });

  test('a well-aimed shot hits the rival and wins', () {
    final d = PenguinDuel();
    final (angle, power) = d.botAim();
    d.shoot(angle, power);
    String? result;
    var steps = 0;
    while (result == null && steps < 60 * 10) {
      result = d.step(1 / 60);
      steps++;
    }
    expect(result, 'hit');
    expect(d.winner, 0);
  });

  test('the iceberg blocks a low shot and passes the turn', () {
    final d = PenguinDuel();
    // Low arc straight at the berg.
    d.shoot(12, 0.55);
    String? result;
    var steps = 0;
    while (result == null && steps < 60 * 10) {
      result = d.step(1 / 60);
      steps++;
    }
    expect(result, isNotNull);
    expect(d.winner, isNull);
    expect(d.turn, 1); // turn passed
  });

  test('shooting is blocked while a ball is flying', () {
    final d = PenguinDuel();
    d.shoot(45, 0.5);
    expect(d.flying, isTrue);
    final vx = d.vx;
    d.shoot(80, 1.0); // ignored
    expect(d.vx, vx);
  });

  test('a bot with big error can miss', () {
    final d = PenguinDuel();
    final (angle, power) = d.botAim(error: -30);
    d.shoot(angle, power);
    String? result;
    var steps = 0;
    while (result == null && steps < 60 * 10) {
      result = d.step(1 / 60);
      steps++;
    }
    expect(result, isNot('hit'));
    expect(d.turn, 1);
  });
}

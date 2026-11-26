import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:shella/games/offline/orbit_logic.dart';

void main() {
  test('meteors spawn and spiral inward', () {
    final r = OrbitRun(random: Random(4));
    for (var i = 0; i < 60 * 3; i++) {
      r.step(1 / 60);
    }
    expect(r.meteors, isNotEmpty);
    final r0 = r.meteors.first.$2;
    r.step(1);
    if (r.meteors.isNotEmpty) {
      expect(r.meteors.first.$2, lessThanOrEqualTo(r0));
    }
  });

  test('hopping toggles rings', () {
    final r = OrbitRun(random: Random(4));
    expect(r.ring, 0);
    r.hop();
    expect(r.ring, 1);
    r.hop();
    expect(r.ring, 0);
  });

  test('a stationary player eventually gets hit', () {
    final r = OrbitRun(random: Random(4));
    var steps = 0;
    while (!r.crashed && steps < 60 * 180) {
      r.step(1 / 60);
      steps++;
    }
    expect(r.crashed, isTrue);
  });

  test('a hopping bot survives much longer than 30 seconds', () {
    final r = OrbitRun(random: Random(4));
    var steps = 0;
    while (!r.crashed && steps < 60 * 60) {
      if (r.botShouldHop()) r.hop();
      r.step(1 / 60);
      steps++;
    }
    expect(r.time, greaterThan(30));
  });

  test('same seed reproduces the meteor stream', () {
    final a = OrbitRun(random: Random(8));
    final b = OrbitRun(random: Random(8));
    for (var i = 0; i < 120; i++) {
      a.step(1 / 60);
      b.step(1 / 60);
    }
    expect(a.meteors, b.meteors);
  });

  test('hop is ignored after crashing', () {
    final r = OrbitRun(random: Random(4));
    while (!r.crashed && r.time < 180) {
      r.step(1 / 60);
    }
    final ring = r.ring;
    r.hop();
    expect(r.ring, ring);
  });
}

import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:shella/games/offline/koala_logic.dart';

void main() {
  test('firing adds a laser that climbs and expires', () {
    final r = KoalaRun(random: Random(2));
    r.fire();
    expect(r.lasers.length, 1);
    final y0 = r.lasers.first.$2;
    r.step(1 / 60);
    expect(r.lasers.first.$2, lessThan(y0));
    var steps = 0;
    while (r.lasers.isNotEmpty && steps < 60 * 3) {
      r.step(1 / 60);
      steps++;
    }
    expect(r.lasers, isEmpty);
  });

  test('fire cooldown blocks a second immediate shot', () {
    final r = KoalaRun(random: Random(2));
    r.fire();
    r.fire();
    expect(r.lasers.length, 1);
  });

  test('meteors spawn on the seeded stream', () {
    final a = KoalaRun(random: Random(6));
    final b = KoalaRun(random: Random(6));
    for (var i = 0; i < 180; i++) {
      a.step(1 / 60);
      b.step(1 / 60);
    }
    expect(a.meteors, b.meteors);
    expect(a.meteors, isNotEmpty);
  });

  test('the ship patrols and bounces at the edges', () {
    final r = KoalaRun(random: Random(2));
    var steps = 0;
    var sawLeft = false, sawRight = false;
    while (steps < 60 * 12 && !r.crashed) {
      r.step(1 / 60);
      steps++;
      if (r.shipDir == -1) sawRight = true;
      if (r.shipDir == 1 && r.shipX < 60) sawLeft = true;
    }
    expect(sawRight, isTrue);
  });

  test('a laser destroys a meteor and scores', () {
    final r = KoalaRun(random: Random(2));
    // Drop a meteor right above the ship and fire straight up.
    r.meteors.add((r.shipX, 300, 60));
    r.fire();
    var steps = 0;
    while (r.hits == 0 && steps < 60 * 3 && !r.crashed) {
      r.step(1 / 60);
      steps++;
    }
    expect(r.hits, 1);
  });

  test('an undodged meteor eventually crashes the ship', () {
    final r = KoalaRun(random: Random(3));
    var steps = 0;
    while (!r.crashed && steps < 60 * 120) {
      r.step(1 / 60);
      steps++;
    }
    expect(r.crashed, isTrue);
  });
}

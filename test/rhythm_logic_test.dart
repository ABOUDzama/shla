import 'package:flutter_test/flutter_test.dart';
import 'package:shella/games/offline/rhythm_logic.dart';

void main() {
  group('RhythmGenerator', () {
    test('level 1 has 4 claps; clap count grows and caps at 8', () {
      final g = RhythmGenerator(seed: 7);
      expect(g.next(1).claps, 4);
      expect(g.next(2).claps, 5);
      expect(g.next(10).claps, RhythmGenerator.maxClaps);
    });

    test('gaps stay physically clappable and tempo tightens', () {
      final g = RhythmGenerator(seed: 11);
      final early = g.next(1);
      final late = g.next(6);
      for (final p in [early, late]) {
        for (final gap in p.intervalsMs) {
          expect(gap, greaterThanOrEqualTo(160));
          expect(gap % 20, 0);
        }
      }
      expect(late.totalMs / late.claps,
          lessThan(early.totalMs / early.claps));
    });

    test('deterministic for the same seed', () {
      final a = RhythmGenerator(seed: 42).next(3);
      final b = RhythmGenerator(seed: 42).next(3);
      expect(a.intervalsMs, b.intervalsMs);
    });
  });

  group('scoreAttempt', () {
    final pattern = const RhythmPattern([400, 400, 800]); // onsets 0,400,800,1600

    test('a perfect imitation scores full marks', () {
      final s = scoreAttempt(pattern, [0, 400, 800, 1600]);
      expect(s.points, s.maxPoints);
      expect(s.accuracy, 100);
      expect(s.passed, isTrue);
    });

    test('a late start is aligned, not punished', () {
      final s = scoreAttempt(pattern, [500, 900, 1300, 2100]);
      expect(s.accuracy, 100);
    });

    test('small timing errors still pass with lower accuracy', () {
      final s = scoreAttempt(pattern, [0, 600, 1000, 1800]);
      expect(s.errorsMs, [0, 200, 200, 200]);
      expect(s.points, 3 + 2 + 2 + 2); // one perfect, three good
      expect(s.passed, isTrue);
    });

    test('missing a clap and wild onsets fail', () {
      final s = scoreAttempt(pattern, [0, 1200]);
      expect(s.errorsMs[0], 0);
      expect(s.errorsMs[3], isNull);
      expect(s.passed, isFalse);
    });

    test('extra onsets are penalized', () {
      final s = scoreAttempt(pattern, [0, 400, 800, 1100, 1600]);
      expect(s.points, s.maxPoints - 1);
    });

    test('empty attempt scores zero', () {
      final s = scoreAttempt(pattern, const []);
      expect(s.points, 0);
      expect(s.accuracy, 0);
    });
  });
}

/// تحدّي الإيقاع: pure rhythm-pattern and scoring logic.
///
/// The phone plays a short clap pattern; each player takes a turn imitating
/// it (claps at the mic, or taps in the clearly-labeled tap mode). Timing of
/// the player's onsets is compared against the pattern's onsets.
library;

import 'dart:math';

/// One rhythm pattern: the gaps (ms) between consecutive claps.
/// The first clap sounds at t=0, so clap count = intervals.length + 1.
class RhythmPattern {
  final List<int> intervalsMs;
  const RhythmPattern(this.intervalsMs);

  int get claps => intervalsMs.length + 1;

  /// Absolute onset times of each clap, first at 0.
  List<int> get onsetsMs {
    final out = <int>[0];
    var t = 0;
    for (final g in intervalsMs) {
      t += g;
      out.add(t);
    }
    return out;
  }

  int get totalMs => intervalsMs.fold(0, (a, b) => a + b);
}

/// Scoring windows (ms of absolute timing error per clap).
class RhythmScoring {
  static const int perfectMs = 120;
  static const int goodMs = 250;
  static const int missWindowMs = 350;

  static const int perfectPts = 3;
  static const int goodPts = 2;
  static const int okPts = 1;
}

class RhythmScore {
  /// Points earned (0 .. 3*claps).
  final int points;

  /// Max possible points for this pattern.
  final int maxPoints;

  /// Per-clap absolute error in ms, null when that clap was missed.
  final List<int?> errorsMs;

  const RhythmScore(this.points, this.maxPoints, this.errorsMs);

  /// 0..100 percentage of the max.
  int get accuracy =>
      maxPoints == 0 ? 0 : ((points / maxPoints) * 100).round();

  bool get passed => accuracy >= 50;
}

/// Deterministic pattern generator. Level 1 is short and slow; each level
/// adds a clap (cap 8) and tightens the tempo.
class RhythmGenerator {
  final Random _random;
  RhythmGenerator({int? seed}) : _random = seed != null ? Random(seed) : Random();

  static const int maxClaps = 8;

  RhythmPattern next(int level) {
    final claps = min(3 + level, maxClaps);
    // Base gap shrinks with level but never below 260ms so humans can keep up.
    final base = max(260, 520 - level * 30);
    final gaps = <int>[];
    for (var i = 0; i < claps - 1; i++) {
      // Mostly straight beats, some doubles and half-time swings.
      final roll = _random.nextDouble();
      double factor;
      if (roll < 0.60) {
        factor = 1.0;
      } else if (roll < 0.82) {
        factor = 2.0;
      } else {
        factor = 0.5;
      }
      var gap = (base * factor).round();
      // Snap to a 20ms grid and keep gaps physically clappable.
      gap = (gap / 20).round() * 20;
      if (factor == 0.5) gap = max(160, gap);
      gaps.add(gap);
    }
    return RhythmPattern(gaps);
  }
}

/// Scores one attempt. [attemptOnsetsMs] are the player's clap/tap times in
/// the same clock as the pattern's playback start (first pattern clap at 0).
/// The player's first onset is aligned to 0 before comparing, so a late
/// start is not punished; only the rhythm itself counts.
RhythmScore scoreAttempt(RhythmPattern pattern, List<int> attemptOnsetsMs) {
  final expected = pattern.onsetsMs;
  final errors = List<int?>.filled(expected.length, null);
  if (attemptOnsetsMs.isEmpty) {
    return RhythmScore(0, expected.length * RhythmScoring.perfectPts, errors);
  }
  final offset = attemptOnsetsMs.first;
  final actual = attemptOnsetsMs.map((t) => t - offset).toList();

  var points = 0;
  final used = List<bool>.filled(actual.length, false);
  for (var i = 0; i < expected.length; i++) {
    var best = -1;
    var bestErr = RhythmScoring.missWindowMs + 1;
    for (var j = 0; j < actual.length; j++) {
      if (used[j]) continue;
      final err = (actual[j] - expected[i]).abs();
      if (err < bestErr) {
        bestErr = err;
        best = j;
      }
    }
    if (best >= 0 && bestErr <= RhythmScoring.missWindowMs) {
      used[best] = true;
      errors[i] = bestErr;
      if (bestErr <= RhythmScoring.perfectMs) {
        points += RhythmScoring.perfectPts;
      } else if (bestErr <= RhythmScoring.goodMs) {
        points += RhythmScoring.goodPts;
      } else {
        points += RhythmScoring.okPts;
      }
    }
  }
  // Extra onsets beyond the pattern claps are sloppy: -1 each, floor at 0.
  final extra = actual.length - expected.length;
  if (extra > 0) points = max(0, points - extra);
  return RhythmScore(points, expected.length * RhythmScoring.perfectPts, errors);
}

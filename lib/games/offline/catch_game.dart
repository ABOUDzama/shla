import 'dart:math';

/// Pure logic for اقطفها (Grab the Fish-style timing game), kept separate
/// from the widget so it can be unit-tested without pumping frames.
///
/// A marker rotates around a ring split into one colored arc per player.
/// A player taps when the marker is inside their arc to score; tapping
/// while it is outside costs nothing but scores nothing. First to
/// [targetScore] wins.
class CatchMatch {
  CatchMatch({
    required this.playerCount,
    this.targetScore = 5,
    this.startAngle = 0.0,
  }) : scores = List<int>.filled(playerCount, 0);

  final int playerCount;
  final int targetScore;
  final double startAngle;
  final List<int> scores;

  int? matchWinner;

  /// The arc owned by [player], in degrees [0, 360). Player 0 starts at
  /// [startAngle] and arcs proceed clockwise in equal shares.
  ({double from, double to}) zoneOf(int player) {
    final slice = 360.0 / playerCount;
    final from = (startAngle + slice * player) % 360;
    final to = (from + slice) % 360;
    return (from: from, to: to);
  }

  /// True when [angle] (degrees, normalized) lies inside [player]'s arc.
  bool inZone(int player, double angle) {
    final a = angle % 360;
    final z = zoneOf(player);
    if (z.from < z.to) {
      return a >= z.from && a < z.to;
    }
    // Arc wraps past 360.
    return a >= z.from || a < z.to;
  }

  /// Registers a tap for [player] at marker position [angle]. Returns true
  /// when the tap scores.
  bool tap(int player, double angle) {
    if (matchWinner != null) return false;
    if (!inZone(player, angle)) return false;
    scores[player]++;
    if (scores[player] >= targetScore) matchWinner = player;
    return true;
  }
}

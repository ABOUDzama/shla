/// Pure logic for Shla Sumo (سومو الشلة), kept separate from the widget so
/// it can be unit-tested without pumping frames.
///
/// Two players share one phone. Each tap pushes the wrestlers toward the
/// opponent's edge. Push the opponent fully out (position reaches ±1) to
/// win, or be ahead when time runs out.
class SumoMatch {
  SumoMatch({this.pushStep = 0.02, this.roundSeconds = 30});

  /// How far one tap moves the ring, as a fraction of half the ring.
  final double pushStep;

  /// Round length; whoever is ahead when it ends wins.
  final int roundSeconds;

  /// Ring position: 0 is center, +1 is player 2's edge out, -1 player 1's.
  double position = 0;

  /// Number of pushes each player landed, for stats/animations.
  final List<int> taps = [0, 0];

  int? winner;

  bool get isOver => winner != null;

  /// Registers a tap for [player] (0 or 1). Player 0 pushes the position
  /// up (toward player 1's edge at -1)... player 0 sits at the bottom and
  /// shoves the opponent upward, so player 0's taps move the position
  /// toward -1 and player 1's taps move it toward +1.
  void tap(int player) {
    if (isOver) return;
    taps[player]++;
    position += player == 0 ? -pushStep : pushStep;
    position = position.clamp(-1.0, 1.0);
    if (position <= -1.0) winner = 0;
    if (position >= 1.0) winner = 1;
  }

  /// Resolves the round when the timer expires: the player who pushed the
  /// ring further into the opponent's half wins. A perfectly centered ring
  /// goes to whoever tapped more; a true tie has no winner (replay).
  void timeUp() {
    if (isOver) return;
    if (position < 0) {
      winner = 0;
    } else if (position > 0) {
      winner = 1;
    } else if (taps[0] != taps[1]) {
      winner = taps[0] > taps[1] ? 0 : 1;
    }
  }
}

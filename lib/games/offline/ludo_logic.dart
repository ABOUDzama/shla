import 'dart:math';

/// لودو الشلة — classic Ludo rules as a pure, testable state machine.
///
/// Board model: 52 main-track squares; player `p` enters at absolute square
/// `p * 13`. Each of a player's 4 tokens is measured in steps from its own
/// start square: `-1` = in the yard, `0..50` = on the main track,
/// `51..56` = the home column, `57` = finished (needs the exact roll).
///
/// Classic rules implemented:
/// * A 6 is required to move a token out of the yard.
/// * Rolling a 6 grants another roll; a third consecutive 6 forfeits the
///   turn with no move.
/// * Landing on a single opponent token (on a non-safe square) sends it back
///   to its yard.
/// * Two or more same-color tokens on one square form a block: opponents can
///   neither capture it nor pass through or land on it.
/// * Start squares (0, 13, 26, 39) and star squares (8, 21, 34, 47) are safe:
///   no captures there.
class LudoGame {
  LudoGame({
    required this.playerCount,
    Set<int> botSeats = const {},
    Random? random,
  })  : assert(playerCount >= 2 && playerCount <= 4),
        botSeats = Set.of(botSeats),
        _random = random ?? Random() {
    tokens = List.generate(playerCount, (_) => List.filled(4, yard));
  }

  static const int yard = -1;
  static const int finished = 57;

  final int playerCount;
  final Set<int> botSeats;
  final Random _random;

  /// Steps per token: tokens[player][tokenIndex].
  late final List<List<int>> tokens;

  int currentPlayer = 0;

  /// The rolled value, or null when the current player has not rolled yet.
  int? dice;

  int _sixes = 0;

  /// Set once a player brings all 4 tokens home.
  int? winner;

  bool get isOver => winner != null;

  /// The value of the last roll that granted the current turn (for UI).
  int get consecutiveSixes => _sixes;

  /// Absolute main-track square for [steps] of [player], or null when the
  /// token is not on the shared track (yard, home column, finished).
  static int? absoluteSquare(int player, int steps) {
    if (steps < 0 || steps > 50) return null;
    return (player * 13 + steps) % 52;
  }

  static const Set<int> _safeSquares = {0, 8, 13, 21, 26, 34, 39, 47};

  static bool isSafeSquare(int absolute) => _safeSquares.contains(absolute);

  /// True when [player] has 2+ own tokens on absolute square [square].
  bool hasBlock(int player, int square) {
    var count = 0;
    for (final t in tokens[player]) {
      if (absoluteSquare(player, t) == square) count++;
      if (count >= 2) return true;
    }
    return false;
  }

  bool _opponentBlockAt(int player, int square) {
    for (var p = 0; p < playerCount; p++) {
      if (p == player) continue;
      if (hasBlock(p, square)) return true;
    }
    return false;
  }

  /// Rolls the dice for the current player. Returns the value.
  /// A third consecutive 6 forfeits the turn immediately (dice cleared,
  /// turn passed) and returns 6.
  int rollDice() {
    if (dice != null || isOver) {
      throw StateError('dice already rolled or game over');
    }
    final value = 1 + _random.nextInt(6);
    if (value == 6 && _sixes >= 2) {
      // Third six in a row: no move, turn forfeits.
      _endTurn();
      return value;
    }
    dice = value;
    if (legalMoves().isEmpty) {
      _endTurn();
    }
    return value;
  }

  /// Token indices the current player may legally move with the rolled dice.
  List<int> legalMoves() {
    final d = dice;
    if (d == null || isOver) return const [];
    final moves = <int>[];
    for (var i = 0; i < 4; i++) {
      final steps = tokens[currentPlayer][i];
      if (steps == finished) continue;
      if (steps == yard) {
        if (d != 6) continue;
        if (_canTravel(currentPlayer, yard, 6)) moves.add(i);
        continue;
      }
      if (steps + d > finished) continue;
      if (_canTravel(currentPlayer, steps, d)) moves.add(i);
    }
    return moves;
  }

  /// Walks square-by-square on the main track; the path and the landing
  /// square must be free of opponent blocks. Tokens in the home column have
  /// no opponents, so only the main-track portion is checked.
  bool _canTravel(int player, int fromSteps, int distance) {
    var remaining = distance;
    var steps = fromSteps;
    if (steps == yard) {
      // Leaving the yard lands on the start square.
      final start = absoluteSquare(player, 0)!;
      return !_opponentBlockAt(player, start);
    }
    while (remaining > 0 && steps < 51) {
      steps++;
      remaining--;
      if (steps > 50) break; // entered the home column: no opponents
      final square = absoluteSquare(player, steps)!;
      if (_opponentBlockAt(player, square)) return false;
    }
    return true;
  }

  /// Moves token [tokenIndex] of the current player. Returns true when the
  /// same player rolls again (rolled a 6), false after the turn passed.
  bool moveToken(int tokenIndex) {
    final d = dice;
    if (d == null || isOver) {
      throw StateError('roll first');
    }
    if (!legalMoves().contains(tokenIndex)) {
      throw ArgumentError('illegal move: $tokenIndex');
    }
    var steps = tokens[currentPlayer][tokenIndex];
    steps = steps == yard ? 0 : steps + d;
    tokens[currentPlayer][tokenIndex] = steps;

    // Capture: a single opponent token on a non-safe main-track square goes
    // back to its yard.
    final square = absoluteSquare(currentPlayer, steps);
    if (square != null && !isSafeSquare(square)) {
      for (var p = 0; p < playerCount; p++) {
        if (p == currentPlayer) continue;
        for (var t = 0; t < 4; t++) {
          if (absoluteSquare(p, tokens[p][t]) == square) {
            tokens[p][t] = yard;
          }
        }
      }
    }

    if (tokens[currentPlayer].every((t) => t == finished)) {
      winner = currentPlayer;
    }

    dice = null;
    if (isOver) return false;
    if (d == 6) {
      _sixes++;
      return true; // same player rolls again
    }
    _endTurn();
    return false;
  }

  void _endTurn() {
    dice = null;
    _sixes = 0;
    currentPlayer = (currentPlayer + 1) % playerCount;
  }

  /// Simple bot heuristic, best first:
  /// 1. finish a token, 2. capture an opponent, 3. leave the yard,
  /// 4. land on a safe square, 5. advance the token closest to home.
  int chooseBotMove() {
    final moves = legalMoves();
    if (moves.isEmpty) {
      throw StateError('no legal moves');
    }
    final d = dice!;
    int? best;
    var bestScore = -1;
    for (final m in moves) {
      final steps = tokens[currentPlayer][m];
      final target = steps == yard ? 0 : steps + d;
      var score = 0;
      if (target == finished) {
        score = 500;
      } else {
        final square = absoluteSquare(currentPlayer, target);
        if (square != null && !isSafeSquare(square) && _capturesAt(square)) {
          score = 400;
        } else if (steps == yard) {
          score = 300;
        } else if (square != null && isSafeSquare(square)) {
          score = 200;
        } else {
          score = steps; // advance the furthest token
        }
      }
      if (score > bestScore) {
        bestScore = score;
        best = m;
      }
    }
    return best!;
  }

  bool _capturesAt(int square) {
    for (var p = 0; p < playerCount; p++) {
      if (p == currentPlayer) continue;
      for (var t = 0; t < 4; t++) {
        if (absoluteSquare(p, tokens[p][t]) == square) return true;
      }
    }
    return false;
  }

  bool isBot(int seat) => botSeats.contains(seat);
}

import 'dart:math';

/// تمساح الشلة — crocodile-dentist elimination as a pure, testable state
/// machine. A row of teeth hides one sore tooth. Players take turns pulling
/// a tooth; whoever pulls the sore one gets chomped and is out. Surviving
/// players start a fresh round (teeth reset, new sore tooth) until one
/// champion remains. Practice mode (solo) counts survived pulls, no winner.
class CrocGame {
  CrocGame({
    required this.playerCount,
    Set<int> botSeats = const {},
    int toothCount = 10,
    Random? random,
  })  : assert(playerCount >= 1 && playerCount <= 4),
        toothCount = toothCount,
        botSeats = Set.of(botSeats),
        _random = random ?? Random() {
    _newRound();
  }

  final int playerCount;
  final Set<int> botSeats;
  final int toothCount;
  final Random _random;

  /// Teeth already pulled this round.
  final Set<int> pulled = {};

  /// Players eliminated from the match.
  final Set<int> eliminated = {};

  /// The sore tooth this round (hidden from the UI until it chomps).
  int soreTooth = -1;

  int currentPlayer = 0;

  /// The player who just got chomped (set right after a chomp pull).
  int? lastChomped;

  /// Match champion once every other seat is eliminated.
  int? winner;

  /// Solo practice ends on the first chomp (no champion by design).
  bool _practiceOver = false;

  /// Solo practice: how many safe pulls the player survived before the
  /// chomp across the whole run.
  int practiceStreak = 0;

  bool get isOver => winner != null || _practiceOver;

  bool isBot(int seat) => botSeats.contains(seat);

  List<int> get alive => [
        for (var p = 0; p < playerCount; p++)
          if (!eliminated.contains(p)) p,
      ];

  /// Teeth still standing this round.
  List<int> get standing => [
        for (var t = 0; t < toothCount; t++)
          if (!pulled.contains(t)) t,
      ];

  void _newRound() {
    pulled.clear();
    soreTooth = _random.nextInt(toothCount);
    if (!eliminated.contains(currentPlayer)) return;
    _advanceTurn();
  }

  void _advanceTurn() {
    final aliveSeats = alive;
    if (aliveSeats.isEmpty) return;
    final i = aliveSeats.indexOf(currentPlayer);
    currentPlayer = aliveSeats[(i + 1) % aliveSeats.length];
  }

  /// Pulls [tooth] for the current player. Returns true when the croc
  /// chomped (sore tooth pulled), false on a safe pull.
  bool pull(int tooth) {
    if (isOver) throw StateError('match over');
    if (!standing.contains(tooth)) {
      throw ArgumentError('tooth $tooth already pulled');
    }
    pulled.add(tooth);
    if (tooth != soreTooth) {
      practiceStreak++;
      lastChomped = null;
      // All safe teeth gone without a chomp: fresh round, same player keeps
      // the turn (a full row of luck).
      if (standing.length == 1) {
        _newRound();
      } else {
        _advanceTurn();
      }
      return false;
    }
    // Chomp.
    lastChomped = currentPlayer;
    eliminated.add(currentPlayer);
    final aliveSeats = alive;
    if (aliveSeats.isEmpty) {
      _practiceOver = true;
    } else if (aliveSeats.length == 1) {
      winner = aliveSeats.single;
    } else {
      currentPlayer = aliveSeats.firstWhere(
        (p) => p != currentPlayer,
        orElse: () => aliveSeats.first,
      );
      _newRound();
    }
    return true;
  }

  /// Bot heuristic: no information exists, so a uniform random standing
  /// tooth is the honest pick.
  int chooseBotPull() {
    final options = standing;
    if (options.isEmpty) throw StateError('no teeth to pull');
    return options[_random.nextInt(options.length)];
  }
}

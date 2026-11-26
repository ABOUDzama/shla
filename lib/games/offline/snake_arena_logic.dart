import 'dart:math';

/// Grid cell.
typedef Cell = Point<int>;

/// Pure logic for Shla Snake Arena (حية الشلة), kept separate from the
/// widget so it can be unit-tested without pumping frames.
///
/// 2-4 players share one phone. Each snake steers with ONE button: a tap
/// turns the snake 90 degrees clockwise. Snakes grow by eating food and
/// die on walls or any snake body. Last snake alive wins the round.
class SnakeArenaMatch {
  SnakeArenaMatch({
    required this.playerCount,
    this.width = 14,
    this.height = 20,
    Random? random,
  })  : assert(playerCount >= 1 && playerCount <= 4),
        _random = random ?? Random() {
    _spawnSnakes();
    _spawnFood();
  }

  final int playerCount;
  final int width;
  final int height;
  final Random _random;

  /// Facing directions as grid deltas; index order is clockwise so a tap
  /// turn is just +1 mod 4.
  static const List<Cell> dirs = [
    Point(0, -1), // up
    Point(1, 0), // right
    Point(0, 1), // down
    Point(-1, 0), // left
  ];

  /// One snake per player: body cells, head first.
  final List<List<Cell>> snakes = [];
  final List<int> facing = [];
  final List<bool> alive = [];
  final List<int> score = [];

  /// Queued turns applied on the next tick (one per player).
  final List<bool> _turnQueued = [];

  /// Seats steered by the built-in bot each tick.
  final Set<int> botSeats = {};

  Cell? food;
  int tickCount = 0;
  int? winner;
  bool get isOver {
    if (winner != null) return true;
    if (playerCount == 1) return !alive[0]; // solo practice ends on death
    return alive.where((a) => a).length <= 1;
  }
  int get aliveCount => alive.where((a) => a).length;

  void _spawnSnakes() {
    // Corner starts; bodies trail directly behind the head along -facing
    // so a first clockwise turn always heads safely along the edge.
    // Everyone spawns facing along the TALL axis (14-15 clear cells ahead),
    // so an unsteered snake lives long enough for its player to react.
    final starts = <List<Cell>>[
      [Cell(2, 5), Cell(2, 4), Cell(2, 3), Cell(2, 2)],
      [Cell(width - 3, height - 6), Cell(width - 3, height - 5), Cell(width - 3, height - 4), Cell(width - 3, height - 3)],
      [Cell(width - 5, 5), Cell(width - 5, 4), Cell(width - 5, 3), Cell(width - 5, 2)],
      [Cell(4, height - 6), Cell(4, height - 5), Cell(4, height - 4), Cell(4, height - 3)],
    ];
    final facings = [2, 0, 2, 0]; // down, up, down, up
    for (var p = 0; p < playerCount; p++) {
      snakes.add(List.of(starts[p]));
      facing.add(facings[p]);
      alive.add(true);
      score.add(0);
      _turnQueued.add(false);
    }
  }

  void _spawnFood() {
    final free = <Cell>[];
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final c = Cell(x, y);
        if (snakes.every((s) => !s.contains(c))) free.add(c);
      }
    }
    food = free.isEmpty ? null : free[_random.nextInt(free.length)];
  }

  /// Bot steering: survive first (turn when straight ahead kills), then
  /// drift toward the food when both options are safe. One clockwise turn
  /// per tick, same control a human has.
  void _steerBot(int p) {
    bool deadAhead(int dir) {
      final d = dirs[dir];
      final h = snakes[p].first;
      final nx = h.x + d.x, ny = h.y + d.y;
      if (nx < 0 || ny < 0 || nx >= width || ny >= height) return true;
      for (var q = 0; q < playerCount; q++) {
        if (!alive[q]) continue;
        final body = snakes[q];
        // skip the tail tip: a non-eating snake vacates it this tick
        for (var i = 0; i < body.length - 1; i++) {
          if (body[i].x == nx && body[i].y == ny) return true;
        }
      }
      return false;
    }

    int foodDist(int dir) {
      final d = dirs[dir];
      final h = snakes[p].first;
      final f = food;
      if (f == null) return 0;
      return (h.x + d.x - f.x).abs() + (h.y + d.y - f.y).abs();
    }

    // Two-step lookahead: after moving one step in [dir], is any
    // follow-up direction safe? If not, the move walks into a pocket.
    bool pocketAhead(int dir) {
      final d = dirs[dir];
      final h = snakes[p].first;
      final nx = h.x + d.x, ny = h.y + d.y;
      bool blocked(int x, int y) {
        if (x < 0 || y < 0 || x >= width || y >= height) return true;
        for (var q = 0; q < playerCount; q++) {
          if (!alive[q]) continue;
          final body = snakes[q];
          for (var i = 0; i < body.length - 1; i++) {
            if (body[i].x == x && body[i].y == y) return true;
          }
        }
        return false;
      }

      for (final turnBy in [0, 1, 3]) {
        // 0 = keep straight, 1 = clockwise, 3 = counter-clockwise
        final d2 = dirs[(dir + turnBy) % 4];
        if (!blocked(nx + d2.x, ny + d2.y)) return false;
      }
      return true;
    }

    final straight = facing[p];
    final turned = (straight + 1) % 4;
    final straightDead = deadAhead(straight) || pocketAhead(straight);
    final turnDead = deadAhead(turned) || pocketAhead(turned);
    if (straightDead) {
      if (!turnDead) _turnQueued[p] = true;
      return; // both fatal: accept fate, go straight
    }
    if (turnDead) return; // keep straight: the turn walks into a pocket
    if (food != null && foodDist(turned) < foodDist(straight)) {
      _turnQueued[p] = true;
    }
  }

  /// Queue a 90-degree clockwise turn for [player]. Ignored when dead/over.
  void turn(int player) {
    if (isOver || !alive[player]) return;
    _turnQueued[player] = true;
  }

  /// Advance the arena one step.
  void tick() {
    if (isOver) return;
    tickCount++;
    for (final p in botSeats) {
      if (p < playerCount && alive[p]) _steerBot(p);
    }
    final newHeads = <Cell>[];
    for (var p = 0; p < playerCount; p++) {
      if (!alive[p]) {
        newHeads.add(const Cell(-1, -1));
        continue;
      }
      if (_turnQueued[p]) {
        facing[p] = (facing[p] + 1) % 4;
        _turnQueued[p] = false;
      }
      final d = dirs[facing[p]];
      final h = snakes[p].first;
      newHeads.add(Cell(h.x + d.x, h.y + d.y));
    }
    // Resolve deaths: wall, own body, any body (tails move unless eating,
    // so compare against current bodies but allow the moving-away tail tip).
    final eating = List.filled(playerCount, false);
    for (var p = 0; p < playerCount; p++) {
      if (alive[p] && newHeads[p] == food) eating[p] = true;
    }
    final died = List.filled(playerCount, false);
    for (var p = 0; p < playerCount; p++) {
      if (!alive[p]) continue;
      final nh = newHeads[p];
      if (nh.x < 0 || nh.y < 0 || nh.x >= width || nh.y >= height) {
        died[p] = true;
        continue;
      }
      for (var q = 0; q < playerCount; q++) {
        if (!alive[q]) continue;
        var body = snakes[q];
        // A non-eating snake's tail tip vacates this tick.
        final limit = eating[q] ? body.length : body.length - 1;
        for (var i = 0; i < limit; i++) {
          if (body[i] == nh) died[p] = true;
        }
      }
      // Head-on-head between living snakes kills both.
      for (var q = p + 1; q < playerCount; q++) {
        if (alive[q] && newHeads[p] == newHeads[q]) {
          died[p] = true;
          died[q] = true;
        }
      }
    }
    for (var p = 0; p < playerCount; p++) {
      if (!alive[p]) continue;
      if (died[p]) {
        alive[p] = false;
        continue;
      }
      snakes[p].insert(0, newHeads[p]);
      if (eating[p]) {
        score[p]++;
        _spawnFood();
      } else {
        snakes[p].removeLast();
      }
    }
    if (playerCount == 1) return; // practice: no winner bookkeeping
    final left = aliveCount;
    if (left == 1) {
      winner = alive.indexOf(true);
    } else if (left == 0) {
      // Mutual wipeout: highest score takes it, else a draw (no winner).
      var best = -1, bestScore = 0, tie = false;
      for (var p = 0; p < playerCount; p++) {
        if (score[p] > bestScore) {
          best = p; bestScore = score[p]; tie = false;
        } else if (score[p] == bestScore) {
          tie = true;
        }
      }
      winner = (bestScore > 0 && !tie) ? best : -1; // -1 marks a decided draw
    }
  }
}

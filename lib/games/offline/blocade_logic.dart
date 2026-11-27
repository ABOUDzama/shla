import 'dart:collection';
import 'dart:math';

/// بلوكيد: Quoridor-style race on a 9x9 board (the "Blocade" shorts game).
/// Each turn a player EITHER moves their pawn one step OR places one wall.
/// A wall may never cut off the last path of any pawn to its goal side.
/// Seats: 2P = bottom vs top; 4P = bottom, left, top, right (clockwise).
/// Rules follow the published Quoridor rules (20 walls total).
class BlocadeGame {
  BlocadeGame({required this.playerCount, Random? random})
      : assert(playerCount == 2 || playerCount == 4),
        _random = random ?? Random() {
    final per = playerCount == 2 ? 10 : 5;
    wallsLeft = List.filled(playerCount, per);
    pawns = playerCount == 2
        ? [const Cell(8, 4), const Cell(0, 4)]
        : [const Cell(8, 4), const Cell(4, 0), const Cell(0, 4), const Cell(4, 8)];
  }

  static const int size = 9;
  final int playerCount;
  final Random _random;

  late List<Cell> pawns;
  late List<int> wallsLeft;

  /// Horizontal wall at (r,c): blocks between rows r and r+1, columns c and c+1.
  final Set<int> hWalls = {};

  /// Vertical wall at (r,c): blocks between columns c and c+1, rows r and r+1.
  final Set<int> vWalls = {};
  final List<Wall> placed = [];

  int current = 0;
  int? winner;

  static int _k(int r, int c) => r * 8 + c;

  /// 2P: seat 0 bottom, seat 1 top. 4P: bottom, left, top, right.
  String sideOf(int seat) => playerCount == 2
      ? (seat == 0 ? 'bottom' : 'top')
      : const ['bottom', 'left', 'top', 'right'][seat];

  bool goalReached(int seat, Cell p) {
    switch (sideOf(seat)) {
      case 'bottom':
        return p.r == 0;
      case 'top':
        return p.r == size - 1;
      case 'left':
        return p.c == size - 1;
      default:
        return p.c == 0;
    }
  }

  bool blockedBetween(Cell a, Cell b) {
    if (a.r == b.r) {
      final c = min(a.c, b.c);
      return vWalls.contains(_k(a.r, c)) ||
          (a.r > 0 && vWalls.contains(_k(a.r - 1, c)));
    }
    final r = min(a.r, b.r);
    return hWalls.contains(_k(r, a.c)) ||
        (a.c > 0 && hWalls.contains(_k(r, a.c - 1)));
  }

  bool _inside(Cell p) => p.r >= 0 && p.c >= 0 && p.r < size && p.c < size;
  bool _occupied(Cell p, {int? except}) {
    for (var i = 0; i < pawns.length; i++) {
      if (i != except && pawns[i] == p) return true;
    }
    return false;
  }

  static const _dirs = [Cell(-1, 0), Cell(1, 0), Cell(0, -1), Cell(0, 1)];

  /// Legal destination cells for [seat]'s pawn (Quoridor jump rules).
  List<Cell> legalMoves(int seat) {
    final me = pawns[seat];
    final out = <Cell>[];
    for (final d in _dirs) {
      final n = Cell(me.r + d.r, me.c + d.c);
      if (!_inside(n) || blockedBetween(me, n)) continue;
      if (!_occupied(n, except: seat)) {
        out.add(n);
        continue;
      }
      // Adjacent pawn: jump straight over it if possible.
      final j = Cell(n.r + d.r, n.c + d.c);
      if (_inside(j) && !blockedBetween(n, j) && !_occupied(j, except: seat)) {
        out.add(j);
        continue;
      }
      // Straight jump blocked: sidestep around the jumped pawn.
      for (final s in _dirs) {
        if (s.r * d.r != 0 || s.c * d.c != 0) continue; // perpendicular only
        final side = Cell(n.r + s.r, n.c + s.c);
        if (_inside(side) &&
            !blockedBetween(n, side) &&
            !_occupied(side, except: seat)) {
          out.add(side);
        }
      }
    }
    return out;
  }

  bool move(int seat, Cell to) {
    if (winner != null || seat != current) return false;
    if (!legalMoves(seat).contains(to)) return false;
    pawns[seat] = to;
    if (goalReached(seat, to)) {
      winner = seat;
      return true;
    }
    _advance();
    return true;
  }

  void _advance() => current = (current + 1) % playerCount;

  /// Why a wall is illegal, or null when it can be placed.
  String? wallProblem(Wall w) {
    if (winner != null) return 'اللعبة خلصت';
    if (wallsLeft[current] <= 0) return 'حيطانك خلصت';
    if (w.r < 0 || w.c < 0 || w.r > 7 || w.c > 7) return 'برة الملعب';
    final k = _k(w.r, w.c);
    if (hWalls.contains(k) || vWalls.contains(k)) return 'المكان ده مشغول';
    if (w.horizontal) {
      if ((w.c > 0 && hWalls.contains(_k(w.r, w.c - 1))) ||
          (w.c < 7 && hWalls.contains(_k(w.r, w.c + 1)))) {
        return 'بتتداخل مع حيطة تانية';
      }
    } else {
      if ((w.r > 0 && vWalls.contains(_k(w.r - 1, w.c))) ||
          (w.r < 7 && vWalls.contains(_k(w.r + 1, w.c)))) {
        return 'بتتداخل مع حيطة تانية';
      }
    }
    final set = w.horizontal ? hWalls : vWalls;
    set.add(k);
    var ok = true;
    for (var i = 0; i < playerCount && ok; i++) {
      if (shortestPath(i) < 0) ok = false;
    }
    set.remove(k);
    return ok ? null : 'مينفعش تقفل الطريق بالكامل';
  }

  bool placeWall(Wall w) {
    if (wallProblem(w) != null) return false;
    (w.horizontal ? hWalls : vWalls).add(_k(w.r, w.c));
    placed.add(w.withOwner(current));
    wallsLeft[current]--;
    _advance();
    return true;
  }

  /// Shortest step count for [seat] to its goal, ignoring pawns. -1 = none.
  int shortestPath(int seat, {Cell? from}) {
    final start = from ?? pawns[seat];
    final dist = <Cell, int>{start: 0};
    final q = Queue<Cell>()..add(start);
    while (q.isNotEmpty) {
      final p = q.removeFirst();
      if (goalReached(seat, p)) return dist[p]!;
      for (final d in _dirs) {
        final n = Cell(p.r + d.r, p.c + d.c);
        if (!_inside(n) || dist.containsKey(n) || blockedBetween(p, n)) continue;
        dist[n] = dist[p]! + 1;
        q.add(n);
      }
    }
    return -1;
  }

  /// Bot turn. [skill] 0..1: how often it plays wall tricks.
  /// Returns 'wall', 'move' or 'pass'.
  String botTurn({double skill = 0.7}) {
    final me = current;
    final myDist = shortestPath(me);
    var lead = -1, leadDist = 999;
    for (var i = 0; i < playerCount; i++) {
      if (i == me) continue;
      final d = shortestPath(i);
      if (d < leadDist) {
        leadDist = d;
        lead = i;
      }
    }
    if (wallsLeft[me] > 0 &&
        (leadDist <= myDist + 1 || _random.nextDouble() < 0.25) &&
        _random.nextDouble() < skill) {
      Wall? best;
      var bestScore = 1; // needs a net gain of 2+ to bother
      for (var r = 0; r < 8; r++) {
        for (var c = 0; c < 8; c++) {
          for (final h in [true, false]) {
            final w = Wall(r, c, h);
            if (wallProblem(w) != null) continue;
            final set = h ? hWalls : vWalls;
            set.add(_k(r, c));
            final score = (shortestPath(lead) - leadDist) -
                (shortestPath(me) - myDist);
            set.remove(_k(r, c));
            if (score > bestScore) {
              bestScore = score;
              best = w;
            }
          }
        }
      }
      if (best != null) {
        placeWall(best);
        return 'wall';
      }
    }
    Cell? bestMove;
    var bestD = 999;
    for (final m in legalMoves(me)) {
      final d = shortestPath(me, from: m);
      if (d >= 0 && (d < bestD || (d == bestD && _random.nextBool()))) {
        bestD = d;
        bestMove = m;
      }
    }
    if (bestMove != null) {
      move(me, bestMove);
      return 'move';
    }
    _advance();
    return 'pass';
  }
}

class Cell {
  const Cell(this.r, this.c);
  final int r, c;
  @override
  bool operator ==(Object o) => o is Cell && o.r == r && o.c == c;
  @override
  int get hashCode => r * 31 + c;
  @override
  String toString() => '($r,$c)';
}

class Wall {
  const Wall(this.r, this.c, this.horizontal, [this.owner = -1]);
  final int r, c;
  final bool horizontal;
  final int owner;
  Wall withOwner(int o) => Wall(r, c, horizontal, o);
}

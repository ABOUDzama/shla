import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'results_service.dart';

/// كأس الشلة: a mini tournament across the ١٢٣٤ arcade games.
///
/// The cup plays N rounds, each round one arcade game. Games keep their own
/// pickers and gameplay untouched; when a game finishes, its winner is
/// already recorded in [ResultsService] by the shared victory screen, and
/// the cup listens to that stream: a human winner takes 1 point, a bot win
/// ('البوتات كسبوا 🤖') counts the round with no points, and leaving a game
/// early (no result recorded) leaves the round open for replay or skip.
/// Champion is the most wins after the last round; ties share the cup.
///
/// State persists to SharedPreferences so a killed app resumes the cup.
class CupService extends ChangeNotifier {
  static final CupService instance = CupService._();
  CupService._();

  static const _key = 'cup_state_v1';

  /// The exact label the arcade win screens record when bots win a match.
  static const botsLabel = 'البوتات كسبوا 🤖';

  bool active = false;
  int rounds = 0;
  List<String> games = [];
  int roundIndex = 0; // 0-based; == rounds when finished
  Map<String, int> points = {};
  bool roundOpen = false; // a round was launched and waits for its result
  int roundStartMs = 0;
  final Set<String> _consumed = {};

  bool get finished => active && roundIndex >= rounds;
  String? get currentGame =>
      active && roundIndex < games.length ? games[roundIndex] : null;
  int get roundNumber => roundIndex + 1;

  /// Leaders: everyone tied at the top score (empty when nobody scored).
  List<MapEntry<String, int>> get leaders {
    if (points.isEmpty) return [];
    final top = points.values.reduce((a, b) => a > b ? a : b);
    if (top == 0) return [];
    final l = points.entries.where((e) => e.value == top).toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return l;
  }

  /// Standings highest-first, ties alphabetical for a stable board.
  List<MapEntry<String, int>> get standings {
    final l = points.entries.toList()
      ..sort((a, b) {
        final c = b.value.compareTo(a.value);
        return c != 0 ? c : a.key.compareTo(b.key);
      });
    return l;
  }

  Future<void> start({required int rounds, required List<String> games}) async {
    active = true;
    this.rounds = rounds;
    this.games = List.of(games);
    roundIndex = 0;
    points = {};
    roundOpen = false;
    roundStartMs = 0;
    _consumed.clear();
    await _save();
    notifyListeners();
  }

  /// Called right before pushing the round's game screen: only results
  /// recorded at/after this moment count for the round.
  Future<void> markRoundStarted() async {
    if (!active || finished) return;
    roundOpen = true;
    roundStartMs = DateTime.now().millisecondsSinceEpoch;
    await _save();
    notifyListeners();
  }

  /// Fold the latest match history into the cup. Safe to call on every
  /// ResultsService notification: only a result for the current game,
  /// recorded after the round started and not consumed yet, is counted.
  Future<void> ingestResults(List<MatchResult> all) async {
    if (!active || !roundOpen || finished) return;
    final g = currentGame;
    if (g == null) return;
    MatchResult? hit;
    for (final r in all.reversed) {
      if (r.game != g) continue;
      if (r.at < roundStartMs - 2000) continue;
      if (_consumed.contains(r.id)) continue;
      hit = r;
      break;
    }
    if (hit == null) return;
    _consumed.add(hit.id);
    roundOpen = false;
    if (hit.winner != botsLabel && hit.winner.trim().isNotEmpty) {
      points[hit.winner] = (points[hit.winner] ?? 0) + 1;
    }
    roundIndex++;
    await _save();
    notifyListeners();
  }

  /// The round's game was left without a result: skip it (no points).
  Future<void> skipRound() async {
    if (!active || finished) return;
    roundOpen = false;
    roundIndex++;
    await _save();
    notifyListeners();
  }

  Future<void> endCup() async {
    active = false;
    roundOpen = false;
    await _save();
    notifyListeners();
  }

  Future<void> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return;
      final j = jsonDecode(raw) as Map<String, dynamic>;
      active = j['a'] as bool? ?? false;
      rounds = j['r'] as int? ?? 0;
      games = List<String>.from(j['g'] as List? ?? const []);
      roundIndex = j['i'] as int? ?? 0;
      points = (j['p'] as Map? ?? {}).map((k, v) => MapEntry('$k', (v as num).toInt()));
      roundOpen = j['o'] as bool? ?? false;
      roundStartMs = j['s'] as int? ?? 0;
      _consumed
        ..clear()
        ..addAll(List<String>.from(j['c'] as List? ?? const []));
      notifyListeners();
    } catch (e) {
      debugPrint('CupService.restore failed: $e');
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _key,
          jsonEncode({
            'a': active,
            'r': rounds,
            'g': games,
            'i': roundIndex,
            'p': points,
            'o': roundOpen,
            's': roundStartMs,
            'c': _consumed.toList(),
          }));
    } catch (e) {
      debugPrint('CupService.save failed: $e');
    }
  }
}

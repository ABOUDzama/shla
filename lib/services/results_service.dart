import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The exact label recorded when bots win a match. CupService counts these
/// rounds with no points; the leaderboard skips the label.
const kBotsWinnerLabel = 'البوتات كسبوا 🤖';

class MatchResult {
  final String game;
  final String winner;
  final List<String> players;
  final int at; // epoch ms
  final String id; // stable round identity
  const MatchResult(this.game, this.winner, this.players, this.at, [this.id = '']);

  Map<String, dynamic> toJson() =>
      {'g': game, 'w': winner, 'p': players, 't': at, 'i': id};

  static MatchResult? fromJson(dynamic j) {
    try {
      final m = j as Map;
      return MatchResult(m['g'] as String, m['w'] as String,
          List<String>.from(m['p'] as List), m['t'] as int,
          (m['i'] as String?) ?? '');
    } catch (_) {
      return null;
    }
  }
}

/// Local match history behind the الترتيب page. Pure SharedPreferences:
/// no network. Only finished matches with a winner are recorded; leaving a
/// game early, or a draw, records nothing.
class ResultsService extends ChangeNotifier {
  static final ResultsService instance = ResultsService._();
  ResultsService._();

  static const _key = 'match_results_v1';
  static const maxEntries = 300;
  static int _seq = 0;

  /// Fresh identity for one finished round. Callers create it once when a
  /// round ends; recording the same id twice is ignored (exactly once),
  /// while a quick rematch has a new id and is always counted.
  static String newRoundId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${_seq++}';

  /// Winner labels that are anonymous seats ("لاعب 2"), not profiles.
  static bool isSeat(String name) => name.startsWith('لاعب ');

  Future<List<MatchResult>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return (prefs.getStringList(_key) ?? [])
          .map((s) => MatchResult.fromJson(jsonDecode(s)))
          .whereType<MatchResult>()
          .toList();
    } catch (e) {
      debugPrint('ResultsService.load failed: $e');
      return [];
    }
  }

  /// Returns false when ignored (blank winner or this round id already saved).
  Future<bool> recordWin({
    required String game,
    required String winner,
    List<String> players = const [],
    String? roundId,
    DateTime? now,
  }) async {
    if (winner.trim().isEmpty) return false;
    final t = (now ?? DateTime.now()).millisecondsSinceEpoch;
    final all = await load();
    final id = roundId ?? newRoundId();
    if (all.any((r) => r.id == id)) return false;
    all.add(MatchResult(game, winner, players, t, id));
    final trimmed =
        all.length > maxEntries ? all.sublist(all.length - maxEntries) : all;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
          _key, trimmed.map((r) => jsonEncode(r.toJson())).toList());
    } catch (e) {
      debugPrint('ResultsService.record failed: $e');
      return false;
    }
    notifyListeners();
    return true;
  }

  /// Wins per named profile, highest first (anonymous seats excluded).
  static List<MapEntry<String, int>> standings(List<MatchResult> results) {
    final wins = <String, int>{};
    for (final r in results) {
      if (isSeat(r.winner)) continue;
      if (r.winner == kBotsWinnerLabel) continue; // bots are not a profile
      wins[r.winner] = (wins[r.winner] ?? 0) + 1;
    }
    final l = wins.entries.toList();
    l.sort((a, b) => b.value.compareTo(a.value));
    return l;
  }
}

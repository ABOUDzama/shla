import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tracks which content items (questions, words, prompts...) were already
/// shown so games serve fresh content first. When everything has been
/// played, the history resets automatically.
class PlayedHistoryService {
  static const String _key = 'played_items_history';
  static const int _maxEntries = 5000;

  static String _fingerprint(dynamic item) {
    if (item is Map) {
      final q = item['question'] ?? item['statement'] ?? item['word'] ?? item['name'];
      if (q != null) return q.toString();
    }
    try {
      return jsonEncode(item);
    } catch (_) {
      return item.toString();
    }
  }

  static Future<Set<String>> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_key) ?? [];
      return list.toSet();
    } catch (e) {
      debugPrint('PlayedHistoryService load failed: $e');
      return <String>{};
    }
  }

  /// Returns the subset of [items] that was never shown. If everything was
  /// played before, clears the history and returns all items.
  static Future<List<dynamic>> filterUnplayed(List<dynamic> items) async {
    if (items.isEmpty) return items;
    final played = await _load();
    final unplayed =
        items.where((item) => !played.contains(_fingerprint(item))).toList();
    if (unplayed.isEmpty) {
      // Everything was played - reset so the fun continues.
      await clear();
      return items;
    }
    return unplayed;
  }

  static Future<void> markAsPlayed(String itemText) async {
    if (itemText.trim().isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_key) ?? [];
      if (!list.contains(itemText)) {
        list.add(itemText);
        if (list.length > _maxEntries) {
          list.removeRange(0, list.length - _maxEntries);
        }
        await prefs.setStringList(_key, list);
      }
    } catch (e) {
      debugPrint('PlayedHistoryService.markAsPlayed failed: $e');
    }
  }

  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {}
  }
}

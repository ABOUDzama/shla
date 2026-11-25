import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local cache for AI-generated content so it survives restarts and can be
/// merged into game data by RawDataManager.
class AICacheService {
  static const String _quizPrefix = 'ai_cache_quiz_';
  static const String _contentPrefix = 'ai_cache_content_';
  static const int _maxPerKey = 500;

  static Future<void> saveQuizQuestions(
    String category,
    List<Map<String, dynamic>> questions,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_quizPrefix$category';
      final existing = await loadQuizQuestions(category);
      final unique = <String, Map<String, dynamic>>{};
      for (final q in existing) {
        unique[jsonEncode(q)] = q;
      }
      for (final q in questions) {
        unique[jsonEncode(q)] = q;
      }
      var merged = unique.values.toList();
      if (merged.length > _maxPerKey) {
        merged = merged.sublist(merged.length - _maxPerKey);
      }
      await prefs.setString(key, jsonEncode(merged));
    } catch (e) {
      debugPrint('AICacheService.saveQuizQuestions failed: $e');
    }
  }

  static Future<List<Map<String, String>>> loadQuizQuestions(
    String category,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_quizPrefix$category');
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => e.map((k, v) => MapEntry(k.toString(), v?.toString() ?? '')))
            .toList();
      }
    } catch (e) {
      debugPrint('AICacheService.loadQuizQuestions failed: $e');
    }
    return [];
  }

  static Future<void> saveGameContent(
    String gameType,
    List<dynamic> content,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_contentPrefix$gameType';
      final existing = await loadGameContent(gameType);
      final unique = <String, dynamic>{};
      for (final item in existing) {
        unique[jsonEncode(item)] = item;
      }
      for (final item in content) {
        unique[jsonEncode(item)] = item;
      }
      var merged = unique.values.toList();
      if (merged.length > _maxPerKey) {
        merged = merged.sublist(merged.length - _maxPerKey);
      }
      await prefs.setString(key, jsonEncode(merged));
    } catch (e) {
      debugPrint('AICacheService.saveGameContent failed: $e');
    }
  }

  static Future<List<dynamic>> loadGameContent(String gameKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_contentPrefix$gameKey');
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw);
      if (decoded is List) return decoded;
    } catch (e) {
      debugPrint('AICacheService.loadGameContent failed: $e');
    }
    return [];
  }
}

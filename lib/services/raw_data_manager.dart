import 'dart:convert';
import 'package:flutter/services.dart';
import 'online_data_service.dart';
import 'ai_cache_service.dart';
import 'played_history_service.dart';
import 'supabase_service.dart';

class RawDataManager {
  static final Map<String, dynamic> _cache = {};

  /// Helper to fetch game data
  /// It first checks if there is updated data from OnlineDataService.
  /// If none exists, it falls back to the provided default local data.
  static Future<Map<String, dynamic>> getGameData(
      String gameKey, Map<String, dynamic> defaultData) async {
    Map<String, dynamic> finalMap = {};

    // 1. Try Online
    final onlineData = await OnlineDataService.getGameData(gameKey);
    if (onlineData != null && onlineData.isNotEmpty) {
      finalMap = Map<String, dynamic>.from(onlineData);
    } else {
      // 2. Try Local JSON File
      final localJson = await loadLocalGameData(gameKey);
      if (localJson != null && localJson.isNotEmpty) {
        finalMap = Map<String, dynamic>.from(localJson);
      } else {
        // 3. Fallback to hardcoded
        finalMap = Map<String, dynamic>.from(defaultData);
      }
    }

    // 4. Merge AI Cached Data
    try {
      final String normalizedKey = gameKey.replaceAll('_game', '');
      final cachedAI = await AICacheService.loadGameContent(normalizedKey);
      if (cachedAI.isNotEmpty) {
        if (finalMap.containsKey('items') && finalMap['items'] is List) {
          final itemsList = List<dynamic>.from(finalMap['items']);
          itemsList.addAll(cachedAI);
          
          final uniqueItems = <String, dynamic>{};
          for (var item in itemsList) {
             uniqueItems[jsonEncode(item)] = item;
          }
          finalMap['items'] = uniqueItems.values.toList();
        } else if (finalMap.containsKey('categories') && finalMap['categories'] is Map) {
          final Map<String, dynamic> cats = Map<String, dynamic>.from(finalMap['categories']);
          for(var item in cachedAI) {
            if (item is Map) {
               String catName = (item['category'] ?? item['cat'] ?? 'عام').toString();
               if (!cats.containsKey(catName)) cats[catName] = [];
               
               if (item.containsKey('words') && item['words'] is List) {
                 final wordsList = List<dynamic>.from(cats[catName]!);
                 wordsList.addAll(item['words']);
                 cats[catName] = wordsList.map((e) => e.toString().trim()).toSet().toList();
               } else if (item.containsKey('word')) {
                 final wordsList = List<dynamic>.from(cats[catName]!);
                 wordsList.add(item['word']);
                 cats[catName] = wordsList.map((e) => e.toString().trim()).toSet().toList();
               }
            }
          }
          finalMap['categories'] = cats;
        } else if (finalMap.isEmpty) {
          finalMap['items'] = List<dynamic>.from(cachedAI);
        }
      }
    } catch (_) {}
    
    // 4.5 Merge Community Data from Supabase
    try {
      final String normalizedKey = gameKey.replaceAll('_game', '');
      final communityData = await SupabaseService.fetchCommunityContent(gameKey: normalizedKey);
      if (communityData.isNotEmpty) {
        if (finalMap.containsKey('items') && finalMap['items'] is List) {
          final itemsList = List<dynamic>.from(finalMap['items']);
          itemsList.addAll(communityData);
          
          final uniqueItems = <String, dynamic>{};
          for (var item in itemsList) {
             uniqueItems[jsonEncode(item)] = item;
          }
          finalMap['items'] = uniqueItems.values.toList();
        } else if (finalMap.containsKey('categories') && finalMap['categories'] is Map) {
          final Map<String, dynamic> cats = Map<String, dynamic>.from(finalMap['categories']);
          for(var item in communityData) {
            if (item is Map) {
               String catName = (item['category'] ?? item['cat'] ?? 'عام').toString();
               if (!cats.containsKey(catName)) cats[catName] = [];
               
               if (item.containsKey('words') && item['words'] is List) {
                 final wordsList = List<dynamic>.from(cats[catName]!);
                 wordsList.addAll(item['words']);
                 cats[catName] = wordsList.map((e) => e.toString().trim()).toSet().toList();
               } else if (item.containsKey('word')) {
                 final wordsList = List<dynamic>.from(cats[catName]!);
                 wordsList.add(item['word']);
                 cats[catName] = wordsList.map((e) => e.toString().trim()).toSet().toList();
               }
            }
          }
          finalMap['categories'] = cats;
        }
      }
    } catch (_) {}

    // 5. Filter Played History
    if (finalMap.containsKey('items') && finalMap['items'] is List) {
      finalMap['items'] = await PlayedHistoryService.filterUnplayed(List<dynamic>.from(finalMap['items']));
    } else if (finalMap.containsKey('categories') && finalMap['categories'] is Map) {
      final Map<String, dynamic> cats = Map<String, dynamic>.from(finalMap['categories']);
      for (var key in cats.keys.toList()) {
         if (cats[key] is List) {
           cats[key] = await PlayedHistoryService.filterUnplayed(List<dynamic>.from(cats[key]));
         }
      }
      finalMap['categories'] = cats;
    }

    return finalMap;
  }

  /// Helper to fetch a list of items for a game
  static Future<List<dynamic>> getGameList(
      String gameKey, List<dynamic> defaultList) async {
    List<dynamic> combinedList = [];

    // 1. Try Online Gist
    final onlineData = await OnlineDataService.getGameData(gameKey);
    if (onlineData != null && onlineData.containsKey('items')) {
      final items = onlineData['items'];
      if (items is List && items.isNotEmpty) {
        combinedList.addAll(items);
      }
    } 
    
    // 2. Local JSON Asset (if nothing found online)
    if (combinedList.isEmpty) {
      final localJson = await loadLocalGameData(gameKey);
      if (localJson != null && localJson.containsKey('items')) {
        final items = localJson['items'];
        if (items is List && items.isNotEmpty) {
          combinedList.addAll(items);
        }
      }
    }

    // 3. Fallback to hardcoded if still empty
    if (combinedList.isEmpty) {
      combinedList.addAll(defaultList);
    }

    // 4. Merge with AI Cached Data
    try {
      final cachedAI = await AICacheService.loadGameContent(gameKey);
      if (cachedAI.isNotEmpty) {
        // Simple deduplication block
        final uniqueItems = <String, dynamic>{};
        for (var item in combinedList) {
          uniqueItems[jsonEncode(item)] = item;
        }
        for (var item in cachedAI) {
          uniqueItems[jsonEncode(item)] = item;
        }
        combinedList = uniqueItems.values.toList();
      }
    } catch (_) {}

    // 4.5 Merge with Community Data from Supabase
    try {
      final communityData = await SupabaseService.fetchCommunityContent(gameKey: gameKey);
      if (communityData.isNotEmpty) {
        final uniqueItems = <String, dynamic>{};
        for (var item in combinedList) {
          uniqueItems[jsonEncode(item)] = item;
        }
        for (var item in communityData) {
          uniqueItems[jsonEncode(item)] = item;
        }
        combinedList = uniqueItems.values.toList();
      }
    } catch (_) {}

    // 5. Filter Played History
    combinedList = await PlayedHistoryService.filterUnplayed(combinedList);

    return combinedList;
  }

  /// Loads game data from assets/games/[gameKey].json
  static Future<Map<String, dynamic>?> loadLocalGameData(String gameKey) async {
    if (_cache.containsKey(gameKey)) return _cache[gameKey];

    try {
      // Normalize gameKey to match filename (e.g. charades_game -> charades)
      String fileName = gameKey.replaceAll('_game', '');
      final String response = await rootBundle.loadString('assets/games/$fileName.json');
      final data = await json.decode(response);
      if (data is Map<String, dynamic>) {
        _cache[gameKey] = data;
        return data;
      }
    } catch (e) {
      // File might not exist yet or be invalid
      return null;
    }
    return null;
  }
}

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Community content + profile sync backend (optional).
///
/// The original keys were removed from the repository, so the app runs fully
/// without them. To re-enable, build with:
///   --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
/// When not configured every call is a safe no-op.
class SupabaseService {
  static const String _url = String.fromEnvironment('SUPABASE_URL');
  static const String _anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool _ready = false;
  static bool get isEnabled => _ready;

  static Future<void> initialize() async {
    if (_url.isEmpty || _anonKey.isEmpty) {
      debugPrint('SupabaseService: no credentials configured, running offline.');
      return;
    }
    try {
      await Supabase.initialize(url: _url, anonKey: _anonKey);
      _ready = true;
    } catch (e) {
      debugPrint('SupabaseService init failed: $e');
    }
  }

  static Future<void> syncProfile({
    required String deviceId,
    required String name,
    String? avatar,
  }) async {
    if (!_ready) return;
    try {
      await Supabase.instance.client.from('profiles').upsert({
        'device_id': deviceId,
        'name': name,
        'avatar': avatar,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('SupabaseService.syncProfile failed: $e');
    }
  }

  static Future<void> uploadContent({
    required String gameKey,
    String? category,
    required Map<String, dynamic> content,
    required String creatorId,
    required String creatorName,
  }) async {
    if (!_ready) return;
    try {
      await Supabase.instance.client.from('community_content').insert({
        'game_key': gameKey,
        'category': category,
        'content': content,
        'creator_id': creatorId,
        'creator_name': creatorName,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('SupabaseService.uploadContent failed: $e');
    }
  }

  /// Returns community-contributed content items for a game (empty when
  /// offline/disabled). Items are decoded from the stored JSON payload.
  static Future<List<dynamic>> fetchCommunityContent({
    required String gameKey,
  }) async {
    if (!_ready) return const [];
    try {
      final rows = await Supabase.instance.client
          .from('community_content')
          .select('content')
          .eq('game_key', gameKey)
          .order('created_at', ascending: false)
          .limit(300);
      return (rows as List)
          .map((r) => (r as Map)['content'])
          .where((c) => c != null)
          .toList();
    } catch (e) {
      debugPrint('SupabaseService.fetchCommunityContent failed: $e');
      return const [];
    }
  }
}

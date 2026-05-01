import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'supabase_service.dart';

class SettingsService {
  static const String _soundEnabledKey = 'sound_enabled';
  static const String _vibrationEnabledKey = 'vibration_enabled';
  static const String _userNameKey = 'current_user_name';
  static const String _userAvatarKey = 'current_user_avatar';
  static const String _deviceIdKey = 'unique_device_id';

  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static bool get isSoundEnabled => _prefs?.getBool(_soundEnabledKey) ?? true;
  static bool get isVibrationEnabled =>
      _prefs?.getBool(_vibrationEnabledKey) ?? true;

  static Future<void> setSoundEnabled(bool value) async {
    await _prefs?.setBool(_soundEnabledKey, value);
  }

  static Future<void> setVibrationEnabled(bool value) async {
    await _prefs?.setBool(_vibrationEnabledKey, value);
  }

  static Future<int> getHighScore(String gameId) async {
    return _prefs?.getInt('highscore_$gameId') ?? 0;
  }

  static Future<void> setHighScore(String gameId, int score) async {
    int currentHighScore = await getHighScore(gameId);
    if (score > currentHighScore) {
      await _prefs?.setInt('highscore_$gameId', score);
    }
  }

  // --- Players Roster ---
  static const String _savedPlayersKey = 'saved_players_roster';

  static List<Map<String, String>> getSavedPlayersProfiles() {
    final list = _prefs?.getStringList(_savedPlayersKey) ?? [];
    return list.map((item) {
      try {
        return Map<String, String>.from(jsonDecode(item));
      } catch (_) {
        // Fallback for old format (plain name)
        return {'name': item, 'avatar': ''};
      }
    }).toList();
  }

  static List<String> getSavedPlayers() {
    // Keep for backward compatibility if needed, but return only names
    return getSavedPlayersProfiles().map((p) => p['name']!).toList();
  }

  static Future<void> savePlayersProfiles(List<Map<String, String>> profiles) async {
    final List<String> list = profiles.map((p) => jsonEncode(p)).toList();
    await _prefs?.setStringList(_savedPlayersKey, list);
  }

  static Future<void> savePlayers(List<String> players) async {
    // Migrate plain names to empty avatar profiles
    final profiles = players.map((name) => {'name': name, 'avatar': ''}).toList();
    await savePlayersProfiles(profiles);
  }

  // --- GitHub AI Tokens ---
  static List<String> get githubTokens => [
        // Add your GitHub token here
        // 'your_github_token_here',
      ];

  static bool get isAiEnabled => githubTokens.isNotEmpty;

  // --- Current User Profile ---
  static String get userName => _prefs?.getString(_userNameKey) ?? '';
  static String? get userAvatar => _prefs?.getString(_userAvatarKey);

  static Future<void> setUserName(String name) async {
    await _prefs?.setString(_userNameKey, name);
    // Sync with global profiles
    SupabaseService.syncProfile(
      deviceId: deviceId,
      name: name,
      avatar: userAvatar,
    ).catchError((_) {});
  }

  static Future<void> setUserAvatar(String? base64) async {
    if (base64 == null) {
      await _prefs?.remove(_userAvatarKey);
    } else {
      await _prefs?.setString(_userAvatarKey, base64);
    }
    // Sync with global profiles
    SupabaseService.syncProfile(
      deviceId: deviceId,
      name: userName,
      avatar: base64,
    ).catchError((_) {});
  }

  // --- Device Identification ---
  static String get deviceId {
    String? id = _prefs?.getString(_deviceIdKey);
    if (id == null || id.isEmpty) {
      id = 'dev_${DateTime.now().millisecondsSinceEpoch}_${(1000 + (double.nan.hashCode % 9000))}';
      _prefs?.setString(_deviceIdKey, id);
    }
    return id;
  }
}

import 'package:flutter/material.dart';
import 'settings_service.dart';
import 'avatar_service.dart';

/// Resolves the display name and avatar for a game seat (0-based) from the
/// user's own profile (seat 0) and the شلتي roster (seats 1-3), so win
/// screens, banners and the leaderboard show real names instead of 'لاعب N'.
/// Falls back to 'لاعب N' when a seat has no saved name.
class PlayerNames {
  PlayerNames._();

  static String name(int seat) {
    if (seat == 0) {
      final n = SettingsService.userName.trim();
      if (n.isNotEmpty) return n;
    } else {
      final roster = SettingsService.getSavedPlayersProfiles();
      final i = seat - 1;
      if (i >= 0 && i < roster.length) {
        final n = (roster[i]['name'] ?? '').trim();
        if (n.isNotEmpty) return n;
      }
    }
    return 'لاعب ${seat + 1}';
  }

  static ImageProvider? avatar(int seat) {
    if (seat == 0) {
      return AvatarService.providerFor(SettingsService.userAvatar);
    }
    final roster = SettingsService.getSavedPlayersProfiles();
    final i = seat - 1;
    if (i >= 0 && i < roster.length) {
      return AvatarService.providerFor(roster[i]['avatar']);
    }
    return null;
  }
}

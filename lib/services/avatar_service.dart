import 'dart:convert';
import 'package:flutter/material.dart';

/// Built-in avatar artwork for الشلة: original 2D character portraits derived
/// from Shla's own cover art (friend cutouts, alpha-cleaned, head-cropped onto
/// pastel circles). Stored as asset paths; a profile's `avatar` field holds
/// either `asset:<path>` for one of these or a base64 photo string.
class AvatarService {
  static const List<String> builtInAvatars = [
    'assets/avatars/avatar_girl.png',
    'assets/avatars/avatar_boy_green.png',
    'assets/avatars/avatar_boy_blue.png',
    'assets/avatars/card_blue.png',
    'assets/avatars/card_purple.png',
    'assets/avatars/card_green.png',
    'assets/avatars/card_hijab.png',
    'assets/avatars/card_headband.png',
    'assets/avatars/card_glasses.png',
    'assets/avatars/card_red.png',
    'assets/avatars/card_yellow.png',
  ];

  /// Avatars offered in the picker: the first three legacy ones stay in
  /// [builtInAvatars] so saved `asset:` ids keep resolving, but are hidden.
  static List<String> get pickerAvatars => builtInAvatars.sublist(3);

  static const String assetPrefix = 'asset:';

  static bool isBuiltIn(String avatar) => avatar.startsWith(assetPrefix);

  /// Resolves a stored avatar value to an [ImageProvider], or null when the
  /// value is empty (callers show their placeholder icon then).
  static ImageProvider? providerFor(String? avatar) {
    if (avatar == null || avatar.isEmpty) return null;
    if (isBuiltIn(avatar)) {
      return AssetImage(avatar.substring(assetPrefix.length));
    }
    try {
      return MemoryImage(base64Decode(avatar));
    } catch (_) {
      return null;
    }
  }
}

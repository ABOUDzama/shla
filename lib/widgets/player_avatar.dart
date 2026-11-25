import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/avatar_service.dart';
import '../services/voice_chat_service.dart';
import '../theme/funky_theme.dart';

/// Circular player avatar: base64 photo when available, otherwise a colored
/// initial derived deterministically from the name. Optional host crown and
/// live speaking ring (driven by VoiceChatService).
class PlayerAvatar extends StatelessWidget {
  final String name;
  final String? avatar;
  final String? playerId;
  final double size;
  final bool enableSpeakingIndicator;
  final bool isHost;

  const PlayerAvatar({
    super.key,
    required this.name,
    this.avatar,
    this.playerId,
    this.size = 48,
    this.enableSpeakingIndicator = false,
    this.isHost = false,
  });

  static const List<List<Color>> _palettes = [
    [FunkyColors.magenta, FunkyColors.violet],
    [Color(0xFF14B8A6), Color(0xFF06B6D4)],
    [Color(0xFFF59E0B), Color(0xFFEF4444)],
    [Color(0xFFEC4899), Color(0xFFF43F5E)],
    [Color(0xFF22C55E), Color(0xFF84CC16)],
    [Color(0xFF3B82F6), Color(0xFF06B6D4)],
    [Color(0xFFA855F7), Color(0xFFEC4899)],
    [Color(0xFFF97316), Color(0xFFFBBF24)],
  ];

  List<Color> _colors() {
    final key = (playerId ?? name).trim();
    final idx = key.isEmpty ? 0 : key.codeUnits.fold<int>(0, (a, b) => a + b) % _palettes.length;
    return _palettes[idx];
  }

  ImageProvider? _avatarProvider() => AvatarService.providerFor(avatar);

  @override
  Widget build(BuildContext context) {
    final provider = _avatarProvider();
    final colors = _colors();
    final initial = name.trim().isEmpty ? '؟' : name.trim()[0];

    Widget circle = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        border: Border.all(color: Colors.white24, width: 1.5),
        image: provider != null
            ? DecorationImage(image: provider, fit: BoxFit.cover)
            : null,
      ),
      alignment: Alignment.center,
      child: provider == null
          ? Text(
              initial,
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: size * 0.42,
              ),
            )
          : null,
    );

    if (enableSpeakingIndicator && playerId != null) {
      circle = StreamBuilder<Set<String>>(
        stream: VoiceChatService().speakingStream,
        initialData: VoiceChatService().currentSpeakingIds,
        builder: (context, snapshot) {
          final speaking = snapshot.data?.contains(playerId) ?? false;
          if (!speaking) return circle;
          return circle
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .boxShadow(
                begin: const BoxShadow(
                  color: Color(0xAA22C55E),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
                end: const BoxShadow(
                  color: Color(0xAA22C55E),
                  blurRadius: 14,
                  spreadRadius: 4,
                ),
                duration: 600.ms,
              );
        },
      );
    }

    if (!isHost) return circle;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        circle,
        Positioned(
          top: -size * 0.22,
          right: -size * 0.1,
          child: Text('👑', style: TextStyle(fontSize: size * 0.34)),
        ),
      ],
    );
  }
}

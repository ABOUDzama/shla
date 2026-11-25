import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/flat_theme.dart';

/// Light victory celebration: the Shla friends cheer the match winner.
/// Shown only on match-over screens — never during gameplay.
class VictoryFriends extends StatelessWidget {
  /// Winner display name, e.g. 'لاعب 2' or a saved friend's name.
  final String winnerName;

  const VictoryFriends({super.key, required this.winnerName});

  static const _friends = [
    'assets/avatars_2d/friend1.png',
    'assets/avatars_2d/friend2.png',
    'assets/avatars_2d/friend3.png',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 110,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < _friends.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Image.asset(_friends[i], height: 104)
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .moveY(
                        begin: 0,
                        end: -8 - i * 3,
                        duration: (500 + i * 120).ms,
                        curve: Curves.easeInOut,
                      ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '$winnerName كسب! 🎉',
          style: flatCairo(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ).copyWith(fontFamilyFallback: const ['Noto Color Emoji']),
        ).animate().scale(
            begin: const Offset(0.8, 0.8),
            end: const Offset(1, 1),
            duration: 300.ms),
      ],
    );
  }
}

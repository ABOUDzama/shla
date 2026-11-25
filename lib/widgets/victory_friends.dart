import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/flat_theme.dart';
import '../services/results_service.dart';

/// Light victory celebration: the Shla friends cheer the match winner.
/// Shown only on match-over screens — never during gameplay.
class VictoryFriends extends StatefulWidget {
  /// Winner display name, e.g. 'لاعب 2' or a saved friend's name.
  final String winnerName;

  /// When set, the win is recorded once in the الترتيب history.
  final String? gameTitle;

  const VictoryFriends({super.key, required this.winnerName, this.gameTitle});

  @override
  State<VictoryFriends> createState() => _VictoryFriendsState();
}

class _VictoryFriendsState extends State<VictoryFriends> {
  @override
  void initState() {
    super.initState();
    final g = widget.gameTitle;
    if (g != null) {
      ResultsService.instance.recordWin(game: g, winner: widget.winnerName);
    }
  }


  static const _friends = [
    'assets/avatars/card_blue.png',
    'assets/avatars/card_purple.png',
    'assets/avatars/card_yellow.png',
    'assets/avatars/card_hijab.png',
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
                  child: Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: FlatColors.ink, width: 2.5),
                      image: DecorationImage(
                          image: AssetImage(_friends[i]), fit: BoxFit.cover),
                    ),
                  )
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
          '${widget.winnerName} كسب! 🎉',
          style: flatCairo(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: FlatColors.ink,
          ).copyWith(fontFamilyFallback: const ['Noto Color Emoji']),
        ).animate().scale(
            begin: const Offset(0.8, 0.8),
            end: const Offset(1, 1),
            duration: 300.ms),
      ],
    );
  }
}

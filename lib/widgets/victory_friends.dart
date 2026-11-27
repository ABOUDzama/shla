import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/flat_theme.dart';
import '../services/results_service.dart';
import '../services/player_names.dart';

/// Light victory celebration: the Shla friends cheer the match winner.
/// Shown only on match-over screens — never during gameplay.
class VictoryFriends extends StatefulWidget {
  /// Winner display name, e.g. 'لاعب 2' or a saved friend's name.
  final String winnerName;

  /// When set, the win is recorded once in the الترتيب history.
  final String? gameTitle;

  /// Seats (0-3) that won, to crown. Defaults to every 'لاعب N' label found
  /// in the winnerName: a single winner ('لاعب 2') crowns one seat, a shared
  /// win ('لاعب 1 و لاعب 3') crowns each named seat. When the name carries no
  /// seat label (a friend name, a bot) nobody is crowned (we never guess a
  /// winner among the four avatars).
  final List<int>? winnerSeats;

  const VictoryFriends(
      {super.key, required this.winnerName, this.gameTitle, this.winnerSeats});

  List<int> get seats {
    if (winnerSeats != null) return winnerSeats!;
    return RegExp(r'لاعب\s*([1-4])')
        .allMatches(winnerName.trim())
        .map((m) => int.parse(m.group(1)!) - 1)
        .toList(growable: false);
  }

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

  Widget _avatar(int i) {
    final crowned = widget.seats.contains(i);
    final dim = widget.seats.isNotEmpty && !crowned;
    final size = crowned ? 92.0 : 72.0;
    final avatar = Opacity(
      opacity: dim ? 0.55 : 1,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
              color: crowned ? const Color(0xFFE0A800) : FlatColors.ink,
              width: crowned ? 4 : 2.5),
          image: DecorationImage(
              image: PlayerNames.avatar(i) ?? AssetImage(_friends[i]),
              fit: BoxFit.cover),
        ),
      ),
    );
    final col = Column(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(
        height: 30,
        child: crowned
            ? CustomPaint(key: ValueKey('crown_$i'), size: const Size(44, 30), painter: _CrownPainter())
            : null,
      ),
      avatar,
      const SizedBox(height: 2),
      if (widget.seats.isNotEmpty)
        Text(PlayerNames.name(i),
            textDirection: TextDirection.rtl,
            overflow: TextOverflow.ellipsis,
            style: flatCairo(fontSize: 11, fontWeight: FontWeight.w800, color: FlatColors.ink)),
    ]);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: crowned
          ? col.animate(onPlay: (c) => c.repeat(reverse: true)).moveY(
              begin: 0, end: -8, duration: 600.ms, curve: Curves.easeInOut)
          : col,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 150,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < _friends.length; i++) _avatar(i),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${widget.winnerName} كسب! 🎉',
          textDirection: TextDirection.rtl,
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

class _CrownPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final path = Path()
      ..moveTo(2, h - 2)
      ..lineTo(0, 6)
      ..lineTo(w * 0.25, h * 0.5)
      ..lineTo(w * 0.5, 0)
      ..lineTo(w * 0.75, h * 0.5)
      ..lineTo(w, 6)
      ..lineTo(w - 2, h - 2)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFFFFC928));
    canvas.drawPath(path, Paint()..color = FlatColors.ink..style = PaintingStyle.stroke..strokeWidth = 2.5..strokeJoin = StrokeJoin.round);
    for (final x in [0.25, 0.5, 0.75]) {
      canvas.drawCircle(Offset(w * x, h - 9), 2.6, Paint()..color = const Color(0xFFE5483B));
    }
  }

  @override
  bool shouldRepaint(covariant _CrownPainter old) => false;
}

/// Shared "bots won" label: records the bots win once (the way
/// [VictoryFriends] records human wins) so a cup round closes with no
/// points instead of looking abandoned, and renders the label.
class BotsWinLabel extends StatefulWidget {
  const BotsWinLabel({super.key, required this.gameTitle, this.style});

  /// The game's registry title, exactly as [VictoryFriends.gameTitle].
  final String gameTitle;
  final TextStyle? style;

  @override
  State<BotsWinLabel> createState() => _BotsWinLabelState();
}

class _BotsWinLabelState extends State<BotsWinLabel> {
  @override
  void initState() {
    super.initState();
    ResultsService.instance
        .recordWin(game: widget.gameTitle, winner: kBotsWinnerLabel);
  }

  @override
  Widget build(BuildContext context) => Text(kBotsWinnerLabel,
      style: widget.style, textDirection: TextDirection.rtl);
}

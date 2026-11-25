import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/game_model.dart';
import '../services/game_registry.dart';
import '../theme/flat_theme.dart';
import '../theme/funky_theme.dart';

/// Dedicated ١٢٣٤ section: same-phone 2/3/4-player arcade games with a
/// distinct neon-arcade look, a player-count filter, and big quick-launch
/// tiles. Games register via GameModel.arcade1234.
class ArcadeSectionScreen extends StatefulWidget {
  /// True when hosted inside HomeScreen's tab switcher (no own nav bar).
  final bool embedded;

  const ArcadeSectionScreen({super.key, this.embedded = false});

  /// Player counts per ١٢٣٤ game title. سومو is 2-player head-to-head;
  /// the rest support 2, 3 and 4.
  static const Map<String, List<int>> playerCounts = {
    'أسرع رد فعل': [2, 3, 4],
    'حية الشلة': [2, 3, 4],
    'سومو الشلة': [2],
    'اقطفها': [2, 3, 4],
    'سباق الدوس': [2, 3, 4],
    'كورة اللمسة': [2, 3, 4],
  };

  static const Map<String, String> _emoji = {
    'أسرع رد فعل': '⚡',
    'حية الشلة': '🐍',
    'سومو الشلة': '🤼',
    'اقطفها': '🐟',
    'سباق الدوس': '👟',
    'كورة اللمسة': '⚽',
  };

  @override
  State<ArcadeSectionScreen> createState() => _ArcadeSectionScreenState();
}

class _ArcadeSectionScreenState extends State<ArcadeSectionScreen> {
  /// 0 = الكل, otherwise the player count filter (2/3/4).
  int _filter = 0;

  String _playersLabel(List<int> counts) {
    if (counts.length == 1) return 'لاعبين بس';
    const arDigits = ['١', '٢', '٣', '٤'];
    // No hyphen: '-' renders as a tofu box in the bundled font weights.
    return 'حتى ${arDigits[counts.last - 1]} لاعبين';
  }

  @override
  Widget build(BuildContext context) {
    final games = GameRegistry.games.where((g) => g.arcade1234).toList();
    final shown = games.where((g) {
      if (_filter == 0) return true;
      final counts = ArcadeSectionScreen.playerCounts[g.title] ?? const [2, 3, 4];
      return counts.contains(_filter);
    }).toList();

    final body = SafeArea(
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
        children: [
          Center(
            child: Text(
              'ألعاب ١٢٣٤',
              style: GoogleFonts.cairo(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              'الكل على نفس الموبايل — اختاروا عددكم والعبوا على طول',
              style: GoogleFonts.cairo(fontSize: 13, color: Colors.white70),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final (label, value) in [
                ('الكل', 0),
                ('٢', 2),
                ('٣', 3),
                ('٤', 4),
              ])
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: GestureDetector(
                    onTap: () => setState(() => _filter = value),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 8),
                      decoration: BoxDecoration(
                        color: _filter == value
                            ? FunkyColors.lime
                            : Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _filter == value
                              ? FunkyColors.lime
                              : Colors.white24,
                          width: 2,
                        ),
                      ),
                      child: Text(
                        label,
                        style: GoogleFonts.cairo(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: _filter == value
                              ? FunkyColors.bgDeep
                              : Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          for (final game in shown)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ArcadeTile(
                game: game,
                emoji: ArcadeSectionScreen._emoji[game.title] ?? '🎮',
                playersLabel: _playersLabel(
                    ArcadeSectionScreen.playerCounts[game.title] ??
                        const [2, 3, 4]),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => game.screen),
                ),
              ),
            ),
          if (shown.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'مفيش ألعاب بالعدد ده لسه',
                  style:
                      GoogleFonts.cairo(fontSize: 15, color: Colors.white70),
                ),
              ),
            ),
        ],
      ),
    );

    if (widget.embedded) {
      return Container(key: const ValueKey('arcade_section'), color: FunkyColors.bgDeep, child: body);
    }
    return Scaffold(backgroundColor: FunkyColors.bgDeep, body: body);
  }
}

class _ArcadeTile extends StatelessWidget {
  final GameModel game;
  final String emoji;
  final String playersLabel;
  final VoidCallback onTap;

  const _ArcadeTile({
    required this.game,
    required this.emoji,
    required this.playersLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: game.color.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: game.color, width: 2.5),
        ),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: game.color,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 30)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    game.title,
                    style: GoogleFonts.cairo(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    game.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.cairo(
                        fontSize: 12, color: Colors.white70, height: 1.3),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                playersLabel,
                style: GoogleFonts.cairo(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

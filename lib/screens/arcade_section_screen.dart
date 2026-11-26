import 'package:flutter/material.dart';
import '../theme/flat_theme.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/game_model.dart';
import '../services/cup_service.dart';
import '../services/game_registry.dart';
import '../theme/funky_theme.dart';
import 'cup/cup_screen.dart';
import 'cup/cup_setup_screen.dart';

/// ألعاب ١٢٣٤ lobby: a card grid of illustrated game covers.
///
/// Flow is game-first: tap a cover, then pick the player count inside the
/// game itself. Covers are placeholder gradients + emoji until the
/// generated cover art lands (tagged 'غلاف مؤقت' honestly).
class ArcadeSectionScreen extends StatefulWidget {
  const ArcadeSectionScreen({super.key, this.embedded = false, this.onOpenCup});

  /// When true, renders without its own Scaffold (embedded as a home tab).
  final bool embedded;

  /// When set, the cup banner jumps to this callback (the cup home tab)
  /// instead of pushing the cup screens.
  final VoidCallback? onOpenCup;

  /// Player counts per ١٢٣٤ game title. سومو is 2-player head-to-head;
  /// the rest support 2, 3 and 4.
  static const Map<String, List<int>> playerCounts = {
    'أسرع رد فعل': [2, 3, 4],
    'حية الشلة': [2, 3, 4],
    'دبابات الشلة': [2, 3, 4],
    'شد الحبل': [2, 3, 4],
    'معركة التلج': [2, 3, 4],
    'لمّ الفلوس': [2, 3, 4],
    'اضرب الخلد': [2, 3, 4],
    'سومو الشلة': [2],
    'اقطفها': [2, 3, 4],
    'سباق الدوس': [2, 3, 4],
    'كورة اللمسة': [2, 3, 4],
    'جري الفراخ': [1, 2, 3, 4],
    'سباق العربيات': [1, 2, 3, 4],
    'ميكرو ريسرز': [1, 2, 3, 4],
    'فليك الشلة': [1, 2, 3, 4],
    'جري الجون': [1, 2, 3, 4],
    'أطعم الحمامة': [1, 2, 3, 4],
    'لودو الشلة': [1, 2, 3, 4],
    'تمساح الشلة': [1, 2, 3, 4],
    'فلابي الشلة': [1, 2, 3, 4],
    'جولف الشلة': [1, 2, 3, 4],
    'سباق العوائق': [1, 2, 3, 4],
    'تصويب الشلة': [1, 2, 3, 4],
    'حرب البطاريق': [1, 2],
    'وحش المدار': [1, 2, 3, 4],
    'كوالا الفضاء': [1, 2, 3, 4],
  };

  /// Original illustrated covers (drawn in-house). Cards with a cover show
  /// the artwork; the rest keep the gradient placeholder until their art
  /// lands (tagged 'غلاف مؤقت').
  static const Map<String, String> covers = {
    'حية الشلة': 'assets/covers/snake_arena.png',
    'أسرع رد فعل': 'assets/covers/reaction.png',
    'شد الحبل': 'assets/covers/tug_of_war.png',
    'دبابات الشلة': 'assets/covers/tank_battle.png',
    'اقطفها': 'assets/covers/catch.png',
    'سومو الشلة': 'assets/covers/sumo.png',
    'معركة التلج': 'assets/covers/snow_brawl.png',
    'لمّ الفلوس': 'assets/covers/coin_grab.png',
    'سباق الدوس': 'assets/covers/tap_race.png',
    'كورة اللمسة': 'assets/covers/touch_ball.png',
    'اضرب الخلد': 'assets/covers/whack_mole.png',
    'جري الفراخ': 'assets/covers/chicken_run.png',
    'سباق العربيات': 'assets/covers/car_race.png',
    'أطعم الحمامة': 'assets/covers/pigeon.png',
  };

  /// Emoji fallback for a ١٢٣٤ game title (used by the cup screens too).
  static String emojiOf(String title) => _emoji[title] ?? '🎮';

  static const Map<String, String> _emoji = {
    'أسرع رد فعل': '⚡',
    'حية الشلة': '🐍',
    'دبابات الشلة': '💥',
    'شد الحبل': '💪',
    'معركة التلج': '❄',
    'لمّ الفلوس': '🪙',
    'اضرب الخلد': '🔨',
    'سومو الشلة': '🤼',
    'اقطفها': '🐟',
    'سباق الدوس': '👟',
    'كورة اللمسة': '⚽',
    'جري الفراخ': '🐔',
    'سباق العربيات': '🏎',
    'ميكرو ريسرز': '🏁',
    'فليك الشلة': '⚽',
    'جري الجون': '🥅',
    'أطعم الحمامة': '🐦',
    'تحدي الإيقاع': '🥁',
    'لودو الشلة': '🎲',
    'تمساح الشلة': '🐊',
  };

  @override
  State<ArcadeSectionScreen> createState() => _ArcadeSectionScreenState();
}

class _ArcadeSectionScreenState extends State<ArcadeSectionScreen> {
  static const _emojiFallback = ['Noto Color Emoji'];

  @override
  void initState() {
    super.initState();
    CupService.instance.restore().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final games =
        GameRegistry.games.where((g) => g.arcade1234).toList();

    final body = SafeArea(
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Center(
                child: Text(
                  'ألعاب 1234',
                  style: GoogleFonts.cairo(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: FlatColors.ink,
                  ).copyWith(fontFamilyFallback: _emojiFallback),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Center(
              child: Text(
                'اختار اللعبة، وبعدين حددوا عدد اللاعبين جواها 🎮',
                style: GoogleFonts.cairo(
                  fontSize: 13,
                  color: FlatColors.ink.withValues(alpha: 0.75),
                ).copyWith(fontFamilyFallback: _emojiFallback),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: _CupBanner(
                  emojiFallback: _emojiFallback, onOpenCup: widget.onOpenCup),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 14)),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 132),
            sliver: SliverGrid(
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.86,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, i) => _ArcadeCard(
                  cover: ArcadeSectionScreen.covers[games[i].title],
                  game: games[i],
                  emoji: ArcadeSectionScreen._emoji[games[i].title] ?? '🎮',
                  counts:
                      ArcadeSectionScreen.playerCounts[games[i].title] ??
                          const [2, 3, 4],
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => games[i].screen),
                  ),
                ),
                childCount: games.length,
              ),
            ),
          ),
        ],
      ),
    );

    if (widget.embedded) {
      return Container(
        key: const ValueKey('arcade_section'),
        color: FlatColors.bg,
        child: body,
      );
    }
    return Scaffold(backgroundColor: FlatColors.bg, body: body);
  }
}

class _ArcadeCard extends StatelessWidget {
  final GameModel game;
  final String emoji;
  final List<int> counts;
  final VoidCallback onTap;

  const _ArcadeCard({
    required this.game,
    required this.emoji,
    required this.counts,
    required this.onTap,
    this.cover,
  });

  final String? cover;

  static const _emojiFallback = ['Noto Color Emoji'];
  static const _arDigits = ['١', '٢', '٣', '٤'];

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: FlatColors.border, width: 2),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color.lerp(game.color, Colors.white, 0.45)!,
                          Color.lerp(game.color, Colors.white, 0.7)!,
                        ],
                      ),
                    ),
                  ),
                  if (cover != null)
                    Image.asset(
                      cover!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Center(
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 46).copyWith(
                              fontFamilyFallback: _emojiFallback),
                        ),
                      ),
                    )
                  else
                    Center(
                      child: Text(
                        emoji,
                        style: const TextStyle(fontSize: 46)
                            .copyWith(fontFamilyFallback: _emojiFallback),
                      ),
                    ),
                  if (cover == null)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: FlatColors.border),
                      ),
                      child: Text(
                        'غلاف مؤقت',
                        style: GoogleFonts.cairo(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: FlatColors.ink,
                        ).copyWith(fontFamilyFallback: _emojiFallback),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    game.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.cairo(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: FlatColors.ink,
                    ).copyWith(fontFamilyFallback: _emojiFallback),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      for (final n in counts)
                        Container(
                          margin: const EdgeInsets.only(left: 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 1),
                          decoration: BoxDecoration(
                            color: Color.lerp(game.color, Colors.white, 0.75),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: FlatColors.border),
                          ),
                          child: Text(
                            counts.length == 1
                                ? '${_arDigits[n - 1]} بس'
                                : _arDigits[n - 1],
                            style: GoogleFonts.cairo(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: FlatColors.ink,
                            ).copyWith(fontFamilyFallback: _emojiFallback),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Golden كأس الشلة banner on top of the ١٢٣٤ tab: starts a new cup, or
/// resumes the running one.
class _CupBanner extends StatelessWidget {
  final List<String> emojiFallback;
  final VoidCallback? onOpenCup;
  const _CupBanner({required this.emojiFallback, this.onOpenCup});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: CupService.instance,
      builder: (context, _) {
        final cup = CupService.instance;
        final running = cup.active && !cup.finished;
        final label = running
            ? 'الكأس شغال: الجولة ${cup.roundNumber} من ${cup.rounds} — كمّل 🏆'
            : 'كأس الشلة 🏆';
        final sub = running
            ? 'ارجع كمّل البطولة من حيث وقفت'
            : 'بطولة جولات من ألعاب ١٢٣٤ — كل فوز بنقطة، والأكتر نقاط ياخد الكأس';
        return InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onOpenCup ??
              () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          running ? const CupScreen() : const CupSetupScreen(),
                    ),
                  ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: FlatColors.tilePastels[4],
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                const Text('🏆', style: TextStyle(fontSize: 36)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: GoogleFonts.cairo(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: FlatColors.ink,
                        ).copyWith(fontFamilyFallback: emojiFallback),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        sub,
                        style: GoogleFonts.cairo(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: FlatColors.ink.withValues(alpha: 0.75),
                        ).copyWith(fontFamilyFallback: emojiFallback),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded,
                    size: 16, color: FlatColors.ink),
              ],
            ),
          ),
        );
      },
    );
  }
}

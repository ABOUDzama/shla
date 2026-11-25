import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../services/avatar_service.dart';
import '../services/settings_service.dart';
import '../services/game_registry.dart';
import '../models/game_model.dart';
import '../theme/flat_theme.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'shellty_screen.dart';
import 'arcade_section_screen.dart';

/// Home — flat/cartoon direction (user-approved WePlay reference):
/// light cream background, flat pastel game tiles with a big emoji
/// "character" each, tiny tags, plain chrome. No gradients, no glow.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isNavigating = false;
  int _tab = 0; // 0 = الألعاب, 1 = شلتي, 2 = ألعاب ١٢٣٤
  final Random _rand = Random();

  /// Big emoji "character" per game tile (all verified against the bundled
  /// emoji font).
  static const Map<String, String> _gameEmoji = {
    'إكس أو': '❌',
    'السيجة': '⭕',
    'جوبلت': '🥤',
    'لعبة الأسئلة': '❓',
    'قنبلة الحروف': '💣',
    'معركة التلج': '❄',
    'لمّ الفلوس': '🪙',
    'اضرب الخلد': '🔨',
    'تحدي اللمس': '👆',
    'تحدي التوازن': '⚖',
    'تحدي الـ ٥ ثواني': '⏱',
    'الأسئلة المعكوسة': '🙃',
    'طلع الغريب': '🤔',
    'أول حرف': '🔤',
    'عكس العكاس': '🔄',
    'مين أنا؟': '🎭',
    'سلسلة الكلمات': '⛓',
    'صراحة ولا جرأة': '😈',
    'ارسم وخمّن': '✏',
    'تمثيل صامت': '🎬',
    'حقيقة أو هبد': '🤥',
    'تحدي الترتيب': '🔢',
    'أتوبيس كومبليت': '🚌',
    'مين فينا؟': '👀',
    'كلمات ممنوعة': '🚫',
    'ذاكرة الشلة': '🧠',
    'مين قالها؟': '💬',
    'أكمل المثل': '📜',
    'أندر كافر': '🥷',
    'مافيا': '🔫',
    'الجاسوس': '🕵',
    'كلمة السر': '🔑',
    'إيموجي إيه؟': '🧩',
    'لو خيروك': '🤔',
    'أنا عمري ما': '✋',
    'كلمة بكلمة': '📖',
    'الشيفرة': '🕵',
    'أسرع رد فعل': '⚡',
    'حية الشلة': '🐍',
    'دبابات الشلة': '💥',
    'شد الحبل': '💪',
    'سومو الشلة': '🤼',
    'اقطفها': '🐟',
    'سباق الدوس': '👟',
    'كورة اللمسة': '⚽',
  };

  /// Original illustrated artwork per game: generated in-house for Shla
  /// (WePlay-inspired richness, original characters and scenes). A tile with
  /// art renders the illustration; the rest keep the emoji tile until their
  /// artwork is generated.
  static const Map<String, String> _gameArt = {
    'إكس أو': 'assets/tiles/xo.png',
    'السيجة': 'assets/tiles/seega.png',
    'جوبلت': 'assets/tiles/goblet.png',
    'لعبة الأسئلة': 'assets/tiles/questions.png',
    'قنبلة الحروف': 'assets/tiles/letter_bomb.png',
    'تحدي اللمس': 'assets/tiles/touch.png',
    'تحدي التوازن': 'assets/tiles/balance.png',
    'تحدي الـ ٥ ثواني': 'assets/tiles/five_seconds.png',
    'الأسئلة المعكوسة': 'assets/tiles/reverse_quiz.png',
    'طلع الغريب': 'assets/tiles/odd_one.png',
    'أول حرف': 'assets/tiles/first_letter.png',
    'عكس العكاس': 'assets/tiles/opposite.png',
    'كلمة بكلمة': 'assets/tiles/story.png',
    'الشيفرة': 'assets/tiles/code.png',
    'مافيا': 'assets/tiles/mafia.png',
    'لو خيروك': 'assets/tiles/would_rather.png',
    'أنا عمري ما': 'assets/tiles/never_have_i.png',
    'تحدي الترتيب': 'assets/tiles/ranking.png',
    'أتوبيس كومبليت': 'assets/tiles/bus.png',
    'مين فينا؟': 'assets/tiles/most_likely.png',
    'كلمات ممنوعة': 'assets/tiles/taboo.png',
    'ذاكرة الشلة': 'assets/tiles/memory.png',
    'مين قالها؟': 'assets/tiles/who_said.png',
    'أكمل المثل': 'assets/tiles/proverb.jpg',
    'أندر كافر': 'assets/tiles/undercover.png',
    'الجاسوس': 'assets/tiles/spy.png',
    'كلمة السر': 'assets/tiles/password.png',
    'إيموجي إيه؟': 'assets/tiles/emoji_guess.png',
    'ارسم وخمّن': 'assets/tiles/draw.png',
    'تمثيل صامت': 'assets/tiles/charades.png',
    'حقيقة أو هبد': 'assets/tiles/truth_cap.png',
    'صراحة ولا جرأة': 'assets/tiles/truth_dare.png',
    'مين أنا؟': 'assets/tiles/who_am_i.png',
    'سلسلة الكلمات': 'assets/tiles/word_chain.png',
  };

  void _handleNavigation(Widget screen) async {
    if (_isNavigating) return;
    setState(() => _isNavigating = true);
    try {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => screen),
      );
    } finally {
      if (mounted) setState(() => _isNavigating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // User instruction (2026-11-25): 1234 arcade games live exclusively in
    // the ١٢٣٤ section, never duplicated in the main الألعاب grid.
    final games =
        GameRegistry.games.where((g) => g.arcade1234 != true).toList();

    return Scaffold(
      backgroundColor: FlatColors.bg,
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(opacity: animation, child: child);
              },
              child: _tab == 1
                  ? const ShelltyScreen(embedded: true)
                  : _tab == 2
                      ? const ArcadeSectionScreen(embedded: true)
                      : SafeArea(
                      key: const ValueKey('games_feed'),
                      child: ListView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
                        children: [
                          _buildHeader(),
                          const SizedBox(height: 10),
                          _buildWelcomeFriends(),
                          const SizedBox(height: 10),
                          _buildRandomCta(games),
                          const SizedBox(height: 18),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text('كل الألعاب 🎮',
                                style: FlatDecor.title(size: 18)),
                          ),
                          const SizedBox(height: 12),
                          GridView.count(
                            crossAxisCount: 2,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            mainAxisSpacing: 14,
                            crossAxisSpacing: 14,
                            childAspectRatio: 0.95,
                            children: [
                              for (var i = 0; i < games.length; i++)
                                _FlatGameTile(
                                  game: games[i],
                                  emoji: _gameEmoji[games[i].title] ?? '🎮',
                                  art: _gameArt[games[i].title],
                                  color: FlatColors.tilePastels[
                                      i % FlatColors.tilePastels.length],
                                  onTap: () =>
                                      _handleNavigation(games[i].screen),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 26,
            child: _buildBottomNav(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        _FlatRoundButton(
          onTap: () => _handleNavigation(const ProfileScreen()),
          child: CircleAvatar(
            radius: 18,
            backgroundColor: Colors.transparent,
            backgroundImage:
                AvatarService.providerFor(SettingsService.userAvatar),
            child: SettingsService.userAvatar == null
                ? const Icon(Icons.person,
                    size: 20, color: FlatColors.ink)
                : null,
          ),
        ),
        Expanded(
          child: Column(
            children: [
              Text('شِلَّة', style: FlatDecor.title(size: 28)),
              Text(
                'اختاروا لعبتكم وشعّلوا الدنيا 🎉',
                style: FlatDecor.body(size: 12.5),
              ),
            ],
          ),
        ),
        _FlatRoundButton(
          onTap: () => _handleNavigation(const SettingsScreen()),
          child: const Icon(Icons.settings_rounded,
              color: FlatColors.ink, size: 20),
        ),
      ],
    );
  }

  /// Approved 2D character use: light welcome strip on the home feed.
  Widget _buildWelcomeFriends() {
    const friends = [
      'assets/avatars_2d/friend2.png',
      'assets/avatars_2d/friend1.png',
      'assets/avatars_2d/friend3.png',
    ];
    return SizedBox(
      height: 64,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < friends.length; i++)
                Align(
                  widthFactor: 0.62,
                  child: Image.asset(friends[i], height: 62),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRandomCta(List<GameModel> games) {
    return GestureDetector(
      onTap: () =>
          _handleNavigation(games[_rand.nextInt(games.length)].screen),
      child: Container(
        decoration: FlatDecor.button(FlatColors.day, radius: 20),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            const Text('🎲', style: TextStyle(fontSize: 34))
                .animate(onPlay: (c) => c.repeat())
                .rotate(duration: 2.seconds, begin: -0.08, end: 0.08),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'مش عارفين تلعبوا إيه؟',
                    style: FlatDecor.title(size: 16, color: Colors.white),
                  ),
                  Text(
                    'دوس وهنختارلكوا لعبة عشوائية',
                    style:
                        FlatDecor.body(size: 12, color: Colors.white),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_back_rounded,
                color: Colors.white, size: 24),
          ],
        ),
      ),
    );
  }

  /// Deep-violet floating bar; each tab lights up in its own bright color.
  /// Redesigned 2026-11-25 after the user rejected the white pill.
  Widget _buildBottomNav() {
    return Container(
      height: 62,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: FlatColors.ink,
        borderRadius: BorderRadius.circular(40),
        boxShadow: const [
          BoxShadow(
            color: Color(0x552B2140),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          _modePill(
            label: 'الألعاب',
            icon: Icons.grid_view_rounded,
            activeColor: const Color(0xFFFF8A5C),
            active: _tab == 0,
            onTap: () {
              if (_tab != 0) setState(() => _tab = 0);
            },
          ),
          _modePill(
            label: 'شلتي',
            icon: Icons.groups_rounded,
            activeColor: const Color(0xFF35C99E),
            active: _tab == 1,
            onTap: () {
              if (_tab != 1) setState(() => _tab = 1);
            },
          ),
          _modePill(
            label: '١٢٣٤',
            icon: Icons.sports_esports_rounded,
            activeColor: const Color(0xFFFFC233),
            active: _tab == 2,
            onTap: () {
              if (_tab != 2) setState(() => _tab = 2);
            },
          ),
        ],
      ),
    );
  }

  Widget _modePill({
    required String label,
    required IconData icon,
    required Color activeColor,
    required bool active,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          decoration: BoxDecoration(
            color: active ? activeColor : Colors.transparent,
            borderRadius: BorderRadius.circular(32),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: active ? FlatColors.ink : Colors.white70,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: FlatDecor.title(
                  size: 13,
                  color: active ? FlatColors.ink : Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Flat white circular chrome button (plain border, no glow).
class _FlatRoundButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;

  const _FlatRoundButton({required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(color: FlatColors.border, width: 2),
        ),
        child: Center(child: child),
      ),
    );
  }
}

/// Flat pastel tile: solid color, big emoji "character", plain white title,
/// tiny flat tag when the game is new (WePlay home pattern).
class _FlatGameTile extends StatelessWidget {
  final GameModel game;
  final String emoji;
  final String? art;
  final Color color;
  final VoidCallback onTap;

  const _FlatGameTile({
    required this.game,
    required this.emoji,
    required this.art,
    required this.color,
    required this.onTap,
  });

  Widget _illustratedTile() {
    return Container(
      decoration: FlatDecor.tile(color),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(art!, fit: BoxFit.cover),
          ),
          Positioned(
            left: 8,
            right: 8,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      game.title,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: FlatDecor.title(size: 14),
                    ),
                  ),
                  // Badge lives inside the title pill: the artwork's safe
                  // zone (faces, focal crop) is never covered.
                  if (game.badge != null) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: FlatDecor.tag(),
                      child:
                          Text(game.badge!, style: FlatDecor.body(size: 10)),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (art != null) {
      return GestureDetector(onTap: onTap, child: _illustratedTile())
          .animate()
          .fadeIn(duration: 300.ms)
          .scale(begin: const Offset(0.96, 0.96), duration: 300.ms);
    }
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: FlatDecor.tile(color),
        padding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 48)),
                  const SizedBox(height: 8),
                  Text(
                    game.title,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: FlatDecor.title(size: 16, color: Colors.white),
                  ),
                ],
              ),
            ),
            if (game.badge != null)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: FlatDecor.tag(),
                  child: Text(game.badge!, style: FlatDecor.body(size: 11)),
                ),
              ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 300.ms)
        .scale(begin: const Offset(0.96, 0.96), duration: 300.ms);
  }
}

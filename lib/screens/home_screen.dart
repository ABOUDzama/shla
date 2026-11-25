import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/settings_service.dart';
import '../services/game_registry.dart';
import '../models/game_model.dart';
import '../theme/funky_theme.dart';
import 'lobby_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';

/// Home — full redesign: compact neon header, random-game CTA, and a
/// vertical feed of tilted "ticket" cards instead of the old 2-col grid.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isNavigating = false;
  bool _isOnlineMode = false;
  final Random _rand = Random();

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
    final games = GameRegistry.games;

    return Scaffold(
      body: Stack(
        children: [
          const FunkyBackground(accent: FunkyColors.cyan),
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(opacity: animation, child: child);
              },
              child: _isOnlineMode
                  ? const LobbyScreen(showBackButton: false)
                  : SafeArea(
                      key: const ValueKey('offline_feed'),
                      child: ListView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                        children: [
                          _buildHeader(),
                          const SizedBox(height: 14),
                          _buildRandomCta(games),
                          const SizedBox(height: 18),
                          Text(
                            'كل الألعاب',
                            style: GoogleFonts.cairo(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ).animate().fadeIn(duration: 400.ms),
                          const SizedBox(height: 10),
                          for (var i = 0; i < games.length; i++)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: _GameTicket(
                                game: games[i],
                                index: i,
                                onTap: () =>
                                    _handleNavigation(games[i].screen),
                              ),
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
            child: _buildModeSwitch(),
          ).animate().slideY(
                begin: 1.0,
                end: 0,
                duration: 800.ms,
                curve: Curves.easeOutBack,
              ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        _RoundIconButton(
          onTap: () => _handleNavigation(const ProfileScreen()),
          child: CircleAvatar(
            radius: 20,
            backgroundColor: FunkyColors.card,
            backgroundImage: SettingsService.userAvatar != null
                ? MemoryImage(base64Decode(SettingsService.userAvatar!))
                : null,
            child: SettingsService.userAvatar == null
                ? const Icon(Icons.person, size: 22, color: Colors.white70)
                : null,
          ),
        ),
        Expanded(
          child: Column(
            children: [
              Text(
                'شِلَّة',
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 34,
                  height: 1.1,
                  shadows: [
                    Shadow(
                      color: FunkyColors.cyan.withValues(alpha: 0.8),
                      blurRadius: 18,
                    ),
                    Shadow(
                      color: FunkyColors.magenta.withValues(alpha: 0.5),
                      blurRadius: 30,
                    ),
                  ],
                ),
              ).animate(onPlay: (c) => c.repeat(reverse: true)).shimmer(
                    duration: 2.5.seconds,
                    color: Colors.white38,
                  ),
              Text(
                'اختاروا لعبتكم وشعّلوا الدنيا 🎉',
                style: FunkyText.body(
                  size: 13,
                  color: Colors.white.withValues(alpha: 0.75),
                ),
              ).animate().fadeIn(delay: 200.ms, duration: 500.ms),
            ],
          ),
        ),
        _RoundIconButton(
          onTap: () => _handleNavigation(const SettingsScreen()),
          child: const Icon(
            Icons.settings_rounded,
            color: Colors.white,
            size: 22,
          ),
        ),
      ],
    );
  }

  Widget _buildRandomCta(List<GameModel> games) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [FunkyColors.magenta, FunkyColors.violet, FunkyColors.cyan],
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: FunkyColors.magenta.withValues(alpha: 0.45),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () =>
              _handleNavigation(games[_rand.nextInt(games.length)].screen),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Row(
              children: [
                const Text('🎲', style: TextStyle(fontSize: 34))
                    .animate(onPlay: (c) => c.repeat())
                    .rotate(duration: 2.seconds, begin: -0.08, end: 0.08),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'مش عارفين تلعبوا إيه؟',
                        style: GoogleFonts.cairo(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'دوس وهنختارلكوا لعبة عشوائية',
                        style: FunkyText.body(
                          size: 12.5,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_back_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ],
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 500.ms)
        .slideY(begin: 0.15, end: 0, curve: Curves.easeOutBack);
  }

  Widget _buildModeSwitch() {
    return Container(
      height: 64,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: FunkyColors.card.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: Colors.white.withAlpha(22), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          _modePill(
            label: 'أوفلاين',
            icon: Icons.grid_view_rounded,
            active: !_isOnlineMode,
            accent: FunkyColors.magenta,
            onTap: () {
              if (_isOnlineMode) setState(() => _isOnlineMode = false);
            },
          ),
          _modePill(
            label: 'أونلاين',
            icon: Icons.language_rounded,
            active: _isOnlineMode,
            accent: FunkyColors.cyan,
            onTap: () {
              if (!_isOnlineMode) setState(() => _isOnlineMode = true);
            },
          ),
        ],
      ),
    );
  }

  Widget _modePill({
    required String label,
    required IconData icon,
    required bool active,
    required Color accent,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          decoration: BoxDecoration(
            gradient: active
                ? LinearGradient(
                    colors: [accent, accent.withValues(alpha: 0.55)],
                  )
                : null,
            borderRadius: BorderRadius.circular(32),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.5),
                      blurRadius: 12,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: active ? Colors.white : Colors.white.withAlpha(110),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.cairo(
                  color: active ? Colors.white : Colors.white.withAlpha(110),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;

  const _RoundIconButton({required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: FunkyColors.card,
          border: Border.all(
            color: FunkyColors.cyan.withValues(alpha: 0.5),
            width: 1.4,
          ),
          boxShadow: [
            BoxShadow(
              color: FunkyColors.cyan.withValues(alpha: 0.25),
              blurRadius: 10,
            ),
          ],
        ),
        child: Center(child: child),
      ),
    );
  }
}

/// Full-width tilted "ticket" card: accent edge, big icon bubble, title,
/// one-line description, and a go chevron. Alternating tilt per index.
class _GameTicket extends StatelessWidget {
  final GameModel game;
  final int index;
  final VoidCallback onTap;

  const _GameTicket({
    required this.game,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tilt = (index.isEven ? -1 : 1) * 0.012;

    return Transform.rotate(
      angle: tilt,
      child: Hero(
        tag: 'game_${game.title}',
        child: Container(
          decoration: BoxDecoration(
            color: FunkyColors.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: game.color.withValues(alpha: 0.55),
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: game.color.withValues(alpha: 0.30),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              splashColor: game.color.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            game.color,
                            game.color.withValues(alpha: 0.3),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                          colors: [
                            game.color,
                            game.color.withValues(alpha: 0.55),
                          ],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: game.color.withValues(alpha: 0.5),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Icon(game.icon, size: 28, color: Colors.white),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  game.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.cairo(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    height: 1.2,
                                  ),
                                ),
                              ),
                              if (game.badge != null) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: game.color,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    game.badge!,
                                    style: GoogleFonts.cairo(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            game.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.cairo(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.75),
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 16,
                      color: game.color,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms, delay: (index * 60).ms)
        .slideX(begin: 0.06, end: 0, curve: Curves.easeOut);
  }
}

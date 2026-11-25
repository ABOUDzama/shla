import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import '../services/settings_service.dart';
import '../services/game_registry.dart';
import '../models/game_model.dart';
import 'lobby_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isNavigating = false;
  bool _isOnlineMode = false;

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
          // Elegant Dark Neon Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0F172A), // Slate 900
                  Color(0xFF1E1B4B), // Indigo 950
                  Color(0xFF312E81), // Indigo 900
                ],
              ),
            ),
          ),
          // Main Content Switcher
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(opacity: animation, child: child);
              },
              child: _isOnlineMode
                  ? const LobbyScreen(showBackButton: false)
                  : CustomScrollView(
                      key: const ValueKey('offline_grid'),
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        SliverAppBar(
                          expandedHeight: 240.0,
                          floating: false,
                          pinned: false,
                          stretch: true,
                          backgroundColor: Colors.transparent,
                          centerTitle: true,
                          actions: [
                            GestureDetector(
                              onTap: () =>
                                  _handleNavigation(const ProfileScreen()),
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(
                                      0xFF6366F1,
                                    ).withAlpha(100),
                                    width: 1.5,
                                  ),
                                ),
                                child: CircleAvatar(
                                  radius: 16,
                                  backgroundColor: const Color(0xFF1E293B),
                                  backgroundImage:
                                      SettingsService.userAvatar != null
                                          ? MemoryImage(
                                              base64Decode(
                                                SettingsService.userAvatar!,
                                              ),
                                            )
                                          : null,
                                  child: SettingsService.userAvatar == null
                                      ? const Icon(
                                          Icons.person,
                                          size: 20,
                                          color: Colors.white70,
                                        )
                                      : null,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: Icon(
                                Icons.settings_rounded,
                                color: Colors.white.withAlpha(200),
                              ),
                              onPressed: () =>
                                  _handleNavigation(const SettingsScreen()),
                            ),
                            const SizedBox(width: 10),
                          ],
                          flexibleSpace: FlexibleSpaceBar(
                            stretchModes: const [
                              StretchMode.zoomBackground,
                              StretchMode.blurBackground,
                            ],
                            centerTitle: true,
                            title: Text(
                              'شِلَّة',
                              style: GoogleFonts.cairo(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 32,
                                letterSpacing: 2.0,
                              ),
                            ),
                            background: ClipRRect(
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Container(
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Color(0xFF1E1B4B), // Indigo 950
                                          Color(0xFF0F172A), // Slate 900
                                        ],
                                      ),
                                    ),
                                  ),
                                  // Aesthetic shapes or Neon pattern
                                  const Center(
                                        child: Text(
                                          '👾',
                                          style: TextStyle(fontSize: 100),
                                        ),
                                      )
                                      .animate(
                                        onPlay: (controller) =>
                                            controller.repeat(),
                                      )
                                      .shimmer(
                                        duration: 3.seconds,
                                        delay: 1.seconds,
                                        color: Colors.white24,
                                      )
                                      .shake(hz: 2, curve: Curves.easeInOut),
                                ],
                              ),
                            ),
                          ),
                        ),

                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 130),
                          sliver: SliverGrid(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  childAspectRatio: 0.78,
                                  crossAxisSpacing: 20,
                                  mainAxisSpacing: 20,
                                ),
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              final game = games[index];
                              return _GameCard(
                                game: game,
                                index: index,
                                onTap: () => _handleNavigation(game.screen),
                              );
                            }, childCount: games.length),
                          ),
                        ),
                      ],
                    ),
            ),
          ),

          // Floating Bottom Navigation (Premium - Classic Version)
          Positioned(
            left: 20,
            right: 20,
            bottom: 30,
            child: Container(
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withAlpha(20), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        if (_isOnlineMode) {
                          setState(() => _isOnlineMode = false);
                        }
                      },
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(16),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: !_isOnlineMode
                              ? LinearGradient(
                                  colors: [
                                    const Color(0xFF6366F1).withAlpha(100),
                                    const Color(0xFF6366F1).withAlpha(40),
                                  ],
                                )
                              : null,
                          borderRadius: const BorderRadius.horizontal(
                            left: Radius.circular(16),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.grid_view_rounded,
                              color: !_isOnlineMode
                                  ? Colors.white
                                  : Colors.white.withAlpha(100),
                            ),
                            Text(
                              'أوفلاين',
                              style: GoogleFonts.cairo(
                                color: !_isOnlineMode
                                    ? Colors.white
                                    : Colors.white.withAlpha(100),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: Colors.white.withAlpha(51),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        if (!_isOnlineMode) {
                          setState(() => _isOnlineMode = true);
                        }
                      },
                      borderRadius: const BorderRadius.horizontal(
                        right: Radius.circular(16),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: _isOnlineMode
                              ? LinearGradient(
                                  colors: [
                                    const Color(0xFF6366F1).withAlpha(100),
                                    const Color(0xFF6366F1).withAlpha(40),
                                  ],
                                )
                              : null,
                          borderRadius: const BorderRadius.horizontal(
                            right: Radius.circular(16),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.language_rounded,
                              color: _isOnlineMode
                                  ? Colors.white
                                  : Colors.white.withAlpha(100),
                            ),
                            Text(
                              'أونلاين',
                              style: GoogleFonts.cairo(
                                color: _isOnlineMode
                                    ? Colors.white
                                    : Colors.white.withAlpha(100),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
}

class _GameCard extends StatelessWidget {
  final GameModel game;
  final int index;
  final VoidCallback onTap;

  const _GameCard({
    required this.game,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: 'game_${game.title}',
      child:
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                    width: 1,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onTap,
                    splashColor: game.color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            flex: 3,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    game.color.withValues(alpha: 0.35),
                                    game.color.withValues(alpha: 0.08),
                                  ],
                                ),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: game.color.withValues(alpha: 0.35),
                                    blurRadius: 18,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: FittedBox(
                                child: Icon(
                                  game.icon,
                                  size: 40,
                                  color: game.color.withValues(alpha: 0.9),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            game.title,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.visible,
                            style: GoogleFonts.cairo(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Flexible(
                            flex: 2,
                            child: Text(
                              game.description,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.cairo(
                                fontSize: 11,
                                color: Colors.white.withValues(alpha: 0.7),
                                height: 1.1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (game.badge != null)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          game.color,
                          game.color.withValues(alpha: 0.75),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      game.badge!,
                      style: GoogleFonts.cairo(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          )
              .animate()
              .fadeIn(duration: 500.ms, delay: (index * 100).ms)
              .slideY(begin: 0.2, end: 0, curve: Curves.easeOutBack),
    );
  }
}
